-- Banc : ban et badge « vérifié » de `users` fermés au compte, policies des
-- trois tables du panneau, droits par défaut retirés sur sept tables
-- (migration 20261014050000 ; audit docs/deploiement/AUDIT_ADMIN_2026-10-14.md
-- § 4, § 6.1, § 6.4, § 6.6, § 6.7).
--
--   supabase db query --linked -f tools/rls_tests/admin_garde_users_et_tables_admin.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : la répétition —
--   python tools/rls_tests/repeter_cible.py tools/rls_tests/admin_garde_users_et_tables_admin.sql
--          supabase/migrations/20261014050000_admin_garde_users_et_tables_admin.sql <sortie.sql>
-- remplace la ligne seule `-- @@CIBLE@@` par la migration. APRÈS, lancé tel
-- quel, le banc prouve l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : lancé SANS la migration, le
-- 2026-10-14 en production, il tombe sur les cas marqués « LA FAILLE » et sur
-- le catalogue — c'est la mesure AVANT, consignée dans le message de commit.
--
-- Ce que le banc touche : le compte de test (`test.diaspo@example.com`,
-- lM9WqWWIVUVcoYla2Tw78L6I13j1), qu'il bannit pour la durée de la transaction ;
-- un compte neuf qu'il crée (sans ville ni pays : aucun déclencheur de groupe
-- de ville ne part) ; une ligne dans chacune des deux tables du panneau. Le
-- `ROLLBACK` efface tout. Il ne crée aucune notification, et n'appelle PAS
-- `get_or_create_official_group` (un `DISABLE TRIGGER` sur `groups`, verrou
-- exclusif) : l'exécutabilité est mesurée par `has_function_privilege`.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('compte',  'lM9WqWWIVUVcoYla2Tw78L6I13j1'),
  ('nouveau', 'banc' || substr(md5(random()::text), 1, 24));

-- Un administrateur RÉEL : on ne peut pas en fabriquer un, le déclencheur
-- `users_guard_admin_flags` refuse toute écriture de `is_admin` hors
-- super-admin. Le superAdmin de préférence.
INSERT INTO ctx
SELECT 'admin', id FROM public.users WHERE is_admin
 ORDER BY (admin_role = 'superAdmin') DESC NULLS LAST LIMIT 1;

-- @@CIBLE@@

-- Mise en situation, hors RLS et hors garde (postgres) : le compte de test est
-- banni par le serveur. C'est l'état dont un banni voudrait sortir.
UPDATE public.users
   SET is_banned = true, ban_reason = 'banc', banned_at = now()
 WHERE id = (SELECT v FROM ctx WHERE k = 'compte');

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : plus aucun droit de table sur les 10 tables (7 du § 6.6 + 3 du panneau)',
       '0 droit', count(*)::text || ' droit(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['reports','products','transactions','events','groups','app_config','support_tickets',
                    'admin_audit_logs','admin_notifications','activity_logs']) t,
       unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.' || t, p);

INSERT INTO resultat
SELECT 2, 'authenticated : ni TRUNCATE, ni REFERENCES, ni TRIGGER sur les 7 tables du § 6.6',
       '0 droit', count(*)::text || ' droit(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['reports','products','transactions','events','groups','app_config','support_tickets']) t,
       unnest(ARRAY['TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.' || t, p);

INSERT INTO resultat
SELECT 3, 'authenticated sur les tables du panneau : SELECT+INSERT, SELECT+INSERT, SELECT seul',
       'activity_logs:SELECT,admin_audit_logs:INSERT,admin_audit_logs:SELECT,admin_notifications:INSERT,admin_notifications:SELECT',
       coalesce(string_agg(t || ':' || p, ',' ORDER BY t, p), '(aucun)'),
       CASE WHEN coalesce(string_agg(t || ':' || p, ',' ORDER BY t, p), '')
            = 'activity_logs:SELECT,admin_audit_logs:INSERT,admin_audit_logs:SELECT,admin_notifications:INSERT,admin_notifications:SELECT'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['admin_audit_logs','admin_notifications','activity_logs']) t,
       unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.' || t, p);

