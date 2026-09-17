-- Banc de la lecture par curseur en clair, et de la faille des accusés.
--
--   supabase db query --linked -f tools/rls_tests/lecture_par_curseur.sql
--
-- Condition : 0 cas en ÉCHEC (« SANS OBJET » est admis : la donnée réelle ne
-- porte pas toujours le cas). Tout est dans un `BEGIN … ROLLBACK` — le banc
-- écrit sur de vraies lignes de production puis annule tout.
--
-- AVANT `db push`, pour éprouver une migration : coller son contenu à la place
-- de la ligne `-- @@MIGRATION@@` ci-dessous (le `ROLLBACK` final l'annule avec
-- le reste). Les cas 30 à 32 (dernier non-lu) demandent
-- `20260917002300_repere_porte_le_dernier_non_lu.sql`.
--
-- `SET LOCAL ROLE authenticated` est indispensable : `db query --linked` se
-- connecte en `postgres`, qui contourne la RLS. Les valeurs ATTENDUES sont
-- calculées avant la bascule, en `postgres`, par une requête indépendante des
-- fonctions testées.
--
-- AUCUNE NOTIFICATION N'EST CRÉÉE : `trg_notify_push` envoie un push à
-- l'insertion. Les cas de notifications travaillent sur des lignes existantes.
--
-- Un banc qui ne sait pas échouer ne prouve rien : retirer les deux gardes
-- d'identité (`IS DISTINCT FROM firebase_uid()`) doit faire tomber les cas 23
-- et 24 — vérifié à l'écriture.
--
-- Données réelles (relevées le 2026-09-16) — si elles disparaissent :
--   · groupe legacy de 24 membres ffd4f06e…, un membre avec des messages lus
--     ET non lus, et au moins 5 non lus ;
--   · une autre conversation dont ce membre n'est pas participant ;
--   · une conversation basculée qui porte des legacy non lus ET un message
--     MLS de contenu (aujourd'hui : comptes `banc_b_…` du banc MLS).

BEGIN;

-- @@MIGRATION@@

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat TO authenticated, anon;
GRANT ALL ON ctx TO authenticated, anon;

INSERT INTO ctx VALUES
  ('conv',   'ffd4f06e-862d-4416-9a67-9f8478f0bea1'),
  ('moi',    '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre',  'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('ailleurs', '97ac9997-f13e-409a-94c6-9f535b6d05f2'),
  ('mixte',  '55f1b1c0-ca2f-49f9-b25f-baaa4b8ee634'),
  ('mixte_moi', 'banc_b_1789578183874');

-- ═══ Attendus, calculés en postgres ═════════════════════════════════════════
DO $$
DECLARE
  v_conv text := (SELECT v FROM ctx WHERE k = 'conv');
  v_moi  text := (SELECT v FROM ctx WHERE k = 'moi');
  v_curseur_a timestamptz;
  v_curseur_id text;
  v_borne record;
  v_suivant record;
  v_dernier record;
BEGIN
  CREATE TEMP TABLE fil_attendu AS
  SELECT m.id, m.created_at,
         COALESCE(m.data->'readBy' ? v_moi, false) AS lu
    FROM messages m
   WHERE m.conversation_id = v_conv
     AND m.sender_id <> v_moi
     AND m.type IS DISTINCT FROM 'system'
     AND NOT m.is_deleted
     AND NOT COALESCE(m.data->'deletedFor' ? v_moi, false);

  SELECT id, created_at INTO v_curseur_id, v_curseur_a
    FROM fil_attendu WHERE lu ORDER BY created_at DESC, id DESC LIMIT 1;
  INSERT INTO ctx VALUES ('curseur_id', v_curseur_id);

  INSERT INTO ctx SELECT 'premier_id', id FROM fil_attendu
   WHERE NOT lu AND created_at > COALESCE(v_curseur_a, '-infinity')
   ORDER BY created_at, id LIMIT 1;
  INSERT INTO ctx SELECT 'non_lus_apres', count(*)::text FROM fil_attendu
   WHERE NOT lu AND created_at > COALESCE(v_curseur_a, '-infinity');
  INSERT INTO ctx SELECT 'non_lus_total', count(*)::text FROM fil_attendu WHERE NOT lu;
  -- Le plus récent des non-lus : la borne haute que le séparateur attend
  -- (20260917002300).
  INSERT INTO ctx SELECT 'dernier_non_lu_id', id FROM fil_attendu
   WHERE NOT lu AND created_at > COALESCE(v_curseur_a, '-infinity')
   ORDER BY created_at DESC, id DESC LIMIT 1;

  -- La borne : le 3e non-lu après le curseur. Il en reste donc au-delà.
  SELECT id, created_at INTO v_borne FROM fil_attendu
   WHERE NOT lu AND created_at > COALESCE(v_curseur_a, '-infinity')
   ORDER BY created_at, id OFFSET 2 LIMIT 1;
  INSERT INTO ctx VALUES ('borne_id', v_borne.id), ('borne_a', v_borne.created_at::text);
  INSERT INTO ctx SELECT 'reste_attendu', count(*)::text FROM fil_attendu
   WHERE NOT lu AND created_at > v_borne.created_at;

  SELECT id INTO v_suivant FROM fil_attendu
   WHERE NOT lu AND created_at > v_borne.created_at ORDER BY created_at, id LIMIT 1;
  INSERT INTO ctx VALUES ('suivant_id', v_suivant.id);

  -- Le dernier message d'autrui, tous types : la borne qui lit tout.
  SELECT m.id INTO v_dernier FROM messages m
   WHERE m.conversation_id = v_conv AND m.sender_id <> v_moi
   ORDER BY m.created_at DESC, m.id DESC LIMIT 1;
  INSERT INTO ctx VALUES ('dernier_id', v_dernier.id);

  -- Instantanés pour les cas de non-réécriture.
  CREATE TEMP TABLE avant AS
  SELECT m.id, m.created_at,
         m.data->'deliveredAt'->v_moi AS livre_a,
         (SELECT count(*) FROM jsonb_array_elements_text(
            CASE WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                 THEN m.data->'deliveredTo' ELSE '[]'::jsonb END) e
           WHERE e = v_moi) AS occurrences_livre,
         COALESCE(m.data->'readBy' ? (SELECT v FROM ctx WHERE k = 'autre'), false) AS lu_par_autre
    FROM messages m
   WHERE m.conversation_id = v_conv;
  INSERT INTO ctx SELECT 'last_read_by_avant', COALESCE(c.data->'lastMessageReadBy', 'null')::text
    FROM conversations c WHERE c.id = v_conv;

  CREATE TEMP TABLE notifs_avant AS
  SELECT n.id, n.is_read, n.type,
         (SELECT m.created_at FROM messages m WHERE m.id = n.data->>'messageId') AS message_a
    FROM notifications n
   WHERE n.user_id = v_moi AND n.data->>'conversationId' = v_conv AND NOT n.is_read;
END $$;
GRANT ALL ON fil_attendu, avant, notifs_avant TO authenticated;

-- Mixte : legacy non lus + MLS de contenu, pour le compte du banc MLS.
DO $$
DECLARE
  v_conv text := (SELECT v FROM ctx WHERE k = 'mixte');
  v_moi  text := (SELECT v FROM ctx WHERE k = 'mixte_moi');
BEGIN
  INSERT INTO ctx SELECT 'mixte_legacy_non_lus', count(*)::text FROM messages m
   WHERE m.conversation_id = v_conv AND m.sender_id <> v_moi AND NOT m.is_deleted
     AND NOT COALESCE(m.data->'readBy' ? v_moi, false);
  INSERT INTO ctx SELECT 'mixte_mls_non_lus', count(*)::text FROM mls_messages mm
    LEFT JOIN mls_message_receipts r ON r.message_id = mm.id AND r.user_id = v_moi
   WHERE mm.conversation_id = v_conv AND mm.kind = 'content' AND NOT mm.is_deleted
     AND mm.sender_id <> v_moi AND r.read_at IS NULL;
  INSERT INTO ctx SELECT 'mixte_borne_mls', mm.id::text FROM mls_messages mm
   WHERE mm.conversation_id = v_conv AND mm.kind = 'content'
   ORDER BY mm.created_at DESC LIMIT 1;
  INSERT INTO ctx SELECT 'mixte_last_read_by', COALESCE(c.data->'lastMessageReadBy', 'null')::text
    FROM conversations c WHERE c.id = v_conv;
END $$;

-- ═══ Bascule en rôle applicatif : le membre ══════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- ── 1-3. Le repère, avant toute lecture ────────────────────────────────────
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'conv'));
  INSERT INTO resultat VALUES
    (1, 'repère : non-lus après le curseur', (SELECT v FROM ctx WHERE k = 'non_lus_apres'), r.non_lus::text,
     CASE WHEN r.non_lus::text = (SELECT v FROM ctx WHERE k = 'non_lus_apres') THEN 'OK' ELSE 'ÉCHEC' END),
    (2, 'repère : premier non-lu', (SELECT v FROM ctx WHERE k = 'premier_id'), r.premier_non_lu_id,
     CASE WHEN r.premier_non_lu_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'premier_id') THEN 'OK' ELSE 'ÉCHEC' END),
    (3, 'repère : curseur', COALESCE((SELECT v FROM ctx WHERE k = 'curseur_id'), '<null>'), COALESCE(r.curseur_id, '<null>'),
     CASE WHEN r.curseur_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'curseur_id') THEN 'OK' ELSE 'ÉCHEC' END),
    (30, 'repère : dernier non-lu', (SELECT v FROM ctx WHERE k = 'dernier_non_lu_id'), r.dernier_non_lu_id,
     CASE WHEN r.dernier_non_lu_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'dernier_non_lu_id') THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'repère', 'une ligne', 'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ── 4. Le repère d'une conversation dont on n'est pas membre ───────────────
