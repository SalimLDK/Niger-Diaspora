-- ============================================================================
-- handle : poignée publique unique de l'utilisateur (@handle), §16f/10c.
--
-- Unicité insensible à la casse via un index UNIQUE sur lower(handle),
-- restreint aux lignes non nulles (une poignée est optionnelle). Les NULL ne
-- sont donc pas contraints — plusieurs utilisateurs peuvent ne pas avoir de
-- poignée.
--
-- L'app normalise déjà la poignée en minuscules avant écriture ; l'index reste
-- le garde-fou serveur (deux clients concurrents ne peuvent pas réserver la
-- même poignée).
--
-- Idempotent : ADD COLUMN IF NOT EXISTS + CREATE UNIQUE INDEX IF NOT EXISTS.
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS handle TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_handle_lower_unique_idx
  ON users (lower(handle))
  WHERE handle IS NOT NULL;

-- Refresh PostgREST schema cache so the new column is visible immediately.
NOTIFY pgrst, 'reload schema';
