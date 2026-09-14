-- =============================================================================
-- Audience des publications et des stories : amis, abonnés, listes.
--
-- Signalé le 2026-09-12 :
--   * « les publications à uniquement Public, il manque les autres » ;
--   * « Ma story est incomplète : je ne peux pas dire qui peut la voir, bannir
--     (une sorte de blacklist et de whitelist), elle ne disparaît pas après
--     24 h » ;
--   * « il y a les amis (friends) et les followers, une distinction à prendre
--     en compte ».
--
-- ## Ce que la base savait déjà, et ce qui manquait
--
-- `posts.visibility` et la policy `posts_select` connaissaient `public` et
-- `friends` depuis le schéma initial — l'app écrivait `public` en dur. Mais
-- la clause « amis » lisait `public.friends`, **vide** : les amitiés vivent
-- dans Firestore (`users/{uid}/friends/{friendId}`, 6 documents le
-- 2026-09-12). Une publication « Amis » aurait été invisible pour tout le
-- monde. Les abonnements, eux, sont bien dans `public.user_follows`.
--
-- Côté stories, `stories_manage_own` (FOR ALL) accordait aussi la LECTURE à
-- l'auteur sans la borne des 24 h de `stories_select` : l'auteur voyait sa
-- story indéfiniment — c'est le « ne disparaît pas après 24 h » (la seule
-- story en base date du 3 août et s'affiche toujours à son auteur).
-- `stories_select` était par ailleurs ouverte à `anon`.
--
-- ## Ce que ce fichier pose
--
-- 1. Reprise des 6 amitiés Firestore dans `public.friends`. La suite est
--    tenue par la Cloud Function `mirrorFriendToSupabase` (functions/index.js).
-- 2. Deux relations, un seul arbitre :
--      ami     = l'AUTEUR a la personne dans SES amis (friends.user_id = auteur)
--      abonné  = la personne suit l'auteur (user_follows)
--    L'auteur décide de qui sont ses amis ; une amitié à sens unique restée
--    chez l'autre ne donne rien.
-- 3. Publications : `public` | `followers` (abonnés ET amis) | `friends` |
--    `private` (moi uniquement). `posts_select` passe par
--    `peut_voir_publication`. Les mentions et les membres de groupes cités ne
--    sont prévenus que s'ils peuvent lire la publication.
-- 4. Stories : `public` | `followers` | `friends` | `close` (liste restreinte,
--    la « whitelist »), plus une liste `hidden` (la « blacklist ») qui prime
--    sur tout, plus les blocages dans les deux sens. 24 h pour tout le monde,
--    auteur compris. Vues et réactions exigent de pouvoir voir la story.
--
-- Les fonctions publiques ne prennent PAS le spectateur en paramètre : elles
-- lisent `firebase_uid()`. Sinon n'importe qui pourrait demander « B est-il
-- ami de A ? » par RPC. Les variantes qui acceptent un tiers vivent dans
-- `private`, sans droit d'exécution.
-- =============================================================================

-- ── 1. Reprise des amitiés Firestore ────────────────────────────────────────
-- Lu le 2026-09-12 par l'API REST Firestore (collection group `friends`) :
--   DfSyAWi… → U64HKfr…    U64HKfr… → DfSyAWi…
--   U64HKfr… → DgHD6gu…    U64HKfr… → vQZE49d…
--   U64HKfr… → zr1SjYS…    vQZE49d… → U64HKfr…
-- Les cinq comptes existent dans public.users (vérifié le même jour).

