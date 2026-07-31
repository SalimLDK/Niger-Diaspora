-- ============================================================================
-- STORIES (rail « À la une » du fil, § handoff tour 4). Greenfield : aucun
-- modèle existant avant cette migration.
--
-- Périmètre MVP : un seul média par story, expiration 24h filtrée à la
-- requête (WHERE created_at > now() - interval '24h'), pas de purge cron
-- (aucun pg_cron ailleurs dans ce projet). Auteur dénormalisé (author_name,
-- author_photo_url) pour éviter une jointure à chaque lecture du rail —
-- même choix que `posts` (author_id + author_name/photo_url en colonnes).
--
-- Idempotent : sûr à rejouer (CREATE TABLE/INDEX/POLICY IF NOT EXISTS,
-- DROP POLICY IF EXISTS avant CREATE POLICY).
-- ============================================================================

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_name TEXT,
  author_photo_url TEXT,
  media_url TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  video_duration_seconds INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS stories_author_created_idx
  ON stories (author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS stories_active_idx
  ON stories (created_at DESC);

ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stories_select" ON stories;
CREATE POLICY "stories_select" ON stories FOR SELECT
  USING (created_at > NOW() - INTERVAL '24 hours');

DROP POLICY IF EXISTS "stories_manage_own" ON stories;
CREATE POLICY "stories_manage_own" ON stories FOR ALL
  USING (current_user_id() = author_id);

CREATE TABLE IF NOT EXISTS story_views (
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS story_views_story_idx ON story_views (story_id);

ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;

-- Lecture : l'auteur de la story (compteur de vues) et le spectateur
-- lui-même (savoir ce qu'il a déjà vu).
DROP POLICY IF EXISTS "story_views_select" ON story_views;
CREATE POLICY "story_views_select" ON story_views FOR SELECT
  USING (
    current_user_id() = viewer_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_views.story_id AND s.author_id = current_user_id()
    )
  );

DROP POLICY IF EXISTS "story_views_insert_own" ON story_views;
CREATE POLICY "story_views_insert_own" ON story_views FOR INSERT
  WITH CHECK (current_user_id() = viewer_id);

-- Refresh PostgREST schema cache so the new tables are visible immediately.
NOTIFY pgrst, 'reload schema';
