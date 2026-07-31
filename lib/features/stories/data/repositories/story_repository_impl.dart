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
      final entities = models.map((m) => m.toEntity()).toList();

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
  }) async {
    try {
      final model = await _dataSource.createStory(
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        mediaUrl: mediaUrl,
        mediaType: mediaType == StoryMediaType.video ? 'video' : 'image',
        videoDurationSeconds: videoDurationSeconds,
      );
      return Right(model.toEntity());
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
}
