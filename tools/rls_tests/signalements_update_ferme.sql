-- Banc : fermeture de l'UPDATE direct sur `reports` (migration 20261023090000).
--
--   supabase db query --linked -f tools/rls_tests/signalements_update_ferme.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
-- Apres `db push`, le banc se lance tel quel (la migration est deja la).

BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

CREATE FUNCTION pg_temp.essai(n int, cas text, attendu text, q text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE obtenu text;
BEGIN
  EXECUTE q;
  obtenu := 'OK';
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN obtenu = attendu THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (n, cas, attendu, SQLSTATE,
    CASE WHEN SQLSTATE = attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-fer-mod', 'Mod', 'fer-mod@banc.test', true, 'contentMod');
INSERT INTO public.reports (id, reporter_id, target_type, target_id, reason) VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'banc-fer-mod', 'post', 'p1', 'spam');

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-fer-mod'))::text, true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.essai(1, 'admin : UPDATE direct de status REFUSÉ', '42501',
  $q$UPDATE public.reports SET status = 'resolved' WHERE id = '00000000-0000-0000-0000-0000000000b1'$q$);
SELECT pg_temp.essai(2, 'admin : UPDATE direct de admin_note REFUSÉ', '42501',
  $q$UPDATE public.reports SET admin_note = 'x' WHERE id = '00000000-0000-0000-0000-0000000000b1'$q$);
SELECT pg_temp.essai(3, 'admin : UPDATE de reported_user_notified accepté', 'OK',
  $q$UPDATE public.reports SET reported_user_notified = true WHERE id = '00000000-0000-0000-0000-0000000000b1'$q$);
SELECT pg_temp.essai(4, 'admin : prise en charge par la RPC acceptée', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000b1', 'reviewing')$q$);
RESET ROLE;

INSERT INTO resultat SELECT 5, 'la ligne a bien le flag et le statut posé par la RPC', 'true/reviewing',
       reported_user_notified || '/' || status,
       CASE WHEN reported_user_notified AND status = 'reviewing' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000b1';

INSERT INTO resultat SELECT 6, 'anon n''a aucun droit UPDATE sur reports', 'false',
       has_table_privilege('anon', 'public.reports', 'UPDATE')::text,
       CASE WHEN NOT has_table_privilege('anon', 'public.reports', 'UPDATE') THEN 'OK' ELSE 'ÉCHEC' END;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
