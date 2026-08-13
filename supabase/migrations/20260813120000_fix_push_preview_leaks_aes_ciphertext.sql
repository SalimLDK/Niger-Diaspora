-- =============================================================================
-- Corrige une fuite de texte chiffré dans les previews de notification push.
--
-- Constat : `message_preview_for_notification` (20260720120000, revue dans
-- 20260805230000) ne masque le contenu que si `encryptionLevel = 'e2ee'` ou si
-- `content` commence par le préfixe legacy `gcm:`. Mais le repli AES réellement
-- utilisé aujourd'hui (MessageCryptoService.encrypt1to1/encryptGroup côté
-- client, quand aucune session Signal n'est établie) écrit
-- `encryptionLevel: 'aes'` et un `content` au format `iv:base64ciphertext`
-- (EncryptionService.encryptText, lib/core/services/encryption_service.dart)
-- — qui ne matche PAS `gcm:%`.
--
-- Résultat : ces messages tombaient dans la branche ELSE et exposaient le
-- ciphertext brut ("<iv_base64>:<contenu_base64>") comme corps de la
-- notification push — visible en clair dans le tiroir de notifications du
-- destinataire, alors que le contenu réel n'a jamais quitté l'appareil
-- expéditeur en clair.
--
-- Correctif : toute valeur non vide de `encryptionLevel` ('aes' OU 'e2ee')
-- déclenche désormais le preview générique par type, comme c'était déjà le
-- cas pour 'e2ee' seul. Le préfixe `gcm:%` reste vérifié pour les messages
-- legacy sans `encryptionLevel`.
--
-- Idempotent : CREATE OR REPLACE, signature inchangée.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.message_preview_for_notification(
  p_type TEXT,
  p_data JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_is_encrypted BOOLEAN;
BEGIN
  v_is_encrypted :=
       COALESCE(p_data->>'encryptionLevel', '') IN ('e2ee', 'aes')
    OR p_data ? 'e2eePayloads'
    OR p_data ? 'e2eePayload'
    OR p_data ? 'e2eeVersion'
    OR p_data ? 'senderKeyPayload'
    OR COALESCE(p_data->>'content', '') LIKE 'gcm:%';

  -- E2EE, AES (repli), ou contenu legacy `gcm:…` : jamais de ciphertext ni de
  -- plaintext côté serveur, uniquement un libellé générique par type.
  IF v_is_encrypted THEN
    RETURN CASE COALESCE(p_type, 'text')
      WHEN 'image'    THEN '📸 Photo'
      WHEN 'video'    THEN '🎥 Vidéo'
      WHEN 'audio'    THEN '🎙️ Message vocal'
      WHEN 'file'     THEN '📄 Document'
      WHEN 'call'     THEN '📞 Appel'
      WHEN 'location' THEN '📍 Position partagée'
      ELSE '🔒 Nouveau message'
    END;
  END IF;

  RETURN CASE COALESCE(p_type, 'text')
    WHEN 'image'    THEN '📸 Photo'
    WHEN 'video'    THEN '🎥 Vidéo'
    WHEN 'audio'    THEN '🎙️ Message vocal'
    WHEN 'file'     THEN '📄 ' || COALESCE(NULLIF(p_data->>'fileName', ''), 'Document')
    WHEN 'location' THEN '📍 Position partagée'
    WHEN 'call'     THEN '📞 Appel'
    ELSE COALESCE(NULLIF(p_data->>'content', ''), 'Nouveau message')
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.message_preview_for_notification(TEXT, JSONB) FROM PUBLIC;
