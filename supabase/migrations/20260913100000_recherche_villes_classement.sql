-- Classement de `rechercher_villes` : la population avant la nature de la
-- correspondance.
--
-- La première version rangeait les correspondances sur le NOM avant celles
-- sur un ALIAS, la population ne départageant qu'à l'intérieur de chaque
-- groupe. Vérifié sur la base peuplée le 2026-09-13 : « london » au
-- Royaume-Uni donnait
--
--   Londonderry County Borough (83 000), Londres (8 900 000), Brent
--
-- parce que le nom plié de Londres est « londres », qui ne commence pas par
-- « london » — la ville n'est trouvée que par son alias, et se retrouvait
-- derrière une petite ville dont le nom, lui, commence bien par « london ».
--
-- Le classement ne garde donc qu'un seul cran au-dessus de la population :
-- la correspondance EXACTE, nom ou alias. « londres » et « london » mettent
-- tous deux Londres en tête ; « mont » au Canada donne toujours Montréal,
-- qui n'a jamais eu besoin de ce cran (1,7 M).
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
   ORDER BY (q.t <> '' AND (v.nom_plie = q.t OR q.t = ANY (v.alias_plies))) DESC,
            v.population DESC,
            v.nom
   LIMIT GREATEST(1, LEAST(COALESCE(p_limite, 20), 50));
$$;

COMMENT ON FUNCTION public.rechercher_villes(text, text, integer) IS
  'Villes d''un pays dont le nom ou un alias commence par le texte saisi, la plus peuplée d''abord, une correspondance exacte avant tout. Texte vide = les plus peuplées du pays. Pays inconnu ou NULL = recherche mondiale ; un code ISO hérité (« CA ») est accepté, pays_canonique le ramène au nom.';
