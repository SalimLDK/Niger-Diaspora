-- Banc : écrire dans une conversation exige d'en être participant
-- (migration 20260920214800).
--
--   supabase db query --linked -f tools/rls_tests/messages_insert_participant.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : lancé tel quel AVANT la
-- migration, les cas 1, 3 et 5 tombent — vérifié à l'écriture, le 2026-09-20.
-- Les autres passaient déjà : ils gardent la non-régression (un participant
-- écrit toujours, l'usurpation de `sender_id` reste refusée, le serveur écrit
-- toujours ses notices).
--
-- AUCUNE NOTIFICATION N'EST CRÉÉE, et ce n'est pas laissé au `ROLLBACK` :
-- `notify_recipients_on_message_insert` insère dans `notifications`, dont
-- `trg_notify_push` envoie un push. Le banc n'écrit donc que dans deux
-- conversations FABRIQUÉES ici, sans destinataire possible :
--   · A, dont le seul participant est l'expéditeur — le déclencheur saute
--     l'expéditeur (c'est le cas « Mes notes ») ;
--   · B, dont le seul participant est un identifiant qui n'existe pas — le
--     déclencheur sort dès que l'expéditeur n'est pas participant, et ne
--     notifierait de toute façon pas un compte absent de `users`.
-- Le cas 10 le vérifie au lieu de le supposer : aucune ligne de
-- `notifications` ne désigne l'une des deux conversations fabriquées. (Compter
-- la table entière donnerait un faux échec dès qu'une vraie notification
-- arriverait pendant le banc.)

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',    '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('autre',  'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('conv_a', 'banc-1.3-a-' || gen_random_uuid()::text),
  ('conv_b', 'banc-1.3-b-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by)
SELECT v, 'individual', ARRAY[(SELECT v FROM ctx WHERE k = 'moi')], (SELECT v FROM ctx WHERE k = 'moi')
  FROM ctx WHERE k = 'conv_a';

INSERT INTO public.conversations (id, type, participant_ids, created_by)
SELECT v, 'individual', ARRAY['banc-1.3-compte-inexistant'], 'banc-1.3-compte-inexistant'
  FROM ctx WHERE k = 'conv_b';

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'messages_insert : authenticated, et exige la participation',
       'authenticated + is_conversation_participant',
       array_to_string(roles, ',') || ' | ' || with_check,
       CASE WHEN roles = ARRAY['authenticated']::name[]
             AND with_check ~ 'is_conversation_participant'
             AND with_check ~ 'sender_id'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'messages_insert';

-- ═══ 2. Compte connecté ═════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m2', (SELECT v FROM ctx WHERE k = 'conv_a'),
          (SELECT v FROM ctx WHERE k = 'moi'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (2, 'participant : écrit dans sa conversation', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'participant : écrit dans sa conversation', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m3', (SELECT v FROM ctx WHERE k = 'conv_b'),
          (SELECT v FROM ctx WHERE k = 'moi'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (3, 'NON participant : écrit dans la conversation d''autrui',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (3, 'NON participant : écrit dans la conversation d''autrui',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m4', (SELECT v FROM ctx WHERE k = 'conv_a'),
          (SELECT v FROM ctx WHERE k = 'autre'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (4, 'participant : signe du nom d''un autre', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'participant : signe du nom d''un autre', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.messages
   WHERE conversation_id = (SELECT v FROM ctx WHERE k = 'conv_a');
  INSERT INTO resultat VALUES (9, 'participant : relit ce qu''il vient d''écrire', '1 message',
    n || ' message(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'participant : relit ce qu''il vient d''écrire', '1 message',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m6', 'banc-1.3-conversation-inexistante',
          (SELECT v FROM ctx WHERE k = 'moi'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (6, 'conversation inexistante', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION
  WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (6, 'conversation inexistante', 'refusé', 'refusé 42501 (policy)', 'OK');
  WHEN foreign_key_violation THEN
    INSERT INTO resultat VALUES (6, 'conversation inexistante', 'refusé', 'refusé 23503 (clé étrangère)', 'OK');
END $$;

-- ── Le cas qui a motivé la migration : l'exclu qui a gardé l'identifiant ────
RESET ROLE;
UPDATE public.conversations
   SET participant_ids = ARRAY['banc-1.3-compte-inexistant']
 WHERE id = (SELECT v FROM ctx WHERE k = 'conv_a');
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m5', (SELECT v FROM ctx WHERE k = 'conv_a'),
          (SELECT v FROM ctx WHERE k = 'moi'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (5, 'EXCLU : écrit encore dans la conversation qu''il a quittée',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'EXCLU : écrit encore dans la conversation qu''il a quittée',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ 3. Anonyme ═════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims = '{"role":"anon"}';
SET LOCAL ROLE anon;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m7', (SELECT v FROM ctx WHERE k = 'conv_b'),
          (SELECT v FROM ctx WHERE k = 'moi'), 'text', '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (7, 'anonyme : écrit un message', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, 'anonyme : écrit un message', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ 4. Serveur ═════════════════════════════════════════════════════════════
-- Les notices de groupe sont écrites par des RPC SECURITY DEFINER, donc sous
-- le rôle propriétaire de la table — celui de cette session. `type = 'system'`
-- fait sortir le déclencheur de notification à sa première ligne.
DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
  VALUES ('banc-1.3-m8', (SELECT v FROM ctx WHERE k = 'conv_b'), 'system', 'system',
          '{"content":"banc"}'::jsonb);
  INSERT INTO resultat VALUES (8, 'serveur : écrit toujours une notice (propriétaire, hors RLS)',
    'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'serveur : écrit toujours une notice (propriétaire, hors RLS)',
    'accepté', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

INSERT INTO resultat
SELECT 10, 'aucune notification créée par le banc', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications n
 WHERE n.data->>'conversationId' IN (SELECT v FROM ctx WHERE k IN ('conv_a', 'conv_b'));

-- ═══ Rapport ════════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
