-- =============================================================================
-- Notifications obsolètes marquées lues, et suppression d'événement par l'admin.
--
-- Signalé le 2026-09-12 : « les notifs déjà ouvertes autre part ou obsolètes
-- sont toujours marquées comme non lues ». Mesuré le même jour : 73
-- notifications `message` non lues en base, TOUTES obsolètes —
--   * 45 portent sur un message que le destinataire a déjà lu
--     (`messages.data.readBy` le contient) : lire la discussion n'a jamais
--     touché la notification ;
--   * 28 portent sur un message et une conversation qui n'existent plus
--     (purge du 2026-08-14).
-- Plus 2 `eventAttendance` sur des événements supprimés (la table `events` est
-- vide) et 1 `groupInvite` dont l'invitation n'est plus en attente.
--
-- Rien, côté base, ne reliait une notification à la vie de sa cible. Ce
-- fichier le fait à trois endroits :
--   1. lire une discussion (RPC `mark_messages_as_read`) marque lues ses
--      notifications — pour l'appelant seulement ;
--   2. supprimer la cible (événement, publication, groupe, conversation,
--      message) ou clore l'invitation marque lues les notifications qui la
--      désignent ;
--   3. un rattrapage marque lues celles qui le sont déjà devenues.
-- Marquées LUES, pas supprimées : la personne garde la trace, le compteur
-- cesse de mentir.
--
-- Et un défaut voisin : « supprimé mais toujours affiché » pour un événement.
-- `events` n'avait qu'une policy d'écriture, `events_manage_own` : une
-- suppression depuis le back-office effaçait zéro ligne, sans erreur, et
-- l'écran annonçait le succès. Policies admin UPDATE/DELETE ajoutées (l'app
-- compte désormais les lignes effacées).
-- =============================================================================

-- ── 0. Suppression / annulation d'événement par un administrateur ───────────

DROP POLICY IF EXISTS events_admin_update ON public.events;
CREATE POLICY events_admin_update ON public.events
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin()))
  WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS events_admin_delete ON public.events;
CREATE POLICY events_admin_delete ON public.events
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin()));

-- ── 1. Marquer lues les notifications qui désignent une cible ───────────────
-- Les notifications ne partagent pas de colonne de cible : selon l'émetteur,
-- l'identifiant vit sous `targetId`, `target_id`, `eventId`, `postId`… (cf
-- `NotificationSupabaseDataSource.fromRow`). On passe donc la liste des clés.

CREATE OR REPLACE FUNCTION private.lire_notifications_de_cible(
  p_id   TEXT,
  p_cles TEXT[]
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE notifications n
  SET is_read = TRUE
  WHERE NOT n.is_read
    AND p_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM unnest(p_cles) AS k WHERE n.data->>k = p_id);
$$;

REVOKE ALL ON FUNCTION private.lire_notifications_de_cible(TEXT, TEXT[])
  FROM PUBLIC, anon, authenticated;

-- Un seul corps de déclencheur, paramétré par les clés à comparer
-- (TG_ARGV). Une erreur ici ne doit JAMAIS faire échouer la suppression qui
-- l'a déclenchée : c'est de la tenue de compteur, pas une contrainte.
CREATE OR REPLACE FUNCTION private.trg_notifications_cible_disparue()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM private.lire_notifications_de_cible(
    (to_jsonb(OLD)->>'id'),
    TG_ARGV::TEXT[]
  );
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_notifications_cible_disparue (%): %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_notifications_cible_disparue()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notifications_evenement_supprime ON public.events;
CREATE TRIGGER trg_notifications_evenement_supprime
  AFTER DELETE ON public.events
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_cible_disparue(
    'eventId', 'targetId', 'target_id'
  );

DROP TRIGGER IF EXISTS trg_notifications_publication_supprimee ON public.posts;
CREATE TRIGGER trg_notifications_publication_supprimee
  AFTER DELETE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_cible_disparue(
    'postId', 'targetId', 'target_id'
  );

DROP TRIGGER IF EXISTS trg_notifications_groupe_supprime ON public.groups;
CREATE TRIGGER trg_notifications_groupe_supprime
  AFTER DELETE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_cible_disparue(
    'groupId'
  );

DROP TRIGGER IF EXISTS trg_notifications_conversation_supprimee ON public.conversations;
CREATE TRIGGER trg_notifications_conversation_supprimee
  AFTER DELETE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_cible_disparue(
    'conversationId'
  );

