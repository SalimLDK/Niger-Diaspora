-- Diagnostic : les policies RLS de `mls_message_receipts`.
--
-- Un GRANT correct ne suffit pas : RLS est un second mécanisme. Et les deux
-- ne ratent pas de la même façon —
--   * un INSERT refusé par RLS **lève** (42501) ;
--   * un UPDATE refusé par RLS **ne touche aucune ligne, en silence**.
--
-- D'où le symptôme observé le 2026-09-15 : `delivered_at` est écrit (INSERT),
-- `read_at` ne l'est jamais (UPDATE), sans une seule exception dans le
-- journal, et `markAsRead` va jusqu'au bout.
--
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT p.policyname,
       p.cmd,
       p.roles,
       p.qual        AS using_clause,
       p.with_check
  FROM pg_policies p
 WHERE p.schemaname = 'public'
   AND p.tablename  = 'mls_message_receipts'
 ORDER BY p.cmd, p.policyname;

ROLLBACK;
