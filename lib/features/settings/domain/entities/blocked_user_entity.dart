import 'package:freezed_annotation/freezed_annotation.dart';

part 'blocked_user_entity.freezed.dart';

@freezed
class BlockedUserEntity with _$BlockedUserEntity {
  const factory BlockedUserEntity({
    required String id,
    required String displayName,
    String? photoUrl,
    required DateTime blockedAt,
  }) = _BlockedUserEntity;
}
