import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/story_entity.dart';

abstract class StoryRepository {
  /// Stories actives (< 24h), groupées par auteur.
  Future<Either<Failure, List<AuthorStories>>> getActiveStories(
    String currentUserId,
  );

  Future<Either<Failure, StoryEntity>> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required StoryMediaType mediaType,
    int? videoDurationSeconds,
    StoryAudience audience = StoryAudience.everyone,
  });

  Future<Either<Failure, void>> deleteStory(String storyId);

  Future<Either<Failure, List<StoryListMember>>> getListMembers(String ownerId);

  Future<Either<Failure, void>> setListMember(
    String ownerId,
    String memberId,
    StoryListKind? kind,
  );

  Future<Either<Failure, void>> markViewed(String storyId, String viewerId);

  Future<Either<Failure, List<StoryViewerEntity>>> getViewers(String storyId);

  Future<Either<Failure, List<StoryReactionEntity>>> getReactions(
    String storyId,
  );

  Future<Either<Failure, void>> setReaction(
    String storyId,
    String userId,
    String emoji,
  );

  Future<Either<Failure, void>> removeReaction(String storyId, String userId);
}
