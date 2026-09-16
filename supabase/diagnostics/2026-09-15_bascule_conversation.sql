-- Diagnostic : cette conversation est-elle vue comme « basculée » ?
--
-- `_passerellePour` rend `null` quand `enMls(conversationId)` est faux, et
-- toute la chaîne MLS s'éteint alors en silence — y compris les reçus
-- (`marquerLus`), qui ne sont écrits que par la passerelle. Le symptôme est
-- muet : `markAsRead` va jusqu'au bout et n'écrit rien.
--
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT c.id,
       c.mls_since,
       c.mls_group_info IS NOT NULL AS a_arbre_public,
       (SELECT count(*) FROM public.mls_messages m
         WHERE m.conversation_id = c.id)              AS messages_mls,
       (SELECT max(m.created_at) FROM public.mls_messages m
         WHERE m.conversation_id = c.id)              AS dernier_mls
  FROM public.conversations c
 WHERE c.id = 'debef5f0-2fa0-4775-b1ed-85a4d6411102';

ROLLBACK;
