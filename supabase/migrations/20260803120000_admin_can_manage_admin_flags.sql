-- =============================================================================
-- Permettre au back-office de promouvoir/rétrograder un admin dans Postgres.
--
-- Contexte : les rôles admin vivaient uniquement dans Firestore
-- (users/{uid}.adminRole). Côté Postgres, users.is_admin / users.admin_role
-- n'étaient jamais écrits — is_admin() renvoyait donc FALSE pour un compte
-- pourtant admin dans l'app, et toutes les policies RLS qui en dépendent
-- (reports, businesses, support_tickets, app_config, profils privés) le
-- refusaient. Voir aussi 20260803034145_fix_is_admin_firebase_uid.sql.
--
-- La policy "users_update_own" (schéma initial) interdit explicitement à un
-- utilisateur de modifier is_admin / admin_role, y compris sur sa propre
-- ligne — ce qui est correct, mais bloquait aussi la synchronisation depuis
-- l'écran de gestion des rôles.
--
-- Cette policy ajoute le seul chemin manquant : un admin déjà établi peut
-- écrire sur les lignes users. Elle s'ajoute à users_update_own (les policies
-- PERMISSIVE sont en OU), donc le comportement des non-admins est inchangé.
--
-- ⚠ AMORÇAGE : le tout premier admin ne peut pas se promouvoir lui-même
-- (is_admin() est encore FALSE pour lui). Il faut le faire une fois à la main
-- dans le SQL Editor, avec le Firebase UID du compte :
--
--   UPDATE users SET is_admin = TRUE, admin_role = 'superAdmin'
--   WHERE id = '<firebase_uid>';
--
-- ⚠ PORTÉE : RLS ne filtre pas par colonne — cette policy donne à un admin le
-- droit d'écrire n'importe quel champ de n'importe quelle ligne users, pas
-- seulement les deux drapeaux admin. C'est le niveau de pouvoir attendu d'un
-- back-office, mais cela veut dire qu'un compte admin compromis est un accès
-- en écriture sur toute la table.
-- =============================================================================

DROP POLICY IF EXISTS "users_update_admin" ON users;
CREATE POLICY "users_update_admin" ON users FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());
