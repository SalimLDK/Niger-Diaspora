import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_post_entity.freezed.dart';

@freezed
class BusinessPostEntity with _$BusinessPostEntity {
  const factory BusinessPostEntity({
    required String id,
    required String businessId,
    required String title,
    required String content,
    @Default(BusinessPostType.announcement) BusinessPostType type,
    @Default([]) List<String> imageUrls,
    // For offers/promotions
    double? originalPrice,
    double? discountedPrice,
    int? discountPercent,
    DateTime? offerStartDate,
    DateTime? offerEndDate,
    String? promoCode,
    // Metadata
    @Default(0) int viewCount,
    @Default(0) int likeCount,
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BusinessPostEntity;
}

enum BusinessPostType {
  announcement,
  offer,
  news,
  event,
}

extension BusinessPostTypeExtension on BusinessPostType {
  String get label {
    switch (this) {
      case BusinessPostType.announcement:
        return 'Annonce';
      case BusinessPostType.offer:
        return 'Offre';
      case BusinessPostType.news:
        return 'Actualite';
      case BusinessPostType.event:
        return 'Evenement';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessPostType.announcement:
        return Icons.campaign;
      case BusinessPostType.offer:
        return Icons.local_offer;
      case BusinessPostType.news:
        return Icons.article;
      case BusinessPostType.event:
        return Icons.event;
    }
  }

  Color get color {
    switch (this) {
      case BusinessPostType.announcement:
        return Colors.blue;
      case BusinessPostType.offer:
        return Colors.orange;
      case BusinessPostType.news:
        return Colors.teal;
      case BusinessPostType.event:
        return Colors.purple;
    }
  }
}
