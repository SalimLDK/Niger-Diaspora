-- Groupes : `id`, `creator_id`, `member_count`, `created_at` et `ville_id` ne
-- se réécrivent plus depuis le client.
--
-- LE DÉFAUT
-- `groups_update_admin` vaut `USING (is_group_admin(id) OR (is_official AND
-- is_admin()))` (20260813234500), sans WITH CHECK, et le seul déclencheur sur
-- le créateur, `enforce_group_creator`, n'agit qu'à l'INSERT. Un
-- administrateur de groupe — n'importe quel membre promu, pas seulement le
-- créateur — réécrit donc toute la ligne. En deux appels :
--
--   1. PATCH groups?id=eq.G  {"creator_id": "<moi>"}
--   2. rpc/delete_group(G)   -- n'autorise que creator_id (20260814003000)
--
-- il supprime le groupe, sa discussion et tout son historique, et entre-temps
-- `est_createur_du_groupe` le protège de toute exclusion. Le même chemin
-- falsifie `member_count` (affiché partout, tri de la recherche) et
-- `ville_id` (qui fait d'un groupe ordinaire LE groupe d'une ville).
--
-- LA CORRECTION
-- Même motif que `guard_conversations_colonnes_figees` (20261003120000) : un
-- déclencheur BEFORE UPDATE refuse, pour les seuls rôles clients, de changer
-- ces colonnes. Les fonctions SECURITY DEFINER (compteur de membres,
-- groupes de ville et officiels, purge de compte) écrivent sous leur
-- propriétaire et ne sont pas concernées. L'application ne les écrit jamais :
-- `updateGroup` écrit nom, description, avatar, catégorie, confidentialité,
-- lieu, étiquettes, permissions et modérateurs ; l'admin plateforme,
-- `is_private`.
--
-- Banc : tools/rls_tests/groupes_colonnes_figees.sql

-- PAS SECURITY DEFINER : `current_user` doit y rester le rôle de l'appelant.
CREATE OR REPLACE FUNCTION public.guard_groups_colonnes_figees()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.creator_id IS DISTINCT FROM OLD.creator_id
     OR NEW.member_count IS DISTINCT FROM OLD.member_count
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.ville_id IS DISTINCT FROM OLD.ville_id THEN
    RAISE EXCEPTION
      'id, creator_id, member_count, created_at et ville_id d''un groupe ne se réécrivent pas'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_groups_colonnes_figees() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS groups_colonnes_figees ON public.groups;
CREATE TRIGGER groups_colonnes_figees
  BEFORE UPDATE ON public.groups
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_groups_colonnes_figees();
