-- Diagnostic : les derniers messages MLS reçus sont-ils marqués lus, et par qui ?
--
-- La vue `mls_unread_counts` est `security_invoker` et s'appuie sur
-- `firebase_uid()` : interrogée en `postgres`, elle est vide par construction
-- (c'est écrit dans la migration qui la crée). Ce fichier recalcule donc la
-- même chose depuis les tables, sans dépendre du JWT.
--
-- Le CLI ne rend que le dernier jeu de résultats : une seule requête ici.
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT m.created_at,
       m.conversation_id,
       m.sender_id,
       m.kind,
       m.is_deleted,
       dest.user_id                         AS destinataire,
       (r.message_id IS NOT NULL)           AS a_un_recu,
       r.read_at,
       r.delivered_at
  FROM public.mls_messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  CROSS JOIN LATERAL unnest(c.participant_ids) AS dest(user_id)
  LEFT JOIN public.mls_message_receipts r ON r.message_id = m.id
                                        AND r.user_id    = dest.user_id
 WHERE dest.user_id <> m.sender_id
   AND m.created_at > now() - interval '30 minutes'
 ORDER BY m.created_at DESC
 LIMIT 12;

ROLLBACK;
