-- Banc : le bloc « À traiter » du tableau de bord
-- (migration 20261019130000).
--
--   supabase db query --linked -f tools/rls_tests/tableau_de_bord_a_traiter.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un administrateur reçoive des nombres de
-- modules auxquels il n'a pas droit (une ligne présente est une information),
-- que ces nombres ne correspondent pas aux files réelles, ou qu'un refus soit
-- rendu comme « tout est calme ». Les comptes sont comparés à ceux que donne
-- le propriétaire par requête directe : le banc ne suppose rien de l'état de
-- la production.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE obtenu_json(k text, v jsonb);
GRANT ALL ON obtenu_json TO anon, authenticated;

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

-- Les clés présentes dans la réponse, triées, séparées par des virgules.
CREATE FUNCTION pg_temp.cles(r jsonb) RETURNS text
LANGUAGE sql AS $f$
  SELECT coalesce(string_agg(i ->> 'key', ',' ORDER BY i ->> 'key'), '')
    FROM jsonb_array_elements(r -> 'items') i
$f$;

CREATE FUNCTION pg_temp.compte(r jsonb, cle text) RETURNS text
LANGUAGE sql AS $f$
  SELECT i ->> 'count' FROM jsonb_array_elements(r -> 'items') i WHERE i ->> 'key' = cle
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-tb-super',   'Super',    'tb-super@banc.test',   true,  'superAdmin'),
  ('banc-tb-content', 'Content',  'tb-content@banc.test', true,  'contentMod'),
  ('banc-tb-biz',     'Biz',      'tb-biz@banc.test',     true,  'businessMod'),
  ('banc-tb-finance', 'Finance',  'tb-fin@banc.test',     true,  'financeMod'),
  ('banc-tb-ordi',    'Ordi',     'tb-ordi@banc.test',    false, NULL);

-- Des lignes connues, en plus de ce que la production contient déjà.
INSERT INTO public.reports (reporter_id, target_type, target_id, reason, status) VALUES
  ('banc-tb-ordi', 'post', 'p1', 'spam', 'pending'),
  ('banc-tb-ordi', 'post', 'p2', 'spam', 'reviewing'),
  ('banc-tb-ordi', 'post', 'p3', 'spam', 'resolved');
INSERT INTO public.support_tickets (user_id, subject, status) VALUES
  ('banc-tb-ordi', 'ouvert', 'open'),
  ('banc-tb-ordi', 'en cours', 'in_progress'),
  ('banc-tb-ordi', 'clos', 'closed');
INSERT INTO public.privacy_requests (kind, requester_contact, due_at, assigned_to, created_by, status) VALUES
  ('access', 'a@banc.test', now() - interval '1 day', 'banc-tb-super', 'banc-tb-super', 'received'),
  ('access', 'b@banc.test', now() + interval '10 days', 'banc-tb-super', 'banc-tb-super', 'received'),
  ('access', 'c@banc.test', now() + interval '10 days', 'banc-tb-super', 'banc-tb-super', 'completed');
INSERT INTO public.security_incidents (title, severity, summary, owner_id, created_by, status) VALUES
  ('Incident critique de banc', 'critical', 'Un résumé assez long de banc.', 'banc-tb-super', 'banc-tb-super', 'open'),
  ('Incident faible de banc',   'low',      'Un résumé assez long de banc.', 'banc-tb-super', 'banc-tb-super', 'open'),
  ('Incident clos de banc',     'high',     'Un résumé assez long de banc.', 'banc-tb-super', 'banc-tb-super', 'closed');

-- ═══ 1. Droits ═════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'anon n''exécute pas admin_dashboard_tasks', 'false',
  has_function_privilege('anon', 'public.admin_dashboard_tasks()', 'EXECUTE')::text);

SELECT pg_temp.moi('banc-tb-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(2, 'un membre ordinaire : REFUSÉ (pas « tout est calme »)', '42501',
  $q$SELECT public.admin_dashboard_tasks()$q$);
RESET ROLE;

-- ═══ 2. Qui reçoit quelles lignes ══════════════════════════════════════════
SELECT pg_temp.moi('banc-tb-finance');
SET LOCAL ROLE authenticated;
INSERT INTO obtenu_json SELECT 'finance', public.admin_dashboard_tasks();
RESET ROLE;
SELECT pg_temp.verifie(10, 'financeMod : aucune ligne (aucun droit de module), mais une date de calcul', '/true',
  (SELECT pg_temp.cles(v) || '/' || ((v ->> 'computed_at') IS NOT NULL)::text FROM obtenu_json WHERE k = 'finance'));

