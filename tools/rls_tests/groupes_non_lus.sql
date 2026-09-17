-- Banc des non-lus en groupe : rien d'avant l'arrivée, jamais un message
-- système (migration 20260917003700).
--
--   supabase db query --linked -f tools/rls_tests/groupes_non_lus.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. Lancé tel quel sur une base où elle n'est pas appliquée, le
-- banc mesure l'état d'avant : les cas 1 à 7 y tombent, 8 à 10 (témoin et
-- droits) passent — vérifié à l'écriture.
--
-- Aucune ligne n'est insérée (`trg_notify_push`, `notify_recipients_on_message_insert`
-- enverraient des notifications) : les cas fabriqués MODIFIENT des lignes
-- existantes, et le ROLLBACK les rend.
--
-- Données réelles relevées le 2026-09-17 — si elles disparaissent, relever :
--   · un membre de groupe avec des non-lus AVANT et APRÈS son arrivée ;
--   · un membre de groupe qui n'en a qu'AVANT ;
--   · une conversation de groupe basculée en MLS avec un non-lu pour un membre ;
--   · une conversation 1:1 avec des non-lus (témoin : rien ne doit y changer).

BEGIN;

-- @@MIGRATION@@

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated, anon;

INSERT INTO ctx VALUES
  ('g_conv',   'ffd4f06e-862d-4416-9a67-9f8478f0bea1'),
  ('g_membre', '8KWRmGS928crtm0VhFQ6CbMAits1'),
  ('p_conv',   '37fd965c-1aad-4075-ac89-c018456a3518'),
  ('p_membre', 'La8GqXDqKJhCC9UdYuXZywMmAfF2'),
  ('m_conv',   'd41d4ea0-cc03-4f23-9bc2-9b4987989658'),
  ('m_groupe', '90a2baa1-3927-4b21-97ac-5907002ed75d'),
  ('m_membre', 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'),
  ('t_conv',   '97ac9997-f13e-409a-94c6-9f535b6d05f2'),
  ('t_membre', 'lXJ2BcP3PrdYcPuS8dRaCwzFpab2');

-- ═══ Attendus, en postgres, par une requête indépendante ════════════════════
CREATE OR REPLACE FUNCTION pg_temp.attendu(p_conv text, p_uid text, p_depuis_arrivee boolean)
RETURNS TABLE (premier text, non_lus int, total_avec_avant int)
LANGUAGE sql AS $$
  WITH arrivee AS (
    SELECT gm.joined_at FROM conversations c
      JOIN group_members gm ON gm.group_id::text = c.group_id AND gm.user_id = p_uid
     WHERE c.id = p_conv
  ),
  fil AS (
    SELECT m.id, m.created_at, COALESCE(m.data->'readBy' ? p_uid, false) AS lu,
           m.created_at > COALESCE((SELECT joined_at FROM arrivee), '-infinity') AS apres_arrivee
      FROM messages m
     WHERE m.conversation_id = p_conv AND m.sender_id <> p_uid
       AND m.type IS DISTINCT FROM 'system' AND m.sender_id <> 'system'
       AND NOT m.is_deleted AND NOT COALESCE(m.data->'deletedFor' ? p_uid, false)
  ),
  retenus AS (SELECT * FROM fil WHERE apres_arrivee OR NOT p_depuis_arrivee),
  curseur AS (SELECT created_at FROM retenus WHERE lu ORDER BY created_at DESC LIMIT 1)
  SELECT (SELECT id FROM retenus WHERE NOT lu AND created_at > COALESCE((SELECT created_at FROM curseur), '-infinity') ORDER BY created_at, id LIMIT 1),
         (SELECT count(*)::int FROM retenus WHERE NOT lu AND created_at > COALESCE((SELECT created_at FROM curseur), '-infinity')),
         (SELECT count(*)::int FROM fil WHERE NOT lu)
$$;

INSERT INTO ctx SELECT 'g_premier', premier FROM pg_temp.attendu((SELECT v FROM ctx WHERE k='g_conv'), (SELECT v FROM ctx WHERE k='g_membre'), true);
INSERT INTO ctx SELECT 'g_non_lus', non_lus::text FROM pg_temp.attendu((SELECT v FROM ctx WHERE k='g_conv'), (SELECT v FROM ctx WHERE k='g_membre'), true);
INSERT INTO ctx SELECT 'g_total', total_avec_avant::text FROM pg_temp.attendu((SELECT v FROM ctx WHERE k='g_conv'), (SELECT v FROM ctx WHERE k='g_membre'), true);
INSERT INTO ctx SELECT 't_non_lus', non_lus::text FROM pg_temp.attendu((SELECT v FROM ctx WHERE k='t_conv'), (SELECT v FROM ctx WHERE k='t_membre'), false);
INSERT INTO ctx SELECT 'g_arrivee', gm.joined_at::text FROM group_members gm JOIN conversations c ON c.group_id = gm.group_id::text
 WHERE c.id = (SELECT v FROM ctx WHERE k='g_conv') AND gm.user_id = (SELECT v FROM ctx WHERE k='g_membre');
INSERT INTO ctx SELECT 'p_borne', m.id FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='p_conv') AND m.sender_id <> (SELECT v FROM ctx WHERE k='p_membre')
   AND NOT COALESCE(m.data->'readBy' ? (SELECT v FROM ctx WHERE k='p_membre'), false)
 ORDER BY m.created_at LIMIT 1;

