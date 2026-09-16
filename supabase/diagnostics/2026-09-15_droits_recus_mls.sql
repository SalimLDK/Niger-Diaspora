-- Diagnostic : pourquoi une conversation basculée n'écrit plus aucun reçu ?
--
-- Symptôme : ouvrir la discussion ne crée ni `delivered_at` ni `read_at`, pas
-- même une ligne dans `mls_message_receipts` — alors qu'une conversation
-- legacy se marque lue normalement par le MÊME `markAsRead`. L'échec est
-- muet : `marquer()` n'a pas de `try`, l'exception remonte au `catch` de
-- `markAsRead` et devient un `Left` que l'appelant ignore.
--
-- Deux causes possibles, et ce fichier les sépare :
--   1. les DROITS de table (`REVOKE ALL` sans `GRANT` complet) ;
--   2. les POLICIES RLS, qui sont un autre mécanisme et qu'un `GRANT` correct
--      ne compense pas.
--
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT 'droits' AS quoi,
       g.grantee,
       g.privilege_type,
       g.column_name
  FROM (
    SELECT grantee, privilege_type, NULL::text AS column_name
      FROM information_schema.table_privileges
     WHERE table_schema = 'public' AND table_name = 'mls_message_receipts'
    UNION ALL
    SELECT grantee, privilege_type, column_name
      FROM information_schema.column_privileges
     WHERE table_schema = 'public' AND table_name = 'mls_message_receipts'
  ) g
 WHERE g.grantee IN ('authenticated', 'anon')
   AND g.privilege_type = 'UPDATE'
 ORDER BY g.grantee, g.privilege_type, g.column_name;

ROLLBACK;
