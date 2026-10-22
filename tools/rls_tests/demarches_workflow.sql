-- Banc : workflow des démarches consulaires (migration 20261018150000).
--
--   supabase db query --linked -f tools/rls_tests/demarches_workflow.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un texte que l'usager lira — pièces,
-- coût, adresse — change sans relecture, sans source, ou par son propre
-- rédacteur ; qu'un brouillon écrase une version publiée entre-temps ; qu'une
-- démarche dépubliée reste servie au public ; et que l'historique se réécrive.
-- Il vérifie aussi que les 20 démarches déjà publiées restent publiées, avec
-- leur provenance.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE ids(k text, v uuid);
GRANT ALL ON ids TO anon, authenticated;
CREATE TEMP TABLE avant(k text, v bigint);
GRANT ALL ON avant TO anon, authenticated;

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

-- Mesures avant la migration : ce que la production publie aujourd'hui.
INSERT INTO avant SELECT 'publiees', count(*) FROM public.demarches_consulaires;
INSERT INTO avant SELECT 'meta_version', version FROM public.demarches_catalogue_meta;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-dem-super',   'Super',   'dem-super@banc.test',   true,  'superAdmin'),
  ('banc-dem-a',       'Agent A', 'dem-a@banc.test',       true,  'contentMod'),
  ('banc-dem-b',       'Agent B', 'dem-b@banc.test',       true,  'contentMod'),
  ('banc-dem-finance', 'Finance', 'dem-fin@banc.test',     true,  'financeMod'),
  ('banc-dem-ordi',    'Ordi',    'dem-ordi@banc.test',    false, NULL);

