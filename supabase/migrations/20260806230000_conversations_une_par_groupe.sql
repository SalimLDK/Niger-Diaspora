-- Garantir en base « une seule conversation par groupe ».
--
-- Le correctif applicatif (findGroupConversationByGroupId cherche désormais
-- par la colonne TEXT `group_id` au lieu d'abandonner sur un id non-UUID)
-- supprime la CAUSE des doublons, mais rien n'empêche structurellement leur
-- retour. Trois chemins restent ouverts :
--   * les APK déjà installés tournent avec l'ancien code et continueront de
--     dupliquer à chaque ouverture de discussion ;
--   * deux appareils du même compte ouvrant la discussion en même temps
--     passent tous les deux la recherche avant que l'un n'ait inséré ;
--   * tout futur chemin d'insertion qui oublierait la recherche préalable.
--
-- Prérequis vérifié avant écriture : 4 conversations de groupe, 4 `group_id`
-- distincts, aucun NULL. L'index est donc créable tel quel. Si un doublon
-- réapparaît d'ici l'application, la création échouera — c'est voulu, il faut
-- trancher le doublon avant, pas contourner l'index.
--
-- ⚠ CHANGEMENT DE COMPORTEMENT VISIBLE, à peser avant d'appliquer.
-- Aujourd'hui une insertion en trop réussit en silence et fragmente
-- l'historique. Avec cet index elle échoue, et l'utilisateur voit « Erreur à
-- l'ouverture de la discussion ». C'est préférable dans presque tous les cas
-- (une erreur se rapporte, une fragmentation silencieuse ne se voit pas), avec
-- une exception à connaître : un membre d'un groupe HÉRITÉ de Firestore qui
-- n'est pas encore dans `participant_ids` ne peut ni retrouver la conversation
-- (RLS) ni en créer une — il passera d'un doublon vide à une erreur franche.
-- Ces groupes n'ont pas de ligne `group_members`, donc la RPC
-- `join_group_conversation` ne peut pas le rattacher non plus.
--
-- Si ce cas se produit en vrai, le vrai correctif est de migrer
-- l'appartenance des groupes hérités vers `group_members` — pas de retirer
-- cet index.
--
-- `where group_id is not null` : les conversations de groupe sans `group_id`
-- (il n'y en a aucune aujourd'hui) resteraient possibles sans se collisionner
-- entre elles.

create unique index if not exists conversations_une_par_groupe
  on public.conversations (group_id)
  where type = 'group' and group_id is not null;
