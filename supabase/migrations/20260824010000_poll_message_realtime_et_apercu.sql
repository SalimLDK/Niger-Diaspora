-- =============================================================================
-- Sondage publie dans une conversation : ce qu'il faut cote base
--
-- 1. `PollCard` lit le sondage via `pollStreamProvider`, donc via
--    `.stream()`. Ni `post_polls` ni `post_poll_options` n'etant dans la
--    publication `supabase_realtime`, ce stream ne fait que son chargement
--    initial : les compteurs ne bougeraient jamais tant que l'ecran reste
--    ouvert, et un vote d'un autre membre resterait invisible.
--    `REPLICA IDENTITY FULL` en plus : sans elle un DELETE ne transporte que
--    la cle primaire et ne passe pas le filtre serveur `poll_id` du stream
--    des options.
--
-- 2. `message_preview_for_notification` ne connait pas le type `poll` : une
--    bulle de sondage portant `encryptionLevel = 'aes'` (comme la position et
--    les stickers) tombait sur le repli « Nouveau message ». On lui donne son
--    libelle, generique comme celui de la position — la question du sondage ne
--    part pas dans la notification.
-- =============================================================================

-- 1. Realtime -----------------------------------------------------------------
DO $mig$
BEGIN
  IF to_regclass('public.post_polls') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.post_polls REPLICA IDENTITY FULL';
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'post_polls'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.post_polls';
    END IF;
  END IF;

  IF to_regclass('public.post_poll_options') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.post_poll_options REPLICA IDENTITY FULL';
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'post_poll_options'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.post_poll_options';
    END IF;
  END IF;
END $mig$;

-- 2. Apercu de notification ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.message_preview_for_notification(
  p_type TEXT,
  p_data JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
AS $fn$
DECLARE
  v_encryption_level TEXT;
  v_is_e2ee          BOOLEAN;
  v_decrypted        TEXT;
BEGIN
  v_encryption_level := COALESCE(p_data->>'encryptionLevel', '');
  v_is_e2ee :=
       v_encryption_level = 'e2ee'
    OR p_data ? 'e2eePayloads'
    OR p_data ? 'e2eePayload'
    OR p_data ? 'e2eeVersion'
    OR p_data ? 'senderKeyPayload';

  -- Repli AES sur un message texte : déchiffrable côté serveur, vrai aperçu.
  IF v_encryption_level = 'aes' AND COALESCE(p_type, 'text') = 'text' THEN
    v_decrypted := public.decrypt_aes_fallback(p_data->>'content');
    IF v_decrypted IS NOT NULL AND v_decrypted <> '' THEN
      RETURN CASE
        WHEN length(v_decrypted) > 80 THEN left(v_decrypted, 80) || '…'
        ELSE v_decrypted
      END;
    END IF;
    -- Échec de déchiffrement (mauvaise clé, format inattendu) : jamais le
    -- ciphertext brut, repli générique.
    RETURN '🔒 Nouveau message';
  END IF;

  -- E2EE, repli AES non-texte (média), ou contenu legacy `gcm:…` : jamais de
  -- contenu côté serveur — l'E2EE ne PEUT pas être déchiffré ici par
  -- construction, et un média chiffré n'a pas de légende exploitable.
  IF v_is_e2ee
     OR v_encryption_level = 'aes'
     OR COALESCE(p_data->>'content', '') LIKE 'gcm:%' THEN
    RETURN CASE COALESCE(p_type, 'text')
      WHEN 'image'    THEN '📸 Photo'
      WHEN 'video'    THEN '🎥 Vidéo'
      WHEN 'audio'    THEN '🎙️ Message vocal'
      WHEN 'file'     THEN '📄 Document'
      WHEN 'call'     THEN '📞 Appel'
      WHEN 'location' THEN '📍 Position partagée'
      WHEN 'poll'     THEN '📊 Sondage'
      ELSE '🔒 Nouveau message'
    END;
  END IF;

  -- Ni E2EE ni AES : contenu déjà en clair (legacy pré-chiffrement).
  RETURN CASE COALESCE(p_type, 'text')
    WHEN 'image'    THEN '📸 Photo'
    WHEN 'video'    THEN '🎥 Vidéo'
    WHEN 'audio'    THEN '🎙️ Message vocal'
    WHEN 'file'     THEN '📄 ' || COALESCE(NULLIF(p_data->>'fileName', ''), 'Document')
    WHEN 'location' THEN '📍 Position partagée'
    WHEN 'poll'     THEN '📊 Sondage'
    WHEN 'call'     THEN '📞 Appel'
    ELSE COALESCE(NULLIF(p_data->>'content', ''), 'Nouveau message')
  END;
END;
$fn$;
