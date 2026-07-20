import 'package:equatable/equatable.dart';

import 'post_entity.dart';

class CommentEntity extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;
  final List<MentionedUser> mentionedUsers;
  final List<MentionedGroup> mentionedGroups;
  final List<String> hashtags;

  /// Id du commentaire parent si c'est une réponse, sinon null.
  final String? parentCommentId;
  final int likeCount;

  /// Réponses rattachées (profondeur 1). Peuplé par le notifier, non persisté
  /// tel quel par ligne.
  final List<CommentEntity> replies;
  final int replyCount;

  const CommentEntity({
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
    this.replies = const [],
    this.replyCount = 0,
  });

  CommentEntity copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? content,
    DateTime? createdAt,
    List<MentionedUser>? mentionedUsers,
    List<MentionedGroup>? mentionedGroups,
    List<String>? hashtags,
    String? parentCommentId,
    int? likeCount,
    List<CommentEntity>? replies,
    int? replyCount,
  }) {
    return CommentEntity(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      mentionedGroups: mentionedGroups ?? this.mentionedGroups,
      hashtags: hashtags ?? this.hashtags,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likeCount: likeCount ?? this.likeCount,
      replies: replies ?? this.replies,
      replyCount: replyCount ?? this.replyCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    authorId,
    authorName,
    authorPhotoUrl,
    content,
    createdAt,
    mentionedUsers,
    mentionedGroups,
    hashtags,
    parentCommentId,
    likeCount,
    replies,
    replyCount,
  ];
}
