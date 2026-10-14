-- Une invitation de groupe est consommée quand l'appartenance prend fin.
--
-- LE DÉFAUT
-- `has_group_invite()` (20260909201500) ouvre la porte d'un groupe PRIVÉ
-- (`group_members_insert_gate`) à quiconque y a une invitation 'pending' OU
-- 'accepted' — 'accepted' parce que l'application marque l'invitation avant
-- d'écrire l'adhésion. Rien ne retire jamais cette invitation : ni
-- `exclure_du_groupe`, ni la synchronisation des participants, ni le départ.
-- Une personne exclue d'un groupe privé y revenait donc d'elle-même :
--
--   POST /rest/v1/group_members {"group_id": G, "user_id": "<moi>", "role": "member"}
--
-- et `join_group_conversation` la remettait dans la discussion, historique
-- compris. L'exclusion ne tenait pas.
--
-- LA CORRECTION
-- Quand une ligne `group_members` disparaît — exclusion, départ, purge —
-- l'invitation de cette personne pour ce groupe est supprimée. Revenir
-- demande une nouvelle invitation d'un administrateur (l'`upsert` sur
-- `group_id,invitee_id` de l'application en recrée une). Le parcours normal
-- ne change pas : l'invitation 'accepted' d'un membre en place reste, elle ne
-- sert à rien tant qu'il est membre.
--
-- Banc : tools/rls_tests/invitation_consommee_au_depart.sql

CREATE OR REPLACE FUNCTION public.group_members_consomme_invitation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.group_invites
   WHERE group_id = OLD.group_id
     AND invitee_id = OLD.user_id;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.group_members_consomme_invitation()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS group_members_consomme_invitation ON public.group_members;
CREATE TRIGGER group_members_consomme_invitation
  AFTER DELETE ON public.group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.group_members_consomme_invitation();
