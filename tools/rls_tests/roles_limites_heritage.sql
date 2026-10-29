-- Banc : fermeture, pour les rôles limités, de l'héritage `is_admin()` (migration 20261029100000).
--
--   supabase db query --linked -f tools/rls_tests/roles_limites_heritage.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`. NON LANCÉ à ce jour.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@CIBLE@@` par les DEUX migrations, dans l'ordre
-- (20261029090000 puis 20261029100000) — la répétition. APRÈS, lancé tel quel, il prouve l'état vivant.
-- Si un INSERT de données de banc échoue sur une colonne NOT NULL non prévue, l'ajuster : il ne touche
-- que des lignes `banc-%`, annulées par le ROLLBACK.
--
-- CE QU'IL PROUVE, rôle par rôle : le rôle historique (contentMod) voit et fait EXACTEMENT ce qu'il faisait ;
-- l'auditeur et l'analyste ne voient ni profils privés, ni signalements, et ne modifient aucun groupe officiel.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role, is_private) VALUES
  ('banc-her-content', 'Content', 'her-content@banc.test', true,  'contentMod', false),
  ('banc-her-audit',   'Audit',   'her-audit@banc.test',   true,  'auditor',    false),
  ('banc-her-analyst', 'Analyst', 'her-analyst@banc.test', true,  'analyst',    false),
  ('banc-her-support', 'Support', 'her-support@banc.test', true,  'supportAgent', false),
  ('banc-her-membre',  'Membre',  'her-membre@banc.test',  false, NULL,         true);

INSERT INTO public.groups (id, name, category, creator_id, is_official)
VALUES ('00000000-0000-0000-0000-00000000b001', 'banc-groupe-officiel', 'banc', 'banc-her-membre', true);

INSERT INTO public.reports (id, reporter_id, target_type, target_id, reason)
VALUES ('00000000-0000-0000-0000-00000000b002', 'banc-her-membre', 'user', 'banc-her-membre', 'banc');

-- ═══ 1. Les objets réécrits portent bien le prédicat ═══
INSERT INTO resultat
SELECT 1, 'policies réécrites (10 attendues, sauf déjà fermées)', '10',
       count(*)::text, CASE WHEN count(*) = 10 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public'
   AND policyname IN ('demarches_rubriques_write', 'demarches_catalogue_meta_write', 'groups_update_admin',
                      'business_reviews_retrait', 'reports_update_admin', 'reports_select_own', 'users_select',
                      'activity_logs_select_own_or_admin', 'error_logs_admin_read', 'admin_notifications_select_admin')
   AND (coalesce(qual, '') || coalesce(with_check, '')) LIKE '%is_limited_admin%';

INSERT INTO resultat
SELECT 2, 'fonctions réécrites (4 noms attendus)', '4',
       count(DISTINCT p.proname)::text, CASE WHEN count(DISTINCT p.proname) = 4 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
 WHERE p.proname IN ('profils_admin', 'profils_admin_page', 'conversations_guard_admin_fields', 'guard_group_official')
   AND p.prosrc LIKE '%is_limited_admin%';

INSERT INTO resultat
SELECT 3, 'is_limited_admin : exécutable par anon et authenticated', 'oui/oui',
       has_function_privilege('anon', 'public.is_limited_admin()', 'EXECUTE')::text || '/' ||
       has_function_privilege('authenticated', 'public.is_limited_admin()', 'EXECUTE')::text,
       CASE WHEN has_function_privilege('anon', 'public.is_limited_admin()', 'EXECUTE')
             AND has_function_privilege('authenticated', 'public.is_limited_admin()', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 2. Comportement, compte par compte ═══
-- (compte, test, attendu)  — « n » = nombre de lignes visibles ou modifiées.
DO $$
DECLARE
  cas record;
  n int := 10;
  v int;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      -- lecture des signalements (identité des déclarants)
      ('banc-her-content', 'reports',  1),
      ('banc-her-audit',   'reports',  0),
      ('banc-her-analyst', 'reports',  0),
      ('banc-her-support', 'reports',  0),
      -- lecture d'un profil privé
      ('banc-her-content', 'users',    1),
      ('banc-her-audit',   'users',    0),
      ('banc-her-analyst', 'users',    0),
      -- modification d'un groupe officiel
      ('banc-her-content', 'groups',   1),
      ('banc-her-audit',   'groups',   0),
      ('banc-her-analyst', 'groups',   0)
    ) AS t(uid, objet, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    IF cas.objet = 'reports' THEN
      SELECT count(*) INTO v FROM public.reports WHERE id = '00000000-0000-0000-0000-00000000b002';
    ELSIF cas.objet = 'users' THEN
      SELECT count(*) INTO v FROM public.users WHERE id = 'banc-her-membre';
    ELSE
      WITH m AS (UPDATE public.groups SET description = 'banc ' || cas.uid
                  WHERE id = '00000000-0000-0000-0000-00000000b001' RETURNING 1)
      SELECT count(*) INTO v FROM m;
    END IF;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · ' || cas.objet, cas.attendu::text, v::text,
      CASE WHEN v = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 3. profils_admin : refusé aux rôles limités, ouvert aux historiques ═══
DO $$
DECLARE
  cas record;
  n int := 30;
  res text;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-her-content', 'ouvert'),
      ('banc-her-audit',   '42501'),
      ('banc-her-analyst', '42501'),
      ('banc-her-support', '42501')
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

-- ═══ 4. Les droits PAR PERMISSION des rôles limités ne sont pas coupés ═══
DO $$
DECLARE v boolean;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-her-support'))::text, true);
  SET LOCAL ROLE authenticated;
  v := public.admin_has_permission('support.tickets.reply');
  RESET ROLE;
  INSERT INTO resultat VALUES (40, 'supportAgent garde support.tickets.reply (par permission)', 'true', v::text,
    CASE WHEN v THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Rapport ═══
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
