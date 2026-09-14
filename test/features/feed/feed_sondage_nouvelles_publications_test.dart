import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/domain/repositories/feed_repository.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_provider.dart';

/// Sondage périodique du fil (« y a-t-il du nouveau ? »), qui alimente la
/// pastille « N nouvelles publications ».
///
/// La pastille existait déjà, mais elle ne dépendait que du canal temps réel.
/// Ce canal tombe en silence (websocket coupée, canal jamais rejoint) et il
/// écarte volontairement les publications « Amis » d'autrui : le fil pouvait
/// donc rester figé sans que rien ne le signale. Le sondage repasse par la
/// requête soumise à la RLS, à intervalle régulier.
///
/// Ce que ces tests fixent : le sondage ne touche pas au fil affiché, il ne
/// compte pas deux fois la même publication, et il ne mitraille pas le réseau.
class _RepoDePage implements FeedRepository {
  _RepoDePage(this.page);

  /// Ce que rend le serveur, remplaçable entre deux appels.
  List<PostEntity> page;

  /// Nombre d'appels reçus, pour prouver l'intervalle minimal.
  int appels = 0;

  @override
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit = 20,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) async {
    appels++;
    return Right(PaginatedPosts(posts: page, hasMore: false));
  }

  @override
  Stream<PostEntity> watchNewPosts() => const Stream.empty();

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostEntity _post(String id, {required DateTime creeLe, String auteur = 'u1'}) {
  return PostEntity(
    id: id,
    authorId: auteur,
    authorName: 'Salim',
    content: 'publication $id',
    createdAt: creeLe,
    updatedAt: creeLe,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final base = DateTime(2026, 9, 14, 8);

  /// Un fil chargé, en mode « Récent » — le mode « Pour vous » passerait par
  /// le scoreur, qui dépend d'un profil absent en test.
  Future<(ProviderContainer, _RepoDePage)> filCharge(
    List<PostEntity> page,
  ) async {
    final repo = _RepoDePage(page);
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(feedNotifierProvider.notifier);
    await notifier.setMode(FeedMode.recent);
    return (container, repo);
  }

  test(
    'une publication parue depuis le chargement part en attente, '
    'sans déplacer le fil affiché',
    () async {
      final (container, repo) = await filCharge([
        _post('p1', creeLe: base),
      ]);
      expect(container.read(feedNotifierProvider).posts, hasLength(1));

      // Le serveur a du nouveau en tête de fil.
      repo.page = [
        _post('p2', creeLe: base.add(const Duration(minutes: 5))),
        _post('p1', creeLe: base),
      ];
      await container
          .read(feedNotifierProvider.notifier)
          .checkForNewPosts(force: true);

      final state = container.read(feedNotifierProvider);
      expect(state.pendingPosts.map((p) => p.id), ['p2'],
          reason: 'la pastille doit annoncer la publication parue');
      expect(state.posts.map((p) => p.id), ['p1'],
          reason: 'le fil ne bouge pas tant que la pastille n\'est pas touchée');

      // Et la pastille, une fois touchée, pose le nouveau en tête.
      container.read(feedNotifierProvider.notifier).showPendingPosts();
      final apres = container.read(feedNotifierProvider);
      expect(apres.posts.map((p) => p.id), ['p2', 'p1']);
      expect(apres.pendingPosts, isEmpty);
    },
  );

  test('une publication déjà affichée ne repasse pas pour nouvelle', () async {
    final (container, repo) = await filCharge([_post('p1', creeLe: base)]);

    // Même page : rien de neuf, malgré une requête qui aboutit.
    await container
        .read(feedNotifierProvider.notifier)
        .checkForNewPosts(force: true);

    expect(container.read(feedNotifierProvider).pendingPosts, isEmpty);
    expect(repo.appels, greaterThan(1), reason: 'le sondage a bien interrogé');
  });

  test(
    'deux sondages rapprochés ne font qu\'une requête : '
    'revenir sur l\'onglet ne mitraille pas le réseau',
    () async {
      final (container, repo) = await filCharge([_post('p1', creeLe: base)]);
      final notifier = container.read(feedNotifierProvider.notifier);

      await notifier.checkForNewPosts(force: true);
      final apresPremier = repo.appels;
      await notifier.checkForNewPosts();
      await notifier.checkForNewPosts();

      expect(repo.appels, apresPremier,
          reason: 'l\'intervalle minimal doit avaler les sondages rapprochés');
    },
  );

  test('un fil vide ne sonde rien : c\'est le chargement qui a la main',
      () async {
    final (container, repo) = await filCharge(const []);
    expect(container.read(feedNotifierProvider).posts, isEmpty);
    final avant = repo.appels;

    await container
        .read(feedNotifierProvider.notifier)
        .checkForNewPosts(force: true);

    expect(repo.appels, avant);
  });
}
