-- Banc : push des messages — nom d'expéditeur posé par le serveur, expéditeur
-- bloqué silencieux (migration 20261005130000).
--
--   supabase db query --linked -f tools/rls_tests/push_expediteur_serveur_et_blocage.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, les cas 1, 2, 4 et 5 sont en ÉCHEC : le nom choisi par
-- le client passe, et le destinataire qui a bloqué est notifié.
--
-- ⚠️ CE BANC CRÉE DES NOTIFICATIONS, donc met des pushs en file
-- (`trg_notify_push` → `net.http_post`). C'est TRANSACTIONNEL : le ROLLBACK
-- final annule la file. Les destinataires sont des profils d'essai sans jeton
-- push. Les messages sont insérés en `postgres` : les déclencheurs de
-- notification sont SECURITY DEFINER et s'exécutent pareil.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);

INSERT INTO public.users (id, display_name, avatar_url) VALUES
  ('banc-push-a', 'Alice Banc', NULL),
  ('banc-push-b', 'Bob Banc',   NULL),
  ('banc-push-c', 'Chloé Banc', NULL);

-- Bob a bloqué Alice.
INSERT INTO public.blocked_users (blocker_id, blocked_id)
VALUES ('banc-push-b', 'banc-push-a');

INSERT INTO public.conversations (id, type, participant_ids, created_by, data) VALUES
  ('banc-push-1a1', 'individual', ARRAY['banc-push-a', 'banc-push-c'], 'banc-push-a', '{}'),
  ('banc-push-1ab', 'individual', ARRAY['banc-push-a', 'banc-push-b'], 'banc-push-a', '{}'),
  ('banc-push-grp', 'group', ARRAY['banc-push-a', 'banc-push-b', 'banc-push-c'], 'banc-push-a',
   '{"name":"Groupe banc","mutedBy":{"banc-push-b":"forever"}}');

-- @@MIGRATION@@

-- ═══ 1. Le nom choisi par le client ne signe plus le push ═════════════════
INSERT INTO public.messages (id, conversation_id, sender_id, type, data) VALUES
  ('banc-push-m1', 'banc-push-1a1', 'banc-push-a', 'text',
   '{"content":"Votre compte est suspendu","senderName":"Banque BCEAO","senderPhotoUrl":"https://faux.invalid/logo.png"}');
INSERT INTO resultat
SELECT 1, 'nom et photo du push : ceux de users, pas du message',
       'titre=Alice Banc, senderName=Alice Banc, photo vide',
       format('titre=%s, senderName=%s, photo=%s', title, data->>'senderName', data->>'senderPhotoUrl'),
       CASE WHEN title = 'Alice Banc' AND data->>'senderName' = 'Alice Banc'
             AND COALESCE(data->>'senderPhotoUrl', '') = ''
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-c' AND data->>'messageId' = 'banc-push-m1';

-- ═══ 2. 1:1 : celui qui a bloqué n'est pas notifié ════════════════════════
INSERT INTO public.messages (id, conversation_id, sender_id, type, data) VALUES
  ('banc-push-m2', 'banc-push-1ab', 'banc-push-a', 'text', '{"content":"coucou"}');
INSERT INTO resultat
SELECT 2, '1:1 : destinataire qui a bloqué → aucune notification', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-b' AND data->>'messageId' = 'banc-push-m2';

-- ═══ 3. Groupe : les autres le sont toujours ══════════════════════════════
INSERT INTO public.messages (id, conversation_id, sender_id, type, data) VALUES
  ('banc-push-m3', 'banc-push-grp', 'banc-push-a', 'text', '{"content":"à tous"}');
INSERT INTO resultat
SELECT 3, 'groupe : Chloé notifiée, préfixe Alice Banc', '1, Alice Banc: …',
       count(*) || ', ' || COALESCE(max(body), ''),
       CASE WHEN count(*) = 1 AND max(body) LIKE 'Alice Banc:%' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-c' AND data->>'messageId' = 'banc-push-m3';

-- ═══ 4. Groupe : la mention ne perce pas le blocage ═══════════════════════
-- Bob a mis le groupe en sourdine ; une mention y passe d'ordinaire
-- (`messageMention`, 20260916130000) — pas venant de quelqu'un qu'il a bloqué.
INSERT INTO public.messages (id, conversation_id, sender_id, type, data) VALUES
  ('banc-push-m4', 'banc-push-grp', 'banc-push-a', 'text',
   '{"content":"@Bob","mentionedUsers":[{"id":"banc-push-b"}]}');
INSERT INTO resultat
SELECT 4, 'mention venant d''un bloqué : rien', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-b' AND data->>'messageId' IN ('banc-push-m3', 'banc-push-m4');

-- ═══ 5. MLS : même règle ══════════════════════════════════════════════════
INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity,
                                signature_key, credential)
VALUES ('00000000-0000-0000-0000-00000000ba5e', 'banc-push-a', 'banc-push', 'Banc',
        'android', 'banc-push-a:banc', '\x01', '\x01');
INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id,
                                 epoch, kind, content_type, ciphertext)
VALUES ('00000000-0000-0000-0000-0000000005a1', 'banc-push-1ab', 'banc-push-a',
        '00000000-0000-0000-0000-00000000ba5e', 1, 'content', 'text', '\x00');
INSERT INTO resultat
SELECT 5, 'MLS 1:1 : destinataire qui a bloqué → aucune notification', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-b'
   AND data->>'messageId' = '00000000-0000-0000-0000-0000000005a1';

-- ═══ 6. MLS : sans blocage, la notification part ══════════════════════════
INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id,
                                 epoch, kind, content_type, ciphertext)
VALUES ('00000000-0000-0000-0000-0000000005a2', 'banc-push-1a1', 'banc-push-a',
        '00000000-0000-0000-0000-00000000ba5e', 1, 'content', 'text', '\x00');
INSERT INTO resultat
SELECT 6, 'MLS 1:1 sans blocage : notifiée, titre Alice Banc', '1 Alice Banc',
       count(*) || ' ' || COALESCE(max(title), ''),
       CASE WHEN count(*) = 1 AND max(title) = 'Alice Banc' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-push-c'
   AND data->>'messageId' = '00000000-0000-0000-0000-0000000005a2';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
