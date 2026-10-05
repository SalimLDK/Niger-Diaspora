-- Banc : `TRUNCATE`, `REFERENCES`, `TRIGGER` retirés aux rôles clients sur la
-- messagerie (migration 20261005120000).
--
--   supabase db query --linked -f tools/rls_tests/messagerie_sans_truncate.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, le cas 1 est en ÉCHEC (le défaut Supabase accorde les
-- trois verbes) — le banc ne peut pas passer à tort.
--
-- Lecture seule des catalogues : rien n'est écrit.

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);

-- @@MIGRATION@@

CREATE TEMP TABLE tables_messagerie AS
SELECT t FROM unnest(ARRAY[
  'messages', 'conversations', 'group_members', 'group_pinned_items',
  'conversation_devices',
  'mls_messages', 'mls_commits', 'mls_welcomes', 'mls_devices',
  'mls_key_packages', 'mls_diagnostics',
  'mls_message_hidden', 'mls_message_mentions', 'mls_message_reactions',
  'mls_message_receipts', 'mls_message_stars'
]) AS t
WHERE to_regclass('public.' || t) IS NOT NULL;

-- 1. Plus aucun des trois verbes, pour aucun des deux rôles.
INSERT INTO resultat
SELECT 1, 'TRUNCATE / REFERENCES / TRIGGER retirés (anon, authenticated)', 'aucun',
       COALESCE(string_agg(r || ':' || v || ':' || t, ', '), 'aucun'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM tables_messagerie,
       unnest(ARRAY['anon', 'authenticated']) AS r,
       unnest(ARRAY['TRUNCATE', 'REFERENCES', 'TRIGGER']) AS v
 WHERE has_table_privilege(r, 'public.' || t, v);

-- 2. L'app garde ce qu'elle emploie : lire et envoyer un message, lire une
--    conversation, en modifier `data`.
INSERT INTO resultat
SELECT 2, 'authenticated garde SELECT/INSERT messages, SELECT conversations, UPDATE(data)',
       'true true true true',
       format('%s %s %s %s',
         has_table_privilege('authenticated', 'public.messages', 'SELECT'),
         has_table_privilege('authenticated', 'public.messages', 'INSERT'),
         has_table_privilege('authenticated', 'public.conversations', 'SELECT'),
         has_column_privilege('authenticated', 'public.messages', 'data', 'UPDATE')),
       CASE WHEN has_table_privilege('authenticated', 'public.messages', 'SELECT')
             AND has_table_privilege('authenticated', 'public.messages', 'INSERT')
             AND has_table_privilege('authenticated', 'public.conversations', 'SELECT')
             AND has_column_privilege('authenticated', 'public.messages', 'data', 'UPDATE')
            THEN 'OK' ELSE 'ÉCHEC' END;

-- 3. Combien de tables le banc a vues : zéro voudrait dire un banc à vide.
INSERT INTO resultat
SELECT 3, 'tables de la messagerie trouvées', '≥ 3', count(*)::text,
       CASE WHEN count(*) >= 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM tables_messagerie;

SELECT n, verdict, cas, attendu, left(obtenu, 200) AS obtenu FROM resultat ORDER BY n;

ROLLBACK;
