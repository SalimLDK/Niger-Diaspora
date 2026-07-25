import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/poll_entity.dart';

abstract class PollRepository {
  Future<Either<Failure, PollEntity>> createPoll({
    required PollContextType contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple,
    DateTime? endsAt,
    String? userId,
  });

  Future<Either<Failure, PollEntity>> getPoll(
    String pollId, {
    String? currentUserId,
  });

  Future<Either<Failure, List<PollEntity>>> getPollsByContext(
    PollContextType contextType,
    String contextId, {
    String? currentUserId,
  });

  Stream<Either<Failure, PollEntity?>> getPollStream(String pollId);

  Future<Either<Failure, void>> vote(
    String pollId,
    List<String> optionIds, {
    String? userId,
  });

  Future<Either<Failure, List<PollVoterEntity>>> getOptionVoters(
    String pollId,
    String optionId,
  );

  Future<Either<Failure, void>> deletePoll(String pollId);
}
