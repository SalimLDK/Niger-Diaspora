-- Banc : écritures atomiques dans `data`, suite (migration 20261005100000).
--
--   supabase db query --linked -f tools/rls_tests/donnees_jsonb_atomiques_suite.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, le banc s'interrompt au premier appel (fonction
-- inexistante) : il ne peut pas passer à tort.
--
-- AUCUNE NOTIFICATION : messages insérés en `postgres`, dans des
-- conversations fabriquées, entre comptes fabriqués.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('conv',    'banc-suite-' || gen_random_uuid()::text),
  ('etr',     'banc-suite-etr-' || gen_random_uuid()::text),
  ('dernier', 'banc-suite-m1-' || gen_random_uuid()::text),
  ('ancien',  'banc-suite-m2-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by, data, last_message_at)
SELECT v, 'individual', ARRAY['banc-suite-moi', 'banc-suite-autre'], 'banc-suite-moi',
       '{"lastMessage":"secret","lastMessageExpired":true,
         "unreadCount":{"banc-suite-moi":5,"banc-suite-autre":2},
         "mutedBy":{"banc-suite-autre":"forever"},
         "lastMessageReadBy":["banc-suite-autre"]}'::jsonb,
       date_trunc('second', now())
  FROM ctx WHERE k = 'conv';

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT v, 'individual', ARRAY['banc-suite-autre', 'banc-suite-tiers'],
       'banc-suite-autre', '{}'::jsonb
  FROM ctx WHERE k = 'etr';

INSERT INTO public.messages (id, conversation_id, sender_id, type, data, created_at)
VALUES
  ((SELECT v FROM ctx WHERE k='dernier'), (SELECT v FROM ctx WHERE k='conv'),
   'banc-suite-moi', 'text',
   '{"content":"secret","fileUrl":"https://x/y","e2eePayloads":{"a":"vieux"},"readBy":["banc-suite-autre"]}',
   date_trunc('second', now())),
  ((SELECT v FROM ctx WHERE k='ancien'), (SELECT v FROM ctx WHERE k='conv'),
   'banc-suite-moi', 'text', '{"content":"avant"}',
   date_trunc('second', now()) - interval '1 second');

