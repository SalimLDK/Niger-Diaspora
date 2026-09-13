-- =============================================================================
-- Compteurs des publications : tenus par la base, et commentaires lisibles.
--
-- Signalé le 2026-09-12 : « erreur sur le nombre de commentaires et de
-- repartages » sur le fil. Deux défauts distincts.
--
-- 1) LES COMMENTAIRES DES AUTRES ÉTAIENT ILLISIBLES.
--    `post_comments` n'avait qu'une policy, `post_comments_manage_own`
--    (FOR ALL, author_id = soi) : chacun ne lisait que SES commentaires. Le
--    compteur disait 2, le détail en montrait 1 (ou 0). Mesuré sur la seule
--    publication de la base : comment_count = 2, deux lignes, dont une
--    seulement lisible par chacun des deux auteurs.
--    → une policy SELECT : un commentaire se lit dès que sa publication se lit.
--    Le sous-select sur `posts` passe par la RLS de `posts` (appelant) : un
--    commentaire d'une publication « amis » ou « moi uniquement » ne fuit pas.
--
-- 2) LES COMPTEURS N'ÉTAIENT TENUS QUE PAR LE CLIENT.
--    `increment_post_*` / `decrement_post_*` étaient appelés par l'app APRÈS
--    l'écriture, en deux requêtes : si la seconde échoue, le compteur diverge
--    pour toujours. Et ces RPC étaient exécutables par `anon` (droits par
--    défaut du projet, cf 20260813130000) : n'importe qui pouvait gonfler
--    n'importe quel compteur sans rien écrire.
--    → des déclencheurs recomptent à partir des lignes réelles. Les RPC gardent
--    leur signature — les versions installées de l'app les appellent encore —
--    mais recomptent au lieu d'ajouter : un appel en double ne compte plus
--    double. `anon` perd l'exécution.
-- =============================================================================

-- ── 1. Lecture des commentaires ──────────────────────────────────────────────

DROP POLICY IF EXISTS post_comments_select_visible ON public.post_comments;
CREATE POLICY post_comments_select_visible ON public.post_comments
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_comments.post_id)
  );

-- ── 2. Recomptage ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION private.recompter_publication(p_post_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE posts p
  SET like_count    = c.likes,
      comment_count = c.commentaires,
      share_count   = c.repartages
  FROM (
    SELECT
      (SELECT count(*) FROM post_likes    WHERE post_id = p_post_id)::int AS likes,
      (SELECT count(*) FROM post_comments WHERE post_id = p_post_id)::int AS commentaires,
      (SELECT count(*) FROM post_reposts  WHERE post_id = p_post_id)::int AS repartages
  ) c
  WHERE p.id = p_post_id
    -- Ne réécrire que si ça change : `posts_updated_at` pose `updated_at` à
    -- chaque UPDATE, inutile de le bouger pour rien.
    AND (p.like_count, p.comment_count, p.share_count)
        IS DISTINCT FROM (c.likes, c.commentaires, c.repartages);
$$;

CREATE OR REPLACE FUNCTION private.recompter_commentaire(p_comment_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE post_comments pc
  SET like_count = c.n
  FROM (
    SELECT count(*)::int AS n FROM post_comment_likes WHERE comment_id = p_comment_id
  ) c
  WHERE pc.id = p_comment_id
    AND pc.like_count IS DISTINCT FROM c.n;
$$;

REVOKE ALL ON FUNCTION private.recompter_publication(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.recompter_commentaire(UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_recompter_publication()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM private.recompter_publication(NEW.post_id);
  END IF;
  IF TG_OP IN ('DELETE', 'UPDATE') THEN
    IF TG_OP = 'DELETE' OR OLD.post_id IS DISTINCT FROM NEW.post_id THEN
      PERFORM private.recompter_publication(OLD.post_id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION private.trg_recompter_commentaire()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM private.recompter_commentaire(
    CASE WHEN TG_OP = 'DELETE' THEN OLD.comment_id ELSE NEW.comment_id END
  );
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_recompter_publication() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.trg_recompter_commentaire() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_compteur_likes ON public.post_likes;
CREATE TRIGGER trg_compteur_likes
  AFTER INSERT OR DELETE OR UPDATE OF post_id ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION private.trg_recompter_publication();

DROP TRIGGER IF EXISTS trg_compteur_commentaires ON public.post_comments;
CREATE TRIGGER trg_compteur_commentaires
  AFTER INSERT OR DELETE OR UPDATE OF post_id ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION private.trg_recompter_publication();

DROP TRIGGER IF EXISTS trg_compteur_repartages ON public.post_reposts;
CREATE TRIGGER trg_compteur_repartages
  AFTER INSERT OR DELETE OR UPDATE OF post_id ON public.post_reposts
  FOR EACH ROW EXECUTE FUNCTION private.trg_recompter_publication();

DROP TRIGGER IF EXISTS trg_compteur_likes_commentaire ON public.post_comment_likes;
CREATE TRIGGER trg_compteur_likes_commentaire
  AFTER INSERT OR DELETE ON public.post_comment_likes
  FOR EACH ROW EXECUTE FUNCTION private.trg_recompter_commentaire();

-- ── 3. Les RPC recomptent au lieu d'ajouter ─────────────────────────────────
-- Même signature (uuid) → void : OR REPLACE remplace le corps sans créer de
-- surcharge.

CREATE OR REPLACE FUNCTION public.increment_post_like(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.decrement_post_like(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.increment_post_comment(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.decrement_post_comment(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.increment_post_share(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.decrement_post_share(p_post_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_publication(p_post_id); $$;

CREATE OR REPLACE FUNCTION public.increment_post_comment_like(p_comment_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_commentaire(p_comment_id); $$;

CREATE OR REPLACE FUNCTION public.decrement_post_comment_like(p_comment_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ SELECT private.recompter_commentaire(p_comment_id); $$;

REVOKE ALL ON FUNCTION public.increment_post_like(UUID)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_post_like(UUID)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.increment_post_comment(UUID)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_post_comment(UUID)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.increment_post_share(UUID)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_post_share(UUID)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.increment_post_comment_like(UUID)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_post_comment_like(UUID)  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_post_like(UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_post_like(UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_post_comment(UUID)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_post_comment(UUID)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_post_share(UUID)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_post_share(UUID)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_post_comment_like(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_post_comment_like(UUID) TO authenticated;

-- ── 4. Rattrapage ────────────────────────────────────────────────────────────

SELECT private.recompter_publication(id) FROM public.posts;
SELECT private.recompter_commentaire(id) FROM public.post_comments;
