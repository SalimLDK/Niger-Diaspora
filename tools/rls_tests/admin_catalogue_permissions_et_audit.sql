-- Banc : catalogue de permissions, admin_has_permission, journal d'audit en
-- ajout seul (migration 20261016090000).
--
--   supabase db query --linked -f tools/rls_tests/admin_catalogue_permissions_et_audit.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@CIBLE@@` par la migration
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>) —
-- c'est la répétition. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- CE QU'IL VÉRIFIE. Le danger est double : une permission accordée à qui ne
-- l'a pas (refus par défaut), et un journal qu'on peut réécrire. Le banc vise
-- donc les refus : anon, ordinaire, ex-admin (rôle resté sur une ligne
-- is_admin = false), admin sans rôle, rôle hors périmètre, clé inconnue — puis
-- UPDATE / DELETE / TRUNCATE sur le journal, y compris par le propriétaire.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-cat-super',   'Super',    'cat-super@banc.test',   true,  'superAdmin'),
  ('banc-cat-content', 'Content',  'cat-content@banc.test', true,  'contentMod'),
  ('banc-cat-finance', 'Finance',  'cat-finance@banc.test', true,  'financeMod'),
  ('banc-cat-fantome', 'Fantome',  'cat-fantome@banc.test', true,  NULL),
  ('banc-cat-ex',      'Ex-admin', 'cat-ex@banc.test',      false, 'superAdmin'),
  ('banc-cat-ordi',    'Ordinaire','cat-ordi@banc.test',    false, NULL);

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'catalogue : 29 permissions, toutes sur le format domaine.ressource.action', '29',
       count(*)::text, CASE WHEN count(*) = 29 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_permissions WHERE key ~ '^[a-z]+(\.[a-z_]+){1,3}$';

INSERT INTO resultat
SELECT 2, 'mapping : contentMod 10, businessMod 9, financeMod 9 (celui du client)', '10/9/9',
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod') || '/' ||
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'businessMod') || '/' ||
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod'),
       CASE WHEN (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod') = 10
             AND (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'businessMod') = 9
             AND (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod') = 9
            THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat
SELECT 3, 'superAdmin ne figure pas dans admin_role_permissions (tout le catalogue, implicite)', '0',
       count(*)::text, CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE role = 'superAdmin';

DO $$
DECLARE refus text := '';
BEGIN
  IF has_function_privilege('anon', 'public.admin_has_permission(text)', 'EXECUTE') THEN refus := refus || 'has_permission '; END IF;
  IF has_function_privilege('anon', 'public.admin_require_permission(text)', 'EXECUTE') THEN refus := refus || 'require_permission '; END IF;
  IF has_function_privilege('anon', 'public.write_admin_audit(text,text,text,text,text,text,jsonb)', 'EXECUTE') THEN refus := refus || 'write_admin_audit '; END IF;
  INSERT INTO resultat VALUES (4, 'anon : aucune des trois fonctions n''est exécutable', '(aucune)',
    coalesce(nullif(refus, ''), '(aucune)'), CASE WHEN refus = '' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE droits text;
BEGIN
  SELECT string_agg(r || ':' || p, ' ') INTO droits
    FROM (VALUES ('anon'), ('authenticated')) AS roles(r),
         (VALUES ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) AS privs(p),
         (VALUES ('public.admin_permissions'), ('public.admin_role_permissions')) AS t(nom)
   WHERE has_table_privilege(r, nom, p);
  INSERT INTO resultat VALUES (5, 'catalogue : aucun droit d''écriture pour anon ni authenticated', '(aucun)',
    coalesce(droits, '(aucun)'), CASE WHEN droits IS NULL THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 2. admin_has_permission, rôle par rôle ════════════════════════════════
-- superAdmin
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-super'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 10, 'superAdmin : security.roles.manage', 'true',
       public.admin_has_permission('security.roles.manage')::text,
       CASE WHEN public.admin_has_permission('security.roles.manage') THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 11, 'superAdmin : clé hors catalogue REFUSÉE (une faute de frappe n''est pas un passe-droit)', 'false',
       public.admin_has_permission('moderation.reports.reviewz')::text,
       CASE WHEN NOT public.admin_has_permission('moderation.reports.reviewz') THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 12, 'superAdmin : NULL → false', 'false',
       public.admin_has_permission(NULL)::text,
       CASE WHEN NOT public.admin_has_permission(NULL) THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 13, 'superAdmin : porte tout le catalogue', '29',
       (SELECT count(*) FROM public.admin_permissions WHERE public.admin_has_permission(key))::text,
       CASE WHEN (SELECT count(*) FROM public.admin_permissions WHERE public.admin_has_permission(key)) = 29
            THEN 'OK' ELSE 'ÉCHEC' END;
RESET ROLE;

-- contentMod
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-content'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 20, 'contentMod : moderation.reports.review accordée', 'true',
       public.admin_has_permission('moderation.reports.review')::text,
       CASE WHEN public.admin_has_permission('moderation.reports.review') THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 21, 'contentMod : finance.transactions.refund REFUSÉE', 'false',
       public.admin_has_permission('finance.transactions.refund')::text,
       CASE WHEN NOT public.admin_has_permission('finance.transactions.refund') THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 22, 'contentMod : security.roles.manage REFUSÉE', 'false',
       public.admin_has_permission('security.roles.manage')::text,
       CASE WHEN NOT public.admin_has_permission('security.roles.manage') THEN 'OK' ELSE 'ÉCHEC' END;
DO $$
BEGIN
  PERFORM public.admin_require_permission('finance.transactions.refund');
  INSERT INTO resultat VALUES (23, 'contentMod : admin_require_permission(refus) LÈVE', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (23, 'contentMod : admin_require_permission(refus) LÈVE', '42501',
    SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
RESET ROLE;

-- financeMod
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-finance'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 30, 'financeMod : finance.transactions.refund accordée', 'true',
       public.admin_has_permission('finance.transactions.refund')::text,
       CASE WHEN public.admin_has_permission('finance.transactions.refund') THEN 'OK' ELSE 'ÉCHEC' END;
INSERT INTO resultat
SELECT 31, 'financeMod : community.accounts.ban REFUSÉE', 'false',
       public.admin_has_permission('community.accounts.ban')::text,
       CASE WHEN NOT public.admin_has_permission('community.accounts.ban') THEN 'OK' ELSE 'ÉCHEC' END;
RESET ROLE;

-- admin sans rôle, ex-admin (rôle resté, is_admin faux), ordinaire
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-fantome'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 40, 'admin sans rôle (fantôme) : dashboard.view REFUSÉE', 'false',
       public.admin_has_permission('dashboard.view')::text,
       CASE WHEN NOT public.admin_has_permission('dashboard.view') THEN 'OK' ELSE 'ÉCHEC' END;
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-ex'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 41, 'ex-admin (is_admin faux, rôle superAdmin resté) : dashboard.view REFUSÉE', 'false',
       public.admin_has_permission('dashboard.view')::text,
       CASE WHEN NOT public.admin_has_permission('dashboard.view') THEN 'OK' ELSE 'ÉCHEC' END;
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-ordi'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 42, 'ordinaire : dashboard.view REFUSÉE', 'false',
       public.admin_has_permission('dashboard.view')::text,
       CASE WHEN NOT public.admin_has_permission('dashboard.view') THEN 'OK' ELSE 'ÉCHEC' END;
DO $$
BEGIN
  PERFORM public.write_admin_audit('BANC_ACTION', 'banc', 'x');
  INSERT INTO resultat VALUES (43, 'ordinaire : write_admin_audit REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (43, 'ordinaire : write_admin_audit REFUSÉ', '42501',
    SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
RESET ROLE;

-- sans session du tout
SELECT set_config('request.jwt.claims', '', true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 44, 'sans session : dashboard.view REFUSÉE', 'false',
       public.admin_has_permission('dashboard.view')::text,
       CASE WHEN NOT public.admin_has_permission('dashboard.view') THEN 'OK' ELSE 'ÉCHEC' END;
RESET ROLE;

-- ═══ 3. Le journal ═════════════════════════════════════════════════════════
-- contentMod écrit : acteur pris de la session, jamais d'un paramètre.
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-content'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_id uuid; v_actor text; v_res text; v_corr text;
BEGIN
  v_id := public.write_admin_audit('BANC_ACTION', 'banc', 'cible-1', 'denied', 'DROIT_MANQUANT',
                                   'corr-1', '{"ligne": 3}'::jsonb);
  SELECT admin_id, result, correlation_id INTO v_actor, v_res, v_corr
    FROM public.admin_audit_logs WHERE id = v_id;
  INSERT INTO resultat VALUES (50, 'write_admin_audit : acteur = la session, result et corrélation posés',
    'banc-cat-content/denied/corr-1', v_actor || '/' || v_res || '/' || v_corr,
    CASE WHEN v_actor = 'banc-cat-content' AND v_res = 'denied' AND v_corr = 'corr-1' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (50, 'write_admin_audit : acteur = la session, result et corrélation posés',
    'banc-cat-content/denied/corr-1', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  PERFORM public.write_admin_audit('banc minuscule', 'banc', 'x');
  INSERT INTO resultat VALUES (51, 'action en minuscules REFUSÉE', '22023', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (51, 'action en minuscules REFUSÉE', '22023', SQLSTATE,
    CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM public.write_admin_audit('BANC_ACTION', 'banc', 'x', 'perdu');
  INSERT INTO resultat VALUES (52, 'result hors liste REFUSÉ', '22023', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (52, 'result hors liste REFUSÉ', '22023', SQLSTATE,
    CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM public.write_admin_audit('BANC_ACTION', 'banc', 'x', 'success', NULL, NULL,
                                   '{"access_token": "eyJ..."}'::jsonb);
  INSERT INTO resultat VALUES (53, 'metadata avec une clé « token » REFUSÉE', '22023', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (53, 'metadata avec une clé « token » REFUSÉE', '22023', SQLSTATE,
    CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM public.write_admin_audit('BANC_ACTION', 'banc', 'x', 'success', NULL, NULL,
                                   jsonb_build_object('gros', repeat('a', 5000)));
  INSERT INTO resultat VALUES (54, 'metadata de plus de 4 Ko REFUSÉE', '22023', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (54, 'metadata de plus de 4 Ko REFUSÉE', '22023', SQLSTATE,
    CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- Lecture : contentMod porte security.audit.view.
INSERT INTO resultat
SELECT 55, 'contentMod : lit le journal (viewAuditLogs)', '1',
       count(*)::text, CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs WHERE target_type = 'banc';

-- Le client ne réécrit pas son propre journal : droits de table.
DO $$
BEGIN
  UPDATE public.admin_audit_logs SET action = 'FALSIFIE' WHERE target_type = 'banc';
  INSERT INTO resultat VALUES (56, 'authenticated : UPDATE du journal REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (56, 'authenticated : UPDATE du journal REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  DELETE FROM public.admin_audit_logs WHERE target_type = 'banc';
  INSERT INTO resultat VALUES (57, 'authenticated : DELETE du journal REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (57, 'authenticated : DELETE du journal REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
RESET ROLE;

-- Le fantôme (admin sans rôle) ne lit rien.
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-cat-fantome'))::text, true);
SET LOCAL ROLE authenticated;
INSERT INTO resultat
SELECT 58, 'admin sans rôle : le journal est illisible', '0',
       count(*)::text, CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs;
RESET ROLE;

-- anon n'a aucun droit sur le journal.
DO $$
DECLARE droits text;
BEGIN
  SELECT string_agg(p, ' ') INTO droits
    FROM (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) AS privs(p)
   WHERE has_table_privilege('anon', 'public.admin_audit_logs', p);
  INSERT INTO resultat VALUES (59, 'anon : aucun droit sur le journal', '(aucun)',
    coalesce(droits, '(aucun)'), CASE WHEN droits IS NULL THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- Le propriétaire (postgres) et service_role ne réécrivent pas non plus :
-- c'est le déclencheur, pas un REVOKE.
DO $$
BEGIN
  UPDATE public.admin_audit_logs SET action = 'FALSIFIE' WHERE target_type = 'banc';
  INSERT INTO resultat VALUES (60, 'propriétaire : UPDATE du journal REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (60, 'propriétaire : UPDATE du journal REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  DELETE FROM public.admin_audit_logs WHERE target_type = 'banc';
  INSERT INTO resultat VALUES (61, 'propriétaire : DELETE du journal REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (61, 'propriétaire : DELETE du journal REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  TRUNCATE public.admin_audit_logs;
  INSERT INTO resultat VALUES (62, 'propriétaire : TRUNCATE du journal REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (62, 'propriétaire : TRUNCATE du journal REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- Les écrivains actuels (client, functions/supabase.js) n'envoient ni result ni
-- corrélation : les défauts doivent les couvrir.
DO $$
DECLARE v_res text;
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, action, target_type, target_id)
  VALUES ('banc-cat-content', 'ban_user', 'banc-legacy', 'x')
  RETURNING result INTO v_res;
  INSERT INTO resultat VALUES (63, 'écrivain historique (sans result) : accepté, result = success',
    'success', v_res, CASE WHEN v_res = 'success' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (63, 'écrivain historique (sans result) : accepté, result = success',
    'success', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
