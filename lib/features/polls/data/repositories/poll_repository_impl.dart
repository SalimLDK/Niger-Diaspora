import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/poll_entity.dart';
import '../../domain/repositories/poll_repository.dart';
import '../datasources/poll_remote_datasource.dart';

class PollRepositoryImpl implements PollRepository {
  final PollRemoteDataSource remoteDataSource;

  PollRepositoryImpl({required this.remoteDataSource});

  String _contextTypeValue(PollContextType type) =>
      type == PollContextType.post ? 'post' : 'group';

  @override
  Future<Either<Failure, PollEntity>> createPoll({
    required PollContextType contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple = false,
    DateTime? endsAt,
    String? userId,
  }) async {
    try {
      final poll = await remoteDataSource.createPoll(
        contextType: _contextTypeValue(contextType),
        contextId: contextId,
        question: question,
        optionLabels: optionLabels,
        allowMultiple: allowMultiple,
        endsAt: endsAt,
        userId: userId,
      );
      return Right(poll.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PollEntity>> getPoll(
    String pollId, {
    String? currentUserId,
  }) async {
    try {
      final poll =
          await remoteDataSource.getPoll(pollId, currentUserId: currentUserId);
      return Right(poll.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PollEntity>>> getPollsByContext(
    PollContextType contextType,
    String contextId, {
    String? currentUserId,
  }) async {
    try {
      final polls = await remoteDataSource.getPollsByContext(
        _contextTypeValue(contextType),
        contextId,
        currentUserId: currentUserId,
      );
      return Right(polls.map((p) => p.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, PollEntity?>> getPollStream(String pollId) {
    return remoteDataSource.getPollStream(pollId).map((poll) {
      return Right<Failure, PollEntity?>(poll?.toEntity());
    }).handleError((e) {
      return Left<Failure, PollEntity?>(ServerFailure(e.toString()));
    });
  }

  @override
  Future<Either<Failure, void>> vote(
    String pollId,
    List<String> optionIds, {
    String? userId,
  }) async {
    try {
      await remoteDataSource.vote(pollId, optionIds, userId: userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PollVoterEntity>>> getOptionVoters(
    String pollId,
    String optionId,
  ) async {
    try {
      final rows = await remoteDataSource.getOptionVoters(pollId, optionId);
      final voters = rows.map((row) {
        final voter = row['voter'] as Map<String, dynamic>?;
        return PollVoterEntity(
          userId: row['user_id'] as String,
          name: voter?['display_name'] as String?,
          photoUrl: voter?['avatar_url'] as String?,
        );
      }).toList();
      return Right(voters);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePoll(String pollId) async {
    try {
      await remoteDataSource.deletePoll(pollId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
