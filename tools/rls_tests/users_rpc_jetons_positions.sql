-- Banc : positions par identifiants et jeton push modifié en base
-- (migration 20260921093000 — écrite sous le numéro 081500, renumérotée avant
-- toute application : l'autre session avait appliqué 083000 et 090000 entre-
-- temps, et une migration placée avant deux déjà appliquées est refusée).
--
--   supabase db query --linked -f tools/rls_tests/users_rpc_jetons_positions.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. Sans elle, les fonctions n'existent pas et tout cas qui
-- les appelle tombe en 42883.
--
-- Comme pour `users_rpc_colonnes_privees.sql`, le banc vise surtout les
-- EXCLUSIONS : ces fonctions contournent le RLS. Profils d'essai près du pôle
-- Nord, annulés par le `ROLLBACK`.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@MIGRATION@@

INSERT INTO public.users
       (id, display_name, share_location, is_visible, is_private,
        latitude, longitude, location_updated_at, fcm_tokens)
VALUES
  ('banc-jp-appelant', 'Appelant', true,  true,  true,  89.00, 179.00, now(), '["a"]'::jsonb),
  ('banc-jp-refus',    'Non',      false, true,  false, 89.01, 179.01, now(), '["r"]'::jsonb),
  ('banc-jp-consent',  'Oui',      true,  true,  false, 89.02, 179.02, now(), '[]'::jsonb),
  ('banc-jp-prive',    'Privé',    true,  true,  true,  89.03, 179.03, now(), '[]'::jsonb),
  ('banc-jp-invisible','Invisible',true,  false, false, 89.04, 179.04, now(), '[]'::jsonb),
  ('banc-jp-sanspos',  'Sans',     true,  true,  false, NULL,  NULL,  NULL,  'null'::jsonb);

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'les trois fonctions existent, en SECURITY DEFINER', '3', count(*)::text,
       CASE WHEN count(*) = 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
   AND p.proname IN ('positions_partagees_par_ids', 'ajouter_jeton_push', 'retirer_jeton_push');

