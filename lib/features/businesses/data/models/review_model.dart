import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/review_entity.dart';

part 'review_model.freezed.dart';
part 'review_model.g.dart';

@freezed
class ReviewModel with _$ReviewModel {
  const ReviewModel._();

  const factory ReviewModel({
    required String id,
    required String businessId,
    required String userId,
    required String userDisplayName,
    String? userPhotoUrl,
    required int rating,
    String? title,
    required String content,
    @Default([]) List<String> imageUrls,
    @Default(0) int helpfulCount,
    @Default([]) List<String> helpfulByUserIds,
    @Default('published') String status,
    String? ownerReply,
    String? ownerReplyAt,
    String? createdAt,
    String? updatedAt,
  }) = _ReviewModel;

  factory ReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewModelFromJson(json);

  ReviewEntity toEntity() => ReviewEntity(
        id: id,
        businessId: businessId,
        userId: userId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        rating: rating,
        title: title,
        content: content,
        imageUrls: imageUrls,
        helpfulCount: helpfulCount,
        helpfulByUserIds: helpfulByUserIds,
        status: _parseStatus(status),
        ownerReply: ownerReply,
        ownerReplyAt:
            ownerReplyAt != null ? DateTime.tryParse(ownerReplyAt!)?.toLocal() : null,
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!)?.toLocal() : null,
        updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!)?.toLocal() : null,
      );

  static ReviewStatus _parseStatus(String value) {
    return ReviewStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReviewStatus.published,
    );
  }

  factory ReviewModel.fromEntity(ReviewEntity entity) => ReviewModel(
        id: entity.id,
        businessId: entity.businessId,
        userId: entity.userId,
        userDisplayName: entity.userDisplayName,
        userPhotoUrl: entity.userPhotoUrl,
        rating: entity.rating,
        title: entity.title,
        content: entity.content,
        imageUrls: entity.imageUrls,
        helpfulCount: entity.helpfulCount,
        helpfulByUserIds: entity.helpfulByUserIds,
        status: entity.status.name,
        ownerReply: entity.ownerReply,
        ownerReplyAt: entity.ownerReplyAt?.toUtc().toIso8601String(),
        createdAt: entity.createdAt?.toUtc().toIso8601String(),
        updatedAt: entity.updatedAt?.toUtc().toIso8601String(),
      );
}
