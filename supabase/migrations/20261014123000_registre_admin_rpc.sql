-- Registre admin : les deux lectures de l'écran Rôles du back-office.
--
-- ═══ POURQUOI ═══════════════════════════════════════════════════════════════
--
-- L'écran Rôles cherchait le compte à promouvoir dans FIRESTORE (`users` par
-- `email`) et listait les admins depuis Firestore (`adminRole` non nul, ou
-- `isAdmin: true`). Plus rien ne crée ces documents depuis la migration vers
-- Supabase : 8 documents Firestore pour 303 lignes Postgres au 2026-10-14
-- (docs/deploiement/AUDIT_ADMIN_2026-10-14.md, § 2). Promouvoir était donc
-- impossible pour presque tout le monde par l'écran prévu — et possible par
-- l'écran Utilisateurs, qui n'écrivait que `is_admin` : d'où l'admin fantôme
-- mesuré en production (is_admin sans admin_role).
--
-- Depuis le 2026-10-14, Postgres `users.admin_role` est la SOURCE du rôle
-- (callable `setAdminRole`, functions/roles_admin.js). L'écran lit donc ici.
--
-- ═══ CE QUE CES FONCTIONS RENDENT, ET À QUI ═══════════════════════════════
--
-- Les deux sont `SECURITY DEFINER` : elles lisent `email` et `last_active_at`,
-- colonnes qui sortiront du GRANT par colonnes de la fermeture 1.1b
-- (supabase/cibles/users_colonnes_privees.sql). Contrepartie : elles
-- contournent le RLS, donc chacune LÈVE 42501 si l'appelant n'est pas
-- superAdmin — le seul rôle qui gère les rôles (`manageRoles` côté client) —
-- et ne rend que les colonnes dont l'écran a besoin, jamais `SELECT *`.
-- `plpgsql` pour pouvoir lever : une fonction `sql` qui filtrerait rendrait
-- zéro ligne à un non-superAdmin, et un écran vide se lit « aucun admin ».
--
-- `administrateurs()` rend AUSSI les lignes incohérentes (`is_admin` sans
-- `admin_role`, ou l'inverse) : c'est exactement ce qu'il faut voir pour les
-- corriger, pas ce qu'il faut cacher. Le client décide de l'affichage.
--
-- Même modèle que `profils_admin` (20260921080000). Pas de `is_admin()` en
-- repli : un contentMod n'a rien à faire ici.
--
-- Banc : tools/rls_tests/registre_admin_rpc.sql

-- ── 1. La liste des admins ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.administrateurs()
RETURNS TABLE (
  id             text,
  email          text,
  display_name   text,
  avatar_url     text,
  is_admin       boolean,
  admin_role     text,
  created_at     timestamptz,
  last_active_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'administrateurs : réservé aux superAdmins'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT u.id, u.email, u.display_name, u.avatar_url,
           u.is_admin, u.admin_role, u.created_at, u.last_active_at
      FROM public.users u
     WHERE u.is_admin OR u.admin_role IS NOT NULL
     ORDER BY (u.admin_role = 'superAdmin') DESC NULLS LAST,
              u.admin_role NULLS LAST,
              u.display_name NULLS LAST
     LIMIT 200;
END $$;

REVOKE ALL ON FUNCTION public.administrateurs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrateurs() TO authenticated;

-- ── 2. Un compte par e-mail, pour lui donner un rôle ──────────────────────
-- Comparaison insensible à la casse, blancs retirés : l'adresse est saisie
-- à la main. Une ligne au plus.
CREATE OR REPLACE FUNCTION public.profil_par_email(p_email text)
RETURNS TABLE (
  id             text,
  email          text,
  display_name   text,
  avatar_url     text,
  is_admin       boolean,
  admin_role     text,
  created_at     timestamptz,
  last_active_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'profil_par_email : réservé aux superAdmins'
      USING ERRCODE = '42501';
  END IF;

  IF p_email IS NULL OR length(trim(p_email)) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT u.id, u.email, u.display_name, u.avatar_url,
           u.is_admin, u.admin_role, u.created_at, u.last_active_at
      FROM public.users u
     WHERE lower(u.email) = lower(trim(p_email))
     ORDER BY u.created_at
     LIMIT 1;
END $$;

REVOKE ALL ON FUNCTION public.profil_par_email(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.profil_par_email(text) TO authenticated;
