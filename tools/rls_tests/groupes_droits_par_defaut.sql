-- Banc : droits par défaut retirés aux tables de groupes, création d'un
-- groupe officiel fermée aux anonymes (migration 20261014120000).
--
--   supabase db query --linked -f tools/rls_tests/groupes_droits_par_defaut.sql
--
-- Condition : 0 cas en ÉCHEC. Lecture seule du catalogue, dans un
-- `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant. Sans la migration, tous les cas « refusé » tombent ; les
-- cas « témoin » vérifient que les verbes utiles et l'appel en session
-- restent.

BEGIN;

-- @@MIGRATION@@

WITH t(nom) AS (VALUES ('groups'), ('group_requests'), ('group_invites'), ('departs_groupe_officiel')),
     r(role) AS (VALUES ('anon'), ('authenticated')),
     v(verbe) AS (VALUES ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'))
SELECT CASE WHEN has_table_privilege(r.role, 'public.' || t.nom, v.verbe) THEN 'ÉCHEC' ELSE 'OK' END AS verdict,
       r.role || ' ' || v.verbe || ' ' || t.nom || ' : refusé' AS cas
  FROM t, r, v
 WHERE to_regclass('public.' || t.nom) IS NOT NULL
UNION ALL
SELECT CASE WHEN has_table_privilege('authenticated', 'public.' || t.nom, 'SELECT') THEN 'OK' ELSE 'ÉCHEC' END,
       'témoin : authenticated SELECT ' || t.nom
  FROM (VALUES ('groups'), ('group_requests'), ('group_invites')) AS t(nom)
 WHERE to_regclass('public.' || t.nom) IS NOT NULL
UNION ALL
SELECT CASE WHEN has_function_privilege('anon', 'public.get_or_create_official_group(text, text)', 'EXECUTE')
            THEN 'ÉCHEC' ELSE 'OK' END,
       'anon EXECUTE get_or_create_official_group : refusé'
UNION ALL
SELECT CASE WHEN has_function_privilege('authenticated', 'public.get_or_create_official_group(text, text)', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END,
       'témoin : authenticated EXECUTE get_or_create_official_group'
ORDER BY 1, 2;

ROLLBACK;
