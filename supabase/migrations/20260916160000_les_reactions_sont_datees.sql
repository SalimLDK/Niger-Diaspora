-- Les notifications de réaction n'étaient pas datées.
--
-- Trouvé en vérifiant le banc de bout en bout du 2026-09-16 : les cinq
-- notifications produites portaient bien `sentAt`… sauf celle de réaction, qui
-- rendait `null`. Le client (`heureDuMessage`) retombe alors sur
-- `DateTime.now()`, c'est-à-dire l'heure de LIVRAISON — exactement le défaut
-- corrigé la veille pour les messages, resté sur son voisin.
--
-- Conséquence faible et c'est pourquoi elle avait survécu : une réaction est
-- rarement différée, et `messageReaction` ne s'affiche pas dans l'écran
-- Notifications (`kTypesHorsEcranNotifications`). Mais sa bannière, elle,
-- s'affiche — et elle mentait sur l'heure dès que le push arrivait en retard.
--
-- L'heure retenue est celle de la RÉACTION, pas celle du message auquel elle
-- répond : c'est la réaction qu'on annonce.
--
-- Les deux corps sont recopiés depuis la production et patchés au seul objet
-- `data`.

-- ---------------------------------------------------------------------------
-- Transport chiffré (déclencheur sur `mls_message_reactions`).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mls_notifier_reaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
      -- L'heure de la RÉACTION — c'est elle qu'on annonce, pas le message
      -- auquel elle répond. Sans ça, le client retombait sur l'heure de
      -- livraison, et une réaction reçue au retour du réseau s'affichait
      -- « à l'instant ».
      'sentAt',           (extract(epoch from COALESCE(NEW.created_at, now())) * 1000)::bigint::text,
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

