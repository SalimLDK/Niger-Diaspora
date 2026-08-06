-- =============================================================================
-- posts INSERT → notifications : abonnés, personnes mentionnées, groupes cités.
--
-- Ces trois notifications venaient de la Cloud Function Firestore
-- `onNewPostCreated`, qui écoutait `posts/{postId}`. Le fil est passé à
-- Supabase : elle ne se déclenche plus, et personne n'est prévenu qu'une
-- publication est parue.
--
-- ⚠️ NE PAS ajouter ici les « j'aime », commentaires, réponses et repartages :
-- l'app les crée déjà côté client via la RPC `create_user_notification`
-- (`feed_provider.dart` — types `postLiked`, `postCommented`, `commentReply`,
-- `postReposted`). Un trigger ferait doublon. C'est exactement la mise en garde
-- laissée dans `functions/index.js` à la suppression de `onCommentMention`.
--
-- Deux écarts assumés par rapport à la fonction Firestore d'origine :
--
--  1. **Pas de diffusion aux abonnés pour une publication de groupe ou non
--     publique.** L'originale notifiait tous les abonnés quoi qu'il arrive, en
--     mettant l'aperçu du contenu dans le corps de la notification — donc en
--     recopiant le texte d'un post de groupe privé à des gens qui n'y ont pas
--     accès. Les mentions, elles, restent envoyées : elles sont explicites.
--  2. **Un destinataire n'est notifié qu'une fois** par publication. L'originale
--     empilait trois notifications pour qui était à la fois abonné, mentionné
--     et membre d'un groupe cité.
--
-- Plafond de 500 abonnés, comme l'originale : chaque ligne déclenche
-- `trg_notify_push`, donc un appel pg_net.
-- =============================================================================

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

  v_public := NEW.group_id IS NULL
          AND COALESCE(NEW.visibility, 'public') = 'public';

  -- 1) Abonnés — seulement si la publication est réellement publique.
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

DROP TRIGGER IF EXISTS trg_notify_on_post_insert ON public.posts;
CREATE TRIGGER trg_notify_on_post_insert
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_post_insert();

COMMENT ON FUNCTION public.notify_on_post_insert() IS
  'Après INSERT posts : notifie abonnés (publications publiques seulement), '
  'personnes mentionnées et membres des groupes cités. Un destinataire n''est '
  'notifié qu''une fois. Les j''aime/commentaires sont créés côté app.';

REVOKE ALL ON FUNCTION public.notify_on_post_insert() FROM PUBLIC;
