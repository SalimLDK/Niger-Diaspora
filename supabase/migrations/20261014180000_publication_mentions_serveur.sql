-- Les notifications d'une publication ne reprennent plus rien du client.
--
-- Audit des notifications du 2026-10-14, constat n° 2. `notify_on_post_insert`
-- lisait dans la ligne `posts` — que l'auteur écrit EN ENTIER — :
--
-- · `author_name`, préféré au nom du profil ;
-- · `mentioned_groups[].name`, repris tel quel dans le titre et le corps ;
-- · `mentioned_groups[].memberIds`, la liste des destinataires.
--
-- Le seul filtre était « le destinataire peut-il voir la publication », vrai
-- pour toute publication publique. Une publication suffisait donc à pousser
-- « Sécurité Diaspo : vérifiez votre compte sur evil.tld » à tous les comptes
-- de la base (les identifiants se listent par `users`), puis à l'effacer : les
-- push étaient partis. Aucun plafond, aucun blocage, aucun quota.
--
-- Désormais :
--
-- · le nom de l'auteur vient de `users.display_name`, seulement ;
-- · un groupe cité est relu dans `groups` : son nom est celui du serveur, ses
--   destinataires sont `group_members`, et seulement si l'AUTEUR EN EST MEMBRE
--   — citer un groupe dont on n'est pas ne prévient personne (la publication
--   le montre toujours) ;
-- · un « groupe pays » (`country_<Pays>`, l'écran des mentions) est relu de
--   même : les 50 profils visibles de ce pays, comme le client les
--   proposait, et seulement pour les pays que l'écran connaît ;
-- · au plus 3 groupes et 200 destinataires de groupe par publication, au plus
--   20 personnes mentionnées ;
-- · au plus 5 publications citant un groupe par heure et par auteur : au-delà,
--   la publication passe, sans notification de groupe ;
-- · personne n'est prévenu par un auteur qu'il a bloqué.
--
-- Banc : tools/rls_tests/publication_mentions_serveur.sql

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
  v_group_id    TEXT;
  v_group_name  TEXT;
  v_pays        TEXT;
  v_groupes     INT := 0;
  v_par_groupe  INT := 0;
  v_recentes    INT;
BEGIN
  IF NEW.author_id IS NULL OR NEW.author_id = '' THEN
    RETURN NEW;
  END IF;

  -- 2026-10-14 : le nom du profil, jamais celui écrit dans la publication.
  v_author_name := COALESCE(
    NULLIF((SELECT display_name FROM users WHERE id = NEW.author_id), ''),
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
        AND NOT EXISTS (SELECT 1 FROM blocked_users b
                         WHERE b.blocker_id = f.follower_id
                           AND b.blocked_id = NEW.author_id)
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

  -- 2) Personnes mentionnées — 20 au plus.
  FOR v_mention IN
    SELECT m FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(NEW.mentioned_users) = 'array'
           THEN NEW.mentioned_users ELSE '[]'::jsonb END) m
    LIMIT 20
  LOOP
    v_uid := v_mention->>'id';
    CONTINUE WHEN v_uid IS NULL OR v_uid = '' OR v_uid = ANY (v_seen);
    -- 2026-09-12 : pas de notification vers une publication illisible.
    CONTINUE WHEN NOT private.peut_voir_publication_pour(
      NEW.author_id, NEW.visibility, v_uid
    );
    CONTINUE WHEN EXISTS (SELECT 1 FROM blocked_users b
                           WHERE b.blocker_id = v_uid AND b.blocked_id = NEW.author_id);
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

  -- 3) Membres des groupes cités — relus côté serveur.
  IF jsonb_typeof(NEW.mentioned_groups) = 'array'
     AND jsonb_array_length(NEW.mentioned_groups) > 0 THEN
    SELECT count(*) INTO v_recentes
      FROM posts p
     WHERE p.author_id = NEW.author_id
       AND p.id <> NEW.id
       AND p.created_at > now() - interval '1 hour'
       AND jsonb_typeof(p.mentioned_groups) = 'array'
       AND jsonb_array_length(p.mentioned_groups) > 0;

    IF v_recentes < 5 THEN
      FOR v_group IN
        SELECT g FROM jsonb_array_elements(NEW.mentioned_groups) g
      LOOP
        EXIT WHEN v_groupes >= 3;
        v_group_id := v_group->>'id';
        CONTINUE WHEN v_group_id IS NULL OR v_group_id = '';
        v_group_name := NULL;
        v_pays := NULL;

        IF v_group_id LIKE 'country\_%' THEN
          -- Les clés de `_knownCountries` (mention_text_field.dart) et le pays
          -- tel que `users.country_code` l'écrit, en toutes lettres.
          SELECT p.pays INTO v_pays
            FROM (VALUES ('Niger', 'Niger'), ('France', 'France'),
                         ('Algerie', 'Algérie'), ('Maroc', 'Maroc'),
                         ('Mali', 'Mali'), ('Burkina', 'Burkina Faso'),
                         ('BurkinaFaso', 'Burkina Faso'), ('Nigeria', 'Nigeria'),
                         ('Senegal', 'Sénégal'), ('Canada', 'Canada'),
                         ('USA', 'USA'), ('Allemagne', 'Allemagne'),
                         ('Belgique', 'Belgique'), ('Italie', 'Italie'),
                         ('Espagne', 'Espagne')) AS p(cle, pays)
           WHERE p.cle = substr(v_group_id, 9);
          CONTINUE WHEN v_pays IS NULL;
          v_group_name := 'Amis · ' || v_pays;
        ELSE
          SELECT g.name INTO v_group_name
            FROM groups g
           WHERE g.id::text = v_group_id
             AND EXISTS (SELECT 1 FROM group_members gm
                          WHERE gm.group_id = g.id AND gm.user_id = NEW.author_id);
          CONTINUE WHEN v_group_name IS NULL;
        END IF;
        v_groupes := v_groupes + 1;

        FOR v_uid IN
          SELECT gm.user_id FROM group_members gm
           WHERE v_pays IS NULL AND gm.group_id::text = v_group_id
          UNION ALL
          (SELECT u.id FROM users u
            WHERE v_pays IS NOT NULL
              AND u.country_code = v_pays
              AND u.is_visible IS TRUE
            ORDER BY u.last_active_at DESC NULLS LAST
            LIMIT 50)
        LOOP
          EXIT WHEN v_par_groupe >= 200;
          CONTINUE WHEN v_uid IS NULL OR v_uid = '' OR v_uid = ANY (v_seen);
          -- 2026-09-12 : idem pour les membres de groupe.
          CONTINUE WHEN NOT private.peut_voir_publication_pour(
            NEW.author_id, NEW.visibility, v_uid
          );
          CONTINUE WHEN EXISTS (SELECT 1 FROM blocked_users b
                                 WHERE b.blocker_id = v_uid AND b.blocked_id = NEW.author_id);
          v_seen := v_seen || v_uid;
          v_par_groupe := v_par_groupe + 1;
          INSERT INTO notifications (user_id, type, title, body, data, is_read)
          VALUES (
            v_uid, 'group_mention',
            v_group_name || ' a été mentionné',
            v_author_name || ' a mentionné ' || v_group_name || ' dans une publication',
            jsonb_build_object(
              'postId', NEW.id, 'authorId', NEW.author_id, 'groupId', v_group_id,
              'targetId', NEW.id, 'target_id', NEW.id
            ),
            FALSE
          );
        END LOOP;
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais faire échouer la publication à cause d'une notification.
    RAISE WARNING 'notify_on_post_insert: %', SQLERRM;
    RETURN NEW;
END;
$$;
