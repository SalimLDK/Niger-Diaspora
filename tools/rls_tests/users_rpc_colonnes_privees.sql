-- Banc : les trois RPC de lecture de `users` (migration 20260921080000).
--
--   supabase db query --linked -f tools/rls_tests/users_rpc_colonnes_privees.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant. Sans la migration, les fonctions n'existent pas : tout cas qui
-- les appelle tombe en 42883, et le banc le montre.
--
-- CE QU'IL VÉRIFIE, AU-DELÀ DU « ÇA MARCHE ». Ces fonctions sont
-- `SECURITY DEFINER` : elles contournent le RLS. Le danger n'est pas qu'elles
-- rendent trop peu, c'est qu'elles rendent PLUS que `users_select`. Le banc
-- vise donc surtout les exclusions — consentement coupé, profil privé, profil
-- invisible, non-administrateur, `anon`.
--
-- LES PROFILS D'ESSAI sont posés près du pôle Nord (89° N, 179° E) : aucun
-- vrai compte n'y tombe, donc chaque décompte est exact et ne dépend pas de
-- l'état de la production. Ils sont annulés par le `ROLLBACK`, pays et ville
-- laissés vides pour que les déclencheurs de groupe de ville n'aient rien à
-- faire.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

-- Un administrateur RÉEL : on ne peut pas en fabriquer un, le déclencheur
-- `users_guard_admin_flags` refuse toute écriture de `is_admin` hors
-- super-admin — y compris au propriétaire de la table.
INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin LIMIT 1;

-- @@MIGRATION@@

-- ── Les profils d'essai ────────────────────────────────────────────────────
INSERT INTO public.users
       (id, display_name, email, share_location, is_visible, is_private,
        latitude, longitude, location_updated_at)
VALUES
  -- L'appelant : privé, partage sa position. Doit se voir lui-même.
  ('banc-1b-appelant',   'Appelant',     'appelant@banc', true,  true,  true,  89.00, 179.00, now()),
  -- LE cas : a coupé le partage. Ne doit JAMAIS sortir.
  ('banc-1b-refus',      'A dit non',    'refus@banc',    false, true,  false, 89.01, 179.01, now()),
  -- A consenti, visible, public : le seul tiers qui doit sortir.
  ('banc-1b-consent',    'A dit oui',    'oui@banc',      true,  true,  false, 89.02, 179.02, now()),
  -- Consent, mais profil privé : `users_select` le cache déjà.
  ('banc-1b-prive',      'Privé',        'prive@banc',    true,  true,  true,  89.03, 179.03, now()),
  -- Consent, mais invisible.
  ('banc-1b-invisible',  'Invisible',    'invis@banc',    true,  false, false, 89.04, 179.04, now());

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'les trois fonctions existent, en SECURITY DEFINER', '3',
       count(*)::text,
       CASE WHEN count(*) = 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
   AND p.proname IN ('mon_profil_prive', 'positions_partagees', 'profils_admin');

-- `anon` hérite de PUBLIC : s'il n'a pas le droit, PUBLIC non plus.
DO $$
DECLARE refus text := '';
BEGIN
  IF has_function_privilege('anon', 'public.mon_profil_prive()', 'EXECUTE') THEN
    refus := refus || 'mon_profil_prive ';
  END IF;
  IF has_function_privilege('anon',
       'public.positions_partagees(double precision,double precision,double precision,double precision,integer)',
       'EXECUTE') THEN
    refus := refus || 'positions_partagees ';
  END IF;
  IF has_function_privilege('anon', 'public.profils_admin(integer)', 'EXECUTE') THEN
    refus := refus || 'profils_admin ';
  END IF;
  INSERT INTO resultat VALUES (2, 'anon : aucune des trois n''est exécutable', '(aucune)',
    coalesce(nullif(refus, ''), '(aucune)'),
    CASE WHEN refus = '' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN undefined_function THEN
  INSERT INTO resultat VALUES (2, 'anon : aucune des trois n''est exécutable', '(aucune)',
    'fonction absente', 'ÉCHEC');
END $$;

-- ═══ 2. L'appelant (un compte ordinaire, privé) ════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-1b-appelant'))::text, true);
SET LOCAL ROLE authenticated;

