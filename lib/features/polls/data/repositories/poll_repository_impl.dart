import 'dart:async';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/poll_entity.dart';
import '../../domain/repositories/poll_repository.dart';
import '../datasources/poll_remote_datasource.dart';
import '../models/poll_model.dart';

class PollRepositoryImpl implements PollRepository {
  final PollRemoteDataSource remoteDataSource;

  PollRepositoryImpl({required this.remoteDataSource});

  String _contextTypeValue(PollContextType type) => type.name;

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
  Stream<Either<Failure, PollEntity?>> getPollStream(
    String pollId, {
    String? currentUserId,
  }) {
    // `handleError` qui se contente de *retourner* une valeur ne la publie
    // pas : l'erreur etait avalee, et l'ecran de resultats tournait
    // indefiniment sur son indicateur de chargement. Un transformateur la
    // convertit en emission `Left`, que l'appelant peut distinguer d'un
    // sondage supprime (`Right(null)`).
    return remoteDataSource.getPollStream(pollId, currentUserId: currentUserId).transform(
          StreamTransformer<PollModel?, Either<Failure, PollEntity?>>.fromHandlers(
            handleData: (poll, sink) =>
                sink.add(Right<Failure, PollEntity?>(poll?.toEntity())),
            handleError: (error, stackTrace, sink) => sink.add(
              Left<Failure, PollEntity?>(ServerFailure(error.toString())),
            ),
          ),
        );
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
  Future<Either<Failure, Map<String, List<PollVoterEntity>>>> getPollVoters(
    String pollId,
  ) async {
    try {
      final parOption = await remoteDataSource.getPollVoters(pollId);
      return Right(parOption.map(
        (optionId, rows) => MapEntry(
          optionId,
          rows
              .map((row) => PollVoterEntity(
                    userId: row['user_id'] as String? ?? '',
                    name: row['display_name'] as String?,
                    photoUrl: row['avatar_url'] as String?,
                  ))
              .toList(),
        ),
      ));
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
