-- =============================================================================
-- Aperçus de notification en clair, quand c'est possible.
--
-- Demande de Salim (2026-08-13), après le correctif qui masquait tout
-- contenu chiffré derrière un libellé générique (« 🔒 Nouveau message »).
-- Deux mécanismes très différents selon le niveau de chiffrement réel :
--
-- 1) REPLI AES (`encryptionLevel = 'aes'`, la majorité des messages
--    aujourd'hui — cf MessageCryptoService.encrypt1to1/encryptGroup, retombe
--    sur AES dès qu'aucune session Signal n'est établie). La clé est
--    **déjà partagée** : elle est codée en dur dans le client
--    (EncryptionService._sharedKeyString, lib/core/services/encryption_service.dart)
--    et documentée comme partagée avec un ancien service Cloud Functions.
--    La stocker aussi côté Postgres n'expose donc rien de nouveau — c'est
--    la même clé, une deuxième copie. `pgcrypto` (déjà activé) permet de
--    déchiffrer côté serveur et d'écrire le vrai texte dans `notifications.body`,
--    qui part ensuite tel quel dans le payload FCM : ça marche premier plan,
--    arrière-plan, app tuée.
--
--    Format vérifié par un aller-retour réel avec le client Dart
--    (`encrypt.AES(key, mode: cbc)`, clé de 32 octets → AES-256, padding
--    PKCS7 par défaut du paquet `encrypt`) : `decrypt_iv(ciphertext, key, iv,
--    'aes-cbc/pad:pkcs')` retombe bien sur le texte clair d'origine.
--
-- 2) E2EE SIGNAL RÉEL (`e2eePayloads` / `senderKeyPayload`) : le serveur ne
--    peut PAS déchiffrer, par construction — seul l'appareil destinataire a
--    la clé privée. Le body serveur reste donc générique. Ce qui change ici :
--    la ligne `notifications.data` transporte désormais le VRAI payload
--    chiffré (au lieu du placeholder littéral `'[E2EE]'` qu'écrit
--    MessageCryptoService dans `content` pour ce cas), pour que l'appareil
--    du destinataire puisse tenter un déchiffrement local et remplacer le
--    texte générique par le vrai contenu — voir le correctif client associé
--    dans NotificationDecryptionService. Ça ne fonctionnera qu'au premier
--    plan (le déchiffrement en arrière-plan nécessiterait de charger tout
--    le magasin de sessions Signal dans un isolate séparé — hors périmètre).
--
--    Garde-fou de taille : FCM limite un message data à 4096 octets au
--    total, tous champs confondus. `e2eePayloads` peut contenir une entrée
--    par appareil actif du destinataire. Le payload crypto n'est inclus que
--    s'il tient dans 2500 octets — au-delà, il est simplement omis (aucune
--    régression : c'est le comportement actuel, générique).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A. Déchiffrement AES-256-CBC côté serveur, clé partagée.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.decrypt_aes_fallback(p_content TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_iv_b64 TEXT;
  v_ct_b64 TEXT;
  v_plain  TEXT;
BEGIN
  IF p_content IS NULL OR position(':' in p_content) = 0 THEN
    RETURN NULL;
  END IF;

  v_iv_b64 := split_part(p_content, ':', 1);
  v_ct_b64 := split_part(p_content, ':', 2);

  IF v_iv_b64 = '' OR v_ct_b64 = '' THEN
    RETURN NULL;
  END IF;

  BEGIN
    v_plain := convert_from(
      decrypt_iv(
        decode(v_ct_b64, 'base64'),
        -- Même clé que EncryptionService._sharedKeyString côté client —
        -- déjà embarquée dans l'APK, pas un nouveau secret.
        'DiaspoNigerSecureKey2025ForApps!'::bytea,
        decode(v_iv_b64, 'base64'),
        'aes-cbc/pad:pkcs'
      ),
      'UTF8'
    );
  EXCEPTION WHEN OTHERS THEN
    -- Format inattendu, clé différente (message pré-migration), ou données
    -- corrompues : jamais d'erreur qui remonte, jamais de ciphertext exposé.
    RETURN NULL;
  END;

  RETURN v_plain;
END;
$$;

REVOKE ALL ON FUNCTION public.decrypt_aes_fallback(TEXT) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.decrypt_aes_fallback(TEXT) IS
  'Déchiffre le repli AES-256-CBC (clé partagée, embarquée côté client) pour '
  'les aperçus de notification en clair. Jamais exposée en RPC : appelée '
  'uniquement depuis message_preview_for_notification (contexte SECURITY '
  'DEFINER du trigger messages).';

