-- Banc du retrait d'un membre de groupe par un administrateur.
--
--   supabase db query --linked -f tools/rls_tests/retrait_membre_groupe.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- CE QUE LE BANC ÉTABLIT
-- `MessageSupabaseDataSource.removeUserFromGroup` commençait par
-- `sendSystemMessage`, un INSERT dans `messages` avec `sender_id = 'system'`,
-- et ne retirait la personne de `participant_ids` qu'ensuite. Cet INSERT ne
-- peut réussir NULLE PART depuis le client :
--   · la policy `messages_insert` exige `firebase_uid() = sender_id`, depuis
--     la migration 20260526270000 — aucun compte ne s'appelle `system` (cas 2) ;
--   · sur une conversation basculée en MLS, le déclencheur
--     `messages_refuse_conversation_mls_trg` refuse avant même la policy
--     (cas 1 : un BEFORE ROW passe avant le WITH CHECK).
-- L'exception remontait, et le retrait n'avait jamais lieu : « Erreur lors du
-- retrait », dans tous les groupes. Mesuré le 2026-09-17 : la table `messages`
-- ne contient AUCUNE ligne `sender_id = 'system'` ni `type = 'system'`.
--
-- Le retrait lui-même, sans le message système, passe (cas 4) et sort la
-- personne de `group_members` par `conversations_sync_group_removal` (cas 5).
-- Un simple membre ne peut toujours pas exclure (cas 3) : c'est le témoin qui
-- montre que le banc sait refuser.
--
-- AUCUNE LIGNE `messages` N'EST CRÉÉE. Le seul INSERT (cas 1) vise la
-- conversation basculée, où il doit échouer — `notify_recipients_on_message_
-- insert` enverrait sinon des notifications, et c'est pourquoi le cas 2 mesure
-- la policy au lieu de l'essayer (voir son commentaire).
--
-- Données réelles relevées le 2026-09-17 — si elles disparaissent, relever
-- une conversation de GROUPE basculée (`mls_since` posé, `group_id` UUID) avec
-- un administrateur (`data.adminIds`) et un simple membre :
--   SELECT c.id, c.group_id, c.participant_ids, c.data->'adminIds'
--     FROM conversations c
--    WHERE c.mls_since IS NOT NULL AND c.type = 'group'
--      AND c.group_id ~ '^[0-9a-f-]{36}$';

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated;

INSERT INTO ctx VALUES
  ('conv',   'd41d4ea0-cc03-4f23-9bc2-9b4987989658'),
  ('groupe', '90a2baa1-3927-4b21-97ac-5907002ed75d'),
  ('admin',  'U64HKfrjM5NwR6HO00XPKo6168z2'),
  ('membre', 'vQZE49dTdyRtLwSG6lMIbhAqoFG2');

-- ═══ Préalables, en postgres ════════════════════════════════════════════════
INSERT INTO resultat
SELECT 0, 'préalable : conversation de groupe basculée, admin et membre présents',
       'mls_since posé, 2 participants attendus, admin dans adminIds',
       'mls_since=' || COALESCE(c.mls_since::text, '<null>')
         || ' admin=' || (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='admin')])::text
         || ' membre=' || (c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='membre')])::text
         || ' adminIds=' || COALESCE(c.data->>'adminIds', '<null>'),
       CASE WHEN c.mls_since IS NOT NULL
             AND c.participant_ids @> ARRAY[(SELECT v FROM ctx WHERE k='admin'), (SELECT v FROM ctx WHERE k='membre')]
             AND c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='admin')
             AND NOT c.data->'adminIds' ? (SELECT v FROM ctx WHERE k='membre')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv');

-- ═══ L'administrateur ═══════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle et identité simulés', 'authenticated / U64HK…',
  current_user || ' / ' || COALESCE(firebase_uid(), '<null>'),
  CASE WHEN current_user = 'authenticated' AND firebase_uid() = 'U64HKfrjM5NwR6HO00XPKo6168z2' THEN 'OK' ELSE 'ÉCHEC' END);

