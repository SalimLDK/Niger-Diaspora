-- Banc : modération des ambassades (migration 20261019090000).
--
--   supabase db query --linked -f tools/rls_tests/ambassades_moderation.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'une ambassade soit marquée « vérifiée »
-- ou suspendue sans source, sans motif, par quelqu'un qui n'en a pas le droit
-- ou par une écriture directe — ou que ces gestes ne laissent aucune trace
-- (ils n'en laissaient aucune). Il vérifie aussi que le super-administrateur
-- garde la main sur les champs de contact, et que les 32 fiches existantes ne
-- bougent pas.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE avant(k text, v text);

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

-- L'état des fiches réelles, avant tout.
INSERT INTO avant
  SELECT 'etat', count(*) || '/' || count(*) FILTER (WHERE is_verified) || '/' || count(*) FILTER (WHERE is_suspended)
    FROM public.embassies;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-amb-super',   'Super',   'amb-super@banc.test',   true,  'superAdmin'),
  ('banc-amb-content', 'Content', 'amb-content@banc.test', true,  'contentMod'),
  ('banc-amb-finance', 'Finance', 'amb-fin@banc.test',     true,  'financeMod'),
  ('banc-amb-ordi',    'Ordi',    'amb-ordi@banc.test',    false, NULL);

INSERT INTO public.embassies (id, name, country, city, is_verified) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'a1 à vérifier',  'Banclandia', 'Capitale', false),
  ('00000000-0000-0000-0000-0000000000a2', 'a2 à suspendre', 'Banclandia', 'Port',     false),
  ('00000000-0000-0000-0000-0000000000a3', 'a3 à refuser',   'Banclandia', 'Nord',     false);

-- ═══ 1. Catalogue, droits, existant ════════════════════════════════════════
SELECT pg_temp.verifie(1, 'les 2 permissions sont au catalogue, mappées à AUCUN rôle', '2/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('consular.embassies.verify', 'consular.embassies.suspend')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission IN ('consular.embassies.verify', 'consular.embassies.suspend')));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des quatre RPC', 'false',
  (has_function_privilege('anon', 'public.embassy_admin_verify(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.embassy_admin_reject(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.embassy_admin_suspend(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.embassy_admin_unsuspend(uuid,text)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'TRUNCATE / REFERENCES / TRIGGER retirés à anon et authenticated', 'false',
  (has_table_privilege('anon', 'public.embassies', 'TRUNCATE')
   OR has_table_privilege('authenticated', 'public.embassies', 'TRUNCATE')
   OR has_table_privilege('anon', 'public.embassies', 'REFERENCES')
   OR has_table_privilege('authenticated', 'public.embassies', 'TRIGGER'))::text);
SELECT pg_temp.verifie(4, 'la lecture publique est intacte', 'true',
  has_table_privilege('anon', 'public.embassies', 'SELECT')::text);

-- ═══ 2. Vérifier : refus et validations ════════════════════════════════════
SELECT pg_temp.moi('banc-amb-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : vérifier REFUSÉ', '42501',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'https://gouv.exemple/x', 'Ministère')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-amb-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'contentMod : vérifier REFUSÉ (comme avant : super-administrateur seul)', '42501',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'https://gouv.exemple/x', 'Ministère')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-amb-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'financeMod : suspendre REFUSÉ', '42501',
  $q$SELECT public.embassy_admin_suspend('00000000-0000-0000-0000-0000000000a2', 'Fermeture signalée')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-amb-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'super : vérifier sans adresse de source → 22023', '22023',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', NULL, 'Ministère')$q$);
SELECT pg_temp.essai(14, 'super : adresse en http:// → 22023', '22023',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'http://gouv.exemple/x', 'Ministère')$q$);
SELECT pg_temp.essai(15, 'super : éditeur manquant → 22023', '22023',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'https://gouv.exemple/x', ' ')$q$);
SELECT pg_temp.essai(16, 'super : ambassade introuvable → P0002', 'P0002',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000ff', 'https://gouv.exemple/x', 'Ministère')$q$);
SELECT pg_temp.essai(17, 'super : vérifie a1 avec sa source', 'OK',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'https://gouv.exemple/consulats', 'Ministère des affaires étrangères')$q$);
SELECT pg_temp.essai(18, 'super : vérifier a1 de nouveau → 55000', '55000',
  $q$SELECT public.embassy_admin_verify('00000000-0000-0000-0000-0000000000a1', 'https://gouv.exemple/consulats', 'Ministère des affaires étrangères')$q$);
