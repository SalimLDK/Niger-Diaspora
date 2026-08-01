import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/story_supabase_datasource.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepositoryImpl(StorySupabaseDataSource());
});

/// Stories actives groupées par auteur, pour le rail du fil.
final activeStoriesProvider =
    FutureProvider<List<AuthorStories>>((ref) async {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return const [];
  final result =
      await ref.watch(storyRepositoryProvider).getActiveStories(userId);
  return result.fold((failure) => throw failure.message, (stories) => stories);
});

/// Qui a vu une story donnée (§4) — visible seulement pour son auteur, RLS
/// déjà posée en ce sens (voir migration `stories.sql`, policy
/// `story_views_select`).
final storyViewersProvider =
    FutureProvider.family<List<StoryViewerEntity>, String>((
  ref,
  storyId,
) async {
  final result = await ref.watch(storyRepositoryProvider).getViewers(storyId);
  return result.fold((failure) => throw failure.message, (viewers) => viewers);
});

/// Réactions visibles sur une story (§4) : toutes si j'en suis l'auteur,
/// sinon seulement la mienne (RLS).
final storyReactionsProvider =
    FutureProvider.family<List<StoryReactionEntity>, String>((
  ref,
  storyId,
) async {
  final result = await ref.watch(storyRepositoryProvider).getReactions(storyId);
  return result.fold(
    (failure) => throw failure.message,
    (reactions) => reactions,
  );
});

final storyActionsNotifierProvider =
    NotifierProvider<StoryActionsNotifier, AsyncValue<void>>(
  StoryActionsNotifier.new,
);

class StoryActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required StoryMediaType mediaType,
    int? videoDurationSeconds,
  }) async {
    state = const AsyncValue.loading();
    final result = await ref.read(storyRepositoryProvider).createStory(
          authorId: authorId,
          authorName: authorName,
          authorPhotoUrl: authorPhotoUrl,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          videoDurationSeconds: videoDurationSeconds,
        );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(activeStoriesProvider);
        return true;
      },
    );
  }

  Future<void> markViewed(String storyId) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref.read(storyRepositoryProvider).markViewed(storyId, userId);
    // Pas d'invalidate ici : ça relancerait un fetch au milieu de la lecture
    // du viewer. L'anneau se remettra à jour au prochain chargement du rail.
  }

  /// Pose ma réaction, ou la retire si je retape le même emoji (toggle).
  Future<void> toggleReaction(String storyId, String emoji) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    final repo = ref.read(storyRepositoryProvider);
    final current = ref.read(storyReactionsProvider(storyId)).valueOrNull;
    final mine = current?.where((r) => r.userId == userId).firstOrNull;
    if (mine?.emoji == emoji) {
      await repo.removeReaction(storyId, userId);
    } else {
      await repo.setReaction(storyId, userId, emoji);
    }
    ref.invalidate(storyReactionsProvider(storyId));
  }
}
