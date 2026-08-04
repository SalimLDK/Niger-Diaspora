import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/utils/date_parsing.dart';
import '../../domain/repositories/feed_repository.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import 'feed_remote_datasource.dart';

/// Classe de pagination Supabase (remplace le DocumentSnapshot Firestore).
class SupabasePaginatedPosts {
  final List<PostModel> posts;
  final int nextOffset;
  final bool hasMore;

  const SupabasePaginatedPosts({
    required this.posts,
    required this.nextOffset,
    this.hasMore = true,
  });
}

Map<String, dynamic> _mapPost(Map<String, dynamic> row) {
  final mediaList = (row['media'] as List?) ?? const [];
  final firstMedia = mediaList.isNotEmpty ? mediaList.first as Map : null;
  final isVideo = (row['media_type'] ?? 'none') == 'video';
  String? videoThumbnailUrl;
  int? videoDurationSeconds;
  if (isVideo && firstMedia != null) {
    videoThumbnailUrl = firstMedia['thumbnailUrl'] as String?;
    videoDurationSeconds = (firstMedia['duration'] as num?)?.toInt();
  }
  return {
    'id': row['id'],
    'authorId': row['author_id'],
    'authorName': row['author_name'] ?? '',
    'authorPhotoUrl': row['author_photo_url'],
    'content': row['content'] ?? '',
    'mediaUrls': mediaList
        .map((e) => (e as Map)['url']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toList(),
    'mediaType': row['media_type'] ?? 'none',
    'likeCount': row['like_count'] ?? 0,
    'commentCount': row['comment_count'] ?? 0,
    'shareCount': row['share_count'] ?? 0,
    'createdAt': row['created_at'],
    'updatedAt': row['updated_at'] ?? row['created_at'],
    'isEdited': row['is_edited'] ?? false,
    'mentionedUsers': (row['mentioned_users'] as List?)
            ?.map(
              (e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
              ),
            )
            .toList() ??
        [],
    'mentionedGroups': (row['mentioned_groups'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    'hashtags': (row['hashtags'] as List?)?.cast<String>() ?? [],
    'authorCountry': row['country_code'],
    'authorCity': row['author_city'],
    'videoThumbnailUrl': videoThumbnailUrl,
    'videoDurationSeconds': videoDurationSeconds,
    'latitude': (row['latitude'] as num?)?.toDouble(),
    'longitude': (row['longitude'] as num?)?.toDouble(),
    'locationAddress': row['location_address'],
  };
}

/// Construit le tableau JSONB `media` d'un post. Une vidéo embarque sa
/// miniature et sa durée ; les images gardent la forme historique {url, type}.
List<Map<String, dynamic>> _buildMediaJson(PostModel post) {
  if (post.mediaType == 'video' && post.mediaUrls.isNotEmpty) {
    return [
      {
        'url': post.mediaUrls.first,
        'type': 'video',
        'thumbnailUrl': post.videoThumbnailUrl,
        'duration': post.videoDurationSeconds,
      },
    ];
  }
  return post.mediaUrls
      .map((url) => {'url': url, 'type': post.mediaType})
      .toList();
}

Map<String, dynamic> _mapComment(Map<String, dynamic> row) => {
  'id': row['id'],
  'postId': row['post_id'],
  'authorId': row['author_id'],
  'authorName': row['author_name'] ?? '',
  'authorPhotoUrl': row['author_photo_url'],
  'content': row['content'] ?? '',
  'likeCount': row['like_count'] ?? 0,
  'parentCommentId': row['parent_comment_id'],
  'mentionedUsers': (row['mentioned_users'] as List?)
          ?.map(
            (e) => Map<String, String>.from(
              (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
          )
          .toList() ??
      [],
  'createdAt': row['created_at'],
};

class FeedSupabaseDataSource implements FeedRemoteDataSource {
  final SupabaseClient _supabase;

  final List<PostModel> _cache = [];

  FeedSupabaseDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId =>
      firebase_auth.FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════
  // FEED
  // ═══════════════════════════════════════════

  @override
  Future<PaginatedPostModels> getFeedPaginated({
    int limit = 20,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) async {
    var query = _supabase.from('posts').select().eq('visibility', 'public');

    if (hashtagFilter != null) {
      // Recherche dans le tableau JSONB hashtags
      query = query.contains('hashtags', [hashtagFilter]);
    }

    if (mode == FeedMode.following) {
      final followingIds = await getFollowingIds();
      if (followingIds.isEmpty) {
        return const PaginatedPostModels(posts: [], hasMore: false);
      }
      query = query.inFilter('author_id', followingIds.toList());
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final posts = (data as List)
        .map((r) => PostModel.fromJson(_mapPost(r)))
        .toList();

    if (offset == 0) {
      _cache
        ..clear()
        ..addAll(posts);
    } else {
      _cache.addAll(posts);
    }

    return PaginatedPostModels(
      posts: posts,
      lastOffset: offset + posts.length,
      hasMore: posts.length >= limit,
    );
  }

  @override
  Future<PostModel> getPostById(String postId) async {
    final data = await _supabase.from('posts').select().eq('id', postId).single();
    return PostModel.fromJson(_mapPost(data));
  }

  @override
  Future<PostModel> createPost(PostModel post) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final media = _buildMediaJson(post);
    final data = await _supabase
        .from('posts')
        .insert({
          'author_id': post.authorId,
          'author_name': post.authorName,
          'author_photo_url': post.authorPhotoUrl,
          'content': post.content,
          'media': media,
          'media_type': post.mediaType,
          'visibility': 'public',
          'hashtags': post.hashtags,
          'mentioned_users': post.mentionedUsers,
          'mentioned_groups': post.mentionedGroups,
          'country_code': post.authorCountry,
          'author_city': post.authorCity,
          if (post.latitude != null) 'latitude': post.latitude,
          if (post.longitude != null) 'longitude': post.longitude,
          if (post.locationAddress != null)
            'location_address': post.locationAddress,
        })
        .select()
        .single();
    return PostModel.fromJson(_mapPost(data));
  }

  @override
  Future<PostModel> updatePost(PostModel post) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final media = _buildMediaJson(post);
    final data = await _supabase
        .from('posts')
        .update({
          'content': post.content,
          'media': media,
          'media_type': post.mediaType,
          'hashtags': post.hashtags,
          'mentioned_users': post.mentionedUsers,
          'mentioned_groups': post.mentionedGroups,
          'is_edited': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', post.id)
        .select()
        .single();
    return PostModel.fromJson(_mapPost(data));
  }

  @override
  Future<void> deletePost(String postId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    await _supabase.from('posts').delete().eq('id', postId);
  }

  @override
  Future<List<PostModel>> getUserPosts(String userId) async {
    final data = await _supabase
        .from('posts')
        .select()
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((r) => PostModel.fromJson(_mapPost(r))).toList();
  }

  @override
  Future<Set<String>> getFollowingIds() async {
    final uid = _currentUserId;
    if (uid == null) return {};
    final data = await _supabase
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', uid);
    return (data as List).map((r) => r['following_id'] as String).toSet();
  }

  // ═══════════════════════════════════════════
  // LIKES
  // ═══════════════════════════════════════════

  @override
  Future<void> toggleLike(String postId, String userId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final existing = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      await _supabase.rpc(
        'decrement_post_like',
        params: {'p_post_id': postId},
      );
    } else {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      await _supabase.rpc(
        'increment_post_like',
        params: {'p_post_id': postId},
      );
    }
  }

  @override
  Future<bool> isPostLiked(String postId, String userId) async {
    final data = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    return data != null;
  }

  @override
  Future<Set<String>> getLikedPostIds(
    List<String> postIds,
    String userId,
  ) async {
    if (postIds.isEmpty) return {};
    final data = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    return (data as List).map((r) => r['post_id'] as String).toSet();
  }

  // ═══════════════════════════════════════════
  // COMMENTS
  // ═══════════════════════════════════════════

  @override
  Future<List<CommentModel>> getComments(
    String postId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _supabase
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);
    return (data as List)
        .map((r) => CommentModel.fromJson(_mapComment(r)))
        .toList();
  }

  @override
  Future<CommentModel> addComment(String postId, CommentModel comment) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final data = await _supabase
        .from('post_comments')
        .insert({
          'post_id': postId,
          'author_id': comment.authorId,
          'author_name': comment.authorName,
          'author_photo_url': comment.authorPhotoUrl,
          'content': comment.content,
          'parent_comment_id': comment.parentCommentId,
          'mentioned_users': comment.mentionedUsers,
        })
        .select()
        .single();
    await _supabase.rpc(
      'increment_post_comment',
      params: {'p_post_id': postId},
    );
    return CommentModel.fromJson(_mapComment(data));
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    await _supabase.from('post_comments').delete().eq('id', commentId);
    await _supabase.rpc(
      'decrement_post_comment',
      params: {'p_post_id': postId},
    );
  }

  @override
  Future<void> toggleCommentLike(String commentId, String userId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final existing = await _supabase
        .from('post_comment_likes')
        .select('comment_id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      await _supabase.rpc(
        'decrement_post_comment_like',
        params: {'p_comment_id': commentId},
      );
    } else {
      await _supabase.from('post_comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
      await _supabase.rpc(
        'increment_post_comment_like',
        params: {'p_comment_id': commentId},
      );
    }
  }

  @override
  Future<Set<String>> getLikedCommentIds(
    List<String> commentIds,
    String userId,
  ) async {
    if (commentIds.isEmpty) return {};
    final data = await _supabase
        .from('post_comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);
    return (data as List).map((r) => r['comment_id'] as String).toSet();
  }

  // ═══════════════════════════════════════════
  // FOLLOWS
  // ═══════════════════════════════════════════

  @override
  Future<void> toggleFollow(String targetUserId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final uid = _currentUserId;
    if (uid == null) return;

    final existing = await _supabase
        .from('user_follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', targetUserId);
    } else {
      await _supabase.from('user_follows').insert({
        'follower_id': uid,
        'following_id': targetUserId,
      });
    }
  }

  @override
  Future<bool> isFollowing(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    final data = await _supabase
        .from('user_follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return data != null;
  }

  @override
  Future<int> getFollowersCount(String userId) async {
    final response = await _supabase
        .from('user_follows')
        .select()
        .eq('following_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<int> getFollowingCount(String userId) async {
    final response = await _supabase
        .from('user_follows')
        .select()
        .eq('follower_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<List<String>> getFollowers(String userId) async {
    final data = await _supabase
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((r) => r['follower_id'] as String).toList();
  }

  @override
  Future<List<String>> getFollowing(String userId) async {
    final data = await _supabase
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((r) => r['following_id'] as String).toList();
  }

  // ═══════════════════════════════════════════
  // BOOKMARKS
  // ═══════════════════════════════════════════

  @override
  Future<void> toggleBookmark(String postId, String userId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final existing = await _supabase
        .from('post_bookmarks')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _supabase.from('post_bookmarks').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  @override
  Future<Set<String>> getBookmarkedPostIds(String userId) async {
    final data = await _supabase
        .from('post_bookmarks')
        .select('post_id')
        .eq('user_id', userId);
    return (data as List).map((r) => r['post_id'] as String).toSet();
  }

  @override
  Future<List<PostModel>> getBookmarkedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // !inner sur posts ET sur son auteur : un signet dont le post a été
    // supprimé, ou dont l'auteur n'existe plus dans users (compte effacé
    // hors cascade), est exclu de la liste au lieu d'afficher un fantôme.
    final data = await _supabase
        .from('post_bookmarks')
        .select('*, posts!inner(*, author:users!posts_author_id_fkey!inner(id))')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .where((r) => r['posts'] != null)
        .map((r) {
      final post = r['posts'] as Map<String, dynamic>;
      return PostModel.fromJson(_mapPost(post));
    }).toList();
  }

  // ═══════════════════════════════════════════
  // REPOSTS (repartages)
  // ═══════════════════════════════════════════

  @override
  Future<bool> toggleRepost(String postId, String userId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final existing = await _supabase
        .from('post_reposts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_reposts')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      await _supabase.rpc(
        'decrement_post_share',
        params: {'p_post_id': postId},
      );
      return false;
    } else {
      await _supabase.from('post_reposts').insert({
        'post_id': postId,
        'user_id': userId,
      });
      await _supabase.rpc(
        'increment_post_share',
        params: {'p_post_id': postId},
      );
      return true;
    }
  }

  @override
  Future<bool> repostWithComment(
    String postId,
    String userId,
    String comment,
  ) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final existing = await _supabase
        .from('post_reposts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // Repartage déjà présent : on met seulement à jour la citation.
      await _supabase
          .from('post_reposts')
          .update({'comment': comment})
          .eq('post_id', postId)
          .eq('user_id', userId);
      return false;
    } else {
      await _supabase.from('post_reposts').insert({
        'post_id': postId,
        'user_id': userId,
        'comment': comment,
      });
      await _supabase.rpc(
        'increment_post_share',
        params: {'p_post_id': postId},
      );
      return true;
    }
  }

  @override
  Future<void> incrementExternalShare(String postId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    await _supabase.rpc(
      'increment_post_external_share',
      params: {'p_post_id': postId},
    );
  }

  @override
  Future<Set<String>> getRepostedPostIds(String userId) async {
    final data = await _supabase
        .from('post_reposts')
        .select('post_id')
        .eq('user_id', userId);
    return (data as List).map((r) => r['post_id'] as String).toSet();
  }

  @override
  Future<List<PostModel>> getRepostedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // Même garde que getBookmarkedPosts : posts supprimés ou auteurs
    // disparus exclus de « Mes repartages ».
    final data = await _supabase
        .from('post_reposts')
        .select('*, posts!inner(*, author:users!posts_author_id_fkey!inner(id))')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .where((r) => r['posts'] != null)
        .map((r) {
      final post = r['posts'] as Map<String, dynamic>;
      return PostModel.fromJson(_mapPost(post));
    }).toList();
  }

  @override
  Future<List<String>> getReposterIds(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _supabase
        .from('post_reposts')
        .select('user_id')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((r) => r['user_id'] as String).toList();
  }

  @override
  Future<List<RepostFeedItemModel>> getRepostFeedItems({
    List<String>? reposterIds,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _supabase.rpc('get_feed_reposts', params: {
      'p_user_ids': reposterIds,
      'p_limit': limit,
      'p_offset': offset,
    });
    return (data as List).map((row) {
      final r = row as Map<String, dynamic>;
      final postJson = r['post'] as Map<String, dynamic>;
      return RepostFeedItemModel(
        post: PostModel.fromJson(_mapPost(postJson)),
        reposterId: r['reposter_id'] as String? ?? '',
        reposterName: r['reposter_name'] as String? ?? '',
        comment: r['comment'] as String?,
        repostedAt: tryParseLocalDate(r['repost_created_at']?.toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════
  // REALTIME
  // ═══════════════════════════════════════════

  @override
  Stream<PostModel> watchNewPosts() {
    final controller = StreamController<PostModel>();
    final channel = _supabase.channel('feed_posts_insert');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'posts',
      callback: (payload) {
        final row = payload.newRecord;
        if (row['visibility'] != 'public') return;
        try {
          controller.add(PostModel.fromJson(_mapPost(row)));
        } catch (_) {}
      },
    ).subscribe();
    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<PostModel> watchPostUpdates({String? postId}) {
    final controller = StreamController<PostModel>();
    final channel = _supabase.channel(
      postId == null ? 'feed_posts_update' : 'post_update_$postId',
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'posts',
      filter: postId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: postId,
            ),
      callback: (payload) {
        try {
          controller.add(PostModel.fromJson(_mapPost(payload.newRecord)));
        } catch (_) {}
      },
    ).subscribe();
    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<CommentModel> watchNewComments(String postId) {
    final controller = StreamController<CommentModel>();
    final channel = _supabase.channel('post_comments_$postId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'post_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: postId,
      ),
      callback: (payload) {
        try {
          controller.add(CommentModel.fromJson(_mapComment(payload.newRecord)));
        } catch (_) {}
      },
    ).subscribe();
    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }

  @override
  List<PostModel> getCachedPosts() => List.unmodifiable(_cache);
}
