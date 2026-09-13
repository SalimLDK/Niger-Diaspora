-- =============================================================================
-- Événements : qui peut les voir, vraiment. Sondages : aussi en discussion privée.
--
-- Demandes du 2026-09-12 : « les events créés dedans [une discussion], je ne
-- peux pas choisir qui peut le voir » et « dans le + il manque sondage ».
--
-- ── 1. La visibilité n'existait qu'à l'écran ─────────────────────────────────
--
-- Le formulaire proposait « Publier dans le fil public » (éteint = « visible
-- uniquement par les participants de la conversation »). Mais :
--   - la policy `events_select` rendait lisible TOUT événement non brouillon, à
--     tout le monde, anonymes compris ;
--   - aucune requête de l'app ne filtrait `is_public` (« À venir » lit toute la
--     table).
-- Un événement « privé » créé dans une discussion apparaissait donc chez tout
-- le monde. La promesse de l'interrupteur était fausse.
--
-- Désormais `events.visibility` décide, et la RLS l'applique :
--   public      tout le monde (anonymes compris, comme avant) ;
--   discussion  les participants de la discussion / membres du groupe d'origine ;
--   groups      + les membres des groupes choisis (event_audience.group_id) ;
--   people      + les personnes choisies (event_audience.user_id).
-- Dans tous les cas : l'organisateur, les inscrits, et la discussion d'origine
-- (sa bulle mène à l'événement : la lui cacher casserait le lien).
--
-- `is_public` reste écrit par les clients déjà installés : un trigger dérive
-- `visibility` quand elle n'est pas fournie, et garde `is_public` synchronisé.
-- Un ancien client ne peut donc pas rendre public ce qui ne l'est pas.
--
-- ── 2. Sondages en discussion privée ─────────────────────────────────────────
--
-- Un sondage appartenait à un post OU à un groupe (contrainte
-- `chk_post_polls_single_context`). Il peut maintenant appartenir à une
-- conversation ; lecture, vote et création sont réservés à ses participants.
-- Décision du 2026-07-17 (« groupes uniquement ») levée par Salim le 2026-09-12.
-- =============================================================================


-- ── 1a. Colonne et dérivation ───────────────────────────────────────────────

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS visibility TEXT;

UPDATE public.events
   SET visibility = CASE
         WHEN COALESCE(is_public, FALSE)
              OR (conversation_id IS NULL AND group_id IS NULL) THEN 'public'
         ELSE 'discussion'
       END
 WHERE visibility IS NULL;

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_visibility_check;
ALTER TABLE public.events ADD CONSTRAINT events_visibility_check
  CHECK (visibility IN ('public', 'discussion', 'groups', 'people'));

CREATE OR REPLACE FUNCTION public.events_sync_visibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.visibility IS NULL THEN
      NEW.visibility := CASE
        -- Un événement hors discussion n'a pas d'autre audience possible.
        WHEN NEW.conversation_id IS NULL AND NEW.group_id IS NULL THEN 'public'
        WHEN COALESCE(NEW.is_public, FALSE) THEN 'public'
        ELSE 'discussion'
      END;
    END IF;
  ELSE
    IF NEW.visibility IS NULL THEN
      NEW.visibility := OLD.visibility;
    END IF;
    -- Un client qui ne connaît que `is_public` l'a basculé : on suit, sans
    -- jamais élargir une audience choisie autrement que par ce geste.
    IF NEW.is_public IS DISTINCT FROM OLD.is_public
       AND NEW.visibility IS NOT DISTINCT FROM OLD.visibility THEN
      NEW.visibility := CASE
        WHEN COALESCE(NEW.is_public, FALSE) THEN 'public'
        WHEN OLD.visibility = 'public' THEN
          CASE WHEN NEW.conversation_id IS NULL AND NEW.group_id IS NULL
               THEN 'people' ELSE 'discussion' END
        ELSE OLD.visibility
      END;
    END IF;
  END IF;

  NEW.is_public := NEW.visibility = 'public';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_events_sync_visibility ON public.events;
CREATE TRIGGER trg_events_sync_visibility
  BEFORE INSERT OR UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.events_sync_visibility();

ALTER TABLE public.events ALTER COLUMN visibility SET NOT NULL;


-- ── 1b. Audience choisie ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.event_audience (
  event_id   UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  group_id   UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id    TEXT REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT event_audience_un_seul_type
    CHECK ((group_id IS NOT NULL)::INT + (user_id IS NOT NULL)::INT = 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS event_audience_groupe_uq
  ON public.event_audience (event_id, group_id) WHERE group_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS event_audience_personne_uq
  ON public.event_audience (event_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS event_audience_user_idx
  ON public.event_audience (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS event_audience_group_idx
  ON public.event_audience (group_id) WHERE group_id IS NOT NULL;

ALTER TABLE public.event_audience ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_audience FROM anon;

-- Écritures : uniquement par `set_event_audience` (SECURITY DEFINER), qui
-- vérifie l'organisateur et l'appartenance aux groupes. Aucune policy
-- d'écriture, donc.
DROP POLICY IF EXISTS event_audience_select ON public.event_audience;
CREATE POLICY event_audience_select ON public.event_audience
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT public.firebase_uid())
    OR EXISTS (
      SELECT 1 FROM public.events e
       WHERE e.id = event_audience.event_id
         AND e.organizer_id = (SELECT public.firebase_uid())
    )
  );


-- ── 1c. Qui voit quoi ───────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.can_see_event(p_event_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH moi AS (SELECT public.firebase_uid() AS uid)
  SELECT EXISTS (
    SELECT 1
      FROM events e, moi
     WHERE e.id = p_event_id
       AND (
         e.organizer_id = moi.uid
         -- Le back-office modère tout (policies `events_admin_*` de
         -- 20260912200000) : un UPDATE/DELETE exige aussi de voir la ligne.
         -- Appelé ici, dans une fonction SECURITY DEFINER, plutôt que dans la
         -- policy : `anon` n'a pas à pouvoir exécuter `is_admin()`.
         OR public.is_admin()
         OR (
           e.status <> 'draft'
           AND (
             e.visibility = 'public'
             OR (e.conversation_id IS NOT NULL AND EXISTS (
                   SELECT 1 FROM conversations c
                    WHERE c.id = e.conversation_id
                      AND moi.uid = ANY (c.participant_ids)))
             OR (e.group_id IS NOT NULL AND EXISTS (
                   SELECT 1 FROM group_members gm
                    WHERE gm.group_id = e.group_id AND gm.user_id = moi.uid))
             OR EXISTS (
                   SELECT 1 FROM event_attendees ea
                    WHERE ea.event_id = e.id AND ea.user_id = moi.uid)
             OR (e.visibility = 'people' AND EXISTS (
                   SELECT 1 FROM event_audience a
                    WHERE a.event_id = e.id AND a.user_id = moi.uid))
             OR (e.visibility = 'groups' AND EXISTS (
                   SELECT 1 FROM event_audience a
                     JOIN group_members gm ON gm.group_id = a.group_id
                    WHERE a.event_id = e.id AND gm.user_id = moi.uid))
           )
         )
       )
  );
$$;

-- Appelée depuis une policy : `anon` doit pouvoir l'exécuter, sinon toute
-- lecture anonyme de `events` part en 42501 (6e forme d'échec muet).
REVOKE ALL ON FUNCTION public.can_see_event(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_see_event(UUID) TO anon, authenticated, service_role;

DROP POLICY IF EXISTS events_select ON public.events;
DROP POLICY IF EXISTS events_select_conversation_participants ON public.events;
DROP POLICY IF EXISTS events_select_visible ON public.events;
CREATE POLICY events_select_visible ON public.events
  FOR SELECT
  USING (
    (status <> 'draft' AND visibility = 'public')
    OR organizer_id = (SELECT public.firebase_uid())
    OR public.can_see_event(id)
  );

-- `event_attendees_select` s'appuie sur cette fonction : la liste des inscrits
-- suit désormais la même règle que l'événement.
CREATE OR REPLACE FUNCTION public.is_event_readable(p_event_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.can_see_event(p_event_id);
$$;

-- On ne s'inscrit qu'à un événement qu'on a le droit de voir. S'ajoute en ET à
-- `event_attendees_own` ; ne touche ni la lecture ni la désinscription.
DROP POLICY IF EXISTS event_attendees_insert_visible ON public.event_attendees;
CREATE POLICY event_attendees_insert_visible ON public.event_attendees
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (public.can_see_event(event_id));


-- ── 1d. Choisir l'audience ──────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.set_event_audience(UUID, TEXT, UUID[], TEXT[]);

CREATE FUNCTION public.set_event_audience(
  p_event_id   UUID,
  p_visibility TEXT,
  p_group_ids  UUID[] DEFAULT '{}',
  p_user_ids   TEXT[] DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     TEXT := public.firebase_uid();
  v_event   RECORD;
  v_nom     TEXT;
  v_nouveau TEXT;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'set_event_audience: not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_visibility NOT IN ('public', 'discussion', 'groups', 'people') THEN
    RAISE EXCEPTION 'set_event_audience: invalid visibility' USING ERRCODE = '22023';
  END IF;

  SELECT id, organizer_id, title, status, conversation_id, group_id
    INTO v_event
    FROM events WHERE id = p_event_id;

  IF NOT FOUND OR v_event.organizer_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'set_event_audience: not the organizer' USING ERRCODE = '42501';
  END IF;

  IF p_visibility = 'discussion'
     AND v_event.conversation_id IS NULL AND v_event.group_id IS NULL THEN
    RAISE EXCEPTION 'set_event_audience: no discussion to restrict to'
      USING ERRCODE = '22023';
  END IF;

  -- Groupes : seulement ceux dont l'organisateur est membre.
  DELETE FROM event_audience
   WHERE event_id = p_event_id AND group_id IS NOT NULL
     AND (p_visibility <> 'groups'
          OR NOT (group_id = ANY (COALESCE(p_group_ids, '{}'))));

  IF p_visibility = 'groups' THEN
    INSERT INTO event_audience (event_id, group_id)
    SELECT p_event_id, gm.group_id
      FROM group_members gm
     WHERE gm.user_id = v_uid
       AND gm.group_id = ANY (COALESCE(p_group_ids, '{}'))
    ON CONFLICT (event_id, group_id) WHERE group_id IS NOT NULL DO NOTHING;
  END IF;

  -- Personnes : comptes existants, hors soi-même, 200 au plus.
  DELETE FROM event_audience
   WHERE event_id = p_event_id AND user_id IS NOT NULL
     AND (p_visibility <> 'people'
          OR NOT (user_id = ANY (COALESCE(p_user_ids, '{}'))));

  IF p_visibility = 'people' THEN
    SELECT COALESCE(NULLIF(display_name, ''), 'Quelqu''un') INTO v_nom
      FROM users WHERE id = v_uid;

    FOR v_nouveau IN
      SELECT u.id
        FROM users u
       WHERE u.id = ANY ((COALESCE(p_user_ids, '{}'))[1:200])
         AND u.id <> v_uid
         AND NOT EXISTS (
               SELECT 1 FROM event_audience a
                WHERE a.event_id = p_event_id AND a.user_id = u.id)
    LOOP
      INSERT INTO event_audience (event_id, user_id)
      VALUES (p_event_id, v_nouveau)
      ON CONFLICT (event_id, user_id) WHERE user_id IS NOT NULL DO NOTHING;

      -- Une invitation dont on n'est pas prévenu ne sert à rien : l'événement
      -- n'apparaît dans aucune liste qu'on consulte par hasard.
      IF v_event.status <> 'draft' THEN
        BEGIN
          INSERT INTO notifications (user_id, type, title, body, data, is_read)
          VALUES (
            v_nouveau,
            'eventUpdate',
            'Invitation à un événement',
            COALESCE(v_nom, 'Quelqu''un') || ' vous invite : ' || v_event.title,
            jsonb_build_object(
              'type',     'eventUpdate',
              'eventId',  p_event_id::TEXT,
              'targetId', p_event_id::TEXT,
              'target_id', p_event_id::TEXT,
              'senderId', v_uid,
              'actor_id', v_uid
            ),
            FALSE
          );
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING 'set_event_audience (notification): %', SQLERRM;
        END;
      END IF;
    END LOOP;
  END IF;

  UPDATE events SET visibility = p_visibility WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_event_audience(UUID, TEXT, UUID[], TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_event_audience(UUID, TEXT, UUID[], TEXT[]) TO authenticated;


-- ── 2. Sondages de conversation ─────────────────────────────────────────────

ALTER TABLE public.post_polls
  ADD COLUMN IF NOT EXISTS conversation_id TEXT
  REFERENCES public.conversations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS post_polls_conversation_idx
  ON public.post_polls (conversation_id) WHERE conversation_id IS NOT NULL;

ALTER TABLE public.post_polls DROP CONSTRAINT IF EXISTS chk_post_polls_single_context;
ALTER TABLE public.post_polls ADD CONSTRAINT chk_post_polls_single_context
  CHECK (
    (post_id IS NOT NULL)::INT
    + (group_id IS NOT NULL)::INT
    + (conversation_id IS NOT NULL)::INT = 1
  );

CREATE OR REPLACE FUNCTION public.is_conversation_participant(p_conversation_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM conversations c
     WHERE c.id = p_conversation_id
       AND public.firebase_uid() = ANY (c.participant_ids)
  );
$$;

REVOKE ALL ON FUNCTION public.is_conversation_participant(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_conversation_participant(TEXT) TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "Conversation participants can create polls" ON public.post_polls;
CREATE POLICY "Conversation participants can create polls" ON public.post_polls
  FOR INSERT TO authenticated
  WITH CHECK (
    conversation_id IS NOT NULL
    AND created_by = (SELECT public.firebase_uid())
    AND public.is_conversation_participant(conversation_id)
  );

DROP POLICY IF EXISTS "Conversation polls are readable by participants" ON public.post_polls;
CREATE POLICY "Conversation polls are readable by participants" ON public.post_polls
  FOR SELECT TO authenticated
  USING (
    conversation_id IS NOT NULL
    AND public.is_conversation_participant(conversation_id)
  );

DROP POLICY IF EXISTS "Conversation poll creators can delete" ON public.post_polls;
CREATE POLICY "Conversation poll creators can delete" ON public.post_polls
  FOR DELETE TO authenticated
  USING (
    conversation_id IS NOT NULL
    AND created_by = (SELECT public.firebase_uid())
  );

-- Options : le créateur d'un sondage de conversation peut les ajouter, comme
-- celui d'un sondage de groupe (sans quoi la 2e écriture part en 42501 — le
-- défaut déjà payé le 2026-08-23).
DROP POLICY IF EXISTS "Poll owners can add options" ON public.post_poll_options;
CREATE POLICY "Poll owners can add options" ON public.post_poll_options
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.post_polls p
       WHERE p.id = post_poll_options.poll_id
         AND (
           ((p.group_id IS NOT NULL OR p.conversation_id IS NOT NULL)
             AND p.created_by = (SELECT public.firebase_uid()))
           OR (p.post_id IS NOT NULL
             AND (SELECT posts.author_id FROM public.posts WHERE posts.id = p.post_id)
                 = (SELECT public.firebase_uid()))
         )
    )
  );

DROP POLICY IF EXISTS "Users can vote once per poll" ON public.post_poll_votes;
CREATE POLICY "Users can vote once per poll" ON public.post_poll_votes
  FOR INSERT
  WITH CHECK (
    (SELECT public.firebase_uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.post_polls p
       WHERE p.id = post_poll_votes.poll_id
         AND (
           p.post_id IS NOT NULL
           OR EXISTS (
                SELECT 1 FROM public.group_members gm
                 WHERE gm.group_id = p.group_id
                   AND gm.user_id = (SELECT public.firebase_uid()))
           OR (p.conversation_id IS NOT NULL
               AND public.is_conversation_participant(p.conversation_id))
         )
    )
  );
