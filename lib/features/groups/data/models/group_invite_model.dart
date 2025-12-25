import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/group_invite_entity.dart';

part 'group_invite_model.freezed.dart';
part 'group_invite_model.g.dart';

@freezed
class GroupInviteModel with _$GroupInviteModel {
  const GroupInviteModel._();

  const factory GroupInviteModel({
    required String id,
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
    @Default('pending') String status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) = _GroupInviteModel;

  factory GroupInviteModel.fromJson(Map<String, dynamic> json) =>
      _$GroupInviteModelFromJson(json);

  GroupInviteEntity toEntity() => GroupInviteEntity(
        id: id,
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        inviterId: inviterId,
        inviterName: inviterName,
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        inviteePhotoUrl: inviteePhotoUrl,
        status: _parseStatus(status),
        createdAt: createdAt,
        respondedAt: respondedAt,
      );

  static GroupInviteStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return GroupInviteStatus.accepted;
      case 'declined':
        return GroupInviteStatus.declined;
      default:
        return GroupInviteStatus.pending;
    }
  }

  static GroupInviteModel fromEntity(GroupInviteEntity entity) =>
      GroupInviteModel(
        id: entity.id,
        groupId: entity.groupId,
        groupName: entity.groupName,
        groupImageUrl: entity.groupImageUrl,
        inviterId: entity.inviterId,
        inviterName: entity.inviterName,
        inviteeId: entity.inviteeId,
        inviteeName: entity.inviteeName,
        inviteePhotoUrl: entity.inviteePhotoUrl,
        status: entity.status.name,
        createdAt: entity.createdAt,
        respondedAt: entity.respondedAt,
      );
}
