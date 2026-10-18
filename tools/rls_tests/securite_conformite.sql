-- Banc : demandes relatives aux données et incidents de sécurité
-- (migration 20261018230000).
--
--   supabase db query --linked -f tools/rls_tests/securite_conformite.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'une demande de données soit traitée sans
-- que l'identité du demandeur ait été vérifiée, close sans compte rendu ou
-- refusée sans motif ; qu'un incident soit clos sans analyse ; que des
-- données personnelles ou des éléments de preuve se retrouvent dans l'audit ;
-- que ces écrans s'ouvrent à un rôle qui n'y a pas droit ; et que la
-- chronologie d'un incident se réécrive.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE ids(k text, v uuid);
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
  ('banc-sec-super',    'Super',   'sec-super@banc.test',   true,  'superAdmin'),
  ('banc-sec-content',  'Content', 'sec-content@banc.test', true,  'contentMod'),
  ('banc-sec-biz',      'Biz',     'sec-biz@banc.test',     true,  'businessMod'),
  ('banc-sec-finance',  'Finance', 'sec-fin@banc.test',     true,  'financeMod'),
  ('banc-sec-ordi',     'Ordi',    'sec-ordi@banc.test',    false, NULL),
  ('banc-sec-demandeur','Demandeur','sec-dem@banc.test',    false, NULL);

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, '2 permissions au catalogue, mappées à AUCUN rôle', '2/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('privacy.requests.manage', 'security.incidents.manage')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission IN ('privacy.requests.manage', 'security.incidents.manage')));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des sept RPC', 'false',
  (has_function_privilege('anon', 'public.privacy_request_create(text,text,text,uuid,text,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_verify_identity(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_transition(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.security_incident_open(text,text,text,text,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.security_incident_note(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.security_incident_set_severity(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.security_incident_transition(uuid,text,text,text,text,text)', 'EXECUTE'))::text);

-- Aucun rôle autre que superAdmin n'entre.
SELECT pg_temp.moi('banc-sec-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'contentMod : créer une demande REFUSÉ', '42501',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() + interval '10 days')$q$);
SELECT pg_temp.essai(11, 'contentMod : ouvrir un incident REFUSÉ', '42501',
  $q$SELECT public.security_incident_open('Fuite supposée', 'high', 'Un résumé assez long.', NULL)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sec-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'businessMod : créer une demande REFUSÉ', '42501',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() + interval '10 days')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sec-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'financeMod : ouvrir un incident REFUSÉ', '42501',
  $q$SELECT public.security_incident_open('Fuite supposée', 'high', 'Un résumé assez long.', NULL)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sec-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(14, 'ordinaire : créer une demande REFUSÉ', '42501',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() + interval '10 days')$q$);
RESET ROLE;

-- ═══ 2. Demandes : validations ═════════════════════════════════════════════
SELECT pg_temp.moi('banc-sec-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'nature inconnue → 22023', '22023',
  $q$SELECT public.privacy_request_create('vente', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() + interval '10 days')$q$);
SELECT pg_temp.essai(21, 'ni compte ni contact → 22023', '22023',
  $q$SELECT public.privacy_request_create('access', NULL, NULL, NULL, 'Tout', now() + interval '10 days')$q$);
SELECT pg_temp.essai(22, 'compte inconnu → 22023', '22023',
  $q$SELECT public.privacy_request_create('access', 'compte-fantome', NULL, NULL, 'Tout', now() + interval '10 days')$q$);
