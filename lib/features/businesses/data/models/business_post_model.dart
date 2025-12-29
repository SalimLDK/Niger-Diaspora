import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/business_post_entity.dart';

part 'business_post_model.freezed.dart';
part 'business_post_model.g.dart';

@freezed
class BusinessPostModel with _$BusinessPostModel {
  const BusinessPostModel._();

  const factory BusinessPostModel({
    required String id,
    required String businessId,
    required String title,
    required String content,
    @Default('announcement') String type,
    @Default([]) List<String> imageUrls,
    double? originalPrice,
    double? discountedPrice,
    int? discountPercent,
    String? offerStartDate,
    String? offerEndDate,
    String? promoCode,
    @Default(0) int viewCount,
    @Default(0) int likeCount,
    @Default(true) bool isActive,
    String? createdAt,
    String? updatedAt,
  }) = _BusinessPostModel;

  factory BusinessPostModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessPostModelFromJson(json);

  factory BusinessPostModel.fromEntity(BusinessPostEntity entity) {
    return BusinessPostModel(
      id: entity.id,
      businessId: entity.businessId,
      title: entity.title,
      content: entity.content,
      type: entity.type.name,
      imageUrls: entity.imageUrls,
      originalPrice: entity.originalPrice,
      discountedPrice: entity.discountedPrice,
      discountPercent: entity.discountPercent,
      offerStartDate: entity.offerStartDate?.toIso8601String(),
      offerEndDate: entity.offerEndDate?.toIso8601String(),
      promoCode: entity.promoCode,
      viewCount: entity.viewCount,
      likeCount: entity.likeCount,
      isActive: entity.isActive,
      createdAt: entity.createdAt?.toIso8601String(),
      updatedAt: entity.updatedAt?.toIso8601String(),
    );
  }

  BusinessPostEntity toEntity() {
    return BusinessPostEntity(
      id: id,
      businessId: businessId,
      title: title,
      content: content,
      type: BusinessPostType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => BusinessPostType.announcement,
      ),
      imageUrls: imageUrls,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      discountPercent: discountPercent,
      offerStartDate:
          offerStartDate != null ? DateTime.tryParse(offerStartDate!) : null,
      offerEndDate:
          offerEndDate != null ? DateTime.tryParse(offerEndDate!) : null,
      promoCode: promoCode,
      viewCount: viewCount,
      likeCount: likeCount,
      isActive: isActive,
      createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
      updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
    );
  }
}
