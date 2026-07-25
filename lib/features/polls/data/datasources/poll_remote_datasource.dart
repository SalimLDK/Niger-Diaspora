import '../models/poll_model.dart';

abstract class PollRemoteDataSource {
  Future<PollModel> createPoll({
    required String contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    required bool allowMultiple,
    DateTime? endsAt,
    String? userId,
  });

  Future<PollModel> getPoll(String pollId, {String? currentUserId});

  Future<List<PollModel>> getPollsByContext(
    String contextType,
    String contextId, {
    String? currentUserId,
  });

  Stream<PollModel?> getPollStream(String pollId);

  Future<void> vote(String pollId, List<String> optionIds, {String? userId});

  Future<List<Map<String, dynamic>>> getOptionVoters(String pollId, String optionId);

  Future<void> deletePoll(String pollId);
}
