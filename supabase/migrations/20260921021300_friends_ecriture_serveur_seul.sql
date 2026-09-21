-- `public.friends` n'est plus inscriptible depuis un client.
--
-- POURQUOI. Cette table décide de l'audience « Amis » et « Abonnés » :
-- `private.est_ami_de(auteur, lecteur)` cherche la ligne
-- `(user_id = auteur, friend_id = lecteur)`, et `peut_voir_publication` /
-- `peut_voir_story` s'appuient dessus. Or `anon` et `authenticated` avaient
-- tous les droits de table (le défaut Supabase, jamais retiré), et la policy
-- `friends_own` vaut pour `ALL` : un compte connecté pouvait donc INSÉRER,
-- MODIFIER et SUPPRIMER librement ses propres lignes d'amitié par PostgREST.
--
-- Ce que cela permettait aujourd'hui : se déclarer ami de quelqu'un dans le
-- sens `(moi, victime)`. Ce sens-là ne donne accès à RIEN — `est_ami_de` lit
-- l'autre — mais il offre au contraire le contenu « Amis » de l'attaquant à
-- sa victime, et surtout il devient dangereux au premier code qui lirait la
-- relation dans l'autre sens, ou qui la croirait réciproque. Supprimer ses
-- propres lignes permettait aussi de se retirer des audiences à l'insu de
-- l'autre.
--
-- PERSONNE N'EN DÉPEND. Vérifié avant d'écrire : `lib/` ne fait que LIRE
-- cette table, à deux endroits, tous deux avec `user_id = soi`
-- (`feed_supabase_datasource.dart:310`, `feed_personalization_provider.dart:51`).
-- Les amitiés sont écrites côté serveur, avec la clé de service, par
-- `setFriendship` (`functions/supabase.js:265`, appelée par le déclencheur
-- `mirrorFriendToSupabase`) — la RLS ne s'applique pas à `service_role`.
-- La RPC `public.accept_friend_request` écrit aussi cette table, en
-- SECURITY DEFINER : elle n'est appelée par aucun code de `lib/` (reste d'un
-- essai « tout Postgres »), et reste fonctionnelle si elle revenait.
--
-- CE QUE ÇA NE FERME PAS — le vrai trou est ailleurs, et reste ouvert.
-- La règle Firestore `users/{userId}/friends/{friendId}` autorise l'écriture
-- dès que `friendId == request.auth.uid` : n'importe qui peut donc s'inscrire
-- dans la liste d'amis d'autrui, et `mirrorFriendToSupabase` recopie cette
-- ligne dans `public.friends` avec la clé de service — dans le sens qui, lui,
-- donne accès. Cette migration ne touche pas à ce chemin. Elle enlève
-- seulement la porte directe, pour que le serveur reste le seul écrivain.
-- Suite dans `docs/deploiement/AUDIT_PRE_PROD_2026-09-20.md`, point 1.2.
--
-- Matière exposée à ce jour : AUCUNE. Mesuré le 2026-09-20 en production —
-- 6 publications et 6 stories, toutes `public` ; 0 contenu en audience
-- « amis » ou « abonnés ». La table est saine : 24 lignes, 12 paires toutes
-- symétriques, aucune auto-amitié, aucun compte fantôme.
--
-- Pas de `SET LOCAL` en tête : `db push` ne joue pas le fichier dans un bloc
-- de transaction explicite (WARNING 25P01 constaté sur 20260920213600).
--
-- Banc : tools/rls_tests/friends_ecriture_serveur_seul.sql

REVOKE ALL ON public.friends FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.friends FROM authenticated;

-- Les deux policies de lecture ne valent plus que pour un compte connecté.
-- Sans droit de table, `anon` ne les atteint plus ; les y laisser rouvrirait
-- tout si un `GRANT` revenait par mégarde.
ALTER POLICY friends_own          ON public.friends TO authenticated;
ALTER POLICY friends_select_other ON public.friends TO authenticated;
