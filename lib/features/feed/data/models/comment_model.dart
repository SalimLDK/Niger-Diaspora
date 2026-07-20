
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;
  final List<Map<String, String>> mentionedUsers;
  final List<Map<String, dynamic>> mentionedGroups;
  final List<String> hashtags;
  final String? parentCommentId;
  final int likeCount;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
    this.mentionedUsers = const [],
    this.mentionedGroups = const [],
    this.hashtags = const [],
    this.parentCommentId,
    this.likeCount = 0,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return CommentModel(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
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
      parentCommentId: json['parentCommentId'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'mentionedUsers': mentionedUsers,
    'mentionedGroups': mentionedGroups,
    'hashtags': hashtags,
    'parentCommentId': parentCommentId,
    'likeCount': likeCount,
  };

  CommentEntity toEntity() => CommentEntity(
    id: id,
    postId: postId,
    authorId: authorId,
    authorName: authorName,
    authorPhotoUrl: authorPhotoUrl,
    content: content,
    createdAt: createdAt,
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
    parentCommentId: parentCommentId,
    likeCount: likeCount,
  );

  static CommentModel fromEntity(CommentEntity entity) => CommentModel(
    id: entity.id,
    postId: entity.postId,
    authorId: entity.authorId,
    authorName: entity.authorName,
    authorPhotoUrl: entity.authorPhotoUrl,
    content: entity.content,
    createdAt: entity.createdAt,
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
    parentCommentId: entity.parentCommentId,
    likeCount: entity.likeCount,
  );
}
