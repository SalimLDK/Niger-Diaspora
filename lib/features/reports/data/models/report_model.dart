import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/report_entity.dart';

part 'report_model.freezed.dart';
part 'report_model.g.dart';

/// Model pour le snapshot de contenu
@freezed
class ContentSnapshotModel with _$ContentSnapshotModel {
  const ContentSnapshotModel._();

  const factory ContentSnapshotModel({
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    String? contentType,
    Map<String, dynamic>? metadata,
    DateTime? capturedAt,
  }) = _ContentSnapshotModel;

  factory ContentSnapshotModel.fromJson(Map<String, dynamic> json) =>
      _$ContentSnapshotModelFromJson(json);

  factory ContentSnapshotModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ContentSnapshotModel();
    return ContentSnapshotModel(
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      videoUrl: data['videoUrl'] as String?,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      contentType: data['contentType'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      capturedAt: _timestampToDateTime(data['capturedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (contentType != null) 'contentType': contentType,
      if (metadata != null) 'metadata': metadata,
      'capturedAt': capturedAt != null
          ? Timestamp.fromDate(capturedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ContentSnapshot toEntity() => ContentSnapshot(
        text: text,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        fileUrl: fileUrl,
        fileName: fileName,
        contentType: contentType,
        metadata: metadata,
        capturedAt: capturedAt,
      );

  factory ContentSnapshotModel.fromEntity(ContentSnapshot entity) =>
      ContentSnapshotModel(
        text: entity.text,
        imageUrl: entity.imageUrl,
        videoUrl: entity.videoUrl,
        fileUrl: entity.fileUrl,
        fileName: entity.fileName,
        contentType: entity.contentType,
        metadata: entity.metadata,
        capturedAt: entity.capturedAt,
      );

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

@freezed
class ReportModel with _$ReportModel {
  const ReportModel._();

  const factory ReportModel({
    required String id,
    required String reporterId,
    String? reporterName,
    String? reporterPhotoUrl,
    required String targetType,
    required String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    required String reason,
    String? description,
    /// Snapshot du contenu signalé
    ContentSnapshotModel? contentSnapshot,
    /// ID de l'utilisateur signalé (pour notification)
    String? reportedUserId,
    @Default('pending') String status,
    String? adminNote,
    String? reviewedBy,
    String? reviewerName,
    String? resolution,
    DateTime? createdAt,
    DateTime? reviewedAt,
    @Default(false) bool reportedUserNotified,
  }) = _ReportModel;

  factory ReportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportModelFromJson(json);

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      reporterName: data['reporterName'] as String?,
      reporterPhotoUrl: data['reporterPhotoUrl'] as String?,
      targetType: data['targetType'] as String? ?? 'user',
      targetId: data['targetId'] as String? ?? '',
      targetName: data['targetName'] as String?,
      targetPreview: data['targetPreview'] as String?,
      conversationId: data['conversationId'] as String?,
      reason: data['reason'] as String? ?? 'other',
      description: data['description'] as String?,
      contentSnapshot: data['contentSnapshot'] != null
          ? ContentSnapshotModel.fromMap(
              data['contentSnapshot'] as Map<String, dynamic>)
          : null,
      reportedUserId: data['reportedUserId'] as String?,
      status: data['status'] as String? ?? 'pending',
      adminNote: data['adminNote'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewerName: data['reviewerName'] as String?,
      resolution: data['resolution'] as String?,
      createdAt: _timestampToDateTime(data['createdAt']),
      reviewedAt: _timestampToDateTime(data['reviewedAt']),
      reportedUserNotified: data['reportedUserNotified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterPhotoUrl': reporterPhotoUrl,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'targetPreview': targetPreview,
      'conversationId': conversationId,
      'reason': reason,
      'description': description,
      if (contentSnapshot != null) 'contentSnapshot': contentSnapshot!.toMap(),
      if (reportedUserId != null) 'reportedUserId': reportedUserId,
      'status': status,
      'adminNote': adminNote,
      'reviewedBy': reviewedBy,
      'reviewerName': reviewerName,
      'resolution': resolution,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'reviewedAt':
          reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reportedUserNotified': reportedUserNotified,
    };
  }

  ReportEntity toEntity() => ReportEntity(
        id: id,
        reporterId: reporterId,
        reporterName: reporterName,
        reporterPhotoUrl: reporterPhotoUrl,
        targetType: _parseTargetType(targetType),
        targetId: targetId,
        targetName: targetName,
        targetPreview: targetPreview,
        conversationId: conversationId,
        reason: _parseReason(reason),
        description: description,
        contentSnapshot: contentSnapshot?.toEntity(),
        reportedUserId: reportedUserId,
        status: _parseStatus(status),
        adminNote: adminNote,
        reviewedBy: reviewedBy,
        reviewerName: reviewerName,
        resolution: resolution,
        createdAt: createdAt,
        reviewedAt: reviewedAt,
        reportedUserNotified: reportedUserNotified,
      );

  factory ReportModel.fromEntity(ReportEntity entity) => ReportModel(
        id: entity.id,
        reporterId: entity.reporterId,
        reporterName: entity.reporterName,
        reporterPhotoUrl: entity.reporterPhotoUrl,
        targetType: entity.targetType.name,
        targetId: entity.targetId,
        targetName: entity.targetName,
        targetPreview: entity.targetPreview,
        conversationId: entity.conversationId,
        reason: entity.reason.name,
        description: entity.description,
        contentSnapshot: entity.contentSnapshot != null
            ? ContentSnapshotModel.fromEntity(entity.contentSnapshot!)
            : null,
        reportedUserId: entity.reportedUserId,
        status: entity.status.name,
        adminNote: entity.adminNote,
        reviewedBy: entity.reviewedBy,
        reviewerName: entity.reviewerName,
        resolution: entity.resolution,
        createdAt: entity.createdAt,
        reviewedAt: entity.reviewedAt,
        reportedUserNotified: entity.reportedUserNotified,
      );

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static ReportTargetType _parseTargetType(String value) {
    return ReportTargetType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReportTargetType.user,
    );
  }

  static ReportReason _parseReason(String value) {
    return ReportReason.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReportReason.other,
    );
  }

  static ReportStatus _parseStatus(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReportStatus.pending,
    );
  }
}
