-- Banc : les deux RPC du registre admin (migration 20261014123000).
--
--   supabase db query --linked -f tools/rls_tests/registre_admin_rpc.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@CIBLE@@` par le contenu
-- de la migration (`python tools/rls_tests/repeter_cible.py` sait le faire) —
-- c'est la répétition. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- CE QU'IL VÉRIFIE. Les deux fonctions sont `SECURITY DEFINER` : elles
-- contournent le RLS et rendent `email`. Le danger est qu'elles répondent à
-- qui n'est pas superAdmin. Le banc vise donc les refus : `anon`, un compte
-- ordinaire, un contentMod — et vérifie que l'admin fantôme (is_admin sans
-- admin_role) SORT de la liste, parce que c'est ce qu'il faut voir.
--
-- Les comptes d'essai sont insérés par le propriétaire de la table (le
-- déclencheur `users_guard_admin_flags` laisse passer sans session
-- applicative), puis annulés par le ROLLBACK.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

-- ── Les comptes d'essai ────────────────────────────────────────────────────
INSERT INTO public.users (id, display_name, email, is_admin, admin_role)
VALUES
  ('banc-reg-super',    'Super banc',   'Super@Banc.Test', true,  'superAdmin'),
  ('banc-reg-content',  'Content banc', 'content@banc.test', true, 'contentMod'),
  ('banc-reg-fantome',  'Fantôme',      'fantome@banc.test', true, NULL),
  ('banc-reg-ordinaire','Ordinaire',    'ordinaire@banc.test', false, NULL);

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'les deux fonctions existent, en SECURITY DEFINER', '2',
       count(*)::text, CASE WHEN count(*) = 2 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
   AND p.proname IN ('administrateurs', 'profil_par_email');

DO $$
DECLARE refus text := '';
BEGIN
  IF has_function_privilege('anon', 'public.administrateurs()', 'EXECUTE') THEN
    refus := refus || 'administrateurs ';
  END IF;
  IF has_function_privilege('anon', 'public.profil_par_email(text)', 'EXECUTE') THEN
    refus := refus || 'profil_par_email ';
  END IF;
  INSERT INTO resultat VALUES (2, 'anon : aucune des deux n''est exécutable', '(aucune)',
    coalesce(nullif(refus, ''), '(aucune)'),
    CASE WHEN refus = '' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN undefined_function THEN
  INSERT INTO resultat VALUES (2, 'anon : aucune des deux n''est exécutable', '(aucune)',
    'fonction absente', 'ÉCHEC');
END $$;

-- ═══ 2. Un compte ordinaire ════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-reg-ordinaire'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.administrateurs();
  INSERT INTO resultat VALUES (3, 'ordinaire : administrateurs() REFUSÉ', '42501',
    'rendu ' || n || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'ordinaire : administrateurs() REFUSÉ', '42501',
    SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.profil_par_email('super@banc.test');
  INSERT INTO resultat VALUES (4, 'ordinaire : profil_par_email() REFUSÉ', '42501',
    'rendu ' || n || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'ordinaire : profil_par_email() REFUSÉ', '42501',
    SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

-- ═══ 3. Un contentMod : admin, mais pas superAdmin ═════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-reg-content'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.administrateurs();
  INSERT INTO resultat VALUES (5, 'contentMod : administrateurs() REFUSÉ (pas de repli is_admin)', '42501',
    'rendu ' || n || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'contentMod : administrateurs() REFUSÉ (pas de repli is_admin)', '42501',
    SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

-- ═══ 4. Le superAdmin ══════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-reg-super'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.administrateurs() WHERE id LIKE 'banc-reg-%';
  INSERT INTO resultat VALUES (6,
    'superAdmin : la liste contient les admins ET le fantôme, pas l''ordinaire',
    'banc-reg-content,banc-reg-fantome,banc-reg-super', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-reg-content,banc-reg-fantome,banc-reg-super' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6,
    'superAdmin : la liste contient les admins ET le fantôme, pas l''ordinaire',
    'banc-reg-content,banc-reg-fantome,banc-reg-super', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.administrateurs() WHERE id = 'banc-reg-fantome';
  INSERT INTO resultat VALUES (7,
    'superAdmin : le fantôme sort avec is_admin=true et admin_role NULL (incohérence visible)',
    'true · ∅',
    coalesce(r.is_admin::text, '∅') || ' · ' || coalesce(r.admin_role, '∅'),
    CASE WHEN r.is_admin AND r.admin_role IS NULL THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (7,
    'superAdmin : le fantôme sort avec is_admin=true et admin_role NULL (incohérence visible)',
    'true · ∅', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE r record; n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.profil_par_email('  SUPER@banc.test ');
  SELECT * INTO r FROM public.profil_par_email('  SUPER@banc.test ');
  INSERT INTO resultat VALUES (8,
    'superAdmin : profil_par_email, casse et blancs ignorés, e-mail rendu',
    '1 · banc-reg-super · Super@Banc.Test',
    n || ' · ' || coalesce(r.id, '∅') || ' · ' || coalesce(r.email, '∅'),
    CASE WHEN n = 1 AND r.id = 'banc-reg-super' AND r.email = 'Super@Banc.Test'
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8,
    'superAdmin : profil_par_email, casse et blancs ignorés, e-mail rendu',
    '1 · banc-reg-super · Super@Banc.Test', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.profil_par_email('personne@banc.test');
  INSERT INTO resultat VALUES (9, 'superAdmin : adresse inconnue → zéro ligne, pas d''erreur',
    '0', n::text, CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'superAdmin : adresse inconnue → zéro ligne, pas d''erreur',
    '0', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.profil_par_email('   ');
  INSERT INTO resultat VALUES (10, 'superAdmin : adresse vide → zéro ligne',
    '0', n::text, CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'superAdmin : adresse vide → zéro ligne',
    '0', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
