-- Banc : promotion payante et badge « vérifié » fermés au client
-- (migration 20260921071500).
--
--   supabase db query --linked -f tools/rls_tests/boost_et_badge_verifie.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : le compte de ce qui tombe
-- sans la migration est relevé plus bas, mesuré et non deviné.
--
-- La production porte 2 entreprises, 0 promue. Le banc ne touche AUCUNE : il
-- crée la sienne sous le rôle propriétaire, et le `ROLLBACK` l'efface. Aucun
-- déclencheur de `businesses` n'envoie de notification (seul
-- `businesses_updated_at`, plus la garde que cette migration ajoute).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('patron', '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('intrus', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('fiche',  gen_random_uuid()::text);

-- Un administrateur RÉEL : on ne peut pas en fabriquer un, le déclencheur
-- `users_guard_admin_flags` refuse toute écriture de `is_admin` hors
-- super-admin — y compris au propriétaire de la table.
INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin LIMIT 1;

-- @@MIGRATION@@

-- Une fiche d'essai, posée par le propriétaire (hors RLS et hors garde).
INSERT INTO public.businesses (id, owner_id, name, description, category,
                               is_active, is_verified, is_boosted,
                               rating, review_count)
SELECT (SELECT v FROM ctx WHERE k = 'fiche')::uuid,
       (SELECT v FROM ctx WHERE k = 'patron'),
       'Banc — entreprise d''essai', 'fiche du banc', 'services',
       true, false, false, 0, 0;

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : aucun droit sur businesses ni business_boosts', '(aucun)',
       coalesce(string_agg(t || ':' || p, ',' ORDER BY t, p), '(aucun)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['businesses','business_boosts']) t,
       unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.' || t, p);

-- Le GRANT sans REVOKE laissait TOUT en place : c'est le piège du CLAUDE.md,
-- et il était ici en vrai. Ce cas le mesure.
INSERT INTO resultat
SELECT 2, 'business_boosts : authenticated en lecture seule', '(aucune écriture)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucune écriture)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.business_boosts', p);

INSERT INTO resultat
SELECT 3, 'plus de policy d''achat de boost', '(aucune)',
       coalesce(string_agg(policyname, ',' ORDER BY policyname), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'business_boosts'
   AND cmd = 'INSERT';

INSERT INTO resultat
SELECT 4, 'la garde de businesses est en place', 'présente',
       coalesce(string_agg(tgname, ','), '(absente)'),
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal AND c.relname = 'businesses'
   AND t.tgname = 'businesses_garde_privileges';

-- ═══ 2. Le propriétaire de la fiche ════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'patron')))::text, true);
SET LOCAL ROLE authenticated;