-- Messages : déclencheur PAR INSTRUCTION. Supprimer une conversation efface
-- ses messages en cascade ; un déclencheur par ligne relirait la table
-- `notifications` autant de fois qu'il y a de messages.
CREATE OR REPLACE FUNCTION private.trg_notifications_messages_supprimes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications n
  SET is_read = TRUE
  WHERE NOT n.is_read
    AND n.type IN ('message', 'messageReaction')
    AND n.data->>'messageId' IN (SELECT o.id FROM messages_supprimes o);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_notifications_messages_supprimes: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_notifications_messages_supprimes()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notifications_message_supprime ON public.messages;
CREATE TRIGGER trg_notifications_message_supprime
  AFTER DELETE ON public.messages
  REFERENCING OLD TABLE AS messages_supprimes
  FOR EACH STATEMENT EXECUTE FUNCTION private.trg_notifications_messages_supprimes();

-- Suppression « douce » d'un message (`is_deleted`) : même effet.
CREATE OR REPLACE FUNCTION private.trg_notifications_message_masque()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(NEW.is_deleted, FALSE) AND NOT COALESCE(OLD.is_deleted, FALSE) THEN
    PERFORM private.lire_notifications_de_cible(NEW.id, ARRAY['messageId']);
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_notifications_message_masque: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_notifications_message_masque()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notifications_message_masque ON public.messages;
CREATE TRIGGER trg_notifications_message_masque
  AFTER UPDATE OF is_deleted ON public.messages
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_message_masque();

-- Invitation de groupe acceptée, refusée ou retirée : la notification
-- d'invitation n'appelle plus d'action.
CREATE OR REPLACE FUNCTION private.trg_notifications_invitation_close()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM private.lire_notifications_de_cible(OLD.id::TEXT, ARRAY['inviteId']);
  ELSIF COALESCE(NEW.status, '') <> 'pending' THEN
    PERFORM private.lire_notifications_de_cible(NEW.id::TEXT, ARRAY['inviteId']);
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_notifications_invitation_close: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_notifications_invitation_close()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notifications_invitation_close ON public.group_invites;
CREATE TRIGGER trg_notifications_invitation_close
  AFTER UPDATE OF status OR DELETE ON public.group_invites
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_invitation_close();

-- ── 2. Lire une discussion marque lues ses notifications ────────────────────
-- Corps repris À L'IDENTIQUE de la version déployée (lue dans pg_proc le
-- 2026-09-12, identique à 20260813130000), plus le bloc final. Même
-- signature (TEXT, TEXT) → VOID : OR REPLACE remplace sans surcharge.
--
-- Le bloc final est restreint à l'appelant (`p_user_id = firebase_uid()`) :
-- la RPC accepte n'importe quel participant en `p_user_id`, et on ne veut pas
-- qu'un participant puisse vider le compteur de notifications d'un autre.

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

  -- Ajout 2026-09-12 : la discussion est lue, ses notifications aussi —
  -- messages et réactions (`messageReaction`, 20260912220000).
  IF p_user_id = (SELECT public.firebase_uid()) THEN
    UPDATE notifications
    SET is_read = TRUE
    WHERE user_id = p_user_id
      AND NOT is_read
      AND type IN ('message', 'messageReaction')
      AND data->>'conversationId' = p_conversation_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) TO authenticated;

-- ── 3. Rattrapage ────────────────────────────────────────────────────────────

UPDATE public.notifications n
SET is_read = TRUE
WHERE NOT n.is_read
  AND (
    -- Message déjà lu, masqué, ou disparu.
    (n.type = 'message' AND n.data ? 'messageId' AND (
        NOT EXISTS (SELECT 1 FROM messages m WHERE m.id = n.data->>'messageId')
        OR EXISTS (
          SELECT 1 FROM messages m
          WHERE m.id = n.data->>'messageId'
            AND (COALESCE(m.is_deleted, FALSE)
                 OR COALESCE((m.data->'readBy') ? n.user_id, FALSE))
        )
    ))
    -- Événement disparu.
    OR (n.type IN ('eventAttendance', 'eventReminder', 'eventUpdate', 'localEvent')
        AND NOT EXISTS (
          SELECT 1 FROM events e
          WHERE e.id::TEXT = COALESCE(n.data->>'eventId', n.data->>'targetId', n.data->>'target_id')
        ))
    -- Publication disparue.
    OR (n.data ? 'postId'
        AND NOT EXISTS (SELECT 1 FROM posts p WHERE p.id::TEXT = n.data->>'postId'))
    -- Invitation de groupe plus en attente.
    OR (n.type = 'groupInvite' AND n.data ? 'inviteId'
        AND NOT EXISTS (
          SELECT 1 FROM group_invites gi
          WHERE gi.id::TEXT = n.data->>'inviteId' AND gi.status = 'pending'
        ))
  );
