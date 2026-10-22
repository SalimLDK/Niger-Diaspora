-- Banc : référentiel géographique (migration 20261019180000).
--
--   supabase db query --linked -f tools/rls_tests/referentiel_geographique.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'une ville fausse ou dupliquée s'installe,
-- qu'une ville utilisée par un profil ou un groupe change de pays, disparaisse
-- ou soit fusionnée sans reporter ses dépendances ; qu'on écrive le référentiel
-- sans passer par les fonctions ; et que l'historique se réécrive. Les pays et
-- les villes réels ne sont jamais touchés : tout est dans un pays fictif.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE ids(k text, v bigint);
GRANT ALL ON ids TO anon, authenticated;

CREATE FUNCTION pg_temp.essai(n int, cas text, attendu text, q text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE obtenu text;
BEGIN
  EXECUTE q;
  obtenu := 'OK';
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN obtenu = attendu THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (n, cas, attendu, SQLSTATE,
    CASE WHEN SQLSTATE = attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $f$;

CREATE FUNCTION pg_temp.moi(uid text) RETURNS void
LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true)
$f$;

CREATE FUNCTION pg_temp.verifie(n int, cas text, attendu text, obtenu text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN attendu = obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-geo-super',   'Super',   'geo-super@banc.test',   true,  'superAdmin'),
  ('banc-geo-biz',     'BizMod',  'geo-biz@banc.test',     true,  'businessMod'),
  ('banc-geo-content', 'Content', 'geo-content@banc.test', true,  'contentMod'),
  ('banc-geo-ordi',    'Ordi',    'geo-ordi@banc.test',    false, NULL),
  ('banc-geo-u1',      'Membre',  'geo-u1@banc.test',      false, NULL);

INSERT INTO public.pays (nom, code_iso_herite) VALUES ('Banclandie', 'ZB'), ('Autrelandie', 'ZC');

-- Villes d'essai posées par le propriétaire (le chemin d'import).
INSERT INTO public.villes (id, nom, nom_plie, pays, latitude, longitude, population) OVERRIDING SYSTEM VALUE VALUES
  (990001, 'Tamara',  'tamara',  'Banclandie', 10.0, 10.0, 1000),
  (990002, 'Tamara',  'tamara',  'Banclandie', 10.05, 10.05, 4000),    -- doublon (≈ 7 km)
  (990003, 'Tamara',  'tamara',  'Banclandie', 15.0, 15.0, 500),       -- homonyme lointain
  (990004, 'Utilisee','utilisee','Banclandie', 11.0, 11.0, 100),
  (990005, 'Inutile', 'inutile', 'Banclandie', 12.0, 12.0, 100),
  (990006, 'Autre',   'autre',   'Autrelandie', 20.0, 20.0, 100);
UPDATE public.villes SET pole_id = 990002 WHERE id = 990003;
UPDATE public.users SET ville_id = 990002 WHERE id = 'banc-geo-u1';
SELECT pg_temp.moi('banc-geo-u1');  -- le déclencheur du créateur de groupe lit la session
INSERT INTO public.groups (id, name, creator_id, ville_id) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'Groupe de banc', 'banc-geo-u1', 990004);

-- ═══ 1. Droits ═════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'permission au catalogue, mappée à aucun rôle', '1/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key = 'geography.reference.manage') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission = 'geography.reference.manage'));
SELECT pg_temp.verifie(2, 'plus aucun droit d''écriture ni TRUNCATE pour anon et authenticated ; la lecture reste', 'false/true',
  (has_table_privilege('anon', 'public.villes', 'INSERT') OR has_table_privilege('anon', 'public.villes', 'UPDATE')
   OR has_table_privilege('anon', 'public.villes', 'DELETE') OR has_table_privilege('anon', 'public.villes', 'TRUNCATE')
   OR has_table_privilege('authenticated', 'public.villes', 'INSERT') OR has_table_privilege('authenticated', 'public.villes', 'TRUNCATE')
   OR has_table_privilege('authenticated', 'public.pays', 'INSERT') OR has_table_privilege('authenticated', 'public.pays', 'TRUNCATE')
   OR has_table_privilege('anon', 'public.pays', 'UPDATE'))::text || '/' ||
  (has_table_privilege('anon', 'public.villes', 'SELECT') AND has_table_privilege('authenticated', 'public.pays', 'SELECT'))::text);
