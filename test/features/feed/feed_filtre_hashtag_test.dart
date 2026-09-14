import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/domain/repositories/feed_repository.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_provider.dart';

/// Filtre hashtag du fil.
///
/// Mesuré sur SM A515F le 2026-09-14 : ouvrir `diasponiger://feed?hashtag=…`
/// alors que le fil est déjà à l'écran affichait la bannière du hashtag **et**
/// le fil non filtré. Deux défauts derrière ce seul symptôme :
///
///   1. le filtre ne pouvait pas être **levé** — `copyWith` faisait
///      `hashtagFilter ?? this.hashtagFilter` et `loadInitial` pareil, donc
///      « null » voulait dire « garde l'ancien ». Le notifier étant partagé
///      par le fil général et le fil d'un hashtag, revenir du second laissait
///      le premier filtré ;
///   2. l'écran ne posait son filtre que dans `initState`, qui ne rejoue pas
///      quand go_router réutilise l'État (le cas du lien profond).
///
/// Ce fichier fixe le premier, qui est la cause profonde : sans un filtre
/// levable, aucun correctif d'écran ne pouvait suffire.
class _RepoTracant implements FeedRepository {
  /// Les filtres reçus, dans l'ordre — `null` compris.
  final filtresRecus = <String?>[];

  /// Ce que rend chaque requête, par filtre.
  final Map<String?, List<PostEntity>> parFiltre = {};

  @override
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit = 20,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) async {
    filtresRecus.add(hashtagFilter);
    return Right(
      PaginatedPosts(posts: parFiltre[hashtagFilter] ?? const [], hasMore: false),
    );
  }

  @override
  Stream<PostEntity> watchNewPosts() => const Stream.empty();

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostEntity _post(String id) {
  final t = DateTime(2026, 9, 14, 11);
  return PostEntity(
    id: id,
    authorId: 'u1',
    authorName: 'Salim',
    content: 'publication $id',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (ProviderContainer, _RepoTracant) monter() {
    final repo = _RepoTracant();
    repo.parFiltre[null] = [_post('general')];
    repo.parFiltre['niamey'] = [_post('niamey')];
    repo.parFiltre['zzz'] = const [];
    final container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue(() => 'moi'),
      ],
    );
    addTearDown(container.dispose);
    return (container, repo);
  }

  test('poser un filtre interroge la base avec ce filtre', () async {
    final (container, repo) = monter();
    final notifier = container.read(feedNotifierProvider.notifier);
    await notifier.setHashtagFilter('niamey');

    expect(container.read(feedNotifierProvider).hashtagFilter, 'niamey');
    expect(repo.filtresRecus.last, 'niamey');
    expect(
      container.read(feedNotifierProvider).posts.map((p) => p.id),
      ['niamey'],
    );
  });

  test('le filtre se lève : c\'est ce qui ne marchait pas', () async {
    final (container, repo) = monter();
    final notifier = container.read(feedNotifierProvider.notifier);
    await notifier.setHashtagFilter('niamey');
    await notifier.setHashtagFilter(null);

    expect(container.read(feedNotifierProvider).hashtagFilter, isNull,
        reason: 'revenir au fil général doit effacer le filtre');
    expect(repo.filtresRecus.last, isNull,
        reason: 'et la requête suivante ne doit plus le porter');
    expect(
      container.read(feedNotifierProvider).posts.map((p) => p.id),
      ['general'],
      reason: 'le fil général reprend ses publications',
    );
  });

  test(
    'un filtre sans résultat vide la liste au lieu de garder la précédente',
    () async {
      final (container, _) = monter();
      final notifier = container.read(feedNotifierProvider.notifier);
      await notifier.setHashtagFilter('niamey');
      expect(container.read(feedNotifierProvider).posts, isNotEmpty);

      await notifier.setHashtagFilter('zzz');

      expect(container.read(feedNotifierProvider).posts, isEmpty,
          reason: 'sinon on lit les publications de l\'autre hashtag sous la '
              'bannière du nouveau');
    },
  );

  test('reposer le même filtre ne relance pas de requête', () async {
    final (container, repo) = monter();
    final notifier = container.read(feedNotifierProvider.notifier);
    await notifier.setHashtagFilter('niamey');
    final apres = repo.filtresRecus.length;

    await notifier.setHashtagFilter('niamey');

    expect(repo.filtresRecus.length, apres,
        reason: 'l\'écran réaffirme son filtre à chaque retour : ça doit être '
            'gratuit quand rien ne change');
  });
}