SELECT pg_temp.essai(23, 'échéance passée → 22023', '22023',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() - interval '1 day')$q$);
SELECT pg_temp.essai(24, 'échéance à 200 jours → 22023', '22023',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', now() + interval '200 days')$q$);
SELECT pg_temp.essai(25, 'sans échéance → 22023', '22023',
  $q$SELECT public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Tout', NULL)$q$);
SELECT pg_temp.essai(26, 'crée une demande d''accès', 'OK',
  $q$INSERT INTO ids SELECT 'd1', public.privacy_request_create('access', 'banc-sec-demandeur', NULL, NULL, 'Compte, messages, positions', now() + interval '30 days')$q$);
SELECT pg_temp.essai(27, 'crée une demande d''effacement par contact seul', 'OK',
  $q$INSERT INTO ids SELECT 'd2', public.privacy_request_create('erasure', NULL, 'demandeur@exemple.org', NULL, NULL, now() + interval '30 days')$q$);

-- ═══ 3. Cycle d'une demande ════════════════════════════════════════════════
SELECT pg_temp.essai(30, 'passer en traitement SANS identité vérifiée → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'in_progress')$q$);
SELECT pg_temp.essai(31, 'terminer sans être passé par le traitement → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'completed', 'Fait')$q$);
SELECT pg_temp.essai(32, 'méthode de vérification trop courte → 22023', '22023',
  $q$SELECT public.privacy_request_verify_identity((SELECT v FROM ids WHERE k = 'd1'), 'ok')$q$);
SELECT pg_temp.essai(33, 'vérifie l''identité', 'OK',
  $q$SELECT public.privacy_request_verify_identity((SELECT v FROM ids WHERE k = 'd1'), 'Message depuis le compte, code reçu par courriel')$q$);
SELECT pg_temp.essai(34, 'vérifier l''identité deux fois → 55000', '55000',
  $q$SELECT public.privacy_request_verify_identity((SELECT v FROM ids WHERE k = 'd1'), 'Message depuis le compte, code reçu par courriel')$q$);
SELECT pg_temp.essai(35, 'passe en traitement', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'in_progress')$q$);
SELECT pg_temp.essai(36, 'terminer sans compte rendu → 22023', '22023',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'completed', '  ')$q$);
SELECT pg_temp.essai(37, 'termine avec compte rendu', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'completed', 'Export envoyé : compte, messages (chiffrés), positions.')$q$);
SELECT pg_temp.essai(38, 'rouvrir une demande terminée → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd1'), 'in_progress')$q$);

