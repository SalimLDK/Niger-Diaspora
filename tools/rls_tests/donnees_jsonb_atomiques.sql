-- Banc : écritures atomiques dans conversations.data / messages.data
-- (migration 20261004100000).
--
--   supabase db query --linked -f tools/rls_tests/donnees_jsonb_atomiques.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — puis, à la suite, de 20261005090000, qui redéfinit
-- `apres_envoi_message` (identifiant du message en plus). APRÈS, lancé tel
-- quel, le banc prouve l'état vivant.
--
-- Sans la migration, le banc s'interrompt au premier appel (fonction
-- inexistante) : il ne peut pas passer à tort. Avec : 11 OK, en local.
--
-- Ce banc vérifie le SENS de chaque fonction et qu'elles n'ouvrent aucun
-- droit (cas 9 et 10). L'ATOMICITÉ, elle, ne se voit qu'en concurrence, hors
-- transaction : mesurée sur un PostgreSQL 16 local le 2026-10-04 — 40 envois
-- simultanés de 4 participants, `unreadCount` attendu 30 chacun :
--   lire-puis-réécrire (l'ancien client) : {"a": 8, "b": 8, "c": 8, "d": 12}
--   apres_envoi_message                   : {"a": 30, "b": 30, "c": 30, "d": 30}
--
-- AUCUNE NOTIFICATION : le banc n'insère aucun message ; il modifie une
-- conversation et un message qu'il fabrique, sans destinataire réel.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',    'banc-jsonb-moi'),
  ('autre',  'banc-jsonb-autre'),
  ('tiers',  'banc-jsonb-tiers'),
  ('conv',   'banc-jsonb-' || gen_random_uuid()::text),
  ('etr',    'banc-jsonb-etr-' || gen_random_uuid()::text),
  ('msg',    'banc-jsonb-m-' || gen_random_uuid()::text),
  ('msg_moi','banc-jsonb-mm-' || gen_random_uuid()::text),
  ('msg_etr','banc-jsonb-me-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT c.v, 'individual',
       ARRAY[(SELECT v FROM ctx WHERE k='moi'), (SELECT v FROM ctx WHERE k='autre')],
       (SELECT v FROM ctx WHERE k='moi'),
       jsonb_build_object(
         'unreadCount', jsonb_build_object((SELECT v FROM ctx WHERE k='autre'), 2),
         'mutedBy', jsonb_build_object((SELECT v FROM ctx WHERE k='autre'), true),
         'lastMessageDeleted', true)
  FROM ctx c WHERE c.k = 'conv';

-- Une conversation dont « moi » n'est PAS participant (cas 9).
INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT v, 'individual',
       ARRAY[(SELECT v FROM ctx WHERE k='autre'), (SELECT v FROM ctx WHERE k='tiers')],
       (SELECT v FROM ctx WHERE k='autre'), '{}'::jsonb
  FROM ctx WHERE k = 'etr';

-- Le message est inséré en `postgres` : aucun déclencheur de notification
-- ne vise un compte réel (destinataire fabriqué).
INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
SELECT m.v, (SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='autre'),
       'text', '{"content":"banc","readBy":["banc-jsonb-autre"]}'::jsonb
  FROM ctx m WHERE m.k = 'msg';

-- Les messages que « moi » vient d'envoyer, dont l'après-envoi recopie la
-- date (20261005090000) — dont un, fabriqué, dans la conversation d'autrui.
INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
SELECT (SELECT v FROM ctx WHERE k='msg_moi'), (SELECT v FROM ctx WHERE k='conv'),
       'banc-jsonb-moi', 'text', '{"content":"salut"}'::jsonb;
INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
SELECT (SELECT v FROM ctx WHERE k='msg_etr'), (SELECT v FROM ctx WHERE k='etr'),
       'banc-jsonb-moi', 'text', '{"content":"pirate"}'::jsonb;

-- @@MIGRATION@@

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","app_metadata":{"firebase_uid":"banc-jsonb-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- 1. apres_envoi_message : pastille de l'autre +1, pas la mienne ; sourdine
--    intacte ; marque « supprimé » retirée.
DO $$
DECLARE ok boolean; d jsonb;
BEGIN
  ok := apres_envoi_message((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='msg_moi'), '{"lastMessage":"salut","lastMessageType":"text"}');
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (1, 'apres_envoi : pastilles, aperçu, sourdine gardée',
    'ok, autre=3, moi absent, mutedBy gardé, lastMessageDeleted retiré',
    format('ok=%s autre=%s moi=%s muted=%s suppr=%s', ok,
      d->'unreadCount'->>'banc-jsonb-autre', d->'unreadCount'->>'banc-jsonb-moi',
      d->'mutedBy', d ? 'lastMessageDeleted'),
    CASE WHEN ok AND (d->'unreadCount'->>'banc-jsonb-autre') = '3'
          AND NOT (d->'unreadCount' ? 'banc-jsonb-moi')
          AND d->'mutedBy' = '{"banc-jsonb-autre": true}'::jsonb
          AND NOT d ? 'lastMessageDeleted'
          AND d->>'lastMessage' = 'salut'
          AND d->>'lastMessageSenderId' = 'banc-jsonb-moi'
         THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'apres_envoi : pastilles, aperçu, sourdine gardée', 'ok',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- 2. fusion simple : remplace les clés données, garde les autres.
DO $$
DECLARE ok boolean; d jsonb;
BEGIN
  ok := fusionner_donnees_conversation((SELECT v FROM ctx WHERE k='conv'), '{"pinned":true}');
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (2, 'fusion simple : clé ajoutée, reste gardé', 'pinned=true, mutedBy gardé',
    format('ok=%s pinned=%s muted=%s', ok, d->'pinned', d->'mutedBy'),
    CASE WHEN ok AND d->'pinned' = 'true'::jsonb AND d ? 'mutedBy' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. fusion profonde : un objet est fusionné, pas remplacé.
DO $$
DECLARE d jsonb;
BEGIN
  PERFORM fusionner_donnees_conversation((SELECT v FROM ctx WHERE k='conv'),
    '{"mutedBy":{"banc-jsonb-moi":true}}', true);
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (3, 'fusion profonde : mutedBy garde les deux entrées', '2 entrées',
    d->'mutedBy'::text,
    CASE WHEN d->'mutedBy' = '{"banc-jsonb-moi":true,"banc-jsonb-autre":true}'::jsonb
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. retrait d'une sous-clé.
DO $$
DECLARE ok boolean; d jsonb;
BEGIN
  ok := retirer_cle_donnees_conversation((SELECT v FROM ctx WHERE k='conv'), 'mutedBy', 'banc-jsonb-moi');
  SELECT data INTO d FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (4, 'retrait : seule la sous-clé visée part', 'mutedBy={autre}',
    format('ok=%s muted=%s', ok, d->'mutedBy'),
    CASE WHEN ok AND d->'mutedBy' = '{"banc-jsonb-autre":true}'::jsonb THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. ajout à une liste de messages.data, sans doublon.
DO $$
DECLARE d jsonb;
BEGIN
  PERFORM fusionner_donnees_message((SELECT v FROM ctx WHERE k='msg'), '{"deletedFor":"banc-jsonb-moi"}', true);
  PERFORM fusionner_donnees_message((SELECT v FROM ctx WHERE k='msg'), '{"deletedFor":"banc-jsonb-moi"}', true);
  SELECT data INTO d FROM messages WHERE id = (SELECT v FROM ctx WHERE k='msg');
  INSERT INTO resultat VALUES (5, 'ajout à une liste : une seule fois, readBy gardé', 'deletedFor=[moi], readBy intact',
    format('deletedFor=%s readBy=%s', d->'deletedFor', d->'readBy'),
    CASE WHEN d->'deletedFor' = '["banc-jsonb-moi"]'::jsonb
          AND d->'readBy' = '["banc-jsonb-autre"]'::jsonb THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'ajout à une liste : une seule fois, readBy gardé', 'ok',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- 6-7. bascule d'une étoile : posée, puis retirée.
DO $$
DECLARE e1 boolean; e2 boolean; d jsonb;
BEGIN
  e1 := basculer_dans_liste_message((SELECT v FROM ctx WHERE k='msg'), 'starredBy', 'banc-jsonb-moi');
  e2 := basculer_dans_liste_message((SELECT v FROM ctx WHERE k='msg'), 'starredBy', 'banc-jsonb-moi');
  SELECT data INTO d FROM messages WHERE id = (SELECT v FROM ctx WHERE k='msg');
  INSERT INTO resultat VALUES (6, 'bascule : posée puis retirée', 'true puis false, liste vide',
    format('%s puis %s, %s', e1, e2, d->'starredBy'),
    CASE WHEN e1 AND NOT e2 AND d->'starredBy' = '[]'::jsonb THEN 'OK' ELSE 'ÉCHEC' END);
  INSERT INTO resultat VALUES (7, 'bascule : readBy toujours intact', '["banc-jsonb-autre"]',
    d->'readBy'::text,
    CASE WHEN d->'readBy' = '["banc-jsonb-autre"]'::jsonb THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'bascule : posée puis retirée', 'ok',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- 8. Les fonctions existent toutes, en SECURITY INVOKER.
INSERT INTO resultat
SELECT 8, 'cinq fonctions, toutes SECURITY INVOKER', '5 / 0 definer',
       count(*) || ' / ' || count(*) FILTER (WHERE p.prosecdef) || ' definer',
       CASE WHEN count(*) = 5 AND count(*) FILTER (WHERE p.prosecdef) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('fusionner_donnees_conversation', 'retirer_cle_donnees_conversation',
                     'fusionner_donnees_message', 'basculer_dans_liste_message',
                     'apres_envoi_message');

-- 9. Aucun droit ouvert : une conversation d'autrui reste intouchable.
DO $$
DECLARE ok boolean;
BEGIN
  ok := fusionner_donnees_conversation((SELECT v FROM ctx WHERE k='etr'), '{"pirate":true}');
  INSERT INTO resultat VALUES (9, 'conversation d''autrui : rien n''est écrit', 'false',
    ok::text, CASE WHEN NOT ok THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 10. Ni par l'après-envoi.
DO $$
DECLARE ok boolean;
BEGIN
  ok := apres_envoi_message((SELECT v FROM ctx WHERE k='etr'), (SELECT v FROM ctx WHERE k='msg_etr'), '{"lastMessage":"pirate"}');
  INSERT INTO resultat VALUES (10, 'apres_envoi sur la conversation d''autrui : rien', 'false',
    ok::text, CASE WHEN NOT ok THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN no_data_found THEN
  -- Le message n'est pas lisible par « moi » (RLS) : refus, c'est l'attendu.
  INSERT INTO resultat VALUES (10, 'apres_envoi sur la conversation d''autrui : rien', 'false',
    'refusé P0002', 'OK');
END $$;

-- 11. Un message système n'incrémente aucune pastille.
DO $$
DECLARE avant jsonb; apres jsonb;
BEGIN
  SELECT data->'unreadCount' INTO avant FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  PERFORM apres_envoi_message((SELECT v FROM ctx WHERE k='conv'), (SELECT v FROM ctx WHERE k='msg_moi'), '{"lastMessageType":"system"}');
  SELECT data->'unreadCount' INTO apres FROM conversations WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (11, 'message système : aucune pastille ne bouge', avant::text,
    apres::text, CASE WHEN avant = apres THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
