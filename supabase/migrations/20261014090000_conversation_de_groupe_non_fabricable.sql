-- Une conversation rattachée à un groupe ne se fabrique plus côté client.
--
-- LE DÉFAUT
-- `data.adminIds` d'une conversation vaut droit d'administrateur du GROUPE en
-- trois endroits : `private.conversation_de_groupe_a_gerer` (exclure, nommer,
-- retirer un admin), `conversations_guard_admin_fields` (retirer des
-- participants) et, par lui, `conversations_sync_group_removal`, qui supprime
-- de `group_members` toute personne retirée des participants. Depuis
-- 20261003120000, `group_id`, `type` et `created_by` ne se réécrivent plus en
-- UPDATE — mais rien ne gardait l'INSERT : `conversations_insert` ne demande
-- que d'être parmi les participants. N'importe quel compte, sans être membre :
--
--   1. INSERT conversations (type 'individual', group_id = G,
--      participant_ids = [moi, propriétaire, membres…],
--      data = {"adminIds": ["moi"]})
--      — 'individual' pour échapper à l'index unique `conversations_une_par_
--      groupe`, qui ne vise que type = 'group' ;
--   2. UPDATE participant_ids = [moi] : la garde me lit dans l'ancien
--      adminIds, laisse passer, et le déclencheur de synchronisation SUPPRIME
--      de G le propriétaire et tous les membres ;
--   ou, sur la même conversation, `nommer_admin_du_groupe(conv, compte2)` :
--      un second compte, simple membre d'un groupe public, devient
--      `role = 'admin'` dans `group_members` — de vrais droits sur G.
-- Variante : pour un groupe sans discussion, l'INSERT de type 'group' passe
-- l'index unique, et `join_group_conversation` y fait entrer les vrais
-- membres — l'intrus lit leur discussion.
--
-- Et l'application le faisait sans attaquant : `createGroupConversation` pose
-- `adminIds = [qui ouvre la discussion le premier]`, simple membre compris.
--
-- LA CORRECTION
--   · À l'INSERT par un client (anon/authenticated), une conversation qui
--     porte un `group_id` est de type 'group', ouverte par un MEMBRE du groupe
--     (ou un superadmin pour un groupe officiel) ; ses participants sont
--     ramenés aux membres du groupe (plus l'auteur), et `data.adminIds` aux
--     administrateurs réels (`group_members.role` owner/admin). Filtrer plutôt
--     que refuser : l'application continue d'ouvrir la discussion comme avant.
--     Groupes hérités de Firestore (`group_id` non UUID) : seul le type est
--     exigé — aucun `group_members` à protéger.
--   · `data.adminIds` ne vaut plus que sur une conversation de type 'group' :
--     une ligne fabriquée AVANT cette migration (type 'individual' + group_id)
--     ne donne plus aucun droit. Les administrateurs de discussion légitimes,
--     que `notices_de_groupe.sql` a relevés en production (admin dans
--     adminIds, simple `member` dans `group_members`), gardent les leurs : ils
--     sont sur la conversation canonique, de type 'group'.
--   · Filet : la synchronisation ne supprime jamais la ligne du propriétaire.
--
-- Fonctions recopiées de leur dernière version (20260917013200,
-- 20260909234500) ; seules les lignes marquées « 20261014 » changent.
--
-- Banc : tools/rls_tests/conversation_de_groupe_fabriquee.sql

-- ═══ 1. Garde d'insertion ═══════════════════════════════════════════════════

-- PAS SECURITY DEFINER : `current_user` y vaudrait le propriétaire de la
-- fonction, et la garde se croirait toujours appelée par le serveur. Elle lit
-- donc `group_members` sous le RLS de l'appelant : `group_members_select`
-- (20260806190000) montre à un membre tous les membres de son groupe, et à un
-- étranger rien d'un groupe privé — ce qui suffit à le refuser.
CREATE OR REPLACE FUNCTION public.guard_conversations_insertion_de_groupe()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller TEXT;
  v_groupe UUID;
BEGIN
  -- Une RPC SECURITY DEFINER écrit sous son propriétaire : pas concernée.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.type IS DISTINCT FROM 'group' THEN
    RAISE EXCEPTION 'Une conversation rattachée à un groupe est de type group'
      USING ERRCODE = '42501';
  END IF;

  -- Pas `private.uuid_de_groupe` : révoquée pour `authenticated`.
  BEGIN
    v_groupe := NULLIF(NEW.group_id, '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    v_groupe := NULL;
  END;
  IF v_groupe IS NULL THEN
    RETURN NEW;  -- groupe hérité de Firestore
  END IF;

  v_caller := public.firebase_uid();
  IF v_caller IS NULL OR v_caller = '' THEN
    RAISE EXCEPTION 'Session requise' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       EXISTS (SELECT 1 FROM public.group_members gm
                WHERE gm.group_id = v_groupe AND gm.user_id = v_caller)
    OR (public.is_admin()
        AND EXISTS (SELECT 1 FROM public.groups g
                     WHERE g.id = v_groupe AND g.is_official))
  ) THEN
    RAISE EXCEPTION 'Seul un membre du groupe ouvre sa discussion'
      USING ERRCODE = '42501';
  END IF;

  -- Participants : les membres du groupe, plus l'auteur ; ordre conservé.
  NEW.participant_ids := ARRAY(
    SELECT u.p
      FROM unnest(COALESCE(NEW.participant_ids, ARRAY[]::text[]))
           WITH ORDINALITY AS u(p, i)
     WHERE u.p = v_caller
        OR EXISTS (SELECT 1 FROM public.group_members gm
                    WHERE gm.group_id = v_groupe AND gm.user_id = u.p)
     ORDER BY u.i
  );

  -- adminIds : les administrateurs réels seulement.
  IF jsonb_typeof(NEW.data->'adminIds') = 'array' THEN
    NEW.data := jsonb_set(NEW.data, '{adminIds}', to_jsonb(ARRAY(
      SELECT a.id
        FROM jsonb_array_elements_text(NEW.data->'adminIds')
             WITH ORDINALITY AS a(id, i)
       WHERE EXISTS (SELECT 1 FROM public.group_members gm
                      WHERE gm.group_id = v_groupe AND gm.user_id = a.id
                        AND gm.role IN ('owner', 'admin'))
       ORDER BY a.i
    )));
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_conversations_insertion_de_groupe()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS conversations_insertion_de_groupe ON public.conversations;
CREATE TRIGGER conversations_insertion_de_groupe
  BEFORE INSERT ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_conversations_insertion_de_groupe();

-- ═══ 2. adminIds ne vaut que sur la conversation de type 'group' ═══════════

-- 20261014 : `v_conv.type = 'group' AND` devant `v_caller = ANY (v_admins)`.
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
       (v_conv.type = 'group' AND v_caller = ANY (v_admins))
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

-- 20261014 : `NEW.type = 'group' AND` devant `v_caller = ANY(v_old_admins)`.
CREATE OR REPLACE FUNCTION public.conversations_guard_admin_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := firebase_uid();
  v_old_admins text[];
  v_new_admins text[];
  v_group_uuid uuid;
  v_is_privileged boolean;
  v_old_len int;
  v_new_len int;
  v_added text;
BEGIN
  -- Les conversations 1:1 n'ont pas de notion d'admin/exclusion.
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_old_admins := ARRAY(
    SELECT jsonb_array_elements_text(COALESCE(OLD.data->'adminIds', '[]'::jsonb))
  );
  v_new_admins := ARRAY(
    SELECT jsonb_array_elements_text(COALESCE(NEW.data->'adminIds', '[]'::jsonb))
  );

  -- adminIds et participant_ids inchangés : rien à protéger ici (mute,
  -- épingle, nom, etc. passent librement, comme avant).
  IF v_old_admins = v_new_admins AND OLD.participant_ids = NEW.participant_ids THEN
    RETURN NEW;
  END IF;

  -- Un participant qui se retire lui-même (quitter le groupe) reste autorisé
  -- sans être admin -- seul SON id disparaît de participant_ids et adminIds.
  IF NEW.participant_ids = array_remove(OLD.participant_ids, v_caller)
     AND OLD.participant_ids @> ARRAY[v_caller]
     AND NEW.participant_ids <> OLD.participant_ids
     AND v_new_admins = array_remove(v_old_admins, v_caller) THEN
    RETURN NEW;
  END IF;

  -- group_id peut être un id hérité Firestore (non-UUID) : cast protégé, une
  -- valeur non-UUID retombe simplement sur "pas de groupe Supabase associé"
  -- plutôt que de faire échouer le trigger.
  BEGIN
    v_group_uuid := NULLIF(NEW.group_id, '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    v_group_uuid := NULL;
  END;

  -- Cas miroir : un membre réel du groupe s'AJOUTE lui-même aux participants,
  -- et rien d'autre. C'est exactement ce que fait `join_group_conversation()`
  -- à l'ouverture de la discussion par quelqu'un qui a rejoint le groupe après
  -- la création de celle-ci.
  v_old_len := COALESCE(array_length(OLD.participant_ids, 1), 0);
  v_new_len := COALESCE(array_length(NEW.participant_ids, 1), 0);

  IF v_group_uuid IS NOT NULL
     AND v_old_admins = v_new_admins
     AND v_new_len = v_old_len + 1
     AND COALESCE(NEW.participant_ids[1:v_old_len], ARRAY[]::text[])
         = COALESCE(OLD.participant_ids, ARRAY[]::text[])
  THEN
    v_added := NEW.participant_ids[v_new_len];

    IF v_added IS NOT NULL
       AND v_added IN (v_caller, current_user_id())
       AND NOT (COALESCE(OLD.participant_ids, ARRAY[]::text[]) @> ARRAY[v_added])
       AND EXISTS (
         SELECT 1 FROM public.group_members gm
         WHERE gm.group_id = v_group_uuid AND gm.user_id = v_added
       )
    THEN
      RETURN NEW;
    END IF;
  END IF;

  v_is_privileged := (NEW.type = 'group' AND v_caller = ANY(v_old_admins))
    OR (v_group_uuid IS NOT NULL AND is_group_admin(v_group_uuid))
    OR (
      v_group_uuid IS NOT NULL AND is_admin()
      AND EXISTS (SELECT 1 FROM groups g WHERE g.id = v_group_uuid AND g.is_official)
    );

  IF NOT v_is_privileged THEN
    RAISE EXCEPTION 'Seul un administrateur du groupe peut modifier les membres ou les droits admin de cette conversation'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- ═══ 3. Filet : jamais la ligne du propriétaire ═════════════════════════════

-- 20261014 : `AND role <> 'owner'` sur le DELETE.
CREATE OR REPLACE FUNCTION public.conversations_sync_group_removal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_group_uuid uuid;
  v_retire     text;
BEGIN
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_group_uuid := NULLIF(NEW.group_id, '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    -- Groupe hérité de Firestore : aucune ligne `group_members` à tenir.
    v_group_uuid := NULL;
  END;
  IF v_group_uuid IS NULL THEN
    RETURN NEW;
  END IF;

  FOR v_retire IN
    SELECT id FROM unnest(COALESCE(OLD.participant_ids, ARRAY[]::text[])) AS o(id)
     WHERE NOT (COALESCE(NEW.participant_ids, ARRAY[]::text[]) @> ARRAY[o.id])
  LOOP
    DELETE FROM group_members
     WHERE group_id = v_group_uuid AND user_id = v_retire
       AND role <> 'owner';
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais faire échouer l'exclusion elle-même : mieux vaut une
    -- appartenance qui traîne qu'un administrateur qui ne peut plus exclure.
    RAISE WARNING 'conversations_sync_group_removal: %', SQLERRM;
    RETURN NEW;
END;
$$;