SELECT pg_temp.essai(40, 'refuser sans motif → 22023', '22023',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd2'), 'refused')$q$);
SELECT pg_temp.essai(41, 'refuse avec motif', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd2'), 'refused', 'Identité du demandeur non établie après relance.')$q$);
SELECT pg_temp.essai(42, 'annuler une demande refusée → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'd2'), 'cancelled', 'Erreur')$q$);
SELECT pg_temp.essai(43, 'demande introuvable → P0002', 'P0002',
  $q$SELECT public.privacy_request_transition('00000000-0000-0000-0000-0000000000ff', 'cancelled', 'Erreur')$q$);
RESET ROLE;

SELECT pg_temp.verifie(44, 'd1 : terminée, identité vérifiée par qui et comment, close', 'completed/banc-sec-super/true/true',
  (SELECT status || '/' || identity_verified_by || '/' || (identity_method IS NOT NULL)::text || '/' || (closed_at IS NOT NULL)::text
     FROM public.privacy_requests WHERE id = (SELECT v FROM ids WHERE k = 'd1')));

-- Lecture.
SELECT pg_temp.moi('banc-sec-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(45, 'contentMod ne lit AUCUNE demande', '0', (SELECT count(*)::text FROM public.privacy_requests));
RESET ROLE;
SELECT pg_temp.moi('banc-sec-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(46, 'superAdmin lit les deux demandes', '2', (SELECT count(*)::text FROM public.privacy_requests));
SELECT pg_temp.essai(47, 'superAdmin : UPDATE direct REFUSÉ', '42501',
  $q$UPDATE public.privacy_requests SET status = 'completed'$q$);
SELECT pg_temp.essai(48, 'superAdmin : INSERT direct REFUSÉ', '42501',
  $q$INSERT INTO public.privacy_requests (kind, requester_contact, due_at, assigned_to, created_by) VALUES ('access', 'x', now() + interval '1 day', 'x', 'x')$q$);
RESET ROLE;

-- ═══ 4. Incidents ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sec-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'titre trop court → 22023', '22023',
  $q$SELECT public.security_incident_open('abc', 'high', 'Un résumé assez long.', NULL)$q$);
SELECT pg_temp.essai(51, 'gravité inconnue → 22023', '22023',
  $q$SELECT public.security_incident_open('Fuite de jetons', 'catastrophique', 'Un résumé assez long.', NULL)$q$);
SELECT pg_temp.essai(52, 'détection dans le futur → 22023', '22023',
  $q$SELECT public.security_incident_open('Fuite de jetons', 'high', 'Un résumé assez long.', NULL, now() + interval '1 day')$q$);
SELECT pg_temp.essai(53, 'ouvre un incident', 'OK',
  $q$INSERT INTO ids SELECT 'i1', public.security_incident_open('Fuite de jetons FCM', 'high', 'Des jetons FCM apparaissent dans un journal applicatif.', 'Notifications de ~30 comptes.', now() - interval '2 hours')$q$);
SELECT pg_temp.essai(54, 'ajoute une note de chronologie', 'OK',
  $q$SELECT public.security_incident_note((SELECT v FROM ids WHERE k = 'i1'), 'Journal purgé, jetons à renouveler. Preuve : ligne 4521.')$q$);
SELECT pg_temp.essai(55, 'note vide → 22023', '22023',
  $q$SELECT public.security_incident_note((SELECT v FROM ids WHERE k = 'i1'), '  ')$q$);
SELECT pg_temp.essai(56, 'change la gravité sans motif → 22023', '22023',
  $q$SELECT public.security_incident_set_severity((SELECT v FROM ids WHERE k = 'i1'), 'critical', '')$q$);
SELECT pg_temp.essai(57, 'gravité inchangée → 55000', '55000',
  $q$SELECT public.security_incident_set_severity((SELECT v FROM ids WHERE k = 'i1'), 'high', 'Rien ne change vraiment')$q$);
SELECT pg_temp.essai(58, 'monte la gravité avec motif', 'OK',
  $q$SELECT public.security_incident_set_severity((SELECT v FROM ids WHERE k = 'i1'), 'critical', 'Les jetons permettent l''envoi de push')$q$);
SELECT pg_temp.essai(59, 'clore un incident encore ouvert → 55000', '55000',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'closed', 'Fini', 'cause assez longue', 'mesures assez longues', 'leçons assez longues')$q$);
SELECT pg_temp.essai(60, 'confiner sans note → 22023', '22023',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'contained', '')$q$);
SELECT pg_temp.essai(61, 'confine', 'OK',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'contained', 'Jetons révoqués côté FCM.')$q$);
SELECT pg_temp.essai(62, 'résout', 'OK',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'resolved', 'Journalisation corrigée, déployée.')$q$);
SELECT pg_temp.essai(63, 'clôturer SANS analyse → 22023', '22023',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'closed', 'Terminé', 'cause', NULL, NULL)$q$);
SELECT pg_temp.essai(64, 'clôturer avec cause mais sans enseignements → 22023', '22023',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'closed', 'Terminé', 'Un journal de débogage laissé actif', 'Retrait du journal et test', NULL)$q$);
SELECT pg_temp.essai(65, 'clôt avec cause, mesures et enseignements', 'OK',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'closed', 'Terminé', 'Un journal de débogage laissé actif en production', 'Retrait du journal, test automatique ajouté', 'Aucun jeton ne doit jamais atteindre un journal')$q$);
SELECT pg_temp.essai(66, 'noter sur un incident clos → 55000', '55000',
  $q$SELECT public.security_incident_note((SELECT v FROM ids WHERE k = 'i1'), 'Encore une note')$q$);
