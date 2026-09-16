-- Diagnostic : les reçus des derniers messages, SANS jointure.
--
-- Le diagnostic précédent joignait `conversations.participant_ids` pour
-- retrouver le destinataire. Si un reçu est écrit sous un `user_id` qui n'est
-- pas dans cette liste, la jointure le rate et affiche « aucun reçu » — ce qui
-- ressemble à une panne alors que c'en est une autre. Ici, on lit la table
-- telle qu'elle est.
--
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT m.created_at,
       m.id          AS message_id,
       m.sender_id,
       r.user_id     AS recu_de,
       r.delivered_at,
       r.read_at
  FROM public.mls_messages m
  LEFT JOIN public.mls_message_receipts r ON r.message_id = m.id
 WHERE m.conversation_id = 'debef5f0-2fa0-4775-b1ed-85a4d6411102'
   AND m.created_at > now() - interval '70 minutes'
 ORDER BY m.created_at DESC, r.user_id;

ROLLBACK;
