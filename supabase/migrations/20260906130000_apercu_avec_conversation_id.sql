-- =============================================================================
-- L'identifiant de conversation descend jusqu'au dechiffrement (etape 5b)
--
-- Depuis l'etape 4b, le client chiffre le repli AES avec une cle derivee de la
-- conversation, et produit le format « v<n>:<iv>:<ct> ». Pour reconstruire la
-- meme cle, Postgres a besoin de l'identifiant de conversation -- que
-- `decrypt_aes_fallback` accepte depuis l'etape 5a, mais que personne ne lui
-- passait encore.
--
-- Sans cette migration, tout nouveau message afficherait « Nouveau message »
-- en notification au lieu de son texte. Pas une erreur, pas un plantage : une
-- REGRESSION SILENCIEUSE de l'apercu, exactement le genre de defaut que ce
-- chantier a passe sa journee a corriger.
--
-- Les deux fonctions sont reprises de leur definition REELLEMENT DEPLOYEE
-- (`pg_get_functiondef`), pas du depot : celui-ci a deja ete en retard sur la
-- production, et recopier une version obsolete annulerait des correctifs
-- posterieurs sans que rien ne le signale. Seuls l'en-tete et la ligne d'appel
-- ont ete modifies.
--
-- Le DROP prealable est indispensable : `CREATE OR REPLACE` ne remplace pas une
-- fonction dont la liste d'arguments differe. Les deux coexisteraient et
-- l'appel a deux arguments deviendrait ambigu (42725), ce qui casserait les
-- notifications de tout le monde. La migration etant transactionnelle, le
-- trigger n'est jamais expose a l'intervalle ou la fonction manque.
-- =============================================================================

DROP FUNCTION IF EXISTS public.message_preview_for_notification(TEXT, JSONB);
DROP FUNCTION IF EXISTS public.message_preview_for_notification(TEXT, JSONB, TEXT);

CREATE OR REPLACE FUNCTION public.message_preview_for_notification(p_type text, p_data jsonb, p_conversation_id text DEFAULT NULL)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
    v_decrypted := public.decrypt_aes_fallback(p_data->>'content', p_conversation_id);
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
$function$;

REVOKE ALL ON FUNCTION public.message_preview_for_notification(TEXT, JSONB, TEXT)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.message_preview_for_notification(TEXT, JSONB, TEXT) IS
  'Apercu de notification. `p_conversation_id` est requis pour dechiffrer un '
  'contenu au format « v<n>:iv:ct » (cle derivee) ; sans lui, le repli est '
  'l''apercu generique -- jamais le ciphertext.';

CREATE OR REPLACE FUNCTION public.notify_recipients_on_message_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  v_preview := public.message_preview_for_notification(NEW.type, NEW.data, NEW.conversation_id);

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
$function$;
