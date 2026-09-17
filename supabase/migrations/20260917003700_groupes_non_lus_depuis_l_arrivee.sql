-- Groupes : rien de ce qui précède l'arrivée d'un membre ne compte comme non
-- lu, et les messages système jamais (étape C du plan du séparateur).
--
-- Mesuré en production le 2026-09-17 avant d'écrire :
--
--   · dans le groupe de la conversation ffd4f06e (26 membres), trois membres
--     ont 7, 4 et 3 messages NON LUS ANTÉRIEURS À LEUR ARRIVÉE ; un autre en a 2
--     dans 37fd965c, et aucun après. `repere_de_lecture` les comptait : le
--     séparateur « N messages non lus » se posait sur un message écrit avant
--     que le lecteur ne soit là, avec un nombre gonflé d'autant ;
--   · aucun cas MLS aujourd'hui, mais la vue `mls_unread_counts` — la pastille
--     de la liste des discussions chiffrées — avait le même défaut : un membre
--     arrivé après la bascule voyait tout l'historique chiffré compté non lu,
--     alors qu'il ne peut même pas le déchiffrer (pas d'epoch à lui).
--
-- La date vient de `group_members.joined_at` — mesurée fiable le 2026-09-16 :
-- aucun membre n'a écrit avant sa date, une date distincte par membre.
--
-- Messages système. `sendSystemMessage` écrit `sender_id = 'system'` ET
-- `type = 'system'`. Les fonctions filtraient déjà sur le type ; elles filtrent
-- désormais aussi sur l'expéditeur, pour qu'un message système mal typé ne
-- devienne pas du courrier. Aucun n'existe en base aujourd'hui (mesuré).
--
-- ⚠️ Côté MLS, `content_type = 'system'` n'est PAS exclu : le client y range
-- aussi les journaux d'appel (`MlsMessageMapper`, `call` → `system`), que le
-- clair compte comme non lus (type `call`). Les exclure créerait une différence
-- entre les deux magasins. Aucun message MLS de ce type n'existe (mesuré), et
-- aucun chemin n'envoie de message système par MLS : le jour où il y en aura,
-- il leur faudra un `content_type` distinct.

-- ── 1. repere_de_lecture ────────────────────────────────────────────────────
-- Corps de 20260917002300. Changements : `v_arrivee`, et les trois conditions
-- marquées (arrivée, expéditeur `system`).

