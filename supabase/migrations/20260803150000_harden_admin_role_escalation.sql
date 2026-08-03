-- =============================================================================
-- Durcissement : empêcher l'escalade de privilèges entre rôles admin.
--
-- Problème corrigé
-- ----------------
-- 20260803120000 a ajouté la policy users_update_admin :
--     FOR UPDATE USING (is_admin()) WITH CHECK (is_admin())
--
-- Deux propriétés se combinent mal :
--   1. RLS ne filtre pas par colonne — la policy autorise l'écriture de
--      n'importe quel champ de n'importe quelle ligne users.
--   2. is_admin() est un simple booléen, qui ne distingue pas les 4 rôles de
--      l'application (superAdmin, contentMod, businessMod, financeMod — voir
--      lib/features/admin/domain/enums/admin_enums.dart). Et
--      role_management_provider.dart écrit is_admin = true pour TOUS ces rôles
--      (`final isAdmin = newRole != AdminRole.none`).
--
-- Conséquence : un contentMod — le rôle le moins privilégié — pouvait exécuter
--     UPDATE users SET admin_role = 'superAdmin' WHERE id = <lui-même>
-- La hiérarchie des rôles n'est appliquée que côté client
-- (lib/features/admin/domain/enums/role_permissions.dart), donc contournable
-- par un appel direct à l'API : la clé anon est publique, embarquée dans l'app.
-- Le même compte pouvait aussi rétrograder le superAdmin légitime.
--
-- Correctif
-- ---------
-- La policy reste en place : le back-office a réellement besoin d'écrire sur
-- users pour bannir et vérifier des comptes (admin_provider.dart:1509..1653).
-- Ce sont uniquement les deux colonnes de privilège qu'on protège, par un
-- trigger — ce que RLS ne sait pas exprimer.
--
-- Règles appliquées aux seules sessions applicatives :
--   - seul un superAdmin peut modifier is_admin / admin_role ;
--   - personne ne peut modifier ses propres droits, superAdmin compris
--     (empêche l'auto-promotion comme l'auto-rétrogradation accidentelle).
--
-- L'amorçage manuel documenté en 20260803120000 reste possible : sans session
-- applicative (SQL Editor, service_role, migration), firebase_uid() est NULL
-- et le trigger laisse passer.
--
-- ⚠ Reste volontairement en dehors de ce correctif : un admin conserve
-- l'écriture sur les autres colonnes de toutes les lignes users. C'est le
-- niveau de pouvoir attendu d'un back-office, mais un compte admin compromis
-- reste un accès en écriture large. À revoir si les rôles doivent être
-- réellement cloisonnés (contentMod ne devrait pas pouvoir toucher aux
-- données bancaires, par exemple).
-- =============================================================================

-- is_admin() était SECURITY DEFINER sans search_path figé. Une fonction qui
-- arbitre tous les accès admin doit résoudre ses objets de façon déterministe,
-- sinon un schéma placé en tête de search_path peut détourner la résolution.
-- Corps inchangé par rapport à 20260803034145.
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM users WHERE id = (SELECT firebase_uid())),
    FALSE
  )
$$;

-- Le pendant manquant : is_admin() dit « c'est un admin », pas « lequel ».
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT COALESCE(
    (SELECT is_admin AND admin_role = 'superAdmin'
       FROM users WHERE id = (SELECT firebase_uid())),
    FALSE
  )
$$;

-- SECURITY INVOKER volontairement (pas DEFINER) : le trigger n'a besoin
-- d'aucun privilège supplémentaire, il délègue la décision à is_super_admin()
-- qui est SECURITY DEFINER.
CREATE OR REPLACE FUNCTION guard_admin_flags()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = public, pg_temp AS $$
DECLARE
  v_caller TEXT;
BEGIN
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin
     OR NEW.admin_role IS DISTINCT FROM OLD.admin_role THEN

    v_caller := (SELECT firebase_uid());

    -- Pas de session applicative : SQL Editor, service_role, migration.
    -- C'est le chemin d'amorçage du premier superAdmin.
    IF v_caller IS NULL THEN
      RETURN NEW;
    END IF;

    IF NOT is_super_admin() THEN
      RAISE EXCEPTION
        'Seul un superAdmin peut modifier les droits admin (is_admin, admin_role)'
        USING ERRCODE = '42501';
    END IF;

    IF OLD.id = v_caller THEN
      RAISE EXCEPTION
        'Modification de ses propres droits admin interdite'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS users_guard_admin_flags ON users;
CREATE TRIGGER users_guard_admin_flags
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION guard_admin_flags();
