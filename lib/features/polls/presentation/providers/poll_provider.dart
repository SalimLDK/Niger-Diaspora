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

/// Sondages d'un post du fil (§13/23d) — mirror de [groupPollsProvider].
final postPollsProvider =
    FutureProvider.family<List<PollEntity>, String>((ref, postId) async {
  final repository = ref.watch(pollRepositoryProvider);
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  final result = await repository.getPollsByContext(
    PollContextType.post,
    postId,
    currentUserId: userId,
  );
  return result.fold((failure) => throw failure.message, (polls) => polls);
});

/// Detail d'un sondage en temps reel (mise a jour live des votes).
///
/// `currentUserId` est observe, pas lu une fois : au premier affichage il est
/// souvent encore null, et sans re-souscription le sondage resterait « jamais
/// vote » pour son propre lecteur.
final pollStreamProvider =
    StreamProvider.family<PollEntity?, String>((ref, pollId) {
  final repository = ref.watch(pollRepositoryProvider);
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  return repository.getPollStream(pollId, currentUserId: userId).map(
        // Une panne de lecture n'est pas une suppression : elle part en
        // erreur, l'ecran garde alors la question envoyee en repli au lieu
        // d'annoncer « Sondage supprime ».
        (either) => either.fold(
          (failure) => throw failure.message,
          (poll) => poll,
        ),
      );
});

/// Votants de chaque option, indexes par identifiant d'option.
///
/// Vide pour un sondage anonyme : `poll_option_voters` ne rend alors rien a
/// personne, pas meme a son auteur. Invalide apres chaque vote — sans quoi
/// l'ecran de resultats gardait la liste du premier affichage.
final pollVotersProvider = FutureProvider.family<
    Map<String, List<PollVoterEntity>>, String>((ref, pollId) async {
  final result = await ref.watch(pollRepositoryProvider).getPollVoters(pollId);
  return result.fold((failure) => const {}, (voters) => voters);
});

final pollActionsNotifierProvider =
    NotifierProvider<PollActionsNotifier, AsyncValue<void>>(
  PollActionsNotifier.new,
);

class PollActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Rend le sondage cree, ou null en cas d'echec — l'appelant a besoin de
  /// son id pour publier la bulle dans la conversation.
  Future<PollEntity?> createGroupPoll({
    required String groupId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple = false,
    bool isAnonymous = false,
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
          isAnonymous: isAnonymous,
          endsAt: endsAt,
          userId: userId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (poll) {
        state = const AsyncValue.data(null);
        ref.invalidate(groupPollsProvider(groupId));
        return poll;
      },
    );
  }

  /// Sondage d'une discussion privée — mirror de [createGroupPoll]. Seuls
  /// ses participants le lisent et y votent (RLS, migration 20260912233000).
  Future<PollEntity?> createConversationPoll({
    required String conversationId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple = false,
    bool isAnonymous = false,
    DateTime? endsAt,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    state = const AsyncValue.loading();

    final result = await ref.read(pollRepositoryProvider).createPoll(
          contextType: PollContextType.conversation,
          contextId: conversationId,
          question: question,
          optionLabels: optionLabels,
          allowMultiple: allowMultiple,
          isAnonymous: isAnonymous,
          endsAt: endsAt,
          userId: userId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (poll) {
        state = const AsyncValue.data(null);
        return poll;
      },
    );
  }

  /// Sondage sur un post du fil — mirror de [createGroupPoll]. Le post doit
  /// déjà exister (contrairement à un groupe, son id n'est connu qu'après
  /// publication : voir `create_post_screen.dart`).
  Future<PollEntity?> createPostPoll({
    required String postId,
    required String question,
    required List<String> optionLabels,
    bool allowMultiple = false,
    bool isAnonymous = false,
    DateTime? endsAt,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    state = const AsyncValue.loading();

    final result = await ref.read(pollRepositoryProvider).createPoll(
          contextType: PollContextType.post,
          contextId: postId,
          question: question,
          optionLabels: optionLabels,
          allowMultiple: allowMultiple,
          isAnonymous: isAnonymous,
          endsAt: endsAt,
          userId: userId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (poll) {
        state = const AsyncValue.data(null);
        ref.invalidate(postPollsProvider(postId));
        return poll;
      },
    );
  }

  /// Enregistre le vote. [optionIds] vide = retrait du vote.
  Future<bool> vote(
    String pollId,
    List<String> optionIds, {
    String? groupId,
    String? postId,
  }) async {
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
        if (postId != null) ref.invalidate(postPollsProvider(postId));
        // La bulle de conversation lit le sondage par ce stream : sans cette
        // invalidation, le votant devait quitter l'ecran pour voir son propre
        // vote compte (le realtime sert les AUTRES membres).
        ref.invalidate(pollStreamProvider(pollId));
        ref.invalidate(pollVotersProvider(pollId));
        return true;
      },
    );
  }

  /// Retire son vote sans en poser un autre. La policy DELETE
  /// « Users can retract their own vote » existait depuis le debut sans que
  /// rien dans l'app ne puisse l'emprunter.
  Future<bool> withdrawVote(
    String pollId, {
    String? groupId,
    String? postId,
  }) =>
      vote(pollId, const [], groupId: groupId, postId: postId);

  Future<bool> deletePoll(
    String pollId, {
    String? groupId,
    String? postId,
  }) async {
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
        if (postId != null) ref.invalidate(postPollsProvider(postId));
        return true;
      },
    );
  }
}