CREATE OR REPLACE FUNCTION public.repere_de_lecture(p_conversation_id TEXT)
RETURNS TABLE (
  curseur_id        TEXT,
  curseur_a         TIMESTAMPTZ,
  premier_non_lu_id TEXT,
  premier_non_lu_a  TIMESTAMPTZ,
  non_lus           INTEGER,
  dernier_non_lu_id TEXT,
  dernier_non_lu_a  TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     TEXT := public.firebase_uid();
  v_arrivee TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'repere_de_lecture: session requise' USING ERRCODE = '42501';
  END IF;

  -- Un refus doit se voir. Sans cette garde, un non-participant recevrait un
  -- repère vide — « rien à lire » — indiscernable d'une conversation lue.
  IF NOT EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = p_conversation_id
      AND v_uid = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'repere_de_lecture: pas participant' USING ERRCODE = '42501';
  END IF;

  -- Arrivée dans le groupe (étape C) : rien de ce qui précède ne compte. Nulle
  -- hors groupe, ou pour un groupe hérité de Firestore sans `group_members`.
  -- `group_id::text` : `conversations.group_id` est TEXT, et peut porter un
  -- identifiant non-UUID qu'un cast dans l'autre sens ferait échouer.
  SELECT gm.joined_at INTO v_arrivee
    FROM conversations c
    JOIN group_members gm ON gm.group_id::text = c.group_id AND gm.user_id = v_uid
   WHERE c.id = p_conversation_id;

  RETURN QUERY
  WITH fil AS (
    SELECT m.id AS id,
           m.created_at AS quand,
           COALESCE((m.data->'readBy') ? v_uid, FALSE) AS lu
      FROM messages m
     WHERE m.conversation_id = p_conversation_id
       AND m.sender_id <> v_uid
       AND m.type IS DISTINCT FROM 'system'
       AND m.sender_id <> 'system'
       AND m.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)
       AND NOT COALESCE(m.is_deleted, FALSE)
       AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)
    UNION ALL
    SELECT mm.id::TEXT,
           mm.created_at,
           r.read_at IS NOT NULL
      FROM mls_messages mm
      LEFT JOIN mls_message_receipts r
             ON r.message_id = mm.id AND r.user_id = v_uid
      LEFT JOIN mls_message_hidden h
             ON h.message_id = mm.id AND h.user_id = v_uid
     WHERE mm.conversation_id = p_conversation_id
       AND mm.kind = 'content'
       AND NOT mm.is_deleted
       AND mm.sender_id <> v_uid
       AND mm.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)
       AND h.message_id IS NULL
  ),
  curseur AS (
    SELECT f.id, f.quand FROM fil f
     WHERE f.lu
     ORDER BY f.quand DESC, f.id DESC
     LIMIT 1
  ),
  apres AS (
    SELECT f.id, f.quand FROM fil f
     WHERE NOT f.lu
       AND f.quand > COALESCE((SELECT c.quand FROM curseur c), '-infinity'::timestamptz)
  )
  SELECT (SELECT c.id FROM curseur c),
         (SELECT c.quand FROM curseur c),
         (SELECT a.id FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT a.quand FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT count(*)::INTEGER FROM apres),
         (SELECT a.id FROM apres a ORDER BY a.quand DESC, a.id DESC LIMIT 1),
         (SELECT a.quand FROM apres a ORDER BY a.quand DESC, a.id DESC LIMIT 1);
END;
$$;

