-- Banc : `users` fermé à `anon`, intact pour un compte connecté
-- (migration 20260920213600).
--
--   supabase db query --linked -f tools/rls_tests/users_ferme_a_anon.sql
--
-- Condition : 0 cas en ÉCHEC (« SANS OBJET » admis). Tout est dans un
-- `BEGIN … ROLLBACK`, et le banc n'écrit rien qui survive : la seule écriture
-- (cas 9) réécrit une colonne avec sa propre valeur.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : lancé tel quel AVANT la
-- migration, les cas 1, 2, 3, 4, 5 et 12 tombent — vérifié à l'écriture, le
-- 2026-09-20. Les cas 6 à 11 passaient déjà : ils gardent la non-régression,
-- c'est-à-dire qu'un compte connecté ne perd rien.
--
-- Le banc ne sort AUCUNE donnée personnelle : des décomptes et des verdicts.
--
-- Aucun TRUNCATE n'est tenté, même pour le voir refusé : sur une base sans
-- sauvegarde, le droit se lit au catalogue (cas 12).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',   '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13');

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : aucun droit de table sur users', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.users', p);

INSERT INTO resultat
SELECT 2, 'aucune policy de users ne vaut pour anon ou public', '(aucune)',
       coalesce(string_agg(policyname, ',' ORDER BY policyname), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'users'
   AND roles && ARRAY['anon','public']::name[];

-- ═══ 2. Anonyme ═════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims = '{"role":"anon"}';
SET LOCAL ROLE anon;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.users;
  INSERT INTO resultat VALUES (3, 'anon lit users', 'refusé 42501',
    'LU : ' || n || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (3, 'anon lit users', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(email) + count(phone_number) + count(latitude) INTO n FROM public.users;
  INSERT INTO resultat VALUES (4, 'anon lit e-mail, téléphone ou position', 'refusé 42501',
    'LU : ' || n || ' valeur(s)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'anon lit e-mail, téléphone ou position', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET bio = bio WHERE id = (SELECT v FROM ctx WHERE k = 'moi');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (5, 'anon écrit dans users', 'refusé 42501',
    'ACCEPTÉ (' || n || ' ligne)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'anon écrit dans users', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- Ce que l'anonyme DOIT encore pouvoir lire : l'annuaire des ambassades et le
-- référentiel des pays sont publics, et ne doivent rien à `users`.
DO $$
DECLARE n bigint;
BEGIN
  SELECT (SELECT count(*) FROM public.embassies) + (SELECT count(*) FROM public.pays) INTO n;
  INSERT INTO resultat VALUES (6, 'anon lit encore embassies et pays', 'lu', 'lu (' || n || ')', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'anon lit encore embassies et pays', 'lu',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 3. Compte connecté : rien ne change ════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (7, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

DO $$
DECLARE n bigint;
BEGIN
  -- `SELECT *` exprès : c'est ce que fait l'app (`.select()` sans liste). Un
  -- droit par colonnes le ferait tomber en 42501 sur la requête entière.
  SELECT count(*) INTO n
    FROM (SELECT * FROM public.users WHERE id = (SELECT v FROM ctx WHERE k = 'moi')) s;
  INSERT INTO resultat VALUES (8, 'connecté : SELECT * sur sa propre ligne', '1 ligne',
    n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'connecté : SELECT * sur sa propre ligne', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET bio = bio WHERE id = (SELECT v FROM ctx WHERE k = 'moi');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (9, 'connecté : écrit sa propre ligne', '1 ligne',
    n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'connecté : écrit sa propre ligne', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET bio = bio WHERE id = (SELECT v FROM ctx WHERE k = 'autre');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10, 'connecté : n''écrit pas la ligne d''un autre', '0 ligne',
    n || ' ligne(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (10, 'connecté : n''écrit pas la ligne d''un autre', '0 ligne',
    'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint; visibles bigint;
BEGIN
  -- La carte, la recherche et la liste des discussions lisent les profils des
  -- autres : ils doivent rester lisibles.
  SELECT count(*) INTO visibles FROM public.users WHERE NOT is_private;
  SELECT count(*) INTO n FROM public.users
   WHERE id = (SELECT v FROM ctx WHERE k = 'autre');
  INSERT INTO resultat VALUES (11, 'connecté : lit les profils non privés des autres',
    '> 1 profil visible', visibles || ' visible(s), « autre » : ' || n,
    CASE WHEN visibles > 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'connecté : lit les profils non privés des autres',
    '> 1 profil visible', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

INSERT INTO resultat
SELECT 12, 'connecté : ni TRUNCATE, ni REFERENCES, ni TRIGGER', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.users', p);

INSERT INTO resultat
SELECT 13, 'connecté : garde SELECT, INSERT, UPDATE', 'INSERT,SELECT,UPDATE',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['SELECT','INSERT','UPDATE']) p
 WHERE has_table_privilege('authenticated', 'public.users', p);

-- ═══ Rapport ════════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
