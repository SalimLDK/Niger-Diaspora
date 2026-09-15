-- Banc du gel de `messages` (plan MLS, phase 6).
--
--   supabase db query -f tools/mls_banc/gel_messages.sql --linked
--
-- Joue le gel de `supabase/gel-messages-cible.sql` **dans une transaction
-- annulée**, puis vérifie qu'il fait ce qu'il promet — et seulement ça. La
-- production ne garde rien : aucune sortie = tout est passé.
--
-- POURQUOI UN BANC POUR DEUX `REVOKE`
-- Parce que le gel est la seule opération du plan qui casse la messagerie si
-- elle est mal cadrée, et que « mal cadrée » ne se voit pas : un `REVOKE`
-- trop large emporterait les réactions et les suppressions sur tout
-- l'historique, sans message d'erreur ailleurs que chez l'utilisateur. Le
-- banc mesure donc autant ce qui doit **continuer** de marcher que ce qui
-- doit cesser.
--
-- Il joue tout en `authenticated` : `db query --linked` se connecte en
-- postgres, qui contourne le RLS **et** possède la table — un gel testé en
-- postgres passerait quoi qu'on écrive.

BEGIN;

DO $banc$
DECLARE
  v_conv  text := 'conv_banc_gel';
  v_alice text := 'u_banc_gel_alice';
  v_bob   text := 'u_banc_gel_bob';
  v_msg   text := 'm_banc_gel_1';
  v_n     bigint;
BEGIN
  -- ── Fixtures, en postgres ───────────────────────────────────────────────
  INSERT INTO public.conversations (id, type, participant_ids, created_by, created_at, data)
  VALUES (v_conv, 'individual', ARRAY[v_alice, v_bob], v_alice, now(), '{}'::jsonb);

  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid', v_alice))::text, true);
  SET LOCAL ROLE authenticated;

  -- ── A. Avant le gel : Alice écrit ───────────────────────────────────────
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES (v_msg, v_conv, v_alice, 'text', jsonb_build_object('content', 'avant le gel'));

  IF NOT EXISTS (SELECT 1 FROM public.messages WHERE id = v_msg) THEN
    RAISE EXCEPTION 'A1 ÉCHEC: le banc n''a pas su écrire AVANT le gel — il ne prouve rien';
  END IF;

  -- ── LE GEL ──────────────────────────────────────────────────────────────
  RESET ROLE;
  REVOKE INSERT ON public.messages FROM authenticated;
  REVOKE INSERT ON public.messages FROM anon;
  SET LOCAL ROLE authenticated;

  -- ── B. Après le gel : plus une écriture en clair ─────────────────────────
  BEGIN
    INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
    VALUES ('m_banc_gel_2', v_conv, v_alice, 'text', jsonb_build_object('content', 'après le gel'));
    RAISE EXCEPTION 'B1 ÉCHEC: un message en clair est passé APRÈS le gel';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- ── C. Ce qui doit CONTINUER de marcher ─────────────────────────────────
  -- L'historique reste lisible : des mois de conversations en dépendent.
  SELECT count(*) INTO v_n FROM public.messages WHERE conversation_id = v_conv;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'C1 ÉCHEC: l''historique n''est plus lisible (% ligne(s))', v_n;
  END IF;

  -- Et amendable : réagir à un vieux message, le masquer, le supprimer pour
  -- tous, tout ça écrit dans `data` d'une ligne qui existe déjà. Un REVOKE
  -- trop large les emporterait en silence.
  BEGIN
    UPDATE public.messages
       SET data = data || jsonb_build_object('reactions', jsonb_build_object(v_alice, '👍'))
     WHERE id = v_msg;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'C2 ÉCHEC: le gel a emporté UPDATE — plus aucune réaction sur l''historique';
  END;
  IF (SELECT data->'reactions'->>v_alice FROM public.messages WHERE id = v_msg) IS NULL THEN
    RAISE EXCEPTION 'C2 ÉCHEC: on ne peut plus réagir à un message de l''historique';
  END IF;

  BEGIN
    UPDATE public.messages SET is_deleted = true WHERE id = v_msg;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'C3 ÉCHEC: le gel a emporté la suppression sur l''historique';
  END;
  IF NOT (SELECT is_deleted FROM public.messages WHERE id = v_msg) THEN
    RAISE EXCEPTION 'C3 ÉCHEC: on ne peut plus supprimer un message de l''historique';
  END IF;

  -- ── D. Et le chemin chiffré, lui, reste ouvert ──────────────────────────
  -- Le gel n'a de sens que si l'autre voie est praticable. Le banc ne peut
  -- pas chiffrer ici, mais il peut vérifier que le droit d'écrire dans
  -- `mls_messages` n'a pas été emporté au passage.
  IF NOT has_table_privilege('authenticated', 'public.mls_messages', 'INSERT') THEN
    RAISE EXCEPTION 'D1 ÉCHEC: le gel a aussi fermé le chemin chiffré';
  END IF;

  RESET ROLE;
END
$banc$;

-- ── Tableau de bord : les trois conditions du gel ──────────────────────────
-- Lu à l'œil avant de décider quoi que ce soit. Aucune assertion : ces
-- nombres ne sont pas un test qui passe ou échoue, ce sont les faits sur
-- lesquels la décision se prend.
SELECT
  (SELECT count(*) FROM messages WHERE created_at > now() - interval '30 days')
    AS legacy_30_derniers_jours,
  (SELECT count(*) FROM mls_messages WHERE kind = 'content') AS messages_chiffres,
  (SELECT count(*) FROM conversations WHERE mls_since IS NOT NULL) AS conversations_basculees,
  (SELECT count(*) FROM conversations) AS conversations_total;

ROLLBACK;
