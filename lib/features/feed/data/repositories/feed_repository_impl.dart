import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/garde_appel.dart';
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
    return garderAppel(() async {
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
    });
  }

  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async {
    return garderAppel(() async {
      final model = await _dataSource.getPostById(postId);
      return Right(model.toEntity());
    }, sinon: (e) {
      // Filet : toute autre erreur (réseau, schéma) doit rester un Left plutôt
      // que de s'échapper vers un appelant qui ne l'attend pas.
      return ServerFailure(e.toString());
    });
  }

  @override
  Future<Either<Failure, PostEntity>> createPost(PostEntity post) async {
    return garderAppel(() async {
      final model = await _dataSource.createPost(PostModel.fromEntity(post));
      return Right(model.toEntity());
    }, sinon: (e) {
      // Filet de securite : toute autre erreur (RLS, schema, reseau Supabase)
      // remonte en Left au lieu de bloquer l'UI sur un spinner figé.
      return ServerFailure(e.toString());
    });
  }

  @override
  Future<Either<Failure, PostEntity>> updatePost(PostEntity post) async {
    return garderAppel(() async {
      final model = await _dataSource.updatePost(PostModel.fromEntity(post));
      return Right(model.toEntity());
    }, sinon: (e) {
      // Filet de securite : toute autre erreur (RLS, schema, reseau Supabase).
      return ServerFailure(e.toString());
    });
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    return garderAppel(() async {
      await _dataSource.deletePost(postId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId) async {
    return garderAppel(() async {
      final models = await _dataSource.getUserPosts(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, void>> toggleLike(
    String postId,
    String userId,
  ) async {
    return garderAppel(() async {
      await _dataSource.toggleLike(postId, userId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, bool>> isPostLiked(
    String postId,
    String userId,
  ) async {
    return garderAppel(() async {
      final result = await _dataSource.isPostLiked(postId, userId);
      return Right(result);
    });
  }

  @override
  Future<Either<Failure, Set<String>>> getLikedPostIds(
    List<String> postIds,
    String userId,
  ) async {
    return garderAppel(() async {
      final ids = await _dataSource.getLikedPostIds(postIds, userId);
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return garderAppel(() async {
      final models = await _dataSource.getComments(
        postId,
        limit: limit,
        offset: offset,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, CommentEntity>> addComment(
    String postId,
    CommentEntity comment,
  ) async {
    return garderAppel(() async {
      final model = await _dataSource.addComment(
        postId,
        CommentModel.fromEntity(comment),
      );
      return Right(model.toEntity());
    });
  }

  @override
  Future<Either<Failure, void>> deleteComment(
    String postId,
    String commentId,
  ) async {
    return garderAppel(() async {
      await _dataSource.deleteComment(postId, commentId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> toggleCommentLike(
    String commentId,
    String userId,
  ) async {
    return garderAppel(() async {
      await _dataSource.toggleCommentLike(commentId, userId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, Set<String>>> getLikedCommentIds(
    List<String> commentIds,
    String userId,
  ) async {
    return garderAppel(() async {
      final ids = await _dataSource.getLikedCommentIds(commentIds, userId);
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, void>> toggleFollow(String targetUserId) async {
    return garderAppel(() async {
      await _dataSource.toggleFollow(targetUserId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, bool>> isFollowing(String targetUserId) async {
    return garderAppel(() async {
      final result = await _dataSource.isFollowing(targetUserId);
      return Right(result);
    });
  }

  @override
  Future<Either<Failure, int>> getFollowersCount(String userId) async {
    return garderAppel(() async {
      final count = await _dataSource.getFollowersCount(userId);
      return Right(count);
    });
  }

  @override
  Future<Either<Failure, int>> getFollowingCount(String userId) async {
    return garderAppel(() async {
      final count = await _dataSource.getFollowingCount(userId);
      return Right(count);
    });
  }

  @override
  Future<Either<Failure, List<String>>> getFollowers(String userId) async {
    return garderAppel(() async {
      final ids = await _dataSource.getFollowers(userId);
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, List<String>>> getFollowing(String userId) async {
    return garderAppel(() async {
      final ids = await _dataSource.getFollowing(userId);
      return Right(ids);
    });
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
    return garderAppel(() async {
      await _dataSource.toggleBookmark(postId, userId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedPostIds(
    String userId,
  ) async {
    return garderAppel(() async {
      final ids = await _dataSource.getBookmarkedPostIds(userId);
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getBookmarkedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return garderAppel(() async {
      final models =
          await _dataSource.getBookmarkedPosts(userId, limit: limit, offset: offset);
      return Right(models.map((m) => m.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, bool>> toggleRepost(
    String postId,
    String userId,
  ) async {
    return garderAppel(() async {
      final reposted = await _dataSource.toggleRepost(postId, userId);
      return Right(reposted);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, bool>> repostWithComment(
    String postId,
    String userId,
    String comment,
  ) async {
    return garderAppel(() async {
      final wasNew =
          await _dataSource.repostWithComment(postId, userId, comment);
      return Right(wasNew);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> trackExternalShare(String postId) async {
    return garderAppel(() async {
      await _dataSource.incrementExternalShare(postId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, Set<String>>> getRepostedPostIds(
    String userId,
  ) async {
    return garderAppel(() async {
      final ids = await _dataSource.getRepostedPostIds(userId);
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getRepostedPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return garderAppel(() async {
      final models = await _dataSource.getRepostedPosts(
        userId,
        limit: limit,
        offset: offset,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, List<String>>> getReposterIds(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return garderAppel(() async {
      final ids = await _dataSource.getReposterIds(
        postId,
        limit: limit,
        offset: offset,
      );
      return Right(ids);
    });
  }

  @override
  Future<Either<Failure, List<RepostFeedEntry>>> getRepostFeedItems({
    List<String>? reposterIds,
    int limit = 20,
    int offset = 0,
  }) async {
    return garderAppel(() async {
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
    }, sinon: (e) => ServerFailure(e.toString()));
  }
}
