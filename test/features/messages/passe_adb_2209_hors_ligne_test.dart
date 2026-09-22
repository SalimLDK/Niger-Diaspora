// Trois défauts vus sur SM A515F le 2026-09-22 (build Play 1.2.2+26), voir
// TESTS_APPAREIL_A_FAIRE.md : « Une réaction retirée disparaît vraiment de
// l'écran » et « « Modifier le message » : saisie en ligne… ».
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';

class _Source implements MessageRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  final Map<String, Map<String, Map<String, dynamic>>> parConversation = {};

  @override
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final fil = parConversation.putIfAbsent(conversationId, () => {});
    for (final m in messages) {
      fil[m['id'] as String] = m;
    }
  }

  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) => [...?parConversation[conversationId]?.values];

  Map<String, dynamic> message(String id) => parConversation['c1']![id]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Passerelle implements MlsGateway {
  bool etoile = false;
  Object? echecModification;

  @override
  bool get actif => true;

  @override
  Future<bool> estMlsMessage(String conversationId, String messageId) async =>
      true;

  @override
  Future<void> reagir(String messageId, String emoji) async {}

  @override
  Future<void> retirerReaction(String messageId) async {}

  @override
  Future<bool> basculerEtoile(String messageId) async => etoile = !etoile;

  @override
  Future<void> modifier({
    required String conversationId,
    required String messageId,
    required String nouveauTexte,
  }) async {
    if (echecModification != null) throw echecModification!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  bool connecte = true;

  @override
  Future<bool> get isConnected async => connecte;
}

void main() {
  late _Cache cache;
  late _Passerelle passerelle;
  late _Reseau reseau;
  late MessageRepositoryImpl depot;

  setUp(() async {
    cache = _Cache();
    await cache.cacheMessages('c1', [
      {
        'id': 'ph1',
        'senderId': 'salim',
        'content': 'PH1',
        'type': 'text',
        'createdAt': '2026-09-21T20:04:00.000Z',
        'reactions': {'sim': '❤️'},
      },
      {
        'id': 'pk1',
        'senderId': 'salim',
        'content': 'PK1',
        'type': 'text',
        'createdAt': '2026-09-21T20:13:00.000Z',
      },
    ]);
    passerelle = _Passerelle();
    reseau = _Reseau();
    depot = MessageRepositoryImpl(
      remoteDataSource: _Source(),
      networkInfo: reseau,
      cacheService: cache,
      mlsGateway: passerelle,
    );
  });

  group('Réactions et étoiles : le cache suit le serveur', () {
    test('retirer une réaction l\'enlève du cache', () async {
      final r = await depot.toggleReaction(
        conversationId: 'c1',
        messageId: 'ph1',
        userId: 'sim',
        emoji: '❤️',
        retirer: true,
      );
      expect(r.isRight(), isTrue);
      // C'était le ❤️ revenu à l'écran hors ligne.
      expect(cache.message('ph1').containsKey('reactions'), isFalse);
    });

    test('poser une réaction l\'écrit dans le cache, sans toucher aux autres',
        () async {
      await cache.cacheMessages('c1', [
        {...cache.message('pk1'), 'reactions': {'salim': '😂'}},
      ]);
      await depot.toggleReaction(
        conversationId: 'c1',
        messageId: 'pk1',
        userId: 'sim',
        emoji: '👍',
        retirer: false,
      );
      expect(cache.message('pk1')['reactions'], {'salim': '😂', 'sim': '👍'});
    });

    test('étoiler puis retirer suit l\'état rendu par le serveur', () async {
      await depot.toggleStarMessage(
        conversationId: 'c1',
        messageId: 'pk1',
        userId: 'sim',
      );
      expect(cache.message('pk1')['starredBy'], ['sim']);
      await depot.toggleStarMessage(
        conversationId: 'c1',
        messageId: 'pk1',
        userId: 'sim',
      );
      expect(cache.message('pk1').containsKey('starredBy'), isFalse);
    });

    test('un message absent du cache n\'y est pas créé', () async {
      await depot.toggleReaction(
        conversationId: 'c1',
        messageId: 'inconnu',
        userId: 'sim',
        emoji: '👍',
        retirer: false,
      );
      expect(cache.parConversation['c1']!.containsKey('inconnu'), isFalse);
    });
  });

  group('Modifier hors ligne : une coupure se dit coupure', () {
    test('le VPN seul n\'est pas une connexion', () {
      // Mode avion sur le SM A515F : agent VPN « CONNECTED », rien dessous.
      expect(estConnecte([ConnectivityResult.vpn]), isFalse);
      expect(estConnecte([ConnectivityResult.none]), isFalse);
      // En service, le VPN porte son transport.
      expect(
        estConnecte([ConnectivityResult.wifi, ConnectivityResult.vpn]),
        isTrue,
      );
      expect(estConnecte([ConnectivityResult.mobile]), isTrue);
      expect(estConnecte([ConnectivityResult.ethernet]), isTrue);
    });

    test('une panne réseau pendant la modification rend une NetworkFailure',
        () async {
      passerelle.echecModification =
          const SocketException('Failed host lookup: zyrfkcjjrhddpfxcgezo.supabase.co');
      final r = await depot.editMessage(
        conversationId: 'c1',
        messageId: 'pk1',
        newContent: 'PK1 bis',
        oldContent: 'PK1',
      );
      r.fold(
        (echec) => expect(echec, isA<NetworkFailure>(),
            reason: 'avant : « Une erreur inattendue s\'est produite »'),
        (_) => fail('la modification ne devait pas réussir'),
      );
    });

    test('une vraie erreur reste « inattendue »', () async {
      passerelle.echecModification = StateError('autre chose');
      final r = await depot.editMessage(
        conversationId: 'c1',
        messageId: 'pk1',
        newContent: 'PK1 bis',
        oldContent: 'PK1',
      );
      r.fold(
        (echec) => expect(echec, isNot(isA<NetworkFailure>())),
        (_) => fail('la modification ne devait pas réussir'),
      );
    });
  });

  test('« Infos du message » formate ses dates dans la langue de l\'app', () {
    final src = File(
      'lib/features/messages/presentation/widgets/message_info_sheet.dart',
    ).readAsStringSync();
    // Sans locale, intl écrivait « Sep 22, 2026 » à un usager francophone.
    expect(RegExp(r'DateFormat\.yMMMd\(\)').hasMatch(src), isFalse);
    expect(RegExp(r'DateFormat\.yMMMd\((locale|l10n\.localeName)\)')
        .allMatches(src)
        .length, 2);
  });
}
