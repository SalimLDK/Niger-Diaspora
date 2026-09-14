-- =============================================================================
-- Réaction à un message : écriture atomique + notification à l'auteur
--
-- Deux défauts signalés le 2026-09-12 (« l'emoji n'envoie pas de notification,
-- ne se met pas tout le temps à jour »), une seule cause d'écriture :
--
-- 1. Le client relisait `messages.data` EN ENTIER, y posait sa réaction, puis
--    réécrivait tout le document. Tout ce qui touchait la ligne entre les deux
--    était perdu : la réaction d'un autre membre (groupe), et surtout
--    `mark_messages_as_read`, qui s'exécute précisément quand on ouvre la
--    discussion — c'est-à-dire juste avant de réagir. Selon l'ordre d'arrivée,
--    la réaction ou l'accusé de lecture disparaissait, sans erreur.
--
-- 2. Aucune notification n'était jamais créée : la chaîne push ne part que
--    d'un INSERT dans `notifications`, et une réaction n'en produisait pas.
--
-- `set_message_reaction` modifie la seule clé `reactions.<uid>` au moment de
-- l'UPDATE (sur la version courante de la ligne, jamais sur une copie lue
-- avant), et crée la notification dans la même transaction.
--
-- `p_emoji` NULL (ou vide) = retirer sa réaction.
--
-- L'identité vient de `firebase_uid()`, jamais d'un paramètre : personne ne
-- peut réagir au nom d'un autre. Le client garde un repli sur l'ancienne
-- écriture tant que cette fonction n'est pas déployée (PGRST202).
-- =============================================================================

DROP FUNCTION IF EXISTS public.set_message_reaction(TEXT, TEXT);

CREATE FUNCTION public.set_message_reaction(
  p_message_id TEXT,
  p_emoji      TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

REVOKE ALL ON FUNCTION public.set_message_reaction(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_message_reaction(TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.set_message_reaction(TEXT, TEXT) IS
  'Pose (ou retire, emoji NULL) la réaction de l''utilisateur courant sur un '
  'message, sans réécrire le reste de messages.data, et notifie l''auteur '
  '(type messageReaction).';
