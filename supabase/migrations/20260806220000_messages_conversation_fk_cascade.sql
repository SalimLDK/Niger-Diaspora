-- « Supprimer pour tout le monde » laissait tous les messages orphelins.
--
-- `MessageSupabaseDataSource.deleteConversation(forEveryone: true)` fait un
-- `from('conversations').delete()` avec le commentaire « Hard delete (cascade
-- deletes messages) ». La cascade n'a jamais existé : `messages.conversation_id`
-- n'avait AUCUNE clé étrangère vers `conversations`. Seules `events` et
-- `group_pinned_items` en avaient une (toutes deux en CASCADE), ce qui rendait
-- l'illusion crédible.
--
-- Conséquence : chaque suppression de conversation « pour tout le monde »
-- abandonnait en base la totalité de ses messages. Plus aucune requête de
-- l'app ne les atteint (tout part de `conversation_id`), ils sont chiffrés
-- E2EE donc illisibles, et rien ne les purge — ils s'accumulent indéfiniment.
--
-- On rétablit ce que le code croyait déjà vrai plutôt que l'inverse : la
-- suppression d'une conversation emporte ses messages. L'alternative (garder
-- les messages, corriger le commentaire) n'a pas de sens ici — sans leur
-- conversation ils ne sont ni lisibles ni rattachables.
--
-- Prérequis vérifié avant écriture : 0 message orphelin.
--   select count(*) from public.messages m
--   where not exists (select 1 from public.conversations c
--                     where c.id = m.conversation_id);
-- Si ce compte n'est plus nul au moment d'appliquer, la contrainte échouera :
-- il faudra d'abord décider quoi faire des orphelins (les purger, ou les
-- rattacher). Ne pas contourner avec `not valid`, ça ne ferait que déplacer
-- le problème.
--
-- Pas d'index à créer : `messages_conversation_idx (conversation_id,
-- created_at desc)` a déjà `conversation_id` en tête de clé, ce qui suffit à
-- la recherche des lignes filles lors du DELETE.
--
-- Types compatibles : `conversations.id` et `messages.conversation_id` sont
-- tous deux `text` (pas `uuid` — les identifiants hérités de Firestore ne sont
-- pas des UUID).

alter table public.messages
  add constraint messages_conversation_id_fkey
  foreign key (conversation_id) references public.conversations(id)
  on delete cascade;