RESET ROLE;

SELECT pg_temp.verifie(19, 'a1 : vérifiée, source et date posées', 'true/https://gouv.exemple/consulats/Ministère des affaires étrangères/true',
  (SELECT is_verified::text || '/' || source_url || '/' || source || '/' || (verified_at IS NOT NULL AND source_checked_at IS NOT NULL)::text
     FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a1'));

-- ═══ 3. Aucune écriture directe n'atteint le statut ════════════════════════
SELECT pg_temp.moi('banc-amb-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'super : poser is_verified par PostgREST REFUSÉ', '42501',
  $q$UPDATE public.embassies SET is_verified = true WHERE id = '00000000-0000-0000-0000-0000000000a2'$q$);
SELECT pg_temp.essai(21, 'super : poser is_suspended par PostgREST REFUSÉ', '42501',
  $q$UPDATE public.embassies SET is_suspended = true WHERE id = '00000000-0000-0000-0000-0000000000a2'$q$);
SELECT pg_temp.essai(22, 'super : effacer un motif de refus par PostgREST REFUSÉ', '42501',
  $q$UPDATE public.embassies SET rejection_reason = NULL, verified_at = now() WHERE id = '00000000-0000-0000-0000-0000000000a2'$q$);
SELECT pg_temp.essai(23, 'super : créer une ambassade DÉJÀ vérifiée REFUSÉ', '42501',
  $q$INSERT INTO public.embassies (name, country, city, is_verified) VALUES ('faux', 'Banclandia', 'X', true)$q$);
SELECT pg_temp.essai(24, 'super : créer une ambassade normale (comme l''écran de création)', 'OK',
  $q$INSERT INTO public.embassies (name, country, city, is_verified, is_suspended) VALUES ('neuve', 'Banclandia', 'Sud', false, false)$q$);
SELECT pg_temp.essai(25, 'super : corriger un numéro de téléphone', 'OK',
  $q$UPDATE public.embassies SET phone = '+000 11 22 33' WHERE id = '00000000-0000-0000-0000-0000000000a2'$q$);
UPDATE public.embassies SET name = 'écrasé' WHERE false;
DELETE FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a2';
RESET ROLE;
SELECT pg_temp.verifie(26, 'DELETE direct : a2 est toujours là', '1',
  (SELECT count(*)::text FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a2'));

-- ═══ 4. Refuser, suspendre, réactiver ══════════════════════════════════════
SELECT pg_temp.moi('banc-amb-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'refuser sans motif → 22023', '22023',
  $q$SELECT public.embassy_admin_reject('00000000-0000-0000-0000-0000000000a3', '')$q$);
SELECT pg_temp.essai(31, 'refuse a3 avec motif', 'OK',
  $q$SELECT public.embassy_admin_reject('00000000-0000-0000-0000-0000000000a3', 'Adresse introuvable chez la source officielle')$q$);
SELECT pg_temp.essai(32, 'refuser a3 de nouveau → 55000', '55000',
  $q$SELECT public.embassy_admin_reject('00000000-0000-0000-0000-0000000000a3', 'Adresse introuvable chez la source officielle')$q$);
SELECT pg_temp.essai(33, 'suspendre sans motif → 22023', '22023',
  $q$SELECT public.embassy_admin_suspend('00000000-0000-0000-0000-0000000000a2', 'x')$q$);
SELECT pg_temp.essai(34, 'suspend a2', 'OK',
  $q$SELECT public.embassy_admin_suspend('00000000-0000-0000-0000-0000000000a2', 'Fermeture signalée par un usager')$q$);
SELECT pg_temp.essai(35, 'suspendre a2 de nouveau → 55000', '55000',
  $q$SELECT public.embassy_admin_suspend('00000000-0000-0000-0000-0000000000a2', 'Fermeture signalée par un usager')$q$);
SELECT pg_temp.essai(36, 'réactiver sans motif → 22023', '22023',
  $q$SELECT public.embassy_admin_unsuspend('00000000-0000-0000-0000-0000000000a2', '')$q$);
SELECT pg_temp.essai(37, 'réactiver a1 (non suspendue) → 55000', '55000',
  $q$SELECT public.embassy_admin_unsuspend('00000000-0000-0000-0000-0000000000a1', 'Erreur de ma part')$q$);
RESET ROLE;
SELECT pg_temp.verifie(38, 'a3 refusée : non vérifiée, motif conservé', 'false/Adresse introuvable chez la source officielle',
  (SELECT is_verified::text || '/' || rejection_reason FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a3'));
SELECT pg_temp.verifie(39, 'a2 suspendue : motif et date conservés', 'true/Fermeture signalée par un usager/true',
  (SELECT is_suspended::text || '/' || suspended_reason || '/' || (suspended_at IS NOT NULL)::text
     FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a2'));

SELECT pg_temp.moi('banc-amb-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'réactive a2 avec motif', 'OK',
  $q$SELECT public.embassy_admin_unsuspend('00000000-0000-0000-0000-0000000000a2', 'Ouverture confirmée par téléphone')$q$);
RESET ROLE;
SELECT pg_temp.verifie(41, 'a2 réactivée : suspension effacée', 'false/vide',
  (SELECT is_suspended::text || '/' || coalesce(suspended_reason, 'vide') FROM public.embassies WHERE id = '00000000-0000-0000-0000-0000000000a2'));

-- ═══ 5. Historique ═════════════════════════════════════════════════════════
SELECT pg_temp.verifie(50, 'a1 : la vérification est consignée, avec la source comme motif', 'changed/admin/banc-amb-super/Ministère des affaires étrangères',
  (SELECT kind || '/' || actor_role || '/' || actor_id || '/' || reason
     FROM public.embassy_history WHERE embassy_id = '00000000-0000-0000-0000-0000000000a1' AND changes ? 'is_verified'));
SELECT pg_temp.verifie(51, 'a2 : téléphone, suspension, réactivation = 3 lignes', '3',
  (SELECT count(*)::text FROM public.embassy_history WHERE embassy_id = '00000000-0000-0000-0000-0000000000a2' AND kind = 'changed'));
SELECT pg_temp.verifie(52, 'la suspension porte son motif dans l''historique', 'true',
  (SELECT bool_or(reason = 'Fermeture signalée par un usager' AND changes ? 'is_suspended')::text
     FROM public.embassy_history WHERE embassy_id = '00000000-0000-0000-0000-0000000000a2'));
SELECT pg_temp.verifie(53, 'la création de l''ambassade « neuve » est consignée', '1',
  (SELECT count(*)::text FROM public.embassy_history WHERE kind = 'created' AND embassy_name = 'neuve'));

SELECT pg_temp.moi('banc-amb-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(54, 'contentMod (consular.view) lit l''historique', 'true',
  ((SELECT count(*) FROM public.embassy_history) >= 5)::text);
RESET ROLE;
SELECT pg_temp.moi('banc-amb-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(55, 'financeMod ne lit pas l''historique', '0', (SELECT count(*)::text FROM public.embassy_history));
RESET ROLE;
SELECT pg_temp.essai(56, 'UPDATE de l''historique REFUSÉ', '42501',
  $q$UPDATE public.embassy_history SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(57, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.embassy_history$q$);

-- ═══ 6. Audit, et les fiches réelles n'ont pas bougé ═══════════════════════
SELECT pg_temp.verifie(60, 'audit : vérifiée 1, refusée 1, suspendue 1, réactivée 1', '1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'EMBASSY_VERIFIED') || '/' ||
          count(*) FILTER (WHERE action = 'EMBASSY_REJECTED') || '/' ||
          count(*) FILTER (WHERE action = 'EMBASSY_SUSPENDED') || '/' ||
          count(*) FILTER (WHERE action = 'EMBASSY_REACTIVATED')
     FROM public.admin_audit_logs WHERE target_id LIKE '00000000-0000-0000-0000-0000000000a%'));
SELECT pg_temp.verifie(61, 'les fiches existantes sont inchangées (total/vérifiées/suspendues, hors celles du banc)', (SELECT v FROM avant WHERE k = 'etat'),
  (SELECT count(*) || '/' || count(*) FILTER (WHERE is_verified) || '/' || count(*) FILTER (WHERE is_suspended)
     FROM public.embassies WHERE country <> 'Banclandia'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
