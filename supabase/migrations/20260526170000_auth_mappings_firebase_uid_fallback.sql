-- =============================================================================
-- Root fix for firebase_uid() returning NULL after session refresh
--
-- Problem: gotrue-dart auto-refreshes the session (background timer or
-- startup recovery). The refreshed JWT is issued by Supabase Auth from the
-- user's current app_metadata in the DB. If app_metadata.firebase_uid is not
-- persisted yet, the refreshed JWT lacks the claim → auth.jwt() shows nothing
-- → firebase_uid() returns NULL → RLS fails.
--
-- Fix: add an auth_mappings table (supabase_uuid → firebase_uid) populated by
-- the Edge Function, and make firebase_uid() fall back to it. This makes RLS
-- work regardless of whether the JWT carries the claim.
-- =============================================================================

-- ── Mapping table ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth_mappings (
  supabase_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  firebase_uid TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS auth_mappings_firebase_uid_idx
  ON auth_mappings (firebase_uid);

ALTER TABLE auth_mappings ENABLE ROW LEVEL SECURITY;

-- Users can read their own mapping (needed if any future client-side check
-- queries this table directly). Writes are service-role only (Edge Function).
CREATE POLICY "auth_mappings_select_own" ON auth_mappings FOR SELECT
  USING (supabase_id = auth.uid());

GRANT SELECT ON TABLE public.auth_mappings TO authenticated;

-- ── firebase_uid() with DB fallback ──────────────────────────────────────────
-- Priority 1: app_metadata.firebase_uid in the JWT (fast, no query)
-- Priority 2: auth_mappings lookup via Supabase UUID (works after refresh)
CREATE OR REPLACE FUNCTION firebase_uid()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    auth.jwt()->'app_metadata'->>'firebase_uid',
    (SELECT am.firebase_uid
       FROM auth_mappings am
      WHERE am.supabase_id = auth.uid()
      LIMIT 1),
    auth.jwt()->>'sub'
  )
$$;

-- ── Re-apply groups INSERT policy (unchanged logic, now benefits from fallback)
DROP POLICY IF EXISTS "groups_insert" ON groups;
CREATE POLICY "groups_insert" ON groups FOR INSERT
  WITH CHECK (firebase_uid() = creator_id);
