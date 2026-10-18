-- Banc : demandes d'informations et recours (migration 20261018090000).
--
--   supabase db query --linked -f tools/rls_tests/moderation_infos_et_recours.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont, côté demande : écrire sur le dossier de
-- quelqu'un d'autre, hors du statut `reviewing`, deux fois, ou sans échéance ;
-- côté recours : qu'un décideur examine sa propre décision (superAdmin
-- compris), qu'un recours saute une étape, qu'un autre que l'examinateur le
-- tranche, et que la décision contestée soit perdue. Il vérifie aussi que le
-- chemin nominal laisse exactement la trace d'audit attendue, qu'un refus n'en
-- laisse aucune, et que personne n'écrit les tables directement.

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
  ('banc-inf-super',   'Super',   'inf-super@banc.test',   true,  'superAdmin'),
  ('banc-inf-a',       'Mod A',   'inf-a@banc.test',       true,  'contentMod'),
  ('banc-inf-b',       'Mod B',   'inf-b@banc.test',       true,  'contentMod'),
  ('banc-inf-finance', 'Finance', 'inf-fin@banc.test',     true,  'financeMod'),
  ('banc-inf-ordi',    'Ordi',    'inf-ordi@banc.test',    false, NULL),
  ('banc-inf-membre',  'Membre',  'inf-membre@banc.test',  false, NULL);

-- c1 en examen chez A ; c2 décidé par A (avertissement) ; c3 en attente ;
-- c4 en examen chez A mais sans membre signalé ; c5 décidé par le superAdmin.
INSERT INTO public.reports
  (id, reporter_id, target_type, target_id, reason, status, assigned_to,
   reported_user_id, reviewed_by, action_taken, reason_code) VALUES
  ('00000000-0000-0000-0000-0000000000c1', 'banc-inf-ordi', 'post', 'p1', 'spam',
   'reviewing', 'banc-inf-a', 'banc-inf-membre', NULL, NULL, NULL),
  ('00000000-0000-0000-0000-0000000000c2', 'banc-inf-ordi', 'post', 'p2', 'spam',
   'resolved', 'banc-inf-a', 'banc-inf-membre', 'banc-inf-a', 'avertissement', 'user_warned'),
  ('00000000-0000-0000-0000-0000000000c3', 'banc-inf-ordi', 'post', 'p3', 'spam',
   'pending', NULL, 'banc-inf-membre', NULL, NULL, NULL),
  ('00000000-0000-0000-0000-0000000000c4', 'banc-inf-ordi', 'post', 'p4', 'spam',
   'reviewing', 'banc-inf-a', NULL, NULL, NULL, NULL),
  ('00000000-0000-0000-0000-0000000000c5', 'banc-inf-ordi', 'post', 'p5', 'spam',
   'resolved', 'banc-inf-super', 'banc-inf-membre', 'banc-inf-super', 'retrait', 'content_removed');

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'les 5 permissions sont dans le catalogue', '5',
  (SELECT count(*)::text FROM public.admin_permissions
    WHERE key IN ('moderation.info_requests.create','moderation.info_requests.send',
                  'moderation.appeals.view','moderation.appeals.review','moderation.appeals.decide')));
SELECT pg_temp.verifie(2, 'contentMod les porte toutes, financeMod aucune', '5/0',
  (SELECT count(*) FROM public.admin_role_permissions
    WHERE role = 'contentMod' AND permission IN ('moderation.info_requests.create',
      'moderation.info_requests.send','moderation.appeals.view','moderation.appeals.review',
      'moderation.appeals.decide')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions
    WHERE role = 'financeMod' AND permission LIKE 'moderation.%'));
SELECT pg_temp.verifie(3, 'anon n''exécute aucune des six RPC', 'false',
  (has_function_privilege('anon', 'public.moderation_info_request_create(uuid,text,text,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.moderation_info_request_send(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.moderation_info_request_record_response(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.moderation_appeal_register(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.moderation_appeal_take(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.moderation_appeal_decide(uuid,text,text)', 'EXECUTE'))::text);