SELECT pg_temp.verifie(3, 'anon n''exécute aucune des cinq fonctions ; l''aide interne est fermée', 'false',
  (has_function_privilege('anon', 'public.ville_admin_save(bigint,text,text,text,double precision,double precision,integer,text[],text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.villes_doublons_possibles(integer)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.ville_admin_merge(bigint,bigint,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.ville_admin_delete(bigint,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.pays_admin_add(text,text,text)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'public.ville_utilisation(bigint)', 'EXECUTE'))::text);

-- ═══ 2. Refus ══════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : créer une ville REFUSÉ', '42501',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 1, 1, 10, NULL, 'Ajout d''essai')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-geo-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'businessMod : créer une ville REFUSÉ (superAdmin seul)', '42501',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 1, 1, 10, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(12, 'businessMod : fusionner REFUSÉ', '42501',
  $q$SELECT public.ville_admin_merge(990001, 990002, 'Doublon évident')$q$);
SELECT pg_temp.essai(13, 'businessMod : lire les doublons REFUSÉ', '42501',
  $q$SELECT * FROM public.villes_doublons_possibles(10)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(14, 'superAdmin : UPDATE direct de villes REFUSÉ (droit retiré)', '42501',
  $q$UPDATE public.villes SET population = 1 WHERE id = 990001$q$);
SELECT pg_temp.essai(15, 'superAdmin : DELETE direct de villes REFUSÉ', '42501',
  $q$DELETE FROM public.villes WHERE id = 990005$q$);
SELECT pg_temp.essai(16, 'superAdmin : INSERT direct dans pays REFUSÉ', '42501',
  $q$INSERT INTO public.pays (nom, code_iso_herite) VALUES ('Fauxpays', 'ZZ')$q$);
RESET ROLE;

-- ═══ 3. Créer / modifier ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'nom trop court → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'A', 'Banclandie', NULL, 1, 1, 10, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(21, 'pays inconnu → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Pays inventé', NULL, 1, 1, 10, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(22, 'latitude 95 → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 95, 1, 10, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(23, 'population négative → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 1, 1, -5, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(24, 'sans motif → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 1, 1, 10, NULL, '')$q$);
SELECT pg_temp.essai(25, '21 alias → 22023', '22023',
  $q$SELECT public.ville_admin_save(NULL, 'Nouvelle', 'Banclandie', NULL, 1, 1, 10, (SELECT array_agg('a' || g) FROM generate_series(1, 21) g), 'Ajout d''essai')$q$);
SELECT pg_temp.essai(26, 'même nom plié à 3 km d''une ville existante → 55000 (doublon)', '55000',
  $q$SELECT public.ville_admin_save(NULL, 'TAMARA', 'Banclandie', NULL, 10.02, 10.02, 10, NULL, 'Ajout d''essai')$q$);
SELECT pg_temp.essai(27, 'crée une ville accentuée avec alias', 'OK',
  $q$INSERT INTO ids SELECT 'n1', public.ville_admin_save(NULL, 'Ségou-Nord', 'Banclandie', 'Région B', 5, 5, 2500, ARRAY['Segu Nord', 'SEGOU NORD'], 'Ville oubliée par l''import')$q$);
SELECT pg_temp.essai(28, 'même nom que la précédente mais à 800 km (homonyme légitime)', 'OK',
  $q$SELECT public.ville_admin_save(NULL, 'Ségou-Nord', 'Banclandie', NULL, 12, 5, 100, NULL, 'Homonyme lointain')$q$);
RESET ROLE;

SELECT pg_temp.verifie(29, 'nom plié par la MÊME fonction que l''application ; alias pliés, sans doublon ni le nom lui-même', 'true/{"segu nord"}',
  (SELECT (nom_plie = public.plier_nom_de_pays('Ségou-Nord'))::text || '/' || alias_plies::text
     FROM public.villes WHERE id = (SELECT v FROM ids WHERE k = 'n1')));

SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'modifie la population et la région', 'OK',
  $q$SELECT public.ville_admin_save((SELECT v FROM ids WHERE k = 'n1'), 'Ségou-Nord', 'Banclandie', 'Région C', 5, 5, 3000, ARRAY['Segu Nord'], 'Recensement')$q$);
SELECT pg_temp.essai(31, 'ville introuvable → P0002', 'P0002',
  $q$SELECT public.ville_admin_save(999999, 'Fantôme', 'Banclandie', NULL, 1, 1, 10, NULL, 'Essai')$q$);
SELECT pg_temp.essai(32, 'changer le pays d''une ville UTILISÉE par un profil → 55000', '55000',
  $q$SELECT public.ville_admin_save(990002, 'Tamara', 'Autrelandie', NULL, 10.05, 10.05, 4000, NULL, 'Mauvais pays')$q$);
SELECT pg_temp.essai(33, 'changer le pays d''une ville portant un groupe → 55000', '55000',
  $q$SELECT public.ville_admin_save(990004, 'Utilisee', 'Autrelandie', NULL, 11, 11, 100, NULL, 'Mauvais pays')$q$);
SELECT pg_temp.essai(34, 'changer le pays d''une ville INUTILISÉE', 'OK',
  $q$SELECT public.ville_admin_save(990005, 'Inutile', 'Autrelandie', NULL, 12, 12, 100, NULL, 'Mauvais pays')$q$);
RESET ROLE;

SELECT pg_temp.verifie(35, 'historique du changement : région et population, ancienne et nouvelle valeur', 'true/true/3000',
  (SELECT (changes ? 'region')::text || '/' || (changes ? 'population')::text || '/' || (changes -> 'population' ->> 'to')
     FROM public.referentiel_history WHERE entity = 'ville' AND entity_id = (SELECT v::text FROM ids WHERE k = 'n1') AND kind = 'updated'));

-- ═══ 4. Doublons ═══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(40, 'le doublon Tamara (≈ 7 km) est listé, avec ses dépendances ; l''homonyme lointain ne l''est pas', '1/990001/990002/1',
  (SELECT count(*) || '/' || min(id_a) || '/' || min(id_b) || '/' || min((usage_b ->> 'profils')::int)
     FROM public.villes_doublons_possibles(500) WHERE pays = 'Banclandie' AND nom_a = 'Tamara'));
RESET ROLE;

-- ═══ 5. Fusion ═════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'fusion de deux villes de pays différents → 22023', '22023',
  $q$SELECT public.ville_admin_merge(990001, 990006, 'Essai')$q$);