-- mon_profil_prive : sa ligne, entière, et seulement elle.
DO $$
DECLARE n bigint; mel text; ident text;
BEGIN
  SELECT count(*), max(email), max(id) INTO n, mel, ident FROM public.mon_profil_prive();
  INSERT INTO resultat VALUES (3, 'mon_profil_prive : une ligne, la SIENNE, e-mail compris',
    '1 · banc-1b-appelant · appelant@banc',
    n::text || ' · ' || coalesce(ident, '∅') || ' · ' || coalesce(mel, '∅'),
    CASE WHEN n = 1 AND ident = 'banc-1b-appelant' AND mel = 'appelant@banc'
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'mon_profil_prive : une ligne, la SIENNE, e-mail compris',
    '1 · banc-1b-appelant · appelant@banc', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- positions_partagees : LE cas du banc.
DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.positions_partagees(88.9, 89.1, 178.9, 179.1);
  INSERT INTO resultat VALUES (4,
    'positions : soi + le seul tiers qui a consenti, visible et public',
    'banc-1b-appelant,banc-1b-consent', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-1b-appelant,banc-1b-consent' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4,
    'positions : soi + le seul tiers qui a consenti, visible et public',
    'banc-1b-appelant,banc-1b-consent', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Détaillé, pour qu'un échec dise LEQUEL a fui.
DO $$
DECLARE fuite text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO fuite
    FROM public.positions_partagees(88.9, 89.1, 178.9, 179.1)
   WHERE id IN ('banc-1b-refus', 'banc-1b-prive', 'banc-1b-invisible');
  INSERT INTO resultat VALUES (5,
    'LE CONSENTEMENT — ni « a dit non », ni privé, ni invisible',
    '(aucune fuite)', coalesce(fuite, '(aucune fuite)'),
    CASE WHEN fuite IS NULL THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5,
    'LE CONSENTEMENT — ni « a dit non », ni privé, ni invisible',
    '(aucune fuite)', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Le témoin de ce que la fonction corrige : la MÊME boîte, lue comme la lit
-- l'app aujourd'hui, mais sans le `.eq('share_location', true)` que le client
-- ajoute de lui-même. « A dit non » y sort. Ce cas MESURE, il n'échoue pas.
DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.users
   WHERE latitude BETWEEN 88.9 AND 89.1 AND longitude BETWEEN 178.9 AND 179.1
     AND id = 'banc-1b-refus';
  INSERT INTO resultat VALUES (6,
    'MESURE — par PostgREST, « a dit non » reste localisable (le trou)',
    'connu : lisible', coalesce(ids, '(invisible)'), 'MESURE');
END $$;

-- La fonction ne rend que 4 colonnes : ni e-mail, ni jetons.
INSERT INTO resultat
SELECT 7, 'positions : le résultat ne porte QUE id, position et date',
       'id,latitude,location_updated_at,longitude',
       coalesce(string_agg(a.attname, ',' ORDER BY a.attname), '(fonction absente)'),
       CASE WHEN string_agg(a.attname, ',' ORDER BY a.attname)
                 = 'id,latitude,location_updated_at,longitude' THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN LATERAL unnest(p.proargnames, p.proargmodes) AS a(attname, mode)
 WHERE n.nspname = 'public' AND p.proname = 'positions_partagees' AND a.mode = 't';

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.positions_partagees(-90, 90, -180, 180, 1000000);
  INSERT INTO resultat VALUES (8, 'positions : plafond de 100 lignes, même si on en demande un million',
    '≤ 100', n::text, CASE WHEN n <= 100 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'positions : plafond de 100 lignes, même si on en demande un million',
    '≤ 100', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- profils_admin : un compte ordinaire est REFUSÉ, pas servi à vide.
DO $$
BEGIN
  PERFORM * FROM public.profils_admin(5);
  INSERT INTO resultat VALUES (9, 'profils_admin : un compte ordinaire est refusé (42501, pas 0 ligne)',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION
  WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (9, 'profils_admin : un compte ordinaire est refusé (42501, pas 0 ligne)',
      'refusé 42501', 'refusé 42501', 'OK');
  WHEN OTHERS THEN
    INSERT INTO resultat VALUES (9, 'profils_admin : un compte ordinaire est refusé (42501, pas 0 ligne)',
      'refusé 42501', 'autre : ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 3. Un tiers : il ne voit pas l'appelant privé ═════════════════════════
-- La branche « soi » de la fonction ne doit servir qu'à soi.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-1b-consent'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.positions_partagees(88.9, 89.1, 178.9, 179.1);
  INSERT INTO resultat VALUES (10,
    'un tiers ne voit PAS l''appelant privé (la branche « soi » ne sert qu''à soi)',
    'banc-1b-consent', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-1b-consent' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10,
    'un tiers ne voit PAS l''appelant privé (la branche « soi » ne sert qu''à soi)',
    'banc-1b-consent', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE ident text;
BEGIN
  SELECT max(id) INTO ident FROM public.mon_profil_prive();
  INSERT INTO resultat VALUES (11, 'mon_profil_prive rend SA ligne à chacun, jamais une autre',
    'banc-1b-consent', coalesce(ident, '∅'),
    CASE WHEN ident = 'banc-1b-consent' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'mon_profil_prive rend SA ligne à chacun, jamais une autre',
    'banc-1b-consent', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 4. Sans identité : rien ═══════════════════════════════════════════════
-- Un rôle `authenticated` sans `firebase_uid` dans le jeton : la garde
-- `firebase_uid() IS NOT NULL` doit tout couper.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE a bigint; b bigint;
BEGIN
  SELECT count(*) INTO a FROM public.mon_profil_prive();
  SELECT count(*) INTO b FROM public.positions_partagees(-90, 90, -180, 180);
  INSERT INTO resultat VALUES (12, 'jeton sans identité : 0 ligne partout',
    '0 · 0', a::text || ' · ' || b::text,
    CASE WHEN a = 0 AND b = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'jeton sans identité : 0 ligne partout',
    '0 · 0', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 5. Le back-office ═════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint; avec_mel bigint;
BEGIN
  SELECT count(*), count(email) INTO n, avec_mel FROM public.profils_admin(20);
  INSERT INTO resultat VALUES (13, 'admin : profils_admin(20) sert 20 lignes, e-mails compris',
    '20 lignes, e-mails présents', n::text || ' lignes, ' || avec_mel::text || ' e-mails',
    CASE WHEN n = 20 AND avec_mel > 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'admin : profils_admin(20) sert 20 lignes, e-mails compris',
    '20 lignes, e-mails présents', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.profils_admin(1000000);
  INSERT INTO resultat VALUES (14, 'admin : plafond de 500 lignes',
    '≤ 500', n::text, CASE WHEN n <= 500 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (14, 'admin : plafond de 500 lignes',
    '≤ 500', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
