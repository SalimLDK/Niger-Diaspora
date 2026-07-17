-- ============================================================================
-- external_share_count : compteur de partages externes d'une publication
-- (WhatsApp / Facebook / X / feuille système), distinct de share_count qui
-- compte les repartages (reposts) internes.
--
-- Incrémenté par l'app via le RPC atomique increment_post_external_share
-- lorsqu'un partage externe aboutit. Stockage seul pour l'instant (non
-- affiché dans l'UI).
--
-- Idempotent : sûr à rejouer (ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE).
-- ============================================================================

ALTER TABLE posts ADD COLUMN IF NOT EXISTS external_share_count INTEGER NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION increment_post_external_share(p_post_id UUID)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE posts SET external_share_count = GREATEST(external_share_count + 1, 0) WHERE id = p_post_id;
$$;

GRANT EXECUTE ON FUNCTION increment_post_external_share(UUID) TO authenticated;

-- Refresh PostgREST schema cache so the new column/RPC are visible immediately.
NOTIFY pgrst, 'reload schema';
