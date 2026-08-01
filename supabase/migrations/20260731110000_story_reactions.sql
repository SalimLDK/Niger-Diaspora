-- ============================================================================
-- STORY_REACTIONS (§4, rail stories) — une réaction (emoji) par utilisateur
-- et par story, upsert au nouveau tap (comme un "j'aime"), pas d'historique
-- de changements. Complète stories/story_views (migration précédente).
--
-- Idempotent : sûr à rejouer.
-- ============================================================================

CREATE TABLE IF NOT EXISTS story_reactions (
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, user_id)
);

CREATE INDEX IF NOT EXISTS story_reactions_story_idx
  ON story_reactions (story_id);

ALTER TABLE story_reactions ENABLE ROW LEVEL SECURITY;

-- Lecture : l'auteur de la story voit toutes les réactions (qui a réagi
-- avec quoi) ; un spectateur ne voit que la sienne (savoir s'il a déjà
-- réagi) — même logique que story_views_select.
DROP POLICY IF EXISTS "story_reactions_select" ON story_reactions;
CREATE POLICY "story_reactions_select" ON story_reactions FOR SELECT
  USING (
    current_user_id() = user_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id AND s.author_id = current_user_id()
    )
  );

DROP POLICY IF EXISTS "story_reactions_manage_own" ON story_reactions;
CREATE POLICY "story_reactions_manage_own" ON story_reactions FOR ALL
  USING (current_user_id() = user_id)
  WITH CHECK (current_user_id() = user_id);

NOTIFY pgrst, 'reload schema';
