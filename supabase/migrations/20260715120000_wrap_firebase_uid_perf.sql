-- =============================================================================
-- Perf RLS : envelopper firebase_uid() en (SELECT firebase_uid())
--
-- Problème : firebase_uid() est STABLE mais fait une sous-requête sur
-- auth_mappings à chaque évaluation. Appelée nue dans une policy
-- (ex: firebase_uid() = sender_id), Postgres peut la ré-évaluer LIGNE PAR LIGNE
-- lors d'un scan → coût O(n) sur les grosses tables (messages, posts).
--
-- Fix (best practice Supabase) : envelopper l'appel dans un sous-SELECT
-- « (SELECT firebase_uid()) ». Le planificateur le traite alors comme un
-- InitPlan évalué UNE SEULE FOIS par requête, plus par ligne.
--
-- Portée : uniquement les tables à fort volume / fort trafic. Logique
-- fonctionnelle STRICTEMENT identique — seule la forme change.
-- Idempotent : DROP POLICY IF EXISTS avant chaque CREATE.
-- =============================================================================

-- ── MESSAGES ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "messages_select" ON messages;
CREATE POLICY "messages_select" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND c.participant_ids @> ARRAY[(SELECT firebase_uid())]
    )
  );

DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages
  FOR INSERT WITH CHECK ((SELECT firebase_uid()) = sender_id);

DROP POLICY IF EXISTS "messages_update" ON messages;
CREATE POLICY "messages_update" ON messages
  FOR UPDATE USING (
    (SELECT firebase_uid()) = sender_id
    OR EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND c.participant_ids @> ARRAY[(SELECT firebase_uid())]
    )
  );

DROP POLICY IF EXISTS "messages_delete" ON messages;
CREATE POLICY "messages_delete" ON messages
  FOR DELETE USING ((SELECT firebase_uid()) = sender_id);

-- ── CONVERSATIONS ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "conversations_select" ON conversations;
CREATE POLICY "conversations_select" ON conversations
  FOR SELECT USING (participant_ids @> ARRAY[(SELECT firebase_uid())]);

DROP POLICY IF EXISTS "conversations_insert" ON conversations;
CREATE POLICY "conversations_insert" ON conversations
  FOR INSERT WITH CHECK (participant_ids @> ARRAY[(SELECT firebase_uid())]);

DROP POLICY IF EXISTS "conversations_update" ON conversations;
CREATE POLICY "conversations_update" ON conversations
  FOR UPDATE USING (participant_ids @> ARRAY[(SELECT firebase_uid())]);

DROP POLICY IF EXISTS "conversations_delete" ON conversations;
CREATE POLICY "conversations_delete" ON conversations
  FOR DELETE USING (created_by = (SELECT firebase_uid()));

-- ── POSTS ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "posts_select" ON posts;
CREATE POLICY "posts_select" ON posts
  FOR SELECT USING (
    visibility = 'public'
    OR (SELECT firebase_uid()) = author_id
    OR (visibility = 'friends' AND EXISTS (
      SELECT 1 FROM friends f
      WHERE f.user_id = (SELECT firebase_uid()) AND f.friend_id = author_id
    ))
  );

DROP POLICY IF EXISTS "posts_manage_own" ON posts;
CREATE POLICY "posts_manage_own" ON posts
  FOR ALL USING ((SELECT firebase_uid()) = author_id);

-- ── POST_COMMENTS ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "post_comments_manage_own" ON post_comments;
CREATE POLICY "post_comments_manage_own" ON post_comments
  FOR ALL USING ((SELECT firebase_uid()) = author_id);

-- ── POST_LIKES ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "post_likes_all" ON post_likes;
CREATE POLICY "post_likes_all" ON post_likes
  FOR ALL USING ((SELECT firebase_uid()) = user_id);

NOTIFY pgrst, 'reload schema';