REVOKE ALL ON FUNCTION public.repere_de_lecture(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repere_de_lecture(TEXT) TO authenticated;

-- ── 2. marquer_lus_jusqua ───────────────────────────────────────────────────
-- Corps de 20260916224700. Changements : `v_arrivee`, et le RECOMPTE qui
-- l'exclut avec l'expéditeur `system`. Le marquage lui-même reste tel quel :
-- lire jusqu'à un message marque aussi l'historique d'avant l'arrivée, ce qui
-- est vrai et sans conséquence.

CREATE OR REPLACE FUNCTION public.marquer_lus_jusqua(
  p_conversation_id TEXT,
  p_message_id      TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid      TEXT := public.firebase_uid();
  v_now      TEXT := NOW()::TEXT;
  v_borne    TIMESTAMPTZ;
  v_bascule  TIMESTAMPTZ;
  v_reste    INTEGER;
  v_data     JSONB;
  v_nouvelle JSONB;
  v_lecteurs JSONB;
  v_arrivee  TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: session requise' USING ERRCODE = '42501';
  END IF;

  -- `FOR UPDATE` : le recompte et l'écriture de `data` ci-dessous forment une
  -- lecture-modification-écriture. Le verrou la rend atomique face à un autre
  -- appel du même utilisateur (deux appareils).
  SELECT c.data, c.mls_since INTO v_data, v_bascule
    FROM conversations c
   WHERE c.id = p_conversation_id
     AND v_uid = ANY (c.participant_ids)
     FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: pas participant' USING ERRCODE = '42501';
  END IF;

  -- Arrivée dans le groupe (étape C) : rien de ce qui précède ne compte. Nulle
  -- hors groupe, ou pour un groupe hérité de Firestore sans `group_members`.
  -- `group_id::text` : `conversations.group_id` est TEXT, et peut porter un
  -- identifiant non-UUID qu'un cast dans l'autre sens ferait échouer.
  SELECT gm.joined_at INTO v_arrivee
    FROM conversations c
    JOIN group_members gm ON gm.group_id::text = c.group_id AND gm.user_id = v_uid
   WHERE c.id = p_conversation_id;

  SELECT m.created_at INTO v_borne
    FROM messages m
   WHERE m.id = p_message_id
     AND m.conversation_id = p_conversation_id;

  IF v_borne IS NULL THEN
    BEGIN
      SELECT mm.created_at INTO v_borne
        FROM mls_messages mm
       WHERE mm.id = p_message_id::uuid
         AND mm.conversation_id = p_conversation_id;
    EXCEPTION WHEN invalid_text_representation THEN
      v_borne := NULL; -- identifiant legacy non-UUID : pas un message MLS
    END;
  END IF;

  -- Une borne introuvable est une erreur, pas un « rien à faire » : sinon un
  -- identifiant faux passerait pour un succès, et le curseur n'avancerait
  -- jamais sans que personne le sache.
  IF v_borne IS NULL THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: message inconnu dans cette conversation'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE messages m
     SET data = jsonb_set(
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 COALESCE(m.data, '{}'::jsonb),
                 '{readBy}',
                 CASE WHEN jsonb_typeof(m.data->'readBy') = 'array'
                      THEN m.data->'readBy' ELSE '[]'::jsonb END
                   || to_jsonb(v_uid)
               ),
               '{readAt}',
               -- `||` garde la valeur de DROITE : une heure déjà posée gagne.
               jsonb_build_object(v_uid, v_now)
                 || CASE WHEN jsonb_typeof(m.data->'readAt') = 'object'
                         THEN m.data->'readAt' ELSE '{}'::jsonb END
             ),
             '{deliveredTo}',
             CASE
               WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                    AND (m.data->'deliveredTo') ? v_uid
                 THEN m.data->'deliveredTo'
               WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                 THEN (m.data->'deliveredTo') || to_jsonb(v_uid)
               ELSE jsonb_build_array(v_uid)
             END
           ),
           '{deliveredAt}',
           jsonb_build_object(v_uid, v_now)
             || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'
                     THEN m.data->'deliveredAt' ELSE '{}'::jsonb END
         )
   WHERE m.conversation_id = p_conversation_id
     AND m.sender_id <> v_uid
     AND m.created_at <= v_borne
     AND NOT COALESCE((m.data->'readBy') ? v_uid, FALSE);

  -- Même définition que `repere_de_lecture`, sans la borne du curseur : c'est
  -- le compte de la pastille, pas celui du séparateur.
  SELECT count(*)::INTEGER INTO v_reste
    FROM messages m
   WHERE m.conversation_id = p_conversation_id
     AND m.sender_id <> v_uid
     AND m.type IS DISTINCT FROM 'system'
     AND m.sender_id <> 'system'
     AND m.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)
     AND NOT COALESCE(m.is_deleted, FALSE)
     AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)
     AND NOT COALESCE((m.data->'readBy') ? v_uid, FALSE);

  v_nouvelle := COALESCE(v_data, '{}'::jsonb);
  v_nouvelle := jsonb_set(
    v_nouvelle,
    '{unreadCount}',
    CASE WHEN jsonb_typeof(v_nouvelle->'unreadCount') = 'object'
         THEN v_nouvelle->'unreadCount' ELSE '{}'::jsonb END
      || jsonb_build_object(v_uid, v_reste)
  );

  -- « Le dernier message a été lu par… » alimente les coches de la liste chez
  -- l'expéditeur. On ne s'y ajoute que quand plus rien ne reste à lire — et
  -- jamais sur une conversation basculée, dont le dernier message est MLS :
  -- n'avoir plus de legacy à lire n'y dit rien du dernier message.
  IF v_reste = 0 AND v_bascule IS NULL THEN
    v_lecteurs := CASE WHEN jsonb_typeof(v_nouvelle->'lastMessageReadBy') = 'array'
                       THEN v_nouvelle->'lastMessageReadBy' ELSE '[]'::jsonb END;
    IF NOT v_lecteurs ? v_uid THEN
      v_nouvelle := jsonb_set(v_nouvelle, '{lastMessageReadBy}', v_lecteurs || to_jsonb(v_uid));
    END IF;
  END IF;

  IF v_nouvelle IS DISTINCT FROM COALESCE(v_data, '{}'::jsonb) THEN
    UPDATE conversations SET data = v_nouvelle WHERE id = p_conversation_id;
  END IF;

  -- Les notifications de ce qui vient d'être lu. `mark_messages_as_read` les
  -- marquait toutes ; ici, celles d'un message POSTÉRIEUR à la borne restent :
  -- il n'a pas été vu. Les réactions (`messageReaction`) portent sur mes
  -- propres messages et n'ont pas de place dans le fil d'autrui — elles
  -- partent dès qu'on regarde la discussion, comme avant.
  UPDATE notifications n
     SET is_read = TRUE
   WHERE n.user_id = v_uid
     AND NOT n.is_read
     AND n.type IN ('message', 'messageReaction')
     AND n.data->>'conversationId' = p_conversation_id
     AND NOT (
       n.type = 'message'
       AND (
         EXISTS (SELECT 1 FROM messages m
                  WHERE m.id = n.data->>'messageId'
                    AND m.created_at > v_borne)
         OR EXISTS (SELECT 1 FROM mls_messages mm
                     WHERE mm.id::TEXT = n.data->>'messageId'
                       AND mm.created_at > v_borne)
       )
     );

  RETURN v_reste;
