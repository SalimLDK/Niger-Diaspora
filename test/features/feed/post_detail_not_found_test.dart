import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/feed/data/datasources/feed_remote_datasource.dart';
import 'package:diaspo_niger/features/feed/data/models/post_model.dart';
import 'package:diaspo_niger/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/domain/repositories/feed_repository.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_provider.dart';

/// Lien vers une publication qui n'existe plus.
///
/// Constaté sur appareil le 2026-08-04 : ouvrir
/// `https://diasponiger.web.app/feed/<id-inexistant>` laissait
/// `PostDetailScreen` sur ses squelettes de chargement — encore présents après
/// 105 s — sans le moindre message, et avec le champ de commentaire actif sur
/// une publication inexistante.
///
/// Deux causes enchaînées :
///   1. `getPostById` du datasource utilise `.single()`, qui lève une
///      `PostgrestException` PGRST116 quand aucune ligne ne correspond. Le
///      repository n'attrapait que `ServerException` : l'exception s'échappait
///      donc de la couche data, et comme `_load` n'est pas attendu, elle
///      partait en erreur asynchrone non gérée.
///   2. l'état du provider était un simple `PostEntity?`, où `null` voulait
///      dire à la fois « pas encore chargé » et « n'existe pas ».
///
/// Le premier groupe de tests ci-dessous porte sur la cause 1 et **échoue sur
/// l'ancien code** (l'exception traverse le repository au lieu de devenir un
/// `Left`). Le second verrouille le nouvel état.
class _DataSourceIntrouvable implements FeedRemoteDataSource {
  @override
  Future<PostModel> getPostById(String postId) async =>
      throw NotFoundException('Publication introuvable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DataSourceEnPanne implements FeedRemoteDataSource {
  @override
  Future<PostModel> getPostById(String postId) async =>
      throw ServerException('boom');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepoIntrouvable implements FeedRepository {
  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async =>
      Left(NotFoundFailure('Publication introuvable'));

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepoEnPanne implements FeedRepository {
  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async =>
      Left(ServerFailure('reseau'));

  @override
  Stream<PostEntity> watchPostUpdates({String? postId}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Repository — une publication absente devient un Left, pas une exception',
      () {
    test('NotFoundException -> NotFoundFailure', () async {
      final repo = FeedRepositoryImpl(_DataSourceIntrouvable());

      final result = await repo.getPostById('id-inexistant');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('un post inexistant ne doit pas remonter un Right'),
      );
    });

    test('une panne reste distincte de « introuvable »', () async {
      final repo = FeedRepositoryImpl(_DataSourceEnPanne());

      final result = await repo.getPostById('peu-importe');

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure, isNot(isA<NotFoundFailure>()));
        },
        (_) => fail('une panne ne doit pas remonter un Right'),
      );
    });
  });

  group('Provider — « introuvable » ne se confond plus avec « en cours »', () {
    test('etat initial = loading, puis notFound', () async {
      final container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(_RepoIntrouvable())],
      );
      addTearDown(container.dispose);

      expect(
        container.read(postDetailProvider('x')).status,
        PostDetailStatus.loading,
        reason: 'le squelette n\'est legitime que pendant le chargement',
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(postDetailProvider('x'));
      expect(state.status, PostDetailStatus.notFound);
      expect(state.post, isNull);
      expect(state.isLoading, isFalse);
    });

    test('une panne donne failed, pas notFound', () async {
      final container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(_RepoEnPanne())],
      );
      addTearDown(container.dispose);

      // Le provider est paresseux : il faut le lire pour déclencher `build`,
      // sinon l'attente ci-dessous ne laisse rien s'exécuter.
      container.read(postDetailProvider('x'));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(postDetailProvider('x')).status,
        PostDetailStatus.failed,
        reason: 'reessayer a du sens sur une panne, pas sur une suppression',
      );
    });
  });
}
