-- ============================================================================
-- Backfill de posts.author_city pour les publications antérieures à l'ajout de
-- la colonne (migration 20260728120000). Renseigne la ville de l'auteur depuis
-- son profil (table users, colonne city) pour que le filtre « villes » du fil
-- couvre aussi l'historique, pas seulement les nouveaux posts.
--
-- Idempotent / sûr à rejouer : ne touche QUE les lignes dont author_city est
-- vide, et seulement quand le profil a une ville renseignée. Cast ::text des
-- deux côtés du join pour être robuste au type de author_id / users.id.
-- ============================================================================

UPDATE posts p
SET author_city = u.city
FROM users u
WHERE p.author_id::text = u.id::text
  AND (p.author_city IS NULL OR p.author_city = '')
  AND u.city IS NOT NULL
  AND btrim(u.city) <> '';

-- Refresh PostgREST schema cache (par cohérence ; aucune structure changée ici).
NOTIFY pgrst, 'reload schema';
