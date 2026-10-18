-- Banc : campagnes programmées, modèles, rapport (migration 20261019110000).
--
--   supabase db query --linked -f tools/rls_tests/campagnes_programmees.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`. Le ROLLBACK
-- annule aussi les appels pg_net posés par `trg_notify_push` : aucun push ne
-- part. L'audience est un pays fictif : les comptes réels ne sont jamais visés.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
-- Le banc 20261018210000 (communications_campagnes.sql) doit passer lui aussi
-- avec cette migration injectée : l'envoi manuel n'a pas changé.
--
-- CE QU'IL VÉRIFIE. Le danger est qu'une tâche planifiée envoie un message qui
-- n'a pas été approuvé, ou sans heure, ou deux fois ; qu'on approuve une heure
-- déjà passée ; qu'une campagne programmée parte à la main avant son heure ;
-- qu'un compte ordinaire écrive un modèle ; et que la tâche ne soit pas posée.

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
  ('banc-prg-super',   'Super',    'prg-super@banc.test',   true,  'superAdmin'),
  ('banc-prg-super2',  'Super 2',  'prg-super2@banc.test',  true,  'superAdmin'),
  ('banc-prg-auteur',  'Auteur',   'prg-auteur@banc.test',  true,  'contentMod'),
  ('banc-prg-autre',   'Autre',    'prg-autre@banc.test',   true,  'contentMod'),
  ('banc-prg-finance', 'Finance',  'prg-fin@banc.test',     true,  'financeMod'),
  ('banc-prg-ordi',    'Ordi',     'prg-ordi@banc.test',    false, NULL),
  ('banc-prg-r1',      'Normal',   'prg-r1@banc.test',      false, NULL),
  ('banc-prg-r2',      'Coupé',    'prg-r2@banc.test',      false, NULL),
  ('banc-prg-r3',      'Sans système', 'prg-r3@banc.test',  false, NULL),
  ('banc-prg-r4',      'Banni',    'prg-r4@banc.test',      false, NULL);
UPDATE public.users SET country_code = 'BancLandP' WHERE id LIKE 'banc-prg-r_';
UPDATE public.users SET notifications_enabled = false WHERE id = 'banc-prg-r2';
UPDATE public.users SET notification_prefs = '{"system_messages": "false"}'::jsonb WHERE id = 'banc-prg-r3';
UPDATE public.users SET is_banned = true WHERE id = 'banc-prg-r4';
UPDATE public.users SET fcm_tokens = '["jeton-banc"]'::jsonb WHERE id = 'banc-prg-r1';

-- ═══ 1. La tâche est posée, les aides internes sont fermées ════════════════
SELECT pg_temp.verifie(1, 'la tâche pg_cron « campaign_send_due » existe, toutes les 5 minutes, active', '1',
  (SELECT count(*)::text FROM cron.job WHERE jobname = 'campaign_send_due'
     AND schedule = '*/5 * * * *' AND active));
SELECT pg_temp.verifie(2, 'authenticated n''exécute aucune fonction interne', 'false',
  (has_function_privilege('authenticated', 'private.campaign_send_core(uuid,integer,text,text)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'private.campaign_send_due()', 'EXECUTE')
   OR has_function_privilege('authenticated', 'private.audit_ecrire(text,text,text,text,text,text,jsonb)', 'EXECUTE')
   OR has_function_privilege('anon', 'private.campaign_send_due()', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'anon n''exécute aucune des fonctions publiques nouvelles', 'false',
  (has_function_privilege('anon', 'public.campaign_schedule(uuid,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_template_save(uuid,text,text,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_template_archive(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_report(uuid)', 'EXECUTE'))::text);

-- ═══ 2. Modèles ════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-prg-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : écrire un modèle REFUSÉ', '42501',
  $q$SELECT public.campaign_template_save(NULL, 'Rappel', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : écrire un modèle REFUSÉ', '42501',
  $q$SELECT public.campaign_template_save(NULL, 'Rappel', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-prg-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'nom trop court → 22023', '22023',
  $q$SELECT public.campaign_template_save(NULL, 'ab', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
SELECT pg_temp.essai(13, 'type inconnu → 22023', '22023',
  $q$SELECT public.campaign_template_save(NULL, 'Rappel', 'spam', 'Rappel', 'Un texte de banc assez long.')$q$);
SELECT pg_temp.essai(14, 'texte trop court → 22023', '22023',
  $q$SELECT public.campaign_template_save(NULL, 'Rappel', 'official_info', 'Rappel', 'court')$q$);
SELECT pg_temp.essai(15, 'crée un modèle', 'OK',
  $q$INSERT INTO ids SELECT 't1', public.campaign_template_save(NULL, 'Rappel mensuel', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
SELECT pg_temp.essai(16, 'même nom, casse différente → 55000', '55000',
  $q$SELECT public.campaign_template_save(NULL, 'RAPPEL MENSUEL', 'official_info', 'Autre', 'Un autre texte de banc long.')$q$);
SELECT pg_temp.essai(17, 'modifie le modèle', 'OK',
  $q$SELECT public.campaign_template_save((SELECT v FROM ids WHERE k = 't1'), 'Rappel mensuel', 'official_info', 'Rappel 2', 'Un texte de banc assez long, v2.')$q$);
SELECT pg_temp.essai(18, 'modèle inconnu → P0002', 'P0002',
  $q$SELECT public.campaign_template_save('00000000-0000-0000-0000-0000000000ff', 'Rappel x', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
SELECT pg_temp.verifie(19, 'lit le modèle', '1', (SELECT count(*)::text FROM public.campaign_templates WHERE title = 'Rappel 2'));
SELECT pg_temp.essai(20, 'archive le modèle', 'OK',
  $q$SELECT public.campaign_template_archive((SELECT v FROM ids WHERE k = 't1'))$q$);
SELECT pg_temp.essai(21, 'archiver deux fois → P0002', 'P0002',
  $q$SELECT public.campaign_template_archive((SELECT v FROM ids WHERE k = 't1'))$q$);
SELECT pg_temp.essai(22, 'le nom d''un modèle archivé se réutilise', 'OK',
  $q$SELECT public.campaign_template_save(NULL, 'Rappel mensuel', 'official_info', 'Rappel', 'Un texte de banc assez long.')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(23, 'un membre ne lit aucun modèle', '0', (SELECT count(*)::text FROM public.campaign_templates));
RESET ROLE;

-- ═══ 3. Programmer ═════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-prg-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'auteur rédige k1 (promotionnel)', 'OK',
  $q$INSERT INTO ids SELECT 'k1', public.campaign_save(NULL, 'promotional', 'Programmée', 'Un message de banc programmé.', '{"kind":"country","country":"BancLandP"}'::jsonb)$q$);
SELECT pg_temp.essai(31, 'dans 1 minute → 22023', '22023',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '1 minute')$q$);
SELECT pg_temp.essai(32, 'dans 100 jours → 22023', '22023',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '100 days')$q$);
SELECT pg_temp.essai(33, 'dans le passé → 22023', '22023',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() - interval '1 hour')$q$);
SELECT pg_temp.essai(34, 'programme dans 1 heure', 'OK',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '1 hour')$q$);
SELECT pg_temp.essai(35, 'efface la programmation', 'OK',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), NULL)$q$);
SELECT pg_temp.essai(36, 'reprogramme dans 1 heure', 'OK',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '1 hour')$q$);
SELECT pg_temp.essai(37, 'campagne inconnue → P0002', 'P0002',
  $q$SELECT public.campaign_schedule('00000000-0000-0000-0000-0000000000ff', now() + interval '1 hour')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(38, 'autre rédacteur : programmer le brouillon de l''auteur REFUSÉ', '42501',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '2 hours')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(39, 'ordinaire : programmer REFUSÉ', '42501',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '2 hours')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-prg-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'soumet k1', 'OK', $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k1'))$q$);
SELECT pg_temp.essai(41, 'programmer un message déjà soumis → 55000', '55000',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k1'), now() + interval '3 hours')$q$);
RESET ROLE;

-- ═══ 4. L'approbation porte sur l'heure ════════════════════════════════════
UPDATE public.campaigns SET scheduled_at = now() + interval '1 minute' WHERE id = (SELECT v FROM ids WHERE k = 'k1');
SELECT pg_temp.moi('banc-prg-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(45, 'approuver une heure trop proche ou passée → 22023', '22023',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
RESET ROLE;
UPDATE public.campaigns SET scheduled_at = now() + interval '1 hour' WHERE id = (SELECT v FROM ids WHERE k = 'k1');
SELECT pg_temp.moi('banc-prg-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(46, 'approuve k1 (heure dans 1 heure)', 'OK',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
SELECT pg_temp.essai(47, 'envoi MANUEL d''une campagne programmée avant son heure → 55000', '55000',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'))$q$);
RESET ROLE;

-- ═══ 5. La tâche : seulement du programmé, approuvé, échu ══════════════════
SELECT pg_temp.verifie(50, 'avant l''heure : la tâche n''envoie rien', '0/0',
  (SELECT private.campaign_send_due()::text || '/' ||
          (SELECT count(*) FROM public.notifications WHERE data ->> 'campaign' = (SELECT v::text FROM ids WHERE k = 'k1'))::text));

-- Une campagne qui n'est PAS approuvée, même échue, ne part jamais.
SELECT pg_temp.moi('banc-prg-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'auteur rédige k4 (jamais approuvée)', 'OK',
  $q$INSERT INTO ids SELECT 'k4', public.campaign_save(NULL, 'promotional', 'Pas approuvée', 'Un message de banc jamais approuvé.', '{"kind":"country","country":"BancLandP"}'::jsonb)$q$);
RESET ROLE;
UPDATE public.campaigns SET scheduled_at = now() - interval '1 hour' WHERE id = (SELECT v FROM ids WHERE k = 'k4');

-- k1 : l'heure vient.
UPDATE public.campaigns SET scheduled_at = now() - interval '1 minute' WHERE id = (SELECT v FROM ids WHERE k = 'k1');
SELECT pg_temp.verifie(52, 'à l''heure : la tâche traite 1 campagne (k1) et pas k4', '1',
  (SELECT private.campaign_send_due()::text));
SELECT pg_temp.verifie(53, 'k1 envoyée : 1 notification (r1), 2 ignorés pour préférences, banni exclu', 'sent/1/2/3',
  (SELECT c.status || '/' ||
          (SELECT count(*) FROM public.campaign_recipients WHERE campaign_id = c.id AND status = 'created') || '/' ||
          (SELECT count(*) FROM public.campaign_recipients WHERE campaign_id = c.id AND status = 'skipped_pref') || '/' ||
          (SELECT count(*) FROM public.campaign_recipients WHERE campaign_id = c.id)
     FROM public.campaigns c WHERE c.id = (SELECT v FROM ids WHERE k = 'k1')));
SELECT pg_temp.verifie(54, 'k4 (jamais approuvée) est restée intacte', 'draft/0',
  (SELECT c.status || '/' || (SELECT count(*) FROM public.notifications WHERE data ->> 'campaign' = c.id::text)
     FROM public.campaigns c WHERE c.id = (SELECT v FROM ids WHERE k = 'k4')));
SELECT pg_temp.verifie(55, 'second passage : rien à faire, aucun doublon', '0/1',
  (SELECT private.campaign_send_due()::text || '/' ||
          (SELECT count(*) FROM public.notifications WHERE data ->> 'campaign' = (SELECT v::text FROM ids WHERE k = 'k1'))::text));
SELECT pg_temp.verifie(56, 'l''audit de la tâche est écrit sous « system:cron » (début + fin)', '2',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE admin_id = 'system:cron' AND target_id = (SELECT v::text FROM ids WHERE k = 'k1')
      AND action IN ('CAMPAIGN_SEND_STARTED', 'CAMPAIGN_SENT')));

-- ═══ 6. Rapport ════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-prg-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(60, 'rapport de k1 : 1 créée, 2 ignorées, 0 restant, 1 joignable par push, départ mesuré', '1/2/0/1/true',
  (SELECT (r ->> 'created') || '/' || (r ->> 'skipped_pref') || '/' || (r ->> 'remaining') || '/' ||
          (r ->> 'reachable_by_push') || '/' || ((r ->> 'start_delay_seconds') IS NOT NULL)::text
     FROM (SELECT public.campaign_report((SELECT v FROM ids WHERE k = 'k1')) AS r) x));
RESET ROLE;
SELECT pg_temp.moi('banc-prg-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(61, 'ordinaire : lire un rapport REFUSÉ', '42501',
  $q$SELECT public.campaign_report((SELECT v FROM ids WHERE k = 'k1'))$q$);
RESET ROLE;

-- ═══ 7. L'envoi manuel d'une campagne SANS heure n'a pas changé ════════════
SELECT pg_temp.moi('banc-prg-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'auteur rédige k3 (sécurité, sans heure)', 'OK',
  $q$INSERT INTO ids SELECT 'k3', public.campaign_save(NULL, 'security', 'Alerte', 'Changez votre mot de passe bientôt.', '{"kind":"country","country":"BancLandP"}'::jsonb)$q$);
SELECT pg_temp.essai(71, 'auteur soumet k3', 'OK', $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k3'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(72, 'super2 approuve k3', 'OK', $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k3'), 'approve')$q$);
SELECT pg_temp.verifie(73, 'envoi manuel : 3 notifiés (la sécurité ignore les préférences), envoyée', '3/sent',
  (SELECT (r ->> 'created') || '/' || (r ->> 'status')
     FROM (SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k3'), 500) AS r) x));
RESET ROLE;
SELECT pg_temp.verifie(74, 'envoi manuel audité sous le nom de l''administrateur, pas du cron', '2',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE admin_id = 'banc-prg-super2' AND target_id = (SELECT v::text FROM ids WHERE k = 'k3')
      AND action IN ('CAMPAIGN_SEND_STARTED', 'CAMPAIGN_SENT')));

-- ═══ 8. Annuler une campagne programmée ════════════════════════════════════
SELECT pg_temp.moi('banc-prg-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(80, 'auteur rédige et programme k5, la soumet', 'OK',
  $q$INSERT INTO ids SELECT 'k5', public.campaign_save(NULL, 'official_info', 'À annuler', 'Un message de banc qui sera annulé.', '{"kind":"country","country":"BancLandP"}'::jsonb)$q$);
SELECT pg_temp.essai(81, 'programme', 'OK',
  $q$SELECT public.campaign_schedule((SELECT v FROM ids WHERE k = 'k5'), now() + interval '2 hours')$q$);
SELECT pg_temp.essai(82, 'soumet', 'OK', $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k5'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-prg-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(83, 'approuve', 'OK', $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k5'), 'approve')$q$);
SELECT pg_temp.essai(84, 'annule avant l''heure', 'OK',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k5'), 'Erreur de ciblage détectée')$q$);
RESET ROLE;
UPDATE public.campaigns SET scheduled_at = now() - interval '1 minute' WHERE id = (SELECT v FROM ids WHERE k = 'k5');
SELECT pg_temp.verifie(85, 'même échue, une campagne annulée ne part pas', '0/cancelled',
  (SELECT private.campaign_send_due()::text || '/' || (SELECT status FROM public.campaigns WHERE id = (SELECT v FROM ids WHERE k = 'k5'))));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