-- ═══ 2. Demandes : refus ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-inf-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : rédiger REFUSÉ', '42501',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : rédiger REFUSÉ', '42501',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'B : dossier de A REFUSÉ', '42501',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'A : dossier en attente (pas reviewing) → 55000', '55000',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c3','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
SELECT pg_temp.essai(14, 'A : dossier introuvable → P0002', 'P0002',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000ff','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
SELECT pg_temp.essai(15, 'A : destinataire hors liste → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','tout-le-monde','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
SELECT pg_temp.essai(16, 'A : questions trop courtes → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','???', now() + interval '7 days')$q$);
SELECT pg_temp.essai(17, 'A : échéance passée → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() - interval '1 day')$q$);
SELECT pg_temp.essai(18, 'A : échéance à 90 jours → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() + interval '90 days')$q$);
SELECT pg_temp.essai(19, 'A : sans échéance → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', NULL)$q$);
SELECT pg_temp.essai(20, 'A : membre signalé inconnu sur c4 → 22023', '22023',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c4','reported','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
RESET ROLE;

-- ═══ 3. Demandes : chemin nominal ══════════════════════════════════════════
SELECT pg_temp.moi('banc-inf-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'A : rédige une demande au signalant', 'OK',
  $q$INSERT INTO ids SELECT 'q1', public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Pouvez-vous préciser le contexte ?', now() + interval '7 days')$q$);
SELECT pg_temp.essai(31, 'A : seconde demande ouverte au même destinataire → 55000', '55000',
  $q$SELECT public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reporter','Une autre question ici ?', now() + interval '7 days')$q$);
SELECT pg_temp.essai(32, 'A : rédige une demande DISTINCTE au membre signalé', 'OK',
  $q$INSERT INTO ids SELECT 'q2', public.moderation_info_request_create('00000000-0000-0000-0000-0000000000c1','reported','Quelle est votre version des faits ?', now() + interval '7 days')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(33, 'B : envoyer la demande de A REFUSÉ', '42501',
  $q$SELECT public.moderation_info_request_send((SELECT v FROM ids WHERE k = 'q1'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(34, 'A : répondre avant l''envoi → 55000 (draft)', '55000',
  $q$SELECT public.moderation_info_request_record_response((SELECT v FROM ids WHERE k = 'q1'), 'Réponse')$q$);
SELECT pg_temp.essai(35, 'A : envoie q1', 'OK',
  $q$SELECT public.moderation_info_request_send((SELECT v FROM ids WHERE k = 'q1'))$q$);
SELECT pg_temp.essai(36, 'A : renvoyer q1 (double clic) → 55000', '55000',
  $q$SELECT public.moderation_info_request_send((SELECT v FROM ids WHERE k = 'q1'))$q$);
SELECT pg_temp.essai(37, 'A : réponse vide → 22023', '22023',
  $q$SELECT public.moderation_info_request_record_response((SELECT v FROM ids WHERE k = 'q1'), '   ')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(38, 'B : consigner la réponse du dossier de A REFUSÉ', '42501',
  $q$SELECT public.moderation_info_request_record_response((SELECT v FROM ids WHERE k = 'q1'), 'Réponse')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(39, 'A : consigne la réponse', 'OK',
  $q$SELECT public.moderation_info_request_record_response((SELECT v FROM ids WHERE k = 'q1'), 'Le message a été publié hier soir.')$q$);
SELECT pg_temp.essai(40, 'A : seconde réponse → 55000', '55000',
  $q$SELECT public.moderation_info_request_record_response((SELECT v FROM ids WHERE k = 'q1'), 'Autre')$q$);
RESET ROLE;

SELECT pg_temp.verifie(41, 'q1 answered, répondu et enregistré par A', 'answered/banc-inf-a/true',
  (SELECT status || '/' || recorded_by || '/' || (responded_at IS NOT NULL)::text
     FROM public.moderation_info_requests WHERE id = (SELECT v FROM ids WHERE k = 'q1')));

-- ═══ 4. Recours : refus ════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-inf-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'ordinaire : enregistrer un recours REFUSÉ', '42501',
  $q$SELECT public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c2','Je conteste cette décision, voici pourquoi.')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'B : recours sur un dossier en attente → 55000', '55000',
  $q$SELECT public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c3','Je conteste cette décision, voici pourquoi.')$q$);
SELECT pg_temp.essai(52, 'B : recours sur un dossier en examen → 55000', '55000',
  $q$SELECT public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c1','Je conteste cette décision, voici pourquoi.')$q$);
SELECT pg_temp.essai(53, 'B : arguments trop courts → 22023', '22023',
  $q$SELECT public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c2','non')$q$);
SELECT pg_temp.essai(54, 'B : enregistre le recours sur c2', 'OK',
  $q$INSERT INTO ids SELECT 'p1', public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c2','Je conteste cette décision, voici pourquoi.')$q$);
SELECT pg_temp.essai(55, 'B : second recours en cours sur c2 → 55000', '55000',
  $q$SELECT public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c2','Je conteste cette décision, voici pourquoi.')$q$);
SELECT pg_temp.essai(56, 'B : décider sans l''avoir pris en examen → 55000', '55000',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'annulled', 'x')$q$);
RESET ROLE;

-- ═══ 5. Recours : séparation des tâches ════════════════════════════════════
SELECT pg_temp.moi('banc-inf-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'A (décideur contesté) : prendre son propre recours REFUSÉ', '42501',
  $q$SELECT public.moderation_appeal_take((SELECT v FROM ids WHERE k = 'p1'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(61, 'B : enregistre un recours sur c5 (décidé par le superAdmin)', 'OK',
  $q$INSERT INTO ids SELECT 'p2', public.moderation_appeal_register('00000000-0000-0000-0000-0000000000c5','Je conteste cette décision, voici pourquoi.')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(62, 'superAdmin (décideur contesté de c5) : prendre le recours REFUSÉ', '42501',
  $q$SELECT public.moderation_appeal_take((SELECT v FROM ids WHERE k = 'p2'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(63, 'B : prend p1 en examen', 'OK',
  $q$SELECT public.moderation_appeal_take((SELECT v FROM ids WHERE k = 'p1'))$q$);
SELECT pg_temp.essai(64, 'B : reprendre p1 → 55000', '55000',
  $q$SELECT public.moderation_appeal_take((SELECT v FROM ids WHERE k = 'p1'))$q$);
SELECT pg_temp.essai(65, 'B : issue hors liste → 22023', '22023',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'peut-etre', 'x')$q$);
SELECT pg_temp.essai(66, 'B : motif final vide → 22023', '22023',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'annulled', '  ')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(67, 'superAdmin : trancher le recours examiné par B REFUSÉ', '42501',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'annulled', 'Je tranche à sa place')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(68, 'financeMod : trancher REFUSÉ', '42501',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'annulled', 'x')$q$);
RESET ROLE;

-- ═══ 6. Recours : décision, renvoi, conservation de l'initiale ═════════════
SELECT pg_temp.moi('banc-inf-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'B : renvoie le dossier pour réexamen', 'OK',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'sent_back', 'Preuves nouvelles, à réexaminer.')$q$);
SELECT pg_temp.essai(71, 'B : trancher une seconde fois → 55000', '55000',
  $q$SELECT public.moderation_appeal_decide((SELECT v FROM ids WHERE k = 'p1'), 'annulled', 'Encore')$q$);
RESET ROLE;

SELECT pg_temp.verifie(72, 'c2 renvoyé : escalated, sans responsable', 'escalated/vide',
  (SELECT status || '/' || COALESCE(assigned_to, 'vide')
     FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000c2'));
SELECT pg_temp.verifie(73, 'le recours garde la décision contestée (A, avertissement, user_warned)',
  'banc-inf-a/avertissement/user_warned',
  (SELECT contested_decider || '/' || contested_action || '/' || contested_reason
     FROM public.moderation_appeals WHERE id = (SELECT v FROM ids WHERE k = 'p1')));
SELECT pg_temp.verifie(74, 'recours tranché : sent_back, par B, daté', 'sent_back/banc-inf-b/true',
  (SELECT status || '/' || reviewer_id || '/' || (decided_at IS NOT NULL)::text
     FROM public.moderation_appeals WHERE id = (SELECT v FROM ids WHERE k = 'p1')));

-- ═══ 7. Personne n'écrit les tables directement ════════════════════════════
SELECT pg_temp.moi('banc-inf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(80, 'superAdmin : INSERT direct dans moderation_appeals REFUSÉ', '42501',
  $q$INSERT INTO public.moderation_appeals (report_id, appellant_id, argument, registered_by, contested_decider)
     VALUES ('00000000-0000-0000-0000-0000000000c5','x','Argument assez long pour passer.','banc-inf-super','banc-inf-super')$q$);
SELECT pg_temp.essai(81, 'superAdmin : UPDATE direct de moderation_appeals REFUSÉ', '42501',
  $q$UPDATE public.moderation_appeals SET status = 'annulled'$q$);
SELECT pg_temp.essai(82, 'superAdmin : UPDATE direct de moderation_info_requests REFUSÉ', '42501',
  $q$UPDATE public.moderation_info_requests SET status = 'answered'$q$);
SELECT pg_temp.essai(83, 'superAdmin : DELETE direct de moderation_info_requests REFUSÉ', '42501',
  $q$DELETE FROM public.moderation_info_requests$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-inf-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(84, 'ordinaire : ne lit aucune demande ni aucun recours', '0/0',
  (SELECT count(*) FROM public.moderation_info_requests) || '/' ||
  (SELECT count(*) FROM public.moderation_appeals));
RESET ROLE;

-- ═══ 8. L'audit : exactement ce qui a réussi, rien de ce qui a été refusé ══
SELECT pg_temp.verifie(90, 'c1 : 2 rédactions, 1 envoi, 1 réponse', '2/1/1',
  (SELECT count(*) FILTER (WHERE action = 'INFO_REQUEST_DRAFTED') || '/' ||
          count(*) FILTER (WHERE action = 'INFO_REQUEST_SENT') || '/' ||
          count(*) FILTER (WHERE action = 'RESPONSE_RECEIVED')
     FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000c1'));
SELECT pg_temp.verifie(91, 'c2 : recours enregistré, pris, tranché (1 chacun)', '1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'APPEAL_REGISTERED') || '/' ||
          count(*) FILTER (WHERE action = 'APPEAL_REVIEW_STARTED') || '/' ||
          count(*) FILTER (WHERE action = 'APPEAL_DECIDED')
     FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000c2'));
SELECT pg_temp.verifie(92, 'c3, c4, c5 : aucune ligne de succès pour un refus (c5 : seul l''enregistrement)', '0/0/1',
  (SELECT count(*) FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000c3') || '/' ||
  (SELECT count(*) FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000c4') || '/' ||
  (SELECT count(*) FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000c5'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
