-- Notifications des messages MLS (plan MLS, phase 4).
--
-- CE QUI CHANGE PAR RAPPORT AU LEGACY
-- Aujourd'hui, Postgres DÉCHIFFRE dans `notify_recipients_on_message_insert`
-- et met le vrai texte dans `notifications.body`, qui part tel quel dans le
-- push. C'est ce que MLS supprime : le serveur ne peut plus rien lire.
--
-- Le `body` écrit ici est donc un REPLI générique (« Nouveau message »,
-- « Photo »…). L'aperçu réel est reconstruit **sur l'appareil**, par l'isolate
-- de notification, qui déchiffre le ciphertext transporté dans le push.
--
-- POURQUOI LE CIPHERTEXT VOYAGE DANS LE PUSH
-- L'alternative — réveiller l'app pour qu'elle aille lire `mls_messages` —
-- exigerait une session Supabase dans un isolate frais, c'est-à-dire tout le
-- pont Firebase→Supabase, ses 401 de démarrage et ses reprises. Un ciphertext
-- MLS mesuré fait **185 octets** pour un texte court : il tient dans le
-- plafond FCM de 4 Ko avec de la marge. Au-delà de 2500 octets il est omis,
-- et l'appareil affiche le repli générique — dégradé, jamais cassé. Même
-- garde-fou que le legacy pour les charges Signal.
--
-- CE QUE LE PUSH NE PORTE JAMAIS
-- Aucun clair, aucune clé. Le ciphertext n'est lisible que par un appareil
-- membre du groupe à cet epoch : l'interception du push ne donne rien.

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
  -- Les messages de contrôle (réaction, modification, suppression) ne
  -- notifient personne : ils n'ont pas de contenu à annoncer.
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

  -- Repli générique. L'appareil le remplace par le vrai texte quand il a pu
  -- déchiffrer ; l'utilisateur ne voit celui-ci que si le déchiffrement local
  -- a échoué (message d'un epoch qu'il n'a pas encore, par exemple).
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
    -- Ce drapeau dit à l'isolate de notification quoi faire du reste. Sans
    -- lui, un client à jour traiterait un message MLS comme un message
    -- legacy et afficherait le repli générique sans jamais déchiffrer.
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
      'mlsCiphertext', encode(NEW.ciphertext, 'base64')
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

DROP TRIGGER IF EXISTS mls_notify_recipients_trg ON public.mls_messages;
CREATE TRIGGER mls_notify_recipients_trg
  AFTER INSERT ON public.mls_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.mls_notify_recipients();
