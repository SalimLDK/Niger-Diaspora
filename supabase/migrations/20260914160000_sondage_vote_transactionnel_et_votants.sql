-- =============================================================================
-- Sondages : un vote qui ne peut plus se perdre, et des votants enfin lisibles
--
-- ── 1. Voter, en une seule transaction ───────────────────────────────────────
--
-- Le client faisait DELETE puis INSERT. Entre les deux, rien ne protège : un
-- refus, une coupure, et l'ancien vote est supprimé sans que le nouveau soit
-- posé — compteurs décrémentés compris, puisque c'est le trigger de DELETE qui
-- les tient. Le votant croit avoir voté, la base a perdu sa voix.
--
-- Trois règles, en plus, n'existaient QUE dans l'écran :
--   - on ne vote plus après `ends_at` (rien ne l'empêchait par l'API) ;
--   - une seule réponse quand `allow_multiple` est faux ;
--   - les options doivent appartenir au sondage voté (la policy INSERT ne
--     vérifiait que le sondage, jamais que l'option en fait partie).
--
-- `cast_poll_vote` fait le remplacement d'un bloc et refait ces trois
-- contrôles côté serveur. Un `RESTRICTIVE` ferme en plus la porte directe
-- après la fin du sondage, pour les clients déjà installés.
--
-- ── 2. Qui a voté quoi ───────────────────────────────────────────────────────
--
-- `post_poll_votes` n'est lisible que par l'auteur de la ligne
-- (`firebase_uid() = user_id`). L'écran de résultats, qui affiche les votants
-- option par option et annonce « les votes sont visibles par l'auteur du
-- sondage », ne recevait donc jamais que le vote du lecteur : « Aucun vote
-- pour le moment » sous des options qui en avaient. La requête réussissait à
-- vide — la 7e forme d'échec muet, celle qui ne laisse aucune trace.
--
-- `poll_option_voters` rend la liste à ceux qui voient le sondage — sauf si
-- son auteur l'a coché anonyme à la création (`is_anonymous`, faux par
-- défaut), auquel cas personne ne l'obtient, lui compris. Le votant lit la
-- règle sous la question avant de choisir.
--
-- Les deux fonctions sont SECURITY DEFINER : elles contournent la RLS, donc
-- elles refont elles-mêmes le contrôle d'accès qu'elle aurait fait.
-- =============================================================================


