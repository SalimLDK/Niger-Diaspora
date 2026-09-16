-- Trois cas de messagerie que les notifications ne couvraient pas.
--
-- Trouvés le 2026-09-16 en comparant les deux déclencheurs de production ligne
-- à ligne, puis en recoupant avec les données réelles. Aucun des trois ne
-- produit d'erreur : c'est ce qui les avait gardés en place.
--
-- 1. TROIS TYPES DE MESSAGE QUE L'APERÇU NE CONNAÎT PAS
--    `message_preview_for_notification` traite `audio`, `image`, `video`,
--    `file`, `call`, `location`, `poll`. L'application, elle, écrit
--    `voiceNote`, `audioFile` et `sticker` — et jamais `audio`, dont la
--    branche n'est donc atteinte par personne. Les trois tombaient dans le
--    `ELSE`.
--
--    Vu en production : les DEUX seules notifications de note vocale disent
--    « 🔒 Nouveau message ». Et dans une conversation en clair, le `ELSE`
--    rend `data->>'content'` — soit, pour un sticker, son URL, et pour un
--    contact, sa fiche. L'étiquette n'est donc pas qu'un confort d'affichage.
--
--    La table côté client (`_formatMessagePreview`) connaissait déjà les trois
--    noms : c'est la table serveur qui était en retard.
--
-- 2. UNE RÉACTION DANS UNE CONVERSATION CHIFFRÉE NE NOTIFIAIT PERSONNE
--    `mls_notify_recipients` sort immédiatement sur `kind <> 'content'`, et
--    `mls_message_reactions` n'avait aucun déclencheur. Le même geste dans une
--    conversation en clair crée une notification `messageReaction`
--    (`set_message_reaction`). L'asymétrie est invisible : rien n'échoue, et
--    la réaction s'affiche bien sous la bulle chez celui qui l'a posée.
--
--    ⚠️ **Le corps ne porte PAS l'emoji, contrairement au chemin en clair.**
--    L'emoji est déjà en clair dans `mls_message_reactions` — le serveur le
--    connaît. Mais le mettre dans le push le donnerait en plus à FCM, donc à
--    Google, sur une conversation dont tout l'intérêt est qu'elle soit
--    illisible en transit. « A réagi à votre message » suffit à faire ouvrir
--    l'application, qui montre laquelle. Choix délibéré, à rediscuter si
--    l'écart avec le chemin en clair gêne.
--
-- 3. UN MESSAGE EN CLAIR NE NOTIFIE PAS LES MENTIONNÉS D'UNE CONVERSATION
--    MUETTE — traité dans la migration suivante (`20260916130000`), qui touche
--    un autre déclencheur.


-- ---------------------------------------------------------------------------
-- 1a. L'aperçu legacy apprend les noms que l'application écrit vraiment.
--     Corps recopié depuis la production, patché aux deux `CASE` seulement.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.message_preview_for_notification(p_type text, p_data jsonb, p_conversation_id text DEFAULT NULL::text)
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
      -- Les trois noms que l'application écrit réellement. `audio` ci-dessus
      -- n'est écrit par personne : c'est `voiceNote` que produit le micro, et
      -- `audioFile` un fichier son joint. Sans eux, une note vocale tombait
      -- dans le `ELSE` et s'annonçait « 🔒 Nouveau message » — vu en
      -- production sur les deux seules notes vocales notifiées.
      WHEN 'voiceNote' THEN '🎙️ Message vocal'
      WHEN 'audioFile' THEN '🎵 Audio'
      WHEN 'sticker'  THEN '🎨 Sticker'
      WHEN 'contact'  THEN '👤 Contact'
      WHEN 'file'     THEN '📄 Document'
      WHEN 'document' THEN '📄 Document'
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
    WHEN 'voiceNote' THEN '🎙️ Message vocal'
    WHEN 'audioFile' THEN '🎵 ' || COALESCE(NULLIF(p_data->>'fileName', ''), 'Audio')
    -- Sans ces deux-là, le `ELSE` rendait `content` : l'URL du sticker, ou la
    -- fiche du contact, dans le corps de la notification.
    WHEN 'sticker'  THEN '🎨 Sticker'
    WHEN 'contact'  THEN '👤 Contact'
    WHEN 'file'     THEN '📄 ' || COALESCE(NULLIF(p_data->>'fileName', ''), 'Document')
    WHEN 'document' THEN '📄 ' || COALESCE(NULLIF(p_data->>'fileName', ''), 'Document')
    WHEN 'location' THEN '📍 Position partagée'
    WHEN 'poll'     THEN '📊 Sondage'
    WHEN 'call'     THEN '📞 Appel'
    ELSE COALESCE(NULLIF(p_data->>'content', ''), 'Nouveau message')
  END;
