-- Banc : une mention (`messageMention`) est lue avec la discussion qui la porte.
--
--   supabase db query --linked -f tools/rls_tests/mentions_lues_avec_la_discussion.sql
--
-- Condition : 0 cas en ÉCHEC (« SANS OBJET » est admis : la donnée réelle ne
-- porte pas toujours le cas). Tout est dans un `BEGIN … ROLLBACK` — le banc
-- écrit sur de vraies lignes de production puis annule tout.
--
-- AVANT `db push`, pour éprouver
-- `20260919120000_mentions_lues_avec_la_discussion.sql` : coller son contenu à
-- la place de la ligne `-- @@MIGRATION@@` ci-dessous (le `ROLLBACK` final
-- l'annule avec le reste). SANS la migration, les cas 1, 2, 9 et 14 DOIVENT
-- tomber : c'est ce qui prouve que le banc sait échouer.
--
-- La migration est APPLIQUÉE (relevé en base le 2026-09-20). Le banc tel quel,
-- sans rien coller, prouve alors l'état VIVANT : 21 cas, 0 ÉCHEC — c'est ce qui
-- a été fait ce jour-là. Un ÉCHEC sur les cas 1, 2, 9 ou 14 y voudrait dire que
-- les fonctions ont été redéfinies depuis, sans `messageMention`.
--
-- AUCUNE NOTIFICATION N'EST CRÉÉE : `trg_notify_push` (AFTER INSERT) enverrait
-- un vrai push. Il n'existe encore aucune ligne `messageMention` en base ; le
-- banc RECLASSE donc des lignes `message` non lues déjà présentes — un `UPDATE`
-- de `type` ne déclenche rien (vérifié : `trg_notify_push` est le seul
-- déclencheur de `notifications`, et il est AFTER INSERT).
--
-- `SET LOCAL ROLE authenticated` est indispensable : `db query --linked` se
-- connecte en `postgres`, qui contourne la RLS. Les états ATTENDUS sont
-- calculés en `postgres`, depuis les dates des messages, par une requête
-- indépendante des fonctions testées.
--
-- Les données sont choisies À L'EXÉCUTION, aucun identifiant n'est écrit ici :
-- un compte qui a au moins 6 notifications `message` non lues, sur des
-- messages en clair de dates toutes distinctes, dans une discussion où il est
-- participant — plus un témoin dans une autre conversation et un témoin chez
-- un autre membre. S'il n'y en a plus, le banc le dit (SANS OBJET).
--
-- Plan du fil du compte, par ordre de date de message :
--   rang 1        A1 : mention, AVANT la borne        → lue
--   rang 2        A2 : message simple, avant la borne → lue      (régression)
--   rang 3        A3 : mention SUR la borne (incluse) → lue
--   rang total-1  F  : message simple, après          → laissée  (régression)
--   rang total    B  : mention, APRÈS la borne        → laissée
--   C : mention du même compte dans une AUTRE conversation     → laissée
--   D : mention d'un AUTRE membre dans la même conversation     → laissée

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat TO authenticated, anon;
GRANT ALL ON ctx TO authenticated, anon;

-- ═══ Attributs des deux fonctions AVANT la migration ═════════════════════════
INSERT INTO ctx
SELECT 'avant_' || p.proname,
       p.prosecdef::text || '|' || COALESCE(p.proconfig::text, '') || '|'
         || COALESCE(p.proacl::text, '') || '|' || pg_get_userbyid(p.proowner)
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('mark_messages_as_read', 'marquer_lus_jusqua');

-- @@MIGRATION@@

-- Vérifie l'état lu/non lu d'une notification repérée par sa clé de `ctx`.
CREATE FUNCTION pg_temp.verifier(p_n int, p_cas text, p_attendu boolean, p_cle text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_lu boolean;
BEGIN
  SELECT n.is_read INTO v_lu FROM notifications n
   WHERE n.id::text = (SELECT v FROM ctx WHERE k = p_cle);
  INSERT INTO resultat VALUES (p_n, p_cas,
    CASE WHEN p_attendu THEN 'lue' ELSE 'non lue' END,
    CASE WHEN v_lu IS NULL THEN 'introuvable' WHEN v_lu THEN 'lue' ELSE 'non lue' END,
    CASE WHEN v_lu IS NOT DISTINCT FROM p_attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Choix des données et reclassement, en postgres ═════════════════════════
DO $$
DECLARE
  v_moi  text;
  v_conv text;
  v_reclassees int;
BEGIN
  SELECT s.user_id, s.conv INTO v_moi, v_conv
    FROM (
      SELECT n.user_id, n.data->>'conversationId' AS conv, count(*) AS nb
        FROM notifications n
        JOIN messages m ON m.id = n.data->>'messageId'
                       AND m.conversation_id = n.data->>'conversationId'
        JOIN conversations c ON c.id = n.data->>'conversationId'
                            AND n.user_id = ANY (c.participant_ids)
       WHERE n.type = 'message' AND NOT n.is_read AND m.sender_id <> n.user_id
       GROUP BY 1, 2
      HAVING count(*) >= 6 AND count(DISTINCT m.created_at) = count(*)
    ) s
   WHERE EXISTS (SELECT 1 FROM notifications n2
                  WHERE n2.user_id = s.user_id AND n2.type = 'message' AND NOT n2.is_read
                    AND n2.data->>'conversationId' <> s.conv)
     AND EXISTS (SELECT 1 FROM notifications n3
                  WHERE n3.user_id <> s.user_id AND n3.type = 'message' AND NOT n3.is_read
                    AND n3.data->>'conversationId' = s.conv)
   ORDER BY s.nb, s.user_id
   LIMIT 1;

  IF v_moi IS NULL THEN
    INSERT INTO resultat VALUES (0, 'données réelles pour le banc',
      'un compte, une discussion, deux témoins', 'aucune', 'SANS OBJET');
    RETURN;
  END IF;
  INSERT INTO ctx VALUES ('moi', v_moi), ('conv', v_conv);

  CREATE TEMP TABLE fil AS
  SELECT n.id AS nid, n.data->>'messageId' AS mid, m.created_at AS a,
         row_number() OVER (ORDER BY m.created_at, n.id) AS rang,
         count(*) OVER () AS total
    FROM notifications n
    JOIN messages m ON m.id = n.data->>'messageId' AND m.conversation_id = v_conv
   WHERE n.user_id = v_moi AND n.type = 'message' AND NOT n.is_read
     AND n.data->>'conversationId' = v_conv AND m.sender_id <> v_moi;

  INSERT INTO ctx SELECT 'borne_id', mid FROM fil WHERE rang = 3;
  INSERT INTO ctx SELECT 'borne_a',  a::text FROM fil WHERE rang = 3;
  INSERT INTO ctx SELECT 'nid_a1', nid::text FROM fil WHERE rang = 1;
  INSERT INTO ctx SELECT 'nid_a2', nid::text FROM fil WHERE rang = 2;
  INSERT INTO ctx SELECT 'nid_a3', nid::text FROM fil WHERE rang = 3;
  INSERT INTO ctx SELECT 'nid_f',  nid::text FROM fil WHERE rang = total - 1;
  INSERT INTO ctx SELECT 'nid_b',  nid::text FROM fil WHERE rang = total;

  INSERT INTO ctx
  SELECT 'nid_c', n.id::text FROM notifications n
   WHERE n.user_id = v_moi AND n.type = 'message' AND NOT n.is_read
     AND n.data->>'conversationId' <> v_conv
   ORDER BY n.created_at, n.id LIMIT 1;

  INSERT INTO ctx
  SELECT 'nid_d', n.id::text FROM notifications n
   WHERE n.user_id <> v_moi AND n.type = 'message' AND NOT n.is_read
     AND n.data->>'conversationId' = v_conv
   ORDER BY n.created_at, n.id LIMIT 1;
  INSERT INTO ctx
  SELECT 'user_d', n.user_id FROM notifications n
   WHERE n.id::text = (SELECT v FROM ctx WHERE k = 'nid_d');

  -- Reclassement en mentions : A1, A3, B, C, D. A2 et F restent des `message`.
  UPDATE notifications SET type = 'messageMention'
   WHERE id::text IN (SELECT v FROM ctx WHERE k IN ('nid_a1', 'nid_a3', 'nid_b', 'nid_c', 'nid_d'));
  GET DIAGNOSTICS v_reclassees = ROW_COUNT;
  INSERT INTO resultat VALUES (0, 'préparation : cinq lignes reclassées en mentions',
    '5', v_reclassees::text, CASE WHEN v_reclassees = 5 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
GRANT ALL ON fil TO authenticated;

-- ═══ Bascule en rôle applicatif : le compte ═════════════════════════════════
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000000aa',
                    'app_metadata', json_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'moi')),
                    'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- ── Lire jusqu'à la borne (chemin par curseur) ─────────────────────────────
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'borne_id'));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (0, 'marquer_lus_jusqua : appel', 'aucune erreur',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;
-- Les attendus viennent des dates, pas des fonctions : lue ⇔ message ≤ borne.
DO $$
DECLARE v_borne timestamptz;
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  v_borne := (SELECT v FROM ctx WHERE k = 'borne_a')::timestamptz;

  PERFORM pg_temp.verifier(1, 'curseur : mention AVANT la borne', (SELECT a <= v_borne FROM fil WHERE rang = 1), 'nid_a1');
  PERFORM pg_temp.verifier(2, 'curseur : mention SUR la borne (incluse)', (SELECT a <= v_borne FROM fil WHERE rang = 3), 'nid_a3');
  PERFORM pg_temp.verifier(3, 'curseur : mention APRÈS la borne laissée', (SELECT a <= v_borne FROM fil WHERE rang = total), 'nid_b');
  PERFORM pg_temp.verifier(4, 'curseur : message simple avant la borne (régression)', (SELECT a <= v_borne FROM fil WHERE rang = 2), 'nid_a2');
  PERFORM pg_temp.verifier(5, 'curseur : message simple après la borne (régression)', (SELECT a <= v_borne FROM fil WHERE rang = total - 1), 'nid_f');
  PERFORM pg_temp.verifier(6, 'curseur : mention du compte dans une AUTRE conversation', false, 'nid_c');
  PERFORM pg_temp.verifier(7, 'curseur : mention d''un AUTRE membre, même conversation', false, 'nid_d');

  INSERT INTO ctx SELECT 'etats_1',
    string_agg(n.is_read::text, ',' ORDER BY n.id::text)
    FROM notifications n
   WHERE n.id::text IN (SELECT v FROM ctx WHERE k IN ('nid_a1','nid_a2','nid_a3','nid_f','nid_b','nid_c','nid_d'));
END $$;

-- Le second appel, identique : aucune erreur, mêmes états.
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  PERFORM marquer_lus_jusqua((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'borne_id'));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'curseur : second appel identique', 'aucune erreur',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;
RESET ROLE;
DO $$
DECLARE v_apres text;
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  SELECT string_agg(n.is_read::text, ',' ORDER BY n.id::text) INTO v_apres
    FROM notifications n
   WHERE n.id::text IN (SELECT v FROM ctx WHERE k IN ('nid_a1','nid_a2','nid_a3','nid_f','nid_b','nid_c','nid_d'));
  INSERT INTO resultat VALUES (8, 'curseur : second appel identique, mêmes états',
    (SELECT v FROM ctx WHERE k = 'etats_1'), v_apres,
    CASE WHEN v_apres = (SELECT v FROM ctx WHERE k = 'etats_1') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── Lire toute la discussion (ancien chemin, et action de la bannière) ─────
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'moi'));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (0, 'mark_messages_as_read : appel', 'aucune erreur',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;
RESET ROLE;
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  PERFORM pg_temp.verifier(9,  'discussion lue : mention APRÈS l''ancienne borne', true, 'nid_b');
  PERFORM pg_temp.verifier(10, 'discussion lue : message simple (régression)', true, 'nid_f');
  PERFORM pg_temp.verifier(11, 'discussion lue : mention d''une AUTRE conversation laissée', false, 'nid_c');
  PERFORM pg_temp.verifier(12, 'discussion lue : mention d''un AUTRE membre laissée', false, 'nid_d');
END $$;

-- ── La garde d'identité recopiée avec la fonction ──────────────────────────
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'moi') IS NULL THEN RETURN; END IF;
  PERFORM mark_messages_as_read((SELECT v FROM ctx WHERE k = 'conv'), (SELECT v FROM ctx WHERE k = 'user_d'));
  INSERT INTO resultat VALUES (13, 'accuser au nom d''un autre membre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION
  WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (13, 'accuser au nom d''un autre membre', 'refusé 42501', 'refusé 42501', 'OK');
  WHEN OTHERS THEN
    INSERT INTO resultat VALUES (13, 'accuser au nom d''un autre membre', 'refusé 42501',
      'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;
RESET ROLE;

-- ── Ce que la migration ne doit PAS changer ────────────────────────────────
INSERT INTO resultat
SELECT 15, 'attributs, propriétaire et ACL inchangés : ' || p.proname, c.v,
       p.prosecdef::text || '|' || COALESCE(p.proconfig::text, '') || '|'
         || COALESCE(p.proacl::text, '') || '|' || pg_get_userbyid(p.proowner),
       CASE WHEN c.v = p.prosecdef::text || '|' || COALESCE(p.proconfig::text, '') || '|'
                    || COALESCE(p.proacl::text, '') || '|' || pg_get_userbyid(p.proowner)
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN ctx c ON c.k = 'avant_' || p.proname
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('mark_messages_as_read', 'marquer_lus_jusqua');

INSERT INTO resultat
SELECT 16, 'anon n''exécute pas, authenticated oui : ' || p.proname, 'anon=false authenticated=true',
       'anon=' || has_function_privilege('anon', p.oid, 'EXECUTE')
         || ' authenticated=' || has_function_privilege('authenticated', p.oid, 'EXECUTE'),
       CASE WHEN NOT has_function_privilege('anon', p.oid, 'EXECUTE')
             AND has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('mark_messages_as_read', 'marquer_lus_jusqua');

-- Les deux fonctions citent bien `messageMention` : c'est ce qui distingue
-- « avec » de « sans » la migration, indépendamment des données.
INSERT INTO resultat
SELECT 14, 'la définition vivante cite messageMention : ' || p.proname, 'true',
       (p.prosrc ~ 'messageMention')::text,
       CASE WHEN p.prosrc ~ 'messageMention' THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('mark_messages_as_read', 'marquer_lus_jusqua');

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
