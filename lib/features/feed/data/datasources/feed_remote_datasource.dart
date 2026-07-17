
import '../../domain/repositories/feed_repository.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

class PaginatedPostModels {
  final List<PostModel> posts;
  final int lastOffset;
  final bool hasMore;

  const PaginatedPostModels({
    required this.posts,
    this.lastOffset = 0,
    this.hasMore = true,
  });
}

/// Un repartage prêt à être affiché dans le fil : le post original + qui l'a
/// reposté (et sa citation éventuelle).
class RepostFeedItemModel {
  final PostModel post;
  final String reposterId;
  final String reposterName;
  final String? comment;
  final DateTime repostedAt;

  const RepostFeedItemModel({
    required this.post,
    required this.reposterId,
    required this.reposterName,
    this.comment,
    required this.repostedAt,
  });
}

abstract class FeedRemoteDataSource {
  Future<PaginatedPostModels> getFeedPaginated({
    int limit,
    int offset,
    String? hashtagFilter,
    FeedMode mode,
  });
  Future<PostModel> getPostById(String postId);
  Future<PostModel> createPost(PostModel post);
  Future<PostModel> updatePost(PostModel post);
  Future<void> deletePost(String postId);
  Future<List<PostModel>> getUserPosts(String userId);
  Future<Set<String>> getFollowingIds();

  Future<void> toggleLike(String postId, String userId);
  Future<bool> isPostLiked(String postId, String userId);
  Future<Set<String>> getLikedPostIds(List<String> postIds, String userId);

  Future<List<CommentModel>> getComments(
    String postId, {
    int limit,
    int offset,
  });
  Future<CommentModel> addComment(String postId, CommentModel comment);
  Future<void> deleteComment(String postId, String commentId);
  Future<void> toggleCommentLike(String commentId, String userId);
  Future<Set<String>> getLikedCommentIds(
    List<String> commentIds,
    String userId,
  );

  Future<void> toggleFollow(String targetUserId);
  Future<bool> isFollowing(String targetUserId);
  Future<int> getFollowersCount(String userId);
  Future<int> getFollowingCount(String userId);
  Future<List<String>> getFollowers(String userId);
  Future<List<String>> getFollowing(String userId);

  // Bookmarks
  Future<void> toggleBookmark(String postId, String userId);
  Future<Set<String>> getBookmarkedPostIds(String userId);
  Future<List<PostModel>> getBookmarkedPosts(String userId, {int limit = 20, int offset = 0});

  // Reposts (repartages)
  Future<bool> toggleRepost(String postId, String userId);
  Future<bool> repostWithComment(String postId, String userId, String comment);
  Future<Set<String>> getRepostedPostIds(String userId);
  Future<List<PostModel>> getRepostedPosts(String userId, {int limit = 20, int offset = 0});
  Future<List<String>> getReposterIds(String postId, {int limit = 50, int offset = 0});
  Future<List<RepostFeedItemModel>> getRepostFeedItems({
    List<String>? reposterIds,
    int limit = 20,
    int offset = 0,
  });

  // Partages externes (WhatsApp/Facebook/X/système)
  Future<void> incrementExternalShare(String postId);

  // Realtime
  Stream<PostModel> watchNewPosts();
  Stream<PostModel> watchPostUpdates({String? postId});
  Stream<CommentModel> watchNewComments(String postId);

  List<PostModel> getCachedPosts();
}