-- @@MIGRATION@@

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f2","app_metadata":{"firebase_uid":"banc-suite-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- ═══ 1. « Marquer comme lu » : ma pastille à 0, celle de l'autre gardée ═══
DO $$
DECLARE ok boolean; d jsonb;
BEGIN
  ok := modifier_donnees_conversation((SELECT v FROM ctx WHERE k='conv'),
    '{"unreadCount":{"banc-suite-moi":0}}', '{"lastMessageReadBy":"banc-suite-moi"}');
  PERFORM modifier_donnees_conversation((SELECT v FROM ctx WHERE k='conv'),
    '{"unreadCount":{"banc-suite-moi":0}}', '{"lastMessageReadBy":"banc-suite-moi"}');
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (1, 'lu : pastilles fusionnées, lecteur ajouté une fois, sourdine gardée',
    'moi=0 autre=2 lecteurs=[autre,moi] sourdine',
    format('ok=%s moi=%s autre=%s lecteurs=%s muted=%s', ok,
      d->'unreadCount'->>'banc-suite-moi', d->'unreadCount'->>'banc-suite-autre',
      d->'lastMessageReadBy', d->'mutedBy'),
    CASE WHEN ok AND d->'unreadCount' = '{"banc-suite-moi":0,"banc-suite-autre":2}'::jsonb
          AND d->'lastMessageReadBy' = '["banc-suite-autre","banc-suite-moi"]'::jsonb
          AND d->'mutedBy' = '{"banc-suite-autre":"forever"}'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 2. Le dernier message, pas encore supprimé : l'aperçu reste ══════════
DO $$
DECLARE ok boolean;
BEGIN
  ok := vider_apercu_si_dernier((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='dernier'));
  INSERT INTO resultat VALUES (2, 'message non supprimé : l''aperçu n''est pas vidé', 'false',
    ok::text, CASE WHEN NOT ok THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 3. « Supprimer pour tout le monde » : une instruction ════════════════
DO $$
DECLARE t timestamptz; d jsonb; s boolean;
BEGIN
  t := modifier_donnees_message((SELECT v FROM ctx WHERE k='dernier'),
    '{"deletedForEveryone":true,"content":""}', ARRAY['fileUrl','e2eePayloads'], '{}', true);
  SELECT data, is_deleted INTO d, s FROM messages WHERE id = (SELECT v FROM ctx WHERE k='dernier');
  INSERT INTO resultat VALUES (3, 'suppression : marques posées, annexes retirées, Lu gardé',
    'date rendue, is_deleted, content vide, fileUrl/e2ee partis, readBy gardé',
    format('t=%s suppr=%s d=%s', t IS NOT NULL, s, d),
    CASE WHEN t IS NOT NULL AND s AND d->>'content' = '' AND (d->>'deletedForEveryone')::boolean
          AND NOT d ? 'fileUrl' AND NOT d ? 'e2eePayloads'
          AND d->'readBy' = '["banc-suite-autre"]'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 4. … puis l'aperçu est vidé, avec sa raison ══════════════════════════
DO $$
DECLARE ok boolean; d jsonb;
BEGIN
  ok := vider_apercu_si_dernier((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='dernier'));
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (4, 'aperçu du dernier message supprimé : vidé',
    'ok, lastMessage vide, supprimé, plus expiré, sourdine gardée',
    format('ok=%s d=%s', ok, d),
    CASE WHEN ok AND d->>'lastMessage' = '' AND (d->>'lastMessageDeleted')::boolean
          AND NOT d ? 'lastMessageExpired'
          AND d->'mutedBy' = '{"banc-suite-autre":"forever"}'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 5. Un message supprimé qui n'est pas le dernier : rien ═══════════════
DO $$
DECLARE ok boolean;
BEGIN
  UPDATE conversations SET data = data || '{"lastMessage":"récent"}'
   WHERE id = (SELECT v FROM ctx WHERE k='conv');
  PERFORM modifier_donnees_message((SELECT v FROM ctx WHERE k='ancien'), '{}', '{}', '{}', true);
  ok := vider_apercu_si_dernier((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='ancien'));
  INSERT INTO resultat VALUES (5, 'message supprimé ancien : l''aperçu reste', 'false',
    ok::text, CASE WHEN NOT ok THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 6. Modifier : charges remplacées, historique allongé, Lu gardé ═══════
DO $$
DECLARE d jsonb;
BEGIN
  PERFORM modifier_donnees_message((SELECT v FROM ctx WHERE k='ancien'),
    '{"e2eePayloads":{"a":"neuf"},"editedAt":"t1"}', ARRAY['e2eePayloads','senderKeyPayload'],
    '{"editHistory":{"editedAt":"t1"}}');
  UPDATE messages SET data = data || '{"readBy":["banc-suite-autre"]}'
   WHERE id = (SELECT v FROM ctx WHERE k='ancien');
  PERFORM modifier_donnees_message((SELECT v FROM ctx WHERE k='ancien'),
    '{"e2eePayloads":{"a":"plus neuf"},"editedAt":"t2"}', ARRAY['e2eePayloads','senderKeyPayload'],
    '{"editHistory":{"editedAt":"t2"}}');
  SELECT data INTO d FROM messages WHERE id = (SELECT v FROM ctx WHERE k='ancien');
  INSERT INTO resultat VALUES (6, 'modification : charge neuve, 2 entrées d''historique, Lu gardé',
    'e2ee=plus neuf, historique t1,t2, readBy gardé', d::text,
    CASE WHEN d->'e2eePayloads' = '{"a":"plus neuf"}'::jsonb
          AND d->'editHistory' = '[{"editedAt":"t1"},{"editedAt":"t2"}]'::jsonb
          AND d->'readBy' = '["banc-suite-autre"]'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 7. Message inconnu : null, pas d'erreur ══════════════════════════════
INSERT INTO resultat
SELECT 7, 'message inconnu : null', 'null',
       COALESCE(t::text, 'null'), CASE WHEN t IS NULL THEN 'OK' ELSE 'ÉCHEC' END
  FROM (SELECT modifier_donnees_message('banc-suite-inexistant', '{"x":1}') AS t) s;

-- ═══ 8. Aucun droit ouvert : la conversation d'autrui reste intouchable ═══
DO $$
DECLARE ok boolean;
BEGIN
  ok := modifier_donnees_conversation((SELECT v FROM ctx WHERE k='etr'),
    '{"pirate":true}', '{"reportedBy":"banc-suite-moi"}');
  INSERT INTO resultat VALUES (8, 'conversation d''autrui : rien n''est écrit', 'false',
    ok::text, CASE WHEN NOT ok THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 9. Les trois fonctions sont SECURITY INVOKER ═════════════════════════
RESET ROLE;
INSERT INTO resultat
SELECT 9, 'trois fonctions, toutes SECURITY INVOKER', '3 / 0 definer',
       count(*) || ' / ' || count(*) FILTER (WHERE p.prosecdef) || ' definer',
       CASE WHEN count(*) = 3 AND count(*) FILTER (WHERE p.prosecdef) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('modifier_donnees_conversation', 'modifier_donnees_message',
                     'vider_apercu_si_dernier');

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
