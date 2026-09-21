-- Banc : `create_user_notification` — type en liste fermée, blocage, quota
-- (migration 20260921032400).
--
--   supabase db query --linked -f tools/rls_tests/notification_type_et_quota.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- ── AUCUN PUSH N'EST ENVOYÉ, et ce n'est pas une supposition ───────────────
--
-- `notifications` porte `trg_notify_push`, qui appelle `net.http_post`. C'est
-- la file TRANSACTIONNELLE de pg_net : l'appel insère une ligne dans
-- `net.http_request_queue`, et le travailleur de pg_net ne lit que ce qui est
-- COMMITÉ. Un `ROLLBACK` l'annule donc avant tout envoi. Le cas 20 mesure
-- combien d'envois ce banc aurait déclenchés — c'est une mesure, pas un
-- verdict : elle rend visible ce que le `ROLLBACK` retient.
--
-- ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
--
-- Sans la migration, **sept cas tombent** : 0 (pas d'index), 2, 3 et 4 (le
-- type est libre, `system` compris), 10 (le blocage est ignoré), 11 et 12
-- (aucun quota) — mesuré le 2026-09-21.
--
-- Les cas 5 à 9 passaient déjà : ce sont les non-régressions. Le 5 tombait
-- pour la mauvaise raison (contrainte NOT NULL de la colonne, 23502, et non
-- la liste fermée) ; le 9 montre que l'acteur était DÉJÀ pris dans le jeton,
-- ce qui était bien fait et le reste.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',   '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13');

-- Combien d'envois étaient déjà en file avant nous.
INSERT INTO ctx
SELECT 'file_avant', count(*)::text FROM net.http_request_queue;

-- @@MIGRATION@@

-- ═══ 0. L'index du quota ═══════════════════════════════════════════════════
INSERT INTO resultat
SELECT 0, 'un index sert le quota par émetteur', 'présent',
       coalesce(string_agg(indexname, ','), '(absent)'),
       CASE WHEN count(*) > 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_indexes
 WHERE schemaname = 'public' AND tablename = 'notifications'
   AND indexdef LIKE '%actor_id%';

