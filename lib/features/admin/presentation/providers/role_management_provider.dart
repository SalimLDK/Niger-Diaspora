import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/message_erreur.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../domain/enums/admin_enums.dart';
import 'permission_provider.dart';
import 'refus_callable.dart';

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

  /// Une ligne rendue par `administrateurs()` ou `profil_par_email()`
  /// (migration 20261014123000) : Postgres `users`, la source du rôle.
  ///
  /// `is_admin` sans `admin_role` — l'admin fantôme mesuré en production le
  /// 2026-10-14 — donne `AdminRole.none` : on ne promeut plus un booléen en
  /// superAdmin, c'est ce que faisait `UserModel.fromJson` et c'est ce qui
  /// affichait un Super Administrateur qui n'en était pas un. Le rôle est
  /// `admin_role`, rien d'autre ; [estIncoherent] dit quand les deux
  /// colonnes se contredisent.
  factory AdminUser.fromRow(Map<String, dynamic> row) {
    return AdminUser(
      id: row['id'] as String,
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      photoUrl: row['avatar_url'] as String?,
      adminRole: AdminRole.fromString(row['admin_role'] as String?),
      createdAt: _dateDepuis(row['created_at']),
      lastLoginAt: _dateDepuis(row['last_active_at']),
    );
  }

  /// Vrai quand `is_admin` et `admin_role` d'une ligne se contredisent :
  /// tous les pouvoirs RLS sans rôle visible, ou l'inverse. À corriger par
  /// `tools/amorcer_super_admin.mjs` ou par une assignation depuis l'écran.
  static bool estIncoherent(Map<String, dynamic> row) {
    final isAdmin = row['is_admin'] == true;
    final role = AdminRole.fromString(row['admin_role'] as String?);
    return isAdmin != role.isAdmin;
  }
}

DateTime? _dateDepuis(dynamic valeur) {
  if (valeur is DateTime) return valeur;
  if (valeur is String) {
    return DateTime.tryParse(valeur)?.toLocal();
  }
  return null;
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
///
/// Plus aucune écriture directe : le rôle s'assigne par la Cloud Function
/// `setAdminRole`, qui écrit Postgres (la source), pose le custom claim et
/// RTDB, et journalise côté serveur. L'ancien `_syncRoleToBackends` écrivait
/// les trois registres depuis le client, en *best-effort*, et l'audit
/// Firestore était refusé en silence (audit du 14/10, § 2 et § 7.5).
@riverpod
class RoleManagementNotifier extends _$RoleManagementNotifier {
  @override
  RoleManagementState build() {
    return const RoleManagementState();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Charge la liste de tous les admins, depuis Postgres.
  Future<void> loadAdmins() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        state = state.copyWith(
          isLoading: false,
          error: messageErreurUsager('permission denied: session absente'),
        );
        return;
      }

      final rows = (await _supabase.rpc('administrateurs') as List)
          .cast<Map<String, dynamic>>();

      final incoherents = rows.where(AdminUser.estIncoherent).toList();
      if (incoherents.isNotEmpty) {
        // Visibles dans le journal, pas dans la liste : l'écran groupe par
        // rôle et ignore `none`. Les montrer est un chantier d'écran.
        debugPrint(
          '[RoleManagement] ${incoherents.length} compte(s) avec is_admin et '
          'admin_role contradictoires : ${incoherents.map((r) => r['id']).join(', ')}',
        );
      }

      final admins = rows
          .map(AdminUser.fromRow)
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
        error: messageErreurUsager(e),
      );
    }
  }

  /// Assigne un rôle admin à un utilisateur, par la Cloud Function.
  ///
  /// Le serveur vérifie que l'appelant est superAdmin dans Postgres, refuse
  /// sa propre ligne et le retrait du dernier superAdmin, écrit les trois
  /// registres et journalise. Un refus arrive en [FirebaseFunctionsException]
  /// avec un message en français : il est montré tel quel.
  Future<bool> assignRole(String userId, AdminRole newRole) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final reponse = await FirebaseFunctions.instance
          .httpsCallable('setAdminRole')
          .call<dynamic>({
        'uid': userId,
        'adminRole': newRole == AdminRole.none ? 'none' : newRole.name,
      });
      final data = reponse.data;
      final journalise = data is Map && data['journalise'] == true;

      // Le claim n'entre dans un jeton qu'à son renouvellement. Celui du
      // compte connecté n'a pas changé (le serveur refuse sa propre ligne),
      // mais le renouveler ici garantit que ce que le panneau affiche vient
      // du jeton courant, pas d'un cache d'une heure — et `currentAdminRole`
      // relit les claims sur l'émission d'`idTokenChanges()`.
      await rafraichirJetonAdmin();

      await loadAdmins();

      state = state.copyWith(
        successMessage: newRole == AdminRole.none
            ? 'Rôle admin révoqué avec succès'
            : 'Rôle ${newRole.displayName} assigné avec succès',
        // Le rôle est posé ; un journal refusé doit rester visible.
        error: journalise
            ? null
            : 'Rôle enregistré, mais non journalisé dans admin_audit_logs.',
      );
      return true;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: messageRefusCallable(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: messageErreurUsager(e),
      );
      return false;
    }
  }

  /// Révoque le rôle admin d'un utilisateur
  Future<bool> revokeRole(String userId) async {
    return assignRole(userId, AdminRole.none);
  }

  /// Recherche un utilisateur par email pour lui assigner un rôle.
  ///
  /// Dans Postgres, par `profil_par_email()` — plus dans Firestore, qui ne
  /// connaît que les comptes d'avant la migration.
  Future<AdminUser?> searchUserByEmail(String email) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        state = state.copyWith(
          error: messageErreurUsager('permission denied: session absente'),
        );
        return null;
      }

      final rows = (await _supabase.rpc(
        'profil_par_email',
        params: {'p_email': email.trim().toLowerCase()},
      ) as List)
          .cast<Map<String, dynamic>>();

      if (rows.isEmpty) {
        return null;
      }

      return AdminUser.fromRow(rows.first);
    } catch (e) {
      state = state.copyWith(error: messageErreurUsager(e));
      return null;
    }
  }

  /// Efface les messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}