-- -----------------------------------------------------------------------------
-- B. Aperçu : texte réel pour le repli AES, générique pour E2EE/legacy/media.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.message_preview_for_notification(
  p_type TEXT,
  p_data JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
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
    WHEN 'call'     THEN '📞 Appel'
    ELSE COALESCE(NULLIF(p_data->>'content', ''), 'Nouveau message')
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.message_preview_for_notification(TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- C. E2EE : transporter le vrai payload chiffré (pas le placeholder '[E2EE]')
--    pour permettre un déchiffrement côté client, au premier plan.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_recipients_on_message_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv              RECORD;
  v_sender_name       TEXT;
  v_sender_photo      TEXT;
  v_participant_id    TEXT;
  v_preview           TEXT;
  v_title             TEXT;
  v_body              TEXT;
  v_conv_type         TEXT;
  v_conv_title        TEXT;
  v_conv_photo        TEXT;
  v_group_id          TEXT;
  v_is_e2ee           BOOLEAN;
  v_muted_by          JSONB;
  v_data              JSONB;
  v_crypto            JSONB;
BEGIN
  -- Ignore system / non-user messages
  IF NEW.sender_id IS NULL
     OR NEW.sender_id = ''
     OR NEW.sender_id = 'system'
     OR COALESCE(NEW.type, '') = 'system' THEN
    RETURN NEW;
  END IF;

  SELECT
    c.id,
    c.type,
    c.participant_ids,
    c.group_id,
    COALESCE(c.data, '{}'::jsonb) AS data
  INTO v_conv
  FROM conversations c
  WHERE c.id = NEW.conversation_id;

  IF NOT FOUND OR v_conv.participant_ids IS NULL THEN
    RETURN NEW;
  END IF;

  -- Expéditeur doit être participant (anti-spoof si insert bypassait RLS)
  IF NOT (NEW.sender_id = ANY (v_conv.participant_ids)) THEN
    RETURN NEW;
  END IF;

  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_group_id   := COALESCE(v_conv.group_id, '');
  v_muted_by   := COALESCE(v_conv.data->'mutedBy', '{}'::jsonb);
  v_conv_title := COALESCE(
    NULLIF(v_conv.data->>'name', ''),
    NULLIF(v_conv.data->>'title', ''),
    'Groupe'
  );
  v_conv_photo := COALESCE(
    NULLIF(v_conv.data->>'imageUrl', ''),
    NULLIF(v_conv.data->>'photoUrl', ''),
    ''
  );

  -- Nom / photo : message.data en priorité, sinon users
  v_sender_name := COALESCE(
    NULLIF(NEW.data->>'senderName', ''),
    (SELECT display_name FROM users WHERE id = NEW.sender_id),
    'Un utilisateur'
  );
  v_sender_photo := COALESCE(
    NULLIF(NEW.data->>'senderPhotoUrl', ''),
    (SELECT avatar_url FROM users WHERE id = NEW.sender_id),
    ''
  );

  v_is_e2ee :=
       COALESCE(NEW.data->>'encryptionLevel', '') = 'e2ee'
    OR NEW.data ? 'e2eePayloads'
    OR NEW.data ? 'e2eePayload'
    OR NEW.data ? 'e2eeVersion'
    OR NEW.data ? 'senderKeyPayload';

  v_preview := public.message_preview_for_notification(NEW.type, NEW.data);

  IF v_conv_type = 'group' THEN
    v_title := v_conv_title;
    v_body  := v_sender_name || ': ' || v_preview;
  ELSE
    v_title := v_sender_name;
    v_body  := v_preview;
  END IF;

  v_data := jsonb_build_object(
    'type',                 'message',
    'targetId',             NEW.conversation_id,
    'target_id',            NEW.conversation_id,
    'conversationId',       NEW.conversation_id,
    'messageId',            NEW.id,
    'senderId',             NEW.sender_id,
    'senderName',           v_sender_name,
    'senderPhotoUrl',       v_sender_photo,
    'messageType',          COALESCE(NEW.type, 'text'),
    'conversationType',     v_conv_type,
    'conversationTitle',    CASE
                              WHEN v_conv_type = 'group' THEN v_conv_title
                              ELSE v_sender_name
                            END,
    'conversationPhotoUrl', CASE
                              WHEN v_conv_type = 'group' THEN v_conv_photo
                              ELSE v_sender_photo
                            END,
    'groupId',              v_group_id,
    'isE2EE',               CASE WHEN v_is_e2ee THEN 'true' ELSE 'false' END,
    'actor_id',             NEW.sender_id
  );

  IF v_is_e2ee THEN
    v_crypto := jsonb_strip_nulls(jsonb_build_object(
      'e2eePayloads',    NEW.data->'e2eePayloads',
      'e2eePayload',     NEW.data->'e2eePayload',
      'senderKeyPayload', NEW.data->'senderKeyPayload'
    ));
    -- Garde-fou taille FCM (4096 o. au total) : on n'ajoute le payload que
    -- s'il laisse de la marge aux autres champs. Au-delà, il est omis --
    -- aucune régression, c'est le comportement générique déjà en place.
    IF octet_length(v_crypto::text) <= 2500 THEN
      v_data := v_data || v_crypto;
    END IF;
  END IF;

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    -- Exclure l'expéditeur (au passage : « Mes notes », conversation à un seul
    -- participant, ne produit donc aucune notification)
    IF v_participant_id IS NULL
       OR v_participant_id = ''
       OR v_participant_id = NEW.sender_id THEN
      CONTINUE;
    END IF;

    -- Mute conversation
    IF public.is_conversation_muted_for(v_muted_by, v_participant_id) THEN
      CONTINUE;
    END IF;

    -- Destinataire doit exister
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_participant_id) THEN
      CONTINUE;
    END IF;

    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (
      v_participant_id,
      'message',
      v_title,
      v_body,
      v_data,
      FALSE
    );
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais faire échouer l'INSERT message à cause d'une notif
    RAISE WARNING 'notify_recipients_on_message_insert: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_recipients_on_message_insert() FROM PUBLIC, anon, authenticated;
