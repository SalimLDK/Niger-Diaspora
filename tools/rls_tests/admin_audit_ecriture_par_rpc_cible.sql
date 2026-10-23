-- Banc de la cible supabase/migrations/20261019172000_journal_audit_ecriture_par_rpc.sql.
--
--   python tools/rls_tests/repeter_cible.py \
--     tools/rls_tests/admin_audit_ecriture_par_rpc_cible.sql \
--     supabase/migrations/20261019172000_journal_audit_ecriture_par_rpc.sql sortie.sql
--   supabase db query --linked -f sortie.sql
--
-- Condition : 0 ÉCHEC. BEGIN … ROLLBACK.

BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role)
VALUES ('banc-rpc-admin', 'Admin banc', 'rpc@banc.test', true, 'contentMod');

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-rpc-admin'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO public.admin_audit_logs (admin_id, action, target_type)
  VALUES ('banc-rpc-admin', 'ban_user', 'banc');
  INSERT INTO resultat VALUES (1, 'INSERT direct par un admin REFUSÉ', '42501', 'passé', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'INSERT direct par un admin REFUSÉ', '42501', SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE v_id uuid; v_actor text;
BEGIN
  v_id := public.write_admin_audit('ban_user', 'banc', 'cible');
  SELECT admin_id INTO v_actor FROM public.admin_audit_logs WHERE id = v_id;
  INSERT INTO resultat VALUES (2, 'la RPC écrit encore, nom historique en minuscules accepté',
    'banc-rpc-admin', v_actor, CASE WHEN v_actor = 'banc-rpc-admin' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'la RPC écrit encore, nom historique en minuscules accepté',
    'banc-rpc-admin', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;
ROLLBACK;
