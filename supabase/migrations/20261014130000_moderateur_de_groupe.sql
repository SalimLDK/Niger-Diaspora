-- Nommer un modérateur lui donne enfin les droits de modérateur.
--
-- LE DÉFAUT
-- L'écran des membres nommait un modérateur en écrivant `groups.moderator_ids`
-- (via `updateGroup`). Le serveur, lui, ne lit QUE `group_members.role` :
-- les policies des sondages et des épingles (20260803180000) accordent
-- `role = 'moderator'`, et `guard_group_members_role` (20260917010000)
-- interdit au client de changer ce rôle. « Membre promu modérateur »
-- affichait donc un badge qui ne donnait rien. Et la bascule réécrivait toute
-- la ligne `groups` depuis la copie de l'écran : deux administrateurs au même
-- moment s'écrasaient l'un l'autre.
--
-- LA CORRECTION
--   · `basculer_moderateur_du_groupe(groupe, membre, moderateur)` :
--     SECURITY DEFINER, réservée aux administrateurs du groupe (ou à un
--     superadmin pour un groupe officiel). Elle ne touche qu'un `member` ou
--     un `moderator` — jamais un admin ni le propriétaire, dont les rôles ont
--     leurs propres RPC — et tient `groups.moderator_ids` (que l'application
--     affiche) au même pas, élément par élément.
--   · Rattrapage : les membres déjà inscrits dans `moderator_ids` reçoivent le
--     rôle `moderator` — ce que l'administrateur avait voulu leur donner.
--
-- Banc : tools/rls_tests/moderateur_de_groupe.sql

CREATE OR REPLACE FUNCTION public.basculer_moderateur_du_groupe(
  p_group_id   uuid,
  p_user_id    text,
  p_moderateur boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := public.firebase_uid();
  v_role   text;
BEGIN
  IF v_caller IS NULL OR v_caller = '' THEN
    RAISE EXCEPTION 'Session requise' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       public.is_group_admin(p_group_id)
    OR (public.is_admin()
        AND EXISTS (SELECT 1 FROM public.groups g
                     WHERE g.id = p_group_id AND g.is_official))
  ) THEN
    RAISE EXCEPTION 'Seul un administrateur du groupe nomme ses modérateurs'
      USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_role
    FROM public.group_members
   WHERE group_id = p_group_id AND user_id = p_user_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cette personne n''est pas membre du groupe'
      USING ERRCODE = '22023';
  END IF;
  IF v_role NOT IN ('member', 'moderator') THEN
    RAISE EXCEPTION 'Un administrateur ne devient pas modérateur : retirer d''abord son rôle d''admin'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.group_members
     SET role = CASE WHEN p_moderateur THEN 'moderator' ELSE 'member' END
   WHERE group_id = p_group_id AND user_id = p_user_id;

  -- Élément par élément : pas de réécriture de toute la liste.
  UPDATE public.groups
     SET moderator_ids = CASE
           WHEN p_moderateur
             THEN array_append(array_remove(moderator_ids, p_user_id), p_user_id)
           ELSE array_remove(moderator_ids, p_user_id)
         END
   WHERE id = p_group_id;
END;
$$;

REVOKE ALL ON FUNCTION public.basculer_moderateur_du_groupe(uuid, text, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.basculer_moderateur_du_groupe(uuid, text, boolean)
  TO authenticated;

-- Rattrapage des modérateurs nommés par l'ancien chemin.
UPDATE public.group_members gm
   SET role = 'moderator'
  FROM public.groups g
 WHERE g.id = gm.group_id
   AND gm.role = 'member'
   AND gm.user_id = ANY (g.moderator_ids);
