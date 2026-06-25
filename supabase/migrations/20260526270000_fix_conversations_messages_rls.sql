-- =============================================================================
-- Fix conversations & messages RLS policies
--
-- Problem: the original policies used current_user_id() which was defined
-- as auth.uid()::text (Supabase UUID). But participant_ids stores Firebase UIDs.
-- The fix_rls_firebase_uid migration updated current_user_id() → firebase_uid()
-- but did NOT re-create the conversations/messages policies.
-- Result: SELECT silently returns empty (no error), INSERT throws 42501.
--
-- Fix: drop and recreate both tables' policies using firebase_uid() explicitly.
-- =============================================================================

-- ── conversations ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "conversations_select" ON conversations;
DROP POLICY IF EXISTS "conversations_insert" ON conversations;
DROP POLICY IF EXISTS "conversations_update" ON conversations;
DROP POLICY IF EXISTS "conversations_delete" ON conversations;

CREATE POLICY "conversations_select" ON conversations
  FOR SELECT USING (participant_ids @> ARRAY[firebase_uid()]);

CREATE POLICY "conversations_insert" ON conversations
  FOR INSERT WITH CHECK (
    participant_ids @> ARRAY[firebase_uid()]
  );

CREATE POLICY "conversations_update" ON conversations
  FOR UPDATE USING (participant_ids @> ARRAY[firebase_uid()]);

CREATE POLICY "conversations_delete" ON conversations
  FOR DELETE USING (created_by = firebase_uid());

-- ── messages ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "messages_select" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;
DROP POLICY IF EXISTS "messages_update" ON messages;
DROP POLICY IF EXISTS "messages_delete" ON messages;

CREATE POLICY "messages_select" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND c.participant_ids @> ARRAY[firebase_uid()]
    )
  );

CREATE POLICY "messages_insert" ON messages
  FOR INSERT WITH CHECK (firebase_uid() = sender_id);

CREATE POLICY "messages_update" ON messages
  FOR UPDATE USING (
    firebase_uid() = sender_id
    OR EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND c.participant_ids @> ARRAY[firebase_uid()]
    )
  );

CREATE POLICY "messages_delete" ON messages
  FOR DELETE USING (firebase_uid() = sender_id);

-- ── Ensure realtime grants are present ───────────────────────────────────────
GRANT SELECT ON TABLE public.conversations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.conversations TO authenticated;
GRANT SELECT ON TABLE public.messages TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.messages TO authenticated;
