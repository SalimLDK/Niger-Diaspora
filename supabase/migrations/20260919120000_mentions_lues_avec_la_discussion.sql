-- Une mention est lue avec la discussion qui la porte.
--
-- `messageMention` — une mention dans une conversation en SOURDINE, écrite par
-- `notify_recipients_on_message_insert` (20260916130000) — est affichée par
-- l'écran Notifications et comptée par la cloche : elle n'est pas dans
-- `kTypesHorsEcranNotifications`. Or les deux fonctions qui marquent des
-- notifications lues ne connaissaient que `message` et `messageReaction`. Lire
-- la discussion, ou toucher « Marquer comme lu » sur la bannière
-- (`BackgroundReplyService.markAsRead` → `mark_messages_as_read`), laissait la
-- mention non lue jusqu'à un appui dans la liste.
--
-- Relevé le 2026-09-19, sur les définitions VIVANTES (`pg_get_functiondef`) :
--
--   · `mark_messages_as_read` et `marquer_lus_jusqua` sont les SEULES fonctions
--     de `public` qui font `UPDATE notifications` (recherche dans `prosrc`) ;
--   · aucune des deux ne cite `messageMention` ;
--   · aucune ligne `messageMention` n'existe encore en base (0 sur 0) : le
--     trou est préventif, il n'explique rien de ce qui a été observé.
--
-- Ce qui change — trois lignes de logique, le reste est la définition vivante
-- recopiée telle quelle :
--
--   · `mark_messages_as_read` : `messageMention` rejoint la liste des types. La
--     borne est « toute la discussion », comme pour `message`.
--   · `marquer_lus_jusqua` : `messageMention` rejoint la liste ET la clause
--     d'exclusion par borne. Une mention dont le message est POSTÉRIEUR à la
--     dernière bulle vue reste non lue — même règle que `message`, sinon elle
--     partirait avant d'avoir été vue.
--
-- Les mentions ne voyagent qu'en clair (dans une conversation MLS elles sont
-- dans la charge chiffrée : le serveur ne peut pas savoir qu'il vous nomme).
-- Le `EXISTS` sur `mls_messages` de la clause de borne ne les concerne donc pas ;
-- il reste par symétrie avec `message`, qui peut annoncer un message MLS.
--
-- Attributs conservés : SECURITY DEFINER et `search_path` de chaque fonction,
-- propriétaire, ACL (`authenticated` et `service_role` exécutent ; ni `anon` ni
-- `PUBLIC`). `CREATE OR REPLACE` ne touche pas aux droits ; les `REVOKE`/`GRANT`
-- de fin ne font que le redire, comme les migrations voisines.
--
-- ⚠️ Le client marque déjà les mentions de la DISCUSSION OUVERTE
-- (`NotificationReadSync`, commit 2c00d81), avec une marge de 2 s. Une fois cette
-- migration appliquée, ce marquage est redondant — et moins exact que celui-ci
-- (jointure sur l'identifiant du message, pas sur une date). À retirer alors,
-- pour qu'il n'y ait qu'une seule source.
--
-- Banc : tools/rls_tests/mentions_lues_avec_la_discussion.sql.

-- ── 1. mark_messages_as_read ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_messages_as_read(p_conversation_id text, p_user_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Les notifications de la discussion, mentions comprises (`messageMention`,
  -- écrite quand la conversation est en sourdine). Elle est affichée par
  -- l'écran Notifications et comptée par la cloche : la laisser non lue
  -- quand on a lu la discussion qui la porte était un oubli de liste.
  UPDATE notifications
  SET is_read = TRUE
  WHERE user_id = p_user_id
    AND NOT is_read
    AND type IN ('message', 'messageReaction', 'messageMention')
    AND data->>'conversationId' = p_conversation_id;
END;
$function$;

-- ── 2. marquer_lus_jusqua ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.marquer_lus_jusqua(p_conversation_id text, p_message_id text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  -- partent dès qu'on regarde la discussion, comme avant. Une mention
  -- (`messageMention`) suit la règle du message qu'elle annonce : celle d'un
  -- message postérieur à la borne reste.
  UPDATE notifications n
     SET is_read = TRUE
   WHERE n.user_id = v_uid
     AND NOT n.is_read
     AND n.type IN ('message', 'messageReaction', 'messageMention')
     AND n.data->>'conversationId' = p_conversation_id
     AND NOT (
       n.type IN ('message', 'messageMention')
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
$function$;

REVOKE ALL ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) TO authenticated;
