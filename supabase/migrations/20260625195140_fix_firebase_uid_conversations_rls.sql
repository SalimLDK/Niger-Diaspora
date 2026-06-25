-- =============================================================================
-- Appliquer les correctifs live du 2026-06-25 :
-- 1. firebase_uid() : ajout du fallback sur auth.jwt()->>'sub'
-- 2. conversations_insert : retirer la condition created_by = firebase_uid()
-- =============================================================================

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

DROP POLICY IF EXISTS "conversations_insert" ON conversations;
CREATE POLICY "conversations_insert" ON conversations
  FOR INSERT WITH CHECK (
    participant_ids @> ARRAY[firebase_uid()]
  );
