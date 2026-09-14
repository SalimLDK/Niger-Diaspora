import '../models/poll_model.dart';

abstract class PollRemoteDataSource {
  Future<PollModel> createPoll({
    required String contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    required bool allowMultiple,
    required bool isAnonymous,
    DateTime? endsAt,
    String? userId,
  });

  Future<PollModel> getPoll(String pollId, {String? currentUserId});

  Future<List<PollModel>> getPollsByContext(
    String contextType,
    String contextId, {
    String? currentUserId,
  });

  /// Flux du sondage. [currentUserId] n'est pas decoratif : sans lui le flux
  /// rend un sondage ou personne n'a jamais vote — voir le doc-comment de
  /// l'implementation Supabase.
  Stream<PollModel?> getPollStream(String pollId, {String? currentUserId});

  Future<void> vote(String pollId, List<String> optionIds, {String? userId});

  /// Votants de chaque option, indexes par `optionId`. Un seul aller-retour
  /// pour tout le sondage — l'ecran de resultats en faisait un par option.
  Future<Map<String, List<Map<String, dynamic>>>> getPollVoters(String pollId);

  Future<void> deletePoll(String pollId);
}
