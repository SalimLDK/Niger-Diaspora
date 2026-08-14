-- Trouvé en revoyant les règles de gestion des groupes officiels : promouvoir
-- /rétrograder un admin et exclure un membre (group_members_screen.dart, menu
-- "gérer") n'écrivent pas dans groups/group_members mais dans
-- conversations.data.adminIds et conversations.participant_ids -- système
-- séparé de celui qu'on vient de corriger. `conversations_update`
-- (participant_ids @> [firebase_uid()]) autorise N'IMPORTE QUEL participant à
-- écrire ces champs : aucune vérification de rôle côté serveur, l'app cache
-- juste le bouton (canModerate). N'importe quel membre d'un groupe -- officiel
-- ou non -- pouvait donc s'auto-promouvoir admin, rétrograder quelqu'un
-- d'autre, ou exclure un membre en écrivant directement la ligne.
--
-- RLS ne peut pas distinguer "modifier adminIds" de "modifier mutedBy" à
-- l'intérieur d'un même JSONB (`conversations.data`) sans comparer OLD/NEW --
-- fragile à écrire correctement en policy. Un trigger BEFORE UPDATE le fait
-- proprement (accès direct et non ambigu à OLD/NEW), même idiome que
-- enforce_group_creator_trigger.

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

DROP TRIGGER IF EXISTS conversations_guard_admin_fields_trigger ON public.conversations;
CREATE TRIGGER conversations_guard_admin_fields_trigger
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.conversations_guard_admin_fields();
