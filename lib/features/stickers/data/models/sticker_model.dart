
import '../../domain/entities/sticker_entity.dart';

/// Data model for a single sticker
class StickerModel {
  final String id;
  final String packId;
  final String url;
  final String? emoji;
  final int order;
  final bool isAnimated;
  final int? frameCount;

  const StickerModel({
    required this.id,
    required this.packId,
    required this.url,
    this.emoji,
    this.order = 0,
    this.isAnimated = false,
    this.frameCount,
  });

  /// Create from JSON
  factory StickerModel.fromJson(Map<String, dynamic> json) {
    return StickerModel(
      id: json['id'] as String? ?? '',
      packId: json['packId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      emoji: json['emoji'] as String?,
      order: json['order'] as int? ?? 0,
      isAnimated: json['isAnimated'] as bool? ?? false,
      frameCount: json['frameCount'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packId': packId,
      'url': url,
      if (emoji != null) 'emoji': emoji,
      'order': order,
      'isAnimated': isAnimated,
      if (frameCount != null) 'frameCount': frameCount,
    };
  }

  /// Create from Firestore document
  /// Convert to domain entity
  StickerEntity toEntity() => StickerEntity(
        id: id,
        packId: packId,
        url: url,
        emoji: emoji,
        order: order,
        isAnimated: isAnimated,
        frameCount: frameCount,
      );

  /// Create from domain entity
  factory StickerModel.fromEntity(StickerEntity entity) => StickerModel(
        id: entity.id,
        packId: entity.packId,
        url: entity.url,
        emoji: entity.emoji,
        order: entity.order,
        isAnimated: entity.isAnimated,
        frameCount: entity.frameCount,
      );

  StickerModel copyWith({
    String? id,
    String? packId,
    String? url,
    String? emoji,
    int? order,
    bool? isAnimated,
    int? frameCount,
  }) {
    return StickerModel(
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packId == other.packId;

  @override
  int get hashCode => Object.hash(id, packId);

  @override
  String toString() => 'StickerModel(id: $id, packId: $packId, url: $url)';
}
