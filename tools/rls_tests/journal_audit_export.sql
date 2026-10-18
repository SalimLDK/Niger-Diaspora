-- Banc : export du journal d'audit (migration 20261019171000).
--
--   python tools/rls_tests/repeter_cible.py tools/rls_tests/journal_audit_export.sql \
--     supabase/migrations/20261019171000_journal_audit_export.sql <sortie.sql>
--   supabase db query --linked -f <sortie.sql>
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un agent autre que le superAdmin emporte
-- le journal ; qu'un export soit sans plafond ; qu'il ne laisse aucune trace ;
-- que les jokers LIKE du filtre servent à tout lire ; et que le journal
-- redevienne réécrivable.

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

CREATE FUNCTION pg_temp.moi(uid text) RETURNS void
LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true)
$f$;

CREATE FUNCTION pg_temp.verifie(n int, cas text, attendu text, obtenu text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN attendu = obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-aud-super',   'Super Banc', 'aud-super@banc.test', true,  'superAdmin'),
  ('banc-aud-content', 'Content',    'aud-cont@banc.test',  true,  'contentMod'),
  ('banc-aud-finance', 'Finance',    'aud-fin@banc.test',   true,  'financeMod'),
  ('banc-aud-ordi',    'Ordi',       'aud-ordi@banc.test',  false, NULL);

-- Trois lignes connues, posées en chemin de confiance (comme write_admin_audit).
INSERT INTO public.admin_audit_logs (admin_id, admin_name, action, target_type, target_id, details, result) VALUES
  ('banc-aud-super', 'Super Banc', 'BANC_ALPHA', 'banc', 'banc-r1', '{"k":"v"}', 'success'),
  ('banc-aud-super', 'Super Banc', 'BANC_BETA',  'banc', 'banc-r2', '{}',        'denied'),
  ('banc-aud-content', 'Content',  'BANC_ALPHA', 'banc', 'banc-r3', '{}',        'success');

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'permission au catalogue, associée à aucun rôle', '1/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key = 'security.audit.export') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission = 'security.audit.export'));
SELECT pg_temp.verifie(2, 'anon n''exécute pas la fonction', 'false',
  has_function_privilege('anon', 'public.admin_audit_export(text,text,text,text,text,timestamptz,timestamptz,integer)', 'EXECUTE')::text);

SELECT pg_temp.moi('banc-aud-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : export REFUSÉ', '42501', $q$SELECT public.admin_audit_export()$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-aud-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : export REFUSÉ', '42501', $q$SELECT public.admin_audit_export()$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-aud-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'contentMod : export REFUSÉ', '42501', $q$SELECT public.admin_audit_export()$q$);
RESET ROLE;
SELECT pg_temp.verifie(13, 'aucun refus n''a écrit AUDIT_EXPORTED', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE action = 'AUDIT_EXPORTED'));

-- ═══ 2. Le superAdmin ══════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-aud-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'limite 0 → 22023', '22023', $q$SELECT public.admin_audit_export(p_limit => 0)$q$);
SELECT pg_temp.essai(21, 'limite 5001 → 22023', '22023', $q$SELECT public.admin_audit_export(p_limit => 5001)$q$);
SELECT pg_temp.essai(22, 'résultat inconnu → 22023', '22023', $q$SELECT public.admin_audit_export(p_result => 'ok')$q$);
SELECT pg_temp.essai(23, 'période inversée → 22023', '22023',
  $q$SELECT public.admin_audit_export(p_from => now(), p_to => now() - interval '1 day')$q$);
RESET ROLE;
SELECT pg_temp.verifie(24, 'les refus de validation n''ont rien écrit', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE action = 'AUDIT_EXPORTED'));

SET LOCAL ROLE authenticated;
CREATE TEMP TABLE r1 AS SELECT public.admin_audit_export(p_action => 'BANC_ALPHA') AS j;
CREATE TEMP TABLE r2 AS SELECT public.admin_audit_export(p_actor => 'Super Banc', p_result => 'denied') AS j;
CREATE TEMP TABLE r3 AS SELECT public.admin_audit_export(p_action => 'BANC%') AS j;
CREATE TEMP TABLE r4 AS SELECT public.admin_audit_export(p_action => 'BANC_') AS j;
CREATE TEMP TABLE r5 AS SELECT public.admin_audit_export(p_resource_type => 'banc', p_limit => 2) AS j;
CREATE TEMP TABLE r6 AS SELECT public.admin_audit_export(p_resource_id => 'banc-r3') AS j;
RESET ROLE;

SELECT pg_temp.verifie(30, 'filtre action : 2 lignes BANC_ALPHA', '2/false', (SELECT (j->>'count') || '/' || (j->>'truncated') FROM r1));
SELECT pg_temp.verifie(31, 'filtre acteur + résultat : 1 ligne', '1', (SELECT j->>'count' FROM r2));
SELECT pg_temp.verifie(32, 'le joker % est littéral : aucune ligne', '0', (SELECT j->>'count' FROM r3));
SELECT pg_temp.verifie(33, 'le _ est littéral : « BANC_ » trouve les 3 lignes', '3', (SELECT j->>'count' FROM r4));
SELECT pg_temp.verifie(34, 'plafond 2 : 2 lignes, tronqué', '2/true', (SELECT (j->>'count') || '/' || (j->>'truncated') FROM r5));
SELECT pg_temp.verifie(35, 'filtre ressource : la ligne de content', 'Content', (SELECT j->'rows'->0->>'admin_name' FROM r6));

SELECT pg_temp.verifie(40, 'chaque export a écrit AUDIT_EXPORTED (6)', '6',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE action = 'AUDIT_EXPORTED' AND admin_id = 'banc-aud-super'));
SELECT pg_temp.verifie(41, 'la trace porte nombre, plafond, filtres', '2/false/BANC_ALPHA',
  (SELECT (details->>'rows') || '/' || (details->>'truncated') || '/' || (details->'filters'->>'action')
     FROM public.admin_audit_logs
    WHERE action = 'AUDIT_EXPORTED' AND details->>'rows' = '2' AND details->'filters'->>'action' = 'BANC_ALPHA'
    LIMIT 1));

-- ═══ 3. Le journal reste en ajout seul ═════════════════════════════════════
SELECT pg_temp.essai(50, 'UPDATE du journal refusé', '42501',
  $q$UPDATE public.admin_audit_logs SET action = 'X_FALSIFIE' WHERE target_id = 'banc-r1'$q$);
SELECT pg_temp.essai(51, 'DELETE du journal refusé', '42501',
  $q$DELETE FROM public.admin_audit_logs WHERE target_id = 'banc-r1'$q$);

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
