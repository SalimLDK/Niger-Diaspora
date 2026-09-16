-- Une édition corrige la notification déjà posée.
--
-- CE QUI SE PASSAIT
-- Aucune notification n'est émise pour une édition — et c'est voulu, on ne
-- réveille pas quelqu'un parce qu'une faute a été corrigée. Mais la bannière
-- déjà affichée gardait le texte d'avant, et surtout la pile d'empilement le
-- gardait **24 h** : le message suivant de la conversation réaffichait la
-- ligne périmée au-dessus de la neuve. Le texte faux ne restait pas, il
-- REVENAIT, et rien ne permettait de s'en apercevoir.
--
-- CE QU'ON ENVOIE, ET CE QU'ON N'ENVOIE PAS
-- Un type `messageEdited`, **silencieux** : `send-push` le traite en data-only
-- comme un message, donc le système n'affiche rien de lui-même ; c'est
-- l'appareil qui corrige sa bannière en place et ne la fait pas re-sonner.
-- Il est aussi écarté de l'écran Notifications côté client.
--
-- LE FILTRE QUI ÉVITE D'INONDER
-- On ne pousse QUE vers les destinataires qui ont encore une notification
-- `message` NON LUE pour cette conversation. Autrement dit : seulement quand il
-- y a une bannière à corriger. Qui a déjà lu ne reçoit rien — une édition ne
-- doit jamais faire réapparaître une conversation.
--
-- POURQUOI DEUX DÉCLENCHEURS
-- En clair, le serveur lit le nouveau texte et recompose l'aperçu lui-même.
-- En chiffré il ne peut pas : l'édition est un message de CONTRÔLE dont la
-- charge (`{targetId, content}`) est chiffrée. On transporte donc ce
-- ciphertext-là, et c'est l'appareil qui en tire le texte — le même mécanisme
-- que l'aperçu, avec la même copie jetable.
--
-- Et le serveur ne sait même pas qu'un contrôle est une édition : `kind` vaut
-- `control` pour une édition, une réaction et une suppression indistinctement.
-- On pousse donc tout contrôle qui a une bannière à corriger, et c'est
-- l'appareil qui trie après déchiffrement. Une réaction y est ignorée : elle a
-- sa propre notification.

-- ---------------------------------------------------------------------------
-- Qui a une bannière en attente pour cette conversation ?
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.a_une_banniere_en_attente(
  p_user_id         TEXT,
  p_conversation_id TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM notifications n
     WHERE n.user_id = p_user_id
       AND n.type = 'message'
       AND NOT n.is_read
       AND n.data->>'conversationId' = p_conversation_id
  );
$$;

REVOKE ALL ON FUNCTION private.a_une_banniere_en_attente(TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Transport en clair : le serveur lit le nouveau texte.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifier_edition_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_conv           RECORD;
  v_participant_id TEXT;
  v_muted_by       JSONB;
  v_apercu         TEXT;
  v_conv_type      TEXT;
  v_conv_titre     TEXT;
  v_nom            TEXT;
BEGIN
  -- Rien d'autre qu'une édition ne nous intéresse.
  IF COALESCE(NEW.data->>'editedAt', '') = COALESCE(OLD.data->>'editedAt', '')
  THEN
    RETURN NULL;
  END IF;

  SELECT c.id, c.type, c.participant_ids, COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = NEW.conversation_id;
  IF NOT FOUND OR v_conv.participant_ids IS NULL THEN
    RETURN NULL;
  END IF;

  v_muted_by   := COALESCE(v_conv.data->'mutedBy', '{}'::jsonb);
  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_conv_titre := COALESCE(NULLIF(v_conv.data->>'name', ''),
                           NULLIF(v_conv.data->>'title', ''), 'Groupe');
  v_nom := COALESCE((SELECT display_name FROM users WHERE id = NEW.sender_id),
                    'Un utilisateur');
  v_apercu := public.message_preview_for_notification(
    NEW.type, NEW.data, NEW.conversation_id);

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    CONTINUE WHEN v_participant_id IS NULL
               OR v_participant_id = ''
               OR v_participant_id = NEW.sender_id;
    CONTINUE WHEN public.is_conversation_muted_for(v_muted_by, v_participant_id);
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM users WHERE id = v_participant_id);
    -- Le filtre qui évite d'inonder : seulement s'il y a une bannière.
    CONTINUE WHEN NOT private.a_une_banniere_en_attente(
                    v_participant_id, NEW.conversation_id);

    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (
      v_participant_id,
      'messageEdited',
      '',
      v_apercu,
      jsonb_build_object(
        'type',           'messageEdited',
        'targetId',       NEW.conversation_id,
        'target_id',      NEW.conversation_id,
        'conversationId', NEW.conversation_id,
        -- Le message CORRIGÉ, celui dont la ligne doit changer dans la pile.
        'editedMessageId', NEW.id,
        'messageId',      NEW.id,
        'senderId',       NEW.sender_id,
        'senderName',     v_nom,
        -- De quoi reposter la bannière sans rien deviner : l'appareil ne
        -- garde pas le titre de la conversation d'un push à l'autre.
        'conversationType',  v_conv_type,
        'conversationTitle', CASE WHEN v_conv_type = 'group' THEN v_conv_titre
                                  ELSE v_nom END,
        'sentAt',         (extract(epoch from now()) * 1000)::bigint::text,
        'actor_id',       NEW.sender_id
      ),
      -- Jamais non lue : elle n'a rien à compter, elle corrige.
      TRUE
    );
  END LOOP;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- Corriger une bannière ne doit jamais faire échouer une édition.
  RAISE WARNING 'notifier_edition_message: %', SQLERRM;
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.notifier_edition_message() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notifier_edition_message ON public.messages;
CREATE TRIGGER trg_notifier_edition_message
  AFTER UPDATE OF data ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notifier_edition_message();

