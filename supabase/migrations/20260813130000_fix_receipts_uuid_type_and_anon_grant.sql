-- =============================================================================
-- Corrige 20260813120000 : mauvais type de paramètre + accès anonyme
--
-- Deux bugs découverts en déployant 20260813120000, aucun des deux visible en
-- lecture du dépôt seul :
--
-- 1) TYPE. `messages.conversation_id`, `messages.sender_id`, `messages.id` et
--    `conversations.id` sont tous en TEXT sur le distant (jamais UUID, malgré
--    ce qu'affirmait 20260727180000). `mark_messages_as_delivered(UUID, TEXT)`
--    — déployée depuis le 20260720120300 — compare donc une colonne TEXT à un
--    paramètre UUID (`conversation_id = p_conversation_id`), ce qui n'a pas
--    d'opérateur en Postgres : CHAQUE appel levait 42883 « operator does not
--    exist: text = uuid ». Les accusés de livraison n'ont jamais été écrits
--    depuis la création de cette RPC — l'erreur était avalée en silence par
--    les `catch` de notification_service.dart / message_supabase_datasource.dart
--    (« best effort »). 20260813120000 a copié ce même type UUID pour
--    mark_messages_as_read : même défaut, en plus tout neuf.
--
-- 2) ANON. Une fonction `mark_messages_as_read(TEXT, TEXT)` existait déjà sur
--    le distant, orpheline (absente de toute migration du dépôt, jamais
--    appelée par le code actuel), SANS vérification de participant, et
--    accessible à `anon`. Elle collisionnait avec celle créée par
--    20260813120000 (PGRST203, comme l'incident du 20260727) et aurait permis
--    à n'importe qui de forger un accusé de lecture sur n'importe quelle
--    conversation.
--
--    Cause structurelle de l'exposition anon : ALTER DEFAULT PRIVILEGES sur ce
--    projet accorde EXECUTE à `anon` (et `authenticated`, `service_role`) sur
--    toute fonction créée par `postgres` — un `REVOKE ALL ... FROM PUBLIC`
--    (motif utilisé par 20260720120300) ne retire PAS ce droit, parce que le
--    droit par défaut est accordé au rôle `anon` directement, pas à `PUBLIC`.
--    Toute nouvelle RPC doit donc `REVOKE ... FROM PUBLIC, anon` explicitement.
--    D'autres fonctions du projet sont probablement dans le même cas — hors
--    périmètre ici, à auditer séparément.
-- =============================================================================

DROP FUNCTION IF EXISTS public.mark_messages_as_delivered(UUID, TEXT);
DROP FUNCTION IF EXISTS public.mark_messages_as_read(UUID, TEXT);
DROP FUNCTION IF EXISTS public.mark_messages_as_read(TEXT, TEXT);

CREATE FUNCTION public.mark_messages_as_delivered(
  p_conversation_id TEXT,
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

REVOKE ALL ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) IS
  'Marque les messages d''une conversation comme livrés (reçus sur l''appareil) par l''utilisateur courant. Ne marque PAS comme lu — voir mark_messages_as_read. Appelée dès la réception d''une notification push.';

CREATE FUNCTION public.mark_messages_as_read(
  p_conversation_id TEXT,
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

REVOKE ALL ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) IS
  'Marque les messages d''une conversation comme lus (et livrés) par l''utilisateur courant. Appelée uniquement quand l''utilisateur ouvre réellement la conversation (conversation_screen.dart).';
