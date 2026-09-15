import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce test protège (plan MLS § 6.3, ligne « Recherche »)
/// -----------------------------------------------------------
/// Le serveur ne détient qu'un ciphertext : son `ilike` sur le contenu d'une
/// conversation basculée ne trouve **rien**, et ne lève pas. La recherche
/// rendait donc une liste vide en annonçant un succès — l'échec muet que ce
/// chantier traque depuis le début.
///
/// Le clair n'existe que sur l'appareil, dans le cache Hive : la recherche
/// d'une conversation chiffrée doit l'interroger. Elle garde en même temps le
/// résultat du serveur, parce qu'au-dessus du séparateur de bascule
/// l'historique est resté en clair et que lui seul le couvre en entier.
///
/// Ce que le test empêche, concrètement : qu'on croie la recherche réparée
/// alors qu'elle ignore le cache, qu'elle perde l'historique d'avant la
/// bascule, ou qu'elle rende deux fois le même message quand les deux sources
/// le portent.

MessageModel _m(String id, String contenu, DateTime quand) => MessageModel(
      id: id,
      senderId: 'u2',
      senderName: 'Amina',
      content: contenu,
      createdAt: quand,
    );

class _SourceAvecHistorique implements MessageRemoteDataSource {
  _SourceAvecHistorique(this.resultats);

  final List<MessageModel> resultats;
  int appels = 0;

  @override
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  }) async {
    appels++;
    return resultats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CacheAvecFil implements CacheService {
  _CacheAvecFil(this.messages);

  final List<MessageModel> messages;

  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) =>
      [for (final m in messages) m.toJson()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le transport, sans réseau : `conversation()` suffit à dire « basculée ».
class _TransportFige extends MlsDelivery {
  _TransportFige(this.mlsSince) : super(ensureAuth: (() async => true));

  final String? mlsSince;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const <String>[],
        'mls_since': mlsSince,
      };
}

class _ServiceMuet extends MlsConversationService {
  _ServiceMuet()
      : super(
          userId: 'u1',
          moteur: () => throw StateError('le moteur ne doit pas être demandé'),
          delivery: _TransportFige(null),
          appareil: () => throw StateError('inutile ici'),
        );
}

MlsGateway _passerelle({required bool basculee}) => MlsGateway(
      userId: 'u1',
      actif: () => false,
      service: _ServiceMuet(),
      delivery: _TransportFige(basculee ? '2026-09-15T00:00:00Z' : null),
    );

MessageRepositoryImpl _depot({
  required _SourceAvecHistorique source,
  required _CacheAvecFil cache,
  MlsGateway? passerelle,
}) =>
    MessageRepositoryImpl(
      remoteDataSource: source,
      networkInfo: _Reseau(),
      cacheService: cache,
      mlsGateway: passerelle,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 15, 8);

  group('recherche dans une conversation basculée', () {
    test('le cache local fournit ce que le serveur ne peut pas lire', () async {
      // Le serveur ne rend rien : le contenu est chiffré chez lui.
      final source = _SourceAvecHistorique([]);
      final cache = _CacheAvecFil([
        _m('mls-1', 'rendez-vous à Niamey', t0),
        _m('mls-2', 'autre chose', t0.add(const Duration(minutes: 1))),
      ]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'niamey');

      final trouves = res.getOrElse(() => []);
      expect(trouves.map((m) => m.id), ['mls-1']);
    });

    test("l'historique d'avant la bascule n'est pas perdu", () async {
      // Au-dessus du séparateur, les messages sont restés en clair : seul le
      // serveur les couvre en entier, le cache pouvant être partiel.
      final source = _SourceAvecHistorique([
        _m('legacy-1', 'rendez-vous de mars', t0.subtract(const Duration(days: 30))),
      ]);
      final cache = _CacheAvecFil([_m('mls-1', 'rendez-vous à Niamey', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'rendez-vous');

      final trouves = res.getOrElse(() => []);
      expect(trouves.map((m) => m.id), containsAll(['legacy-1', 'mls-1']));
      // Le plus récent d'abord.
      expect(trouves.first.id, 'mls-1');
    });

    test('un message porté par les deux sources ne sort qu\'une fois', () async {
      final source = _SourceAvecHistorique([_m('x', 'rendez-vous', t0)]);
      final cache = _CacheAvecFil([_m('x', 'rendez-vous', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'rendez');

      expect(res.getOrElse(() => []).length, 1);
    });

    test('la casse est indifférente, comme côté serveur', () async {
      final cache = _CacheAvecFil([_m('mls-1', 'Rendez-Vous à NIAMEY', t0)]);

      final res = await _depot(
        source: _SourceAvecHistorique([]),
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'niamey');

      expect(res.getOrElse(() => []).length, 1);
    });
  });

  group('recherche dans une conversation en clair', () {
    test('rien ne change : le serveur reste seul juge', () async {
      // Sans bascule, le cache ne doit pas s'inviter — il est partiel, et
      // ajouterait des résultats que la pagination serveur n'a pas.
      final source = _SourceAvecHistorique([_m('s-1', 'bonjour', t0)]);
      final cache = _CacheAvecFil([_m('cache-seul', 'bonjour aussi', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: false),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'bonjour');

      expect(res.getOrElse(() => []).map((m) => m.id), ['s-1']);
      expect(source.appels, 1);
    });

    test('sans passerelle du tout, le comportement est celui d\'avant',
        () async {
      final source = _SourceAvecHistorique([_m('s-1', 'bonjour', t0)]);

      final res = await _depot(
        source: source,
        cache: _CacheAvecFil([_m('cache-seul', 'bonjour aussi', t0)]),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'bonjour');

      expect(res.getOrElse(() => []).map((m) => m.id), ['s-1']);
    });
  });
}
