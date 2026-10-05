-- Banc : un message en clair supprimé pour tous emporte le texte de sa
-- notification et retire la bannière (migration 20261005140000).
--
--   supabase db query --linked -f tools/rls_tests/notification_suit_le_message_clair_supprime.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, les cas 1 et 2 sont en ÉCHEC : le texte reste, aucun
-- signal ne part.
--
-- ⚠️ CE BANC CRÉE DES NOTIFICATIONS, donc met des pushs en file
-- (`trg_notify_push` → `net.http_post`). C'est TRANSACTIONNEL : le ROLLBACK
-- final annule la file. Les destinataires sont des profils d'essai sans jeton
-- push. Une notification d'origine est fabriquée ici en plus de celle du
-- déclencheur d'envoi : le banc ne dépend pas de ce dernier, et vérifie
-- TOUTES les notifications du message.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);

INSERT INTO public.users (id, display_name) VALUES
  ('banc-sup-a', 'Alice Banc'), ('banc-sup-b', 'Bob Banc');

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
VALUES ('banc-sup-conv', 'individual', ARRAY['banc-sup-a', 'banc-sup-b'], 'banc-sup-a', '{}');

-- @@MIGRATION@@

INSERT INTO public.messages (id, conversation_id, sender_id, type, data) VALUES
  ('banc-sup-m1', 'banc-sup-conv', 'banc-sup-a', 'text', '{"content":"PA6SECRET"}'),
  ('banc-sup-m2', 'banc-sup-conv', 'banc-sup-a', 'text', '{"content":"sans push"}');
-- « Sans push » : ce que le déclencheur d'envoi a pu créer pour m2 disparaît.
DELETE FROM public.notifications WHERE data->>'messageId' = 'banc-sup-m2';

INSERT INTO public.notifications (user_id, type, title, body, data, is_read) VALUES
  ('banc-sup-b', 'message', 'Alice Banc', 'PA6SECRET',
   '{"type":"message","messageId":"banc-sup-m1","conversationId":"banc-sup-conv",
     "senderName":"Alice Banc","conversationType":"individual",
     "conversationTitle":"Alice Banc","e2eePayloads":{"x":"chiffré"}}', FALSE),
  ('banc-sup-a', 'messageReaction', 'Bob Banc', 'a réagi à votre message',
   '{"type":"messageReaction","messageId":"banc-sup-m1","conversationId":"banc-sup-conv"}', FALSE);

-- Supprimer pour tout le monde (en `postgres` : c'est le déclencheur qu'on
-- vérifie, pas la garde des droits).
UPDATE public.messages
   SET is_deleted = TRUE,
       data = '{"content":"","deletedForEveryone":true}'
 WHERE id IN ('banc-sup-m1', 'banc-sup-m2');

-- ═══ 1. Le texte et la charge chiffrée quittent la notification ═══════════
INSERT INTO resultat
SELECT 1, 'notifications du message : texte effacé, charge retirée, lues',
       'toutes : Message supprimé, pas d''e2ee, lues',
       string_agg(format('%s, e2ee=%s, lue=%s', body, data ? 'e2eePayloads', is_read), ' | '),
       CASE WHEN count(*) >= 1
             AND bool_and(body = 'Message supprimé' AND NOT data ? 'e2eePayloads' AND is_read)
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-sup-b' AND type = 'message' AND data->>'messageId' = 'banc-sup-m1';

-- ═══ 2. Le destinataire reçoit le signal de retrait de bannière ═══════════
INSERT INTO resultat
SELECT 2, 'signal messageDeleted au destinataire, data-only', '1, lue, identifiants',
       count(*) || ', lue=' || bool_and(is_read) || ', ' || COALESCE(max(data->>'conversationId'), ''),
       CASE WHEN count(*) = 1 AND bool_and(is_read)
             AND max(data->>'conversationId') = 'banc-sup-conv'
             AND max(data->>'messageId') = 'banc-sup-m1'
             AND max(body) = ''
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-sup-b' AND type = 'messageDeleted';

-- ═══ 3. Ni l'expéditeur, ni un message sans push, ne déclenchent de signal ═
INSERT INTO resultat
SELECT 3, 'pas de signal à l''expéditeur ni pour un message sans push', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE type = 'messageDeleted'
   AND (user_id = 'banc-sup-a' OR data->>'messageId' = 'banc-sup-m2');

-- ═══ 4. La réaction : lue, texte inchangé (il ne porte pas de contenu) ════
INSERT INTO resultat
SELECT 4, 'notification de réaction : lue, texte gardé', 'lue, a réagi à votre message',
       format('lue=%s, %s', is_read, body),
       CASE WHEN is_read AND body = 'a réagi à votre message' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications
 WHERE user_id = 'banc-sup-a' AND type = 'messageReaction';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