END;
$$;

REVOKE ALL ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) TO authenticated;

-- ── 3. mls_unread_counts ────────────────────────────────────────────────────
-- Définition relue dans `pg_get_viewdef` le 2026-09-17. Seuls ajouts : la
-- jointure sur `group_members` et sa condition. Mêmes colonnes, même ordre —
-- condition de `CREATE OR REPLACE VIEW`.
--
-- `security_invoker = on` est REDIT : `CREATE OR REPLACE VIEW` remplace les
-- options par celles de l'instruction. Sans lui, la vue repasserait en droits
-- du propriétaire, et `firebase_uid()` resterait le seul filtre — la RLS de
-- `mls_messages` ne s'appliquerait plus.

CREATE OR REPLACE VIEW public.mls_unread_counts
WITH (security_invoker = on) AS
 SELECT m.conversation_id,
    moi.user_id,
    count(*) FILTER (WHERE r.read_at IS NULL) AS unread,
    count(*) FILTER (WHERE r.read_at IS NULL AND mn.user_id IS NOT NULL) AS unread_mentions
   FROM mls_messages m
     JOIN conversations c ON c.id = m.conversation_id
     CROSS JOIN LATERAL ( SELECT firebase_uid() AS user_id) moi
     LEFT JOIN mls_message_receipts r ON r.message_id = m.id AND r.user_id = moi.user_id
     LEFT JOIN mls_message_mentions mn ON mn.message_id = m.id AND mn.user_id = moi.user_id
     LEFT JOIN mls_message_hidden h ON h.message_id = m.id AND h.user_id = moi.user_id
     LEFT JOIN group_members gm ON gm.group_id::text = c.group_id AND gm.user_id = moi.user_id
  WHERE m.kind = 'content'::text AND NOT m.is_deleted AND h.message_id IS NULL
    AND moi.user_id IS NOT NULL AND moi.user_id <> m.sender_id
    AND (moi.user_id = ANY (c.participant_ids))
    AND (gm.joined_at IS NULL OR m.created_at > gm.joined_at)
  GROUP BY m.conversation_id, moi.user_id;

REVOKE ALL ON public.mls_unread_counts FROM anon;
GRANT SELECT ON public.mls_unread_counts TO authenticated;
