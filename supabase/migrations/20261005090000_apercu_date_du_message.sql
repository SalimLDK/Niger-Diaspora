-- `last_message_at` reprend la date DU MESSAGE, pas celle de l'après-envoi.
--
-- LE DÉFAUT (introduit par 20261004090000 et 20261004100000)
-- Deux mécanismes reconnaissent le dernier message d'une conversation à
-- l'égalité `conversations.last_message_at = messages.created_at` :
--   · « supprimer pour tout le monde » (`_viderApercuSiDernier`) ;
--   · la purge des messages éphémères (`purger_messages_expires`).
-- Tant que le client écrivait les deux dates avec la même valeur, l'égalité
-- tenait. Depuis que `created_at` est posé par le serveur À L'INSERTION
-- (20261004090000) et `last_message_at` par `apres_envoi_message` DANS UNE
-- AUTRE REQUÊTE (20261004100000), les deux `now()` diffèrent toujours de
-- quelques millisecondes. Plus aucun aperçu n'était vidé : le texte d'un
-- message supprimé pour tout le monde, ou expiré, restait lisible EN CLAIR
-- dans la liste des discussions, sous la bulle « Message supprimé ».
--
-- LE CORRECTIF
-- `apres_envoi_message` reçoit l'identifiant du message et en recopie le
-- `created_at`. L'égalité redevient exacte, sans toucher ni au client de
-- suppression ni à la purge.
--
-- Et un envoi qui arrive en retard — deux messages partis coup sur coup, le
-- second dont l'après-envoi passe avant le premier — n'écrase plus l'aperçu
-- du plus récent : seule la pastille est incrémentée.
--
-- Le message doit appartenir à la conversation et à l'appelant : sinon
-- n'importe qui pourrait recopier la date d'un message tiers.
--
-- Banc : tools/rls_tests/apercu_date_du_message.sql

DROP FUNCTION IF EXISTS public.apres_envoi_message(TEXT, JSONB);

CREATE OR REPLACE FUNCTION public.apres_envoi_message(
  p_conversation_id TEXT,
  p_message_id TEXT,
  p_apercu JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid TEXT := public.firebase_uid();
  v_quand TIMESTAMPTZ;
  v_maj INTEGER;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'apres_envoi_message : non authentifié' USING ERRCODE = '42501';
  END IF;

  SELECT m.created_at INTO v_quand
    FROM messages m
   WHERE m.id = p_message_id
     AND m.conversation_id = p_conversation_id
     AND m.sender_id = v_uid;
  IF v_quand IS NULL THEN
    RAISE EXCEPTION 'apres_envoi_message : message % introuvable', p_message_id
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE conversations c
     SET last_message_at = GREATEST(c.last_message_at, v_quand),
         data = CASE
                  -- Le plus récent porte l'aperçu ; un retardataire non.
                  WHEN c.last_message_at IS NULL OR v_quand >= c.last_message_at THEN
                    (COALESCE(c.data, '{}'::jsonb)
                       - 'lastMessageDeleted' - 'lastMessageExpired')
                    || COALESCE(p_apercu, '{}'::jsonb)
                    || jsonb_build_object(
                         'lastMessageSenderId', v_uid,
                         'lastMessageStatus', 'sent',
                         'lastMessageReadBy', jsonb_build_array(v_uid),
                         'lastMessageDeliveredTo', jsonb_build_array(v_uid))
                  ELSE COALESCE(c.data, '{}'::jsonb)
                END
                || jsonb_build_object(
                     'unreadCount',
                       CASE WHEN jsonb_typeof(c.data -> 'unreadCount') = 'object'
                            THEN c.data -> 'unreadCount' ELSE '{}'::jsonb END
                       || COALESCE((
                            SELECT jsonb_object_agg(
                                     p.pid,
                                     COALESCE(
                                       CASE WHEN jsonb_typeof(c.data -> 'unreadCount' -> p.pid) = 'number'
                                            THEN (c.data -> 'unreadCount' ->> p.pid)::numeric::integer
                                       END, 0) + 1)
                              FROM unnest(c.participant_ids) AS p(pid)
                             WHERE p.pid IS DISTINCT FROM v_uid
                               -- Un message système n'est pas du courrier.
                               AND COALESCE(p_apercu ->> 'lastMessageType', '')
                                     <> 'system'
                          ), '{}'::jsonb))
   WHERE c.id = p_conversation_id;

  GET DIAGNOSTICS v_maj = ROW_COUNT;
  RETURN v_maj > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.apres_envoi_message(TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apres_envoi_message(TEXT, TEXT, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
