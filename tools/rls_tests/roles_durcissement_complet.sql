-- Banc : statistiques serveur, enveloppe d'audit, fermeture de write_admin_audit, resserrement des rôles
-- historiques (migrations 20261029110000, 120000, 130000, 140000). NON LANCÉ à ce jour.
--
--   supabase db query --linked -f tools/rls_tests/roles_durcissement_complet.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT application : remplacer la ligne seule `-- @@CIBLE@@` par les QUATRE migrations, dans l'ordre
-- (concaténées en un fichier, repeter_cible.py n'en prend qu'une). APRÈS, lancé tel quel, il prouve l'état vivant.
--
-- ⚠️ Ce banc suppose les quatre migrations appliquées ENSEMBLE. En production elles ne le sont pas le même
-- jour : 130000 attend le déploiement du panneau. Les cas 60 et 61 portent sur 130000 ; avant son application ils
-- sont attendus en ÉCHEC et ne sont pas à lire comme une régression.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role, is_private) VALUES
  ('banc-dur-super',   'Super',   'dur-super@banc.test',   true,  'superAdmin',  false),
  ('banc-dur-content', 'Content', 'dur-content@banc.test', true,  'contentMod',  false),
  ('banc-dur-biz',     'Biz',     'dur-biz@banc.test',     true,  'businessMod', false),
  ('banc-dur-fin',     'Fin',     'dur-fin@banc.test',     true,  'financeMod',  false),
  ('banc-dur-analyst', 'Analyst', 'dur-analyst@banc.test', true,  'analyst',     false),
  ('banc-dur-audit',   'Audit',   'dur-audit@banc.test',   true,  'auditor',     false),
  ('banc-dur-membre',  'Membre',  'dur-membre@banc.test',  false, NULL,          true);

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-dur-content'))::text, true);
INSERT INTO public.groups (id, name, category, creator_id, is_official, country_code)
VALUES ('00000000-0000-0000-0000-00000000c001', 'banc-dur-groupe', 'banc', 'banc-dur-content', true, 'Banc-Pays-Dur');

INSERT INTO public.reports (id, reporter_id, target_type, target_id, reason)
VALUES ('00000000-0000-0000-0000-00000000c002', 'banc-dur-membre', 'user', 'banc-dur-membre', 'banc');

-- ═══ 1. admin_stats : droit nommé, agrégats seulement ═══
DO $$
DECLARE
  cas record; n int := 10; res text; j jsonb;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-dur-analyst', 'ok'), ('banc-dur-super', 'ok'),
      ('banc-dur-audit', '42501'), ('banc-dur-content', '42501'), ('banc-dur-biz', '42501')
    ) AS t(uid, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      j := public.admin_stats();
      res := CASE WHEN jsonb_typeof(j->'users_total') = 'number' AND j ? 'signups_30d' THEN 'ok' ELSE 'forme' END;
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · admin_stats', cas.attendu, res,
      CASE WHEN res = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 2. Enveloppe d'audit ═══
DO $$
DECLARE
  cas record; n int := 20; res text;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-dur-content', 'ok'), ('banc-dur-super', 'ok'),
      ('banc-dur-audit', '42501'), ('banc-dur-analyst', '42501')
    ) AS t(uid, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM public.admin_audit_client('BANC_ENVELOPPE', 'banc', 'x', '{}'::jsonb);
      res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · admin_audit_client', cas.attendu, res,
      CASE WHEN res = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 3. Resserrement : ce que lit et modifie chaque rôle historique ═══
-- 1 = visible/modifié, 0 = invisible. contentMod porte moderation.reports.view, community.members.view et
-- community.groups.manage ; businessMod et financeMod ne les portent pas ; superAdmin a tout le catalogue.
DO $$
DECLARE
  cas record; n int := 30; v int;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-dur-super',   'reports', 1), ('banc-dur-content', 'reports', 1),
      ('banc-dur-biz',     'reports', 0), ('banc-dur-fin',     'reports', 0),
      ('banc-dur-analyst', 'reports', 0), ('banc-dur-audit',   'reports', 0),
      ('banc-dur-super',   'users',   1), ('banc-dur-content', 'users',   1),
      ('banc-dur-biz',     'users',   0), ('banc-dur-fin',     'users',   0),
      ('banc-dur-super',   'groups',  1), ('banc-dur-content', 'groups',  1),
      ('banc-dur-biz',     'groups',  0), ('banc-dur-audit',   'groups',  0)
    ) AS t(uid, objet, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    IF cas.objet = 'reports' THEN
      SELECT count(*) INTO v FROM public.reports WHERE id = '00000000-0000-0000-0000-00000000c002';
    ELSIF cas.objet = 'users' THEN
      SELECT count(*) INTO v FROM public.users WHERE id = 'banc-dur-membre';
    ELSE
      WITH m AS (UPDATE public.groups SET description = 'banc ' || cas.uid
                  WHERE id = '00000000-0000-0000-0000-00000000c001' RETURNING 1)
      SELECT count(*) INTO v FROM m;
    END IF;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · ' || cas.objet, cas.attendu::text, v::text,
      CASE WHEN v = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 4. profils_admin : par permission ═══
DO $$
DECLARE
  cas record; n int := 50; res text;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-dur-super', 'ouvert'), ('banc-dur-content', 'ouvert'),
      ('banc-dur-biz', '42501'), ('banc-dur-fin', '42501'),
      ('banc-dur-analyst', '42501'), ('banc-dur-audit', '42501')
    ) AS t(uid, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM * FROM public.profils_admin(1);
      res := 'ouvert';
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · profils_admin', cas.attendu, res,
      CASE WHEN res = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 5. write_admin_audit n'est plus exécutable par les rôles de connexion (migration 130000) ═══
INSERT INTO resultat
SELECT 60, 'write_admin_audit : non exécutable par authenticated', 'false',
       has_function_privilege('authenticated', 'public.write_admin_audit(text,text,text,text,text,text,jsonb)', 'EXECUTE')::text,
       CASE WHEN NOT has_function_privilege('authenticated', 'public.write_admin_audit(text,text,text,text,text,text,jsonb)', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 61, 'write_admin_audit : non exécutable par anon', 'false',
       has_function_privilege('anon', 'public.write_admin_audit(text,text,text,text,text,text,jsonb)', 'EXECUTE')::text,
       CASE WHEN NOT has_function_privilege('anon', 'public.write_admin_audit(text,text,text,text,text,text,jsonb)', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ Rapport ═══
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
