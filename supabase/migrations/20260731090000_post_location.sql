-- ============================================================================
-- Lieu joint à un post (§ handoff Fil & Discussion, tours 13/23d). Les trois
-- colonnes vont ensemble ou sont toutes NULL — pas de contrainte CHECK
-- imposée côté DB, la cohérence est garantie côté app (post_entity.dart).
--
-- Idempotent : sûr à rejouer (ADD COLUMN IF NOT EXISTS).
-- ============================================================================

ALTER TABLE posts ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_address TEXT;

-- Refresh PostgREST schema cache so the new columns are visible immediately.
NOTIFY pgrst, 'reload schema';
