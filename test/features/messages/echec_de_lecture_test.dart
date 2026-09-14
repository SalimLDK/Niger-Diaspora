import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/conversation_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/domain/repositories/message_repository.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';

/// Un échec de lecture doit se voir, et ne pas se faire passer pour autre chose.
///
/// Les trois flux de `MessageRepositoryImpl` se terminaient par un
/// `.handleError((error) { return Left(...); })`. Dart **ignore la valeur de
/// retour** de `handleError` : ce `Left` n'était jamais émis, l'erreur était
/// avalée, et le flux ne rendait plus rien du tout. Mesuré sur SM A515F le
/// 2026-09-14 : liste des discussions sur un rond de chargement sans fin après
/// un démarrage hors ligne, sans erreur ni réessai.
///
/// L'autre moitié du piège est côté provider : plier l'échec en `null` ferait
/// dire « Conversation supprimée » à l'écran sur une simple coupure.
class _SourceQuiEchoue implements MessageRemoteDataSource {
  @override
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    return Stream<ConversationModel?>.error(Exception('hors ligne'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxCache implements CacheService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxReseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DepotQuiEchoue implements MessageRepository {
  /// Rien en cache : sans ça, le provider servirait la copie locale et
  /// l'erreur ne serait jamais observée.
  @override
  Either<Failure, List<ConversationEntity>> getCachedConversations() =>
      const Right(<ConversationEntity>[]);

  @override
  Stream<Either<Failure, ConversationEntity?>> getConversationStream(
    String conversationId,
  ) {
    return Stream.value(
      Left<Failure, ConversationEntity?>(ServerFailure('hors ligne')),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le cas du démarrage à froid hors ligne : la lecture réseau échoue, mais la
/// conversation est déjà sur le disque.
class _DepotAvecCache implements MessageRepository {
  @override
  Either<Failure, List<ConversationEntity>> getCachedConversations() => Right([
    ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['moi', 'lautre'],
      createdAt: DateTime(2026, 1, 1),
      createdBy: 'moi',
    ),
  ]);

  @override
  Stream<Either<Failure, ConversationEntity?>> getConversationStream(
    String conversationId,
  ) {
    return Stream.value(
      Left<Failure, ConversationEntity?>(ServerFailure('hors ligne')),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('une erreur du flux ressort en Left, au lieu d\'être avalée', () async {
    final depot = MessageRepositoryImpl(
      remoteDataSource: _SourceQuiEchoue(),
      networkInfo: _FauxReseau(),
      cacheService: _FauxCache(),
    );

    final recu = await depot.getConversationStream('c1').first.timeout(
      const Duration(seconds: 2),
    );

    expect(recu.isLeft(), isTrue);
  });

  test('un échec de lecture est une erreur, jamais « supprimée »', () async {
    final container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(_DepotQuiEchoue()),
      ],
    );
    addTearDown(container.dispose);

    final flux = container.listen(
      conversationStreamProvider('c1'),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(conversationStreamProvider('c1').future).then(
      (_) => null,
      onError: (_) => null,
    );

    final etat = flux.read();
    expect(etat.hasError, isTrue);
    // Le piège : `null` ici, c'est « conversation supprimée » à l'écran.
    expect(etat.hasValue, isFalse);
  });

  test('hors ligne, la conversation en cache est servie avant le réseau', () async {
    final container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(_DepotAvecCache()),
      ],
    );
    addTearDown(container.dispose);

    container.listen(conversationStreamProvider('c1'), (_, __) {},
        fireImmediately: true);
    await Future<void>.delayed(Duration.zero);

    // Sans elle, l'écran ne sait pas qui est en face : l'identifiant de
    // l'autre participant se déduit de la conversation.
    final etat = container.read(conversationStreamProvider('c1'));
    expect(etat.valueOrNull?.id, 'c1');
  });
}