-- ---------------------------------------------------------------------------
-- Transport chiffré : le serveur transporte, l'appareil lit.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mls_notifier_controle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_conv           RECORD;
  v_participant_id TEXT;
  v_muted_by       JSONB;
  v_data           JSONB;
  v_conv_type      TEXT;
  v_conv_titre     TEXT;
  v_nom            TEXT;
BEGIN
  IF NEW.kind <> 'control' THEN
    RETURN NULL;
  END IF;

  -- Au-delà, le ciphertext ne tient pas dans le plafond FCM : l'appareil ne
  -- pourra pas lire la correction, inutile de le réveiller pour rien.
  IF octet_length(NEW.ciphertext) > 2500 THEN
    RETURN NULL;
  END IF;

  SELECT c.id, c.type, c.participant_ids, COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = NEW.conversation_id;
  IF NOT FOUND OR v_conv.participant_ids IS NULL THEN
    RETURN NULL;
  END IF;

  v_muted_by   := COALESCE(v_conv.data->'mutedBy', '{}'::jsonb);
  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_conv_titre := COALESCE(NULLIF(v_conv.data->>'name', ''),
                           NULLIF(v_conv.data->>'title', ''), 'Groupe');
  v_nom := COALESCE((SELECT display_name FROM users WHERE id = NEW.sender_id),
                    'Un utilisateur');

  v_data := jsonb_build_object(
    'type',              'messageEdited',
    'protocol',          'mls',
    'targetId',          NEW.conversation_id,
    'target_id',         NEW.conversation_id,
    'conversationId',    NEW.conversation_id,
    -- L'identifiant du CONTRÔLE, pas du message corrigé : c'est lui qui entre
    -- dans l'AAD, et le message corrigé est nommé dans la charge chiffrée.
    'messageId',         NEW.id::text,
    'senderId',          NEW.sender_id,
    'senderName',        v_nom,
    'conversationType',  v_conv_type,
    'conversationTitle', CASE WHEN v_conv_type = 'group' THEN v_conv_titre
                              ELSE v_nom END,
    'mlsEpoch',          NEW.epoch::text,
    'mlsSenderDeviceId', NEW.sender_device_id::text,
    'mlsKind',           NEW.kind,
    'mlsCiphertext',     encode(NEW.ciphertext, 'base64'),
    'sentAt',            (extract(epoch from NEW.created_at) * 1000)::bigint::text,
    'isE2EE',            'true',
    'actor_id',          NEW.sender_id
  );

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    CONTINUE WHEN v_participant_id IS NULL
               OR v_participant_id = ''
               OR v_participant_id = NEW.sender_id;
    CONTINUE WHEN public.is_conversation_muted_for(v_muted_by, v_participant_id);
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM users WHERE id = v_participant_id);
    CONTINUE WHEN NOT private.a_une_banniere_en_attente(
                    v_participant_id, NEW.conversation_id);

    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (v_participant_id, 'messageEdited', '', '', v_data, TRUE);
  END LOOP;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'mls_notifier_controle: %', SQLERRM;
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.mls_notifier_controle() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS mls_notifier_controle_trg ON public.mls_messages;
CREATE TRIGGER mls_notifier_controle_trg
  AFTER INSERT ON public.mls_messages
  FOR EACH ROW EXECUTE FUNCTION public.mls_notifier_controle();

COMMENT ON FUNCTION public.mls_notifier_controle() IS
  'Transporte un message de contrôle MLS vers les appareils qui ont une bannière à corriger. Le serveur ne sait pas ce que le contrôle dit : l''appareil déchiffre et trie.';
