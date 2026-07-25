-- =============================================================================
-- Trigger : messages INSERT → notifications (1 ligne / destinataire)
--
-- Remplace le flux Firebase RTDB `onMessageCreated` qui créait des notifs
-- Firestore + push FCM. Désormais :
--   1) client insert dans `messages` seulement
--   2) ce trigger (SECURITY DEFINER) crée les lignes `notifications`
--   3) trigger/webhook `notify_push_on_notification` → Edge Function send-push → FCM
--
-- Sécurité : impossible pour un client de spoof le destinataire — seuls les
-- participant_ids de la conversation (hors expéditeur) reçoivent une notif.
-- Les messages système (type/sender_id = 'system') sont ignorés.
-- Conversations mutées (data.mutedBy) : pas de notification.
--
-- Payload `data` aligné sur notification_service.dart / ancien CF :
--   type, conversationId, messageId, senderId, senderName, senderPhotoUrl,
--   targetId, messageType, conversationType, conversationTitle,
--   conversationPhotoUrl, groupId, isE2EE, encryptedPreview (si E2EE)
--
-- Idempotent : CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- À appliquer manuellement (ne pas lancer supabase db push sans approbation).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_conversation_muted_for(
  p_muted_by JSONB,
  p_user_id  TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_val TEXT;
  v_exp TIMESTAMPTZ;
BEGIN
  IF p_muted_by IS NULL OR p_user_id IS NULL OR p_user_id = '' THEN
    RETURN FALSE;
  END IF;

  IF NOT (p_muted_by ? p_user_id) THEN
    RETURN FALSE;
  END IF;

  -- true / "forever" / bool JSON
  IF jsonb_typeof(p_muted_by -> p_user_id) = 'boolean' THEN
    RETURN (p_muted_by ->> p_user_id)::boolean;
  END IF;

  v_val := p_muted_by ->> p_user_id;
  IF v_val IS NULL OR v_val = '' THEN
    RETURN FALSE;
  END IF;
  IF lower(v_val) IN ('true', 'forever') THEN
    RETURN TRUE;
  END IF;

  BEGIN
    v_exp := v_val::timestamptz;
  EXCEPTION WHEN OTHERS THEN
    -- Date invalide → traité comme mute permanent (comportement CF historique)
    RETURN TRUE;
  END;

  RETURN v_exp > NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public.message_preview_for_notification(
  p_type TEXT,
  p_data JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_is_e2ee BOOLEAN;
BEGIN
  v_is_e2ee :=
       COALESCE(p_data->>'encryptionLevel', '') = 'e2ee'
    OR p_data ? 'e2eePayloads'
    OR p_data ? 'e2eePayload'
    OR p_data ? 'e2eeVersion'
    OR p_data ? 'senderKeyPayload';

  -- E2EE ou contenu AES opaque (gcm:…) : jamais de plaintext côté serveur
  IF v_is_e2ee
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
    v_data := v_data || jsonb_build_object(
      'encryptedPreview', COALESCE(NEW.data->>'content', '')
    );
  END IF;

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    -- Exclure l'expéditeur
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

DROP TRIGGER IF EXISTS trg_notify_recipients_on_message_insert ON messages;
CREATE TRIGGER trg_notify_recipients_on_message_insert
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_recipients_on_message_insert();

COMMENT ON FUNCTION public.notify_recipients_on_message_insert() IS
  'Après INSERT messages : crée une ligne notifications par destinataire '
  '(hors sender, hors mute, hors system). Déclenche ensuite send-push via '
  'notify_push_on_notification.';

-- Pas de GRANT EXECUTE aux clients : trigger only (SECURITY DEFINER).
REVOKE ALL ON FUNCTION public.notify_recipients_on_message_insert() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_conversation_muted_for(JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.message_preview_for_notification(TEXT, JSONB) FROM PUBLIC;
