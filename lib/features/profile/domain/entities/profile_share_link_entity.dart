import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_share_link_entity.freezed.dart';

@freezed
class ProfileShareLinkEntity with _$ProfileShareLinkEntity {
  const factory ProfileShareLinkEntity({
    required String id,
    required String userId,
    required String shortCode,
    required DateTime createdAt,
    DateTime? expiresAt,
    @Default(0) int clickCount,
  }) = _ProfileShareLinkEntity;
}
