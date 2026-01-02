import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/enums/admin_enums.dart';
import 'admin_provider.dart';

part 'role_management_provider.freezed.dart';
part 'role_management_provider.g.dart';

/// Représente un admin avec son rôle
@freezed
class AdminUser with _$AdminUser {
  const factory AdminUser({
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
    required AdminRole adminRole,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) = _AdminUser;

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return AdminUser(id: doc.id, adminRole: AdminRole.none);
    }

    AdminRole role = AdminRole.none;
    if (data['adminRole'] != null) {
      role = AdminRole.fromString(data['adminRole'] as String?);
    } else if (data['isAdmin'] == true) {
      role = AdminRole.superAdmin;
    }

    // Helper to parse DateTime from Timestamp or String
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AdminUser(
      id: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      adminRole: role,
      createdAt: parseDate(data['createdAt']),
      lastLoginAt: parseDate(data['lastLoginAt']),
    );
  }
}

/// État de la gestion des rôles
@freezed
class RoleManagementState with _$RoleManagementState {
  const factory RoleManagementState({
    @Default([]) List<AdminUser> admins,
    @Default(false) bool isLoading,
    String? error,
    String? successMessage,
  }) = _RoleManagementState;
}

/// Provider pour gérer les rôles admin (SuperAdmin uniquement)
@riverpod
class RoleManagementNotifier extends _$RoleManagementNotifier {
  @override
  RoleManagementState build() {
    return const RoleManagementState();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Charge la liste de tous les admins
  Future<void> loadAdmins() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Récupérer les utilisateurs avec un adminRole défini
      final snapshot = await _firestore
          .collection('users')
          .where('adminRole', isNull: false)
          .get();

      // Aussi récupérer les anciens admins (isAdmin: true) pour la migration
      final legacySnapshot = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();

      final adminDocs = <String, DocumentSnapshot>{};

      // Ajouter les admins avec nouveau format
      for (final doc in snapshot.docs) {
        adminDocs[doc.id] = doc;
      }

      // Ajouter les anciens admins (sans écraser)
      for (final doc in legacySnapshot.docs) {
        if (!adminDocs.containsKey(doc.id)) {
          adminDocs[doc.id] = doc;
        }
      }

      final admins = adminDocs.values
          .map((doc) => AdminUser.fromFirestore(doc))
          .where((admin) => admin.adminRole != AdminRole.none)
          .toList();

      // Trier par rôle (superAdmin en premier) puis par nom
      admins.sort((a, b) {
        final roleCompare = a.adminRole.index.compareTo(b.adminRole.index);
        if (roleCompare != 0) return roleCompare;
        return (a.displayName ?? '').compareTo(b.displayName ?? '');
      });

      state = state.copyWith(admins: admins, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du chargement des admins: $e',
      );
    }
  }

  /// Assigne un rôle admin à un utilisateur
  Future<bool> assignRole(String userId, AdminRole newRole) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      // Récupérer les infos de l'utilisateur cible
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        state = state.copyWith(
          isLoading: false,
          error: 'Utilisateur non trouvé',
        );
        return false;
      }

      final userData = userDoc.data()!;
      final previousRole = AdminRole.fromString(userData['adminRole'] as String?);

      // Mettre à jour le rôle
      await _firestore.collection('users').doc(userId).update({
        'adminRole': newRole == AdminRole.none ? null : newRole.name,
        // Nettoyer l'ancien champ isAdmin si présent
        'isAdmin': FieldValue.delete(),
      });

      // Logger l'action
      final admin = ref.read(currentAdminProvider);
      await AdminAuditHelper.log(
        adminId: admin?.id ?? 'unknown',
        adminName: admin?.name,
        action: previousRole == AdminRole.none ? 'assign_role' : 'change_role',
        targetType: 'user',
        targetId: userId,
        details: {
          'previousRole': previousRole.name,
          'newRole': newRole.name,
          'targetEmail': userData['email'],
          'targetName': userData['displayName'],
        },
      );

      // Recharger la liste
      await loadAdmins();

      state = state.copyWith(
        successMessage: newRole == AdminRole.none
            ? 'Rôle admin révoqué avec succès'
            : 'Rôle ${newRole.displayName} assigné avec succès',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de l\'assignation du rôle: $e',
      );
      return false;
    }
  }

  /// Révoque le rôle admin d'un utilisateur
  Future<bool> revokeRole(String userId) async {
    return assignRole(userId, AdminRole.none);
  }

  /// Recherche un utilisateur par email pour lui assigner un rôle
  Future<AdminUser?> searchUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return AdminUser.fromFirestore(snapshot.docs.first);
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de la recherche: $e');
      return null;
    }
  }

  /// Efface les messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Helper pour logger les actions admin (repris de admin_provider.dart)
class AdminAuditHelper {
  static Future<void> log({
    required String adminId,
    String? adminName,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'adminId': adminId,
        'adminName': adminName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error but don't throw - audit logging shouldn't break operations
      debugPrint('Failed to log admin action: $e');
    }
  }
}