SELECT pg_temp.essai(67, 'rouvrir un incident clos → 55000', '55000',
  $q$SELECT public.security_incident_transition((SELECT v FROM ids WHERE k = 'i1'), 'open', 'Retour')$q$);
RESET ROLE;

SELECT pg_temp.verifie(68, 'i1 : close, dates posées, analyse conservée', 'closed/critical/true/true/true',
  (SELECT status || '/' || severity || '/' || (contained_at IS NOT NULL)::text || '/' || (resolved_at IS NOT NULL AND closed_at IS NOT NULL)::text ||
          '/' || (cause IS NOT NULL AND corrective_actions IS NOT NULL AND lessons IS NOT NULL)::text
     FROM public.security_incidents WHERE id = (SELECT v FROM ids WHERE k = 'i1')));
SELECT pg_temp.verifie(69, 'chronologie : ouverture, note, gravité, 3 changements de statut (confiné, résolu, clos) = 6', '6',
  (SELECT count(*)::text FROM public.security_incident_events WHERE incident_id = (SELECT v FROM ids WHERE k = 'i1')));

SELECT pg_temp.moi('banc-sec-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(70, 'contentMod ne lit ni incidents ni chronologie', '0/0',
  (SELECT count(*) FROM public.security_incidents) || '/' || (SELECT count(*) FROM public.security_incident_events));
RESET ROLE;
SELECT pg_temp.essai(71, 'UPDATE de la chronologie REFUSÉ (même pour le propriétaire)', '42501',
  $q$UPDATE public.security_incident_events SET body = 'réécrit'$q$);
SELECT pg_temp.essai(72, 'DELETE de la chronologie REFUSÉ', '42501',
  $q$DELETE FROM public.security_incident_events$q$);

-- ═══ 5. L'audit : des actions, jamais les données ══════════════════════════
SELECT pg_temp.verifie(80, 'audit des demandes : 2 créées, 1 identité, 1 traitement, 1 terminée, 1 refusée', '2/1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'PRIVACY_REQUEST_CREATED') || '/' ||
          count(*) FILTER (WHERE action = 'PRIVACY_IDENTITY_VERIFIED') || '/' ||
          count(*) FILTER (WHERE action = 'PRIVACY_REQUEST_STARTED') || '/' ||
          count(*) FILTER (WHERE action = 'PRIVACY_REQUEST_COMPLETED') || '/' ||
          count(*) FILTER (WHERE action = 'PRIVACY_REQUEST_REFUSED')
     FROM public.admin_audit_logs WHERE target_id IN (SELECT v::text FROM ids WHERE k IN ('d1', 'd2'))));
SELECT pg_temp.verifie(81, 'audit des incidents : ouvert, note, gravité, confiné, résolu, clos', '1/1/1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'INCIDENT_OPENED') || '/' ||
          count(*) FILTER (WHERE action = 'INCIDENT_NOTE_ADDED') || '/' ||
          count(*) FILTER (WHERE action = 'INCIDENT_SEVERITY_CHANGED') || '/' ||
          count(*) FILTER (WHERE action = 'INCIDENT_CONTAINED') || '/' ||
          count(*) FILTER (WHERE action = 'INCIDENT_RESOLVED') || '/' ||
          count(*) FILTER (WHERE action = 'INCIDENT_CLOSED')
     FROM public.admin_audit_logs WHERE target_id = (SELECT v::text FROM ids WHERE k = 'i1')));
SELECT pg_temp.verifie(82, 'ni l''identité du demandeur, ni le périmètre, ni les notes de preuve dans l''audit', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id IN (SELECT v::text FROM ids)
      AND (details::text LIKE '%banc-sec-demandeur%' OR details::text LIKE '%demandeur@exemple%'
           OR details::text LIKE '%positions%' OR details::text LIKE '%ligne 4521%'
           OR details::text LIKE '%jetons FCM%')));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
