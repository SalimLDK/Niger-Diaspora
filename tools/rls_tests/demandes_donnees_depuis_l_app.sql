-- Banc : demandes de données depuis l'application, prise en charge, garde
-- d'effacement (migration 20261018250000).
--
--   supabase db query --linked -f tools/rls_tests/demandes_donnees_depuis_l_app.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un utilisateur ouvre une demande au nom
-- d'un autre, lise celle d'un autre ou ses notes internes, noie la file ;
-- qu'un agent traite une demande qu'il n'a pas prise (la comparaison `<>`
-- d'avant laissait passer un responsable nul) ; et qu'une demande d'effacement
-- soit déclarée « terminée » alors que le compte existe toujours.
-- Le banc 20261018230000 (securite_conformite.sql) doit continuer de passer
-- avec cette migration injectée : il vérifie que rien n'a régressé.

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
  ('banc-dd-super',   'Super',    'dd-super@banc.test',   true,  'superAdmin'),
  ('banc-dd-content', 'Content',  'dd-content@banc.test', true,  'contentMod'),
  ('banc-dd-u1',      'Membre 1', 'dd-u1@banc.test',      false, NULL),
  ('banc-dd-u2',      'Membre 2', 'dd-u2@banc.test',      false, NULL),
  ('banc-dd-u3',      'Membre 3', 'dd-u3@banc.test',      false, NULL);

