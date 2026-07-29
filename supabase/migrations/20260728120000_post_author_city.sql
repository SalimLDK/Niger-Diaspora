-- ============================================================================
-- author_city : ville de l'auteur d'une publication, pour le filtre « villes »
-- du fil (§ handoff Fil & Discussion). Complète country_code (pays) déjà présent.
--
-- Renseigné par l'app à la création du post depuis la ville du profil
-- (ProfileEntity.currentCity → PostEntity.authorCity → colonne author_city).
-- Le filtre côté app s'applique aux posts chargés ; cette colonne permet aussi
-- un filtrage serveur ultérieur (index à ajouter alors).
--
-- Idempotent : sûr à rejouer (ADD COLUMN IF NOT EXISTS).
-- ============================================================================

ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_city TEXT;

-- Refresh PostgREST schema cache so the new column is visible immediately.
NOTIFY pgrst, 'reload schema';
