-- ============================================================================
-- Un membre NON-ADMIN ne pouvait pas ouvrir la discussion de son groupe.
--
-- Constaté sur SM A515F le 2026-09-09 : compte « Sim A », membre simple du
-- groupe « Testeurs », tape « Ouvrir la discussion » → bandeau rouge
--
--   createGroupConversation error: ServerException:
--   findGroupConversationByGroupId error: PostgrestException(message: Seul un
--   administrateur du groupe peut modifier les membres ou les droits admin de
--   cette conversation, code: 42501, details: Forbidden)
--
-- Deux migrations correctes prises séparément, incompatibles ensemble :
--
--   • 20260720130000 a créé `join_group_conversation()`, SECURITY DEFINER,
--     dont tout le travail est justement d'ajouter l'appelant à
--     `conversations.participant_ids` quand il a rejoint le groupe APRÈS la
--     création de la conversation — le cas courant. Elle vérifie d'abord
--     l'appartenance réelle dans `group_members`.
--   • 20260814000500 a ensuite posé le trigger
--     `conversations_guard_admin_fields`, qui refuse toute UPDATE modifiant
--     `participant_ids` ou `adminIds` à qui n'est pas administrateur.
--
-- **SECURITY DEFINER contourne les policies RLS, PAS les triggers.** L'UPDATE
-- de la RPC déclenche donc le trigger, qui la refuse : la fonction écrite pour
-- laisser entrer un nouveau membre est bloquée par une garde écrite trois
-- semaines plus tard, et le groupe devient inouvrable pour tous ses membres
-- simples. Seuls les administrateurs voyaient encore leur discussion.
--
-- Le trigger exempte déjà le cas symétrique — un participant qui se RETIRE
-- lui-même (quitter le groupe) sans être admin. On ajoute l'exemption
-- miroir : s'AJOUTER soi-même, et rien d'autre.
--
-- L'exemption est volontairement étroite. Elle exige tout à la fois :
--   1. `adminIds` strictement inchangé (aucun droit ne se gagne par ici) ;
--   2. `participant_ids` = l'ancien tableau + exactement UN id, ajouté en
--      queue, l'ancien contenu intact (donc aucun retrait, aucune
--      substitution) ;
--   3. cet id est celui de l'appelant ;
--   4. cet id est un membre RÉEL du groupe (`group_members`) — la même
--      vérification que fait la RPC, refaite ici pour que l'exemption tienne
--      seule, sans dépendre de qui l'appelle.
--
-- Point 3, la subtilité : le trigger identifie l'appelant par `firebase_uid()`
-- alors que la RPC ajoute `current_user_id()`. Les deux ne sont pas le même
-- code — `firebase_uid()` résout l'UID Firebase (app_metadata, puis
-- `auth_mappings`, puis `sub`), `current_user_id()` rend `sub` directement —
-- et rien ne garantit qu'ils coïncident pour tous les comptes. L'exemption
-- accepte donc l'une ou l'autre identité : ce qui autorise réellement, c'est
-- le point 4 (appartenance au groupe), le point 3 servant seulement à
-- interdire d'ajouter QUELQU'UN D'AUTRE.
-- ============================================================================

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

-- Le trigger lui-même n'est pas recréé : `CREATE OR REPLACE FUNCTION` suffit,
-- `conversations_guard_admin_fields_trigger` pointe déjà dessus.
