// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ContentSnapshotModelImpl _$$ContentSnapshotModelImplFromJson(
  Map<String, dynamic> json,
) => _$ContentSnapshotModelImpl(
  text: json['text'] as String?,
  imageUrl: json['imageUrl'] as String?,
  videoUrl: json['videoUrl'] as String?,
  fileUrl: json['fileUrl'] as String?,
  fileName: json['fileName'] as String?,
  contentType: json['contentType'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  capturedAt: const LocalDateTimeNullableConverter().fromJson(
    json['capturedAt'],
  ),
);

Map<String, dynamic> _$$ContentSnapshotModelImplToJson(
  _$ContentSnapshotModelImpl instance,
) => <String, dynamic>{
  'text': instance.text,
  'imageUrl': instance.imageUrl,
  'videoUrl': instance.videoUrl,
  'fileUrl': instance.fileUrl,
  'fileName': instance.fileName,
  'contentType': instance.contentType,
  'metadata': instance.metadata,
  'capturedAt': const LocalDateTimeNullableConverter().toJson(
    instance.capturedAt,
  ),
};

_$ReportModelImpl _$$ReportModelImplFromJson(Map<String, dynamic> json) =>
    _$ReportModelImpl(
      id: json['id'] as String,
      reporterId: json['reporterId'] as String,
      reporterName: json['reporterName'] as String?,
      reporterPhotoUrl: json['reporterPhotoUrl'] as String?,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      targetName: json['targetName'] as String?,
      targetPreview: json['targetPreview'] as String?,
      conversationId: json['conversationId'] as String?,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      contentSnapshot:
          json['contentSnapshot'] == null
              ? null
              : ContentSnapshotModel.fromJson(
                json['contentSnapshot'] as Map<String, dynamic>,
              ),
      reportedUserId: json['reportedUserId'] as String?,
      status: json['status'] as String? ?? 'pending',
      adminNote: json['adminNote'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewerName: json['reviewerName'] as String?,
      resolution: json['resolution'] as String?,
      createdAt: const LocalDateTimeNullableConverter().fromJson(
        json['createdAt'],
      ),
      reviewedAt: const LocalDateTimeNullableConverter().fromJson(
        json['reviewedAt'],
      ),
      reportedUserNotified: json['reportedUserNotified'] as bool? ?? false,
    );

Map<String, dynamic> _$$ReportModelImplToJson(_$ReportModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reporterId': instance.reporterId,
      'reporterName': instance.reporterName,
      'reporterPhotoUrl': instance.reporterPhotoUrl,
      'targetType': instance.targetType,
      'targetId': instance.targetId,
      'targetName': instance.targetName,
      'targetPreview': instance.targetPreview,
      'conversationId': instance.conversationId,
      'reason': instance.reason,
      'description': instance.description,
      'contentSnapshot': instance.contentSnapshot,
      'reportedUserId': instance.reportedUserId,
      'status': instance.status,
      'adminNote': instance.adminNote,
      'reviewedBy': instance.reviewedBy,
      'reviewerName': instance.reviewerName,
      'resolution': instance.resolution,
      'createdAt': const LocalDateTimeNullableConverter().toJson(
        instance.createdAt,
      ),
      'reviewedAt': const LocalDateTimeNullableConverter().toJson(
        instance.reviewedAt,
      ),
      'reportedUserNotified': instance.reportedUserNotified,
    };
