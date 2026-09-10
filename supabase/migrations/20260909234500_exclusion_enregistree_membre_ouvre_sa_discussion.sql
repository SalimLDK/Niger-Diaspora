-- « Tout membre peut ouvrir la discussion de son groupe » (demande de Salim,
-- 2026-09-09) -- en commençant par enregistrer l'exclusion, sans quoi la
-- phrase n'est pas applicable.
--
-- ── L'impasse, trouvée deux fois ──────────────────────────────────────────
--
-- `join_group_conversation()` (SECURITY DEFINER) ajoute l'appelant à
-- `conversations.participant_ids` : c'est ce qui fait apparaître dans l'onglet
-- Messages un groupe rejoint APRÈS la création de sa conversation -- le cas
-- courant. Le garde `conversations_guard_admin_fields` (20260814000500) refuse
-- toute modification de `participant_ids` par un non-administrateur.
-- SECURITY DEFINER contourne les policies RLS, PAS les triggers : la RPC est
-- donc bloquée, et la discussion inouvrable pour tous les membres simples.
--
-- Les deux agents ont écrit l'exemption, chacun de son côté, et chacun l'a
-- retirée pour la même raison :
--
--   * adossée à l'INVITATION, elle ne couvre pas qui a rejoint un groupe
--     PUBLIC sans jamais être invité ;
--   * adossée à l'APPARTENANCE, elle rouvre la porte aux exclus.
--
-- Parce que **l'exclusion n'était enregistrée nulle part de durable**.
-- `removeUserFromGroup` (message_supabase_datasource.dart) retire la personne
-- de `participant_ids` et de `data.adminIds`, et laisse sa ligne
-- `group_members` intacte : la base continue d'affirmer qu'elle est membre.
-- Elle apparaît même encore dans la liste des membres de la fiche, et compte
-- dans `member_count`. « Membre du groupe » ne pouvait donc pas servir à
-- autoriser quoi que ce soit.
--
-- Mesuré le 2026-09-09, migration de l'exemption appliquée dans une
-- transaction annulée puis cas d'un exclu rejoué : `exclu_de_retour = true`,
-- la RPC rend l'id de la conversation. L'exclusion était annulable par
-- l'exclu lui-même, en ouvrant simplement la discussion.
--
-- ── On ferme par le bas, côté base, et l'exemption redevient sûre ─────────
--
-- Le correctif tient en un déclencheur : disparaître de `participant_ids`
-- d'une conversation de GROUPE, c'est ne plus être membre du groupe. Aucun
-- changement côté app -- volontairement : `message_supabase_datasource.dart`
-- est tenu (modifié, non committé) par le worktree `partage-discussion`, et
-- une RPC de retrait aurait dû y être appelée. Le déclencheur fait que
-- `removeUserFromGroup`, tel qu'il est écrit aujourd'hui, fait enfin ce que
-- son nom annonce.
--
-- Les seuls chemins qui retirent un participant d'une conversation de groupe
-- sont exactement ceux qui doivent retirer l'appartenance -- vérifié sur les
-- 23 écritures de `participant_ids` du datasource :
--   * `removeUserFromGroup` -> exclusion par un administrateur ;
--   * `leave_group_conversation` -> départ volontaire (et `leaveGroup`
--     supprime déjà la ligne `group_members` de son côté : le déclencheur y
--     est un no-op).
-- « Supprimer la conversation » ne touche PAS `participant_ids` : elle écrit
-- `data.deletedBy`. Elle ne fait donc sortir personne d'un groupe.

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
     WHERE group_id = v_group_uuid AND user_id = v_retire;
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

-- AFTER, pas BEFORE : on ne modifie pas la ligne, on répercute une décision
-- déjà prise. `OF participant_ids` évite de réveiller le déclencheur à chaque
-- message (qui met `data` à jour, jamais les participants).
DROP TRIGGER IF EXISTS conversations_sync_group_removal_trigger
  ON public.conversations;
CREATE TRIGGER conversations_sync_group_removal_trigger
  AFTER UPDATE OF participant_ids ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.conversations_sync_group_removal();

-- ═══════════════════════════════════════════════════════════════════════════
-- L'exemption redevient sûre : tout membre RÉEL peut entrer dans sa discussion
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Corps repris de `20260909210500` (l'autre agent), que son auteur avait
-- retirée faute du déclencheur ci-dessus. Deux points de sa version qui
-- valent d'être conservés tels quels :
--
--   * l'id ajouté doit être `firebase_uid()` OU `current_user_id()` : le
--     garde identifie l'appelant par la première, la RPC ajoute la seconde,
--     et rien ne garantit qu'elles coïncident pour tous les comptes. Ce qui
--     autorise réellement, c'est l'appartenance ; l'égalité d'identité ne
--     sert qu'à interdire d'ajouter QUELQU'UN D'AUTRE ;
--   * la comparaison `NEW.participant_ids[1:v_old_len] = OLD.participant_ids`
--     exige un ajout en queue et l'ancien contenu intact : aucun retrait,
--     aucune substitution ne peut passer par cette porte.
--
-- Aucune reprise de données n'est nécessaire : les deux seules appartenances
-- absentes de leur conversation au 2026-09-09 (« Diaspora Niger — NE » et
-- « Testeurs », un `role='member'` chacune) sont des membres qui n'ont jamais
-- pu se rattacher, pas des exclus -- elles se rattacheront à l'ouverture.

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

  v_is_privileged := v_caller = ANY(v_old_admins)
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