DO $$
BEGIN
  PERFORM * FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'ailleurs'));
  INSERT INTO resultat VALUES (4, 'repère hors de ses conversations', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'repère hors de ses conversations', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ── 6-15. Avancer le curseur jusqu'au 3e non-lu ────────────────────────────
DO $$
DECLARE v_reste int;
BEGIN
  v_reste := marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'borne_id'));
  INSERT INTO ctx VALUES ('reste_obtenu', v_reste::text);
  INSERT INTO resultat VALUES (6, 'avancer : rend ce qui reste à lire',
    (SELECT v FROM ctx WHERE k = 'reste_attendu'), v_reste::text,
    CASE WHEN v_reste::text = (SELECT v FROM ctx WHERE k = 'reste_attendu') THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'avancer', 'un entier', 'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Le second appel, identique, ne doit rien réécrire dans `conversations`.
-- `ctid` change à chaque UPDATE, même dans la transaction ; `updated_at`
-- non (now() y est constant).
RESET ROLE;
INSERT INTO ctx SELECT 'ctid_1', ctid::text FROM conversations WHERE id = (SELECT v FROM ctx WHERE k = 'conv');
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'borne_id')); END $$;

-- ── Vérifications en postgres ──────────────────────────────────────────────
RESET ROLE;
DO $$
DECLARE
  v_conv text := (SELECT v FROM ctx WHERE k = 'conv');
  v_moi  text := (SELECT v FROM ctx WHERE k = 'moi');
  v_autre text := (SELECT v FROM ctx WHERE k = 'autre');
  v_borne timestamptz := (SELECT v FROM ctx WHERE k = 'borne_a')::timestamptz;
  n int;
  n2 int;
