-- Banc : `last_message_at` reprend la date du message (migration 20261005090000).
--
--   supabase db query --linked -f tools/rls_tests/apercu_date_du_message.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, le premier appel à trois arguments échoue (fonction
-- inexistante) : le banc ne peut pas passer à tort.
--
-- AUCUNE NOTIFICATION : les messages sont insérés en `postgres` dans des
-- conversations fabriquées, entre comptes fabriqués.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('conv',   'banc-apercu-' || gen_random_uuid()::text),
  ('autre_c','banc-apercu-c2-' || gen_random_uuid()::text),
  ('ancien', 'banc-apercu-m1-' || gen_random_uuid()::text),
  ('recent', 'banc-apercu-m2-' || gen_random_uuid()::text),
  ('sien',   'banc-apercu-m3-' || gen_random_uuid()::text),
  ('ailleurs','banc-apercu-m4-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT v, 'individual', ARRAY['banc-apercu-moi', 'banc-apercu-autre'],
       'banc-apercu-moi', '{}'::jsonb
  FROM ctx WHERE k IN ('conv', 'autre_c');

-- Deux messages de « moi », à une seconde d'écart : dans une transaction,
-- `now()` est le même partout, les dates sont donc posées à la main.
INSERT INTO public.messages (id, conversation_id, sender_id, type, data, created_at)
VALUES
  ((SELECT v FROM ctx WHERE k='ancien'), (SELECT v FROM ctx WHERE k='conv'),
   'banc-apercu-moi', 'text', '{"content":"premier"}', now() - interval '2 seconds'),
  ((SELECT v FROM ctx WHERE k='recent'), (SELECT v FROM ctx WHERE k='conv'),
   'banc-apercu-moi', 'text', '{"content":"second"}', now() - interval '1 second'),
  ((SELECT v FROM ctx WHERE k='sien'), (SELECT v FROM ctx WHERE k='conv'),
   'banc-apercu-autre', 'text', '{"content":"à lui"}', now()),
  ((SELECT v FROM ctx WHERE k='ailleurs'), (SELECT v FROM ctx WHERE k='autre_c'),
   'banc-apercu-moi', 'text', '{"content":"ailleurs"}', now());

-- @@MIGRATION@@

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f1","app_metadata":{"firebase_uid":"banc-apercu-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- ═══ 1. La date de l'aperçu EST celle du message ══════════════════════════
-- C'est l'égalité dont dépendent « supprimer pour tout le monde » et la
-- purge des éphémères. Avant : deux `now()` de deux requêtes, jamais égaux.
DO $$
DECLARE c timestamptz; m timestamptz;
BEGIN
  PERFORM apres_envoi_message((SELECT v FROM ctx WHERE k='conv'),
    (SELECT v FROM ctx WHERE k='recent'), '{"lastMessage":"second","lastMessageType":"text"}');
  SELECT last_message_at INTO c FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  SELECT created_at INTO m FROM messages WHERE id = (SELECT v FROM ctx WHERE k='recent');
  INSERT INTO resultat VALUES (1, 'last_message_at = created_at du message', m::text, c::text,
    CASE WHEN c = m THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 2. Un après-envoi en retard n'écrase pas l'aperçu du plus récent ═════
DO $$
DECLARE d jsonb; c timestamptz; m timestamptz;
BEGIN
  PERFORM apres_envoi_message((SELECT v FROM ctx WHERE k='conv'),
    (SELECT v FROM ctx WHERE k='ancien'), '{"lastMessage":"premier","lastMessageType":"text"}');
  SELECT data, last_message_at INTO d, c FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  SELECT created_at INTO m FROM messages WHERE id = (SELECT v FROM ctx WHERE k='recent');
  INSERT INTO resultat VALUES (2, 'retardataire : aperçu et date gardés, pastille comptée',
    'lastMessage=second, date du second, autre=2',
    format('lastMessage=%s date=%s autre=%s', d->>'lastMessage', c = m, d->'unreadCount'->>'banc-apercu-autre'),
    CASE WHEN d->>'lastMessage' = 'second' AND c = m
          AND d->'unreadCount'->>'banc-apercu-autre' = '2'
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 3. Le message d'un autre ne prête pas sa date ════════════════════════
DO $$
BEGIN
  PERFORM apres_envoi_message((SELECT v FROM ctx WHERE k='conv'),
    (SELECT v FROM ctx WHERE k='sien'), '{"lastMessage":"usurpé"}');
  INSERT INTO resultat VALUES (3, 'message d''un autre : refusé', 'refusé P0002', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN no_data_found THEN
  INSERT INTO resultat VALUES (3, 'message d''un autre : refusé', 'refusé P0002', 'refusé P0002', 'OK');
END $$;

-- ═══ 4. Ni un message d'une autre conversation ════════════════════════════
DO $$
BEGIN
  PERFORM apres_envoi_message((SELECT v FROM ctx WHERE k='conv'),
    (SELECT v FROM ctx WHERE k='ailleurs'), '{"lastMessage":"déplacé"}');
  INSERT INTO resultat VALUES (4, 'message d''une autre conversation : refusé', 'refusé P0002', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN no_data_found THEN
  INSERT INTO resultat VALUES (4, 'message d''une autre conversation : refusé', 'refusé P0002', 'refusé P0002', 'OK');
END $$;

-- ═══ 5. Le critère de « supprimer pour tout le monde » retrouve le dernier ═
-- C'est la clause WHERE de `_viderApercuSiDernier` / `purger_messages_expires`.
INSERT INTO resultat
SELECT 5, 'le dernier message est reconnu à sa date', '1 conversation', count(*) || ' conversation',
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c JOIN messages m ON m.conversation_id = c.id
 WHERE c.id = (SELECT v FROM ctx WHERE k='conv')
   AND m.id = (SELECT v FROM ctx WHERE k='recent')
   AND c.last_message_at = m.created_at;

-- ═══ 6. L'ancienne signature a disparu ════════════════════════════════════
-- Deux surcharges rendraient l'appel nommé de PostgREST ambigu.
RESET ROLE;
INSERT INTO resultat
SELECT 6, 'une seule apres_envoi_message, à trois arguments, INVOKER', '1 / 3 / invoker',
       count(*) || ' / ' || string_agg(p.pronargs::text, ',') || ' / ' ||
         CASE WHEN bool_or(p.prosecdef) THEN 'definer' ELSE 'invoker' END,
       CASE WHEN count(*) = 1 AND min(p.pronargs) = 3 AND NOT bool_or(p.prosecdef)
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'apres_envoi_message';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
