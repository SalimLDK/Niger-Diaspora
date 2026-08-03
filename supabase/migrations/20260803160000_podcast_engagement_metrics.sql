-- =============================================================================
-- Rendre réelles les métriques d'engagement des podcasts.
--
-- Problème corrigé
-- ----------------
-- L'écran de statistiques (podcast_stats_screen.dart) affiche « J'aime »,
-- « Partages » et « Téléchargements » sous un intitulé « Engagement », plus une
-- section « Rythme de publication ». Aucune de ces valeurs ne pouvait bouger :
--
--   - share_count / download_count : les colonnes n'existaient pas, le mapper
--     ne les lisait pas, et RIEN dans l'app ne les incrémentait. Les boutons
--     Partager et Télécharger de episode_detail_screen n'enregistraient rien.
--   - like_count : la colonne n'existait pas non plus. likeEpisode() écrit
--     seulement podcast_user_data.liked, sans jamais agréger sur l'épisode.
--   - published_at : colonne absente, donc publishedAt toujours NULL et la
--     section « Rythme de publication » affichait « — » en permanence.
--   - increment_podcast_play : la RPC est appelée par recordPlay() depuis
--     toujours, mais n'était définie dans aucune migration. Si elle n'existe
--     pas non plus au distant, même le compteur d'écoutes — le chiffre vedette
--     de l'écran — reste à zéro.
--
-- Un zéro affiché sous « Engagement » se lit « personne n'a partagé », alors
-- que la vérité était « ce n'est pas mesuré ». C'est ce mensonge par omission
-- que cette migration supprime.
--
-- podcast_user_data est également créée ici : la table est lue et écrite par
-- l'app depuis toujours mais n'apparaissait dans aucune migration. Le stream
-- Dart l'interroge avec primaryKey ['id'], d'où la colonne id.
-- =============================================================================

-- ─── Colonnes manquantes ────────────────────────────────────────────────────
ALTER TABLE podcast_episodes
  ADD COLUMN IF NOT EXISTS like_count     INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS download_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS published_at   TIMESTAMPTZ;

ALTER TABLE podcasts
  ADD COLUMN IF NOT EXISTS total_play_count INTEGER NOT NULL DEFAULT 0;

-- Les épisodes déjà publiés n'ont pas de date de publication : sans ce
-- rattrapage, « Rythme de publication » resterait vide pour tout l'existant.
UPDATE podcast_episodes
SET published_at = created_at
WHERE published_at IS NULL AND status = 'published';

-- ─── Données d'écoute par utilisateur ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS podcast_user_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES podcast_episodes(id) ON DELETE CASCADE,
  podcast_id UUID REFERENCES podcasts(id) ON DELETE CASCADE,
  liked BOOLEAN NOT NULL DEFAULT FALSE,
  progress_seconds INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, episode_id)
);

CREATE INDEX IF NOT EXISTS podcast_user_data_user_idx
  ON podcast_user_data (user_id);
CREATE INDEX IF NOT EXISTS podcast_user_data_episode_idx
  ON podcast_user_data (episode_id) WHERE liked;

ALTER TABLE podcast_user_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "podcast_user_data_own" ON podcast_user_data;
CREATE POLICY "podcast_user_data_own" ON podcast_user_data FOR ALL
  USING (user_id = (SELECT firebase_uid()))
  WITH CHECK (user_id = (SELECT firebase_uid()));

-- ─── Compteurs ──────────────────────────────────────────────────────────────
-- SECURITY DEFINER : un auditeur n'est pas propriétaire du podcast, la policy
-- podcast_episodes_manage lui interdit donc l'UPDATE. Ces fonctions sont le
-- seul chemin d'écriture accordé, et elles ne touchent qu'un compteur.

CREATE OR REPLACE FUNCTION increment_podcast_play(
  p_episode_id UUID,
  p_podcast_id UUID
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE podcast_episodes
  SET play_count = play_count + 1
  WHERE id = p_episode_id;

  UPDATE podcasts
  SET total_play_count = total_play_count + 1
  WHERE id = p_podcast_id;
END $$;

CREATE OR REPLACE FUNCTION increment_podcast_share(p_episode_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE podcast_episodes
  SET share_count = share_count + 1
  WHERE id = p_episode_id;
END $$;

CREATE OR REPLACE FUNCTION increment_podcast_download(p_episode_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE podcast_episodes
  SET download_count = download_count + 1
  WHERE id = p_episode_id;
END $$;

-- Recalcul plutôt qu'incrément : likeEpisode() fait un upsert idempotent,
-- un +1 par appel gonflerait le compteur à chaque re-tap.
CREATE OR REPLACE FUNCTION refresh_episode_like_count(p_episode_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE podcast_episodes e
  SET like_count = (
    SELECT COUNT(*)
    FROM podcast_user_data d
    WHERE d.episode_id = e.id AND d.liked
  )
  WHERE e.id = p_episode_id;
END $$;

GRANT EXECUTE ON FUNCTION increment_podcast_play(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_podcast_share(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_podcast_download(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_episode_like_count(UUID) TO authenticated;