-- LE BADGE DE CONFIANCE, EN LIBRE-SERVICE.
DO $$
BEGIN
  UPDATE public.businesses SET is_verified = true
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  INSERT INTO resultat VALUES (5, 'LA FAILLE — le patron se décerne le badge « vérifié »',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'LA FAILLE — le patron se décerne le badge « vérifié »',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA PROMOTION PAYANTE, GRATUITE. C'est le chemin nominal du code :
-- `updateBusinessBoostStatus` pose exactement ces deux colonnes.
DO $$
BEGIN
  UPDATE public.businesses
     SET is_boosted = true, boost_expires_at = now() + interval '10 years'
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  INSERT INTO resultat VALUES (6, 'LA FAILLE — le patron se promeut dix ans, gratuitement',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6, 'LA FAILLE — le patron se promeut dix ans, gratuitement',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA NOTE. `_versLigne` ne l'envoie pas, mais rien n'empêchait un PATCH direct,
-- et aucun déclencheur d'agrégat n'existe pour la recalculer.
DO $$
BEGIN
  UPDATE public.businesses SET rating = 5, review_count = 999
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  INSERT INTO resultat VALUES (7, 'LA FAILLE — le patron se met 5 étoiles et 999 avis',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, 'LA FAILLE — le patron se met 5 étoiles et 999 avis',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA QUITTANCE : une ligne de boost « active » à 0 franc.
DO $$
BEGIN
  INSERT INTO public.business_boosts
         (business_id, user_id, type, duration, amount, currency,
          start_date, end_date, status)
  VALUES ((SELECT v FROM ctx WHERE k = 'fiche')::uuid,
          (SELECT v FROM ctx WHERE k = 'patron'), 'premium', 'days30',
          0, 'XOF', now(), now() + interval '10 years', 'active');
  INSERT INTO resultat VALUES (8, 'LA FAILLE — quittance de boost « active » à 0',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (8, 'LA FAILLE — quittance de boost « active » à 0',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA NAISSANCE : une fiche qui naît déjà vérifiée et promue.
DO $$
BEGIN
  INSERT INTO public.businesses (owner_id, name, description, category,
                                 is_active, is_verified, is_boosted)
  VALUES ((SELECT v FROM ctx WHERE k = 'patron'), 'Banc — née vérifiée',
          'fiche du banc', 'services', true, true, true);
  INSERT INTO resultat VALUES (9, 'LA FAILLE — une fiche naît vérifiée et promue',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9, 'LA FAILLE — une fiche naît vérifiée et promue',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ 3. Non-régression : la fiche reste au patron ══════════════════════════
-- LE CAS QUI COMPTE LE PLUS. `updateBusiness` renvoie TOUTE la ligne, donc il
-- réécrit `is_verified` et `is_boosted` avec leur valeur courante à chaque
-- retouche. Un `REVOKE` par colonnes ferait échouer ceci en 42501 ; la garde
-- compare les valeurs, donc laisse passer.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.businesses
     SET name = 'Banc — nom retouché', phone = '+22790000000',
         description = 'nouvelle description',
         is_verified = false, is_boosted = false, boost_expires_at = NULL
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10,
    'updateBusiness renvoie toute la ligne, à l''identique : passe',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10,
    'updateBusiness renvoie toute la ligne, à l''identique : passe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.businesses (owner_id, name, description, category,
                                 is_active, is_verified, is_boosted,
                                 boost_expires_at)
  VALUES ((SELECT v FROM ctx WHERE k = 'patron'), 'Banc — création nominale',
          'fiche du banc', 'services', true, false, false, NULL);
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (11, 'createBusiness nominal (false/false/null) : passe',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'createBusiness nominal (false/false/null) : passe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.business_boosts
   WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  INSERT INTO resultat VALUES (12, 'le patron lit toujours l''historique de boost',
    'lecture permise', n::text || ' ligne(s) lue(s)', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'le patron lit toujours l''historique de boost',
    'lecture permise', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Le compteur de vues passe par une fonction SECURITY DEFINER : chemin de
-- confiance, la garde ne doit pas l'arrêter.
DO $$
BEGIN
  PERFORM public.increment_business_view_count(
    (SELECT v FROM ctx WHERE k = 'fiche')::uuid);
  INSERT INTO resultat VALUES (13, 'increment_business_view_count passe toujours',
    'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'increment_business_view_count passe toujours',
    'accepté', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 4. L'intrus ═══════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'intrus')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.businesses SET name = 'détournée'
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (14, 'un tiers ne modifie pas la fiche d''autrui',
    '0 ligne', n::text || ' ligne(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (14, 'un tiers ne modifie pas la fiche d''autrui',
    '0 ligne', 'refusé ' || SQLSTATE, 'OK');
END $$;

RESET ROLE;

-- ═══ 5. Le back-office ═════════════════════════════════════════════════════
-- Sans la sortie `is_admin()` du déclencheur, ces deux cas tombent — et c'est
-- exactement la panne trouvée sur `orders` la veille.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.businesses SET is_verified = true
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (15, 'admin : vérifie une fiche',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (15, 'admin : vérifie une fiche',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.businesses
     SET is_boosted = true, boost_expires_at = now() + interval '30 days'
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (16, 'admin : bascule la promotion',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (16, 'admin : bascule la promotion',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 6. Le serveur garde tout ══════════════════════════════════════════════
DO $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.business_boosts
         (business_id, user_id, type, duration, amount, currency,
          start_date, end_date, status)
  VALUES ((SELECT v FROM ctx WHERE k = 'fiche')::uuid,
          (SELECT v FROM ctx WHERE k = 'patron'), 'premium', 'days30',
          5000, 'XOF', now(), now() + interval '30 days', 'active');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (17, 'le serveur pose toujours une quittance payée',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (17, 'le serveur pose toujours une quittance payée',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