-- ── Qui peut voter dans ce sondage ──────────────────────────────────────────
-- Miroir exact de la policy INSERT « Users can vote once per poll » : post =
-- tout compte connecté, groupe = ses membres, discussion = ses participants.
CREATE OR REPLACE FUNCTION public.peut_voter_au_sondage(p_poll_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH moi AS (SELECT public.firebase_uid() AS uid)
  SELECT EXISTS (
    SELECT 1
      FROM post_polls p, moi
     WHERE p.id = p_poll_id
       AND moi.uid IS NOT NULL
       AND moi.uid <> ''
       AND (
         p.post_id IS NOT NULL
         OR EXISTS (
              SELECT 1 FROM group_members gm
               WHERE gm.group_id = p.group_id AND gm.user_id = moi.uid)
         OR (p.conversation_id IS NOT NULL
             AND public.is_conversation_participant(p.conversation_id))
       )
  );
$$;

REVOKE ALL ON FUNCTION public.peut_voter_au_sondage(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.peut_voter_au_sondage(UUID)
  TO anon, authenticated, service_role;


-- ── Voter, ou retirer son vote ──────────────────────────────────────────────
-- `p_option_ids` vide = retrait du vote (policy DELETE « Users can retract
-- their own vote », qui n'avait jusqu'ici aucun chemin depuis l'app).
CREATE OR REPLACE FUNCTION public.cast_poll_vote(
  p_poll_id    UUID,
  p_option_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     TEXT := public.firebase_uid();
  v_poll    RECORD;
  v_options UUID[];
  v_connues INT;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'cast_poll_vote: non authentifié' USING ERRCODE = '42501';
  END IF;

  SELECT id, allow_multiple, ends_at INTO v_poll
    FROM post_polls WHERE id = p_poll_id;

  IF NOT FOUND OR NOT public.peut_voter_au_sondage(p_poll_id) THEN
    RAISE EXCEPTION 'cast_poll_vote: sondage inaccessible'
      USING ERRCODE = '42501';
  END IF;

  IF v_poll.ends_at IS NOT NULL AND NOW() > v_poll.ends_at THEN
    RAISE EXCEPTION 'Ce sondage est terminé.' USING ERRCODE = '22023';
  END IF;

  -- Deux fois la même option n'est pas deux voix : la clé primaire
  -- (poll_id, option_id, user_id) refuserait l'insertion, ce qui annulerait
  -- tout le vote plutôt que de compter une fois.
  SELECT COALESCE(ARRAY_AGG(DISTINCT o), '{}')
    INTO v_options
    FROM UNNEST(COALESCE(p_option_ids, '{}')) AS o;

  IF NOT v_poll.allow_multiple AND COALESCE(ARRAY_LENGTH(v_options, 1), 0) > 1 THEN
    RAISE EXCEPTION 'Ce sondage n''accepte qu''une seule réponse.'
      USING ERRCODE = '22023';
  END IF;

  IF COALESCE(ARRAY_LENGTH(v_options, 1), 0) > 0 THEN
    SELECT COUNT(*) INTO v_connues
      FROM post_poll_options
     WHERE poll_id = p_poll_id AND id = ANY (v_options);

    IF v_connues <> ARRAY_LENGTH(v_options, 1) THEN
      RAISE EXCEPTION 'cast_poll_vote: option étrangère au sondage'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Remplacement d'un bloc : les triggers de compteur suivent, et si quoi que
  -- ce soit échoue plus bas, le vote précédent est toujours là.
  DELETE FROM post_poll_votes
   WHERE poll_id = p_poll_id AND user_id = v_uid;

  IF COALESCE(ARRAY_LENGTH(v_options, 1), 0) > 0 THEN
    INSERT INTO post_poll_votes (poll_id, option_id, user_id)
    SELECT p_poll_id, o, v_uid FROM UNNEST(v_options) AS o;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.cast_poll_vote(UUID, UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cast_poll_vote(UUID, UUID[]) TO authenticated;


-- ── Plus de vote après la fin, même en écrivant directement ─────────────────
-- S'ajoute en ET aux policies existantes : ne donne aucun droit, en retire un
-- que personne n'aurait dû avoir. Les clients déjà installés écrivent encore
-- dans la table sans passer par la fonction.
DROP POLICY IF EXISTS post_poll_votes_pas_apres_la_fin ON public.post_poll_votes;
CREATE POLICY post_poll_votes_pas_apres_la_fin ON public.post_poll_votes
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.post_polls p
     WHERE p.id = post_poll_votes.poll_id
       AND (p.ends_at IS NULL OR NOW() <= p.ends_at)
  ));


-- ── Anonyme ou non, au choix de qui crée le sondage ───────────────────────
-- Par défaut non : c'est le comportement que l'écran décrivait déjà, et les
-- sondages existants n'ont jamais promis l'anonymat à leurs votants.
ALTER TABLE public.post_polls
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT FALSE;


-- ── Les votants, quand le sondage n'est pas anonyme ───────────────────────────
CREATE OR REPLACE FUNCTION public.poll_option_voters(p_poll_id UUID)
RETURNS TABLE (
  option_id    UUID,
  user_id      TEXT,
  display_name TEXT,
  avatar_url   TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT v.option_id,
         v.user_id,
         u.display_name,
         u.avatar_url
    FROM post_poll_votes v
    LEFT JOIN users u ON u.id = v.user_id
   WHERE v.poll_id = p_poll_id
     AND EXISTS (
           SELECT 1
             FROM post_polls p
            WHERE p.id = p_poll_id
              -- Anonyme : personne, pas même l'auteur du sondage. Sinon,
              -- ceux qui peuvent voir le sondage — même ensemble que ceux
              -- qui peuvent y voter, et c'est ce que la notice annonce au
              -- votant avant qu'il ne choisisse.
              AND NOT p.is_anonymous
              AND public.peut_voter_au_sondage(p_poll_id)
         )
   ORDER BY v.created_at;
$$;

REVOKE ALL ON FUNCTION public.poll_option_voters(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poll_option_voters(UUID) TO authenticated;
