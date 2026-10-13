import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/garde_appel.dart';
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
    return garderAppel(() async {
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
    }, sinon: (e) => ServerFailure(e.toString()));
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
    return garderAppel(() async {
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
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> deleteStory(String storyId) async {
    return garderAppel(() async {
      await _dataSource.deleteStory(storyId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, List<StoryListMember>>> getListMembers(
    String ownerId,
  ) async {
    return garderAppel(() async {
      return Right(await _dataSource.getListMembers(ownerId));
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> setListMember(
    String ownerId,
    String memberId,
    StoryListKind? kind,
  ) async {
    return garderAppel(() async {
      await _dataSource.setListMember(ownerId, memberId, kind);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> markViewed(
    String storyId,
    String viewerId,
  ) async {
    return garderAppel(() async {
      await _dataSource.markViewed(storyId, viewerId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, List<StoryViewerEntity>>> getViewers(
    String storyId,
  ) async {
    return garderAppel(() async {
      final viewers = await _dataSource.getViewers(storyId);
      return Right(viewers);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, List<StoryReactionEntity>>> getReactions(
    String storyId,
  ) async {
    return garderAppel(() async {
      final reactions = await _dataSource.getReactions(storyId);
      return Right(reactions);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> setReaction(
    String storyId,
    String userId,
    String emoji,
  ) async {
    return garderAppel(() async {
      await _dataSource.setReaction(storyId, userId, emoji);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> removeReaction(
    String storyId,
    String userId,
  ) async {
    return garderAppel(() async {
      await _dataSource.removeReaction(storyId, userId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }
}
