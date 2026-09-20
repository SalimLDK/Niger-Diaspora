-- Banc de `account_deletion_completed` : un téléphone déconnecté peut-il savoir,
-- SANS COMPTE, si une suppression est menée à terme — et rien de plus ?
--
-- Suppose `20260918224100` APPLIQUÉE et joue `20260919123300` dans la même
-- transaction :
--
--   { echo "BEGIN;"; \
--     cat supabase/migrations/20260919123300_suppression_compte_effacement_local.sql; \
--     cat tools/rls_tests/suppression_compte_effacement_local.sql; \
--     echo "ROLLBACK;"; } > /tmp/effacement_local_banc.sql
--   supabase db query --linked -o csv -f /tmp/effacement_local_banc.sql
--
-- Une fois cette migration appliquée, ce fichier se joue seul entre `BEGIN;` et
-- `ROLLBACK;`. Condition : 0 cas en ÉCHEC — la dernière ligne le dit.
--
-- CE QUE LE BANC ÉTABLIT
-- La réponse est un booléen, `true` pour `completed` et pour RIEN d'autre : un
-- compte en délai de grâce (`pending`), en cours (`deleting`), bloqué ou annulé est
-- indiscernable d'un compte qui n'a rien demandé. Elle se lit sous les rôles `anon`
-- (le téléphone n'a plus de session) et `authenticated`, et n'ouvre pas la table.

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated, anon;

CREATE FUNCTION pg_temp.verifie(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, p_obtenu,
    CASE WHEN p_attendu IS NOT DISTINCT FROM p_obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$$;

-- Une demande dans chaque état.
INSERT INTO public.account_deletion_requests (user_id, status, execute_at) VALUES
  ('zz_loc_completed', 'completed', now() - interval '2 days'),
  ('zz_loc_pending',   'pending',   now() + interval '20 days'),
  ('zz_loc_deleting',  'deleting',  now() - interval '1 hour'),
  ('zz_loc_blocked',   'blocked',   now() - interval '1 hour'),
  ('zz_loc_cancelled', 'cancelled', now() + interval '10 days');

-- ═══ Droits ═════════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'droits : anon, authenticated et service_role — le téléphone n''a plus de session',
  'anon=true authenticated=true service_role=true',
  'anon=' || has_function_privilege('anon','public.account_deletion_completed(text)','EXECUTE')::text
  || ' authenticated=' || has_function_privilege('authenticated','public.account_deletion_completed(text)','EXECUTE')::text
  || ' service_role=' || has_function_privilege('service_role','public.account_deletion_completed(text)','EXECUTE')::text);

SELECT pg_temp.verifie(2, 'la table reste FERMÉE à l''anonyme : la fonction n''ouvre que son booléen',
  'select=false insert=false update=false delete=false',
  'select=' || has_table_privilege('anon','public.account_deletion_requests','SELECT')::text
  || ' insert=' || has_table_privilege('anon','public.account_deletion_requests','INSERT')::text
  || ' update=' || has_table_privilege('anon','public.account_deletion_requests','UPDATE')::text
  || ' delete=' || has_table_privilege('anon','public.account_deletion_requests','DELETE')::text);

-- ═══ Ce que répond la fonction, SANS COMPTE ═════════════════════════════════
SET LOCAL ROLE anon;
INSERT INTO ctx SELECT 'completed', public.account_deletion_completed('zz_loc_completed')::text;
INSERT INTO ctx SELECT 'pending',   public.account_deletion_completed('zz_loc_pending')::text;
INSERT INTO ctx SELECT 'deleting',  public.account_deletion_completed('zz_loc_deleting')::text;
INSERT INTO ctx SELECT 'blocked',   public.account_deletion_completed('zz_loc_blocked')::text;
INSERT INTO ctx SELECT 'cancelled', public.account_deletion_completed('zz_loc_cancelled')::text;
INSERT INTO ctx SELECT 'inconnu',   public.account_deletion_completed('zz_loc_inconnu')::text;
INSERT INTO ctx SELECT 'vide',      public.account_deletion_completed('')::text;
INSERT INTO ctx SELECT 'nul',       COALESCE(public.account_deletion_completed(NULL)::text, 'NULL');
RESET ROLE;

SELECT pg_temp.verifie(3, 'sous `anon` : vrai pour completed, et POUR RIEN D''AUTRE',
  'completed=true pending=false deleting=false blocked=false cancelled=false',
  'completed=' || (SELECT v FROM ctx WHERE k = 'completed')
  || ' pending=' || (SELECT v FROM ctx WHERE k = 'pending')
  || ' deleting=' || (SELECT v FROM ctx WHERE k = 'deleting')
  || ' blocked=' || (SELECT v FROM ctx WHERE k = 'blocked')
  || ' cancelled=' || (SELECT v FROM ctx WHERE k = 'cancelled'));

SELECT pg_temp.verifie(4, 'un uid inconnu, vide ou NULL : faux, jamais une erreur',
  'inconnu=false vide=false nul=false',
  'inconnu=' || (SELECT v FROM ctx WHERE k = 'inconnu')
  || ' vide=' || (SELECT v FROM ctx WHERE k = 'vide')
  || ' nul=' || (SELECT v FROM ctx WHERE k = 'nul'));

SELECT pg_temp.verifie(5, 'le type rendu est un booléen : rien d''autre ne s''en échappe',
  'boolean', pg_typeof(public.account_deletion_completed('zz_loc_completed'))::text);

-- Un compte en délai de grâce est INDISCERNABLE d'un compte qui n'a rien demandé.
SELECT pg_temp.verifie(6, 'indiscernabilité : pending, deleting, blocked, cancelled et « jamais demandé » rendent la même réponse',
  '1', (SELECT count(DISTINCT v)::text FROM ctx WHERE k IN ('pending', 'deleting', 'blocked', 'cancelled', 'inconnu')));

-- ═══ Sous un compte connecté aussi ══════════════════════════════════════════
SET LOCAL ROLE authenticated;
INSERT INTO ctx SELECT 'auth_completed', public.account_deletion_completed('zz_loc_completed')::text;
INSERT INTO ctx SELECT 'auth_pending',   public.account_deletion_completed('zz_loc_pending')::text;
RESET ROLE;
SELECT pg_temp.verifie(7, 'sous `authenticated` : même réponse',
  'completed=true pending=false',
  'completed=' || (SELECT v FROM ctx WHERE k = 'auth_completed')
  || ' pending=' || (SELECT v FROM ctx WHERE k = 'auth_pending'));

-- ═══ Verdict ════════════════════════════════════════════════════════════════
SELECT n, cas, attendu, obtenu, verdict FROM resultat
UNION ALL
SELECT 9999, 'BILAN', '0 échec',
       count(*) FILTER (WHERE verdict <> 'OK')::text || ' échec(s) sur ' || count(*)::text,
       CASE WHEN count(*) FILTER (WHERE verdict <> 'OK') = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM resultat
ORDER BY 1;
