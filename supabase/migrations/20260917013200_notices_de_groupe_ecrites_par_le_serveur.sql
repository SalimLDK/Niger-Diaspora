-- Exclure, nommer admin, retirer le rôle d'admin : l'action et sa notice dans
-- le fil, écrites ensemble par le serveur (décision de Salim, 2026-09-17).
--
-- ── Pourquoi une RPC ───────────────────────────────────────────────────────
--
-- 1. **La notice ne peut pas venir du client.** `sendSystemMessage` insérait
--    `sender_id = 'system'` dans `messages` ; la policy `messages_insert` exige
--    `firebase_uid() = sender_id`, et une conversation basculée refuse avant
--    même, par `messages_refuse_conversation_mls_trg` (23514). Placée en tête
--    de `removeUserFromGroup`, elle a empêché toute exclusion jusqu'au
--    7b3794f, qui l'a retirée. Depuis, aucune notice du tout.
--
-- 2. **Promouvoir et rétrograder ne changeaient rien de visible.** Le client
--    n'écrivait que `conversations.data.adminIds`. Or la fiche des membres lit
--    les admins dans `group_members.role` (`_membershipFor`), et c'est aussi ce
--    que lit `is_group_admin()`. Mesuré le 2026-09-17 : dans 3 groupes sur 7,
--    les deux listes divergent déjà. Un membre « promu » n'avait ni badge, ni
--    menu de gestion ; un admin « rétrogradé » gardait `role = 'admin'`, donc
--    tous ses droits. Une notice « X est maintenant admin » aurait menti :
--    les fonctions ci-dessous écrivent les DEUX.
--
-- 3. **Exclure un membre qui n'a jamais ouvert la discussion réussissait à
--    vide.** Présent dans `group_members`, absent de `participant_ids` : la
--    mise à jour ne retirait rien, `conversations_sync_group_removal` ne voyait
--    aucun départ, et la personne restait membre du groupe. L'exclusion
--    supprime désormais aussi la ligne `group_members`.
--
-- ÉCRIRE `group_members.role` N'EST PLUS POSSIBLE AUTREMENT
-- `20260917010000_group_members_role_sans_auto_promotion.sql` a fermé, le même
-- jour, l'auto-promotion : un déclencheur `BEFORE INSERT OR UPDATE` refuse tout
-- changement de `role` émis en tant que `authenticated`/`anon`. Il s'exempte
-- explicitement des fonctions `SECURITY DEFINER`, dont celles-ci
-- (`current_user` y devient le propriétaire de la fonction). Le point 2
-- ci-dessus n'est donc plus seulement « invisible » : depuis cette garde, ces
-- RPC sont le SEUL chemin qui peut nommer ou rétrograder un admin.
--
-- ── La notice ─────────────────────────────────────────────────────────────
--
-- Une ligne `messages`, `sender_id = type = 'system'`, **seulement si la
-- conversation n'est pas basculée** (`mls_since IS NULL`) : en clair dans une
-- conversation chiffrée, elle dirait au serveur ce que le chiffrement lui
-- tait. Dans un groupe MLS, l'action a lieu sans notice (dette consignée).
--
-- `data.content` porte la phrase en français — ce que lit un client qui ne
-- connaît pas encore les notices. `data.evenement` porte l'événement
-- structuré (type, acteur, cible, noms à l'instant de l'action), d'où le
-- client neuf compose la phrase dans la langue du lecteur, et dit « Vous »
-- quand c'est lui.
--
-- Déjà neutres pour un message système, vérifié dans les corps en production :
--   · `notify_recipients_on_message_insert` sort dès `sender_id = 'system'` —
--     aucune notification ;
--   · `repere_de_lecture` et `marquer_lus_jusqua` excluent `type = 'system'`
--     et `sender_id = 'system'` — pas de non-lu, pas de curseur.
-- La notice ne touche pas l'aperçu de la liste (`data.lastMessage`,
-- `last_message_at`) : une action de gestion ne remonte pas la discussion.
--
-- Échec de la notice = avertissement, jamais échec de l'action : une notice
-- manquante vaut mieux qu'un administrateur qui ne peut plus exclure.
--
-- ── Qui peut agir ─────────────────────────────────────────────────────────
--
-- La même règle que `conversations_guard_admin_fields` : admin de la
-- conversation (`data.adminIds`), admin du groupe (`is_group_admin`), ou
-- superAdmin plateforme sur un groupe officiel. Elle est RECOPIÉE ici pour
-- refuser avant d'écrire quoi que ce soit, mais le déclencheur reste l'autorité :
-- il s'exécute sur l'UPDATE que font ces fonctions, avec la même identité
-- (`firebase_uid()` lit le jeton, pas le propriétaire de la fonction). Une
-- divergence future ne pourrait que rendre la RPC plus stricte, jamais plus
-- permissive.
--
-- En plus, ce que l'écran faisait seul jusqu'ici :
--   · on n'agit pas sur soi-même (quitter a son propre chemin, avec son
--     consentement pour les groupes officiels) ;
--   · le créateur du groupe n'est ni exclu ni rétrogradé.
--
-- Le chemin direct (UPDATE de `participant_ids` / `data.adminIds`) reste ouvert
-- aux versions installées de l'app : le fermer les casserait. Il ne produit
-- simplement pas de notice.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Outils privés
-- ═══════════════════════════════════════════════════════════════════════════

