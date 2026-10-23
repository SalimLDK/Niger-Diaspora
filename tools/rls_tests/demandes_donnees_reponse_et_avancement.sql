-- Banc : notification du demandeur, réponse écrite, état des lieux
-- (migration 20261019100000).
--
--   supabase db query --linked -f tools/rls_tests/demandes_donnees_reponse_et_avancement.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`, qui annule
-- aussi les appels pg_net posés par `trg_notify_push` : aucun push ne part.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un aperçu de notification affiché sur un
-- écran verrouillé révèle la nature d'une demande ou son motif ; qu'une
-- demande soit annoncée « traitée » sans réponse écrite ; que la note interne
-- sorte vers le demandeur ; et qu'un état des lieux de données personnelles
-- soit produit avant la vérification d'identité ou pour un agent sans droit.

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
  ('banc-ra-super',   'Super',    'ra-super@banc.test',   true,  'superAdmin'),
  ('banc-ra-content', 'Content',  'ra-content@banc.test', true,  'contentMod'),
  ('banc-ra-u1',      'Membre 1', 'ra-u1@banc.test',      false, NULL),
  ('banc-ra-u2',      'Membre 2', 'ra-u2@banc.test',      false, NULL);

-- ═══ 1. Droits ═════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'anon et authenticated n''appellent ni l''aide de notification ni, pour anon, le reste', 'false',
  (has_function_privilege('authenticated', 'public.privacy_notify_requester(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_notify_requester(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_transition(uuid,text,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_data_summary(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_mine()', 'EXECUTE'))::text);

-- ═══ 2. Une demande d'accès, du dépôt à la réponse ═════════════════════════
SELECT pg_temp.moi('banc-ra-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'le membre dépose une demande d''accès', 'OK',
  $q$INSERT INTO ids SELECT 'a', public.privacy_request_submit('access', 'Je souhaite savoir quelles données vous détenez sur moi.')$q$);
SELECT pg_temp.essai(11, 'le membre dépose une demande de rectification', 'OK',
  $q$INSERT INTO ids SELECT 'r', public.privacy_request_submit('rectification', 'Mon pays est mal enregistré, merci de corriger.')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-ra-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'contentMod : état des lieux REFUSÉ', '42501',
  $q$SELECT public.privacy_request_data_summary((SELECT v FROM ids WHERE k = 'a'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-ra-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'prend la demande d''accès', 'OK',
  $q$SELECT public.privacy_request_take((SELECT v FROM ids WHERE k = 'a'))$q$);
SELECT pg_temp.essai(14, 'état des lieux AVANT la vérification d''identité → 55000', '55000',
  $q$SELECT public.privacy_request_data_summary((SELECT v FROM ids WHERE k = 'a'))$q$);
SELECT pg_temp.essai(15, 'vérifie l''identité', 'OK',
  $q$SELECT public.privacy_request_verify_identity((SELECT v FROM ids WHERE k = 'a'), 'Code reçu sur le compte connecté')$q$);
SELECT pg_temp.verifie(16, 'état des lieux : 15 entrées, nombres seulement', '15/true',
  (SELECT (SELECT count(*) FROM jsonb_object_keys(s))::text || '/' || ((s ->> 'friends') ~ '^[0-9]+$')::text
     FROM (SELECT public.privacy_request_data_summary((SELECT v FROM ids WHERE k = 'a')) AS s) x));
SELECT pg_temp.essai(17, 'passe en traitement', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'a'), 'in_progress')$q$);
SELECT pg_temp.essai(18, 'terminer SANS réponse au demandeur → 22023', '22023',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'a'), 'completed', 'Récapitulatif préparé.')$q$);
SELECT pg_temp.essai(19, 'terminer avec une réponse trop courte → 22023', '22023',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'a'), 'completed', 'Récapitulatif préparé.', 'ok')$q$);
SELECT pg_temp.essai(20, 'termine avec note interne ET réponse', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'a'), 'completed', 'NOTE-INTERNE-SECRETE : récapitulatif préparé.', 'Voici les données que nous détenons : votre profil et vos messages chiffrés.')$q$);
RESET ROLE;

-- ═══ 3. Ce que le demandeur reçoit ═════════════════════════════════════════
SELECT pg_temp.verifie(30, '3 notifications au demandeur (identité, traitement, traitée), type general, titre fixe', '3/general/Votre demande sur vos données',
  (SELECT count(*) || '/' || min(type) || '/' || min(title)
     FROM public.notifications WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'a')));
SELECT pg_temp.verifie(31, 'aperçus neutres : ni « accès », ni la nature, ni la note, ni la réponse', '0',
  (SELECT count(*)::text FROM public.notifications
    WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'a')
      AND (body ILIKE '%accès%' OR body ILIKE '%access%' OR body ILIKE '%SECRETE%' OR body ILIKE '%profil%')));
SELECT pg_temp.verifie(32, 'tous destinés au demandeur', 'banc-ra-u1',
  (SELECT min(user_id) || '' FROM public.notifications WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'a')));

SELECT pg_temp.moi('banc-ra-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(33, 'le demandeur lit la RÉPONSE de sa demande traitée', 'completed/Voici les données que nous détenons : votre profil et vos messages chiffrés.',
  (SELECT status || '/' || answer FROM public.privacy_request_mine() WHERE kind = 'access'));
SELECT pg_temp.verifie(34, 'la rectification, encore ouverte, n''a pas de réponse', 'received/vide',
  (SELECT status || '/' || coalesce(answer, 'vide') FROM public.privacy_request_mine() WHERE kind = 'rectification'));
SELECT pg_temp.verifie(35, 'la note interne n''est lisible nulle part côté demandeur (ni colonne, ni table)', '0',
  (SELECT count(*)::text FROM public.privacy_request_mine() m
    WHERE m.answer ILIKE '%SECRETE%'));
SELECT pg_temp.verifie(36, 'la table reste fermée au demandeur', '0',
  (SELECT count(*)::text FROM public.privacy_requests));
RESET ROLE;
SELECT pg_temp.moi('banc-ra-u2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(37, 'membre 2 ne lit rien', '0', (SELECT count(*)::text FROM public.privacy_request_mine()));
RESET ROLE;

-- ═══ 4. Refus : réponse obligatoire, motif jamais dans l'aperçu ════════════
SELECT pg_temp.moi('banc-ra-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'prend la rectification', 'OK',
  $q$SELECT public.privacy_request_take((SELECT v FROM ids WHERE k = 'r'))$q$);
SELECT pg_temp.essai(41, 'refuser sans réponse au demandeur → 22023', '22023',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'r'), 'refused', 'Hors périmètre')$q$);
SELECT pg_temp.essai(42, 'refuse avec une réponse', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'r'), 'refused', 'MOTIF-JURIDIQUE-INTERNE', 'Nous ne pouvons pas corriger ce champ : il vient de votre profil, modifiable dans les réglages.')$q$);
RESET ROLE;
SELECT pg_temp.verifie(43, 'refus : une notification, aperçu sans le motif', '1/0',
  (SELECT count(*) || '/' || count(*) FILTER (WHERE body ILIKE '%JURIDIQUE%' OR body ILIKE '%corriger%')
     FROM public.notifications WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'r')));
SELECT pg_temp.moi('banc-ra-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(44, 'le demandeur lit la réponse du refus, pas le motif interne', 'refused/true/true',
  (SELECT status || '/' || (answer LIKE 'Nous ne pouvons pas corriger%')::text || '/' || (answer NOT ILIKE '%JURIDIQUE%')::text
     FROM public.privacy_request_mine() WHERE kind = 'rectification'));
RESET ROLE;

-- ═══ 5. Sans notification : retrait par le demandeur, demande sans compte ══
SELECT pg_temp.moi('banc-ra-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'le demandeur retire une nouvelle demande', 'OK',
  $q$INSERT INTO ids SELECT 'o', public.privacy_request_submit('objection', 'Je m''oppose à l''usage de ma position.')$q$);
SELECT pg_temp.essai(51, 'il la retire lui-même', 'OK',
  $q$SELECT public.privacy_request_withdraw((SELECT v FROM ids WHERE k = 'o'))$q$);
RESET ROLE;
SELECT pg_temp.verifie(52, 'son propre retrait ne le notifie pas', '0',
  (SELECT count(*)::text FROM public.notifications WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'o')));

SELECT pg_temp.moi('banc-ra-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(53, 'demande par contact seul, sans compte', 'OK',
  $q$INSERT INTO ids SELECT 'c', public.privacy_request_create('access', NULL, 'externe@exemple.org', NULL, NULL, now() + interval '20 days')$q$);
SELECT pg_temp.essai(54, 'état des lieux d''une demande sans compte → 22023', '22023',
  $q$SELECT public.privacy_request_data_summary((SELECT v FROM ids WHERE k = 'c'))$q$);
SELECT pg_temp.essai(55, 'l''annuler sans réponse (aucun compte à qui répondre)', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'c'), 'cancelled', 'Doublon d''un courriel déjà traité')$q$);
RESET ROLE;
SELECT pg_temp.verifie(56, 'aucune notification pour une demande sans compte', '0',
  (SELECT count(*)::text FROM public.notifications WHERE data ->> 'privacy_request' = (SELECT v::text FROM ids WHERE k = 'c')));

-- ═══ 6. Audit : jamais les textes ══════════════════════════════════════════
SELECT pg_temp.verifie(60, 'ni la réponse, ni la note interne, ni le motif dans l''audit', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id IN (SELECT v::text FROM ids)
      AND (details::text ILIKE '%SECRETE%' OR details::text ILIKE '%JURIDIQUE%'
           OR details::text ILIKE '%profil%' OR details::text ILIKE '%corriger%')));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
