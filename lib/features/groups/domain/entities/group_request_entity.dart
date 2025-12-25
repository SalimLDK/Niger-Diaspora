import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_request_entity.freezed.dart';

enum GroupRequestStatus {
  pending,
  approved,
  rejected,
}

@freezed
class GroupRequestEntity with _$GroupRequestEntity {
  const factory GroupRequestEntity({
    required String id,
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    @Default(GroupRequestStatus.pending) GroupRequestStatus status,
    String? message,
    DateTime? createdAt,
    DateTime? processedAt,
    String? processedBy,
  }) = _GroupRequestEntity;
}
