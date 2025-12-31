import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/enums/admin_enums.dart';
import '../../domain/constants/role_permissions.dart';

part 'permission_provider.g.dart';

/// Provider qui récupère le rôle admin de l'utilisateur courant depuis Firestore
@riverpod
Stream<AdminRole> currentAdminRole(Ref ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('[PermissionProvider] No user logged in');
    return Stream.value(AdminRole.none);
  }

  debugPrint('[PermissionProvider] Checking role for user: ${user.uid}');

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) {
      debugPrint('[PermissionProvider] User document does not exist');
      return AdminRole.none;
    }

    final data = doc.data();
    if (data == null) {
      debugPrint('[PermissionProvider] User document has no data');
      return AdminRole.none;
    }

    // Migration support: handle old isAdmin field
    if (data['adminRole'] != null) {
      final role = AdminRole.fromString(data['adminRole'] as String?);
      debugPrint('[PermissionProvider] Found adminRole: ${data['adminRole']} -> $role');
      return role;
    } else if (data['isAdmin'] == true) {
      debugPrint('[PermissionProvider] Found legacy isAdmin: true -> superAdmin');
      return AdminRole.superAdmin;
    }

    debugPrint('[PermissionProvider] No admin role found, returning none');
    return AdminRole.none;
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