-- ── 1. L'INSERT de `sendSystemMessage`, tel quel ────────────────────────────
DO $$
BEGIN
  INSERT INTO messages (id, conversation_id, sender_id, type, created_at, data)
  VALUES (gen_random_uuid()::text, (SELECT v FROM ctx WHERE k='conv'), 'system', 'system',
          now(), jsonb_build_object('senderName', 'Système',
            'content', 'Un utilisateur a été retiré du groupe', 'status', 'sent',
            'readBy', '[]'::jsonb, 'readAt', '{}'::jsonb, 'encryptionLevel', 'aes'));
  INSERT INTO resultat VALUES (1, 'conversation basculée : l''INSERT système est refusé', 'refusé 23514 (déclencheur MLS)', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'conversation basculée : l''INSERT système est refusé', 'refusé 23514 (déclencheur MLS)',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80),
    CASE WHEN SQLSTATE = '23514' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 2. Sans le déclencheur MLS, la policy refuse aussi ─────────────────────
-- C'est ce que rencontre une conversation NON basculée. On ne l'essaie pas
-- par un INSERT : ailleurs que sur une conversation basculée, rien ne
-- garantit l'échec, et un INSERT réussi réveille les notifications. Couper
-- les déclencheurs n'est pas possible non plus (`session_replication_role`
-- est refusé au rôle `postgres` de Supabase, 42501 — essayé). On mesure donc
-- les deux faits qui décident à la place du serveur :
--   · la policy INSERT permissive est UNIQUE (plusieurs s'additionneraient
--     en OU) et sa condition est `firebase_uid() = sender_id` ;
--   · pour l'administrateur authentifié, `firebase_uid()` n'est pas `system`.
RESET ROLE;
INSERT INTO ctx
SELECT 'policies_insert', COALESCE(string_agg(p.polname || ' ' || CASE WHEN p.polpermissive THEN 'permissive' ELSE 'restrictive' END
         || ' : ' || COALESCE(pg_get_expr(p.polwithcheck, p.polrelid), '<aucune>'), ' | '), '<aucune>')
  FROM pg_policy p
 WHERE p.polrelid = 'public.messages'::regclass AND p.polcmd IN ('a', '*');
SET LOCAL ROLE authenticated;

INSERT INTO resultat
SELECT 2, 'ailleurs, la policy refuse sender_id = ''system''',
       'une seule policy INSERT : firebase_uid() = sender_id, et firebase_uid() <> ''system''',
       (SELECT v FROM ctx WHERE k='policies_insert') || ' — firebase_uid()=' || COALESCE(firebase_uid(), '<null>'),
       CASE WHEN (SELECT v FROM ctx WHERE k='policies_insert')
                 = 'messages_insert permissive : (( SELECT firebase_uid() AS firebase_uid) = sender_id)'
             AND firebase_uid() IS NOT NULL AND firebase_uid() <> 'system'
            THEN 'OK' ELSE 'ÉCHEC' END;

RESET ROLE;
INSERT INTO resultat
SELECT 2, 'et la table n''a jamais reçu un seul message système', '0 ligne',
       count(*) || ' ligne(s)', CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages WHERE sender_id = 'system' OR type = 'system';

-- ═══ Témoin : un simple membre ne peut pas exclure l'administrateur ═════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  UPDATE conversations
     SET participant_ids = array_remove(participant_ids, (SELECT v FROM ctx WHERE k='admin'))
   WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (3, 'un simple membre n''exclut personne', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'un simple membre n''exclut personne', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ Le retrait tel que le client le fait désormais ═════════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE v_n int;
BEGIN
  WITH maj AS (
    UPDATE conversations
       SET participant_ids = array_remove(participant_ids, (SELECT v FROM ctx WHERE k='membre')),
           data = jsonb_set(data, '{adminIds}',
             COALESCE((SELECT jsonb_agg(a) FROM jsonb_array_elements_text(data->'adminIds') a
                        WHERE a <> (SELECT v FROM ctx WHERE k='membre')), '[]'::jsonb))
     WHERE id = (SELECT v FROM ctx WHERE k='conv')
    RETURNING id)
  SELECT count(*) INTO v_n FROM maj;
  INSERT INTO resultat VALUES (4, 'l''administrateur retire le membre de participant_ids', '1 ligne', v_n || ' ligne(s)',
    CASE WHEN v_n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'l''administrateur retire le membre de participant_ids', '1 ligne',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 5, 'le déclencheur de synchronisation le sort de group_members', '0 ligne', count(*) || ' ligne(s)',
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM group_members
 WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid AND user_id = (SELECT v FROM ctx WHERE k='membre');

INSERT INTO resultat
SELECT 6, 'aucune ligne messages créée par le banc', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM messages WHERE conversation_id = (SELECT v FROM ctx WHERE k='conv') AND sender_id = 'system';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
