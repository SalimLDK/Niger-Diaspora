import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/repost_ref.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_remote_datasource.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDataSource _dataSource;

  FeedRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit = 30,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) async {
    try {
      final result = await _dataSource.getFeedPaginated(
        limit: limit,
        offset: offset,
        hashtagFilter: hashtagFilter,
        mode: mode,
      );
      return Right(
        PaginatedPosts(
          posts: result.posts.map((m) => m.toEntity()).toList(),
          lastOffset: result.lastOffset,
          hasMore: result.hasMore,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async {
    try {
      final model = await _dataSource.getPostById(postId);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      // Publication supprimée ou id inexistant : l'appelant doit pouvoir le
      // distinguer d'une panne, pour afficher « introuvable » et non un
      // chargement sans fin.
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Filet : toute autre erreur (réseau, schéma) doit rester un Left plutôt
      // que de s'échapper vers un appelant qui ne l'attend pas.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> createPost(PostEntity post) async {
    try {
      final model = await _dataSource.createPost(PostModel.fromEntity(post));
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Filet de securite : toute autre erreur (RLS, schema, reseau Supabase)
      // remonte en Left au lieu de bloquer l'UI sur un spinner figé.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> updatePost(PostEntity post) async {
    try {
      final model = await _dataSource.updatePost(PostModel.fromEntity(post));
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Filet de securite : toute autre erreur (RLS, schema, reseau Supabase).
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      await _dataSource.deletePost(postId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId) async {
    try {
      final models = await _dataSource.getUserPosts(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleLike(
    String postId,
    String userId,
  ) async {
    try {
      await _dataSource.toggleLike(postId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isPostLiked(
    String postId,
    String userId,
  ) async {
    try {
      final result = await _dataSource.isPostLiked(postId, userId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getLikedPostIds(
    List<String> postIds,
    String userId,
  ) async {
    try {
      final ids = await _dataSource.getLikedPostIds(postIds, userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final models = await _dataSource.getComments(
        postId,
        limit: limit,
        offset: offset,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, CommentEntity>> addComment(
    String postId,
    CommentEntity comment,
  ) async {
    try {
      final model = await _dataSource.addComment(
        postId,
        CommentModel.fromEntity(comment),
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(
    String postId,
    String commentId,
  ) async {
    try {
      await _dataSource.deleteComment(postId, commentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleCommentLike(
    String commentId,
    String userId,
  ) async {
    try {
      await _dataSource.toggleCommentLike(commentId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getLikedCommentIds(
    List<String> commentIds,
    String userId,
  ) async {
    try {
      final ids = await _dataSource.getLikedCommentIds(commentIds, userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFollow(String targetUserId) async {
    try {
      await _dataSource.toggleFollow(targetUserId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isFollowing(String targetUserId) async {
    try {
      final result = await _dataSource.isFollowing(targetUserId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getFollowersCount(String userId) async {
    try {
      final count = await _dataSource.getFollowersCount(userId);
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getFollowingCount(String userId) async {
    try {
      final count = await _dataSource.getFollowingCount(userId);
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getFollowers(String userId) async {
    try {
      final ids = await _dataSource.getFollowers(userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getFollowing(String userId) async {
    try {
      final ids = await _dataSource.getFollowing(userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<PostEntity> watchNewPosts() =>
      _dataSource.watchNewPosts().map((m) => m.toEntity());

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) =>
      _dataSource.watchPostUpdates(postId: postId).map((m) => m.toEntity());

  @override
  Stream<CommentEntity> watchNewComments(String postId) =>
      _dataSource.watchNewComments(postId).map((m) => m.toEntity());

  @override
  Either<Failure, List<PostEntity>> getCachedPosts() {
    try {
      final models = _dataSource.getCachedPosts();
      return Right(models.map((m) => m.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleBookmark(
    String postId,
    String userId,
  ) async {
    try {
      await _dataSource.toggleBookmark(postId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedPostIds(
    String userId,
  ) async {
    try {
      final ids = await _dataSource.getBookmarkedPostIds(userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getBookmarkedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final models =
          await _dataSource.getBookmarkedPosts(userId, limit: limit, offset: offset);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleRepost(
    String postId,
    String userId,
  ) async {
    try {
      final reposted = await _dataSource.toggleRepost(postId, userId);
      return Right(reposted);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> repostWithComment(
    String postId,
    String userId,
    String comment,
  ) async {
    try {
      final wasNew =
          await _dataSource.repostWithComment(postId, userId, comment);
      return Right(wasNew);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> trackExternalShare(String postId) async {
    try {
      await _dataSource.incrementExternalShare(postId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getRepostedPostIds(
    String userId,
  ) async {
    try {
      final ids = await _dataSource.getRepostedPostIds(userId);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getRepostedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final models = await _dataSource.getRepostedPosts(
        userId,
        limit: limit,
        offset: offset,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getReposterIds(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ids = await _dataSource.getReposterIds(
        postId,
        limit: limit,
        offset: offset,
      );
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<RepostFeedEntry>>> getRepostFeedItems({
    List<String>? reposterIds,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final items = await _dataSource.getRepostFeedItems(
        reposterIds: reposterIds,
        limit: limit,
        offset: offset,
      );
      return Right(
        items
            .map((i) => RepostFeedEntry(
                  post: i.post.toEntity(),
                  ref: RepostRef(
                    reposterId: i.reposterId,
                    reposterName: i.reposterName,
                    comment: i.comment,
                    repostedAt: i.repostedAt,
                  ),
                ))
            .toList(),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