-- `group_id` peut porter un identifiant Firestore hérité : il ne désigne
-- alors aucun groupe Supabase.
CREATE OR REPLACE FUNCTION private.uuid_de_groupe(p_group_id TEXT)
RETURNS UUID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN NULLIF(p_group_id, '')::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.uuid_de_groupe(TEXT) FROM PUBLIC, anon, authenticated;

-- Relit la conversation VERROUILLÉE et vérifie tout ce qui précède l'action.
-- Le verrou tient jusqu'à la fin de la transaction : `mls_since` ne peut pas
-- être posé entre la décision « notice ou pas » et l'écriture de la notice —
-- sinon `messages_refuse_conversation_mls_trg` la refuserait, et avec elle
-- l'action entière.
CREATE OR REPLACE FUNCTION private.conversation_de_groupe_a_gerer(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller TEXT := public.firebase_uid();
  v_conv   public.conversations;
  v_groupe UUID;
  v_admins TEXT[];
BEGIN
  IF v_caller IS NULL OR v_caller = '' THEN
    RAISE EXCEPTION 'Session requise' USING ERRCODE = '42501';
  END IF;
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'Membre visé manquant' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_conv
    FROM public.conversations
   WHERE id = p_conversation_id
     FOR UPDATE;

  -- Introuvable et non autorisé répondent pareil : la fonction contourne le
  -- RLS, elle ne doit pas dire à un tiers qu'une conversation existe.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seul un administrateur du groupe peut modifier les membres ou les droits admin de cette conversation'
      USING ERRCODE = '42501';
  END IF;

  IF v_conv.group_id IS NULL THEN
    RAISE EXCEPTION 'Cette conversation n''est pas celle d''un groupe'
      USING ERRCODE = '22023';
  END IF;

  v_groupe := private.uuid_de_groupe(v_conv.group_id);
  v_admins := ARRAY(
    SELECT jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(v_conv.data->'adminIds') = 'array'
           THEN v_conv.data->'adminIds' ELSE '[]'::jsonb END)
  );

  IF NOT (
       v_caller = ANY (v_admins)
    OR (v_groupe IS NOT NULL AND public.is_group_admin(v_groupe))
    OR (v_groupe IS NOT NULL AND public.is_admin()
        AND EXISTS (SELECT 1 FROM public.groups g WHERE g.id = v_groupe AND g.is_official))
  ) THEN
    RAISE EXCEPTION 'Seul un administrateur du groupe peut modifier les membres ou les droits admin de cette conversation'
      USING ERRCODE = '42501';
  END IF;

  IF p_user_id = v_caller THEN
    RAISE EXCEPTION 'On ne gère pas son propre rôle : quitter le groupe a son propre chemin'
      USING ERRCODE = '22023';
  END IF;

  RETURN v_conv;
