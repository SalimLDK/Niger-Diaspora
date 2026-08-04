import '../../domain/entities/story_entity.dart';

/// Écrit à la main, comme `PostModel` (pas de freezed/build_runner dans le
/// fil — cohérence de style).
class StoryModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String mediaUrl;
  final String mediaType;
  final int? videoDurationSeconds;
  final DateTime createdAt;
  final int viewCount;
  final bool isViewedByMe;

  const StoryModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.videoDurationSeconds,
    required this.createdAt,
    this.viewCount = 0,
    this.isViewedByMe = false,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value).toLocal();
      return DateTime.now();
    }

    return StoryModel(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      mediaUrl: json['mediaUrl'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'image',
      videoDurationSeconds: (json['videoDurationSeconds'] as num?)?.toInt(),
      createdAt: parseDate(json['createdAt']),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      isViewedByMe: json['isViewedByMe'] as bool? ?? false,
    );
  }

  StoryEntity toEntity() => StoryEntity(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        mediaUrl: mediaUrl,
        mediaType: mediaType == 'video'
            ? StoryMediaType.video
            : StoryMediaType.image,
        videoDurationSeconds: videoDurationSeconds,
        createdAt: createdAt,
        viewCount: viewCount,
        isViewedByMe: isViewedByMe,
      );
}