SELECT pg_temp.essai(51, 'fusion sans motif → 22023', '22023',
  $q$SELECT public.ville_admin_merge(990001, 990002, '')$q$);
SELECT pg_temp.essai(52, 'fusionner une ville sur elle-même → 22023', '22023',
  $q$SELECT public.ville_admin_merge(990001, 990001, 'Essai de banc')$q$);
SELECT pg_temp.essai(53, 'fusionner une ville qui PORTE un groupe → 55000', '55000',
  $q$SELECT public.ville_admin_merge(990001, 990004, 'Essai de banc')$q$);
SELECT pg_temp.essai(54, 'ville retirée introuvable → P0002', 'P0002',
  $q$SELECT public.ville_admin_merge(990001, 999998, 'Essai de banc')$q$);
SELECT pg_temp.essai(55, 'fusionne 990002 dans 990001', 'OK',
  $q$SELECT public.ville_admin_merge(990001, 990002, 'Doublon à 7 km, même nom')$q$);
RESET ROLE;

SELECT pg_temp.verifie(56, 'la ville retirée a disparu ; le profil et le pôle sont reportés', '0/990001/990001',
  (SELECT (SELECT count(*) FROM public.villes WHERE id = 990002) || '/' ||
          (SELECT ville_id FROM public.users WHERE id = 'banc-geo-u1') || '/' ||
          (SELECT pole_id FROM public.villes WHERE id = 990003)));
SELECT pg_temp.verifie(57, 'population = la plus grande ; le nom plié de la ville retirée n''est pas en double dans les alias', '4000/{}',
  (SELECT population || '/' || alias_plies::text FROM public.villes WHERE id = 990001));