END;
$$;

REVOKE ALL ON FUNCTION private.conversation_de_groupe_a_gerer(TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.est_createur_du_groupe(
  p_group_id TEXT,
  p_user_id  TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
           SELECT 1 FROM public.groups g
            WHERE g.id = private.uuid_de_groupe(p_group_id)
              AND g.creator_id = p_user_id)
      OR EXISTS (
           SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = private.uuid_de_groupe(p_group_id)
              AND gm.user_id = p_user_id
              AND gm.role = 'owner');
$$;

REVOKE ALL ON FUNCTION private.est_createur_du_groupe(TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

-- Pose la notice, si la conversation est en clair. Rend `true` si elle a été
-- écrite. [p_conv] est la ligne lue AVANT l'action, sous verrou.
CREATE OR REPLACE FUNCTION private.poser_notice_de_groupe(
  p_conv      public.conversations,
  p_evenement TEXT,
  p_cible     TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     TEXT := public.firebase_uid();
  v_groupe     UUID := private.uuid_de_groupe(p_conv.group_id);
  v_admins     TEXT[];
  v_acteur_id  TEXT := v_caller;
  v_acteur_nom TEXT;
  v_cible_nom  TEXT;
  v_texte      TEXT;
BEGIN
  IF p_conv.mls_since IS NOT NULL THEN
    RETURN FALSE;
  END IF;

  BEGIN
    v_admins := ARRAY(
      SELECT jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(p_conv.data->'adminIds') = 'array'
             THEN p_conv.data->'adminIds' ELSE '[]'::jsonb END)
    );

    -- Un superAdmin qui n'administre PAS ce groupe agit au nom de la
    -- plateforme : la notice nomme le groupe officiel par son créateur
    -- affiché (« Diaspo Niger »), pas le compte personnel qui a tapé. C'est
    -- la même substitution que la fiche du groupe (`isOfficialCreator`).
    IF NOT (v_caller = ANY (v_admins)
            OR (v_groupe IS NOT NULL AND public.is_group_admin(v_groupe))) THEN
      SELECT g.creator_id, NULLIF(g.creator_name, '')
        INTO v_acteur_id, v_acteur_nom
        FROM public.groups g WHERE g.id = v_groupe;
      v_acteur_id := COALESCE(v_acteur_id, v_caller);
    END IF;

    v_acteur_nom := COALESCE(
      v_acteur_nom,
      (SELECT NULLIF(u.display_name, '') FROM public.users u WHERE u.id = v_acteur_id),
      'Un administrateur'
    );
    v_cible_nom := COALESCE(
      (SELECT NULLIF(u.display_name, '') FROM public.users u WHERE u.id = p_cible),
      'Un membre'
    );

    -- Tournures sans accord de genre : « a retiré X », « a nommé X admin ».
    v_texte := CASE p_evenement
      WHEN 'membre_retire' THEN format('%s a retiré %s du groupe', v_acteur_nom, v_cible_nom)
      WHEN 'admin_nomme'   THEN format('%s a nommé %s admin', v_acteur_nom, v_cible_nom)
      WHEN 'admin_retire'  THEN format('%s a retiré le rôle d''admin à %s', v_acteur_nom, v_cible_nom)
    END;
    IF v_texte IS NULL THEN
      RAISE EXCEPTION 'événement inconnu : %', p_evenement;
    END IF;

    INSERT INTO public.messages (id, conversation_id, sender_id, type, created_at, data)
    VALUES (
      gen_random_uuid()::text,
      p_conv.id,
      'system',
      'system',
      now(),
      jsonb_build_object(
        'senderName', '',
        'content',    v_texte,
        'status',     'sent',
        'readBy',     '[]'::jsonb,
        'readAt',     '{}'::jsonb,
        'evenement',  jsonb_build_object(
          'type',      p_evenement,
          'acteurId',  v_acteur_id,
          'acteurNom', v_acteur_nom,
          'cibleId',   p_cible,
          'cibleNom',  v_cible_nom
        )
      )
    );
    RETURN TRUE;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'poser_notice_de_groupe(%, %) : %', p_conv.id, p_evenement, SQLERRM;
    RETURN FALSE;
  END;
END;
$$;

REVOKE ALL ON FUNCTION private.poser_notice_de_groupe(public.conversations, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Exclure
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Rend `true` si quelqu'un a été retiré, `false` s'il n'y avait plus personne
-- à retirer (double appui, autre admin plus rapide) — sans notice alors.

CREATE OR REPLACE FUNCTION public.exclure_du_groupe(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_conv      public.conversations;
  v_groupe    UUID;
  v_dans_conv BOOLEAN;
  v_retires   INTEGER := 0;
BEGIN
  v_conv   := private.conversation_de_groupe_a_gerer(p_conversation_id, p_user_id);
  v_groupe := private.uuid_de_groupe(v_conv.group_id);

  IF private.est_createur_du_groupe(v_conv.group_id, p_user_id) THEN
    RAISE EXCEPTION 'Le créateur du groupe ne peut pas en être exclu'
      USING ERRCODE = '42501';
  END IF;

  v_dans_conv := COALESCE(v_conv.participant_ids, ARRAY[]::text[]) @> ARRAY[p_user_id];

  IF v_dans_conv THEN
    -- `conversations_guard_admin_fields` vérifie à nouveau le droit, et
    -- `conversations_sync_group_removal` retire la ligne `group_members`.
    UPDATE public.conversations
       SET participant_ids = array_remove(participant_ids, p_user_id),
           data = jsonb_set(
             COALESCE(data, '{}'::jsonb),
             '{adminIds}',
             COALESCE(
               (SELECT jsonb_agg(a)
                  FROM jsonb_array_elements_text(
                         CASE WHEN jsonb_typeof(data->'adminIds') = 'array'
                              THEN data->'adminIds' ELSE '[]'::jsonb END) a
                 WHERE a <> p_user_id),
               '[]'::jsonb))
     WHERE id = v_conv.id;
  END IF;

  -- Sans condition : un membre qui n'a jamais ouvert la discussion n'est pas
  -- dans `participant_ids`, et le déclencheur ne l'aurait pas vu partir. Et
  -- le déclencheur avale ses erreurs : on ne compte pas sur lui.
  IF v_groupe IS NOT NULL THEN
    DELETE FROM public.group_members
     WHERE group_id = v_groupe AND user_id = p_user_id;
    GET DIAGNOSTICS v_retires = ROW_COUNT;
  END IF;

  IF NOT v_dans_conv AND v_retires = 0 THEN
    RETURN FALSE;
  END IF;

  PERFORM private.poser_notice_de_groupe(v_conv, 'membre_retire', p_user_id);
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.exclure_du_groupe(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.exclure_du_groupe(TEXT, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. Nommer admin
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Rend `true` si quelque chose a changé. Déjà admin des deux côtés : `false`,
-- sans notice. Personne visée hors du groupe : 22023. Un modérateur nommé admin perd le rôle `moderator` dans
-- `group_members` (un seul rôle par ligne) ; `groups.moderator_ids`, que
-- l'écran lit à part, n'est pas touché.

CREATE OR REPLACE FUNCTION public.nommer_admin_du_groupe(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_conv    public.conversations;
  v_groupe  UUID;
  v_admins  TEXT[];
  v_modifie BOOLEAN := FALSE;
  v_n       INTEGER;
BEGIN
  v_conv   := private.conversation_de_groupe_a_gerer(p_conversation_id, p_user_id);
  v_groupe := private.uuid_de_groupe(v_conv.group_id);

  -- Membre du groupe OU de la discussion : la fiche liste `group_members`, où
  -- figure aussi qui n'a jamais ouvert la discussion.
  IF NOT (COALESCE(v_conv.participant_ids, ARRAY[]::text[]) @> ARRAY[p_user_id])
     AND NOT EXISTS (SELECT 1 FROM public.group_members gm
                      WHERE gm.group_id = v_groupe AND gm.user_id = p_user_id) THEN
    RAISE EXCEPTION 'Ce membre ne fait pas partie du groupe'
      USING ERRCODE = '22023';
  END IF;

  v_admins := ARRAY(
    SELECT jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(v_conv.data->'adminIds') = 'array'
           THEN v_conv.data->'adminIds' ELSE '[]'::jsonb END)
  );

  IF NOT (p_user_id = ANY (v_admins)) THEN
    UPDATE public.conversations
       SET data = jsonb_set(
             COALESCE(data, '{}'::jsonb),
             '{adminIds}',
             (CASE WHEN jsonb_typeof(data->'adminIds') = 'array'
                   THEN data->'adminIds' ELSE '[]'::jsonb END)
               || to_jsonb(p_user_id))
     WHERE id = v_conv.id;
    v_modifie := TRUE;
  END IF;

  IF v_groupe IS NOT NULL THEN
    UPDATE public.group_members
       SET role = 'admin'
     WHERE group_id = v_groupe
       AND user_id = p_user_id
       AND role IN ('member', 'moderator');
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_modifie := v_modifie OR v_n > 0;
  END IF;

  IF v_modifie THEN
    PERFORM private.poser_notice_de_groupe(v_conv, 'admin_nomme', p_user_id);
  END IF;
  RETURN v_modifie;
END;
$$;

REVOKE ALL ON FUNCTION public.nommer_admin_du_groupe(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.nommer_admin_du_groupe(TEXT, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. Retirer le rôle d'admin
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Rend `true` si quelque chose a changé. Le rôle `owner` n'est jamais touché :
-- le créateur est refusé avant.

CREATE OR REPLACE FUNCTION public.retirer_admin_du_groupe(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_conv    public.conversations;
  v_groupe  UUID;
  v_admins  TEXT[];
  v_modifie BOOLEAN := FALSE;
  v_n       INTEGER;
BEGIN
  v_conv   := private.conversation_de_groupe_a_gerer(p_conversation_id, p_user_id);
  v_groupe := private.uuid_de_groupe(v_conv.group_id);

  IF private.est_createur_du_groupe(v_conv.group_id, p_user_id) THEN
    RAISE EXCEPTION 'Le créateur du groupe reste administrateur'
      USING ERRCODE = '42501';
  END IF;

  v_admins := ARRAY(
    SELECT jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(v_conv.data->'adminIds') = 'array'
           THEN v_conv.data->'adminIds' ELSE '[]'::jsonb END)
  );

  IF p_user_id = ANY (v_admins) THEN
    UPDATE public.conversations
       SET data = jsonb_set(
             COALESCE(data, '{}'::jsonb),
             '{adminIds}',
             COALESCE(
               (SELECT jsonb_agg(a)
                  FROM jsonb_array_elements_text(
                         CASE WHEN jsonb_typeof(data->'adminIds') = 'array'
                              THEN data->'adminIds' ELSE '[]'::jsonb END) a
                 WHERE a <> p_user_id),
               '[]'::jsonb))
     WHERE id = v_conv.id;
    v_modifie := TRUE;
  END IF;

  IF v_groupe IS NOT NULL THEN
    UPDATE public.group_members
       SET role = 'member'
     WHERE group_id = v_groupe
       AND user_id = p_user_id
       AND role = 'admin';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_modifie := v_modifie OR v_n > 0;
  END IF;

  IF v_modifie THEN
    PERFORM private.poser_notice_de_groupe(v_conv, 'admin_retire', p_user_id);
  END IF;
  RETURN v_modifie;
END;
$$;

REVOKE ALL ON FUNCTION public.retirer_admin_du_groupe(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.retirer_admin_du_groupe(TEXT, TEXT) TO authenticated;
