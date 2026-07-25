import 'package:equatable/equatable.dart';

/// Represents a single sticker
class StickerEntity extends Equatable {
  final String id;
  final String packId;
  final String url;
  final String? emoji; // Associated emoji for search
  final int order; // Display order within pack
  final bool isAnimated; // true if WebP animated or GIF
  final int? frameCount; // Number of frames for animated stickers

  const StickerEntity({
    required this.id,
    required this.packId,
    required this.url,
    this.emoji,
    this.order = 0,
    this.isAnimated = false,
    this.frameCount,
  });

  StickerEntity copyWith({
    String? id,
    String? packId,
    String? url,
    String? emoji,
    int? order,
    bool? isAnimated,
    int? frameCount,
  }) {
    return StickerEntity(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      url: url ?? this.url,
      emoji: emoji ?? this.emoji,
      order: order ?? this.order,
      isAnimated: isAnimated ?? this.isAnimated,
      frameCount: frameCount ?? this.frameCount,
    );
  }

  @override
  List<Object?> get props => [id, packId, url, emoji, order, isAnimated, frameCount];
}
