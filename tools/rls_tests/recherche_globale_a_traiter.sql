-- Banc : recherche globale et file « à traiter » (migration 20261019230000).
--
--   supabase db query --linked -f tools/rls_tests/recherche_globale_a_traiter.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont : qu'une recherche rende des données d'une
-- source que l'administrateur n'a pas le droit de lire ; qu'un joker (% ou _)
-- du mot cherché ratisse toute la table ; que le mot cherché — souvent un nom
-- de membre — entre dans l'audit ; qu'un membre ordinaire ou anon appelle les
-- deux fonctions ; et que la file « à traiter » compte autre chose que ce qui
-- attend réellement.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE avant(k text, t int, l int);
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

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, handle, email, is_admin, admin_role) VALUES
  ('banc-rch-super',   'Super',    'rchsuper', 'rch-super@banc.test',   true,  'superAdmin'),
  ('banc-rch-mod',     'Mod',      'rchmod',   'rch-mod@banc.test',     true,  'contentMod'),
  ('banc-rch-finance', 'Finance',  'rchfin',   'rch-fin@banc.test',     true,  'financeMod'),
  ('banc-rch-zorg',    'Zorglub Banc', 'zorglubb', 'rch-zorg@banc.test', false, NULL),
  ('banc-rch-autre',   'Autre Membre', 'autrem',   'rch-autre@banc.test', false, NULL);

-- Instantané de la file AVANT les graines : la base réelle a déjà ses attentes.
SELECT pg_temp.moi('banc-rch-super');
SET LOCAL ROLE authenticated;
INSERT INTO avant
  SELECT e ->> 'key', (e ->> 'total')::int, (e ->> 'late')::int
    FROM jsonb_array_elements(public.admin_attention_queue()) e;
RESET ROLE;

SELECT set_config('request.jwt.claims', '', true);  -- graines : sans session applicative
INSERT INTO public.support_tickets (id, user_id, subject, status, user_name, has_unread_user_messages, escalated_at, escalated_by, escalation_reason) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'banc-rch-zorg', 'Zorglub panne', 'open', 'Zorglub Banc', true, NULL, NULL, NULL),
  ('00000000-0000-0000-0000-0000000000a2', 'banc-rch-zorg', 'autre sujet',   'in_progress', 'Zorglub Banc', false, now(), 'banc-rch-mod', 'motif');
INSERT INTO public.reports (id, reporter_id, target_type, target_id, reason, status, target_name, due_at) VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'banc-rch-autre', 'user', 'banc-rch-zorg-1', 'spam',   'pending',   'Zorglub Banc', now() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000b2', 'banc-rch-autre', 'user', 'banc-rch-zorg-2', 'spam',   'pending',   'Zorglub Banc', NULL),
  ('00000000-0000-0000-0000-0000000000b3', 'banc-rch-autre', 'user', 'banc-rch-zorg-3', 'spam',   'resolved',  'Zorglub Banc', NULL);
INSERT INTO public.businesses (id, owner_id, name, description, category, city, country_code) VALUES
  ('00000000-0000-0000-0000-0000000000c1', 'banc-rch-zorg', 'Zorglub Shop', 'd', 'restaurant', 'Niamey', 'Niger');
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, city, organizer_name) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'banc-rch-zorg', 'Zorglub fête', '2031-03-10 18:00+00', 'people', 'draft', 'Niamey', 'Zorglub');
INSERT INTO public.embassies (id, name, country, city, is_verified) VALUES
  ('00000000-0000-0000-0000-0000000000e1', 'Ambassade Zorglub', 'Banclandia', 'Capitale', false);
INSERT INTO public.campaigns (id, type, title, body, audience, status, author_id) VALUES
  ('00000000-0000-0000-0000-0000000000f1', 'promotional', 'Zorglub campagne', 'corps de dix car', '{"kind":"all"}', 'pending_approval', 'banc-rch-mod');

-- ═══ 1. Accès ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'anon n''exécute ni la recherche ni la file', 'false',
  (has_function_privilege('anon', 'public.admin_global_search(text,integer)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.admin_attention_queue()', 'EXECUTE'))::text);

SELECT pg_temp.moi('banc-rch-zorg');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(2, 'un membre ordinaire ne cherche pas', '42501',
  $q$ SELECT public.admin_global_search('Zorglub') $q$);
SELECT pg_temp.essai(3, 'un membre ordinaire ne lit pas la file', '42501',
  $q$ SELECT public.admin_attention_queue() $q$);
RESET ROLE;

-- ═══ 2. Saisie ═════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-rch-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(4, 'un seul caractère refusé', '22023', $q$ SELECT public.admin_global_search('z') $q$);
SELECT pg_temp.essai(5, 'plus de 80 caractères refusé', '22023',
  $q$ SELECT public.admin_global_search(repeat('z', 81)) $q$);
SELECT pg_temp.essai(6, 'vide refusé', '22023', $q$ SELECT public.admin_global_search('   ') $q$);

-- ═══ 3. Ce que le superAdmin trouve ════════════════════════════════════════
SELECT pg_temp.verifie(10, 'super : Zorglub est trouvé dans les 7 sources semées (les démarches ne le sont pas)', 'businesses,campaigns,embassies,events,members,reports,tickets',
  (SELECT string_agg(g ->> 'kind', ',' ORDER BY g ->> 'kind')
     FROM jsonb_array_elements(public.admin_global_search('Zorglub') -> 'groups') g));
SELECT pg_temp.verifie(11, 'super : rien n''est ignoré', '0',
  (SELECT jsonb_array_length(public.admin_global_search('Zorglub') -> 'skipped')::text));
