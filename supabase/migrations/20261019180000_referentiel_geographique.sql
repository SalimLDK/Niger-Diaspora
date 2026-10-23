-- Référentiel géographique : gérer villes et pays sans casser ce qui s'y appuie.
--
-- Référentiel d'administration § 7 (« Pays, villes, géodonnées »), spécification
-- d'interfaces § 12 (« CRUD avec contrôle des dépendances, détecter les
-- doublons de villes, conserver des identifiants stables, auditer toute
-- modification de référentiel »).
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- `pays` (197) et `villes` (33 880, GeoNames + liste Niger) : lecture publique,
-- aucune écriture prévue — le référentiel se chargeait par le script
-- `tools/import_villes_geonames.mjs`. Deux faits à nommer :
--
-- • Les deux tables donnaient TOUS les droits (INSERT, UPDATE, DELETE, TRUNCATE,
--   REFERENCES, TRIGGER) à `anon` et à `authenticated`. Seule la RLS (activée,
--   avec une unique policy SELECT) retenait les écritures ; TRUNCATE, lui,
--   ignore la RLS. PostgREST n'expose pas TRUNCATE, ce n'était donc pas une
--   porte ouverte, mais le motif est celui que le dépôt documente : un
--   `GRANT` n'enlève rien, il faut `REVOKE`.
-- • Une ville n'est pas une simple ligne d'adresse : `users.ville_id` et
--   `groups.ville_id` y pointent, des groupes officiels « Diaspora Niger —
--   <ville> » s'ouvrent à partir d'elle, et `pays.nom` est la clé de textes
--   (`users.country_code` porte des NOMS de pays). Y toucher sans contrôle des
--   dépendances casserait des groupes et des profils.
-- • 829 couples (nom plié, pays) portent plusieurs villes. La plupart sont de
--   vrais homonymes distants ; une partie sont des doublons.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • Droits d'écriture retirés à `anon` et `authenticated` sur les deux tables
--   (la lecture publique reste).
-- • `referentiel_history` : tout ajout, changement, fusion ou suppression, avec
--   l'ancienne et la nouvelle valeur, l'auteur et le motif. Ajout seul.
-- • `ville_admin_save` (créer / modifier, `nom_plie` recalculé par la même
--   fonction que l'application et l'import), `ville_admin_merge`,
--   `ville_admin_delete`, `pays_admin_add`, `villes_doublons_possibles`.
--   Motif obligatoire, audit dans la même transaction.
-- • Contrôle des dépendances : on ne supprime pas une ville utilisée par un
--   profil ou un groupe, on ne change pas son pays si elle est utilisée, on ne
--   fusionne pas deux villes de pays différents, ni une ville qui porte un
--   groupe (fusionner les groupes d'abord). Une fusion reporte les profils et
--   les pôles sur la ville conservée, réunit les alias, garde la plus grande
--   population, et trace le geonames_id de la ville retirée.
-- • Doublon à la création : une ville de même nom plié, dans le même pays, à
--   moins de 20 km d'une existante est refusée.
-- • `geography.reference.manage` : au catalogue, mappée à AUCUN rôle — seul le
--   superAdmin la porte. Une ville fausse peut ouvrir des groupes officiels.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle ne renomme ni ne supprime un PAYS : `pays.nom` est référencé comme
--   texte par `users.country_code`, `businesses.country_code`, `events` … sans
--   clé étrangère ; un renommage laisserait des profils orphelins. L'ajout
--   seul est offert.
-- • Elle ne gère pas les CATÉGORIES de fiches : elles vivent dans une
--   énumération Dart de l'application (`BusinessCategory`), pas en base ; en
--   ajouter une côté panneau sans nouvelle version de l'application n'afficherait
--   rien. C'est un chantier d'application, pas de cette tranche.
-- • Elle ne corrige pas les 159 comptes sans pays ni les noms de pays
--   mal orthographiés des profils existants.
--
-- Banc : tools/rls_tests/referentiel_geographique.sql.

SET lock_timeout = '5s';

-- ── 1. Droits ───────────────────────────────────────────────────────────────
REVOKE ALL ON public.pays   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.villes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.pays   TO anon, authenticated;
GRANT SELECT ON public.villes TO anon, authenticated;

INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('geography.reference.manage', 'directory', 'Gérer le référentiel des villes et des pays', NULL)
ON CONFLICT (key) DO NOTHING;
-- Volontairement aucun INSERT dans admin_role_permissions (voir l'en-tête).

-- ── 2. L'historique ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.referentiel_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity      text NOT NULL CHECK (entity IN ('ville', 'pays')),
  entity_id   text NOT NULL,     -- pas de FK : l'historique survit à la suppression
  kind        text NOT NULL CHECK (kind IN ('created', 'updated', 'merged', 'deleted')),
  actor_id    text NOT NULL,
  changes     jsonb NOT NULL,
  reason      text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS referentiel_history_idx
  ON public.referentiel_history (entity, entity_id, occurred_at DESC);

ALTER TABLE public.referentiel_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.referentiel_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.referentiel_history TO authenticated;
DROP POLICY IF EXISTS referentiel_history_select ON public.referentiel_history;
CREATE POLICY referentiel_history_select ON public.referentiel_history
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('geography.reference.manage'));

CREATE OR REPLACE FUNCTION public.referentiel_history_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'referentiel_history est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS referentiel_history_no_rewrite ON public.referentiel_history;
CREATE TRIGGER referentiel_history_no_rewrite
  BEFORE UPDATE OR DELETE ON public.referentiel_history
  FOR EACH ROW EXECUTE FUNCTION public.referentiel_history_append_only();

-- ── 3. Utilisation d'une ville (profils, groupes) ───────────────────────────
DROP FUNCTION IF EXISTS public.ville_utilisation(bigint);

CREATE FUNCTION public.ville_utilisation(p_id bigint) RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'profils', (SELECT count(*) FROM public.users WHERE ville_id = p_id),
    'groupes', (SELECT count(*) FROM public.groups WHERE ville_id = p_id),
    'poles',   (SELECT count(*) FROM public.villes WHERE pole_id = p_id))
