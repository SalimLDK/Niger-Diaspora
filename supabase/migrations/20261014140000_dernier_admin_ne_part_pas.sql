-- Le dernier administrateur d'un groupe ne le quitte pas en laissant des
-- membres sans personne pour le gérer.
--
-- LE DÉFAUT
-- La règle « le créateur ne part que s'il reste un autre administrateur »
-- n'existait que dans l'application (menu de la fiche du groupe).
-- `group_members_own` laisse chacun supprimer sa propre ligne : un appel
-- direct (ou une version de l'app qui n'a pas le garde-fou) laissait un
-- groupe avec des membres et sans aucun `owner`/`admin`. Plus personne ne
-- pouvait accepter une demande, inviter, exclure ni nommer d'administrateur
-- — et `is_group_admin` ne rendait plus jamais vrai pour ce groupe.
--
-- LA CORRECTION
-- BEFORE DELETE, pour les seuls rôles clients : on refuse de retirer la
-- dernière ligne `owner`/`admin` d'un groupe tant qu'il y reste d'autres
-- membres. Le dernier membre, lui, part librement. Les chemins serveur
-- (exclusion, suppression du groupe par cascade, purge de compte) écrivent
-- sous leur propriétaire et ne sont pas concernés.
--
-- Banc : tools/rls_tests/dernier_admin_ne_part_pas.sql

-- PAS SECURITY DEFINER : `current_user` doit y rester le rôle de l'appelant.
-- La lecture des autres membres passe par le RLS de l'appelant, membre du
-- groupe tant que sa ligne existe (`group_members_select`, 20260806190000).
CREATE OR REPLACE FUNCTION public.guard_dernier_admin_du_groupe()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN OLD;
  END IF;
  IF OLD.role NOT IN ('owner', 'admin') THEN
    RETURN OLD;
  END IF;

  IF EXISTS (SELECT 1 FROM public.group_members gm
              WHERE gm.group_id = OLD.group_id
                AND gm.user_id <> OLD.user_id
                AND gm.role IN ('owner', 'admin')) THEN
    RETURN OLD;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.group_members gm
                  WHERE gm.group_id = OLD.group_id
                    AND gm.user_id <> OLD.user_id) THEN
    RETURN OLD;  -- dernier membre : rien à administrer après lui
  END IF;

  RAISE EXCEPTION 'Dernier administrateur du groupe : nommer un autre administrateur avant de partir'
    USING ERRCODE = '42501';
END;
$$;

REVOKE ALL ON FUNCTION public.guard_dernier_admin_du_groupe() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS group_members_dernier_admin ON public.group_members;
CREATE TRIGGER group_members_dernier_admin
  BEFORE DELETE ON public.group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_dernier_admin_du_groupe();