SELECT pg_temp.verifie(12, 'les membres sont trouvés par le pseudo aussi, sans casse', '1',
  (SELECT jsonb_array_length(g -> 'items')::text
     FROM jsonb_array_elements(public.admin_global_search('ZORGLUBB') -> 'groups') g
    WHERE g ->> 'kind' = 'members'));
SELECT pg_temp.verifie(13, 'jamais par le courriel', '0',
  (SELECT count(*)::text
     FROM jsonb_array_elements(public.admin_global_search('rch-zorg@banc') -> 'groups') g
    WHERE g ->> 'kind' = 'members'));
SELECT pg_temp.verifie(14, 'le joker % est une lettre : « %% » ne ratisse rien', '0',
  (public.admin_global_search('%%') ->> 'total'));
SELECT pg_temp.verifie(15, 'le joker _ aussi : « Z_rglub » ne trouve pas Zorglub', '0',
  (public.admin_global_search('Z_rglub') ->> 'total'));
SELECT pg_temp.verifie(16, 'la limite borne chaque groupe', 'true',
  (SELECT (max(jsonb_array_length(g -> 'items')) <= 1)::text
     FROM jsonb_array_elements(public.admin_global_search('Zorglub', 1) -> 'groups') g));
SELECT pg_temp.verifie(17, 'une recherche sans résultat dit searched, pas une erreur', 'true',
  ((public.admin_global_search('introuvableabc') -> 'searched') @> '"members"')::text);
RESET ROLE;

-- ═══ 4. Ce que les autres rôles ne voient pas ═════════════════════════════
SELECT pg_temp.moi('banc-rch-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(20, 'financeMod : ni membres, ni tickets, ni signalements, ni événements', '0',
  (SELECT count(*)::text
     FROM jsonb_array_elements(public.admin_global_search('Zorglub') -> 'groups') g
    WHERE g ->> 'kind' IN ('members', 'tickets', 'reports', 'events')));
SELECT pg_temp.verifie(21, 'financeMod : la réponse dit qu''elle les a ignorés', 'true',
  ((public.admin_global_search('Zorglub') -> 'skipped') @> '["members","tickets","reports","events"]')::text);
RESET ROLE;

SELECT pg_temp.moi('banc-rch-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(22, 'contentMod trouve les tickets et les signalements', 'true',
  (SELECT (count(*) FILTER (WHERE g ->> 'kind' IN ('tickets', 'reports')) = 2)::text
     FROM jsonb_array_elements(public.admin_global_search('Zorglub') -> 'groups') g));
RESET ROLE;

-- ═══ 5. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(30, 'chaque recherche réussie laisse une ligne ADMIN_SEARCH', 'true',
  ((SELECT count(*) FROM public.admin_audit_logs
     WHERE action = 'ADMIN_SEARCH' AND created_at >= now() - interval '1 minute') >= 8)::text);
SELECT pg_temp.verifie(31, 'l''audit ne contient pas le mot cherché', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE action = 'ADMIN_SEARCH' AND created_at >= now() - interval '1 minute'
      AND (details::text ILIKE '%zorglub%' OR details::text ILIKE '%introuvableabc%')));
SELECT pg_temp.verifie(32, 'l''audit porte longueur, sources et nombre de résultats', 'true',
  (SELECT bool_and(details ? 'length' AND details ? 'sources' AND details ? 'results')::text
     FROM public.admin_audit_logs
    WHERE action = 'ADMIN_SEARCH' AND created_at >= now() - interval '1 minute'));

-- ═══ 6. La file « à traiter » ═════════════════════════════════════════════
SELECT pg_temp.moi('banc-rch-super');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE apres AS
  SELECT e ->> 'key' AS k, (e ->> 'total')::int AS t, (e ->> 'late')::int AS l
    FROM jsonb_array_elements(public.admin_attention_queue()) e;
RESET ROLE;
SELECT pg_temp.verifie(40, 'signalements : +2 en attente (le résolu ne compte pas), dont +1 en retard', '2/1',
  (SELECT (a.t - v.t) || '/' || (a.l - v.l) FROM apres a JOIN avant v USING (k) WHERE k = 'reports'));
SELECT pg_temp.verifie(41, 'tickets : +2 à traiter, dont +1 avec message non lu', '2/1',
  (SELECT (a.t - v.t) || '/' || (a.l - v.l) FROM apres a JOIN avant v USING (k) WHERE k = 'tickets'));
SELECT pg_temp.verifie(42, 'tickets escaladés : +1', '1',
  (SELECT (a.t - v.t)::text FROM apres a JOIN avant v USING (k) WHERE k = 'tickets_escalated'));
SELECT pg_temp.verifie(43, 'campagnes à approuver : +1', '1',
  (SELECT (a.t - v.t)::text FROM apres a JOIN avant v USING (k) WHERE k = 'campaigns'));
SELECT pg_temp.verifie(44, 'le superAdmin reçoit au moins les 8 familles sauf celles sans droit', 'true',
  ((SELECT count(*) FROM apres) >= 9)::text);

SELECT pg_temp.moi('banc-rch-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(45, 'financeMod ne reçoit ni signalements, ni tickets, ni vie privée, ni campagnes à approuver', '0',
  (SELECT count(*)::text
     FROM jsonb_array_elements(public.admin_attention_queue()) e
    WHERE e ->> 'key' IN ('reports', 'tickets', 'tickets_escalated', 'privacy', 'campaigns')));
RESET ROLE;

SELECT pg_temp.moi('banc-rch-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(46, 'contentMod ne reçoit pas les campagnes à approuver (réservées à l''envoi)', '0',
  (SELECT count(*)::text
     FROM jsonb_array_elements(public.admin_attention_queue()) e WHERE e ->> 'key' = 'campaigns'));
RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