$$;

REVOKE ALL ON FUNCTION public.ville_utilisation(bigint) FROM PUBLIC, anon, authenticated;

-- ── 4. Créer / modifier une ville ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.ville_admin_save(bigint, text, text, text, double precision, double precision, integer, text[], text);

CREATE FUNCTION public.ville_admin_save(
  p_id         bigint,
  p_nom        text,
  p_pays       text,
  p_region     text,
  p_lat        double precision,
  p_lon        double precision,
  p_population integer,
  p_aliases    text[],
  p_reason     text
) RETURNS bigint
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller  text := (SELECT public.firebase_uid());
  v_plie    text;
  v_alias   text[];
  old_v     public.villes%ROWTYPE;
  v_id      bigint;
  v_voisine bigint;
  v_use     jsonb;
  v_changes jsonb := '{}'::jsonb;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ville : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('geography.reference.manage');

  IF p_nom IS NULL OR length(btrim(p_nom)) NOT BETWEEN 2 AND 120 THEN
    RAISE EXCEPTION 'ville : nom requis (2 à 120 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_pays IS NULL OR NOT EXISTS (SELECT 1 FROM public.pays WHERE nom = p_pays) THEN
    RAISE EXCEPTION 'ville : pays inconnu du référentiel' USING ERRCODE = '22023';
  END IF;
  IF p_lat IS NULL OR p_lat NOT BETWEEN -90 AND 90 OR p_lon IS NULL OR p_lon NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'ville : coordonnées invalides (latitude -90..90, longitude -180..180)'
      USING ERRCODE = '22023';
  END IF;
  IF p_population IS NULL OR p_population < 0 OR p_population > 100000000 THEN
    RAISE EXCEPTION 'ville : population invalide' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_region, '')) > 120 THEN
    RAISE EXCEPTION 'ville : région trop longue' USING ERRCODE = '22001';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'ville : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  IF coalesce(array_length(p_aliases, 1), 0) > 20 THEN
    RAISE EXCEPTION 'ville : 20 alias au plus' USING ERRCODE = '22023';
  END IF;

  v_plie := public.plier_nom_de_pays(btrim(p_nom));
  SELECT coalesce(array_agg(DISTINCT public.plier_nom_de_pays(btrim(a)))
                  FILTER (WHERE length(btrim(a)) BETWEEN 1 AND 80
                            AND public.plier_nom_de_pays(btrim(a)) <> v_plie),
                  '{}')
    INTO v_alias FROM unnest(coalesce(p_aliases, '{}')) a;

  -- Doublon probable : même nom plié, même pays, moins de 20 km.
  SELECT v.id INTO v_voisine FROM public.villes v
   WHERE v.nom_plie = v_plie AND v.pays = p_pays AND v.id IS DISTINCT FROM p_id
     AND 2 * 6371 * asin(sqrt(
           power(sin(radians((v.latitude - p_lat) / 2)), 2)
           + cos(radians(p_lat)) * cos(radians(v.latitude))
             * power(sin(radians((v.longitude - p_lon) / 2)), 2))) < 20
   LIMIT 1;
  IF v_voisine IS NOT NULL THEN
    RAISE EXCEPTION 'ville : doublon probable de la ville % (même nom, moins de 20 km)', v_voisine
      USING ERRCODE = '55000';
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.villes (nom, nom_plie, pays, region, latitude, longitude, population, alias_plies)
    VALUES (btrim(p_nom), v_plie, p_pays, nullif(btrim(coalesce(p_region, '')), ''),
            p_lat, p_lon, p_population, v_alias)
    RETURNING id INTO v_id;
    INSERT INTO public.referentiel_history (entity, entity_id, kind, actor_id, changes, reason)
    VALUES ('ville', v_id::text, 'created', v_caller,
            jsonb_build_object('nom', btrim(p_nom), 'pays', p_pays, 'latitude', p_lat, 'longitude', p_lon),
            btrim(p_reason));
    PERFORM public.write_admin_audit('REFERENTIEL_VILLE_CREATED', 'ville', v_id::text, 'success',
      NULL, v_id::text, jsonb_build_object('pays', p_pays));
    RETURN v_id;
  END IF;

  SELECT * INTO old_v FROM public.villes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ville : introuvable' USING ERRCODE = 'P0002';
  END IF;
  v_use := public.ville_utilisation(p_id);
  IF old_v.pays <> p_pays AND ((v_use ->> 'profils')::int > 0 OR (v_use ->> 'groupes')::int > 0) THEN
    RAISE EXCEPTION 'ville : utilisée par % profil(s) et % groupe(s), son pays ne change pas',
      v_use ->> 'profils', v_use ->> 'groupes' USING ERRCODE = '55000';
  END IF;

  IF old_v.nom <> btrim(p_nom) THEN
    v_changes := v_changes || jsonb_build_object('nom', jsonb_build_object('from', old_v.nom, 'to', btrim(p_nom)));
  END IF;
  IF old_v.pays <> p_pays THEN
    v_changes := v_changes || jsonb_build_object('pays', jsonb_build_object('from', old_v.pays, 'to', p_pays));
  END IF;
  IF old_v.region IS DISTINCT FROM nullif(btrim(coalesce(p_region, '')), '') THEN
    v_changes := v_changes || jsonb_build_object('region', jsonb_build_object('from', old_v.region, 'to', p_region));
  END IF;
  IF old_v.latitude <> p_lat OR old_v.longitude <> p_lon THEN
    v_changes := v_changes || jsonb_build_object('position', jsonb_build_object(
      'from', jsonb_build_array(old_v.latitude, old_v.longitude),
      'to', jsonb_build_array(p_lat, p_lon)));
  END IF;
  IF old_v.population <> p_population THEN
    v_changes := v_changes || jsonb_build_object('population', jsonb_build_object('from', old_v.population, 'to', p_population));
  END IF;
  IF old_v.alias_plies IS DISTINCT FROM v_alias THEN
    v_changes := v_changes || jsonb_build_object('alias_plies', jsonb_build_object('from', old_v.alias_plies, 'to', v_alias));
  END IF;

  UPDATE public.villes SET
    nom = btrim(p_nom), nom_plie = v_plie, pays = p_pays,
    region = nullif(btrim(coalesce(p_region, '')), ''),
    latitude = p_lat, longitude = p_lon, population = p_population, alias_plies = v_alias
   WHERE id = p_id;

  IF v_changes <> '{}'::jsonb THEN
    INSERT INTO public.referentiel_history (entity, entity_id, kind, actor_id, changes, reason)
    VALUES ('ville', p_id::text, 'updated', v_caller, v_changes, btrim(p_reason));
  END IF;
  PERFORM public.write_admin_audit('REFERENTIEL_VILLE_UPDATED', 'ville', p_id::text, 'success',
    NULL, p_id::text, jsonb_build_object('fields', (SELECT array_agg(k) FROM jsonb_object_keys(v_changes) k)));
  RETURN p_id;
