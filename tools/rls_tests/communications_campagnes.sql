-- Banc : campagnes de communication (migration 20261018210000).
--
--   supabase db query --linked -f tools/rls_tests/communications_campagnes.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`. Le
-- ROLLBACK annule aussi les entrées `net.http_request_queue` posées par
-- `trg_notify_push` : aucun push ne part pendant l'essai.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un message de masse parte sans
-- approbation, soit approuvé par son propre auteur, notifie des comptes qui
-- l'ont refusé (ou qui sont bannis), soit envoyé deux fois à la même
-- personne, ou continue après son annulation ; et qu'un écran annonce un envoi
-- qui n'a pas eu lieu. L'audience est un pays fictif « BancLand » : les
-- comptes réels ne sont jamais visés.

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
  ('banc-cmp-super',   'Super',    'cmp-super@banc.test',   true,  'superAdmin'),
  ('banc-cmp-super2',  'Super 2',  'cmp-super2@banc.test',  true,  'superAdmin'),
  ('banc-cmp-auteur',  'Auteur',   'cmp-auteur@banc.test',  true,  'contentMod'),
  ('banc-cmp-autre',   'Autre',    'cmp-autre@banc.test',   true,  'contentMod'),
  ('banc-cmp-finance', 'Finance',  'cmp-fin@banc.test',     true,  'financeMod'),
  ('banc-cmp-ordi',    'Ordi',     'cmp-ordi@banc.test',    false, NULL),
  ('banc-cmp-r1',      'Normal',   'cmp-r1@banc.test',      false, NULL),
  ('banc-cmp-r2',      'Coupé',    'cmp-r2@banc.test',      false, NULL),
  ('banc-cmp-r3',      'Sans système', 'cmp-r3@banc.test',  false, NULL),
  ('banc-cmp-r4',      'Banni',    'cmp-r4@banc.test',      false, NULL),
  ('banc-cmp-r5',      'Ailleurs', 'cmp-r5@banc.test',      false, NULL);
UPDATE public.users SET country_code = 'BancLand' WHERE id IN ('banc-cmp-r1', 'banc-cmp-r2', 'banc-cmp-r3', 'banc-cmp-r4');
UPDATE public.users SET country_code = 'Ailleurs' WHERE id = 'banc-cmp-r5';
UPDATE public.users SET notifications_enabled = false WHERE id = 'banc-cmp-r2';
UPDATE public.users SET notification_prefs = '{"system_messages": "false"}'::jsonb WHERE id = 'banc-cmp-r3';
UPDATE public.users SET is_banned = true WHERE id = 'banc-cmp-r4';

-- ═══ 1. Catalogue, droits, ancien chemin fermé ═════════════════════════════
SELECT pg_temp.verifie(1, 'view/create au catalogue, contentMod les porte, send non ; financeMod rien', '2/2/0/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('communications.view', 'communications.create')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission IN ('communications.view', 'communications.create')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission = 'communications.send') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod' AND permission LIKE 'communications.%'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune RPC ; authenticated n''appelle pas les aides internes', 'false',
  (has_function_privilege('anon', 'public.campaign_save(uuid,text,text,text,jsonb)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_submit(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_review(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_send_batch(uuid,integer)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_cancel(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.campaign_audience_count(uuid)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'public.campaign_audience_ids(jsonb)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'public.campaign_audience_check(jsonb)', 'EXECUTE'))::text);
SELECT pg_temp.moi('banc-cmp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(3, 'superAdmin : l''ancien INSERT admin_notifications (qui ne livrait rien) est REFUSÉ', '42501',
  $q$INSERT INTO public.admin_notifications (sent_by, title, body) VALUES ('banc-cmp-super', 'x', 'y')$q$);
RESET ROLE;
SELECT pg_temp.essai(4, 'personne n''écrit campaigns directement', '42501',
  $q$SET LOCAL ROLE authenticated; INSERT INTO public.campaigns (type, title, body, audience, author_id) VALUES ('promotional','abc','corps de dix car', '{"kind":"all"}', 'x')$q$);
RESET ROLE;

-- ═══ 2. Rédiger : refus et validations ═════════════════════════════════════
SELECT pg_temp.moi('banc-cmp-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : rédiger REFUSÉ', '42501',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'Un texte assez long.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : rédiger REFUSÉ', '42501',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'Un texte assez long.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-cmp-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'auteur : type inconnu → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'spam', 'Titre', 'Un texte assez long.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(13, 'auteur : titre trop court → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'ab', 'Un texte assez long.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(14, 'auteur : texte trop court → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'court', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(15, 'auteur : texte de 301 caractères → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', repeat('x', 301), '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(16, 'auteur : audience inconnue → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'Un texte assez long.', '{"kind":"tous les admins"}'::jsonb)$q$);
SELECT pg_temp.essai(17, 'auteur : pays sans nom → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'Un texte assez long.', '{"kind":"country"}'::jsonb)$q$);
SELECT pg_temp.essai(18, 'auteur : 101 comptes → 22023', '22023',
  $q$SELECT public.campaign_save(NULL, 'promotional', 'Titre', 'Un texte assez long.', jsonb_build_object('kind','users','user_ids',(SELECT jsonb_agg('u' || g) FROM generate_series(1,101) g)))$q$);
SELECT pg_temp.essai(19, 'auteur : rédige k1 (promotionnel, BancLand)', 'OK',
  $q$INSERT INTO ids SELECT 'k1', public.campaign_save(NULL, 'promotional', 'Bonjour le BancLand', 'Un message de banc pour le pays fictif.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-cmp-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'autre rédacteur : modifier le brouillon de l''auteur REFUSÉ', '42501',
  $q$SELECT public.campaign_save((SELECT v FROM ids WHERE k = 'k1'), 'promotional', 'Détourné', 'Un texte détourné de banc.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(21, 'autre rédacteur : soumettre le brouillon de l''auteur REFUSÉ', '42501',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k1'))$q$);
RESET ROLE;

-- ═══ 3. Soumettre ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-cmp-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(22, 'auteur : envoyer un brouillon non approuvé REFUSÉ', '42501',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'))$q$);
SELECT pg_temp.essai(23, 'auteur : soumet k1', 'OK',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k1'))$q$);
SELECT pg_temp.essai(24, 'auteur : soumettre deux fois → 55000', '55000',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k1'))$q$);
SELECT pg_temp.essai(25, 'auteur : modifier un message soumis → 55000', '55000',
  $q$SELECT public.campaign_save((SELECT v FROM ids WHERE k = 'k1'), 'promotional', 'Changé', 'Un texte changé de banc.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(26, 'auteur : approuver SON message REFUSÉ (pas de droit d''envoi)', '42501',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-cmp-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(27, 'contentMod : approuver REFUSÉ (communications.send réservé)', '42501',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(28, 'financeMod : approuver REFUSÉ', '42501',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
RESET ROLE;

-- Combien de comptes : les mêmes règles que l'envoi.
SELECT pg_temp.moi('banc-cmp-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(29, 'k1 (promotionnel) : 3 comptes, 2 ont coupé ces messages, 1 sera notifié (banni et autre pays exclus)', '3/2/1',
  (SELECT (r ->> 'total') || '/' || (r ->> 'skipped_pref') || '/' || (r ->> 'will_notify')
     FROM (SELECT public.campaign_audience_count((SELECT v FROM ids WHERE k = 'k1')) AS r) x));
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'ordinaire : compter l''audience REFUSÉ', '42501',
  $q$SELECT public.campaign_audience_count((SELECT v FROM ids WHERE k = 'k1'))$q$);
SELECT pg_temp.verifie(31, 'ordinaire : ne lit aucune campagne', '0', (SELECT count(*)::text FROM public.campaigns));
RESET ROLE;

-- ═══ 4. Séparation auteur / approbateur ════════════════════════════════════
SELECT pg_temp.moi('banc-cmp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(32, 'superAdmin rédige k2', 'OK',
  $q$INSERT INTO ids SELECT 'k2', public.campaign_save(NULL, 'official_info', 'Info officielle', 'Une information officielle de banc.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(33, 'superAdmin soumet k2', 'OK',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k2'))$q$);
SELECT pg_temp.essai(34, 'superAdmin : approuver SON propre message REFUSÉ', '42501',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k2'), 'approve')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(35, 'super2 : décision hors liste → 22023', '22023',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k2'), 'peut-etre')$q$);
SELECT pg_temp.essai(36, 'super2 : refuser sans motif → 22023', '22023',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k2'), 'reject')$q$);
SELECT pg_temp.essai(37, 'super2 : refuse k2 avec motif', 'OK',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k2'), 'reject', 'Formulation à revoir')$q$);
SELECT pg_temp.essai(38, 'super2 : relire un message déjà refusé → 55000', '55000',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k2'), 'approve')$q$);
SELECT pg_temp.essai(39, 'super2 : envoyer un message refusé → 55000', '55000',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k2'))$q$);
RESET ROLE;

-- ═══ 5. Approuver et envoyer k1, par lots ══════════════════════════════════
SELECT pg_temp.moi('banc-cmp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'superAdmin : approuve k1', 'OK',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k1'), 'approve')$q$);
SELECT pg_temp.essai(41, 'superAdmin : lot de 0 → 22023', '22023',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'), 0)$q$);
SELECT pg_temp.essai(42, 'superAdmin : lot de 501 → 22023', '22023',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'), 501)$q$);
SELECT pg_temp.verifie(43, 'premier lot de 2 : 2 traités, 1 notification, 1 reste, en cours d''envoi', '2/1/1/sending',
  (SELECT (r ->> 'processed') || '/' || (r ->> 'created') || '/' || (r ->> 'remaining') || '/' || (r ->> 'status')
     FROM (SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'), 2) AS r) x));
SELECT pg_temp.verifie(44, 'second lot : 1 traité, aucune notification, rien ne reste, envoyée', '1/0/0/sent',
  (SELECT (r ->> 'processed') || '/' || (r ->> 'created') || '/' || (r ->> 'remaining') || '/' || (r ->> 'status')
     FROM (SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'), 200) AS r) x));
SELECT pg_temp.essai(45, 'superAdmin : relancer l''envoi d''une campagne envoyée → 55000 (pas de doublon)', '55000',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k1'))$q$);
RESET ROLE;

SELECT pg_temp.verifie(46, 'k1 : 1 notification créée, 2 ignorés pour préférences, 3 lignes', '1/2/3',
  (SELECT count(*) FILTER (WHERE status = 'created') || '/' || count(*) FILTER (WHERE status = 'skipped_pref') || '/' || count(*)
     FROM public.campaign_recipients WHERE campaign_id = (SELECT v FROM ids WHERE k = 'k1')));
SELECT pg_temp.verifie(47, 'la notification : r1, type system, titre, marqueur de campagne — et une seule', '1/banc-cmp-r1/system/Bonjour le BancLand/true',
  (SELECT count(*) || '/' || min(user_id) || '/' || min(type) || '/' || min(title) ||
          '/' || (min(data ->> 'campaign') = (SELECT v::text FROM ids WHERE k = 'k1'))::text
     FROM public.notifications WHERE data ->> 'campaign' = (SELECT v::text FROM ids WHERE k = 'k1')));
SELECT pg_temp.verifie(48, 'ni le banni, ni l''autre pays, ni les comptes qui ont coupé ne sont notifiés', '0',
  (SELECT count(*)::text FROM public.notifications
    WHERE data ->> 'campaign' = (SELECT v::text FROM ids WHERE k = 'k1')
      AND user_id IN ('banc-cmp-r2', 'banc-cmp-r3', 'banc-cmp-r4', 'banc-cmp-r5')));
SELECT pg_temp.verifie(49, 'k1 : statut envoyée, datée', 'sent/true',
  (SELECT status || '/' || (sent_at IS NOT NULL AND send_started_at IS NOT NULL)::text
     FROM public.campaigns WHERE id = (SELECT v FROM ids WHERE k = 'k1')));

-- ═══ 6. Un message de sécurité ne tient pas compte des préférences ═════════
SELECT pg_temp.moi('banc-cmp-super2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'super2 rédige k3 (sécurité)', 'OK',
  $q$INSERT INTO ids SELECT 'k3', public.campaign_save(NULL, 'security', 'Alerte sécurité', 'Changez votre mot de passe bientôt.', '{"kind":"country","country":"BancLand"}'::jsonb)$q$);
SELECT pg_temp.essai(51, 'super2 soumet k3', 'OK',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k3'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(52, 'superAdmin approuve k3', 'OK',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k3'), 'approve')$q$);
SELECT pg_temp.verifie(53, 'k3 : 3 notifiés d''un coup (les préférences ne retiennent pas la sécurité), banni exclu', '3/0/sent',
  (SELECT (r ->> 'created') || '/' || (r ->> 'remaining') || '/' || (r ->> 'status')
     FROM (SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k3'), 500) AS r) x));
RESET ROLE;

-- ═══ 7. Annuler ════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-cmp-auteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'auteur : rédige k4', 'OK',
  $q$INSERT INTO ids SELECT 'k4', public.campaign_save(NULL, 'promotional', 'À annuler', 'Un message de banc qui sera annulé.', '{"kind":"users","user_ids":["banc-cmp-r1","banc-cmp-r5","inconnu"]}'::jsonb)$q$);
SELECT pg_temp.essai(61, 'auteur : annuler sans motif → 22023', '22023',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k4'), '  ')$q$);
SELECT pg_temp.essai(62, 'auteur : retire son propre brouillon', 'OK',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k4'), 'Finalement inutile')$q$);
SELECT pg_temp.essai(63, 'auteur : annuler deux fois → 55000', '55000',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k4'), 'Finalement inutile')$q$);
SELECT pg_temp.essai(64, 'auteur : rédige k5 et la soumet', 'OK',
  $q$INSERT INTO ids SELECT 'k5', public.campaign_save(NULL, 'promotional', 'En cours', 'Un message de banc qui sera interrompu.', '{"kind":"users","user_ids":["banc-cmp-r1","banc-cmp-r5","inconnu"]}'::jsonb)$q$);
SELECT pg_temp.essai(65, 'auteur : soumet k5', 'OK',
  $q$SELECT public.campaign_submit((SELECT v FROM ids WHERE k = 'k5'))$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(66, 'autre rédacteur : annuler le message de l''auteur REFUSÉ', '42501',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k5'), 'Je ne suis pas d''accord')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-cmp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(67, 'superAdmin approuve k5', 'OK',
  $q$SELECT public.campaign_review((SELECT v FROM ids WHERE k = 'k5'), 'approve')$q$);
SELECT pg_temp.verifie(68, 'k5 : lot de 1 sur 2 comptes valides (l''identifiant inconnu est ignoré) → 1 reste', '1/1/sending',
  (SELECT (r ->> 'created') || '/' || (r ->> 'remaining') || '/' || (r ->> 'status')
     FROM (SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k5'), 1) AS r) x));
SELECT pg_temp.essai(69, 'superAdmin : arrête l''envoi en cours', 'OK',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k5'), 'Erreur de ciblage détectée')$q$);
SELECT pg_temp.essai(70, 'superAdmin : poursuivre l''envoi d''une campagne annulée → 55000', '55000',
  $q$SELECT public.campaign_send_batch((SELECT v FROM ids WHERE k = 'k5'))$q$);
SELECT pg_temp.essai(71, 'superAdmin : annuler une campagne déjà envoyée → 55000', '55000',
  $q$SELECT public.campaign_cancel((SELECT v FROM ids WHERE k = 'k1'), 'Trop tard pour revenir')$q$);
RESET ROLE;
SELECT pg_temp.verifie(72, 'envoi partiel visible : k5 annulée, 1 destinataire déjà notifié', 'cancelled/1',
  (SELECT c.status || '/' || (SELECT count(*) FROM public.campaign_recipients r WHERE r.campaign_id = c.id)
     FROM public.campaigns c WHERE c.id = (SELECT v FROM ids WHERE k = 'k5')));

-- ═══ 8. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(80, 'k1 : rédigée, soumise, approuvée, envoi commencé, envoyée (1 chacun)', '1/1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'CAMPAIGN_DRAFTED') || '/' ||
          count(*) FILTER (WHERE action = 'CAMPAIGN_SUBMITTED') || '/' ||
          count(*) FILTER (WHERE action = 'CAMPAIGN_APPROVED') || '/' ||
          count(*) FILTER (WHERE action = 'CAMPAIGN_SEND_STARTED') || '/' ||
          count(*) FILTER (WHERE action = 'CAMPAIGN_SENT')
     FROM public.admin_audit_logs WHERE target_id = (SELECT v::text FROM ids WHERE k = 'k1')));
SELECT pg_temp.verifie(81, 'k2 refusée : tracée ; aucun envoi tracé', '1/0',
  (SELECT count(*) FILTER (WHERE action = 'CAMPAIGN_REJECTED') || '/' ||
          count(*) FILTER (WHERE action IN ('CAMPAIGN_SEND_STARTED', 'CAMPAIGN_SENT'))
     FROM public.admin_audit_logs WHERE target_id = (SELECT v::text FROM ids WHERE k = 'k2')));
SELECT pg_temp.verifie(82, 'l''audit ne contient ni le titre ni le texte', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id IN (SELECT v::text FROM ids)
      AND (details::text LIKE '%Bonjour le BancLand%' OR details::text LIKE '%message de banc%')));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
