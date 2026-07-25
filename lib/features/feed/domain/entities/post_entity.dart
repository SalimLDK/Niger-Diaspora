import 'package:equatable/equatable.dart';

enum PostMediaType { none, images, video }

class MentionedUser extends Equatable {
  final String id;
  final String name;

  const MentionedUser({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class MentionedGroup extends Equatable {
  final String id;
  final String name;
  final List<String> memberIds;

  const MentionedGroup({
    required this.id,
    required this.name,
    this.memberIds = const [],
  });

  @override
  List<Object?> get props => [id, name, memberIds];
}

class PostEntity extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final List<String> mediaUrls;
  final PostMediaType mediaType;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final List<MentionedUser> mentionedUsers;
  final List<MentionedGroup> mentionedGroups;
  final List<String> hashtags;
  final String? authorCountry;

  /// Miniature de la vid├®o (uniquement si [mediaType] == video).
  final String? videoThumbnailUrl;

  /// Dur├®e de la vid├®o en secondes (uniquement si [mediaType] == video).
  final int? videoDurationSeconds;

  const PostEntity({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    this.mediaUrls = const [],
    this.mediaType = PostMediaType.none,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.mentionedUsers = const [],
    this.mentionedGroups = const [],
    this.hashtags = const [],
    this.authorCountry,
    this.videoThumbnailUrl,
    this.videoDurationSeconds,
  });

  PostEntity copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? content,
    List<String>? mediaUrls,
    PostMediaType? mediaType,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    List<MentionedUser>? mentionedUsers,
    List<MentionedGroup>? mentionedGroups,
    List<String>? hashtags,
    String? authorCountry,
    String? videoThumbnailUrl,
    int? videoDurationSeconds,
  }) {
    return PostEntity(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      mentionedGroups: mentionedGroups ?? this.mentionedGroups,
      hashtags: hashtags ?? this.hashtags,
      authorCountry: authorCountry ?? this.authorCountry,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
    );
  }

  @override
  List<Object?> get props => [
    id,
    authorId,
    authorName,
    authorPhotoUrl,
    content,
    mediaUrls,
    mediaType,
    likeCount,
    commentCount,
    shareCount,
    createdAt,
    updatedAt,
    isEdited,
    mentionedUsers,
    mentionedGroups,
    hashtags,
    authorCountry,
    videoThumbnailUrl,
    videoDurationSeconds,
  ];
}