END $$;

-- ── 5. Doublons possibles ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.villes_doublons_possibles(integer);

CREATE FUNCTION public.villes_doublons_possibles(p_limit integer DEFAULT 50)
RETURNS TABLE (id_a bigint, id_b bigint, nom_a text, nom_b text, pays text,
               distance_km numeric, usage_a jsonb, usage_b jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ville : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('geography.reference.manage');
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'ville : limite de 1 à 500' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT a.id, b.id, a.nom, b.nom, a.pays,
         round((2 * 6371 * asin(sqrt(
           power(sin(radians((b.latitude - a.latitude) / 2)), 2)
           + cos(radians(a.latitude)) * cos(radians(b.latitude))
             * power(sin(radians((b.longitude - a.longitude) / 2)), 2))))::numeric, 1),
         public.ville_utilisation(a.id), public.ville_utilisation(b.id)
    FROM public.villes a
    JOIN public.villes b ON b.nom_plie = a.nom_plie AND b.pays = a.pays AND b.id > a.id
   WHERE 2 * 6371 * asin(sqrt(
           power(sin(radians((b.latitude - a.latitude) / 2)), 2)
           + cos(radians(a.latitude)) * cos(radians(b.latitude))
             * power(sin(radians((b.longitude - a.longitude) / 2)), 2))) < 20
   ORDER BY 6, a.id
   LIMIT p_limit;
END $$;

-- ── 6. Fusionner deux villes ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.ville_admin_merge(bigint, bigint, text);

CREATE FUNCTION public.ville_admin_merge(p_keep bigint, p_drop bigint, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k        public.villes%ROWTYPE;
  d        public.villes%ROWTYPE;
  v_use    jsonb;
  v_alias  text[];
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ville : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('geography.reference.manage');

  IF p_keep IS NULL OR p_drop IS NULL OR p_keep = p_drop THEN
    RAISE EXCEPTION 'ville : deux villes différentes requises' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'ville : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;

  -- Toujours dans l'ordre des identifiants : deux fusions croisées ne se bloquent pas.
  PERFORM 1 FROM public.villes WHERE id IN (p_keep, p_drop) ORDER BY id FOR UPDATE;
  SELECT * INTO k FROM public.villes WHERE id = p_keep;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ville : ville conservée introuvable' USING ERRCODE = 'P0002';
  END IF;
  SELECT * INTO d FROM public.villes WHERE id = p_drop;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ville : ville retirée introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF k.pays <> d.pays THEN
    RAISE EXCEPTION 'ville : deux villes de pays différents ne fusionnent pas' USING ERRCODE = '22023';
  END IF;

  v_use := public.ville_utilisation(p_drop);
  IF (v_use ->> 'groupes')::int > 0 THEN
    RAISE EXCEPTION 'ville : la ville retirée porte % groupe(s), fusionner les groupes d''abord',
      v_use ->> 'groupes' USING ERRCODE = '55000';
  END IF;

  UPDATE public.users SET ville_id = p_keep WHERE ville_id = p_drop;
  UPDATE public.villes SET pole_id = NULL WHERE id = p_keep AND pole_id = p_drop;
  UPDATE public.villes SET pole_id = p_keep WHERE pole_id = p_drop AND id <> p_keep;

  SELECT coalesce(array_agg(DISTINCT a), '{}') INTO v_alias
    FROM unnest(k.alias_plies || d.alias_plies || ARRAY[d.nom_plie]) a
   WHERE a <> k.nom_plie;
  UPDATE public.villes SET
    alias_plies = v_alias,
    population = greatest(k.population, d.population)
   WHERE id = p_keep;

  INSERT INTO public.referentiel_history (entity, entity_id, kind, actor_id, changes, reason)
  VALUES ('ville', p_drop::text, 'merged', v_caller,
          jsonb_build_object('into', p_keep, 'nom', d.nom, 'geonames_id', d.geonames_id,
                             'profils_reportes', v_use ->> 'profils'),
          btrim(p_reason)),
         ('ville', p_keep::text, 'updated', v_caller,
          jsonb_build_object('absorbe', p_drop, 'alias_plies',
            jsonb_build_object('from', k.alias_plies, 'to', v_alias)),
          btrim(p_reason));

  DELETE FROM public.villes WHERE id = p_drop;

  PERFORM public.write_admin_audit('REFERENTIEL_VILLE_MERGED', 'ville', p_drop::text, 'success',
    NULL, p_drop::text, jsonb_build_object('into', p_keep, 'profils', v_use ->> 'profils'));
  RETURN 'merged';
END $$;

-- ── 7. Supprimer une ville inutilisée ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.ville_admin_delete(bigint, text);

CREATE FUNCTION public.ville_admin_delete(p_id bigint, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v        public.villes%ROWTYPE;
  v_use    jsonb;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ville : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('geography.reference.manage');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'ville : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v FROM public.villes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ville : introuvable' USING ERRCODE = 'P0002';
  END IF;
  v_use := public.ville_utilisation(p_id);
  IF (v_use ->> 'profils')::int > 0 OR (v_use ->> 'groupes')::int > 0 OR (v_use ->> 'poles')::int > 0 THEN
    RAISE EXCEPTION 'ville : utilisée (% profil(s), % groupe(s), % pôle(s)), fusionner plutôt que supprimer',
      v_use ->> 'profils', v_use ->> 'groupes', v_use ->> 'poles' USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.referentiel_history (entity, entity_id, kind, actor_id, changes, reason)
  VALUES ('ville', p_id::text, 'deleted', v_caller,
          jsonb_build_object('nom', v.nom, 'pays', v.pays, 'geonames_id', v.geonames_id),
          btrim(p_reason));
  DELETE FROM public.villes WHERE id = p_id;

  PERFORM public.write_admin_audit('REFERENTIEL_VILLE_DELETED', 'ville', p_id::text, 'success',
    NULL, p_id::text, '{}'::jsonb);
  RETURN 'deleted';
END $$;

-- ── 8. Ajouter un pays ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.pays_admin_add(text, text, text);

CREATE FUNCTION public.pays_admin_add(p_nom text, p_code text, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'pays : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('geography.reference.manage');

  IF p_nom IS NULL OR length(btrim(p_nom)) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'pays : nom requis (2 à 80 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_code IS NULL OR p_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'pays : code ISO à deux lettres majuscules requis' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'pays : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;

  BEGIN
    INSERT INTO public.pays (nom, code_iso_herite) VALUES (btrim(p_nom), p_code);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'pays : nom ou code déjà présent' USING ERRCODE = '55000';
  END;

  INSERT INTO public.referentiel_history (entity, entity_id, kind, actor_id, changes, reason)
  VALUES ('pays', btrim(p_nom), 'created', v_caller,
          jsonb_build_object('nom', btrim(p_nom), 'code', p_code), btrim(p_reason));
  PERFORM public.write_admin_audit('REFERENTIEL_PAYS_ADDED', 'pays', btrim(p_nom), 'success',
    NULL, btrim(p_nom), jsonb_build_object('code', p_code));
  RETURN 'added';
END $$;

-- ── 9. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.ville_admin_save(bigint, text, text, text, double precision, double precision, integer, text[], text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.villes_doublons_possibles(integer)      FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ville_admin_merge(bigint, bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ville_admin_delete(bigint, text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pays_admin_add(text, text, text)        FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ville_admin_save(bigint, text, text, text, double precision, double precision, integer, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.villes_doublons_possibles(integer)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.ville_admin_merge(bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ville_admin_delete(bigint, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.pays_admin_add(text, text, text)        TO authenticated;

NOTIFY pgrst, 'reload schema';
