import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_entity.freezed.dart';

@freezed
class ReviewEntity with _$ReviewEntity {
  const factory ReviewEntity({
    required String id,
    required String businessId,
    required String userId,
    required String userDisplayName,
    String? userPhotoUrl,
    required int rating, // 1-5
    String? title,
    required String content,
    @Default([]) List<String> imageUrls,
    @Default(0) int helpfulCount,
    @Default([]) List<String> helpfulByUserIds,
    @Default(ReviewStatus.published) ReviewStatus status,
    // Réponse du gérant de l'entreprise à cet avis (§18c).
    String? ownerReply,
    DateTime? ownerReplyAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ReviewEntity;
}

enum ReviewStatus {
  pending,
  published,
  flagged,
}

extension ReviewStatusExtension on ReviewStatus {
  String get label {
    switch (this) {
      case ReviewStatus.pending:
        return 'En attente';
      case ReviewStatus.published:
        return 'Publie';
      case ReviewStatus.flagged:
        return 'Signale';
    }
  }

  IconData get icon {
    switch (this) {
      case ReviewStatus.pending:
        return Icons.hourglass_empty;
      case ReviewStatus.published:
        return Icons.check_circle;
      case ReviewStatus.flagged:
        return Icons.flag;
    }
  }

  Color get color {
    switch (this) {
      case ReviewStatus.pending:
        return Colors.orange;
      case ReviewStatus.published:
        return Colors.green;
      case ReviewStatus.flagged:
        return Colors.red;
    }
  }
}
