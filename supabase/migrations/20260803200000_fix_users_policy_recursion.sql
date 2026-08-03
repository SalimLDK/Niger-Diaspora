-- =============================================================================
-- Supprimer la récursion infinie des policies RLS de `users` (SQLSTATE 42P17).
--
-- Symptôme observé sur appareil le 2026-08-03 :
--
--   PostgrestException(message: infinite recursion detected in policy
--   for relation "users", code: 42P17)
--
-- Cause : la policy `users_update_own` interroge `users` dans son propre
-- WITH CHECK, en SQL nu :
--
--   AND is_admin = (SELECT u.is_admin FROM users u WHERE u.id = ...)
--   AND (admin_role IS NOT DISTINCT FROM (SELECT u.admin_role FROM users u ...))
--
-- Une policy sur `users` qui lit `users` oblige Postgres à ré-appliquer la RLS
-- de `users` pendant qu'il est déjà en train de l'appliquer → il refuse avec
-- 42P17. Toute écriture applicative sur la table est alors bloquée (présence,
-- jeton FCM, dernière connexion, profil).
--
-- Le clause date du schéma initial (20260522223150) ; 20260803170000 l'a
-- reprise telle quelle en changeant seulement la fonction d'identité. Ce n'est
-- donc pas une régression de cette migration-là, mais un défaut de longue date.
--
-- Correctif : passer par des fonctions SECURITY DEFINER. Le corps d'une
-- fonction SECURITY DEFINER n'est pas soumis à la RLS de l'appelant, donc la
-- lecture de `users` n'ouvre plus de second cycle d'expansion. C'est déjà le
-- mécanisme utilisé par `is_admin()` et `firebase_uid()` partout ailleurs.
--
-- La SÉMANTIQUE de la policy est strictement inchangée : un utilisateur ne peut
-- toujours modifier que sa propre ligne, et toujours pas ses drapeaux admin.
-- Le trigger `users_guard_admin_flags` (20260803150000) reste en place et
-- couvre le même invariant de façon plus stricte (défense en profondeur).
-- =============================================================================

-- Pendant de is_admin() pour l'autre colonne. `is_admin()` couvre déjà
-- users.is_admin ; il manquait l'équivalent pour users.admin_role.
CREATE OR REPLACE FUNCTION current_user_admin_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT u.admin_role FROM users u WHERE u.id = (SELECT firebase_uid())
$$;

DROP POLICY IF EXISTS "users_update_own" ON users;
CREATE POLICY "users_update_own" ON users FOR UPDATE
  USING ((SELECT firebase_uid()) = id)
  WITH CHECK (
    (SELECT firebase_uid()) = id
    AND is_admin = is_admin()
    AND (admin_role IS NOT DISTINCT FROM current_user_admin_role())
  );
