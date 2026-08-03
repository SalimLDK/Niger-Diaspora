-- =============================================================================
-- Fix is_admin() : comparait current_user_id() (UUID interne Supabase Auth) à
-- users.id (Firebase UID, TEXT) — deux valeurs qui ne coïncident jamais.
--
-- Contexte : l'app s'authentifie exclusivement via Firebase Auth. Le pont
-- SupabaseAuthBridge échange le token Firebase contre une session Supabase
-- (via l'Edge Function auth-firebase-exchange), mais auth.jwt()->>'sub'
-- expose l'ID interne du user Supabase Auth généré par cet échange, pas le
-- Firebase UID. public.users.id, lui, est explicitement le Firebase UID
-- (voir auth-firebase-exchange/index.ts : `id: firebaseUid`).
--
-- Les migrations 20260526170000 et 20260715120000 ont corrigé toutes les
-- policies RLS basées sur l'identité pour utiliser firebase_uid() (qui
-- résout le bon UID via app_metadata ou la table auth_mappings) au lieu de
-- current_user_id(). is_admin() a été oubliée dans ce passage — elle
-- retournait donc FALSE pour tout le monde, quel que soit le contenu réel
-- de users.is_admin / users.admin_role. Toute policy qui en dépend
-- (reports, businesses, support_tickets, app_config, visibilité des
-- profils privés) n'accordait jamais l'accès admin attendu.
--
-- Fix : même logique, mais via firebase_uid(). Signature et usages
-- inchangés — aucune policy appelante n'a besoin d'être modifiée.
-- =============================================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM users WHERE id = (SELECT firebase_uid())),
    FALSE
  )
$$;