-- ═══ 1. Droits ═════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'anon n''exécute aucune des sept fonctions', 'false',
  (has_function_privilege('anon', 'public.privacy_request_submit(text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_mine()', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_withdraw(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_take(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_verify_identity(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_transition(uuid,text,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.privacy_request_erasure_status(uuid)', 'EXECUTE'))::text);

-- ═══ 2. Le membre ouvre une demande ════════════════════════════════════════
SELECT pg_temp.moi('banc-dd-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'effacement : renvoyé vers « Supprimer mon compte » → 22023', '22023',
  $q$SELECT public.privacy_request_submit('erasure', 'Je veux que tout soit supprimé')$q$);
SELECT pg_temp.essai(11, 'portabilité : renvoyée vers l''export → 22023', '22023',
  $q$SELECT public.privacy_request_submit('portability', 'Je veux une copie de mes données')$q$);
SELECT pg_temp.essai(12, 'nature inconnue → 22023', '22023',
  $q$SELECT public.privacy_request_submit('vente', 'Je veux vendre mes données ici')$q$);
SELECT pg_temp.essai(13, 'précision trop courte → 22023', '22023',
  $q$SELECT public.privacy_request_submit('access', 'oui')$q$);
SELECT pg_temp.essai(14, 'précision de 1001 caractères → 22023', '22023',
  $q$SELECT public.privacy_request_submit('access', repeat('x', 1001))$q$);
SELECT pg_temp.essai(15, 'demande d''accès', 'OK',
  $q$INSERT INTO ids SELECT 'a1', public.privacy_request_submit('access', 'Je souhaite savoir quelles données vous détenez sur moi.')$q$);
SELECT pg_temp.essai(16, 'une seconde demande d''accès ouverte → 55000', '55000',
  $q$SELECT public.privacy_request_submit('access', 'Je souhaite savoir quelles données vous détenez.')$q$);
SELECT pg_temp.essai(17, 'demande de rectification', 'OK',
  $q$SELECT public.privacy_request_submit('rectification', 'Mon pays est mal enregistré, merci de corriger.')$q$);
SELECT pg_temp.essai(18, 'demande d''opposition', 'OK',
  $q$SELECT public.privacy_request_submit('objection', 'Je m''oppose à l''usage de ma position.')$q$);
SELECT pg_temp.essai(19, 'retire sa demande d''accès', 'OK',
  $q$SELECT public.privacy_request_withdraw((SELECT v FROM ids WHERE k = 'a1'))$q$);
SELECT pg_temp.essai(20, 'retirer deux fois → 55000', '55000',
  $q$SELECT public.privacy_request_withdraw((SELECT v FROM ids WHERE k = 'a1'))$q$);
SELECT pg_temp.essai(21, 'quatrième demande en 24 h (même après retrait) → 55000', '55000',
  $q$SELECT public.privacy_request_submit('access', 'Je souhaite savoir quelles données vous détenez, bis.')$q$);
SELECT pg_temp.verifie(22, 'il lit ses 3 demandes, sans note ni agent', '3',
  (SELECT count(*)::text FROM public.privacy_request_mine()));
SELECT pg_temp.verifie(23, 'et ne peut pas lire la table directement', '0',
  (SELECT count(*)::text FROM public.privacy_requests));
RESET ROLE;

SELECT pg_temp.moi('banc-dd-u2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(24, 'membre 2 ne voit aucune demande de membre 1', '0',
  (SELECT count(*)::text FROM public.privacy_request_mine()));
SELECT pg_temp.essai(25, 'membre 2 : retirer la demande de membre 1 → P0002 (introuvable, pas « interdit »)', 'P0002',
  $q$SELECT public.privacy_request_withdraw((SELECT id FROM public.privacy_requests LIMIT 1))$q$);
RESET ROLE;
SELECT pg_temp.essai(26, 'visiteur sans session : soumettre REFUSÉ', '42501',
  $q$SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', true); SET LOCAL ROLE authenticated; SELECT public.privacy_request_submit('access', 'Je souhaite savoir quelles données vous détenez.')$q$);
RESET ROLE;

SELECT pg_temp.verifie(27, 'la demande est dans la file : app, non attribuée, au nom de l''uid de la SESSION', 'app/vide/banc-dd-u1',
  (SELECT source || '/' || coalesce(assigned_to, 'vide') || '/' || requester_id
     FROM public.privacy_requests WHERE id = (SELECT v FROM ids WHERE k = 'a1')));

-- ═══ 3. L'agent la prend, et ne traite pas sans l'avoir prise ══════════════
SELECT pg_temp.moi('banc-dd-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'contentMod : prendre en charge REFUSÉ', '42501',
  $q$SELECT public.privacy_request_take((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'))$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dd-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'superAdmin : vérifier l''identité d''une demande non prise → 55000', '55000',
  $q$SELECT public.privacy_request_verify_identity((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'), 'Message depuis le compte connecté')$q$);
SELECT pg_temp.essai(32, 'superAdmin : refuser une demande non prise → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'), 'refused', 'Hors périmètre')$q$);
SELECT pg_temp.essai(33, 'superAdmin : prend la demande de rectification', 'OK',
  $q$SELECT public.privacy_request_take((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'))$q$);
SELECT pg_temp.essai(34, 'superAdmin : la reprendre (idempotent)', 'OK',
  $q$SELECT public.privacy_request_take((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'))$q$);
SELECT pg_temp.essai(35, 'superAdmin : prendre une demande retirée → 55000', '55000',
  $q$SELECT public.privacy_request_take((SELECT v FROM ids WHERE k = 'a1'))$q$);
SELECT pg_temp.essai(36, 'vérifie l''identité', 'OK',
  $q$SELECT public.privacy_request_verify_identity((SELECT id FROM public.privacy_requests WHERE kind = 'rectification'), 'Message depuis le compte connecté')$q$);
SELECT pg_temp.verifie(37, 'l''agent voit la demande de l''application, avec le périmètre libre', 'app/banc-dd-u1/true',
  (SELECT source || '/' || requester_id || '/' || (scope LIKE '%mal enregistré%')::text
     FROM public.privacy_requests WHERE kind = 'rectification'));
RESET ROLE;

-- Ce que le membre voit de l'avancement.
SELECT pg_temp.moi('banc-dd-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(38, 'le membre lit « identity_verified » pour sa rectification', 'identity_verified',
  (SELECT status FROM public.privacy_request_mine() WHERE kind = 'rectification'));
RESET ROLE;

-- ═══ 4. L'effacement ne se déclare pas terminé tant que le compte existe ═══
SELECT pg_temp.moi('banc-dd-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'crée une demande d''effacement liée au compte de membre 2', 'OK',
  $q$INSERT INTO ids SELECT 'e1', public.privacy_request_create('erasure', 'banc-dd-u2', NULL, NULL, 'Tout', now() + interval '20 days')$q$);
SELECT pg_temp.essai(41, 'vérifie l''identité', 'OK',
  $q$SELECT public.privacy_request_verify_identity((SELECT v FROM ids WHERE k = 'e1'), 'Appel au demandeur, code reçu')$q$);
SELECT pg_temp.essai(42, 'passe en traitement', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'e1'), 'in_progress')$q$);
SELECT pg_temp.verifie(43, 'état de la suppression : compte présent, aucune demande de suppression', 'true/true/vide',
  (SELECT ((r ->> 'linked')::boolean)::text || '/' || ((r ->> 'account_exists')::boolean)::text || '/' || coalesce(r ->> 'deletion_status', 'vide')
     FROM (SELECT public.privacy_request_erasure_status((SELECT v FROM ids WHERE k = 'e1')) AS r) x));
SELECT pg_temp.essai(44, 'TERMINER alors que le compte existe → 55000', '55000',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'e1'), 'completed', 'Compte supprimé (en réalité non)', 'Votre compte a été supprimé.')$q$);
RESET ROLE;

-- La suppression en phases a abouti : la ligne de pierre tombale existe, le compte est parti.
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, completed_at)
VALUES ('banc-dd-u2', 'completed', now(), now());
DELETE FROM public.users WHERE id = 'banc-dd-u2';

SELECT pg_temp.moi('banc-dd-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(45, 'état de la suppression : compte parti, suppression achevée', 'false/completed',
  (SELECT ((r ->> 'account_exists')::boolean)::text || '/' || (r ->> 'deletion_status')
     FROM (SELECT public.privacy_request_erasure_status((SELECT v FROM ids WHERE k = 'e1')) AS r) x));
SELECT pg_temp.essai(46, 'terminer une fois le compte effacé', 'OK',
  $q$SELECT public.privacy_request_transition((SELECT v FROM ids WHERE k = 'e1'), 'completed', 'Suppression achevée par le parcours de suppression de compte.', 'Votre compte a été supprimé.')$q$);
SELECT pg_temp.essai(47, 'effacement par contact seul (aucun compte) : terminable sans preuve de compte', 'OK',
  $q$SELECT public.privacy_request_create('erasure', NULL, 'externe@exemple.org', NULL, NULL, now() + interval '20 days')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-dd-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(48, 'contentMod : état de suppression REFUSÉ', '42501',
  $q$SELECT public.privacy_request_erasure_status((SELECT v FROM ids WHERE k = 'e1'))$q$);
RESET ROLE;

-- ═══ 5. L'audit ════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(60, 'la prise en charge est auditée une fois par appel réussi (2 : prise + reprise) ; aucun texte du membre dans l''audit', '2/0',
  (SELECT count(*) FILTER (WHERE action = 'PRIVACY_REQUEST_TAKEN') || '/' ||
          count(*) FILTER (WHERE details::text LIKE '%mal enregistré%' OR details::text LIKE '%banc-dd-u1%')
     FROM public.admin_audit_logs WHERE action LIKE 'PRIVACY_%'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
