-- `repere_de_lecture` rend aussi le DERNIER non-lu.
--
-- Étape B du plan du séparateur : « N messages non lus » disparaît quand tout
-- ce qui était non lu à l'ouverture a été lu. Pour le savoir, l'écran doit
-- connaître la borne haute de cet ensemble — le plus récent des non-lus au
-- moment du relevé. Le curseur l'atteint : tout est lu.
--
-- Pourquoi pas simplement « plus aucun non-lu » (`non_lus = 0`) : un message
-- arrivé PENDANT la lecture est non lu lui aussi. Avec ce seul critère, le
-- séparateur ne partirait jamais dans une discussion active — il faudrait lire
-- plus vite qu'on n'écrit.
--
-- Corps repris À L'IDENTIQUE de 20260916224700 (lu dans `pg_proc` le
-- 2026-09-17, identique au fichier), plus les deux colonnes, ajoutées EN FIN :
-- l'app lit les colonnes par leur nom, et une version installée qui ne les
-- connaît pas les ignore.
--
-- Changer le type de retour d'une fonction `RETURNS TABLE` interdit
-- `CREATE OR REPLACE` (42P13) : DROP puis CREATE, dans la transaction de la
-- migration. Il n'y a qu'une surcharge, `(TEXT)`, et rien n'en dépend (ni vue
-- ni autre fonction).

DROP FUNCTION IF EXISTS public.repere_de_lecture(TEXT);

CREATE FUNCTION public.repere_de_lecture(p_conversation_id TEXT)
RETURNS TABLE (
  curseur_id        TEXT,
  curseur_a         TIMESTAMPTZ,
  premier_non_lu_id TEXT,
  premier_non_lu_a  TIMESTAMPTZ,
  non_lus           INTEGER,
  dernier_non_lu_id TEXT,
  dernier_non_lu_a  TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid TEXT := public.firebase_uid();
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'repere_de_lecture: session requise' USING ERRCODE = '42501';
  END IF;

  -- Un refus doit se voir. Sans cette garde, un non-participant recevrait un
  -- repère vide — « rien à lire » — indiscernable d'une conversation lue.
  IF NOT EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = p_conversation_id
      AND v_uid = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'repere_de_lecture: pas participant' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH fil AS (
    SELECT m.id AS id,
           m.created_at AS quand,
           COALESCE((m.data->'readBy') ? v_uid, FALSE) AS lu
      FROM messages m
     WHERE m.conversation_id = p_conversation_id
       AND m.sender_id <> v_uid
       AND m.type IS DISTINCT FROM 'system'
       AND NOT COALESCE(m.is_deleted, FALSE)
       AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)
    UNION ALL
    SELECT mm.id::TEXT,
           mm.created_at,
           r.read_at IS NOT NULL
      FROM mls_messages mm
      LEFT JOIN mls_message_receipts r
             ON r.message_id = mm.id AND r.user_id = v_uid
      LEFT JOIN mls_message_hidden h
             ON h.message_id = mm.id AND h.user_id = v_uid
     WHERE mm.conversation_id = p_conversation_id
       AND mm.kind = 'content'
       AND NOT mm.is_deleted
       AND mm.sender_id <> v_uid
       AND h.message_id IS NULL
  ),
  curseur AS (
    SELECT f.id, f.quand FROM fil f
     WHERE f.lu
     ORDER BY f.quand DESC, f.id DESC
     LIMIT 1
  ),
  apres AS (
    SELECT f.id, f.quand FROM fil f
     WHERE NOT f.lu
       AND f.quand > COALESCE((SELECT c.quand FROM curseur c), '-infinity'::timestamptz)
  )
  SELECT (SELECT c.id FROM curseur c),
         (SELECT c.quand FROM curseur c),
         (SELECT a.id FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT a.quand FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT count(*)::INTEGER FROM apres),
         (SELECT a.id FROM apres a ORDER BY a.quand DESC, a.id DESC LIMIT 1),
         (SELECT a.quand FROM apres a ORDER BY a.quand DESC, a.id DESC LIMIT 1);
END;
$$;

REVOKE ALL ON FUNCTION public.repere_de_lecture(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repere_de_lecture(TEXT) TO authenticated;
