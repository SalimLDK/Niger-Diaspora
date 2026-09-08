-- =============================================================================
-- Coordonnees des postes diplomatiques (2) : 9 postes de plus, et Abuja corrige
--
-- La migration precedente en avait place 21 sur 32 avec les seules sources
-- ouvertes. Les 11 restants n'etaient ni dans OpenStreetMap, ni geocodables
-- depuis leur adresse -- huit d'entre eux ne publient qu'une boite postale.
-- La Geocoding API de Google, activee depuis, les situe presque tous.
--
-- CE QUI A FAIT LA DIFFERENCE : chercher le poste par SON NOM, dans la langue
-- du pays d'accueil. Le Caire ne repond qu'a l'arabe (« سفارة النيجر »), La
-- Havane qu'a l'espagnol ; l'anglais couvre le reste, le francais presque
-- rien. Et le resultat obtenu par le nom vaut mieux que celui obtenu par
-- l'adresse : a Addis-Abeba, « Kirkos Sub-city, Kebele 02/03 » rend un point
-- quelconque du quartier, a 5,7 km de la chancellerie que Google connait
-- comme un lieu de type `embassy`.
--
-- LE CRITERE RETENU, pour ne rien ecrire qu'on ne puisse defendre : Google
-- doit rendre un lieu typé `embassy`, ou une adresse qui recoupe l'annuaire
-- officiel. Un resultat `APPROXIMATE`, ou qui n'est qu'une « locality »,
-- est un centre-ville deguise et n'est jamais ecrit. Trois recoupements
-- valent confirmation :
--   * Le Caire : Google rend « 101 Al Haram » -- c'est exactement l'adresse
--     publiee, l'avenue des Pyramides a Guizeh ;
--   * Rabat : « Av. Al Haour » -- l'adresse publiee, secteur 7 de Hay Riad ;
--   * Dubai : « Abu Hail, Deira » -- l'annuaire ecrit « Abau Hain Street,
--     Deira », soit la meme rue mal transcrite.
--
-- DEUX POSTES RESTENT SANS PIN, et c'est deliberé :
--   * Khartoum : aucune source ne le connait. Google ne rend que le centre
--     de la ville, l'annuaire n'a qu'une boite postale.
--   * Djeddah : le seul resultat (« قنصلية النيجر », a Al Kausar, 22 km au
--     nord du centre) n'est PAS typé `embassy` par Google, contrairement aux
--     neuf ci-dessous. Une position fausse enverrait l'usager a 22 km ; la
--     fiche reste consultable sans pin, avec sa boite postale. A confirmer
--     aupres du poste.
-- =============================================================================

UPDATE public.embassies AS e
SET    latitude  = c.lat,
       longitude = c.lon
FROM (VALUES
  -- Addis-Abeba : POI type embassy, rooftop -- XQV5+9X6, Addis-Abeba, Ethiopie
  ('addis-abeba-ambassade', 8.993415, 38.759887),
  -- Le Caire : POI type embassy, rooftop -- 101 Al Haram, Nazlet El-Semman, El Omraniya, Giza Governor
  ('le-caire-ambassade', 29.987313, 31.143414),
  -- Rabat : POI type embassy, rooftop -- X49M+2Q8, Av. Al Haour, Rabat, Maroc
  ('rabat-ambassade', 33.967527, -6.865552),
  -- La Havane : POI type embassy, rooftop -- 4H78+FWP, La Havane, Cuba
  ('la-havane-ambassade', 23.113705, -82.432681),
  -- Doha : POI type embassy, geometric_center -- hizam el murkhya st. 544 zone 67,, Qatar
  ('doha-ambassade', 25.339001, 51.489480),
  -- Koweit : POI type embassy, rooftop -- 25 6 St, Koweit
  ('koweit-ambassade', 29.276712, 48.083539),
  -- New Delhi : POI type embassy, rooftop -- 22, F 8 St, Block F, Vasant Vihar, New Delhi, Delhi 110057
  ('new-delhi-ambassade', 28.558582, 77.158660),
  -- Dubai : POI type embassy, rooftop -- 46 14th St - Abu Hail - Deira - Dubai - Emirats arabes uni
  ('dubai-consulat', 25.289979, 55.330214),
  -- Pekin : POI type embassy, rooftop -- WFM5+MCP, Gong Ren Ti Yu Chang Bei Lu, Chao Yang Qu, Bei J
  ('pekin-ambassade', 39.934203, 116.458567)
) AS c(slug, lat, lon)
WHERE  e.slug = c.slug;

-- Abuja : le pin etait a 5,7 km de la chancellerie ------------------------
--
-- La migration precedente avait pris le noeud OpenStreetMap « Embassy of
-- Niger, 305 Diplomatic Drive », dans le quartier des affaires. Deux sources
-- independantes le contredisent : l'annuaire officiel publie « Plot 933 Pope
-- John Paul II Street, MAITAMA District », et Google situe un lieu typé
-- `embassy` a Maitama. Le noeud OSM decrit vraisemblablement une adresse
-- anterieure. On retient Maitama, ou les deux se rejoignent.
UPDATE public.embassies
SET    latitude = 9.091678, longitude = 7.488118
WHERE  slug = 'abuja-ambassade';

-- Dakar et Pretoria, eux, sont CONFIRMES sur leur position OpenStreetMap ---
--
-- Leur adresse publiee tombait a 5,2 km et 2,4 km du noeud OSM, ce qui restait
-- ouvert apres la premiere migration. Google y rend un lieu typé `embassy` a
-- 7 m et 14 m du noeud : c'est l'annuaire officiel qui est en retard, pas la
-- carte. Rien a changer -- la remarque est ici pour que la question ne soit
-- pas rouverte une troisieme fois.
--
-- Reste ouvert : Copenhague, ou le noeud OSM (Rosbaeksvej, Osterbro) et
-- l'adresse publiee (Niels Juels Gade 5) sont a 5,1 km, sans que Google ne
-- departage -- il n'y connait aucun lieu typé `embassy`.