DO $$
DECLARE ouvertes text := '';
BEGIN
  IF has_function_privilege('anon', 'public.positions_partagees_par_ids(text[])', 'EXECUTE') THEN
    ouvertes := ouvertes || 'positions ';
  END IF;
  IF has_function_privilege('anon', 'public.ajouter_jeton_push(text)', 'EXECUTE') THEN
    ouvertes := ouvertes || 'ajouter ';
  END IF;
  IF has_function_privilege('anon', 'public.retirer_jeton_push(text)', 'EXECUTE') THEN
    ouvertes := ouvertes || 'retirer ';
  END IF;
  INSERT INTO resultat VALUES (2, 'anon : aucune des trois n''est exécutable', '(aucune)',
    coalesce(nullif(ouvertes, ''), '(aucune)'), CASE WHEN ouvertes = '' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN undefined_function THEN
  INSERT INTO resultat VALUES (2, 'anon : aucune des trois n''est exécutable', '(aucune)',
    'fonction absente', 'ÉCHEC');
END $$;

-- ═══ 2. Positions par identifiants ═════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-jp-appelant'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.positions_partagees_par_ids(ARRAY[
      'banc-jp-appelant', 'banc-jp-refus', 'banc-jp-consent', 'banc-jp-prive',
      'banc-jp-invisible', 'banc-jp-sanspos', 'inconnu']);
  INSERT INTO resultat VALUES (3,
    'par ids : soi + le seul tiers qui a consenti (refus, privé, invisible, sans position écartés)',
    'banc-jp-appelant,banc-jp-consent', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-jp-appelant,banc-jp-consent' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3,
    'par ids : soi + le seul tiers qui a consenti (refus, privé, invisible, sans position écartés)',
    'banc-jp-appelant,banc-jp-consent', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Le plafond : 200 leurres d'abord, le vrai en 201e position — il ne doit
-- PAS sortir. C'est ce qui prouve la coupe, sans avoir 200 comptes sous la main.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n
    FROM public.positions_partagees_par_ids(
      array_append(array_fill('leurre'::text, ARRAY[200]), 'banc-jp-consent'));
  INSERT INTO resultat VALUES (4, 'par ids : le 201e identifiant est ignoré (plafond de 200)',
    '0', n::text, CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'par ids : le 201e identifiant est ignoré (plafond de 200)',
    '0', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- ═══ 3. Le jeton push ══════════════════════════════════════════════════════
DO $$
BEGIN
  PERFORM public.ajouter_jeton_push('b');
  PERFORM public.ajouter_jeton_push('b');   -- deux fois : pas de doublon
  INSERT INTO resultat VALUES (5, 'ajouter : « b » s''ajoute une seule fois', '["a", "b"]',
    (SELECT fcm_tokens::text FROM public.mon_profil_prive()),
    CASE WHEN (SELECT fcm_tokens FROM public.mon_profil_prive()) = '["a","b"]'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'ajouter : « b » s''ajoute une seule fois', '["a", "b"]',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  PERFORM public.retirer_jeton_push('a');
  PERFORM public.retirer_jeton_push('absent');
  INSERT INTO resultat VALUES (6, 'retirer : « a » part, un absent ne change rien', '["b"]',
    (SELECT fcm_tokens::text FROM public.mon_profil_prive()),
    CASE WHEN (SELECT fcm_tokens FROM public.mon_profil_prive()) = '["b"]'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'retirer : « a » part, un absent ne change rien', '["b"]',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  PERFORM public.ajouter_jeton_push('');
  INSERT INTO resultat VALUES (7, 'un jeton vide est refusé (22023)', 'refusé 22023', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION
  WHEN invalid_parameter_value THEN
    INSERT INTO resultat VALUES (7, 'un jeton vide est refusé (22023)', 'refusé 22023', 'refusé 22023', 'OK');
  WHEN OTHERS THEN
    INSERT INTO resultat VALUES (7, 'un jeton vide est refusé (22023)', 'refusé 22023', 'autre : ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- Le tiers n'a pas bougé : la fonction n'écrit que SA ligne.
INSERT INTO resultat
SELECT 8, 'la ligne d''un tiers est intacte', '["r"]', fcm_tokens::text,
       CASE WHEN fcm_tokens = '["r"]'::jsonb THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.users WHERE id = 'banc-jp-refus';

-- ═══ 4. Des jetons mal formés en base ══════════════════════════════════════
-- Un `null` JSON (admis : la colonne est `NOT NULL` au sens SQL seulement) et
-- un tableau vide. Sans la garde `jsonb_typeof`, le premier donnerait
-- `[null, "x"]` et `send-push` enverrait au jeton `null`.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-jp-sanspos'))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM public.ajouter_jeton_push('x');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-jp-consent'))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM public.ajouter_jeton_push('y');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
RESET ROLE;

INSERT INTO resultat
SELECT 9, '`null` JSON et tableau vide donnent un tableau propre',
       '["x"] · ["y"]',
       coalesce((SELECT fcm_tokens::text FROM public.users WHERE id = 'banc-jp-sanspos'), '∅')
         || ' · ' ||
       coalesce((SELECT fcm_tokens::text FROM public.users WHERE id = 'banc-jp-consent'), '∅'),
       CASE WHEN (SELECT fcm_tokens FROM public.users WHERE id = 'banc-jp-sanspos') = '["x"]'::jsonb
             AND (SELECT fcm_tokens FROM public.users WHERE id = 'banc-jp-consent') = '["y"]'::jsonb
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 5. Sans identité ══════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.positions_partagees_par_ids(ARRAY['banc-jp-consent']);
  BEGIN
    PERFORM public.ajouter_jeton_push('z');
    INSERT INTO resultat VALUES (10, 'sans identité : 0 position, et le jeton est refusé (42501)',
      '0 · refusé 42501', n::text || ' · ACCEPTÉ', 'ÉCHEC');
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (10, 'sans identité : 0 position, et le jeton est refusé (42501)',
      '0 · refusé 42501', n::text || ' · refusé 42501',
      CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
  END;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'sans identité : 0 position, et le jeton est refusé (42501)',
    '0 · refusé 42501', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;
RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
