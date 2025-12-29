import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    @Default(false) bool isAdmin,
    @Default(false) bool isBanned,
    String? banReason,
    DateTime? bannedAt,
  }) = _UserEntity;
}