INSERT INTO public.friends (user_id, friend_id, friend_name, friend_photo_url)
SELECT v.user_id, v.friend_id, u.display_name, u.avatar_url
FROM (VALUES
  ('DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'U64HKfrjM5NwR6HO00XPKo6168z2'),
  ('U64HKfrjM5NwR6HO00XPKo6168z2', 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2'),
  ('U64HKfrjM5NwR6HO00XPKo6168z2', 'DgHD6guYAwVepbUmIAt9P2mJeQ52'),
  ('U64HKfrjM5NwR6HO00XPKo6168z2', 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'),
  ('U64HKfrjM5NwR6HO00XPKo6168z2', 'zr1SjYSQhLWMb7rXrFJI6bCBuRF2'),
  ('vQZE49dTdyRtLwSG6lMIbhAqoFG2', 'U64HKfrjM5NwR6HO00XPKo6168z2')
) AS v(user_id, friend_id)
JOIN public.users u ON u.id = v.friend_id
WHERE EXISTS (SELECT 1 FROM public.users w WHERE w.id = v.user_id)
ON CONFLICT (user_id, friend_id) DO NOTHING;

-- ── 2. Relations ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION private.est_ami_de(p_author TEXT, p_viewer TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM friends f
    WHERE f.user_id = p_author AND f.friend_id = p_viewer
  );
$$;

CREATE OR REPLACE FUNCTION private.est_abonne_de(p_author TEXT, p_viewer TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_follows uf
    WHERE uf.following_id = p_author AND uf.follower_id = p_viewer
  );
$$;

REVOKE ALL ON FUNCTION private.est_ami_de(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.est_abonne_de(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- ── 3. Publications ──────────────────────────────────────────────────────────

ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_visibility_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_visibility_check
  CHECK (visibility IN ('public', 'followers', 'friends', 'private'));

CREATE OR REPLACE FUNCTION private.peut_voir_publication_pour(
  p_author     TEXT,
  p_visibility TEXT,
  p_viewer     TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN COALESCE(p_visibility, 'public') = 'public' THEN TRUE
    WHEN p_viewer IS NULL OR p_viewer = '' THEN FALSE
    WHEN p_viewer = p_author THEN TRUE
    WHEN p_visibility = 'friends' THEN private.est_ami_de(p_author, p_viewer)
    WHEN p_visibility = 'followers' THEN
      private.est_ami_de(p_author, p_viewer)
      OR private.est_abonne_de(p_author, p_viewer)
    ELSE FALSE
  END;
$$;

REVOKE ALL ON FUNCTION private.peut_voir_publication_pour(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

-- Variante appelée par la policy : le spectateur est l'appelant, rien d'autre.
-- `anon` garde l'exécution : sans elle, la lecture anonyme des publications
-- publiques (page de partage web) lèverait « permission denied » au lieu de
-- rendre les lignes publiques.
CREATE OR REPLACE FUNCTION public.peut_voir_publication(
  p_author     TEXT,
  p_visibility TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT private.peut_voir_publication_pour(
    p_author, p_visibility, (SELECT public.firebase_uid())
  );
$$;

REVOKE ALL ON FUNCTION public.peut_voir_publication(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.peut_voir_publication(TEXT, TEXT) TO anon, authenticated;

DROP POLICY IF EXISTS posts_select ON public.posts;
CREATE POLICY posts_select ON public.posts
  FOR SELECT
  USING (public.peut_voir_publication(author_id, visibility));

-- Notifications de nouvelle publication : corps repris de la version déployée
-- (lue dans pg_proc le 2026-09-12), trois changements marqués « 2026-09-12 ».
CREATE OR REPLACE FUNCTION public.notify_on_post_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_name TEXT;
  v_preview     TEXT;
  v_public      BOOLEAN;
  v_seen        TEXT[] := ARRAY[NEW.author_id];
  v_uid         TEXT;
  v_mention     JSONB;
  v_group       JSONB;
BEGIN
  IF NEW.author_id IS NULL OR NEW.author_id = '' THEN
    RETURN NEW;
  END IF;

  v_author_name := COALESCE(
    NULLIF(NEW.author_name, ''),
    (SELECT display_name FROM users WHERE id = NEW.author_id),
    'Quelqu''un'
  );

  v_preview := CASE
    WHEN length(COALESCE(NEW.content, '')) > 60
      THEN left(NEW.content, 60) || '…'
    ELSE COALESCE(NULLIF(NEW.content, ''), 'Nouvelle publication')
  END;

  -- 2026-09-12 : une publication « Abonnés » est aussi annoncée aux abonnés.
  v_public := NEW.group_id IS NULL
          AND COALESCE(NEW.visibility, 'public') IN ('public', 'followers');

  -- 1) Abonnés — seulement si la publication leur est destinée.
  IF v_public THEN
    FOR v_uid IN
      SELECT f.follower_id
      FROM user_follows f
      WHERE f.following_id = NEW.author_id
        AND f.follower_id IS NOT NULL
        AND f.follower_id <> ''
        AND f.follower_id <> NEW.author_id
      LIMIT 500
    LOOP
      IF NOT (v_uid = ANY (v_seen)) THEN
        v_seen := v_seen || v_uid;
        INSERT INTO notifications (user_id, type, title, body, data, is_read)
        VALUES (
          v_uid, 'new_post', v_author_name, v_preview,
          jsonb_build_object(
            'postId', NEW.id, 'authorId', NEW.author_id,
            'targetId', NEW.id, 'target_id', NEW.id
          ),
          FALSE
        );
      END IF;
    END LOOP;
  END IF;

  -- 2) Personnes mentionnées.
  FOR v_mention IN
    SELECT jsonb_array_elements(COALESCE(NEW.mentioned_users, '[]'::jsonb))
  LOOP
    v_uid := v_mention->>'id';
    CONTINUE WHEN v_uid IS NULL OR v_uid = '' OR v_uid = ANY (v_seen);
    -- 2026-09-12 : pas de notification vers une publication illisible.
    CONTINUE WHEN NOT private.peut_voir_publication_pour(
      NEW.author_id, NEW.visibility, v_uid
    );
    v_seen := v_seen || v_uid;
    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (
      v_uid, 'mentioned', 'Vous avez été mentionné(e)',
      v_author_name || ' vous a mentionné(e) dans une publication',
      jsonb_build_object(
        'postId', NEW.id, 'authorId', NEW.author_id,
        'targetId', NEW.id, 'target_id', NEW.id
      ),
      FALSE
    );
  END LOOP;

  -- 3) Membres des groupes cités.
  FOR v_group IN
    SELECT jsonb_array_elements(COALESCE(NEW.mentioned_groups, '[]'::jsonb))
  LOOP
    FOR v_uid IN
      SELECT jsonb_array_elements_text(COALESCE(v_group->'memberIds', '[]'::jsonb))
    LOOP
      CONTINUE WHEN v_uid IS NULL OR v_uid = '' OR v_uid = ANY (v_seen);
      -- 2026-09-12 : idem pour les membres de groupe.
      CONTINUE WHEN NOT private.peut_voir_publication_pour(
        NEW.author_id, NEW.visibility, v_uid
      );
      v_seen := v_seen || v_uid;
      INSERT INTO notifications (user_id, type, title, body, data, is_read)
      VALUES (
        v_uid, 'group_mention',
        COALESCE(NULLIF(v_group->>'name', ''), 'Votre groupe') || ' a été mentionné',
        v_author_name || ' a mentionné '
          || COALESCE(NULLIF(v_group->>'name', ''), 'votre groupe')
          || ' dans une publication',
        jsonb_build_object(
          'postId', NEW.id, 'authorId', NEW.author_id, 'groupId', v_group->>'id',
          'targetId', NEW.id, 'target_id', NEW.id
        ),
        FALSE
      );
    END LOOP;
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais faire échouer la publication à cause d'une notification.
    RAISE WARNING 'notify_on_post_insert: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ── 4. Stories ───────────────────────────────────────────────────────────────

ALTER TABLE public.stories
  ADD COLUMN IF NOT EXISTS audience TEXT NOT NULL DEFAULT 'public';
ALTER TABLE public.stories DROP CONSTRAINT IF EXISTS stories_audience_check;
ALTER TABLE public.stories ADD CONSTRAINT stories_audience_check
  CHECK (audience IN ('public', 'followers', 'friends', 'close'));

-- Listes de l'auteur. Une personne est dans UNE liste au plus (clé
-- (owner, member)) : la mettre en « masqué » la retire de « restreinte ».
CREATE TABLE IF NOT EXISTS public.story_audience_members (
  owner_id   TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  member_id  TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  list       TEXT NOT NULL CHECK (list IN ('close', 'hidden')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, member_id),
  CHECK (owner_id <> member_id)
);

CREATE INDEX IF NOT EXISTS story_audience_members_member_idx
  ON public.story_audience_members (member_id);

ALTER TABLE public.story_audience_members ENABLE ROW LEVEL SECURITY;

-- Seul l'auteur lit et écrit ses listes : une personne masquée n'a pas à
-- savoir qu'elle l'est.
DROP POLICY IF EXISTS story_audience_members_own ON public.story_audience_members;
CREATE POLICY story_audience_members_own ON public.story_audience_members
  FOR ALL TO authenticated
  USING (owner_id = (SELECT public.firebase_uid()))
  WITH CHECK (owner_id = (SELECT public.firebase_uid()));

REVOKE ALL ON public.story_audience_members FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.story_audience_members TO authenticated;

CREATE OR REPLACE FUNCTION private.peut_voir_story_pour(
  p_author   TEXT,
  p_audience TEXT,
  p_viewer   TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_viewer IS NULL OR p_viewer = '' THEN FALSE
    WHEN p_viewer = p_author THEN TRUE
    -- La liste « masqué » prime sur tout, y compris sur l'audience publique.
    WHEN EXISTS (
      SELECT 1 FROM story_audience_members m
      WHERE m.owner_id = p_author AND m.member_id = p_viewer AND m.list = 'hidden'
    ) THEN FALSE
    WHEN EXISTS (
      SELECT 1 FROM blocked_users b
      WHERE (b.blocker_id = p_author AND b.blocked_id = p_viewer)
         OR (b.blocker_id = p_viewer AND b.blocked_id = p_author)
    ) THEN FALSE
    WHEN COALESCE(p_audience, 'public') = 'public' THEN TRUE
    WHEN p_audience = 'friends' THEN private.est_ami_de(p_author, p_viewer)
    WHEN p_audience = 'followers' THEN
      private.est_ami_de(p_author, p_viewer)
      OR private.est_abonne_de(p_author, p_viewer)
    WHEN p_audience = 'close' THEN EXISTS (
      SELECT 1 FROM story_audience_members m
      WHERE m.owner_id = p_author AND m.member_id = p_viewer AND m.list = 'close'
    )
    ELSE FALSE
  END;
$$;

REVOKE ALL ON FUNCTION private.peut_voir_story_pour(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.peut_voir_story(p_author TEXT, p_audience TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT private.peut_voir_story_pour(
    p_author, p_audience, (SELECT public.firebase_uid())
  );
$$;

REVOKE ALL ON FUNCTION public.peut_voir_story(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.peut_voir_story(TEXT, TEXT) TO authenticated;

-- Lecture : 24 h pour TOUT le monde, auteur compris, et audience respectée.
-- Écriture : l'auteur, séparément — `stories_manage_own` (FOR ALL) accordait
-- aussi la lecture hors des 24 h.
DROP POLICY IF EXISTS stories_manage_own ON public.stories;
DROP POLICY IF EXISTS stories_select ON public.stories;
DROP POLICY IF EXISTS stories_insert_own ON public.stories;
DROP POLICY IF EXISTS stories_update_own ON public.stories;
DROP POLICY IF EXISTS stories_delete_own ON public.stories;

CREATE POLICY stories_select ON public.stories
  FOR SELECT TO authenticated
  USING (
    created_at > now() - INTERVAL '24 hours'
    AND public.peut_voir_story(author_id, audience)
  );

CREATE POLICY stories_insert_own ON public.stories
  FOR INSERT TO authenticated
  WITH CHECK (author_id = (SELECT public.firebase_uid()));

CREATE POLICY stories_update_own ON public.stories
  FOR UPDATE TO authenticated
  USING (author_id = (SELECT public.firebase_uid()))
  WITH CHECK (author_id = (SELECT public.firebase_uid()));

CREATE POLICY stories_delete_own ON public.stories
  FOR DELETE TO authenticated
  USING (author_id = (SELECT public.firebase_uid()));

REVOKE ALL ON public.stories FROM anon;

-- Vues et réactions : seulement sur une story qu'on peut voir. Le sous-select
-- passe par la RLS de `stories` ci-dessus.
DROP POLICY IF EXISTS story_views_insert_own ON public.story_views;
CREATE POLICY story_views_insert_own ON public.story_views
  FOR INSERT TO authenticated
  WITH CHECK (
    viewer_id = (SELECT public.firebase_uid())
    AND EXISTS (SELECT 1 FROM public.stories s WHERE s.id = story_views.story_id)
  );

DROP POLICY IF EXISTS story_reactions_manage_own ON public.story_reactions;
CREATE POLICY story_reactions_manage_own ON public.story_reactions
  FOR ALL TO authenticated
  USING (user_id = (SELECT public.firebase_uid()))
  WITH CHECK (
    user_id = (SELECT public.firebase_uid())
    AND EXISTS (SELECT 1 FROM public.stories s WHERE s.id = story_reactions.story_id)
  );
