-- =============================================================================
-- Sondages : rendre la creation possible, et les compteurs de votes vivants
--
-- 1. `post_poll_options` a RLS active mais AUCUNE politique INSERT. La creation
--    d'un sondage insere la question dans `post_polls`, puis ses options dans
--    `post_poll_options` -- et cette seconde ecriture est refusee 42501 pour
--    tout le monde. Cote app : « Impossible de creer le sondage », et une
--    question orpheline sans aucune option reste en base (6 en production au
--    2026-08-23, toutes sans option -- la signature exacte du defaut).
--
-- 2. Meme famille : `increment_poll_vote_count` / `decrement_poll_vote_count`
--    ne sont pas SECURITY DEFINER. Leur UPDATE sur `post_poll_options` et
--    `post_polls` est donc soumis au RLS de l'appelant, qui n'a aucune
--    politique UPDATE sur ces deux tables : l'UPDATE ne touche 0 ligne, sans
--    lever d'erreur. Le vote est bien enregistre, les compteurs restent a 0.
--    On passe les fonctions en SECURITY DEFINER plutot que d'ouvrir un UPDATE
--    au client : personne ne doit pouvoir forger vote_count / total_votes.
--
-- Les deux tables et les deux fonctions appartiennent a `postgres`, et
-- `relforcerowsecurity` est false : le proprietaire contourne bien le RLS.
-- =============================================================================

-- 1. Poser les options du sondage qu'on vient de creer -----------------------
--    Miroir exact des deux chemins d'INSERT de `post_polls` :
--      - sondage de groupe : c'est le createur (`created_by`) ;
--      - sondage de post   : c'est l'auteur du post.
DROP POLICY IF EXISTS "Poll owners can add options" ON post_poll_options;
CREATE POLICY "Poll owners can add options" ON post_poll_options
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (EXISTS (
    SELECT 1
      FROM post_polls p
     WHERE p.id = post_poll_options.poll_id
       AND (
         (p.group_id IS NOT NULL AND p.created_by = (SELECT firebase_uid()))
         OR
         (p.post_id IS NOT NULL AND (SELECT posts.author_id
                                       FROM posts
                                      WHERE posts.id = p.post_id) = (SELECT firebase_uid()))
       )
  ));

-- 2. Comptage des votes ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_poll_vote_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  UPDATE post_poll_options
     SET vote_count = vote_count + 1
   WHERE id = NEW.option_id;

  UPDATE post_polls
     SET total_votes = total_votes + 1
   WHERE id = NEW.poll_id;

  RETURN NEW;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.decrement_poll_vote_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  UPDATE post_poll_options
     SET vote_count = GREATEST(vote_count - 1, 0)
   WHERE id = OLD.option_id;

  UPDATE post_polls
     SET total_votes = GREATEST(total_votes - 1, 0)
   WHERE id = OLD.poll_id;

  RETURN OLD;
END;
$fn$;