-- ---------------------------------------------------------------------------
-- Transport en clair (RPC `set_message_reaction`).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_message_reaction(p_message_id text, p_emoji text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid          TEXT := public.firebase_uid();
  v_emoji        TEXT := NULLIF(btrim(COALESCE(p_emoji, '')), '');
  v_msg          RECORD;
  v_conv         RECORD;
  v_previous     TEXT;
  v_reactions    JSONB;
  v_actor_name   TEXT;
  v_actor_photo  TEXT;
  v_conv_type    TEXT;
  v_conv_title   TEXT;
  v_title        TEXT;
  v_body         TEXT;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'set_message_reaction: not authenticated'
      USING ERRCODE = '42501';
  END IF;

  -- Un emoji, pas un texte : les séquences les plus longues (familles,
  -- drapeaux de sous-division) tiennent sous 16 points de code.
  IF v_emoji IS NOT NULL AND char_length(v_emoji) > 16 THEN
    RAISE EXCEPTION 'set_message_reaction: invalid emoji'
      USING ERRCODE = '22023';
  END IF;

  SELECT m.id, m.conversation_id, m.sender_id, m.type,
         COALESCE(m.data, '{}'::jsonb) AS data
    INTO v_msg
    FROM messages m
   WHERE m.id = p_message_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'set_message_reaction: message not found'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT c.id, c.type, c.participant_ids, COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = v_msg.conversation_id;

  IF NOT FOUND OR v_conv.participant_ids IS NULL
     OR NOT (v_uid = ANY (v_conv.participant_ids)) THEN
    RAISE EXCEPTION 'set_message_reaction: not a participant'
      USING ERRCODE = '42501';
  END IF;

  v_previous := v_msg.data->'reactions'->>v_uid;

  -- L'expression est évaluée sur la version COURANTE de la ligne au moment de
  -- l'UPDATE : une réaction ou un accusé posé entre-temps est conservé.
  UPDATE messages
     SET data = jsonb_set(
           COALESCE(data, '{}'::jsonb),
           '{reactions}',
           CASE
             WHEN v_emoji IS NULL THEN
               (CASE WHEN jsonb_typeof(data->'reactions') = 'object'
                     THEN data->'reactions' ELSE '{}'::jsonb END) - v_uid
             ELSE
               (CASE WHEN jsonb_typeof(data->'reactions') = 'object'
                     THEN data->'reactions' ELSE '{}'::jsonb END)
               || jsonb_build_object(v_uid, v_emoji)
           END
         )
   WHERE id = p_message_id
  RETURNING data->'reactions' INTO v_reactions;

  -- ── Notification à l'auteur ────────────────────────────────────────────────
  -- Jamais pour soi-même, ni pour un message système. Une réaction changée ou
  -- retirée remplace la notification encore non lue du même auteur sur le
  -- même message : trois changements d'avis ne font pas trois bannières.
  IF v_msg.sender_id IS NULL OR v_msg.sender_id IN ('', 'system')
     OR v_msg.sender_id = v_uid
     OR COALESCE(v_msg.type, '') = 'system' THEN
    RETURN COALESCE(v_reactions, '{}'::jsonb);
  END IF;

  BEGIN
    DELETE FROM notifications
     WHERE user_id = v_msg.sender_id
       AND type = 'messageReaction'
       AND is_read = FALSE
       AND data->>'messageId' = p_message_id
       AND data->>'actor_id' = v_uid;

    IF v_emoji IS NULL OR v_emoji IS NOT DISTINCT FROM v_previous THEN
      RETURN COALESCE(v_reactions, '{}'::jsonb);
    END IF;

    IF public.is_conversation_muted_for(
         COALESCE(v_conv.data->'mutedBy', '{}'::jsonb), v_msg.sender_id) THEN
      RETURN COALESCE(v_reactions, '{}'::jsonb);
    END IF;

    SELECT u.display_name, u.avatar_url
      INTO v_actor_name, v_actor_photo
      FROM users u
     WHERE u.id = v_uid;

    v_actor_name := COALESCE(NULLIF(v_actor_name, ''), 'Quelqu''un');
    v_conv_type  := COALESCE(v_conv.type, 'individual');
    v_conv_title := COALESCE(
      NULLIF(v_conv.data->>'name', ''),
      NULLIF(v_conv.data->>'title', ''),
      'Groupe'
    );

    -- Aucun extrait du message : il est chiffré, et l'auteur a pu couper les
    -- aperçus. L'emoji et le nom suffisent à dire ce qui s'est passé.
    IF v_conv_type = 'group' THEN
      v_title := v_conv_title;
      v_body  := v_actor_name || ' a réagi ' || v_emoji || ' à votre message';
    ELSE
      v_title := v_actor_name;
      v_body  := 'A réagi ' || v_emoji || ' à votre message';
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE id = v_msg.sender_id) THEN
      INSERT INTO notifications (user_id, type, title, body, data, is_read)
      VALUES (
        v_msg.sender_id,
        'messageReaction',
        v_title,
        v_body,
        jsonb_build_object(
          'type',             'messageReaction',
          -- Même raison que côté MLS. Ici c'est une RPC, pas un
          -- déclencheur : l'instant de l'appel est l'heure de la réaction.
          'sentAt',           (extract(epoch from now()) * 1000)::bigint::text,
          'targetId',         v_msg.conversation_id,
          'target_id',        v_msg.conversation_id,
          'conversationId',   v_msg.conversation_id,
          'messageId',        p_message_id,
          'emoji',            v_emoji,
          'senderId',         v_uid,
          'senderName',       v_actor_name,
          'senderPhotoUrl',   COALESCE(v_actor_photo, ''),
          'conversationType', v_conv_type,
          'actor_id',         v_uid
        ),
        FALSE
      );
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- La réaction est posée : une notification ratée ne doit pas l'annuler.
      RAISE WARNING 'set_message_reaction (notification): %', SQLERRM;
  END;

  RETURN COALESCE(v_reactions, '{}'::jsonb);
END;
$function$;
