import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../admin/domain/enums/admin_enums.dart';
import '../../../admin/domain/constants/role_permissions.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    @Default(AdminRole.none) AdminRole adminRole,
    @Default(false) bool isBanned,
    String? banReason,
    DateTime? bannedAt,
  }) = _UserEntity;

  /// Vérifie si l'utilisateur a un rôle admin (rétrocompatibilité)
  bool get isAdmin => adminRole != AdminRole.none;

  /// Vérifie si l'utilisateur est SuperAdmin
  bool get isSuperAdmin => adminRole == AdminRole.superAdmin;

  /// Vérifie si l'utilisateur a une permission spécifique
  bool hasPermission(AdminPermission permission) {
    return adminRole.hasPermission(permission);
  }

  /// Vérifie si l'utilisateur a au moins une des permissions données
  bool hasAnyPermission(Set<AdminPermission> permissions) {
    return adminRole.hasAnyPermission(permissions);
  }
}
