-- Banc : `public.friends` en lecture seule pour les clients, le serveur seul
-- écrit (migration 20260921021300).
--
--   supabase db query --linked -f tools/rls_tests/friends_ecriture_serveur_seul.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : lancé tel quel AVANT la
-- migration, les cas 1, 2, 3, 5, 6, 7 et 8 tombent — vérifié à l'écriture, le
-- 2026-09-21. Les cas 4, 9, 10 et 11 passaient déjà : ils gardent la
-- non-régression, c'est-à-dire que le fil continue de lire ses amitiés.
--
-- AUCUNE DONNÉE N'EST ÉCRITE, même avant le `ROLLBACK` : les cas d'écriture
-- visent la paire (moi, autre) telle quelle. Postgres vérifie le PRIVILÈGE
-- avant d'exécuter, donc tout résultat autre que 42501 — succès comme
-- violation de clé primaire — prouve que le droit d'écrire était là, et
-- compte comme ÉCHEC. On n'a donc pas besoin de savoir si cette paire existe
-- déjà, et on ne touche à personne.

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',   '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13');

-- Un compte qui a VRAIMENT des amis, choisi dans la table : le compte de test
-- n'en a aucun, et « 0 ligne lue » ne prouverait pas que le fil lit encore.
-- Il ne sert qu'à la lecture (cas 4) ; les tentatives d'écriture restent sur
-- le compte de test, pour ne pas toucher aux lignes de quelqu'un, même le
-- temps d'une transaction annulée.
INSERT INTO ctx
SELECT 'lecteur', user_id FROM public.friends ORDER BY user_id LIMIT 1;

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : aucun droit de table sur friends', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.friends', p);

INSERT INTO resultat
SELECT 2, 'authenticated : lecture seule sur friends', 'SELECT',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN coalesce(string_agg(p, ',' ORDER BY p), '') = 'SELECT' THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.friends', p);

INSERT INTO resultat
SELECT 3, 'aucune policy de friends ne vaut pour anon ou public', '(aucune)',
       coalesce(string_agg(policyname, ',' ORDER BY policyname), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'friends'
   AND roles && ARRAY['anon','public']::name[];

-- ═══ 2. Compte connecté ═════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- Ce que le fil lit vraiment (feed_supabase_datasource.dart:310), sous
-- l'identité d'un compte qui a des amis.
RESET ROLE;
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'lecteur')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint; attendu bigint;
BEGIN
  SELECT count(*) INTO n FROM public.friends WHERE user_id = (SELECT v FROM ctx WHERE k = 'lecteur');
  RESET ROLE;
  SELECT count(*) INTO attendu FROM public.friends WHERE user_id = (SELECT v FROM ctx WHERE k = 'lecteur');
  INSERT INTO resultat VALUES (4, 'le fil lit ses amitiés (select friend_id where user_id = soi)',
    attendu || ' ligne(s)', n || ' ligne(s)',
    CASE WHEN n = attendu AND n > 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'le fil lit ses amitiés (select friend_id where user_id = soi)',
    'lu', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Retour sur le compte de test pour les tentatives d'écriture.
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO public.friends (user_id, friend_id)
  VALUES ((SELECT v FROM ctx WHERE k = 'moi'), (SELECT v FROM ctx WHERE k = 'autre'));
  INSERT INTO resultat VALUES (5, 'connecté : se déclare ami de quelqu''un', 'refusé 42501',
    'ACCEPTÉ', 'ÉCHEC');
EXCEPTION
  WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (5, 'connecté : se déclare ami de quelqu''un', 'refusé 42501',
      'refusé 42501', 'OK');
  WHEN unique_violation THEN
    -- Le privilège est vérifié AVANT l'exécution : arriver jusqu'au conflit
    -- prouve que le droit d'écrire était là.
    INSERT INTO resultat VALUES (5, 'connecté : se déclare ami de quelqu''un', 'refusé 42501',
      'ACCEPTÉ (jusqu''au conflit de clé)', 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.friends SET friend_name = friend_name
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'moi');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (6, 'connecté : modifie une de ses lignes', 'refusé 42501',
    'ACCEPTÉ (' || n || ' ligne)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6, 'connecté : modifie une de ses lignes', 'refusé 42501',
    'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  DELETE FROM public.friends WHERE user_id = (SELECT v FROM ctx WHERE k = 'moi');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (7, 'connecté : se retire d''une audience à l''insu de l''autre',
    'refusé 42501', 'ACCEPTÉ (' || n || ' ligne(s))', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, 'connecté : se retire d''une audience à l''insu de l''autre',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

INSERT INTO resultat
SELECT 8, 'connecté : ni TRUNCATE, ni REFERENCES, ni TRIGGER', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.friends', p);

-- ═══ 3. Anonyme ═════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims = '{"role":"anon"}';
SET LOCAL ROLE anon;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.friends;
  INSERT INTO resultat VALUES (9, 'anonyme : lit friends', 'refusé 42501',
    'LU : ' || n || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9, 'anonyme : lit friends', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ 4. Le serveur écrit toujours ═══════════════════════════════════════════
-- `setFriendship` passe par la clé de service, donc hors RLS et hors droits de
-- table. Ici la session est déjà propriétaire : l'écriture doit passer.
DO $$
BEGIN
  INSERT INTO public.friends (user_id, friend_id, friend_name)
  VALUES ('banc-1.2-a', 'banc-1.2-b', 'banc')
  ON CONFLICT (user_id, friend_id) DO NOTHING;
  DELETE FROM public.friends WHERE user_id = 'banc-1.2-a';
  INSERT INTO resultat VALUES (10, 'serveur : écrit et retire une amitié', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'serveur : écrit et retire une amitié', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- L'audience elle-même : `est_ami_de` est SECURITY DEFINER, elle doit
-- continuer de trancher malgré les droits retirés.
INSERT INTO resultat
SELECT 11, 'l''audience « Amis » tranche toujours', 'toutes les lignes, dans leur sens',
       count(*) || ' ligne(s) sur ' || (SELECT count(*) FROM public.friends),
       CASE WHEN count(*) = (SELECT count(*) FROM public.friends) THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.friends f
 WHERE private.est_ami_de(f.user_id, f.friend_id);

-- ═══ Rapport ════════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
