-- `public.friend_requests` n'est lue ni écrite par personne.
--
-- Relevé le 2026-09-14 en auditant le cycle de vie d'une demande d'ami :
-- `grep "from('friend_requests')"` sur tout `lib/` ne rend **rien**. Les
-- demandes vivent dans Firestore (`friend_requests`, écrite par
-- `friend_remote_datasource.dart`), et cette table-ci est restée du schéma
-- initial, avec sa policy, sans jamais recevoir une ligne.
--
-- On ne la supprime pas : détruire une table en production pour un ménage
-- n'est pas un correctif, et la migration vers Supabase en aura besoin — c'est
-- précisément là qu'elle devra être remplie. On la marque, pour que la
-- prochaine personne qui lit le schéma ne la croie pas alimentée. Le piège
-- était réel : elle porte le bon nom, les bonnes colonnes et une policy
-- plausible.
--
-- `COMMENT ON` ne touche aucune donnée et n'a aucun effet de bord.

COMMENT ON TABLE public.friend_requests IS
  'INUTILISÉE au 2026-09-15 : les demandes d''ami vivent dans Firestore '
  '(collection friend_requests), pas ici. Aucune ligne de l''application ne '
  'lit ni n''écrit cette table. À remplir le jour où les amitiés migrent vers '
  'Postgres — voir public.friends, qui est déjà le miroir des amitiés '
  'conclues, alimenté par la Cloud Function mirrorFriendToSupabase.';

COMMENT ON TABLE public.friends IS
  'Miroir des amitiés Firestore (users/{uid}/friends/{friendId}), écrit par '
  'la Cloud Function mirrorFriendToSupabase en service_role. UNE LIGNE PAR '
  'SENS : une amitié complète en compte deux. Les audiences « Amis » lisent '
  'friends.user_id = auteur, donc une ligne isolée ne donne rien — '
  'tools/invariants_donnees.py compte les amitiés à sens unique.';
