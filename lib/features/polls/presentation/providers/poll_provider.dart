import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/poll_supabase_datasource.dart';
import '../../data/repositories/poll_repository_impl.dart';
import '../../domain/entities/poll_entity.dart';
import '../../domain/repositories/poll_repository.dart';

final pollRepositoryProvider = Provider<PollRepository>((ref) {
  return PollRepositoryImpl(remoteDataSource: PollSupabaseDataSource());
});

/// Sondages d'un groupe (rafraichi via ref.invalidate apres creation/vote/suppression)
final groupPollsProvider =
    FutureProvider.family<List<PollEntity>, String>((ref, groupId) async {
  final repository = ref.watch(pollRepositoryProvider);
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  final result = await repository.getPollsByContext(
    PollContextType.group,
    groupId,
    currentUserId: userId,
  );
  return result.fold((failure) => throw failure.message, (polls) => polls);
});

/// Detail d'un sondage en temps reel (mise a jour live des votes)
final pollStreamProvider =
    StreamProvider.family<PollEntity?, String>((ref, pollId) {
  final repository = ref.watch(pollRepositoryProvider);
  return repository.getPollStream(pollId).map(
        (either) => either.fold((failure) => null, (poll) => poll),
      );
});

final pollActionsNotifierProvider =
    NotifierProvider<PollActionsNotifier, AsyncValue<void>>(
  PollActionsNotifier.new,
);

class PollActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> createGroupPoll({
    required String groupId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple = false,
    DateTime? endsAt,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    state = const AsyncValue.loading();

    final result = await ref.read(pollRepositoryProvider).createPoll(
          contextType: PollContextType.group,
          contextId: groupId,
          question: question,
          optionLabels: optionLabels,
          allowMultiple: allowMultiple,
          endsAt: endsAt,
          userId: userId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(groupPollsProvider(groupId));
        return true;
      },
    );
  }

  Future<bool> vote(String pollId, List<String> optionIds, {String? groupId}) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    state = const AsyncValue.loading();

    final result = await ref
        .read(pollRepositoryProvider)
        .vote(pollId, optionIds, userId: userId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        if (groupId != null) ref.invalidate(groupPollsProvider(groupId));
        return true;
      },
    );
  }

  Future<List<PollVoterEntity>> getOptionVoters(
    String pollId,
    String optionId,
  ) async {
    final result =
        await ref.read(pollRepositoryProvider).getOptionVoters(pollId, optionId);
    return result.fold((failure) => [], (voters) => voters);
  }

  Future<bool> deletePoll(String pollId, {String? groupId}) async {
    state = const AsyncValue.loading();
    final result = await ref.read(pollRepositoryProvider).deletePoll(pollId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        if (groupId != null) ref.invalidate(groupPollsProvider(groupId));
        return true;
      },
    );
  }
}