BEGIN
  SELECT count(*) INTO n FROM messages m
   WHERE m.conversation_id = v_conv AND m.sender_id <> v_moi
     AND m.created_at <= v_borne AND NOT COALESCE(m.data->'readBy' ? v_moi, false);
  INSERT INTO resultat VALUES (7, 'avancer : rien de non lu jusqu''à la borne', '0', n::text,
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM messages m JOIN fil_attendu f ON f.id = m.id
   WHERE f.created_at > v_borne AND NOT f.lu AND COALESCE(m.data->'readBy' ? v_moi, false);
  INSERT INTO resultat VALUES (8, 'avancer : rien de marqué au-delà de la borne', '0', n::text,
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM messages m JOIN fil_attendu f ON f.id = m.id
   WHERE f.created_at <= v_borne AND NOT f.lu
     AND (jsonb_typeof(m.data->'readAt') <> 'object' OR NOT (m.data->'readAt') ? v_moi);
  INSERT INTO resultat VALUES (9, 'avancer : readAt posé sur chaque message lu', '0 sans', n::text || ' sans',
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM messages m JOIN avant a ON a.id = m.id
   WHERE COALESCE(m.data->'readBy' ? v_autre, false) IS DISTINCT FROM a.lu_par_autre;
  INSERT INTO resultat VALUES (10, 'avancer : la lecture d''un autre membre est intacte', '0 changé', n::text || ' changé',
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*), count(*) FILTER (WHERE m.data->'deliveredAt'->v_moi IS DISTINCT FROM a.livre_a)
    INTO n2, n
    FROM messages m JOIN avant a ON a.id = m.id
   WHERE a.livre_a IS NOT NULL AND a.created_at <= v_borne;
  INSERT INTO resultat VALUES (11, 'avancer : un deliveredAt déjà posé garde son heure',
    '0 réécrit', n::text || ' réécrit sur ' || n2,
    CASE WHEN n2 = 0 THEN 'SANS OBJET' WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) INTO n FROM messages m JOIN avant a ON a.id = m.id
   WHERE a.created_at <= v_borne
     AND (SELECT count(*) FROM jsonb_array_elements_text(m.data->'deliveredTo') e WHERE e = v_moi)
         > GREATEST(1, a.occurrences_livre);
  INSERT INTO resultat VALUES (12, 'avancer : deliveredTo sans doublon ajouté', '0', n::text,
    CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  INSERT INTO resultat
  SELECT 13, 'unreadCount recalculé, pas remis à zéro',
         (SELECT v FROM ctx WHERE k = 'reste_attendu'), COALESCE(c.data->'unreadCount'->>v_moi, '<absent>'),
         CASE WHEN c.data->'unreadCount'->>v_moi = (SELECT v FROM ctx WHERE k = 'reste_attendu') THEN 'OK' ELSE 'ÉCHEC' END
    FROM conversations c WHERE c.id = v_conv;

  INSERT INTO resultat
  SELECT 14, 'lastMessageReadBy inchangé tant qu''il reste à lire',
         (SELECT v FROM ctx WHERE k = 'last_read_by_avant'), COALESCE(c.data->'lastMessageReadBy', 'null')::text,
         CASE WHEN COALESCE(c.data->'lastMessageReadBy', 'null')::text = (SELECT v FROM ctx WHERE k = 'last_read_by_avant') THEN 'OK' ELSE 'ÉCHEC' END
    FROM conversations c WHERE c.id = v_conv;

  INSERT INTO resultat
  SELECT 15, 'second appel identique : conversations non réécrite',
         (SELECT v FROM ctx WHERE k = 'ctid_1'), c.ctid::text,
         CASE WHEN c.ctid::text = (SELECT v FROM ctx WHERE k = 'ctid_1') THEN 'OK' ELSE 'ÉCHEC' END
    FROM conversations c WHERE c.id = v_conv;

  SELECT count(*) FILTER (WHERE na.message_a IS NOT NULL AND na.message_a <= v_borne AND NOT n0.is_read),
         count(*) FILTER (WHERE na.message_a IS NOT NULL AND na.message_a <= v_borne)
    INTO n, n2
    FROM notifs_avant na JOIN notifications n0 ON n0.id = na.id;
  INSERT INTO resultat VALUES (16, 'notification d''un message lu : marquée',
    '0 restée', n::text || ' restée sur ' || n2,
    CASE WHEN n2 = 0 THEN 'SANS OBJET' WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  SELECT count(*) FILTER (WHERE na.message_a > v_borne AND n0.is_read),
         count(*) FILTER (WHERE na.message_a > v_borne)
    INTO n, n2
    FROM notifs_avant na JOIN notifications n0 ON n0.id = na.id;
  INSERT INTO resultat VALUES (17, 'notification d''un message au-delà : laissée',
    '0 marquée', n::text || ' marquée sur ' || n2,
    CASE WHEN n2 = 0 THEN 'SANS OBJET' WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 18. Le repère suit le curseur ──────────────────────────────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'conv'));
  INSERT INTO resultat VALUES (18, 'repère après avancée : premier non-lu = le suivant de la borne',
    (SELECT v FROM ctx WHERE k = 'suivant_id') || ' / curseur ' || (SELECT v FROM ctx WHERE k = 'borne_id'),
    COALESCE(r.premier_non_lu_id, '<null>') || ' / curseur ' || COALESCE(r.curseur_id, '<null>'),
    CASE WHEN r.premier_non_lu_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'suivant_id')
          AND r.curseur_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'borne_id')
         THEN 'OK' ELSE 'ÉCHEC' END);
  -- Le dernier ne bouge pas quand on n'a lu qu'une partie : c'est lui que le
  -- séparateur attend.
  INSERT INTO resultat VALUES (31, 'repère après avancée partielle : dernier non-lu inchangé',
    (SELECT v FROM ctx WHERE k = 'dernier_non_lu_id'), COALESCE(r.dernier_non_lu_id, '<null>'),
    CASE WHEN r.dernier_non_lu_id IS NOT DISTINCT FROM (SELECT v FROM ctx WHERE k = 'dernier_non_lu_id')
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 19-21. Bornes et conversations refusées ───────────────────────────────
DO $$
BEGIN
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), 'id-qui-n-existe-pas');
  INSERT INTO resultat VALUES (19, 'avancer jusqu''à un message inconnu', 'refusé P0002', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN no_data_found THEN
  INSERT INTO resultat VALUES (19, 'avancer jusqu''à un message inconnu', 'refusé P0002', 'refusé P0002', 'OK');
END $$;

DO $$
BEGIN
  -- Un message qui existe, mais dans une autre conversation.
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'mixte_borne_mls'));
  INSERT INTO resultat VALUES (20, 'avancer jusqu''à un message d''une autre conversation', 'refusé P0002', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN no_data_found THEN
  INSERT INTO resultat VALUES (20, 'avancer jusqu''à un message d''une autre conversation', 'refusé P0002', 'refusé P0002', 'OK');
END $$;

DO $$
BEGIN
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'ailleurs'), 'peu-importe');
  INSERT INTO resultat VALUES (21, 'avancer dans une conversation dont on n''est pas membre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (21, 'avancer dans une conversation dont on n''est pas membre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ── 23-24. La faille : accuser au nom d'un autre membre ────────────────────
DO $$
BEGIN
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'autre'));
  INSERT INTO resultat VALUES (23, 'mark_messages_as_read au nom d''un autre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (23, 'mark_messages_as_read au nom d''un autre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  PERFORM mark_messages_as_delivered((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'autre'));
  INSERT INTO resultat VALUES (24, 'mark_messages_as_delivered au nom d''un autre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (24, 'mark_messages_as_delivered au nom d''un autre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ── 25-27. Lire jusqu'au bout, puis les anciennes RPC pour soi ─────────────
DO $$
DECLARE v_reste int;
BEGIN
  v_reste := marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'dernier_id'));
  INSERT INTO resultat VALUES (25, 'avancer jusqu''au dernier : plus rien à lire', '0', v_reste::text,
    CASE WHEN v_reste = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'conv'));
  INSERT INTO resultat VALUES (32, 'tout lu : repère vide, et le curseur a dépassé le dernier non-lu d''ouverture',
    '0 / <null> / <null> / curseur >= dernier',
    r.non_lus || ' / ' || COALESCE(r.premier_non_lu_id, '<null>') || ' / ' || COALESCE(r.dernier_non_lu_id, '<null>'),
    CASE WHEN r.non_lus = 0 AND r.premier_non_lu_id IS NULL AND r.dernier_non_lu_id IS NULL
          AND r.curseur_a >= (SELECT m.created_at FROM messages m WHERE m.id = (SELECT v FROM ctx WHERE k = 'dernier_non_lu_id'))
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 26, 'tout lu : je rejoins lastMessageReadBy', 'contient', COALESCE(c.data->'lastMessageReadBy', 'null')::text,
       CASE WHEN c.data->'lastMessageReadBy' ? (SELECT v FROM ctx WHERE k = 'moi') THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k = 'conv');
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
  PERFORM mark_messages_as_delivered((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
  INSERT INTO resultat VALUES (27, 'anciennes RPC pour soi : toujours acceptées', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (27, 'anciennes RPC pour soi : toujours acceptées', 'accepté', 'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ── 5, 22. anon n'exécute rien ─────────────────────────────────────────────
RESET ROLE;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM * FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'conv'));
  INSERT INTO resultat VALUES (5, 'anon : repère', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'anon : repère', 'refusé', 'refusé 42501', 'OK');
END $$;
DO $$
BEGIN
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'borne_id'));
  INSERT INTO resultat VALUES (22, 'anon : avancer', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (22, 'anon : avancer', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 28-29. Conversation basculée : les deux magasins ───────────────────────
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"banc_b_1789578183874"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE r record; v_attendu int;
BEGIN
  v_attendu := (SELECT v FROM ctx WHERE k = 'mixte_legacy_non_lus')::int
             + (SELECT v FROM ctx WHERE k = 'mixte_mls_non_lus')::int;
  SELECT * INTO r FROM repere_de_lecture((SELECT v FROM ctx WHERE k = 'mixte'));
  INSERT INTO resultat VALUES (28, 'basculée : le repère compte legacy ET MLS',
    v_attendu::text || ' (' || (SELECT v FROM ctx WHERE k = 'mixte_legacy_non_lus') || ' + ' || (SELECT v FROM ctx WHERE k = 'mixte_mls_non_lus') || ')',
    r.non_lus::text,
    CASE WHEN v_attendu = 0 THEN 'SANS OBJET' WHEN r.non_lus = v_attendu THEN 'OK' ELSE 'ÉCHEC' END);

  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'mixte'), (SELECT v FROM ctx WHERE k = 'mixte_borne_mls'));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (28, 'basculée', 'sans erreur', 'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 29, 'basculée : borne MLS, legacy antérieurs lus, lastMessageReadBy intact',
       '0 non lu / ' || (SELECT v FROM ctx WHERE k = 'mixte_last_read_by'),
       (SELECT count(*) FROM messages m
         WHERE m.conversation_id = c.id AND m.sender_id <> 'banc_b_1789578183874'
           AND NOT COALESCE(m.data->'readBy' ? 'banc_b_1789578183874', false))::text
         || ' non lu / ' || COALESCE(c.data->'lastMessageReadBy', 'null')::text,
       CASE WHEN (SELECT count(*) FROM messages m
                   WHERE m.conversation_id = c.id AND m.sender_id <> 'banc_b_1789578183874'
                     AND NOT COALESCE(m.data->'readBy' ? 'banc_b_1789578183874', false)) = 0
             AND COALESCE(c.data->'lastMessageReadBy', 'null')::text = (SELECT v FROM ctx WHERE k = 'mixte_last_read_by')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k = 'mixte');

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
