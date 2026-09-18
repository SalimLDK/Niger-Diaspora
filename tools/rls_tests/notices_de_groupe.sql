-- Banc des notices de groupe écrites par le serveur.
--
--   supabase db query --linked -f tools/rls_tests/notices_de_groupe.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`, y compris
-- les rares lignes que le banc fabrique lui-même (cas 13).
--
-- ⚠️ **Suppose la migration `20260917013200_notices_de_groupe_ecrites_par_le_
-- serveur.sql` appliquée.** Avant `db push`, le banc échoue au cas 0b sur
-- « fonction absente » — c'est le témoin, pas une régression.
--
-- CE QUE LE BANC ÉTABLIT
-- `tools/rls_tests/retrait_membre_groupe.sql` a montré qu'aucune notice ne
-- peut venir du client : `messages_insert` exige `firebase_uid() = sender_id`,
-- et `messages_refuse_conversation_mls_trg` refuse avant même sur une
-- conversation basculée. Les trois RPC mesurées ici la posent côté serveur, et
-- font au passage ce que le client ne faisait pas :
--   · l'exclusion sort la personne de `group_members` MÊME quand elle n'était
--     pas dans `participant_ids` (cas 13) — sinon elle restait membre ;
--   · promouvoir/rétrograder écrit `group_members.role` EN PLUS de
--     `data.adminIds` (cas 7 à 9). Les deux listes divergent déjà en
--     production : le cas 0a le mesure sur des données réelles.
--
-- La notice n'existe QUE hors MLS (cas 12) : en clair dans une conversation
-- chiffrée, elle dirait au serveur ce que le chiffrement lui tait.
--
-- Données réelles relevées le 2026-09-17 — si elles disparaissent, relever une
-- conversation de GROUPE **non basculée** (`mls_since IS NULL`, `group_id`
-- UUID) avec un admin dans `data.adminIds` et au moins deux simples membres :
--   SELECT c.id, c.group_id, c.participant_ids, c.data->'adminIds'
--     FROM conversations c
--    WHERE c.mls_since IS NULL AND c.type = 'group'
--      AND c.group_id ~ '^[0-9a-f-]{36}$';

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated;

INSERT INTO ctx VALUES
  -- Groupe officiel « Diaspora Niger — Algérie », en clair, 5 participants.
  ('conv',       '392e2aab-1f01-4807-a07b-a52ccfee6871'),
  ('groupe',     'b21e8f5a-faca-4c89-9ef3-650234187161'),
  -- Admin de la CONVERSATION (`data.adminIds`), simple `member` dans
  -- `group_members` : la divergence que les RPC rattrapent.
  ('admin',      'I54Ixk7LrcXGxQMP9BbZrjUxewC3'),   -- Nasara Assouman
  ('cible',      'mzi52ZtZlWWQnRoEI5Dr3bN3dtF2'),   -- Hocine Djalab
  ('promu',      'UV9flhFfIbUlVr0yoeYBUE1O2mH3'),   -- Tchandikou
  ('createur',   'czk5UoUclLOFmbRtUIZ5XYLYKo52'),   -- owner, display_name NULL
  ('hors_conv',  'vQZE49dTdyRtLwSG6lMIbhAqoFG2'),   -- Sim A, étranger au groupe
  -- superAdmin plateforme, étranger à ce groupe officiel.
  ('super',      'U64HKfrjM5NwR6HO00XPKo6168z2'),   -- Salim L.
  -- Groupe « Testeurs », basculé en MLS.
  ('conv_mls',   'd41d4ea0-cc03-4f23-9bc2-9b4987989658'),
  ('groupe_mls', '90a2baa1-3927-4b21-97ac-5907002ed75d'),
  ('admin_mls',  'U64HKfrjM5NwR6HO00XPKo6168z2'),
  ('cible_mls',  'vQZE49dTdyRtLwSG6lMIbhAqoFG2');

-- Sert de borne : tout `messages` système apparu après appartient au banc.
INSERT INTO ctx SELECT 'systemes_avant', count(*)::text
  FROM messages WHERE sender_id = 'system' OR type = 'system';

-- ═══ 0. Préalables ══════════════════════════════════════════════════════════

INSERT INTO resultat
SELECT 0, '0a. conversation en clair, et adminIds divergent de group_members.role',
       'mls_since NULL, admin dans adminIds mais role=member, 2 autres membres',
       'mls_since=' || COALESCE(c.mls_since::text, 'NULL')
         || ' adminIds=' || COALESCE(c.data->>'adminIds', 'NULL')
         || ' role(admin)=' || COALESCE((SELECT gm.role FROM group_members gm
              WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                AND gm.user_id = (SELECT v FROM ctx WHERE k='admin')), '<absent>'),
       CASE WHEN c.mls_since IS NULL
             AND c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='admin')
             AND c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='cible'),
                                            (SELECT v FROM ctx WHERE k='promu')]
             AND NOT c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='cible')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

INSERT INTO resultat
SELECT 0, '0b. les trois RPC existent, et rien de `private` n''est exécutable par le client',
       '3 RPC publiques exécutables par authenticated, 0 fonction private accordée',
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('exclure_du_groupe','nommer_admin_du_groupe','retirer_admin_du_groupe')
           AND has_function_privilege('authenticated', p.oid, 'EXECUTE'))::text
         || ' publique(s) / '
         || (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'private'
                AND p.proname IN ('uuid_de_groupe','conversation_de_groupe_a_gerer',
                                  'est_createur_du_groupe','poser_notice_de_groupe')
                AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
                  OR has_function_privilege('anon', p.oid, 'EXECUTE')))::text
         || ' private accordée(s)',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public'
                     AND p.proname IN ('exclure_du_groupe','nommer_admin_du_groupe','retirer_admin_du_groupe')
                     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')) = 3
             AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'private'
                     AND p.proname IN ('uuid_de_groupe','conversation_de_groupe_a_gerer',
                                       'est_createur_du_groupe','poser_notice_de_groupe')
                     AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
                       OR has_function_privilege('anon', p.oid, 'EXECUTE'))) = 0
            THEN 'OK' ELSE 'ÉCHEC' END;

-- Ce que la notice ne doit PAS bouger : une action de gestion ne remonte pas
-- la discussion dans la liste.
INSERT INTO ctx
SELECT 'apercu_avant',
       COALESCE(last_message_at::text, 'NULL') || ' | ' || COALESCE(data->>'lastMessage', 'NULL')
  FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');

-- ═══ Témoin : un simple membre ne peut rien ═════════════════════════════════

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000cc","app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  PERFORM exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='promu'));
  INSERT INTO resultat VALUES (1, 'un simple membre n''exclut personne', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'un simple membre n''exclut personne', 'refusé 42501',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 60),
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM nommer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='promu'));
  INSERT INTO resultat VALUES (1, 'un simple membre ne nomme pas d''admin', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'un simple membre ne nomme pas d''admin', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ L'administrateur de la conversation ════════════════════════════════════

RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (2, 'rôle et identité simulés', 'authenticated / I54Ixk7…',
  current_user || ' / ' || COALESCE(firebase_uid(), '<null>'),
  CASE WHEN current_user = 'authenticated' AND firebase_uid() = 'I54Ixk7LrcXGxQMP9BbZrjUxewC3'
       THEN 'OK' ELSE 'ÉCHEC' END);

-- ── 3. On ne se gère pas soi-même, et le créateur est intouchable ───────────
DO $$
BEGIN
  PERFORM exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='admin'));
  INSERT INTO resultat VALUES (3, 'un admin ne s''exclut pas lui-même', 'refusé 22023', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'un admin ne s''exclut pas lui-même', 'refusé 22023',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='createur'));
  INSERT INTO resultat VALUES (3, 'le créateur du groupe n''est pas exclu', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'le créateur du groupe n''est pas exclu', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM retirer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='createur'));
  INSERT INTO resultat VALUES (3, 'le créateur reste administrateur', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'le créateur reste administrateur', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
BEGIN
  PERFORM nommer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='hors_conv'));
  INSERT INTO resultat VALUES (3, 'on ne nomme pas admin un étranger au groupe', 'refusé 22023', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'on ne nomme pas admin un étranger au groupe', 'refusé 22023',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '22023' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 4. L'exclusion, avec sa notice ─────────────────────────────────────────
DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='cible'));
  INSERT INTO resultat VALUES (4, 'l''admin exclut le membre', 'true', v_ok::text,
    CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'l''admin exclut le membre', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;

INSERT INTO resultat
SELECT 4, 'le membre exclu sort de participant_ids ET de group_members',
       'absent des deux',
       'participant_ids=' || (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='cible')])::text
         || ' group_members=' || EXISTS (SELECT 1 FROM group_members gm
              WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                AND gm.user_id = (SELECT v FROM ctx WHERE k='cible'))::text,
       CASE WHEN NOT (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='cible')])
             AND NOT EXISTS (SELECT 1 FROM group_members gm
                  WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                    AND gm.user_id = (SELECT v FROM ctx WHERE k='cible'))
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

INSERT INTO resultat
SELECT 4, 'une notice, système des deux côtés, nommant l''acteur et la cible',
       '1 ligne · sender_id=system · type=system · « Nasara Assouman a retiré Hocine Djalab du groupe » · evenement.type=membre_retire',
       COALESCE(count(*)::text, '0') || ' ligne(s)'
         || COALESCE(' · ' || max(m.sender_id) || '/' || max(m.type)
              || ' · « ' || max(m.data->>'content') || ' »'
              || ' · evenement.type=' || COALESCE(max(m.data->'evenement'->>'type'), '<absent>')
              || ' · acteurId=' || COALESCE(max(m.data->'evenement'->>'acteurId'), '<absent>')
              || ' · cibleId=' || COALESCE(max(m.data->'evenement'->>'cibleId'), '<absent>'), ''),
       CASE WHEN count(*) = 1
             AND max(m.sender_id) = 'system' AND max(m.type) = 'system'
             AND max(m.data->>'content') = 'Nasara Assouman a retiré Hocine Djalab du groupe'
             AND max(m.data->'evenement'->>'type') = 'membre_retire'
             AND max(m.data->'evenement'->>'acteurId') = (SELECT v FROM ctx WHERE k='admin')
             AND max(m.data->'evenement'->>'cibleId') = (SELECT v FROM ctx WHERE k='cible')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv') AND m.sender_id = 'system';

-- ── 5. La notice ne remonte pas la discussion ──────────────────────────────
INSERT INTO resultat
SELECT 5, 'l''aperçu de la liste des discussions est inchangé',
       (SELECT v FROM ctx WHERE k='apercu_avant'),
       COALESCE(c.last_message_at::text, 'NULL') || ' | ' || COALESCE(c.data->>'lastMessage', 'NULL'),
       CASE WHEN COALESCE(c.last_message_at::text, 'NULL') || ' | ' || COALESCE(c.data->>'lastMessage', 'NULL')
                 = (SELECT v FROM ctx WHERE k='apercu_avant')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

-- ── 6. La notice ne compte pas comme non lu, pour personne ─────────────────
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000dd","app_metadata":{"firebase_uid":"UV9flhFfIbUlVr0yoeYBUE1O2mH3"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat
SELECT 6, 'repere_de_lecture ignore la notice (aucun non-lu, aucun curseur dessus)',
       'premier_non_lu_id <> l''id de la notice',
       'premier_non_lu=' || COALESCE(r.premier_non_lu_id, 'NULL') || ' non_lus=' || r.non_lus,
       CASE WHEN r.premier_non_lu_id IS NULL
             OR r.premier_non_lu_id NOT IN (SELECT m.id FROM messages m
                  WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv') AND m.sender_id = 'system')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM repere_de_lecture((SELECT v FROM ctx WHERE k='conv')) r;

-- ── 7. Le membre exclu ne lit pas la notice ────────────────────────────────
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000cc","app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat
SELECT 7, 'l''exclu ne voit pas la notice de son exclusion (messages_select)',
       '0 ligne visible', count(*) || ' ligne(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv') AND m.sender_id = 'system';

-- ── 8. Rappel de l'action : rien à faire, pas de seconde notice ────────────
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='cible'));
  INSERT INTO resultat VALUES (8, 'second appel : plus personne à retirer', 'false', v_ok::text,
    CASE WHEN NOT v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'second appel : plus personne à retirer', 'false',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 8, 'et toujours UNE seule notice d''exclusion', '1 ligne', count(*) || ' ligne(s)',
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv')
   AND m.data->'evenement'->>'type' = 'membre_retire';

-- ── 9. Nommer admin : les DEUX listes, et la notice ────────────────────────
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := nommer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='promu'));
  INSERT INTO resultat VALUES (9, 'l''admin nomme un membre admin', 'true', v_ok::text,
    CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'l''admin nomme un membre admin', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 9, 'le promu est admin des DEUX côtés (adminIds ET group_members.role)',
       'adminIds=true role=admin',
       'adminIds=' || (c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='promu'))::text
         || ' role=' || COALESCE((SELECT gm.role FROM group_members gm
              WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                AND gm.user_id = (SELECT v FROM ctx WHERE k='promu')), '<absent>'),
       CASE WHEN c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='promu')
             AND (SELECT gm.role FROM group_members gm
                   WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                     AND gm.user_id = (SELECT v FROM ctx WHERE k='promu')) = 'admin'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

INSERT INTO resultat
SELECT 9, 'la notice de promotion nomme les deux personnes',
       '1 ligne · « Nasara Assouman a nommé Tchandikou admin »',
       count(*) || ' ligne(s) · « ' || COALESCE(max(m.data->>'content'), '<aucune>') || ' »',
       CASE WHEN count(*) = 1
             AND max(m.data->>'content') = 'Nasara Assouman a nommé Tchandikou admin'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv')
   AND m.data->'evenement'->>'type' = 'admin_nomme';

-- ── 10. La divergence rattrapée : déjà dans adminIds, encore `member` ──────
-- `admin` (l'appelant) est lui-même dans ce cas ; on le fait rattraper par le
-- superAdmin plateforme, qui a le droit sur un groupe officiel — et dont la
-- notice doit nommer « Diaspo Niger », pas son compte personnel.
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000ee","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := nommer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='admin'));
  INSERT INTO resultat VALUES (10, 'le superAdmin rattrape un admin resté `member`', 'true', v_ok::text,
    CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'le superAdmin rattrape un admin resté `member`', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 10, 'group_members.role rejoint adminIds', 'admin',
       COALESCE((SELECT gm.role FROM group_members gm
                  WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                    AND gm.user_id = (SELECT v FROM ctx WHERE k='admin')), '<absent>'),
       CASE WHEN (SELECT gm.role FROM group_members gm
                   WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                     AND gm.user_id = (SELECT v FROM ctx WHERE k='admin')) = 'admin'
            THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat
SELECT 10, 'la notice du superAdmin nomme le groupe officiel, pas son compte',
       'acteurNom=Diaspo Niger, acteurId=czk5UoU… (le créateur)',
       'acteurNom=' || COALESCE(m.data->'evenement'->>'acteurNom', '<absent>')
         || ' acteurId=' || COALESCE(m.data->'evenement'->>'acteurId', '<absent>'),
       CASE WHEN m.data->'evenement'->>'acteurNom' = 'Diaspo Niger'
             AND m.data->'evenement'->>'acteurId' = (SELECT v FROM ctx WHERE k='createur')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv')
   AND m.data->'evenement'->>'type' = 'admin_nomme'
   AND m.data->'evenement'->>'cibleId' = (SELECT v FROM ctx WHERE k='admin');

-- ── 11. Retirer le rôle d'admin ────────────────────────────────────────────
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000ee","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := retirer_admin_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='promu'));
  INSERT INTO resultat VALUES (11, 'le rôle d''admin est retiré', 'true', v_ok::text,
    CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'le rôle d''admin est retiré', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 11, 'le rétrogradé quitte les DEUX listes', 'adminIds=false role=member',
       'adminIds=' || (c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='promu'))::text
         || ' role=' || COALESCE((SELECT gm.role FROM group_members gm
              WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                AND gm.user_id = (SELECT v FROM ctx WHERE k='promu')), '<absent>'),
       CASE WHEN NOT (c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='promu'))
             AND (SELECT gm.role FROM group_members gm
                   WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                     AND gm.user_id = (SELECT v FROM ctx WHERE k='promu')) = 'member'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

INSERT INTO resultat
SELECT 11, 'la notice de rétrogradation est écrite', '1 ligne · « Diaspo Niger a retiré le rôle d''admin à Tchandikou »',
       count(*) || ' ligne(s) · « ' || COALESCE(max(m.data->>'content'), '<aucune>') || ' »',
       CASE WHEN count(*) = 1
             AND max(m.data->>'content') = 'Diaspo Niger a retiré le rôle d''admin à Tchandikou'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv')
   AND m.data->'evenement'->>'type' = 'admin_retire';

-- ── 12. Un membre absent de participant_ids est quand même exclu ───────────
-- Le cas que le chemin direct rate en silence : présent dans `group_members`,
-- jamais entré dans la discussion. La ligne est fabriquée ici, et annulée
-- avec le reste par le ROLLBACK.
INSERT INTO group_members (group_id, user_id, role, joined_at)
VALUES ((SELECT v FROM ctx WHERE k='groupe')::uuid, (SELECT v FROM ctx WHERE k='hors_conv'), 'member', now());

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000ee","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := exclure_du_groupe((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='hors_conv'));
  INSERT INTO resultat VALUES (12, 'un membre jamais entré dans la discussion est exclu quand même', 'true',
    v_ok::text, CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'un membre jamais entré dans la discussion est exclu quand même', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 12, 'sa ligne group_members a disparu', '0 ligne', count(*) || ' ligne(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM group_members gm
 WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
   AND gm.user_id = (SELECT v FROM ctx WHERE k='hors_conv');

-- ═══ 13. En MLS : l'action a lieu, la notice NON ════════════════════════════

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000ee","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_ok boolean;
BEGIN
  v_ok := exclure_du_groupe((SELECT v FROM ctx WHERE k='conv_mls'), (SELECT v FROM ctx WHERE k='cible_mls'));
  INSERT INTO resultat VALUES (13, 'dans un groupe basculé, l''exclusion aboutit', 'true', v_ok::text,
    CASE WHEN v_ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'dans un groupe basculé, l''exclusion aboutit', 'true',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 13, 'et AUCUNE notice n''est écrite en clair dans la conversation chiffrée',
       '0 ligne', count(*) || ' ligne(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages m
 WHERE m.conversation_id = (SELECT v FROM ctx WHERE k='conv_mls')
   AND (m.sender_id = 'system' OR m.type = 'system');

INSERT INTO resultat
SELECT 13, 'le membre est bien parti du groupe basculé', 'absent des deux',
       'participant_ids=' || (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='cible_mls')])::text
         || ' group_members=' || EXISTS (SELECT 1 FROM group_members gm
              WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe_mls')::uuid
                AND gm.user_id = (SELECT v FROM ctx WHERE k='cible_mls'))::text,
       CASE WHEN NOT (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='cible_mls')])
             AND NOT EXISTS (SELECT 1 FROM group_members gm
                  WHERE gm.group_id = (SELECT v FROM ctx WHERE k='groupe_mls')::uuid
                    AND gm.user_id = (SELECT v FROM ctx WHERE k='cible_mls'))
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv_mls');

-- ═══ 14. Décompte : le banc n'a écrit que les notices attendues ═════════════
--
-- Cinq, toutes dans la conversation EN CLAIR : l'exclusion (cas 4), les deux
-- promotions (cas 9 et 10), la rétrogradation (cas 11), et l'exclusion du
-- membre jamais entré (cas 12). Le groupe basculé n'en a produit aucune.

INSERT INTO resultat
SELECT 14, 'total des messages système : les 5 notices du banc, et rien de plus',
       ((SELECT v FROM ctx WHERE k='systemes_avant')::int + 5)::text,
       count(*)::text,
       CASE WHEN count(*) = (SELECT v FROM ctx WHERE k='systemes_avant')::int + 5
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages WHERE sender_id = 'system' OR type = 'system';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
