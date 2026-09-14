import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/domain/repositories/feed_repository.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_provider.dart';

/// Les chiffres de « Mon espace » et du Profil restaient figés.
///
/// Deux causes distinctes, toutes deux invisibles à la relecture :
///   - « Abonnés » / « Abonnements » sortent de providers qui ne sont pas
///     `autoDispose` et que **personne** n'invalidait : suivre quelqu'un
///     changeait l'état du bouton, et les compteurs gardaient jusqu'au
///     redémarrage la valeur lue au premier affichage ;
///   - « Publications » est `autoDispose`, mais Mon espace reste monté sous
///     l'écran de rédaction : personne ne le relâche, donc publier ne le
///     recalculait pas non plus.
///
/// Ces tests tiennent un abonnement ouvert sur chaque compteur (comme l'écran
/// qui l'affiche) : sans cela `autoDispose` relancerait le calcul à chaque
/// lecture et les tests passeraient sans rien prouver.
class _RepoCompteurs implements FeedRepository {
  /// Ce que la base répond, modifiable entre deux lectures.
  int abonnes = 2;
  int abonnements = 5;
  List<PostEntity> mesPosts = const [];
  Set<String> favoris = const {};

  @override
  Future<Either<Failure, void>> toggleFollow(String targetUserId) async =>
      const Right(null);

  @override
  Future<Either<Failure, int>> getFollowersCount(String userId) async =>
      Right(abonnes);

  @override
  Future<Either<Failure, int>> getFollowingCount(String userId) async =>
      Right(abonnements);

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId) async =>
      Right(mesPosts);

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedPostIds(
    String userId,
  ) async =>
      Right(favoris);

  @override
  Future<Either<Failure, void>> toggleBookmark(
    String postId,
    String userId,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, PostEntity>> createPost(PostEntity post) async =>
      Right(post);

  @override
  Future<Either<Failure, void>> deletePost(String postId) async =>
      const Right(null);

  @override
  Future<Either<Failure, PaginatedPosts>> getFeedPaginated({
    int limit = 20,
    int offset = 0,
    String? hashtagFilter,
    FeedMode mode = FeedMode.forYou,
  }) async =>
      const Right(PaginatedPosts(posts: [], hasMore: false));

  @override
  Stream<PostEntity> watchNewPosts() => const Stream.empty();

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostEntity _post(String id) {
  final t = DateTime(2026, 9, 14, 9);
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

  (ProviderContainer, _RepoCompteurs) monter() {
    final repo = _RepoCompteurs();
    final container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        // Pas de session Firebase sous test : on dit qui est connecté.
        currentUidProvider.overrideWithValue(() => 'moi'),
      ],
    );
    addTearDown(container.dispose);
    return (container, repo);
  }

  test('suivre quelqu\'un recalcule « Abonnés » et « Abonnements »', () async {
    final (container, repo) = monter();
    // L'écran affiche les deux compteurs : il les garde donc vivants.
    container.listen(followersCountProvider('u2'), (_, __) {});
    container.listen(followingCountProvider('moi'), (_, __) {});

    expect(await container.read(followersCountProvider('u2').future), 2);
    expect(await container.read(followingCountProvider('moi').future), 5);

    // La base enregistre l'abonnement.
    repo.abonnes = 3;
    repo.abonnements = 6;
    await container.read(feedNotifierProvider.notifier).toggleFollow('u2');

    expect(await container.read(followersCountProvider('u2').future), 3,
        reason: 'le compte suivi gagne un abonné');
    expect(await container.read(followingCountProvider('moi').future), 6,
        reason: 'et moi un abonnement');
  });

  test('publier recalcule « Publications », supprimer aussi', () async {
    final (container, repo) = monter();
    container.listen(userPostsCountProvider, (_, __) {});
    expect(await container.read(userPostsCountProvider.future), 0);

    repo.mesPosts = [_post('p1')];
    await container.read(feedNotifierProvider.notifier).createPost(_post('p1'));
    expect(await container.read(userPostsCountProvider.future), 1,
        reason: 'le compteur devait suivre la publication');

    repo.mesPosts = const [];
    await container.read(feedNotifierProvider.notifier).deletePost('p1');
    expect(await container.read(userPostsCountProvider.future), 0,
        reason: 'et redescendre à la suppression');
  });

  test('enregistrer une publication recalcule « Enregistrés »', () async {
    final (container, repo) = monter();
    container.listen(bookmarkedPostsCountProvider, (_, __) {});
    expect(await container.read(bookmarkedPostsCountProvider.future), 0);

    repo.favoris = {'p1'};
    await container.read(feedNotifierProvider.notifier).toggleBookmark('p1');

    expect(await container.read(bookmarkedPostsCountProvider.future), 1);
  });
}
