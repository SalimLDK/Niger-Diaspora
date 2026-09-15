-- L'arbre public du groupe, pour que l'on puisse le rejoindre sans attendre
-- personne (plan MLS § 5.7).
--
-- POURQUOI PAS DANS `mls_commits`
-- `add_members` d'OpenMLS rend bien un `GroupInfo` optionnel, mais il est nul
-- avec notre configuration : il faut l'exporter explicitement, donc APRÈS
-- avoir fusionné le commit — c'est-à-dire après avoir inséré la ligne. Il
-- aurait fallu rouvrir `mls_commits` en écriture, alors que cette table tire
-- sa valeur d'être en insertion seule : c'est sa clé primaire
-- `(conversation, epoch)` qui arbitre les commits concurrents.
--
-- Ici, une seule valeur par conversation, toujours celle de l'epoch courant.
-- Un arrivant la lit, s'ajoute lui-même, et republie la sienne.
--
-- CE QUE C'EST, ET CE QUE CE N'EST PAS
-- L'arbre des clés PUBLIQUES du groupe et son contexte : aucun secret, rien
-- qui permette de déchiffrer un message. C'est justement ce qui autorise à le
-- stocker. Le RLS le réserve quand même aux participants — le serveur reste
-- l'autorité d'appartenance, MLS reste l'autorité cryptographique, et les
-- membres vérifient l'identité de l'arrivant avant de fusionner son commit.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS mls_group_info bytea;

COMMENT ON COLUMN public.conversations.mls_group_info IS
  'GroupInfo MLS de l''epoch courant (arbre public, aucun secret). Publié par le dernier committeur, lu par un arrivant qui rejoint un groupe ouvert.';
