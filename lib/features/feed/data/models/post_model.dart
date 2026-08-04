
import '../../../../core/utils/date_parsing.dart';
import '../../domain/entities/post_entity.dart';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final List<String> mediaUrls;
  final String mediaType;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final List<Map<String, String>> mentionedUsers;
  final List<Map<String, dynamic>> mentionedGroups;
  final List<String> hashtags;
  final String? authorCountry;
  final String? authorCity;
  final String? videoThumbnailUrl;
  final int? videoDurationSeconds;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    this.mediaUrls = const [],
    this.mediaType = 'none',
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
    this.authorCity,
    this.videoThumbnailUrl,
    this.videoDurationSeconds,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // `toLocal()` : un `created_at` Supabase arrive en ISO terminé par `Z`,
    // donc `DateTime.parse` renvoie de l'UTC que `DateFormat` imprimerait tel
    // quel (02:01 affiché « 06:01 » à Toronto). Voir `core/utils/date_parsing`.
    DateTime parseDate(dynamic value) => parseLocalDate(value);

    return PostModel(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['mediaUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mediaType: json['mediaType'] as String? ?? 'none',
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      isEdited: json['isEdited'] as bool? ?? false,
      mentionedUsers: (json['mentionedUsers'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      mentionedGroups: (json['mentionedGroups'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      hashtags: (json['hashtags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      authorCountry: json['authorCountry'] as String?,
      authorCity: json['authorCity'] as String?,
      videoThumbnailUrl: json['videoThumbnailUrl'] as String?,
      videoDurationSeconds: (json['videoDurationSeconds'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['locationAddress'] as String?,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'content': content,
    'mediaUrls': mediaUrls,
    'mediaType': mediaType,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'shareCount': shareCount,
    // UTC explicite : les dates sont locales depuis `parseDate`, et
    // `toIso8601String()` seul produirait une chaîne sans fuseau, ambiguë pour
    // qui la relit (cache comme serveur).
    'createdAt': toIsoUtc(createdAt),
    'updatedAt': toIsoUtc(updatedAt),
    'isEdited': isEdited,
    'mentionedUsers': mentionedUsers,
    'mentionedGroups': mentionedGroups,
    'hashtags': hashtags,
    if (authorCountry != null) 'authorCountry': authorCountry,
    if (authorCity != null) 'authorCity': authorCity,
    if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
    if (videoDurationSeconds != null)
      'videoDurationSeconds': videoDurationSeconds,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (locationAddress != null) 'locationAddress': locationAddress,
  };

  PostEntity toEntity() => PostEntity(
    id: id,
    authorId: authorId,
    authorName: authorName,
    authorPhotoUrl: authorPhotoUrl,
    content: content,
    mediaUrls: mediaUrls,
    mediaType: _parseMediaType(mediaType),
    likeCount: likeCount,
    commentCount: commentCount,
    shareCount: shareCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isEdited: isEdited,
    mentionedUsers: mentionedUsers
        .map((m) => MentionedUser(id: m['id'] ?? '', name: m['name'] ?? ''))
        .toList(),
    mentionedGroups: mentionedGroups
        .map((g) => MentionedGroup(
              id: g['id'] as String? ?? '',
              name: g['name'] as String? ?? '',
              memberIds: (g['memberIds'] as List<dynamic>?)
                      ?.map((e) => e as String)
                      .toList() ??
                  [],
            ),)
        .toList(),
    hashtags: hashtags,
    authorCountry: authorCountry,
    authorCity: authorCity,
    videoThumbnailUrl: videoThumbnailUrl,
    videoDurationSeconds: videoDurationSeconds,
    latitude: latitude,
    longitude: longitude,
    locationAddress: locationAddress,
  );

  static PostModel fromEntity(PostEntity entity) => PostModel(
    id: entity.id,
    authorId: entity.authorId,
    authorName: entity.authorName,
    authorPhotoUrl: entity.authorPhotoUrl,
    content: entity.content,
    mediaUrls: entity.mediaUrls,
    mediaType: _mediaTypeToString(entity.mediaType),
    likeCount: entity.likeCount,
    commentCount: entity.commentCount,
    shareCount: entity.shareCount,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
    isEdited: entity.isEdited,
    mentionedUsers:
        entity.mentionedUsers.map((m) => {'id': m.id, 'name': m.name}).toList(),
    mentionedGroups: entity.mentionedGroups
        .map((g) => {
              'id': g.id,
              'name': g.name,
              'memberIds': g.memberIds,
            },)
        .toList(),
    hashtags: entity.hashtags,
    authorCountry: entity.authorCountry,
    authorCity: entity.authorCity,
    videoThumbnailUrl: entity.videoThumbnailUrl,
    videoDurationSeconds: entity.videoDurationSeconds,
    latitude: entity.latitude,
    longitude: entity.longitude,
    locationAddress: entity.locationAddress,
  );

  static PostMediaType _parseMediaType(String value) {
    switch (value) {
      case 'images':
        return PostMediaType.images;
      case 'video':
        return PostMediaType.video;
      default:
        return PostMediaType.none;
    }
  }

  static String _mediaTypeToString(PostMediaType type) {
    switch (type) {
      case PostMediaType.images:
        return 'images';
      case PostMediaType.video:
        return 'video';
      case PostMediaType.none:
        return 'none';
    }
  }
}
