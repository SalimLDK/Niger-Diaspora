import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_invite_entity.freezed.dart';

enum GroupInviteStatus {
  pending,
  accepted,
  declined,
}

@freezed
class GroupInviteEntity with _$GroupInviteEntity {
  const factory GroupInviteEntity({
    required String id,
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
    @Default(GroupInviteStatus.pending) GroupInviteStatus status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) = _GroupInviteEntity;
}