-- ═══ Le membre de groupe, arrivé en cours de route ══════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"8KWRmGS928crtm0VhFQ6CbMAits1"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'g_conv'));
  INSERT INTO resultat VALUES
    (1, 'groupe : seuls les non-lus d''après l''arrivée comptent',
     (SELECT v FROM ctx WHERE k='g_non_lus') || ' (sur ' || (SELECT v FROM ctx WHERE k='g_total') || ' non lus en tout)',
     r.non_lus::text,
     CASE WHEN r.non_lus::text = (SELECT v FROM ctx WHERE k='g_non_lus') THEN 'OK' ELSE 'ÉCHEC' END),
    (2, 'groupe : le séparateur se pose après l''arrivée',
     (SELECT v FROM ctx WHERE k='g_premier'), COALESCE(r.premier_non_lu_id, '<null>'),
     CASE WHEN r.premier_non_lu_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k='g_premier')
           AND (r.premier_non_lu_a IS NULL OR r.premier_non_lu_a > (SELECT v FROM ctx WHERE k='g_arrivee')::timestamptz)
          THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 5. Un message d'expéditeur « system », fabriqué sur le dernier non-lu ──
RESET ROLE;
UPDATE messages SET sender_id = 'system'
 WHERE id = (SELECT m.id FROM messages m
              WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='g_conv')
                AND m.sender_id NOT IN ((SELECT v FROM ctx WHERE k='g_membre'), 'system')
                AND NOT COALESCE(m.data->'readBy' ? (SELECT v FROM ctx WHERE k='g_membre'), false)
                AND m.created_at > (SELECT v FROM ctx WHERE k='g_arrivee')::timestamptz
                AND NOT m.is_deleted
              ORDER BY m.created_at DESC LIMIT 1);
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record; v_attendu int := (SELECT v FROM ctx WHERE k='g_non_lus')::int - 1;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'g_conv'));
  INSERT INTO resultat VALUES
    (5, 'un expéditeur « system » ne compte pas, même mal typé', v_attendu::text, r.non_lus::text,
     CASE WHEN (SELECT v FROM ctx WHERE k='g_non_lus')::int = 0 THEN 'SANS OBJET'
          WHEN r.non_lus = v_attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Le membre qui n'a de non-lus qu'avant son arrivée ══════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"La8GqXDqKJhCC9UdYuXZywMmAfF2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record; v_reste int;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'p_conv'));
  INSERT INTO resultat VALUES (3, 'rien que de l''avant-arrivée : aucun séparateur',
    '0 / <null>', r.non_lus || ' / ' || COALESCE(r.premier_non_lu_id, '<null>'),
    CASE WHEN r.non_lus = 0 AND r.premier_non_lu_id IS NULL THEN 'OK' ELSE 'ÉCHEC' END);

  -- Lire le plus ancien seulement : ce qui reste est d'avant l'arrivée.
  v_reste := marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'p_conv'), (SELECT v FROM ctx WHERE k = 'p_borne'));
  INSERT INTO resultat VALUES (4, 'le recompte de la pastille ignore l''avant-arrivée', '0', v_reste::text,
    CASE WHEN v_reste = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Groupe chiffré : la pastille (vue) et le repère ════════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000cc","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;
INSERT INTO ctx SELECT 'm_avant', COALESCE((SELECT unread::text FROM mls_unread_counts WHERE conversation_id = (SELECT v FROM ctx WHERE k='m_conv')), '<absent>');

-- L'arrivée déplacée APRÈS tous les messages : plus rien ne doit compter.
RESET ROLE;
UPDATE group_members SET joined_at = now()
 WHERE group_id = (SELECT v FROM ctx WHERE k='m_groupe')::uuid AND user_id = (SELECT v FROM ctx WHERE k='m_membre');
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record; v_vue text;
BEGIN
  v_vue := COALESCE((SELECT unread::text FROM mls_unread_counts WHERE conversation_id = (SELECT v FROM ctx WHERE k='m_conv')), '<absent>');
  INSERT INTO resultat VALUES (6, 'pastille chiffrée : l''avant-arrivée ne compte pas',
    '<absent> ou 0 (avant : ' || (SELECT v FROM ctx WHERE k='m_avant') || ')', v_vue,
    CASE WHEN (SELECT v FROM ctx WHERE k='m_avant') IN ('<absent>', '0') THEN 'SANS OBJET'
         WHEN v_vue IN ('<absent>', '0') THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'm_conv'));
  INSERT INTO resultat VALUES (7, 'repère chiffré : l''avant-arrivée ne compte pas', '0', r.non_lus::text,
    CASE WHEN (SELECT v FROM ctx WHERE k='m_avant') IN ('<absent>', '0') THEN 'SANS OBJET'
         WHEN r.non_lus = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Témoin : une conversation hors groupe ne change pas ════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000dd","app_metadata":{"firebase_uid":"lXJ2BcP3PrdYcPuS8dRaCwzFpab2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 't_conv'));
  INSERT INTO resultat VALUES (8, 'tête-à-tête : aucune borne d''arrivée', (SELECT v FROM ctx WHERE k='t_non_lus'), r.non_lus::text,
    CASE WHEN r.non_lus::text = (SELECT v FROM ctx WHERE k='t_non_lus') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Droits de la vue ═══════════════════════════════════════════════════════
RESET ROLE;
INSERT INTO resultat
SELECT 9, 'la vue reste security_invoker', 'security_invoker=on', COALESCE(array_to_string(c.reloptions, ','), '<aucune>'),
       CASE WHEN 'security_invoker=on' = ANY (c.reloptions) OR 'security_invoker=true' = ANY (c.reloptions) THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relname = 'mls_unread_counts';

SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM mls_unread_counts LIMIT 1;
  INSERT INTO resultat VALUES (10, 'anon ne lit pas la vue', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (10, 'anon ne lit pas la vue', 'refusé', 'refusé 42501', 'OK');
END $$;
RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
