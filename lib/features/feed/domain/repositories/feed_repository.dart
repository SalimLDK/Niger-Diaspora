import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/comment_entity.dart';
import '../entities/post_entity.dart';
import '../entities/repost_ref.dart';

enum FeedMode { forYou, following, recent }

class PaginatedPosts {
  final List<PostEntity> posts;
  final int lastOffset;
  final bool hasMore;

  const PaginatedPosts({
    required this.posts,
    this.lastOffset = 0,
    this.hasMore = true,
  });
}

/// Un repartage à afficher dans le fil : le post original + son attribution.
class RepostFeedEntry {
  final PostEntity post;
  final RepostRef ref;

  const RepostFeedEntry({required this.post, required this.ref});
}

abstract class FeedRepository {
  // Posts
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit,
    int offset,
    String? hashtagFilter,
    FeedMode mode,
  });
  Future<Either<Failure, PostEntity>> getPostById(String postId);
  Future<Either<Failure, PostEntity>> createPost(PostEntity post);
  Future<Either<Failure, PostEntity>> updatePost(PostEntity post);
  Future<Either<Failure, void>> deletePost(String postId);
  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId);

  // Likes
  Future<Either<Failure, void>> toggleLike(String postId, String userId);
  Future<Either<Failure, bool>> isPostLiked(String postId, String userId);
  Future<Either<Failure, Set<String>>> getLikedPostIds(
    List<String> postIds,
    String userId,
  );

  // Comments
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int limit,
    int offset,
  });
  Future<Either<Failure, CommentEntity>> addComment(
    String postId,
    CommentEntity comment,
  );
  Future<Either<Failure, void>> deleteComment(
    String postId,
    String commentId,
  );

  // Comment likes
  Future<Either<Failure, void>> toggleCommentLike(
    String commentId,
    String userId,
  );
  Future<Either<Failure, Set<String>>> getLikedCommentIds(
    List<String> commentIds,
    String userId,
  );

  // Follow
  Future<Either<Failure, void>> toggleFollow(String targetUserId);
  Future<Either<Failure, bool>> isFollowing(String targetUserId);
  Future<Either<Failure, int>> getFollowersCount(String userId);
  Future<Either<Failure, int>> getFollowingCount(String userId);
  Future<Either<Failure, List<String>>> getFollowers(String userId);
  Future<Either<Failure, List<String>>> getFollowing(String userId);

  // Bookmarks
  Future<Either<Failure, void>> toggleBookmark(String postId, String userId);
  Future<Either<Failure, Set<String>>> getBookmarkedPostIds(String userId);
  Future<Either<Failure, List<PostEntity>>> getBookmarkedPosts(
    String userId, {
    int limit,
    int offset,
  });

  // Reposts (repartages)
  Future<Either<Failure, bool>> toggleRepost(String postId, String userId);
  Future<Either<Failure, bool>> repostWithComment(
    String postId,
    String userId,
    String comment,
  );
  Future<Either<Failure, Set<String>>> getRepostedPostIds(String userId);
  Future<Either<Failure, List<PostEntity>>> getRepostedPosts(
    String userId, {
    int limit,
    int offset,
  });
  Future<Either<Failure, List<String>>> getReposterIds(
    String postId, {
    int limit,
    int offset,
  });
  Future<Either<Failure, List<RepostFeedEntry>>> getRepostFeedItems({
    List<String>? reposterIds,
    int limit,
    int offset,
  });

  // Partages externes (WhatsApp/Facebook/X/système)
  Future<Either<Failure, void>> trackExternalShare(String postId);

  // Realtime
  Stream<PostEntity> watchNewPosts();
  Stream<PostEntity> watchPostUpdates({String? postId});
  Stream<CommentEntity> watchNewComments(String postId);

  // Cache
  Either<Failure, List<PostEntity>> getCachedPosts();
}
