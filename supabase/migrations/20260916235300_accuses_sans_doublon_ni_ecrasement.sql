-- Accusés en clair : plus de doublon dans `deliveredTo`, plus d'heure de
-- livraison écrasée par la lecture.
--
-- Mesuré en production le 2026-09-16, après application de 20260916224700 :
--
--   · 84 messages portent un même utilisateur plusieurs fois dans
--     `data->'deliveredTo'` (83 quelques heures plus tôt : le compte montait) ;
--   · pour 424 couples (message, lecteur), `deliveredAt` est STRICTEMENT égal à
--     `readAt` — et il n'existe AUCUN couple où la livraison précède la
--     lecture. Toute heure de livraison a donc été remplacée par l'heure de
--     lecture ; l'écran d'information d'un message montrait « Distribué » et
--     « Lu » à la même seconde.
--
-- La cause est unique : `mark_messages_as_read` ne filtre que sur `readBy`, et
-- pour chaque message non encore lu il AJOUTE l'utilisateur à `deliveredTo`
-- sans regarder s'il y est déjà, et RÉÉCRIT `deliveredAt[uid]`. Or un message
-- reçu par notification est presque toujours déjà livré quand on le lit.
--
-- `mark_messages_as_delivered` ne fabrique pas de doublon (son WHERE exclut les
-- messages déjà livrés), mais la même règle d'écriture lui est appliquée, pour
-- qu'une donnée incohérente (heure posée sans l'identifiant) ne soit pas
-- écrasée non plus.
--
-- Ce que l'application lit ne changeait pas à l'écran pour les doublons : le
-- client refait l'union par ensemble (`_mergedReceipts`). La base, elle,
-- mentait, et tout lecteur direct de `deliveredTo` (compte, SQL, Edge
-- Function) se trompait.
--
-- ⚠️ CE QUI NE SE RÉPARE PAS : les 424 heures de livraison écrasées. L'heure
-- d'origine n'est écrite nulle part ailleurs ; en inventer une serait pire que
-- de laisser « livré = lu ». Seuls les accusés à venir seront justes.
--
-- `marquer_lus_jusqua` (20260916224700), que l'application appelle désormais,
-- suivait déjà cette règle. Ce correctif vaut pour les versions de l'app
-- encore installées qui appellent l'ancienne RPC à l'ouverture, pour
-- `BackgroundReplyService.markAsRead`, et pour le repli de l'écran.

-- ── 1. mark_messages_as_read ────────────────────────────────────────────────
-- Corps repris de 20260916224700 (garde d'identité comprise). Seules changent
-- les trois expressions d'écriture ; `||` garde la valeur de DROITE, donc une
-- heure déjà posée gagne.

CREATE OR REPLACE FUNCTION public.mark_messages_as_read(
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

  IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN
    RAISE EXCEPTION 'mark_messages_as_read: on ne marque lu que pour soi'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_read: user is not a participant';
  END IF;

  -- Lire implique avoir reçu : on pose aussi deliveredTo/deliveredAt, pour les
  -- messages ouverts directement (sans étape de livraison push) — mais sans
  -- toucher à ce qui est déjà posé.
  UPDATE messages m
  SET data = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              COALESCE(m.data, '{}'::jsonb),
              '{deliveredTo}',
              CASE
                WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                     AND (m.data->'deliveredTo') ? p_user_id
                  THEN m.data->'deliveredTo'
                WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                  THEN (m.data->'deliveredTo') || to_jsonb(p_user_id)
                ELSE jsonb_build_array(p_user_id)
              END
            ),
            '{deliveredAt}',
            jsonb_build_object(p_user_id, v_now)
              || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'
                      THEN m.data->'deliveredAt' ELSE '{}'::jsonb END
          ),
          '{readBy}',
          CASE WHEN jsonb_typeof(m.data->'readBy') = 'array'
               THEN m.data->'readBy' ELSE '[]'::jsonb END
            || to_jsonb(p_user_id)
        ),
        '{readAt}',
        jsonb_build_object(p_user_id, v_now)
          || CASE WHEN jsonb_typeof(m.data->'readAt') = 'object'
                  THEN m.data->'readAt' ELSE '{}'::jsonb END
      )
  WHERE m.conversation_id = p_conversation_id
    AND m.sender_id <> p_user_id
    AND NOT COALESCE((m.data->'readBy') ? p_user_id, FALSE);

  UPDATE notifications
  SET is_read = TRUE
  WHERE user_id = p_user_id
    AND NOT is_read
    AND type IN ('message', 'messageReaction')
    AND data->>'conversationId' = p_conversation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) TO authenticated;

-- ── 2. mark_messages_as_delivered ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.mark_messages_as_delivered(
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

  IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: on n''accuse réception que pour soi'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: user is not a participant';
  END IF;

  UPDATE messages m
  SET data = jsonb_set(
        jsonb_set(
          COALESCE(m.data, '{}'::jsonb),
          '{deliveredTo}',
          CASE WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
               THEN m.data->'deliveredTo' ELSE '[]'::jsonb END
            || to_jsonb(p_user_id)
        ),
        '{deliveredAt}',
        jsonb_build_object(p_user_id, v_now)
          || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'
                  THEN m.data->'deliveredAt' ELSE '{}'::jsonb END
      )
  WHERE m.conversation_id = p_conversation_id
    AND m.sender_id <> p_user_id
    AND NOT COALESCE((m.data->'deliveredTo') ? p_user_id, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) TO authenticated;

-- ── 3. Réparation des doublons existants ────────────────────────────────────
-- Chaque identifiant n'est gardé qu'une fois, à la place de sa PREMIÈRE
-- apparition : l'ordre d'arrivée reste lisible.
--
-- Exécuté en `postgres` : `messages_garde_update_trg` laisse passer (il ne
-- filtre que `authenticated` et `anon`), et les deux déclencheurs AFTER UPDATE
-- ne réagissent qu'à `editedAt` et à `is_deleted`, que ceci ne touche pas.

UPDATE public.messages m
SET data = jsonb_set(
      m.data,
      '{deliveredTo}',
      (SELECT jsonb_agg(u.e ORDER BY u.premier)
         FROM (SELECT t.e, min(t.pos) AS premier
                 FROM jsonb_array_elements(m.data->'deliveredTo') WITH ORDINALITY AS t(e, pos)
                GROUP BY t.e) u)
    )
WHERE jsonb_typeof(m.data->'deliveredTo') = 'array'
  AND jsonb_array_length(m.data->'deliveredTo')
      <> (SELECT count(DISTINCT e) FROM jsonb_array_elements(m.data->'deliveredTo') e);
