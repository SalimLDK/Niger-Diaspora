import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/feed/data/models/post_model.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/domain/repositories/feed_repository.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_provider.dart';

/// Repli hors ligne du fil (maquette 2a).
///
/// Régression constatée sur appareil le 2026-08-04, en mode avion réel :
/// « Le fil » restait sur ses squelettes de chargement indéfiniment alors que
/// le cache était présent et valide. Cause : `getFeedPaginated` était attendu
/// sans borne — un réseau qui *pend* au lieu d'échouer ne rendait jamais la
/// main, donc `_handleLoadFailure` (qui lit le cache) n'était jamais atteint
/// et `isLoading` restait vrai.
///
/// Le correctif a deux volets, testés ici :
///   1. le cache est affiché **avant** d'interroger le réseau ;
///   2. l'attente réseau est bornée.
///
/// Le volet 2 n'est pas testé par une attente réelle de 10 s : on vérifie le
/// volet 1, qui est ce que l'utilisateur voit, et qui suffit à faire
/// disparaître les squelettes.
class _RepoQuiPend implements FeedRepository {
  /// Ne se complète jamais : simule un socket qui pend (mode avion, portail
  /// captif) plutôt qu'une erreur franche.
  @override
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit = 20,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) => Completer<Either<Failure, PaginatedPosts>>().future;

  @override
  Stream<PostEntity> watchNewPosts() => const Stream.empty();

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('feed_cache_test');
    Hive.init(tempDir.path);
    await CacheService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async => CacheService.instance.clearFeedCache());

  /// Une page de fil en cache, telle que l'app l'écrit réellement
  /// (`PostModel.toJson`, donc horodatage UTC suffixé `Z`).
  Future<void> semerLeCache({required String createdAtIso}) async {
    final post = PostModel.fromJson({
      'id': 'p1',
      'authorId': 'u1',
      'authorName': 'Salim',
      'content': 'publication en cache',
      'createdAt': createdAtIso,
      'updatedAt': createdAtIso,
    });
    await CacheService.instance.cacheFeed(
      CacheService.feedKey(mode: FeedMode.forYou.name),
      [post.toJson()],
    );
  }

  test(
    'un réseau qui pend n\'enferme plus le fil dans ses squelettes : '
    'le cache est affiché',
    () async {
      await semerLeCache(createdAtIso: '2026-08-04T06:01:00.000Z');

      final container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(_RepoQuiPend())],
      );
      addTearDown(container.dispose);

      // `build()` déclenche loadInitial via un microtask ; on laisse la boucle
      // d'évènements tourner sans jamais compléter la requête réseau.
      container.read(feedNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(feedNotifierProvider);

      // Le point de la régression : des publications, pas un écran vide.
      // L'écran ne montre ses squelettes que si `posts` est vide.
      expect(state.posts, isNotEmpty,
          reason: 'le cache aurait dû être affiché sans attendre le réseau');
      expect(state.posts.single.content, 'publication en cache');
      expect(state.isFromCache, isTrue,
          reason: 'le bandeau « contenu hors ligne » doit apparaître');
      expect(state.cachedAt, isNotNull);
      // Pas de pagination sur du cache : on n'a que la première page.
      expect(state.hasMore, isFalse);
    },
  );

  test('sans cache, rien n\'est inventé : le fil reste vide', () async {
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(_RepoQuiPend())],
    );
    addTearDown(container.dispose);

    container.read(feedNotifierProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(feedNotifierProvider);
    expect(state.posts, isEmpty);
    expect(state.isFromCache, isFalse);
  });

  test('le cache traverse l\'aller-retour sans décaler l\'instant', () async {
    await semerLeCache(createdAtIso: '2026-08-04T06:01:00.000Z');

    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(_RepoQuiPend())],
    );
    addTearDown(container.dispose);

    container.read(feedNotifierProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final relu = container.read(feedNotifierProvider).posts.single.createdAt;
    expect(relu.isUtc, isFalse, reason: 'normalisé en local à la lecture');
    expect(relu, DateTime.utc(2026, 8, 4, 6, 1).toLocal());
  });
}