SELECT pg_temp.moi('banc-tb-content');
SET LOCAL ROLE authenticated;
INSERT INTO obtenu_json SELECT 'content', public.admin_dashboard_tasks();
RESET ROLE;
SELECT pg_temp.verifie(11, 'contentMod : signalements, support, démarches ; ni campagnes, ni données, ni incidents, ni annuaire', 'demarches,reports,support',
  (SELECT pg_temp.cles(v) FROM obtenu_json WHERE k = 'content'));

SELECT pg_temp.moi('banc-tb-biz');
SET LOCAL ROLE authenticated;
INSERT INTO obtenu_json SELECT 'biz', public.admin_dashboard_tasks();
RESET ROLE;
SELECT pg_temp.verifie(12, 'businessMod : l''annuaire seulement', 'listings',
  (SELECT pg_temp.cles(v) FROM obtenu_json WHERE k = 'biz'));

SELECT pg_temp.moi('banc-tb-super');
SET LOCAL ROLE authenticated;
INSERT INTO obtenu_json SELECT 'super', public.admin_dashboard_tasks();
RESET ROLE;
SELECT pg_temp.verifie(13, 'superAdmin : les sept lignes', 'campaigns,demarches,incidents,listings,privacy,reports,support',
  (SELECT pg_temp.cles(v) FROM obtenu_json WHERE k = 'super'));

-- ═══ 3. Les nombres sont ceux des files réelles ════════════════════════════
SELECT pg_temp.verifie(20, 'signalements = nouveaux + en examen + escaladés', 'true',
  (SELECT (pg_temp.compte(v, 'reports')::bigint =
           (SELECT count(*) FROM public.reports WHERE status IN ('pending', 'reviewing', 'escalated')))::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(21, 'signalements : urgent = non pris en charge (pending)', 'true',
  (SELECT ((SELECT i ->> 'urgent' FROM jsonb_array_elements(v -> 'items') i WHERE i ->> 'key' = 'reports')::bigint =
           (SELECT count(*) FROM public.reports WHERE status = 'pending'))::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(22, 'support = ouverts + en cours, sans les clos', 'true',
  (SELECT (pg_temp.compte(v, 'support')::bigint =
           (SELECT count(*) FROM public.support_tickets WHERE status IN ('open', 'in_progress')))::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(23, 'demandes de données : ouvertes seulement, une en retard au moins', 'true/true',
  (SELECT (pg_temp.compte(v, 'privacy')::bigint =
           (SELECT count(*) FROM public.privacy_requests WHERE status IN ('received', 'identity_verified', 'in_progress')))::text || '/' ||
          (((SELECT i ->> 'urgent' FROM jsonb_array_elements(v -> 'items') i WHERE i ->> 'key' = 'privacy')::bigint) >= 1)::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(24, 'incidents : non clos ; urgent = élevés ou critiques non clos', 'true/true',
  (SELECT (pg_temp.compte(v, 'incidents')::bigint =
           (SELECT count(*) FROM public.security_incidents WHERE status <> 'closed'))::text || '/' ||
          (((SELECT i ->> 'urgent' FROM jsonb_array_elements(v -> 'items') i WHERE i ->> 'key' = 'incidents')::bigint) =
           (SELECT count(*) FROM public.security_incidents WHERE status <> 'closed' AND severity IN ('high', 'critical')))::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(25, 'annuaire : fiches actives sans badge', 'true',
  (SELECT (pg_temp.compte(v, 'listings')::bigint =
           (SELECT count(*) FROM public.businesses WHERE is_active AND NOT is_verified))::text
     FROM obtenu_json WHERE k = 'super'));
SELECT pg_temp.verifie(26, 'ce que voit contentMod pour les signalements est le même nombre', 'true',
  (SELECT (pg_temp.compte(c.v, 'reports') = pg_temp.compte(s.v, 'reports'))::text
     FROM obtenu_json c, obtenu_json s WHERE c.k = 'content' AND s.k = 'super'));

-- ═══ 4. Une lecture n'écrit rien ═══════════════════════════════════════════
SELECT pg_temp.verifie(30, 'aucune ligne d''audit pour une simple consultation', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE admin_id LIKE 'banc-tb-%'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