SELECT pg_temp.verifie(58, 'historique de la fusion : ville retirée (merged, geonames_id tracé) + ville conservée', '1/1',
  (SELECT count(*) FILTER (WHERE entity_id = '990002' AND kind = 'merged' AND changes ? 'geonames_id') || '/' ||
          count(*) FILTER (WHERE entity_id = '990001' AND kind = 'updated' AND changes ? 'absorbe')
     FROM public.referentiel_history));

-- ═══ 6. Supprimer ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'supprimer une ville utilisée par un profil → 55000', '55000',
  $q$SELECT public.ville_admin_delete(990001, 'Essai de banc')$q$);
SELECT pg_temp.essai(61, 'supprimer une ville qui porte un groupe → 55000', '55000',
  $q$SELECT public.ville_admin_delete(990004, 'Essai de banc')$q$);
SELECT pg_temp.essai(62, 'supprimer sans motif → 22023', '22023',
  $q$SELECT public.ville_admin_delete(990005, '')$q$);
SELECT pg_temp.essai(63, 'supprime une ville inutilisée', 'OK',
  $q$SELECT public.ville_admin_delete(990005, 'Créée par erreur')$q$);
SELECT pg_temp.essai(64, 'supprimer de nouveau → P0002', 'P0002',
  $q$SELECT public.ville_admin_delete(990005, 'Créée par erreur')$q$);
RESET ROLE;

-- ═══ 7. Pays ═══════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'code ISO à trois lettres → 22023', '22023',
  $q$SELECT public.pays_admin_add('Troisièmeland', 'ZZZ', 'Nouveau pays')$q$);
SELECT pg_temp.essai(71, 'code ISO en minuscules → 22023', '22023',
  $q$SELECT public.pays_admin_add('Troisièmeland', 'zz', 'Nouveau pays')$q$);
SELECT pg_temp.essai(72, 'code déjà pris → 55000', '55000',
  $q$SELECT public.pays_admin_add('Troisièmeland', 'ZB', 'Nouveau pays')$q$);
SELECT pg_temp.essai(73, 'nom déjà pris → 55000', '55000',
  $q$SELECT public.pays_admin_add('Banclandie', 'ZD', 'Nouveau pays')$q$);
SELECT pg_temp.essai(74, 'ajoute un pays', 'OK',
  $q$SELECT public.pays_admin_add('Troisièmeland', 'ZD', 'Pays absent du référentiel')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-geo-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(75, 'contentMod : ajouter un pays REFUSÉ', '42501',
  $q$SELECT public.pays_admin_add('Quatrièmeland', 'ZE', 'Nouveau pays')$q$);
RESET ROLE;

-- ═══ 8. Historique et audit ════════════════════════════════════════════════
SELECT pg_temp.moi('banc-geo-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(80, 'businessMod ne lit pas l''historique du référentiel', '0',
  (SELECT count(*)::text FROM public.referentiel_history));
RESET ROLE;
SELECT pg_temp.moi('banc-geo-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(81, 'superAdmin le lit', 'true', ((SELECT count(*) FROM public.referentiel_history) >= 6)::text);
RESET ROLE;
SELECT pg_temp.essai(82, 'UPDATE de l''historique REFUSÉ (même pour le propriétaire)', '42501',
  $q$UPDATE public.referentiel_history SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(83, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.referentiel_history$q$);
SELECT pg_temp.verifie(84, 'audit : 2 créations, 3 modifications (2 + 1 fusion), 1 fusion, 1 suppression, 1 pays ; refus sans trace', '2/3/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'REFERENTIEL_VILLE_CREATED') || '/' ||
          count(*) FILTER (WHERE action = 'REFERENTIEL_VILLE_UPDATED' OR action = 'REFERENTIEL_VILLE_MERGED') || '/' ||
          count(*) FILTER (WHERE action = 'REFERENTIEL_VILLE_MERGED') || '/' ||
          count(*) FILTER (WHERE action = 'REFERENTIEL_VILLE_DELETED') || '/' ||
          count(*) FILTER (WHERE action = 'REFERENTIEL_PAYS_ADDED')
     FROM public.admin_audit_logs WHERE action LIKE 'REFERENTIEL_%'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
