-- Banc des accusés en clair : ni doublon dans `deliveredTo`, ni heure de
-- livraison écrasée par la lecture (migration 20260916235300).
--
--   supabase db query --linked -f tools/rls_tests/accuses_sans_doublon.sql
--
-- Condition : 0 cas en ÉCHEC (« SANS OBJET » admis). Tout est dans un
-- `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. Les cas de réparation (4, 5) ne mesurent quelque chose
-- qu'à ce moment-là — une fois la migration appliquée, il n'y a plus de
-- doublon à réparer et ils passent « SANS OBJET ».
--
-- Un banc qui ne sait pas échouer ne prouve rien : avec les corps d'avant
-- (20260916224700) et sans la réparation, les cas 1, 3, 4 et 5 tombent —
-- vérifié à l'écriture. Le cas 2 (message jamais livré) passait déjà : il
-- garde la non-régression.
--
-- L'état de départ est FABRIQUÉ dans la transaction, sur deux messages non lus
-- d'une vraie conversation : l'un déjà livré à une heure sentinelle (2020),
-- l'autre jamais livré. Aucune notification n'est créée (`trg_notify_push`).

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated;

INSERT INTO ctx VALUES
  ('conv',  'ffd4f06e-862d-4416-9a67-9f8478f0bea1'),
  ('moi',   '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13');

-- Doublons AVANT la migration : la réparation se juge là-dessus.
CREATE TEMP TABLE doublons_avant AS
SELECT m.id,
       (SELECT array_agg(DISTINCT e ORDER BY e) FROM jsonb_array_elements_text(m.data->'deliveredTo') e) AS ensemble,
       (SELECT array_agg(u.e ORDER BY u.premier)
          FROM (SELECT t.e, min(t.pos) AS premier
                  FROM jsonb_array_elements_text(m.data->'deliveredTo') WITH ORDINALITY AS t(e, pos)
                 GROUP BY t.e) u) AS ordre_attendu
  FROM messages m
 WHERE jsonb_typeof(m.data->'deliveredTo') = 'array'
   AND jsonb_array_length(m.data->'deliveredTo')
       <> (SELECT count(DISTINCT e) FROM jsonb_array_elements_text(m.data->'deliveredTo') e);

-- @@MIGRATION@@

-- ═══ Réparation, jugée AVANT tout appel du banc ═════════════════════════════
-- Après, la lecture ajoute légitimement le lecteur à `deliveredTo` : l'ordre
-- ne se comparerait plus à l'instantané.
DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM messages m
   WHERE jsonb_typeof(m.data->'deliveredTo') = 'array'
     AND jsonb_array_length(m.data->'deliveredTo')
         <> (SELECT count(DISTINCT e) FROM jsonb_array_elements_text(m.data->'deliveredTo') e);
  INSERT INTO resultat VALUES (4, 'réparation : plus aucun doublon en base',
    '0 (avant : ' || (SELECT count(*) FROM doublons_avant) || ')', n::text,
    CASE WHEN (SELECT count(*) FROM doublons_avant) = 0 THEN 'SANS OBJET'
         WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM doublons_avant d JOIN messages m ON m.id = d.id
   WHERE (SELECT array_agg(e ORDER BY ord) FROM jsonb_array_elements_text(m.data->'deliveredTo') WITH ORDINALITY AS t(e, ord))
         IS DISTINCT FROM d.ordre_attendu;
  INSERT INTO resultat VALUES (5, 'réparation : personne perdu, ordre d''arrivée gardé',
    '0 écart sur ' || (SELECT count(*) FROM doublons_avant), n::text || ' écart',
    CASE WHEN (SELECT count(*) FROM doublons_avant) = 0 THEN 'SANS OBJET'
         WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ État de départ, fabriqué en postgres ═══════════════════════════════════
DO $$
DECLARE
  v_conv text := (SELECT v FROM ctx WHERE k = 'conv');
  v_moi  text := (SELECT v FROM ctx WHERE k = 'moi');
  v_livre text;
  v_jamais text;
BEGIN
  SELECT m.id INTO v_livre FROM messages m
   WHERE m.conversation_id = v_conv AND m.sender_id <> v_moi
     AND NOT COALESCE(m.data->'readBy' ? v_moi, false)
   ORDER BY m.created_at, m.id LIMIT 1;
  SELECT m.id INTO v_jamais FROM messages m
   WHERE m.conversation_id = v_conv AND m.sender_id <> v_moi
     AND NOT COALESCE(m.data->'readBy' ? v_moi, false)
     AND m.id <> v_livre
   ORDER BY m.created_at, m.id LIMIT 1;
  INSERT INTO ctx VALUES ('livre', v_livre), ('jamais', v_jamais);

  -- Déjà livré, une seule fois, à une heure reconnaissable.
  UPDATE messages m
     SET data = jsonb_set(jsonb_set(m.data,
           '{deliveredTo}',
           COALESCE((SELECT jsonb_agg(e) FROM jsonb_array_elements(m.data->'deliveredTo') e
                      WHERE e <> to_jsonb(v_moi)), '[]'::jsonb) || to_jsonb(v_moi)),
           '{deliveredAt}',
           CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object' THEN m.data->'deliveredAt' ELSE '{}'::jsonb END
             || jsonb_build_object(v_moi, '2020-01-01 00:00:00+00'))
   WHERE m.id = v_livre;

  -- Jamais livré.
  UPDATE messages m
     SET data = jsonb_set(jsonb_set(m.data,
           '{deliveredTo}',
           COALESCE((SELECT jsonb_agg(e) FROM jsonb_array_elements(m.data->'deliveredTo') e
                      WHERE e <> to_jsonb(v_moi)), '[]'::jsonb)),
           '{deliveredAt}',
           CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object' THEN m.data->'deliveredAt' ELSE '{}'::jsonb END - v_moi)
   WHERE m.id = v_jamais;
END $$;

-- ═══ En rôle applicatif ═════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

DO $$
BEGIN
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
  -- Une seconde fois : rien ne doit bouger.
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
  PERFORM mark_messages_as_delivered((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (99, 'appels pour soi', 'acceptés', 'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'autre'));
  INSERT INTO resultat VALUES (6, 'lire au nom d''un autre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6, 'lire au nom d''un autre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  PERFORM mark_messages_as_delivered((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'autre'));
  INSERT INTO resultat VALUES (7, 'accuser réception au nom d''un autre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, 'accuser réception au nom d''un autre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ Vérifications en postgres ══════════════════════════════════════════════
RESET ROLE;
DO $$
DECLARE
  v_moi text := (SELECT v FROM ctx WHERE k = 'moi');
  r record;
  n int;
BEGIN
  SELECT m.data INTO r FROM messages m WHERE m.id = (SELECT v FROM ctx WHERE k = 'livre');
  INSERT INTO resultat VALUES (1, 'déjà livré puis lu : l''heure de livraison reste',
    '2020-01-01 00:00:00+00 / 1 fois',
    COALESCE(r.data->'deliveredAt'->>v_moi, '<absent>') || ' / '
      || (SELECT count(*) FROM jsonb_array_elements_text(r.data->'deliveredTo') e WHERE e = v_moi) || ' fois',
    CASE WHEN r.data->'deliveredAt'->>v_moi = '2020-01-01 00:00:00+00'
          AND (SELECT count(*) FROM jsonb_array_elements_text(r.data->'deliveredTo') e WHERE e = v_moi) = 1
          AND r.data->'readAt' ? v_moi
         THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT m.data INTO r FROM messages m WHERE m.id = (SELECT v FROM ctx WHERE k = 'jamais');
  INSERT INTO resultat VALUES (2, 'jamais livré puis lu : livré ET lu, une fois chacun',
    '1 / 1 / heures posées',
    (SELECT count(*) FROM jsonb_array_elements_text(r.data->'deliveredTo') e WHERE e = v_moi) || ' / '
      || (SELECT count(*) FROM jsonb_array_elements_text(r.data->'readBy') e WHERE e = v_moi) || ' / '
      || CASE WHEN r.data->'deliveredAt' ? v_moi AND r.data->'readAt' ? v_moi THEN 'heures posées' ELSE 'heure manquante' END,
    CASE WHEN (SELECT count(*) FROM jsonb_array_elements_text(r.data->'deliveredTo') e WHERE e = v_moi) = 1
          AND (SELECT count(*) FROM jsonb_array_elements_text(r.data->'readBy') e WHERE e = v_moi) = 1
          AND r.data->'deliveredAt' ? v_moi AND r.data->'readAt' ? v_moi
         THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM messages m
   WHERE m.conversation_id = (SELECT v FROM ctx WHERE k = 'conv')
     AND (SELECT count(*) FROM jsonb_array_elements_text(
            CASE WHEN jsonb_typeof(m.data->'deliveredTo') = 'array' THEN m.data->'deliveredTo' ELSE '[]'::jsonb END) e
           WHERE e = v_moi) > 1;
  INSERT INTO resultat VALUES (3, 'trois appels de suite : aucun doublon dans la conversation', '0', n::text,
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

END $$;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
