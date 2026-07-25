-- =============================================================================
-- e2ee_devices.device_name : libellé personnalisé d'un appareil E2EE
--
-- Permet à l'utilisateur de renommer ses appareils depuis Settings → Devices.
-- Avant cette colonne, getMyDevices dérivait un libellé de `platform` uniquement
-- et renameDevice écrivait dans Firestore (plus alimenté).
--
-- Idempotent : sûr à rejouer (ADD COLUMN IF NOT EXISTS).
-- NE PAS appliquer en prod sans validation explicite.
-- =============================================================================

ALTER TABLE e2ee_devices
  ADD COLUMN IF NOT EXISTS device_name text;

COMMENT ON COLUMN e2ee_devices.device_name IS
  'User-editable display name for the device. NULL → client falls back to a platform label.';

-- Refresh PostgREST schema cache so the new column is visible immediately.
NOTIFY pgrst, 'reload schema';