INSERT INTO resultat
SELECT 4, 'policies des tables du panneau (2, 2, 1)',
       'activity_logs:1,admin_audit_logs:2,admin_notifications:2',
       coalesce(string_agg(tablename || ':' || n, ',' ORDER BY tablename), '(aucune)'),
       CASE WHEN coalesce(string_agg(tablename || ':' || n, ',' ORDER BY tablename), '')
            = 'activity_logs:1,admin_audit_logs:2,admin_notifications:2' THEN 'OK' ELSE 'ÉCHEC' END
  FROM (SELECT tablename, count(*) n FROM pg_policies
         WHERE schemaname = 'public'
           AND tablename IN ('admin_audit_logs','admin_notifications','activity_logs')
         GROUP BY 1) q;

INSERT INTO resultat
SELECT 5, 'users.verified_at existe (le panneau l''écrit)', 'timestamp with time zone',
       coalesce((SELECT data_type FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'verified_at'), '(absente)'),
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'verified_at')
            THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat
SELECT 6, 'la garde users_garde_privileges est en place (BEFORE INSERT OR UPDATE)', 'présente',
       coalesce(string_agg(tgname, ','), '(absente)'),
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal AND c.relname = 'users' AND t.tgname = 'users_garde_privileges';

INSERT INTO resultat
SELECT 7, 'get_or_create_official_group(text,text) : anon non, authenticated et service_role oui',
       'anon:f,authenticated:t,service_role:t',
       'anon:' || has_function_privilege('anon', 'public.get_or_create_official_group(text,text)', 'EXECUTE')::text
       || ',authenticated:' || has_function_privilege('authenticated', 'public.get_or_create_official_group(text,text)', 'EXECUTE')::text
       || ',service_role:' || has_function_privilege('service_role', 'public.get_or_create_official_group(text,text)', 'EXECUTE')::text,
       CASE WHEN NOT has_function_privilege('anon', 'public.get_or_create_official_group(text,text)', 'EXECUTE')
             AND has_function_privilege('authenticated', 'public.get_or_create_official_group(text,text)', 'EXECUTE')
             AND has_function_privilege('service_role', 'public.get_or_create_official_group(text,text)', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat
SELECT 8, 'admin_audit_logs.admin_id et admin_notifications.sent_by sont du texte (uid Firebase)',
       'text,text',
       coalesce((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_logs' AND column_name='admin_id'), '?')
       || ',' || coalesce((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_notifications' AND column_name='sent_by'), '?'),
       CASE WHEN (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_logs' AND column_name='admin_id') = 'text'
             AND (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_notifications' AND column_name='sent_by') = 'text'
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 2. Le compte banni ════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'compte')))::text, true);
SET LOCAL ROLE authenticated;

-- LE DÉBANNISSEMENT EN LIBRE-SERVICE. Exactement le PATCH du § 6.1.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET is_banned = false, ban_reason = NULL, banned_at = NULL
   WHERE id = (SELECT v FROM ctx WHERE k = 'compte');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (9, 'LA FAILLE — le banni se débannit lui-même',
    'refusé 42501', 'ACCEPTÉ (' || n || ' ligne)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9, 'LA FAILLE — le banni se débannit lui-même',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LE BADGE EN LIBRE-SERVICE.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET is_verified = true
   WHERE id = (SELECT v FROM ctx WHERE k = 'compte');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10, 'LA FAILLE — le compte se décerne le badge « vérifié »',
    'refusé 42501', 'ACCEPTÉ (' || n || ' ligne)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (10, 'LA FAILLE — le compte se décerne le badge « vérifié »',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- Non-régression : l'enregistrement du profil (`ecrireSaLigneUsers`, UPDATE
-- ciblé sans aucune colonne gardée) passe toujours — même banni, le ban
-- n'étant pas appliqué côté serveur par cette migration.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET bio = 'banc', updated_at = now()
   WHERE id = (SELECT v FROM ctx WHERE k = 'compte');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (11, 'updateProfile nominal (profil seul) : passe',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'updateProfile nominal (profil seul) : passe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Non-régression : un client qui renvoie les colonnes gardées À L'IDENTIQUE
-- passe — la garde compare les valeurs, pas les colonnes écrites.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users
     SET is_banned = true, ban_reason = 'banc', is_verified = false, verified_at = NULL,
         display_name = 'Compte Test'
   WHERE id = (SELECT v FROM ctx WHERE k = 'compte');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (12, 'réécriture des colonnes gardées à l''identique : passe',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'réécriture des colonnes gardées à l''identique : passe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Un compte ordinaire n'écrit pas dans le journal d'audit, même sous son nom.
DO $$
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, admin_name, action, target_type)
  VALUES ((SELECT v FROM ctx WHERE k = 'compte'), 'Banc', 'faux_audit', 'user');
  INSERT INTO resultat VALUES (13, 'un compte ordinaire écrit dans admin_audit_logs',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (13, 'un compte ordinaire écrit dans admin_audit_logs',
    'refusé 42501', 'refusé 42501', 'OK');
WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'un compte ordinaire écrit dans admin_audit_logs',
    'refusé 42501', 'REFUSÉ ' || SQLSTATE, 'OK');
END $$;

-- Ni ne le lit : 0 ligne, sans erreur (SELECT accordé, policy is_admin()).
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.admin_audit_logs;
  INSERT INTO resultat VALUES (14, 'un compte ordinaire lit admin_audit_logs : vide',
    '0 ligne', n::text || ' ligne(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (14, 'un compte ordinaire lit admin_audit_logs : vide',
    '0 ligne', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Ses propres lignes d'activité : lecture permise (vide aujourd'hui).
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.activity_logs
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'compte');
  INSERT INTO resultat VALUES (15, 'un compte lit ses activity_logs : permis',
    'lecture permise', n::text || ' ligne(s) lue(s)', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (15, 'un compte lit ses activity_logs : permis',
    'lecture permise', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 3. Le compte neuf (§ 6.7) ═════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'nouveau')))::text, true);
SET LOCAL ROLE authenticated;

-- LA NAISSANCE ARMÉE : `admin_role = 'superAdmin'` et le badge dès l'INSERT.
-- `users_insert_own` ne force que `is_admin = FALSE`. La garde FORCE le reste
-- au lieu de lever : l'INSERT passe, les valeurs non.
DO $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.users (id, display_name, is_admin, admin_role, is_verified, is_banned)
  VALUES ((SELECT v FROM ctx WHERE k = 'nouveau'), 'Banc — compte neuf', false, 'superAdmin', true, false);
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (16, 'création de son compte (users_insert_own) : passe',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (16, 'création de son compte (users_insert_own) : passe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- Relu en postgres : ce qui est resté de la naissance armée.
INSERT INTO resultat
SELECT 17, 'LA FAILLE — un compte naît superAdmin (admin_role) et vérifié',
       'admin_role:NULL,is_verified:f,is_banned:f',
       'admin_role:' || coalesce(admin_role, 'NULL') || ',is_verified:' || is_verified::text || ',is_banned:' || is_banned::text,
       CASE WHEN admin_role IS NULL AND NOT is_verified AND NOT is_banned THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.users WHERE id = (SELECT v FROM ctx WHERE k = 'nouveau');

-- ═══ 4. Le back-office ═════════════════════════════════════════════════════
-- Sans la sortie `is_admin()` de la garde, tout ceci tombe — la panne
-- d'`orders` du 2026-09-21.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

-- banUser : exactement ses trois colonnes.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET is_banned = true, ban_reason = 'banc admin', banned_at = now()
   WHERE id = (SELECT v FROM ctx WHERE k = 'nouveau');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (18, 'admin : bannit un compte (banUser)',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (18, 'admin : bannit un compte (banUser)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- verifyProfile : `is_verified` ET `verified_at` — la colonne absente.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.users SET is_verified = true, verified_at = now()
   WHERE id = (SELECT v FROM ctx WHERE k = 'nouveau');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (19, 'admin : vérifie un profil (verifyProfile, avec verified_at)',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (19, 'admin : vérifie un profil (verifyProfile, avec verified_at)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- AdminAuditHelper.log : exactement ses six colonnes, `admin_id` = uid Firebase.
DO $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, admin_name, action, target_type, target_id, details)
  VALUES ((SELECT v FROM ctx WHERE k = 'admin'), 'Banc', 'verify_profile', 'user',
          (SELECT v FROM ctx WHERE k = 'nouveau'), '{}'::jsonb);
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (20, 'admin : écrit dans admin_audit_logs sous son uid (AdminAuditHelper.log)',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (20, 'admin : écrit dans admin_audit_logs sous son uid (AdminAuditHelper.log)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- … mais pas sous le nom d'un autre.
DO $$
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, admin_name, action, target_type)
  VALUES ((SELECT v FROM ctx WHERE k = 'compte'), 'Banc', 'usurpation', 'user');
  INSERT INTO resultat VALUES (21, 'admin : écrit dans admin_audit_logs sous un AUTRE uid',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (21, 'admin : écrit dans admin_audit_logs sous un AUTRE uid',
    'refusé 42501', 'refusé 42501', 'OK');
WHEN OTHERS THEN
  INSERT INTO resultat VALUES (21, 'admin : écrit dans admin_audit_logs sous un AUTRE uid',
    'refusé 42501', 'REFUSÉ ' || SQLSTATE, 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.admin_audit_logs
   WHERE admin_id = (SELECT v FROM ctx WHERE k = 'admin') AND action = 'verify_profile';
  INSERT INTO resultat VALUES (22, 'admin : relit le journal d''audit (fetchAuditLogs)',
    '>= 1 ligne', n::text || ' ligne(s)', CASE WHEN n >= 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (22, 'admin : relit le journal d''audit (fetchAuditLogs)',
    '>= 1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- sendGlobalNotification : ses cinq colonnes, puis `.select('id')` (RETURNING).
DO $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO public.admin_notifications (sent_by, title, body, target_type, data)
  VALUES ((SELECT v FROM ctx WHERE k = 'admin'), 'Banc', 'corps du banc', 'all', '{}'::jsonb)
  RETURNING id INTO v_id;
  INSERT INTO resultat VALUES (23, 'admin : enregistre une diffusion (admin_notifications, RETURNING id)',
    '1 id', CASE WHEN v_id IS NULL THEN 'aucun id' ELSE '1 id' END,
    CASE WHEN v_id IS NULL THEN 'ÉCHEC' ELSE 'OK' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (23, 'admin : enregistre une diffusion (admin_notifications, RETURNING id)',
    '1 id', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.admin_notifications WHERE title = 'Banc';
  INSERT INTO resultat VALUES (24, 'admin : relit les diffusions (fetchSentNotifications)',
    '>= 1 ligne', n::text || ' ligne(s)', CASE WHEN n >= 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (24, 'admin : relit les diffusions (fetchSentNotifications)',
    '>= 1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.activity_logs
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'nouveau');
  INSERT INTO resultat VALUES (25, 'admin : lit l''activité d''autrui (getUserActivity) : permis',
    'lecture permise', n::text || ' ligne(s) lue(s)', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (25, 'admin : lit l''activité d''autrui (getUserActivity) : permis',
    'lecture permise', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 5. L'anonyme ══════════════════════════════════════════════════════════
SET LOCAL ROLE anon;

-- `events_select_visible` et `groups_select_public` sont au rôle `public` :
-- seul le droit de table retenait `anon`, et il l'avait.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.events;
  INSERT INTO resultat VALUES (26, 'LA FAILLE — anon lit events',
    'refusé 42501', 'LU (' || n || ' ligne(s))', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (26, 'LA FAILLE — anon lit events',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.groups;
  INSERT INTO resultat VALUES (27, 'LA FAILLE — anon lit groups',
    'refusé 42501', 'LU (' || n || ' ligne(s))', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (27, 'LA FAILLE — anon lit groups',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, action) VALUES ('anonyme', 'faux_audit');
  INSERT INTO resultat VALUES (28, 'anon écrit dans admin_audit_logs',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (28, 'anon écrit dans admin_audit_logs',
    'refusé 42501', 'refusé 42501', 'OK');
WHEN OTHERS THEN
  INSERT INTO resultat VALUES (28, 'anon écrit dans admin_audit_logs',
    'refusé 42501', 'REFUSÉ ' || SQLSTATE, 'OK');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
