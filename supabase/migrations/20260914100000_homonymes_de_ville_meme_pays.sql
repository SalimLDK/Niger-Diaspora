-- Deux villes homonymes dans le MÊME pays : le pays ne les distingue pas.
--
-- Vérifié sur la base peuplée le 2026-09-14, avant tout groupe de ville réel.
-- Le cas inter-pays marchait : « Victoria » (Canada) puis « Victoria »
-- (Seychelles) donnent « — Victoria (Canada) » et « — Victoria (Seychelles) »,
-- la première renommée à l'arrivée de la seconde. Mais les deux Springfield
-- des États-Unis donnaient « — Springfield » et « — Springfield
-- (États-Unis) » : un qualificatif qui ne qualifie rien, et deux groupes au
-- même nom une fois la première renommée.
--
-- Le référentiel a ce qu'il faut : `villes.region` dit Missouri et
-- Massachusetts. La règle devient donc « le plus précis qui distingue » —
-- la région quand l'homonyme est dans le même pays, le pays sinon. Un
-- homonyme sans région retombe sur le pays : mieux vaut un qualificatif
-- faible qu'aucun.
--
-- L'unicité ne repose toujours pas sur le nom : `uniq_groupe_officiel_par_ville`
-- la tient, et ces noms ne sont que de l'affichage.

/**
 * Le nom que porterait le groupe de cette ville, vu les groupes qui existent
 * DÉJÀ. Appelée avant l'insertion pour le nouveau groupe, après pour
 * renommer ses homonymes — c'est le même calcul, à un instant différent.
 */
CREATE OR REPLACE FUNCTION public.nom_du_groupe_de_ville(p_ville_id bigint)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.villes%ROWTYPE;
  v_meme_pays  boolean;
  v_autre_pays boolean;
BEGIN
  SELECT * INTO v FROM public.villes WHERE id = p_ville_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT
    EXISTS (SELECT 1 FROM public.groups g JOIN public.villes w ON w.id = g.ville_id
             WHERE g.is_official AND w.id <> v.id
               AND w.nom_plie = v.nom_plie AND w.pays = v.pays),
    EXISTS (SELECT 1 FROM public.groups g JOIN public.villes w ON w.id = g.ville_id
             WHERE g.is_official AND w.id <> v.id
               AND w.nom_plie = v.nom_plie AND w.pays <> v.pays)
  INTO v_meme_pays, v_autre_pays;

  IF v_meme_pays AND COALESCE(v.region, '') <> '' THEN
    RETURN format('Diaspora Niger — %s (%s)', v.nom, v.region);
  ELSIF v_meme_pays OR v_autre_pays THEN
    RETURN format('Diaspora Niger — %s (%s)', v.nom, v.pays);
  END IF;
  RETURN format('Diaspora Niger — %s', v.nom);
END;
$$;

/**
 * Ce nom est-il encore l'un de ceux que la plateforme a pu poser elle-même ?
 *
 * Sert de garde au renommage : un nom retouché à la main appartient à qui l'a
 * écrit, et aucun homonyme arrivant plus tard ne doit l'effacer.
 */
CREATE OR REPLACE FUNCTION public.est_nom_automatique_de_ville(p_ville_id bigint, p_nom text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_nom IN (
    format('Diaspora Niger — %s', v.nom),
    format('Diaspora Niger — %s (%s)', v.nom, v.pays),
    format('Diaspora Niger — %s (%s)', v.nom, COALESCE(v.region, ''))
  )
  FROM public.villes v WHERE v.id = p_ville_id;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- La création reprend ces deux fonctions, et surtout renomme les homonymes
-- APRÈS l'insertion : avant, le nouveau groupe n'existe pas encore, donc
-- `nom_du_groupe_de_ville` ne le compte pas parmi les homonymes des autres et
-- leur rendrait leur nom nu.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_or_create_ville_group(p_ville_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_row public.groups%ROWTYPE;
  v_ville public.villes%ROWTYPE;
  v_platform_uid CONSTANT text := 'czk5UoUclLOFmbRtUIZ5XYLYKo52';
BEGIN
  SELECT * INTO v_ville FROM public.villes
   WHERE id = public.ville_de_groupe(p_ville_id);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ville inconnue : %', p_ville_id USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_row FROM public.groups
    WHERE ville_id = v_ville.id AND is_official
    LIMIT 1;
  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  ALTER TABLE public.groups DISABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups DISABLE TRIGGER groups_guard_official;

  INSERT INTO public.groups (
    name, description, creator_id, creator_name,
    category, is_private, country_code, ville_id, is_official, member_count
  ) VALUES (
    public.nom_du_groupe_de_ville(v_ville.id),
    format('Groupe officiel de la communauté nigérienne de %s.', v_ville.nom),
    v_platform_uid, 'Diaspo Niger',
    'regional', false, v_ville.pays, v_ville.id, true, 0
  )
  ON CONFLICT (ville_id) WHERE is_official AND ville_id IS NOT NULL DO NOTHING
  RETURNING * INTO v_row;

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  IF NOT FOUND THEN
    SELECT * INTO v_row FROM public.groups
      WHERE ville_id = v_ville.id AND is_official LIMIT 1;
    RETURN row_to_json(v_row);
  END IF;

  -- Les homonymes déjà en place gagnent leur qualificatif, s'ils portent
  -- encore un nom posé par la plateforme.
  UPDATE public.groups g
     SET name = public.nom_du_groupe_de_ville(g.ville_id)
    FROM public.villes w
   WHERE w.id = g.ville_id
     AND g.is_official
     AND w.id <> v_ville.id
     AND w.nom_plie = v_ville.nom_plie
     AND public.est_nom_automatique_de_ville(g.ville_id, g.name)
     AND g.name IS DISTINCT FROM public.nom_du_groupe_de_ville(g.ville_id);

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_platform_uid, 'owner')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';

  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;
  RETURN row_to_json(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.nom_du_groupe_de_ville(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.nom_du_groupe_de_ville(bigint) FROM anon;
REVOKE ALL ON FUNCTION public.est_nom_automatique_de_ville(bigint, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.est_nom_automatique_de_ville(bigint, text) FROM anon;