-- ═══ 1. Compte connecté ════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'moi')))::text, true);
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (1, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- Un petit utilitaire : tente un appel et note le verdict.
CREATE OR REPLACE FUNCTION pg_temp.tenter(
  p_n int, p_cas text, p_dest text, p_type text, p_attendu text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  v_id := public.create_user_notification(p_dest, p_type, 'Titre', 'Corps', '{}'::jsonb);
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu,
    CASE WHEN v_id IS NULL THEN 'silencieux (NULL)' ELSE 'ACCEPTÉ' END,
    CASE WHEN (v_id IS NULL AND p_attendu = 'silencieux (NULL)')
            OR (v_id IS NOT NULL AND p_attendu = 'accepté')
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, 'refusé ' || SQLSTATE,
    CASE WHEN p_attendu = 'refusé' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 2. Le type ════════════════════════════════════════════════════════════
SELECT pg_temp.tenter(2, 'LA FAILLE — type « system » (annonce de plateforme)',
  (SELECT v FROM ctx WHERE k = 'autre'), 'system', 'refusé');

SELECT pg_temp.tenter(3, 'LA FAILLE — type « message » (réservé au serveur)',
  (SELECT v FROM ctx WHERE k = 'autre'), 'message', 'refusé');

SELECT pg_temp.tenter(4, 'type inventé',
  (SELECT v FROM ctx WHERE k = 'autre'), 'securite_compte', 'refusé');

DO $$
BEGIN
  PERFORM public.create_user_notification(
    (SELECT v FROM ctx WHERE k = 'autre'), NULL, 'T', 'C', '{}'::jsonb);
  INSERT INTO resultat VALUES (5, 'type absent', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'type absent', 'refusé', 'refusé ' || SQLSTATE, 'OK');
END $$;

SELECT pg_temp.tenter(6, 'type légitime : demande d''ami',
  (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'accepté');

-- Le cas 7 visait `orderPaid`, légitime le matin du 2026-09-21. La migration
-- 20260921100000 a retiré les cinq types de commande (chaîne de paiement
-- fermée des deux côtés : ils ne pouvaient plus servir qu'à des notifications
-- falsifiées) et ajouté `postLiked`, que le relevé du matin avait oublié.
SELECT pg_temp.tenter(7, 'type légitime : j''aime sur une publication',
  (SELECT v FROM ctx WHERE k = 'autre'), 'postLiked', 'accepté');

-- ═══ 3. Destinataire et identité ═══════════════════════════════════════════
SELECT pg_temp.tenter(8, 'destinataire inexistant',
  'banc-destinataire-qui-nexiste-pas', 'friendRequest', 'refusé');

-- L'`actor_id` est celui du JETON, jamais celui qu'on passe dans `p_data`.
--
-- La vérification se fait APRÈS `RESET ROLE` : la policy `notifications_own`
-- réserve la lecture au destinataire, donc l'émetteur ne voit pas la ligne
-- qu'il vient de créer. Lire sous son identité rendait `NULL`, et le cas
-- échouait pour une raison qui n'avait rien à voir avec la faille.
INSERT INTO ctx
SELECT 'notif_acteur', public.create_user_notification(
  (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'T', 'C',
  jsonb_build_object('actor_id', 'un-autre-que-moi'))::text;

RESET ROLE;

INSERT INTO resultat
SELECT 9, 'l''acteur vient du jeton, pas de la requête',
       (SELECT v FROM ctx WHERE k = 'moi'),
       coalesce(n.data->>'actor_id', '(ligne introuvable)'),
       CASE WHEN n.data->>'actor_id' = (SELECT v FROM ctx WHERE k = 'moi')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications n
 WHERE n.id = (SELECT v FROM ctx WHERE k = 'notif_acteur')::uuid;

-- ═══ 4. Le blocage ═════════════════════════════════════════════════════════
RESET ROLE;
INSERT INTO blocked_users (blocker_id, blocked_id)
SELECT (SELECT v FROM ctx WHERE k = 'autre'), (SELECT v FROM ctx WHERE k = 'moi')
ON CONFLICT DO NOTHING;
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'moi')))::text, true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.tenter(10, 'LA FAILLE — notifier quelqu''un qui vous a bloqué',
  (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'silencieux (NULL)');

RESET ROLE;
DELETE FROM blocked_users
 WHERE blocker_id = (SELECT v FROM ctx WHERE k = 'autre')
   AND blocked_id = (SELECT v FROM ctx WHERE k = 'moi');

-- ═══ 5. Les quotas ═════════════════════════════════════════════════════════
-- L'état de départ est fabriqué en écrivant directement : on veut éprouver le
-- quota, pas l'atteindre à coups d'appels.
INSERT INTO notifications (user_id, type, title, body, data, is_read)
SELECT (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'banc', 'banc',
       jsonb_build_object('actor_id', (SELECT v FROM ctx WHERE k = 'moi')), false
  FROM generate_series(1, 12);

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'moi')))::text, true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.tenter(11, 'LA FAILLE — 12 notifications vers la même personne dans l''heure',
  (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'refusé');

RESET ROLE;
INSERT INTO notifications (user_id, type, title, body, data, is_read)
SELECT (SELECT v FROM ctx WHERE k = 'moi'), 'friendRequest', 'banc', 'banc',
       jsonb_build_object('actor_id', (SELECT v FROM ctx WHERE k = 'moi')), false
  FROM generate_series(1, 60);

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'moi')))::text, true);
SET LOCAL ROLE authenticated;

-- Destinataire neuf : seul le quota PAR ÉMETTEUR peut encore mordre.
SELECT pg_temp.tenter(12, 'LA FAILLE — diffusion de masse (quota par émetteur)',
  (SELECT v FROM ctx WHERE k = 'autre'), 'friendRequest', 'refusé');

RESET ROLE;

-- ═══ 6. Ce que le ROLLBACK retient ═════════════════════════════════════════
INSERT INTO resultat
SELECT 20, 'envois que le ROLLBACK annule (mesure, pas verdict)',
       'mesure',
       (count(*) - (SELECT v::bigint FROM ctx WHERE k = 'file_avant'))::text || ' en file',
       'OK'
  FROM net.http_request_queue;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