END;
$function$
;


-- ---------------------------------------------------------------------------
-- 1b. Le repli MLS apprend `call` et `contact`.
--     Corps recopié depuis `20260915160000`, patché au seul `CASE`.
-- ---------------------------------------------------------------------------

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


-- ---------------------------------------------------------------------------
-- 2. Les réactions des conversations chiffrées notifient l'auteur du message.
--
-- Pendant de `set_message_reaction` pour le transport MLS. Mêmes gardes que
-- lui : jamais soi-même, jamais une conversation muette, jamais un
-- destinataire sans ligne `users` — et le même dédoublonnage, qui retire la
-- notification non lue précédente du même acteur sur le même message avant
-- d'en poser une neuve.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mls_notifier_reaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_msg        RECORD;
  v_conv       RECORD;
  v_acteur     TEXT;
  v_message_id UUID;
  v_nom        TEXT;
  v_photo      TEXT;
  v_conv_type  TEXT;
  v_conv_titre TEXT;
  v_titre      TEXT;
  v_corps      TEXT;
BEGIN
  v_acteur     := COALESCE(NEW.user_id, OLD.user_id);
  v_message_id := COALESCE(NEW.message_id, OLD.message_id);

  SELECT m.sender_id, m.conversation_id
    INTO v_msg
    FROM mls_messages m
   WHERE m.id = v_message_id;
  IF NOT FOUND OR v_msg.sender_id IS NULL OR v_msg.sender_id = '' THEN
    RETURN NULL;
  END IF;

  -- Le dédoublonnage vaut aussi pour le retrait : une réaction annulée ne doit
  -- pas laisser sa notification derrière elle.
  DELETE FROM notifications n
   WHERE n.user_id = v_msg.sender_id
     AND n.type = 'messageReaction'
     AND NOT n.is_read
     AND n.data->>'messageId' = v_message_id::text
     AND n.data->>'actor_id'  = v_acteur;

  IF TG_OP = 'DELETE' THEN
    RETURN NULL;
  END IF;

  -- Réagir à son propre message ne notifie personne.
  IF v_msg.sender_id = v_acteur THEN
    RETURN NULL;
  END IF;

  SELECT c.type, COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = v_msg.conversation_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF public.is_conversation_muted_for(
       COALESCE(v_conv.data->'mutedBy', '{}'::jsonb), v_msg.sender_id) THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_msg.sender_id) THEN
    RETURN NULL;
  END IF;

  SELECT u.display_name, u.avatar_url INTO v_nom, v_photo
    FROM users u WHERE u.id = v_acteur;
  v_nom   := COALESCE(NULLIF(v_nom, ''), 'Un utilisateur');
  v_photo := COALESCE(v_photo, '');

  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_conv_titre := COALESCE(NULLIF(v_conv.data->>'name', ''),
                           NULLIF(v_conv.data->>'title', ''), 'Groupe');

  -- Pas d'emoji dans le titre ni dans le corps : voir l'en-tête du fichier.
  IF v_conv_type = 'group' THEN
    v_titre := v_conv_titre;
    v_corps := v_nom || ' a réagi à votre message';
  ELSE
    v_titre := v_nom;
    v_corps := 'A réagi à votre message';
  END IF;

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    v_msg.sender_id,
    'messageReaction',
    v_titre,
    v_corps,
    jsonb_build_object(
      'type',             'messageReaction',
      'targetId',         v_msg.conversation_id,
      'target_id',        v_msg.conversation_id,
      'conversationId',   v_msg.conversation_id,
      'messageId',        v_message_id::text,
      'senderId',         v_acteur,
      'senderName',       v_nom,
      'senderPhotoUrl',   v_photo,
      'conversationType', v_conv_type,
      'actor_id',         v_acteur
      -- Volontairement pas d'`emoji` : la charge `data` part telle quelle dans
      -- le push (`send-push` recopie chaque clé), donc l'y mettre reviendrait
      -- à le donner à FCM par une autre porte.
    ),
    FALSE
  );

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- Notifier est accessoire : ça ne doit jamais faire échouer la réaction.
  RAISE WARNING 'mls_notifier_reaction: %', SQLERRM;
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.mls_notifier_reaction() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS mls_notifier_reaction_trg ON public.mls_message_reactions;
CREATE TRIGGER mls_notifier_reaction_trg
  AFTER INSERT OR UPDATE OR DELETE ON public.mls_message_reactions
  FOR EACH ROW EXECUTE FUNCTION public.mls_notifier_reaction();

COMMENT ON FUNCTION public.mls_notifier_reaction() IS
  'Notifie l''auteur d''un message MLS qu''on y a réagi. Sans l''emoji : il est en clair côté serveur, mais le push le donnerait aussi à FCM.';
