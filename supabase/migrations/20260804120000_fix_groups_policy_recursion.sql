-- =============================================================================
-- Supprimer la récursion infinie des policies RLS de `groups` /
-- `group_members` (SQLSTATE 42P17).
--
-- Symptôme reproduit le 2026-08-04 contre le projet de production, sur un
-- simple `GET /rest/v1/groups?limit=0` :
--
--   infinite recursion detected in policy for relation "group_members"
--
-- Touche `groups`, `group_members`, et par ricochet `post_polls` dont les
-- policies interrogent `group_members`. Le module Groupes est donc
-- inutilisable, sondages compris.
--
-- Cause : les deux policies se lisent mutuellement.
--
--   group_members_select  →  EXISTS (SELECT 1 FROM groups g …)
--   groups_select_public  →  EXISTS (SELECT 1 FROM group_members gm …)
--
-- Lire `group_members` déclenche la RLS de `groups`, qui déclenche la RLS de
-- `group_members`, et Postgres refuse d'entrer une seconde fois dans une RLS
-- déjà en cours d'application.
--
-- Le cycle date du schéma initial (20260522223150). 20260803170000 l'a repris
-- tel quel en changeant seulement la fonction d'identité — ce n'est donc pas
-- une régression de cette migration-là, mais un défaut de longue date, du même
-- ordre que celui corrigé sur `users` par 20260803200000.
--
-- Correctif : même mécanisme que 20260803200000 — passer par des fonctions
-- SECURITY DEFINER, dont le corps n'est pas soumis à la RLS de l'appelant. Le
-- cycle d'expansion ne se rouvre plus.
--
-- La SÉMANTIQUE des policies est strictement inchangée. Chaque fonction ne
-- répond qu'à propos de **l'appelant lui-même** (`firebase_uid()` est appliqué
-- à l'intérieur, il n'est pas paramétrable) ou à propos d'un fait déjà public
-- (un groupe est-il public). Aucune n'ouvre de nouvelle visibilité :
--
--   is_group_member / is_group_admin — ne lisent que la ligne d'appartenance
--     de l'appelant, que `group_members_own` lui laissait déjà lire ;
--   is_group_public — n'expose que `NOT is_private`, ce que
--     `groups_select_public` publiait déjà à tout le monde.
--
-- `SET search_path` est figé sur chacune : une fonction SECURITY DEFINER sans
-- search_path explicite est détournable par un appelant qui place une table
-- homonyme en tête de son propre search_path.
-- =============================================================================

-- ── Fonctions d'appartenance (brise-cycle) ──────────────────────────────────

CREATE OR REPLACE FUNCTION is_group_member(p_group_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = p_group_id
      AND gm.user_id = (SELECT firebase_uid())
  )
$$;

CREATE OR REPLACE FUNCTION is_group_admin(p_group_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = p_group_id
      AND gm.user_id = (SELECT firebase_uid())
      AND gm.role IN ('admin','owner')
  )
$$;

CREATE OR REPLACE FUNCTION is_group_public(p_group_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = p_group_id AND NOT g.is_private
  )
$$;

-- ── Policies, réécrites sans lecture croisée ────────────────────────────────

-- Avant : EXISTS (SELECT 1 FROM groups g WHERE g.id = group_id AND NOT g.is_private)
DROP POLICY IF EXISTS "group_members_select" ON group_members;
CREATE POLICY "group_members_select" ON group_members FOR SELECT
  USING (
    (SELECT firebase_uid()) = user_id
    OR is_group_public(group_id)
  );

-- Avant : EXISTS (SELECT 1 FROM group_members gm WHERE gm.group_id = id AND gm.user_id = …)
DROP POLICY IF EXISTS "groups_select_public" ON groups;
CREATE POLICY "groups_select_public" ON groups FOR SELECT
  USING (
    NOT is_private
    OR (SELECT firebase_uid()) = creator_id
    OR is_group_member(id)
  );

-- Avant : EXISTS (SELECT 1 FROM group_members gm WHERE … AND gm.role IN ('admin','owner'))
DROP POLICY IF EXISTS "groups_update_admin" ON groups;
CREATE POLICY "groups_update_admin" ON groups FOR UPDATE
  USING (is_group_admin(id));

-- `group_members_own` (FOR ALL USING firebase_uid() = user_id) ne lit aucune
-- autre table : laissée telle quelle.
--
-- Les policies de `post_polls` (20260803180000) interrogent `group_members`
-- mais rien ne les rappelle en retour : une fois le cycle ci-dessus rompu,
-- elles cessent de récurser sans être modifiées.

NOTIFY pgrst, 'reload schema';
