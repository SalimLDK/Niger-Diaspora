-- Push des messages : le nom de l'expéditeur vient du serveur, et un
-- expéditeur bloqué ne notifie plus.
--
-- LES DÉFAUTS (audit du 2026-10-03, P2 notifications)
-- 1. `notify_recipients_on_message_insert` prenait le nom et la photo de
--    l'expéditeur dans `messages.data->>'senderName'` / `senderPhotoUrl` EN
--    PRIORITÉ — deux valeurs écrites par le client. Le titre du push (1:1) ou
--    son préfixe (groupe) était donc au choix de l'expéditeur : « Banque
--    BCEAO », « Équipe Diaspo Niger »… sous l'icône de l'app. C'est
--    l'hameçonnage que 20260921100000 a fermé pour `create_user_notification`,
--    resté ouvert sur le chemin des messages.
-- 2. Ni ce déclencheur ni `mls_notify_recipients` ne regardaient
--    `blocked_users` : bloquer quelqu'un n'arrêtait pas ses notifications de
--    message — le levier de harcèlement par excellence. `create_user_
--    notification` le fait depuis 20260921032400 (« bloqué par le
--    destinataire : on ne crée rien, et on ne le dit pas »).
--
-- LE CORRECTIF
-- Les deux fonctions sont reprises de 20260916140000, à trois changements
-- près : nom et photo lus dans `users` seulement (un nom vide retombe sur
-- « Un utilisateur ») ; un destinataire qui a bloqué l'expéditeur est sauté,
-- mention comprise ; rien d'autre ne bouge. Les déclencheurs restent ceux
-- qui existent (`CREATE OR REPLACE` ne touche que le corps).
--
-- Banc : tools/rls_tests/push_expediteur_serveur_et_blocage.sql

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
    NULLIF((SELECT display_name FROM users WHERE id = NEW.sender_id), ''),
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
    WHEN 'call'     THEN 'Appel'
    WHEN 'contact'  THEN 'Contact'
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
    -- L'heure que le SERVEUR a donnée au message, en millisecondes.
    -- Sans elle, l'appareil datait la notification de sa réception : un
    -- message reçu au retour du réseau s'affichait « à l'instant » alors
    -- qu'il datait de deux heures.
    'sentAt',               (extract(epoch from NEW.created_at) * 1000)::bigint::text,
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

    -- Le destinataire a bloqué l'expéditeur : rien —
    -- même règle que `create_user_notification` (20260921032400).
    IF EXISTS (
      SELECT 1 FROM blocked_users
       WHERE blocker_id = v_participant_id AND blocked_id = NEW.sender_id
    ) THEN
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

  -- Nom / photo : de `users`, JAMAIS de `message.data`. `senderName` est
  -- écrit par le client : il passait en priorité, et n'importe quel compte
  -- pouvait signer son push « Banque … » ou « Équipe Diaspo Niger ». Même
  -- règle que `create_user_notification` (20260921100000) et que le chemin
  -- MLS, qui lisait déjà `users`.
  v_sender_name := COALESCE(
    NULLIF((SELECT display_name FROM users WHERE id = NEW.sender_id), ''),
    'Un utilisateur'
  );
  v_sender_photo := COALESCE(
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
    -- L'heure que le SERVEUR a donnée au message, en millisecondes.
    -- Sans elle, l'appareil datait la notification de sa réception : un
    -- message reçu au retour du réseau s'affichait « à l'instant » alors
    -- qu'il datait de deux heures.
    'sentAt',               (extract(epoch from NEW.created_at) * 1000)::bigint::text,
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

    -- Le destinataire a bloqué l'expéditeur : rien, ni message ni mention —
    -- même règle que `create_user_notification` (20260921032400).
    IF EXISTS (
      SELECT 1 FROM blocked_users
       WHERE blocker_id = v_participant_id AND blocked_id = NEW.sender_id
    ) THEN
      CONTINUE;
    END IF;

    -- Conversation muette. C'est ici, et nulle part ailleurs, qu'une MENTION
    -- passe outre : si ce message vous nomme, vous êtes prévenu·e malgré la
    -- sourdine — mais sous un AUTRE type, `messageMention`, pour que la
    -- bannière dise pourquoi elle est là et n'ait pas l'air d'une sourdine qui
    -- fuit. Le type `mentioned` du fil ne convenait pas : son appui ouvre
    -- `/feed/<cible>`, et la cible est ici une conversation.
    --
    -- ⚠️ Transport en clair seulement. Dans une conversation MLS, les mentions
    -- voyagent DANS la charge chiffrée (`MlsPayload.mentions`) : le serveur ne
    -- peut pas savoir qu'il vous nomme, et une conversation chiffrée mise en
    -- sourdine reste donc silencieuse même sur mention. Ce n'est pas un oubli,
    -- c'est la contrainte du chiffrement.
    IF public.is_conversation_muted_for(v_muted_by, v_participant_id) THEN
      IF EXISTS (SELECT 1 FROM users WHERE id = v_participant_id)
         AND EXISTS (
           SELECT 1
             FROM jsonb_array_elements(
                    CASE WHEN jsonb_typeof(NEW.data->'mentionedUsers') = 'array'
                         THEN NEW.data->'mentionedUsers'
                         ELSE '[]'::jsonb END) AS mention
            WHERE COALESCE(mention->>'id', mention->>'userId') = v_participant_id
         )
      THEN
        INSERT INTO notifications (user_id, type, title, body, data, is_read)
        VALUES (
          v_participant_id,
          'messageMention',
          v_title,
          v_sender_name || ' vous a mentionné(e)',
          v_data || jsonb_build_object('type', 'messageMention'),
          FALSE
        );
      END IF;
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
