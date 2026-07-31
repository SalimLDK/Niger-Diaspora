import 'package:equatable/equatable.dart';

enum StoryMediaType { image, video }

/// Une story individuelle (§4, rail « À la une »). MVP : un seul média,
/// expiration 24h, pas de réactions.
class StoryEntity extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final int? videoDurationSeconds;
  final DateTime createdAt;
  final int viewCount;
  final bool isViewedByMe;

  const StoryEntity({
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

  bool get isExpired =>
      DateTime.now().difference(createdAt) > const Duration(hours: 24);

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorPhotoUrl,
        mediaUrl,
        mediaType,
        videoDurationSeconds,
        createdAt,
        viewCount,
        isViewedByMe,
      ];
}

/// Stories actives d'un même auteur, groupées pour le rail et le viewer.
class AuthorStories extends Equatable {
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final List<StoryEntity> stories;

  const AuthorStories({
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.stories,
  });

  bool get hasUnviewed => stories.any((s) => !s.isViewedByMe);

  @override
  List<Object?> get props => [authorId, authorName, authorPhotoUrl, stories];
}
