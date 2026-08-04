import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/group_request_entity.dart';

import '../../../../core/utils/date_parsing.dart';
part 'group_request_model.freezed.dart';
part 'group_request_model.g.dart';

@freezed
class GroupRequestModel with _$GroupRequestModel {
  const GroupRequestModel._();

  const factory GroupRequestModel({
    required String id,
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    @Default('pending') String status,
    String? message,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
    @LocalDateTimeNullableConverter() DateTime? processedAt,
    String? processedBy,
  }) = _GroupRequestModel;

  factory GroupRequestModel.fromJson(Map<String, dynamic> json) =>
      _$GroupRequestModelFromJson(json);

  GroupRequestEntity toEntity() => GroupRequestEntity(
        id: id,
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        requesterId: requesterId,
        requesterName: requesterName,
        requesterPhotoUrl: requesterPhotoUrl,
        status: _parseStatus(status),
        message: message,
        createdAt: createdAt,
        processedAt: processedAt,
        processedBy: processedBy,
      );

  static GroupRequestStatus _parseStatus(String status) {
    switch (status) {
      case 'approved':
        return GroupRequestStatus.approved;
      case 'rejected':
        return GroupRequestStatus.rejected;
      default:
        return GroupRequestStatus.pending;
    }
  }

  static GroupRequestModel fromEntity(GroupRequestEntity entity) =>
      GroupRequestModel(
        id: entity.id,
        groupId: entity.groupId,
        groupName: entity.groupName,
        groupImageUrl: entity.groupImageUrl,
        requesterId: entity.requesterId,
        requesterName: entity.requesterName,
        requesterPhotoUrl: entity.requesterPhotoUrl,
        status: entity.status.name,
        message: entity.message,
        createdAt: entity.createdAt,
        processedAt: entity.processedAt,
        processedBy: entity.processedBy,
      );
}
