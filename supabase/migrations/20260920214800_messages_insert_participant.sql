-- Écrire dans une conversation exige d'en être participant.
--
-- CE QUI ÉTAIT OUVERT (lu en production le 2026-09-20) : `messages_insert`
-- n'exigeait que `firebase_uid() = sender_id`. N'importe quel compte connecté
-- pouvait donc insérer un message, signé de son propre nom, dans n'importe
-- quelle conversation dont il connaissait l'identifiant — et d'abord celui
-- d'une conversation dont il vient d'être exclu, qu'il a forcément gardé.
-- `messages_select` ne regarde que la conversation : tous les participants
-- voyaient le message arriver dans leur fil, par le flux temps réel.
--
-- `mls_messages` avait la bonne règle depuis sa création
-- (`is_conversation_participant(conversation_id)`, migration 20260915120000) ;
-- le transport en clair ne l'avait jamais reçue.
--
-- CE QUE CE N'ÉTAIT PAS : un message ainsi injecté ne poussait **aucune
-- notification**. `notify_recipients_on_message_insert` sort sans rien créer
-- quand l'expéditeur n'est pas dans `participant_ids` (« anti-spoof si insert
-- bypassait RLS ») — le garde-fou existait, mais un étage trop bas : après
-- l'écriture, pas avant.
--
-- PERSONNE N'EN DÉPEND. Mesuré avant d'écrire : 185 messages en base, 0 dont
-- l'expéditeur n'est pas participant de sa conversation. Côté app, les trois
-- points d'insertion (`_insererMessageUtilisateur`, `call_message_service`,
-- `background_reply_service`) écrivent dans une conversation que l'appelant
-- lit déjà. Les notices de groupe sont écrites par des RPC SECURITY DEFINER
-- dont le propriétaire est celui de la table, et `messages` n'est pas en
-- FORCE ROW LEVEL SECURITY : elles ne passent pas par cette policy.
--
-- CE QUE ÇA NE RÉPARE PAS. Le contrôle porte sur `participant_ids`. Mesuré le
-- même jour : 2 personnes figurent encore dans les `participant_ids` d'une
-- conversation de groupe sans plus être dans `group_members` — elles gardent
-- lecture ET écriture, avant comme après. C'est une anomalie de données, pas
-- de policy : à réparer à part, sur décision. (À l'inverse, 1 membre de groupe
-- manque à `participant_ids` : il ne lisait déjà pas la discussion, il ne perd
-- rien.)
--
-- Une seule instruction, donc atomique d'elle-même : pas de `SET LOCAL` en
-- tête, `db push` ne joue pas le fichier dans un bloc de transaction explicite
-- (WARNING 25P01 constaté sur 20260920213600). Le rôle passe au passage de
-- `public` à `authenticated` : pour `anon`, `firebase_uid()` est nul et la
-- condition était déjà fausse.
--
-- Banc : tools/rls_tests/messages_insert_participant.sql

ALTER POLICY messages_insert ON public.messages
  TO authenticated
  WITH CHECK (
    (SELECT public.firebase_uid()) = sender_id
    AND public.is_conversation_participant(conversation_id)
  );
