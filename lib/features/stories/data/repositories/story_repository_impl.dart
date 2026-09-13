import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_supabase_datasource.dart';

class StoryRepositoryImpl implements StoryRepository {
  final StoryRemoteDataSource _dataSource;

  StoryRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<AuthorStories>>> getActiveStories(
    String currentUserId,
  ) async {
    try {
      final models = await _dataSource.getActiveStories(currentUserId);
      // Borne des 24 h réappliquée à la réception : l'horloge du serveur et
      // celle du téléphone diffèrent, et une story ne doit pas survivre à
      // l'écran à son expiration.
      final entities = models
          .map((m) => m.toEntity())
          .where((s) => !s.isExpired)
          .toList();

      // Groupe par auteur, plus récent en tête de chaque groupe conservé.
      final byAuthor = <String, List<StoryEntity>>{};
      for (final story in entities) {
        (byAuthor[story.authorId] ??= []).add(story);
      }
      final grouped = byAuthor.entries.map((entry) {
        final stories = entry.value..sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        );
        final first = stories.first;
        return AuthorStories(
          authorId: entry.key,
          authorName: first.authorName,
          authorPhotoUrl: first.authorPhotoUrl,
          stories: stories,
        );
      }).toList();

      return Right(grouped);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StoryEntity>> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required StoryMediaType mediaType,
    int? videoDurationSeconds,
    StoryAudience audience = StoryAudience.everyone,
  }) async {
    try {
      final model = await _dataSource.createStory(
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        mediaUrl: mediaUrl,
        mediaType: mediaType == StoryMediaType.video ? 'video' : 'image',
        videoDurationSeconds: videoDurationSeconds,
        audience: audience,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteStory(String storyId) async {
    try {
      await _dataSource.deleteStory(storyId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StoryListMember>>> getListMembers(
    String ownerId,
  ) async {
    try {
      return Right(await _dataSource.getListMembers(ownerId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setListMember(
    String ownerId,
    String memberId,
    StoryListKind? kind,
  ) async {
    try {
      await _dataSource.setListMember(ownerId, memberId, kind);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markViewed(
    String storyId,
    String viewerId,
  ) async {
    try {
      await _dataSource.markViewed(storyId, viewerId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StoryViewerEntity>>> getViewers(
    String storyId,
  ) async {
    try {
      final viewers = await _dataSource.getViewers(storyId);
      return Right(viewers);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StoryReactionEntity>>> getReactions(
    String storyId,
  ) async {
    try {
      final reactions = await _dataSource.getReactions(storyId);
      return Right(reactions);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setReaction(
    String storyId,
    String userId,
    String emoji,
  ) async {
    try {
      await _dataSource.setReaction(storyId, userId, emoji);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeReaction(
    String storyId,
    String userId,
  ) async {
    try {
      await _dataSource.removeReaction(storyId, userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
