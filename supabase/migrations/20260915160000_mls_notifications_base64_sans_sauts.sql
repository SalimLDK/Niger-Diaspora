-- `encode(bytea, 'base64')` coupe sa sortie tous les 76 caractères.
--
-- Trouvé par le banc de la phase 3 le 2026-09-15, quelques minutes après
-- l'application de `20260915140000` : le ciphertext transporté dans le push
-- arrivait avec des sauts de ligne, et `base64Decode` de Dart les refuse
-- (« FormatException: Invalid character »). L'aperçu de notification aurait
-- donc échoué **à chaque message**, silencieusement — la bannière serait
-- retombée sur « Nouveau message » sans que rien n'explique pourquoi.
--
-- Deux raisons de corriger côté serveur plutôt que côté client seul :
-- un client n'a pas à connaître les habitudes de mise en forme de Postgres,
-- et chaque saut de ligne coûte un octet dans un payload FCM plafonné à
-- 4 Ko. Le client est rendu tolérant en plus, pas à la place.

CREATE OR REPLACE FUNCTION public.mls_notify_recipients()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_conv           RECORD;
  v_sender_name    TEXT;
  v_sender_photo   TEXT;
  v_participant_id TEXT;
  v_conv_type      TEXT;
  v_conv_title     TEXT;
  v_conv_photo     TEXT;
  v_title          TEXT;
  v_body           TEXT;
  v_muted_by       JSONB;
  v_data           JSONB;
BEGIN
  IF NEW.kind <> 'content' THEN
    RETURN NEW;
  END IF;

  SELECT c.id, c.type, c.participant_ids, c.group_id,
         COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = NEW.conversation_id;

  IF NOT FOUND OR v_conv.participant_ids IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT (NEW.sender_id = ANY (v_conv.participant_ids)) THEN
    RETURN NEW;
  END IF;

  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_muted_by   := COALESCE(v_conv.data->'mutedBy', '{}'::jsonb);
  v_conv_title := COALESCE(NULLIF(v_conv.data->>'name', ''),
                           NULLIF(v_conv.data->>'title', ''), 'Groupe');
  v_conv_photo := COALESCE(NULLIF(v_conv.data->>'imageUrl', ''),
                           NULLIF(v_conv.data->>'photoUrl', ''), '');

  v_sender_name := COALESCE(
    (SELECT display_name FROM users WHERE id = NEW.sender_id),
    'Un utilisateur'
  );
  v_sender_photo := COALESCE(
    (SELECT avatar_url FROM users WHERE id = NEW.sender_id),
    ''
  );

  v_body := CASE NEW.content_type
    WHEN 'media'    THEN 'Pièce jointe'
    WHEN 'voice'    THEN 'Note vocale'
    WHEN 'location' THEN 'Position'
    WHEN 'poll'     THEN 'Sondage'
    WHEN 'sticker'  THEN 'Sticker'
    ELSE 'Nouveau message'
  END;

  IF v_conv_type = 'group' THEN
    v_title := v_conv_title;
    v_body  := v_sender_name || ' : ' || v_body;
  ELSE
    v_title := v_sender_name;
  END IF;

  v_data := jsonb_build_object(
    'type',                 'message',
    'protocol',             'mls',
    'targetId',             NEW.conversation_id,
    'target_id',            NEW.conversation_id,
    'conversationId',       NEW.conversation_id,
    'messageId',            NEW.id::text,
    'senderId',             NEW.sender_id,
    'senderName',           v_sender_name,
    'senderPhotoUrl',       v_sender_photo,
    'messageType',          NEW.content_type,
    'mlsEpoch',             NEW.epoch::text,
    'mlsSenderDeviceId',    NEW.sender_device_id::text,
    'mlsKind',              NEW.kind,
    'conversationType',     v_conv_type,
    'conversationTitle',    CASE WHEN v_conv_type = 'group' THEN v_conv_title
                                 ELSE v_sender_name END,
    'conversationPhotoUrl', CASE WHEN v_conv_type = 'group' THEN v_conv_photo
                                 ELSE v_sender_photo END,
    'groupId',              COALESCE(v_conv.group_id, ''),
    'isE2EE',               'true',
    'actor_id',             NEW.sender_id
  );

  IF octet_length(NEW.ciphertext) <= 2500 THEN
    v_data := v_data || jsonb_build_object(
      -- Le `replace` est tout l'objet de cette migration.
      'mlsCiphertext', replace(encode(NEW.ciphertext, 'base64'), E'\n', '')
    );
  END IF;

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    IF v_participant_id IS NULL
       OR v_participant_id = ''
       OR v_participant_id = NEW.sender_id THEN
      CONTINUE;
    END IF;

    IF public.is_conversation_muted_for(v_muted_by, v_participant_id) THEN
      CONTINUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_participant_id) THEN
      CONTINUE;
    END IF;

    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (v_participant_id, 'message', v_title, v_body, v_data, FALSE);
  END LOOP;

  RETURN NEW;
END;
$function$;
