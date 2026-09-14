-- Référentiel des villes, sur le modèle de `pays` (20260913030000).
--
-- POURQUOI
-- Le champ ville du profil est un champ de texte nu
-- (`edit_profile_screen.dart`, `CustomTextField(_currentCityController)`).
-- Relevé en base le 2026-09-13, sur les neuf profils qui portent une ville :
--
--   Niamey ×3 (Niger)      niamey ×1 (Niger)      ← déjà deux écritures
--   Bouza ×1 (Niger)       Djelfa ×1 (Algérie)
--   Arewa ×1 (Niger)       ← un département, pas une ville
--   Almoustapha ×1 (Niger) ← un prénom
--   Montréal ×1 (pays nul)
--   test.diaspo@example.com ×1 (Angola)
--
-- Ouvrir des groupes de ville à partir de ce texte donnerait
-- « Diaspora Niger — niamey » à côté de « — Niamey », et un groupe
-- « — Almoustapha ». C'est exactement ce que les codes ISO viennent de coûter
-- sur les pays, en pire : les villes n'ont pas de liste fermée côté app.
--
-- D'où une liste de référence, et le même contrat que pour les pays : la
-- colonne texte reste (« Autre ville », saisie libre), mais ce qui ouvre un
-- groupe est un `ville_id` qui pointe ici.
--
-- CE QUE CETTE MIGRATION FAIT, ET PAS PLUS
-- Elle crée la table vide et ses fonctions de lecture. Le contenu vient de
-- `tools/import_villes_geonames.mjs` : environ 25 000 villes, soit ~3 Mo de
-- SQL qu'on ne met pas dans le dépôt. Les étapes suivantes (`users.ville_id`,
-- `groups.ville_id`, la reprise des profils) sont des migrations à part.
--
-- LES DEUX SOURCES, ET POURQUOI DEUX
-- GeoNames `cities15000` (CC-BY, mention à porter dans « À propos ») couvre
-- le monde à partir de 15 000 habitants. Elle ne suffit pas pour le Niger :
-- Bouza (~11 000 habitants), portée par un profil existant, en est absente.
-- Le Niger vient donc des 48 villes de `ProfileOptions.nigerRegions` — la
-- liste que `origin_city` utilise déjà — relevées dans le fichier GeoNames du
-- pays. Une seule table, deux sources à l'import.
--
-- Le code pays GeoNames ne sert qu'à l'import, pour trouver le pays via
-- `pays.code_iso_herite`. Aucun code ISO n'est stocké ici : la colonne `pays`
-- porte le nom en toutes lettres, et la clé étrangère empêche la base
-- elle-même de rattacher une ville au mauvais pays.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. La table.
--    `nom_plie` et `alias_plies` sont écrits par l'import, pas calculés par
--    une colonne générée : une colonne générée figerait `plier_nom_de_pays`
--    (la remplacer ne recalculerait rien, en silence). L'import est le seul
--    écrivain ; qu'il porte la règle de pliage est plus honnête.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.villes (
  id          bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  nom         text NOT NULL,
  nom_plie    text NOT NULL,
  pays        text NOT NULL REFERENCES public.pays(nom) ON UPDATE CASCADE,
  region      text,
  latitude    double precision NOT NULL,
  longitude   double precision NOT NULL,
  population  integer NOT NULL DEFAULT 0,
  geonames_id integer UNIQUE,
  alias_plies text[] NOT NULL DEFAULT '{}',
  pole_id     bigint REFERENCES public.villes(id) ON DELETE SET NULL,
  CONSTRAINT villes_latitude_valide  CHECK (latitude  BETWEEN -90  AND 90),
  CONSTRAINT villes_longitude_valide CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT villes_pas_son_propre_pole CHECK (pole_id IS DISTINCT FROM id)
);

COMMENT ON TABLE public.villes IS
  'Villes de référence. Source : GeoNames cities15000 (CC-BY) pour le monde, ProfileOptions.nigerRegions pour le Niger. Peuplée par tools/import_villes_geonames.mjs, jamais par une migration.';
COMMENT ON COLUMN public.villes.nom IS
  'Nom affiché, en français quand un exonyme existe (Londres, Le Caire). Sinon le nom GeoNames.';
COMMENT ON COLUMN public.villes.nom_plie IS
  'plier_nom_de_pays(nom). Écrit par l''import — si la règle de pliage change, relancer l''import.';
COMMENT ON COLUMN public.villes.alias_plies IS
  'Autres écritures reconnues à la recherche, DÉJÀ PLIÉES (London pour Londres, Peking pour Pékin). Jamais affichées.';
COMMENT ON COLUMN public.villes.geonames_id IS
  'Identifiant GeoNames. Clé de rapprochement de l''import. NULL pour une ville ajoutée à la main.';
COMMENT ON COLUMN public.villes.pole_id IS
  'Grande ville dont celle-ci est une banlieue (Laval → Montréal). Calculé à l''import : plus grande ville à moins de 40 km, dans le même pays, au moins 3× plus peuplée. Réglable à la main ensuite.';

-- Recherche « Mont… » dans un pays : `text_pattern_ops` sert le LIKE ancré à
-- gauche, que l'opérateur par défaut n'indexe pas hors collation C.
CREATE INDEX IF NOT EXISTS villes_pays_nom_plie
  ON public.villes (pays, nom_plie text_pattern_ops);
