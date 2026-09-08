-- =============================================================================
-- Coordonnees des postes diplomatiques : 21 fiches placables sur la carte
--
-- Les 32 fiches de l'annuaire sont arrivees sans latitude ni longitude :
-- diplomatie.gouv.ne ne publie que des adresses postales, dont huit sont de
-- simples boites postales. Consequence, invisible a la relecture : la carte
-- saute la fiche (`map_screen.dart`, « Skip embassies without valid
-- coordinates ») et le bouton « voir sur la carte » du detail reste masque
-- (`EmbassyEntity.hasCoordinates`). Depuis l'import, aucun poste n'a jamais
-- ete affiche sur la carte.
--
-- D'OU VIENNENT CES CHIFFRES. De deux sources publiques, croisees par
-- `tools/geocode_postes_diplomatiques.mjs` (rejouable, releve du 2026-09-08) :
--
--   * OpenStreetMap (Overpass, `country=NE`) pour 19 postes -- position au
--     batiment, relevee sur le terrain ;
--   * l'adresse officielle geocodee via Nominatim pour 2 postes (Paris/UNESCO
--     et Kano), quand OSM ne connait pas le poste mais que l'adresse est une
--     vraie rue.
--
-- Aucune valeur n'est inventee, et aucun centre-ville n'est ecrit comme s'il
-- etait une adresse : le centre-ville n'a servi que de garde-fou (un candidat
-- a plus de 60 km de sa ville est rejete). C'est la meme regle que le seed
-- d'origine -- « un champ douteux est laisse NULL plutot que devine ».
--
-- CE QUI N'EST PAS TRAITE. 11 postes restent sans coordonnees : Addis-Abeba,
-- Le Caire, Rabat, La Havane, Doha, Koweit, New Delhi, Djeddah, Dubai,
-- Khartoum, Pekin. Ils ne sont pas dans OSM, et leur adresse est soit une
-- boite postale, soit une voie qu'OSM ne connait pas. Ils restent visibles
-- dans l'annuaire avec leur adresse ; ils ne portent simplement pas de pin.
-- Addis-Abeba est un cas a part : OSM n'y cartographie que la RESIDENCE de
-- l'ambassadeur. Y envoyer un usager serait pire que de l'omettre.
--
-- TROIS ECARTS ASSUMES entre OSM et l'adresse publiee, tous en faveur d'OSM,
-- dont le noeud porte le nom du poste :
--   * Copenhague (5,1 km) : OSM place le poste Rosbaeksvej / Osterbro, quand
--     l'annuaire publie « Niels Juels Gade 5 ».
--   * Dakar (5,2 km) : OSM le place « Voie de Degagement Nord, Point E »,
--     l'annuaire « 8 avenue Leopold Sedar Senghor ».
--   * Riyad (10,4 km) : ecart sans objet, l'adresse publiee n'est qu'une
--     boite postale -- le geocodage retombait sur le centre-ville.
-- Ces deux premiers ecarts meritent une confirmation aupres du poste ; d'ici
-- la, la position OSM est la plus defendable des deux.
-- =============================================================================

UPDATE public.embassies AS e
SET    latitude  = c.lat,
       longitude = c.lon
FROM (VALUES
  -- Rome : Ambasciata del Niger (embassy, node/8197650456) ; adresse publiee a 0,07 km
  ('rome-ambassade', 41.913474, 12.460900),
  -- Copenhague : Nigers ambassade (embassy, way/919392775) ; adresse publiee a 5,1 km
  ('copenhague-ambassade', 55.722402, 12.573758),
  -- Tripoli : le noeud est nomme en arabe dans OSM (embassy, node/9032294389)
  ('tripoli-ambassade', 32.868841, 13.135106),
  -- Abidjan : Ambassade du Niger en Cote d'Ivoire (embassy, node/3957827413) ; adresse publiee a 0,38 km
  ('abidjan-ambassade', 5.308296, -3.994829),
  -- Abuja : Embassy of Niger (embassy, way/480411945)
  ('abuja-ambassade', 9.041019, 7.479344),
  -- Accra : Embassy of Niger (embassy, node/1390293430)
  ('accra-ambassade', 5.564325, -0.193963),
  -- Alger : le noeud est nomme en arabe dans OSM (embassy, node/2963379785)
  ('alger-ambassade', 36.775935, 3.010507),
  -- Cotonou : Ambassade du Niger a Cotonou (embassy, node/7684794072)
  ('cotonou-ambassade', 6.352522, 2.435454),
  -- Dakar : Niger Embassy (embassy, node/6836421286) ; adresse publiee a 5,2 km
  ('dakar-ambassade', 14.698142, -17.468305),
  -- Lome : Ambassade du Niger (embassy, way/182197845) ; adresse publiee a 0,24 km
  ('lome-ambassade', 6.142128, 1.208256),
  -- Pretoria : Embassy of Niger (embassy, way/937268926)
  ('pretoria-ambassade', -25.743448, 28.220634),
  -- Ankara : Nijer Buyukelciligi (embassy, way/228548713)
  ('ankara-ambassade', 39.890526, 32.874202),
  -- Berlin : Botschaft der Republik Niger (embassy, way/165814997) ; adresse publiee a 0 km
  ('berlin-ambassade', 52.426639, 13.253449),
  -- Bruxelles : Ambassade du Niger - Ambassade van Niger (embassy, node/13443472900) ; adresse publiee a 0,01 km
  ('bruxelles-ambassade', 50.809841, 4.383609),
  -- Paris : Ambassade du Niger (embassy, way/80897207) ; adresse publiee a 0,01 km
  ('paris-ambassade', 48.868389, 2.275326),
  -- Washington DC : Embassy of Niger (embassy, way/261634172) ; adresse publiee a 0 km
  ('washington-ambassade', 38.912379, -77.049181),
  -- Riyad : le noeud est nomme en arabe dans OSM (embassy, way/716755830) ;
  -- l'ecart de 10,42 km est sans objet, l'adresse publiee est une boite postale
  ('riyad-ambassade', 24.724452, 46.673971),
  -- Geneve : Ambassade, mission permanente du Niger (embassy, node/13617247433) ; adresse publiee a 0,02 km
  ('geneve-mission', 46.219957, 6.143939),
  -- New York : Permanent Mission of Niger to the United Nations (embassy, way/265458959) ; adresse publiee a 0 km
  ('new-york-mission', 40.753752, -73.965353),
  -- Paris : adresse officielle geocodee -- UNESCO Miollis, 1, Rue Miollis, Quartier Necker, Paris 
  ('paris-unesco-mission', 48.845214, 2.306747),
  -- Kano : adresse officielle geocodee -- Katsina Road, Fagge D2, Fagge, Etat de Kano, 700271, Ni
  ('kano-consulat', 12.025077, 8.516525)
) AS c(slug, lat, lon)
WHERE  e.slug = c.slug;
