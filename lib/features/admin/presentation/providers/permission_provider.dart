import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/constants/role_permissions.dart';
import '../../domain/enums/admin_enums.dart';

part 'permission_provider.g.dart';

/// Nom du custom claim Firebase qui porte le rôle admin.
///
/// Posé UNIQUEMENT par la Cloud Function `setAdminRole`
/// (`functions/roles_admin.js`) depuis Postgres `users.admin_role`, la
/// source. Les règles Firestore et RTDB lisent le même claim : ce que le
/// panneau affiche et ce que le serveur accorde viennent du même jeton.
const String claimRoleAdmin = 'adminRole';

/// Le rôle porté par les claims d'un jeton — `none` s'il n'y en a pas, ou si
/// la valeur n'est pas l'un des quatre rôles.
///
/// Jusqu'au 2026-10-14 le rôle se lisait dans le document Firestore
/// `users/{uid}` (`adminRole`, ou le drapeau hérité `isAdmin`, promu en
/// superAdmin). Un admin sans document — tous ceux créés depuis la migration
/// vers Supabase — n'avait donc aucun rôle ici, et n'importe quel admin
/// pouvait poser `isAdmin: true` sur n'importe qui (audit du 14/10, § 2 et
/// § 7.1). Plus aucun repli : pas de claim, pas de rôle.
AdminRole roleDepuisClaims(Map<String, dynamic>? claims) {
  final valeur = claims?[claimRoleAdmin];
  if (valeur is! String) return AdminRole.none;
  return AdminRole.fromString(valeur);
}

/// Force le renouvellement du jeton du compte connecté.
///
/// Un claim posé côté serveur n'entre dans le jeton qu'à son prochain
/// renouvellement (jusqu'à une heure). À appeler après une assignation de
/// rôle : le renouvellement émet sur `idTokenChanges()`, donc
/// [currentAdminRole] relit les claims sans qu'on ait rien d'autre à faire.
Future<void> rafraichirJetonAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await user.getIdToken(true);
  } catch (e) {
    debugPrint('[PermissionProvider] renouvellement du jeton impossible : $e');
  }
}

/// Le rôle admin du compte courant, lu dans les claims de son jeton.
///
/// Au premier passage le jeton est renouvelé de force (`getIdTokenResult(true)`) :
/// un rôle posé depuis la dernière connexion est vu tout de suite, pas une
/// heure plus tard. Ce renouvellement émet lui-même sur `idTokenChanges()` ;
/// les passages suivants lisent le jeton en cache — sans quoi chaque lecture
/// forcée en déclencherait une autre, sans fin.
@riverpod
Stream<AdminRole> currentAdminRole(Ref ref) {
  var premierPassage = true;
  return FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
    if (user == null) {
      premierPassage = true;
      return AdminRole.none;
    }
    final forcer = premierPassage;
    premierPassage = false;
    try {
      final resultat = await user.getIdTokenResult(forcer);
      final role = roleDepuisClaims(resultat.claims);
      debugPrint('[PermissionProvider] claim $claimRoleAdmin -> $role');
      return role;
    } catch (e) {
      // Un jeton illisible n'est pas un rôle : on ne donne rien, et on le dit.
      debugPrint('[PermissionProvider] lecture des claims impossible : $e');
      return AdminRole.none;
    }
  });
}

/// Provider synchrone pour obtenir le rôle admin actuel (avec valeur par défaut)
@riverpod
AdminRole adminRole(Ref ref) {
  final asyncRole = ref.watch(currentAdminRoleProvider);
  return asyncRole.valueOrNull ?? AdminRole.none;
}

/// Vérifie si l'utilisateur a une permission spécifique
@riverpod
bool hasPermission(Ref ref, AdminPermission permission) {
  final role = ref.watch(adminRoleProvider);
  return role.hasPermission(permission);
}

/// Vérifie si l'utilisateur a au moins une des permissions données
@riverpod
bool hasAnyPermission(Ref ref, Set<AdminPermission> permissions) {
  final role = ref.watch(adminRoleProvider);
  return role.hasAnyPermission(permissions);
}

/// Vérifie si l'utilisateur est SuperAdmin
@riverpod
bool isSuperAdmin(Ref ref) {
  final role = ref.watch(adminRoleProvider);
  return role == AdminRole.superAdmin;
}

/// Vérifie si l'utilisateur a un rôle admin (n'importe lequel)
@riverpod
bool isAnyAdmin(Ref ref) {
  final role = ref.watch(adminRoleProvider);
  return role.isAdmin;
}

/// Classe utilitaire pour vérifier les permissions de manière synchrone
class PermissionChecker {
  final AdminRole role;

  const PermissionChecker(this.role);

  bool hasPermission(AdminPermission permission) {
    return role.hasPermission(permission);
  }

  bool hasAnyPermission(Set<AdminPermission> permissions) {
    return role.hasAnyPermission(permissions);
  }

  bool hasAllPermissions(Set<AdminPermission> permissions) {
    return role.hasAllPermissions(permissions);
  }

  bool get isSuperAdmin => role == AdminRole.superAdmin;
  bool get isAdmin => role.isAdmin;
}

/// Provider pour obtenir un PermissionChecker
@riverpod
PermissionChecker permissionChecker(Ref ref) {
  final role = ref.watch(adminRoleProvider);
  return PermissionChecker(role);
}
