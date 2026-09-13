import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/story_supabase_datasource.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepositoryImpl(StorySupabaseDataSource());
});

/// Délai de relecture du rail tant qu'il est affiché.
///
/// Le provider n'était relu qu'après MA propre publication : une story
/// publiée par quelqu'un d'autre n'apparaissait qu'au redémarrage de l'app —
/// « je ne vois pas les stories des autres » (2026-09-12).
const Duration _storyRailRefresh = Duration(minutes: 2);

/// Stories actives groupées par auteur, pour le rail du fil.
///
/// Se relit tout seul : à la prochaine expiration d'une story affichée (elle
/// quitte le rail à l'heure dite, pas au prochain chargement), et toutes les
/// deux minutes tant que quelqu'un l'écoute.
final activeStoriesProvider =
    FutureProvider<List<AuthorStories>>((ref) async {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return const [];

  final timers = <Timer>[];
  void cancelTimers() {
    for (final t in timers) {
      t.cancel();
    }
    timers.clear();
  }

  ref.onDispose(cancelTimers);
  // Plus personne n'écoute : on arrête de relire. Au retour d'un auditeur,
  // on relit tout de suite — le rail a pu rater des publications.
  ref.onCancel(cancelTimers);
  ref.onResume(ref.invalidateSelf);

  final result =
      await ref.watch(storyRepositoryProvider).getActiveStories(userId);
  final groups =
      result.fold((failure) => throw failure.message, (stories) => stories);

  timers.add(Timer(_storyRailRefresh, ref.invalidateSelf));
  final now = DateTime.now();
  final prochaine = groups
      .expand((g) => g.stories)
      .map((s) => s.expiresAt)
      .where((t) => t.isAfter(now))
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  if (prochaine != null) {
    timers.add(
      Timer(
        prochaine.difference(now) + const Duration(seconds: 1),
        ref.invalidateSelf,
      ),
    );
  }
  return groups;
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

/// Mes deux listes de stories : restreinte (« whitelist ») et masqué
/// (« blacklist »). La base n'en rend qu'à leur auteur.
final storyListMembersProvider =
    FutureProvider.autoDispose<List<StoryListMember>>((ref) async {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return const [];
  final result =
      await ref.watch(storyRepositoryProvider).getListMembers(userId);
  return result.fold((failure) => throw failure.message, (members) => members);
});

/// Audience proposée par défaut à la prochaine story : la dernière choisie.
///
/// Une préférence d'appareil, pas un réglage de compte : l'audience réelle
/// est écrite sur chaque story (`stories.audience`), c'est elle qui fait foi.
final storyDefaultAudienceProvider =
    NotifierProvider<StoryDefaultAudienceNotifier, StoryAudience>(
  StoryDefaultAudienceNotifier.new,
);

class StoryDefaultAudienceNotifier extends Notifier<StoryAudience> {
  static const _key = 'story_default_audience';

  @override
  StoryAudience build() {
    unawaited(_load());
    return StoryAudience.everyone;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = StoryAudience.fromDb(prefs.getString(_key));
      state = saved;
    } catch (_) {
      // Préférence d'appareil illisible : « Tout le monde », comme la base.
    }
  }

  Future<void> set(StoryAudience audience) async {
    state = audience;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, audience.dbValue);
    } catch (_) {}
  }
}

final storyActionsNotifierProvider =
    NotifierProvider<StoryActionsNotifier, AsyncValue<void>>(
  StoryActionsNotifier.new,
);

class StoryActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Publie une story. Renvoie le message d'échec, ou `null` en cas de
  /// succès — l'appelant doit l'afficher : l'échec était avalé et une
  /// publication ratée ne se distinguait pas d'un appui sans effet.
  Future<String?> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required StoryMediaType mediaType,
    int? videoDurationSeconds,
    required StoryAudience audience,
  }) async {
    state = const AsyncValue.loading();
    final result = await ref.read(storyRepositoryProvider).createStory(
          authorId: authorId,
          authorName: authorName,
          authorPhotoUrl: authorPhotoUrl,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          videoDurationSeconds: videoDurationSeconds,
          audience: audience,
        );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(activeStoriesProvider);
        return null;
      },
    );
  }

  /// Supprime une de mes stories. Renvoie le message d'échec, ou `null`.
  Future<String?> deleteStory(String storyId) async {
    final result = await ref.read(storyRepositoryProvider).deleteStory(storyId);
    return result.fold((failure) => failure.message, (_) {
      ref.invalidate(activeStoriesProvider);
      return null;
    });
  }

  /// Range une personne dans une liste, ou l'en retire ([kind] nul).
  Future<String?> setListMember(String memberId, StoryListKind? kind) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return 'Non connecté';
    if (memberId == userId) return 'Vous ne pouvez pas vous ajouter vous-même';
    final result = await ref
        .read(storyRepositoryProvider)
        .setListMember(userId, memberId, kind);
    return result.fold((failure) => failure.message, (_) {
      ref.invalidate(storyListMembersProvider);
      return null;
    });
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
