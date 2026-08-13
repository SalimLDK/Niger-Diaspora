-- =============================================================================
-- Sépare « livré » de « lu »
--
-- Bug : mark_messages_as_delivered écrivait deliveredTo/deliveredAt ET
-- readBy/readAt dans le même appel. Elle est appelée dès qu'une notification
-- push atteint l'appareil (notification_service.dart, handler background ET
-- foreground) — donc un message passait à « lu » avant même que l'utilisateur
-- ait ouvert la conversation. Le sheet « infos du message »
-- (message_info_sheet.dart) affichait alors les mêmes utilisateurs aux mêmes
-- horodatages dans les onglets « Lu par » et « Livré à », sans distinction
-- possible.
--
-- mark_messages_as_delivered ne touche désormais QUE deliveredTo/deliveredAt.
-- mark_messages_as_read (nouvelle RPC) touche readBy/readAt ET
-- deliveredTo/deliveredAt (lire implique avoir reçu) ; elle n'est appelée que
-- lorsque l'utilisateur ouvre réellement la conversation
-- (conversation_screen.dart → markAsReadProvider).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.mark_messages_as_delivered(
  p_conversation_id UUID,
  p_user_id         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TEXT := NOW()::TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: user_id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: user is not a participant';
  END IF;

  UPDATE messages
  SET data = jsonb_set(
        jsonb_set(
          COALESCE(data, '{}'::jsonb),
          '{deliveredTo}',
          COALESCE(
            (data->'deliveredTo') || to_jsonb(p_user_id),
            jsonb_build_array(p_user_id)
          )
        ),
        '{deliveredAt}',
        COALESCE(
          jsonb_set(
            COALESCE(data->'deliveredAt', '{}'::jsonb),
            ARRAY[p_user_id],
            to_jsonb(v_now)
          ),
          jsonb_build_object(p_user_id, v_now)
        )
      )
  WHERE conversation_id = p_conversation_id
    AND sender_id <> p_user_id
    AND (
      data->'deliveredTo' IS NULL
      OR NOT (data->'deliveredTo') ? p_user_id
    );
END;
$$;

COMMENT ON FUNCTION public.mark_messages_as_delivered(UUID, TEXT) IS
  'Marque les messages d''une conversation comme livrés (reçus sur l''appareil) par l''utilisateur courant. Ne marque PAS comme lu — voir mark_messages_as_read. Appelée dès la réception d''une notification push.';

CREATE OR REPLACE FUNCTION public.mark_messages_as_read(
  p_conversation_id UUID,
  p_user_id         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TEXT := NOW()::TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'mark_messages_as_read: user_id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_read: user is not a participant';
  END IF;

  -- Lire implique avoir reçu : on pose aussi deliveredTo/deliveredAt, pour
  -- les messages ouverts directement (sans étape de livraison push).
  UPDATE messages
  SET data = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              COALESCE(data, '{}'::jsonb),
              '{deliveredTo}',
              COALESCE(
                (data->'deliveredTo') || to_jsonb(p_user_id),
                jsonb_build_array(p_user_id)
              )
            ),
            '{deliveredAt}',
            COALESCE(
              jsonb_set(
                COALESCE(data->'deliveredAt', '{}'::jsonb),
                ARRAY[p_user_id],
                to_jsonb(v_now)
              ),
              jsonb_build_object(p_user_id, v_now)
            )
          ),
          '{readBy}',
          COALESCE(
            (data->'readBy') || to_jsonb(p_user_id),
            jsonb_build_array(p_user_id)
          )
        ),
        '{readAt}',
        COALESCE(
          jsonb_set(
            COALESCE(data->'readAt', '{}'::jsonb),
            ARRAY[p_user_id],
            to_jsonb(v_now)
          ),
          jsonb_build_object(p_user_id, v_now)
        )
      )
  WHERE conversation_id = p_conversation_id
    AND sender_id <> p_user_id
    AND (
      data->'readBy' IS NULL
      OR NOT (data->'readBy') ? p_user_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_read(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.mark_messages_as_read(UUID, TEXT) IS
  'Marque les messages d''une conversation comme lus (et livrés) par l''utilisateur courant. Appelée uniquement quand l''utilisateur ouvre réellement la conversation (conversation_screen.dart).';
