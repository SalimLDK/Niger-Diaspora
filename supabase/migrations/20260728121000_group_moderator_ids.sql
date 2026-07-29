-- ============================================================================
-- moderator_ids : rôle « modérateur » de groupe (distinct d'admin), pour le
-- badge MODÉ de la fiche de groupe (§9d handoff Fil & Discussion).
--
-- « Champ seul » : l'app lit/affiche le rôle ; l'affectation des modérateurs
-- reste à câbler côté backend/administration (aucune UI d'affectation dans ce
-- lot). Le badge reste donc inactif tant que le tableau est vide.
--
-- Firestore (miroir) est sans schéma : aucune migration nécessaire côté RTDB.
-- Idempotent : sûr à rejouer (ADD COLUMN IF NOT EXISTS).
-- ============================================================================

ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS moderator_ids TEXT[] NOT NULL DEFAULT '{}';

-- Refresh PostgREST schema cache so the new column is visible immediately.
NOTIFY pgrst, 'reload schema';
