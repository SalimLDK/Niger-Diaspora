import 'package:cloud_firestore/cloud_firestore.dart';
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
    String? createdAt,
    String? updatedAt,
  }) = _ReviewModel;

  factory ReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewModelFromJson(json);

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final processedData = <String, dynamic>{
      ...data,
      'id': doc.id,
    };

    // Conversion des timestamps
    if (data['createdAt'] is Timestamp) {
      processedData['createdAt'] =
          (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['updatedAt'] is Timestamp) {
      processedData['updatedAt'] =
          (data['updatedAt'] as Timestamp).toDate().toIso8601String();
    }

    // Assurer que les listes sont bien des List<String>
    if (data['imageUrls'] != null) {
      processedData['imageUrls'] =
          (data['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }
    if (data['helpfulByUserIds'] != null) {
      processedData['helpfulByUserIds'] =
          (data['helpfulByUserIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }

    return ReviewModel.fromJson(processedData);
  }

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
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
        updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
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
        createdAt: entity.createdAt?.toIso8601String(),
        updatedAt: entity.updatedAt?.toIso8601String(),
      );
}
