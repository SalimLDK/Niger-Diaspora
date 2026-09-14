-- `coordonnees_des_groupes` nomme aussi le lieu.
--
-- La carte des groupes (`groups_map_screen.dart`) pose UN marqueur par
-- endroit, pas un par groupe : elle regroupe d'abord, puis place. Avec les
-- groupes de ville, l'endroit n'est plus toujours un pays — et la carte n'a
-- aucun moyen de le savoir depuis `GroupEntity`, qui ne porte pas `ville_id`.
--
-- Plutôt que d'ajouter une colonne à l'entité (et de faire tourner
-- `build_runner` sur tout le projet pour un libellé), la fonction rend le nom
-- du lieu avec ses coordonnées : le nom de la ville pour un groupe de ville,
-- NULL pour un groupe de pays — auquel cas la carte a déjà le pays dans le
-- groupe.
--
-- `DROP` obligatoire : changer le type de retour d'une fonction `RETURNS
-- TABLE` n'est pas un `CREATE OR REPLACE`. Une seule signature existe, donc
-- un seul `DROP`.
DROP FUNCTION IF EXISTS public.coordonnees_des_groupes(uuid[]);

CREATE OR REPLACE FUNCTION public.coordonnees_des_groupes(p_group_ids uuid[])
RETURNS TABLE (
  group_id  uuid,
  latitude  double precision,
  longitude double precision,
  source    text,
  ville_nom text
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT g.id,
         COALESCE(v.latitude, p.latitude),
         COALESCE(v.longitude, p.longitude),
         CASE WHEN v.id IS NOT NULL THEN 'ville' ELSE 'pays' END,
         v.nom
    FROM public.groups g
    LEFT JOIN public.villes v ON v.id = g.ville_id
    LEFT JOIN LATERAL (
      SELECT w.latitude, w.longitude
        FROM public.villes w
       WHERE g.ville_id IS NULL AND w.pays = g.country_code
       ORDER BY w.population DESC, w.nom
       LIMIT 1
    ) p ON TRUE
   WHERE g.id = ANY (p_group_ids)
     AND COALESCE(v.latitude, p.latitude) IS NOT NULL;
$$;

COMMENT ON FUNCTION public.coordonnees_des_groupes(uuid[]) IS
  'Où poser chaque groupe sur la carte : coordonnées de sa ville (source « ville », ville_nom rempli) ou, pour un groupe de pays, celles de la plus grande ville du pays (source « pays »). Un groupe dont le pays n''a aucune ville connue n''est pas rendu.';

REVOKE ALL ON FUNCTION public.coordonnees_des_groupes(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.coordonnees_des_groupes(uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.coordonnees_des_groupes(uuid[]) TO authenticated;