-- ═══ 1. Catalogue, droits, héritage ════════════════════════════════════════
SELECT pg_temp.verifie(1, '4 permissions au catalogue, contentMod les porte, financeMod aucune', '4/4/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key LIKE 'consular.%') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission LIKE 'consular.%') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod' AND permission LIKE 'consular.%'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des sept fonctions', 'false',
  (has_function_privilege('anon', 'public.demarche_draft_save(text,jsonb,text,text,timestamptz,timestamptz,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.demarche_submit(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.demarche_withdraw(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.demarche_review(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.demarche_publish(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.demarche_unpublish(text,text)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'public.demarche_payload_check(jsonb)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'plus aucun droit d''écriture direct sur les démarches', 'false',
  (has_table_privilege('authenticated', 'public.demarches_consulaires', 'INSERT')
   OR has_table_privilege('authenticated', 'public.demarches_consulaires', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.demarches_consulaires', 'DELETE')
   OR has_table_privilege('anon', 'public.demarches_consulaires', 'INSERT')
   OR has_table_privilege('anon', 'public.demarches_consulaires', 'UPDATE'))::text);
SELECT pg_temp.verifie(4, 'les démarches déjà publiées le restent, toutes avec source et vérification', 'true/0',
  ((SELECT count(*) FROM public.demarches_consulaires WHERE publication_status = 'published')
     = (SELECT v FROM avant WHERE k = 'publiees'))::text || '/' ||
  (SELECT count(*) FROM public.demarches_consulaires
    WHERE publication_status = 'published' AND (source_url IS NULL OR verified_at IS NULL)));
SELECT pg_temp.verifie(5, 'chaque démarche d''origine a sa version 1 dans l''historique', 'true',
  ((SELECT count(DISTINCT demarche_id) FROM public.demarches_versions WHERE version = 1)
     >= (SELECT v FROM avant WHERE k = 'publiees'))::text);

-- ═══ 2. Rédaction : refus et validations ═══════════════════════════════════
SELECT pg_temp.moi('banc-dem-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : rédiger REFUSÉ', '42501',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{"montant":null}}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-dem-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : rédiger REFUSÉ', '42501',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{"montant":null}}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'A : identifiant invalide → 22023', '22023',
  $q$SELECT public.demarche_draft_save('Mauvais Id!', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
SELECT pg_temp.essai(13, 'A : source en http:// → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, 'http://exemple.ne/x', 'Ministère', now(), NULL, NULL)$q$);
SELECT pg_temp.essai(14, 'A : vérification dans le futur → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, 'https://exemple.ne/x', 'Ministère', now() + interval '2 days', NULL, NULL)$q$);
SELECT pg_temp.essai(15, 'A : champ inconnu dans le contenu → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{},"publication_status":"published"}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
SELECT pg_temp.essai(16, 'A : rubrique inconnue → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"nimporte","request_type":"other","cout":{}}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
SELECT pg_temp.essai(17, 'A : nouvelle démarche sans coût → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other"}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
SELECT pg_temp.essai(18, 'A : modifier une démarche publiée sans motif → 22023', '22023',
  $q$SELECT public.demarche_draft_save('carte_consulaire', '{"resume":"Nouveau résumé"}'::jsonb, 'https://exemple.ne/x', 'Ministère', now(), NULL, NULL)$q$);
SELECT pg_temp.essai(19, 'A : révision avant la vérification → 22023', '22023',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, 'https://exemple.ne/x', 'Ministère', now() - interval '1 day', now() - interval '3 days', NULL)$q$);
RESET ROLE;

-- ═══ 3. Cycle nominal d'une nouvelle démarche ═════════════════════════════
SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'A : rédige une nouvelle démarche (sans source encore)', 'OK',
  $q$INSERT INTO ids SELECT 'n1', public.demarche_draft_save('banc_demarche', '{"titre":"Démarche de banc","rubrique":"etat_civil","request_type":"other","cout":{"montant":null},"pieces":[{"libelle":"Passeport"}]}'::jsonb, NULL, NULL, NULL, NULL, NULL)$q$);
SELECT pg_temp.essai(21, 'A : soumettre sans source → 22023', '22023',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(22, 'A : complète la source et la vérification', 'OK',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"resume":"Résumé de banc"}'::jsonb, 'https://diplomatie.gouv.ne/exemple', 'Ministère des Affaires étrangères', now() - interval '1 day', now() + interval '180 days', NULL)$q$);
RESET ROLE;

SELECT pg_temp.verifie(23, 'le complément a mis à jour le MÊME brouillon, avec le résumé et l''ancien titre', '1/Résumé de banc/Démarche de banc',
  (SELECT count(*) || '/' || max(payload ->> 'resume') || '/' || max(payload ->> 'titre')
     FROM public.demarches_brouillons WHERE demarche_id = 'banc_demarche'));

SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(24, 'B : modifier le brouillon de A REFUSÉ', '42501',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"resume":"Détourné"}'::jsonb, 'https://exemple.ne/x', 'X', now(), NULL, NULL)$q$);
SELECT pg_temp.essai(25, 'B : soumettre le brouillon de A REFUSÉ', '42501',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(26, 'B : retirer le brouillon de A REFUSÉ', '42501',
  $q$SELECT public.demarche_withdraw((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(27, 'B : approuver un brouillon non soumis → 55000', '55000',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'approve')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(28, 'A : soumet', 'OK',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(29, 'A : soumettre une seconde fois → 55000', '55000',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(30, 'A : modifier un brouillon soumis → 55000', '55000',
  $q$SELECT public.demarche_draft_save('banc_demarche', '{"resume":"Changé"}'::jsonb, 'https://exemple.ne/x', 'X', now(), NULL, NULL)$q$);
SELECT pg_temp.essai(31, 'A : approuver SON propre texte REFUSÉ', '42501',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'approve')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dem-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(32, 'financeMod : approuver REFUSÉ', '42501',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'approve')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(33, 'B : décision hors liste → 22023', '22023',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'peut-etre')$q$);
SELECT pg_temp.essai(34, 'B : publier un texte non approuvé → 55000', '55000',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(35, 'B : approuve', 'OK',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'approve')$q$);
SELECT pg_temp.essai(36, 'B : approuver une seconde fois → 55000', '55000',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'n1'), 'approve')$q$);
RESET ROLE;

SELECT pg_temp.verifie(37, 'avant publication : rien de public sur banc_demarche', '0',
  (SELECT count(*)::text FROM public.demarches_consulaires WHERE id = 'banc_demarche'));

SELECT pg_temp.moi('banc-dem-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(38, 'ordinaire : publier REFUSÉ', '42501',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'n1'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(39, 'B : publie', 'OK',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'n1'))$q$);
SELECT pg_temp.essai(40, 'B : publier une seconde fois → 55000', '55000',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'n1'))$q$);
RESET ROLE;

SELECT pg_temp.verifie(41, 'publiée : version 1, source et auteur de la publication', '1/published/https://diplomatie.gouv.ne/exemple/banc-dem-b',
  (SELECT version || '/' || publication_status || '/' || source_url || '/' || published_by
     FROM public.demarches_consulaires WHERE id = 'banc_demarche'));

-- Le public voit la démarche, et le RPC l'inclut.
SET LOCAL ROLE anon;
SELECT pg_temp.verifie(42, 'anon voit la démarche publiée', '1',
  (SELECT count(*)::text FROM public.demarches_consulaires WHERE id = 'banc_demarche'));
SELECT pg_temp.verifie(43, 'anon : le catalogue la contient avec sa date de vérification', '1/true',
  (SELECT count(*) || '/' || bool_and(d ? 'verifieLe')::text
     FROM jsonb_array_elements(public.get_demarches_catalogue() -> 'demarches') d
    WHERE d ->> 'id' = 'banc_demarche'));
RESET ROLE;

-- ═══ 4. Modifier une démarche publiée : version 2, historique conservé ═════
SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'A : brouillon sur une démarche publiée, avec motif', 'OK',
  $q$INSERT INTO ids SELECT 'm1', public.demarche_draft_save('carte_consulaire', '{"resume":"Résumé corrigé en banc"}'::jsonb, 'https://diplomatie.gouv.ne/exemple', 'Ministère', now() - interval '1 hour', NULL, 'Correction du résumé')$q$);
SELECT pg_temp.essai(51, 'A : soumet', 'OK',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'm1'))$q$);
RESET ROLE;
SELECT pg_temp.verifie(52, 'le brouillon n''a rien changé au texte publié', 'true',
  (SELECT (resume IS DISTINCT FROM 'Résumé corrigé en banc' AND version = 1)::text
     FROM public.demarches_consulaires WHERE id = 'carte_consulaire'));
SELECT pg_temp.verifie(53, 'le brouillon a repris les autres champs de la version publiée (pièces)', 'true',
  (SELECT (jsonb_array_length(payload -> 'pieces') = (SELECT jsonb_array_length(pieces) FROM public.demarches_consulaires WHERE id = 'carte_consulaire'))::text
     FROM public.demarches_brouillons WHERE id = (SELECT v FROM ids WHERE k = 'm1')));

SELECT pg_temp.moi('banc-dem-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(54, 'superAdmin (pas l''auteur) : approuve', 'OK',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'm1'), 'approve')$q$);
SELECT pg_temp.essai(55, 'superAdmin : publie', 'OK',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'm1'))$q$);
RESET ROLE;

SELECT pg_temp.verifie(56, 'carte_consulaire : version 2, nouveau résumé', '2/Résumé corrigé en banc',
  (SELECT version || '/' || resume FROM public.demarches_consulaires WHERE id = 'carte_consulaire'));
SELECT pg_temp.verifie(57, 'historique : versions 1 ET 2 conservées, avec le motif', '1/2/Correction du résumé',
  (SELECT min(version) || '/' || max(version) || '/' || max(reason) FILTER (WHERE version = 2)
     FROM public.demarches_versions WHERE demarche_id = 'carte_consulaire' AND event = 'published'));

-- ═══ 5. Refus motivé, retrait ══════════════════════════════════════════════
SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'A : rédige banc_rejet', 'OK',
  $q$INSERT INTO ids SELECT 'r1', public.demarche_draft_save('banc_rejet', '{"titre":"Démarche rejetée","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, 'https://diplomatie.gouv.ne/exemple', 'Ministère', now() - interval '1 day', NULL, NULL)$q$);
SELECT pg_temp.essai(61, 'A : soumet banc_rejet', 'OK',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'r1'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(62, 'B : refuser sans motif → 22023', '22023',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'r1'), 'reject')$q$);
SELECT pg_temp.essai(63, 'B : refuse avec motif', 'OK',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'r1'), 'reject', 'Source trop ancienne')$q$);
SELECT pg_temp.essai(64, 'B : publier un texte refusé → 55000', '55000',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'r1'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(65, 'A : après un refus, rouvre un nouveau brouillon', 'OK',
  $q$INSERT INTO ids SELECT 'r2', public.demarche_draft_save('banc_rejet', '{"titre":"Démarche reprise","rubrique":"etat_civil","request_type":"other","cout":{}}'::jsonb, 'https://diplomatie.gouv.ne/exemple', 'Ministère', now() - interval '1 day', NULL, NULL)$q$);
SELECT pg_temp.essai(66, 'A : retire ce brouillon', 'OK',
  $q$SELECT public.demarche_withdraw((SELECT v FROM ids WHERE k = 'r2'))$q$);
SELECT pg_temp.essai(67, 'A : retirer une seconde fois → 55000', '55000',
  $q$SELECT public.demarche_withdraw((SELECT v FROM ids WHERE k = 'r2'))$q$);
RESET ROLE;

-- ═══ 6. Conflit de version ═════════════════════════════════════════════════
SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'A : brouillon sur carte_electeur', 'OK',
  $q$INSERT INTO ids SELECT 'c1', public.demarche_draft_save('carte_electeur', '{"resume":"Version de A"}'::jsonb, 'https://diplomatie.gouv.ne/exemple', 'Ministère', now() - interval '1 hour', NULL, 'Précision')$q$);
SELECT pg_temp.essai(71, 'A : soumet', 'OK',
  $q$SELECT public.demarche_submit((SELECT v FROM ids WHERE k = 'c1'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(72, 'B : approuve', 'OK',
  $q$SELECT public.demarche_review((SELECT v FROM ids WHERE k = 'c1'), 'approve')$q$);
RESET ROLE;
-- Quelqu'un d'autre a publié entre-temps (simulé par le propriétaire).
UPDATE public.demarches_consulaires SET version = version + 1 WHERE id = 'carte_electeur';
SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(73, 'B : publier un texte devenu périmé → 55000 (pas d''écrasement)', '55000',
  $q$SELECT public.demarche_publish((SELECT v FROM ids WHERE k = 'c1'))$q$);
RESET ROLE;

-- ═══ 7. Dépublier ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-dem-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(80, 'ordinaire : dépublier REFUSÉ', '42501',
  $q$SELECT public.demarche_unpublish('banc_demarche', 'Information obsolète')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-dem-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(81, 'B : dépublier sans motif → 22023', '22023',
  $q$SELECT public.demarche_unpublish('banc_demarche', '  ')$q$);
SELECT pg_temp.essai(82, 'B : dépublier une démarche inconnue → P0002', 'P0002',
  $q$SELECT public.demarche_unpublish('nexiste_pas', 'Information obsolète')$q$);
SELECT pg_temp.essai(83, 'B : dépublie banc_demarche', 'OK',
  $q$SELECT public.demarche_unpublish('banc_demarche', 'Information obsolète')$q$);
SELECT pg_temp.essai(84, 'B : dépublier deux fois → 55000', '55000',
  $q$SELECT public.demarche_unpublish('banc_demarche', 'Information obsolète')$q$);
RESET ROLE;

SET LOCAL ROLE anon;
SELECT pg_temp.verifie(85, 'anon ne voit plus la démarche dépubliée (table)', '0',
  (SELECT count(*)::text FROM public.demarches_consulaires WHERE id = 'banc_demarche'));
SELECT pg_temp.verifie(86, 'anon ne la reçoit plus dans le catalogue', '0',
  (SELECT count(*)::text FROM jsonb_array_elements(public.get_demarches_catalogue() -> 'demarches') d
    WHERE d ->> 'id' = 'banc_demarche'));
RESET ROLE;

SELECT pg_temp.moi('banc-dem-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(87, 'un agent avec consular.view la voit encore (pour la republier)', '1',
  (SELECT count(*)::text FROM public.demarches_consulaires WHERE id = 'banc_demarche'));
RESET ROLE;
SELECT pg_temp.moi('banc-dem-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(88, 'financeMod ne la voit pas', '0',
  (SELECT count(*)::text FROM public.demarches_consulaires WHERE id = 'banc_demarche'));
SELECT pg_temp.verifie(89, 'financeMod ne lit aucun brouillon', '0',
  (SELECT count(*)::text FROM public.demarches_brouillons));
RESET ROLE;

-- ═══ 8. L'historique ne se réécrit pas, le public ne l'écrit pas ═══════════
SELECT pg_temp.essai(90, 'UPDATE de l''historique REFUSÉ (même pour le propriétaire)', '42501',
  $q$UPDATE public.demarches_versions SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(91, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.demarches_versions$q$);
SELECT pg_temp.moi('banc-dem-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(92, 'superAdmin : UPDATE direct d''une démarche REFUSÉ', '42501',
  $q$UPDATE public.demarches_consulaires SET resume = 'direct' WHERE id = 'carte_consulaire'$q$);
SELECT pg_temp.essai(93, 'superAdmin : INSERT direct d''une démarche REFUSÉ', '42501',
  $q$INSERT INTO public.demarches_consulaires (id, titre, rubrique, request_type, cout) VALUES ('direct','x','etat_civil','other','{}')$q$);
RESET ROLE;

-- ═══ 9. Audit et version du catalogue ══════════════════════════════════════
SELECT pg_temp.verifie(100, 'banc_demarche : 2 rédactions, 1 soumission, 1 approbation, 1 publication, 1 dépublication', '2/1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'DEMARCHE_DRAFTED') || '/' ||
          count(*) FILTER (WHERE action = 'DEMARCHE_SUBMITTED') || '/' ||
          count(*) FILTER (WHERE action = 'DEMARCHE_APPROVED') || '/' ||
          count(*) FILTER (WHERE action = 'DEMARCHE_PUBLISHED') || '/' ||
          count(*) FILTER (WHERE action = 'DEMARCHE_UNPUBLISHED')
     FROM public.admin_audit_logs WHERE target_id = 'banc_demarche'));
SELECT pg_temp.verifie(101, 'banc_rejet : refus et retrait tracés', '1/1',
  (SELECT count(*) FILTER (WHERE action = 'DEMARCHE_REJECTED') || '/' ||
          count(*) FILTER (WHERE action = 'DEMARCHE_WITHDRAWN')
     FROM public.admin_audit_logs WHERE target_id = 'banc_rejet'));
SELECT pg_temp.verifie(102, 'le conflit de version ne laisse aucune publication', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id = 'carte_electeur' AND action = 'DEMARCHE_PUBLISHED'));
SELECT pg_temp.verifie(103, 'la version du catalogue a avancé (3 publications/dépublications)', 'true',
  ((SELECT version FROM public.demarches_catalogue_meta)
     >= (SELECT v FROM avant WHERE k = 'meta_version') + 3)::text);

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