CREATE INDEX IF NOT EXISTS villes_pays_population
  ON public.villes (pays, population DESC);
CREATE INDEX IF NOT EXISTS villes_alias_plies
  ON public.villes USING gin (alias_plies);
-- Ville la plus proche de coordonnées : le filtre est une boîte lat/lon.
CREATE INDEX IF NOT EXISTS villes_coordonnees
  ON public.villes (latitude, longitude);
CREATE INDEX IF NOT EXISTS villes_pole
  ON public.villes (pole_id) WHERE pole_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Lecture. `authenticated` seulement : le seul lecteur est l'éditeur de
--    profil, et la cartographie des accès anon (soldée le 2026-09) va vers le
--    retrait des droits `anon` sur les tables, pas vers un de plus. `pays`
--    reste ouvert à anon parce qu'il l'était déjà.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.villes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS villes_lecture ON public.villes;
CREATE POLICY villes_lecture ON public.villes
  FOR SELECT TO authenticated USING (true);

-- ─────────────────────────────────────────────────────────────────────────
-- 3. La recherche du champ ville : « Mont… » dans le pays choisi.
--    Le nom d'abord, les alias ensuite, puis la population décroissante —
--    « Mont » doit donner Montréal avant Montauban.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rechercher_villes(
  p_pays   text,
  p_texte  text,
  p_limite integer DEFAULT 20
)
RETURNS SETOF public.villes
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH q AS (
    SELECT public.plier_nom_de_pays(p_texte) AS t,
           public.pays_canonique(p_pays)     AS pays
  )
  SELECT v.*
    FROM public.villes v, q
   WHERE (q.pays IS NULL OR v.pays = q.pays)
     AND (
       q.t = '' OR
       v.nom_plie LIKE q.t || '%' OR
       EXISTS (SELECT 1 FROM unnest(v.alias_plies) a WHERE a LIKE q.t || '%')
     )
   ORDER BY (v.nom_plie LIKE q.t || '%') DESC,
            v.population DESC,
            v.nom
   LIMIT GREATEST(1, LEAST(COALESCE(p_limite, 20), 50));
$$;

COMMENT ON FUNCTION public.rechercher_villes(text, text, integer) IS
  'Villes d''un pays dont le nom ou un alias commence par le texte saisi. Texte vide = les plus peuplées du pays. Pays inconnu ou NULL = recherche mondiale.';

-- ─────────────────────────────────────────────────────────────────────────
-- 4. « Vous êtes à Montréal ? » : la ville de la liste la plus proche des
--    coordonnées du téléphone. On ne retient jamais le texte que renvoie le
--    géocodage de l'appareil — c'est lui qui produirait « Almoustapha ».
--
--    Pas de PostGIS : haversine, après un filtre en boîte qui seul touche
--    l'index. La boîte est élargie en longitude par la latitude (un degré de
--    longitude vaut moins d'un kilomètre près des pôles).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ville_la_plus_proche(
  p_latitude  double precision,
  p_longitude double precision,
  p_rayon_km  double precision DEFAULT 50
)
RETURNS SETOF public.villes
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH b AS (
    SELECT LEAST(GREATEST(COALESCE(p_rayon_km, 50), 1), 500) AS rayon
  ), boite AS (
    SELECT b.rayon,
           b.rayon / 111.0 AS d_lat,
           b.rayon / GREATEST(111.0 * cos(radians(p_latitude)), 0.1) AS d_lon
      FROM b
  )
  SELECT v.*
    FROM public.villes v, boite
   WHERE p_latitude IS NOT NULL
     AND p_longitude IS NOT NULL
     AND v.latitude  BETWEEN p_latitude  - boite.d_lat AND p_latitude  + boite.d_lat
     AND v.longitude BETWEEN p_longitude - boite.d_lon AND p_longitude + boite.d_lon
     AND 6371 * acos(LEAST(1, GREATEST(-1,
           sin(radians(p_latitude)) * sin(radians(v.latitude)) +
           cos(radians(p_latitude)) * cos(radians(v.latitude)) *
           cos(radians(v.longitude - p_longitude))
         ))) <= boite.rayon
   ORDER BY 6371 * acos(LEAST(1, GREATEST(-1,
              sin(radians(p_latitude)) * sin(radians(v.latitude)) +
              cos(radians(p_latitude)) * cos(radians(v.latitude)) *
              cos(radians(v.longitude - p_longitude))
            )))
   LIMIT 1;
$$;

COMMENT ON FUNCTION public.ville_la_plus_proche(double precision, double precision, double precision) IS
  'Ville de référence la plus proche de coordonnées, dans un rayon (50 km par défaut, 500 au plus). Aucune ligne si rien dans le rayon.';

-- `REVOKE ... FROM PUBLIC` ne suffit pas : Supabase accorde EXECUTE à `anon`
-- nommément sur toute nouvelle fonction de `public` (voir 20260910070000).
REVOKE ALL ON FUNCTION public.rechercher_villes(text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rechercher_villes(text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.rechercher_villes(text, text, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.ville_la_plus_proche(double precision, double precision, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ville_la_plus_proche(double precision, double precision, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.ville_la_plus_proche(double precision, double precision, double precision) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. L'import écrit avec les droits du propriétaire (supabase db query).
--    Aucune policy d'écriture : ni `anon` ni `authenticated` ne touchent à
--    cette table.
-- ─────────────────────────────────────────────────────────────────────────
GRANT SELECT ON public.villes TO authenticated;
