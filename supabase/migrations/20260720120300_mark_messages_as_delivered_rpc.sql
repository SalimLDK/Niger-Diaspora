-- =============================================================================
-- RPC : mark_messages_as_delivered
--
-- Marque tous les messages non-lus d'une conversation comme livrés au
-- destinataire courant. Met à jour :
--   - messages.data->'deliveredTo'  : ajoute l'userId
--   - messages.data->'deliveredAt'  : timestamp ISO par userId
--   - messages.data->'readBy'       : ajoute l'userId
--   - messages.data->'readAt'       : timestamp ISO par userId
--
-- Pourquoi livré ET lu en une fois ? Lorsque l'utilisateur ouvre l'app via la
-- notification ou affiche la conversation, on considère implicitement que le
-- message est vu.
--
-- Single source of truth : remplace l'ancienne écriture directe dans
-- Firebase RTDB faite par notification_service.dart. Les accusés de réception
-- sont désormais stockés dans la colonne JSONB `data` de `messages` et
-- diffusés en temps réel via Supabase Realtime.
--
-- Sécurité : SECURITY DEFINER, appelable par authenticated. On vérifie que
-- l'appelant est bien participant de la conversation.
--
-- Idempotent : les tableaux/maps JSONB sont mergeés, pas écrasés.
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

  -- Vérifier que l'utilisateur est participant de la conversation
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

REVOKE ALL ON FUNCTION public.mark_messages_as_delivered(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_delivered(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.mark_messages_as_delivered(UUID, TEXT) IS
  'Marque tous les messages d''une conversation comme livrus/lus par l''utilisateur courant (JSONB data). Appelé depuis notification_service.dart.';
