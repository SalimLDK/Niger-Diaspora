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
    bool isAnonymous,
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

  /// Flux du sondage. Sans [currentUserId] le sondage arrive « jamais vote »
  /// quel que soit le lecteur — voir l'implementation Supabase.
  Stream<Either<Failure, PollEntity?>> getPollStream(
    String pollId, {
    String? currentUserId,
  });

  Future<Either<Failure, void>> vote(
    String pollId,
    List<String> optionIds, {
    String? userId,
  });

  /// Votants de chaque option, indexes par identifiant d'option. Vide pour un
  /// sondage anonyme — la base ne les rend alors a personne.
  Future<Either<Failure, Map<String, List<PollVoterEntity>>>> getPollVoters(
    String pollId,
  );

  Future<Either<Failure, void>> deletePoll(String pollId);
}
