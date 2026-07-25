import 'package:equatable/equatable.dart';

import 'sticker_entity.dart';

/// Status of a user-created sticker pack
enum StickerPackStatus {
  pending, // Awaiting moderation
  approved, // Approved for use
  rejected, // Rejected by moderation
}

/// Represents a sticker pack containing multiple stickers
class StickerPackEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String thumbnailUrl;
  final String creatorId;
  final String? creatorName;
  final List<StickerEntity> stickers;
  final bool isOfficial; // App-provided vs user-created
  final bool isPremium; // For future monetization
  final bool isPublic; // Visible to other users
  final StickerPackStatus status; // Moderation status
  final String? moderationNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int downloadCount;

  const StickerPackEntity({
    required this.id,
    required this.name,
    this.description,
    required this.thumbnailUrl,
    required this.creatorId,
    this.creatorName,
    this.stickers = const [],
    this.isOfficial = false,
    this.isPremium = false,
    this.isPublic = true,
    this.status = StickerPackStatus.approved,
    this.moderationNotes,
    required this.createdAt,
    this.updatedAt,
    this.downloadCount = 0,
  });

  /// Number of stickers in this pack
  int get stickerCount => stickers.length;

  /// Check if pack has animated stickers
  bool get hasAnimatedStickers => stickers.any((s) => s.isAnimated);

  StickerPackEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? thumbnailUrl,
    String? creatorId,
    String? creatorName,
    List<StickerEntity>? stickers,
    bool? isOfficial,
    bool? isPremium,
    bool? isPublic,
    StickerPackStatus? status,
    String? moderationNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? downloadCount,
  }) {
    return StickerPackEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      stickers: stickers ?? this.stickers,
      isOfficial: isOfficial ?? this.isOfficial,
      isPremium: isPremium ?? this.isPremium,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      moderationNotes: moderationNotes ?? this.moderationNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        thumbnailUrl,
        creatorId,
        creatorName,
        stickers,
        isOfficial,
        isPremium,
        isPublic,
        status,
        moderationNotes,
        createdAt,
        updatedAt,
        downloadCount,
      ];
}
