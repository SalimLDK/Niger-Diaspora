import 'dart:convert';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_metadonnees.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Charger les messages plus anciens d'une discussion.
///
/// Le curseur d'une page plus ancienne était l'**id** (un uuid) du plus ancien
/// message affiché, et la source le comparait à une date :
/// `.lt('created_at', '<uuid>')`. Postgres refusait (22007), l'écran affichait
/// une erreur, `hasMore` restait vrai — et l'échec se rejouait à chaque
/// défilement. Au-delà de 30 messages, l'historique était inaccessible.
///
/// Le curseur est désormais le couple `(created_at, id)` : la date seule perd
/// les ex-aequo d'une page à l'autre, l'id seul ne se compare à rien.
///
/// Et une fois la pagination réparée, un second défaut devenait visible :
/// chaque page plus ancienne repassait par la fusion MLS, qui rend **tout** le
/// fil chiffré — ajouté une fois de plus en tête de l'écran à chaque page.
void main() {
  group('la requête de la source', () {
    late List<http.Request> requetes;
    late MessageSupabaseDataSource source;

    setUp(() {
      requetes = [];
      final client = MockClient((requete) async {
        requetes.add(requete);
        return http.Response(
          jsonEncode(const <Object>[]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: requete,
        );
      });
      source = MessageSupabaseDataSource(
        client: SupabaseClient(
          'http://supabase.test',
          'cle-anon-de-test',
          httpClient: client,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        ensureReadableAuth: () async => true,
      );
    });

    Map<String, List<String>> parametres() {
      final lectures = requetes
          .where((r) => r.url.path.endsWith('/rest/v1/messages'))
          .toList();
      expect(lectures, hasLength(1));
      return lectures.single.url.queryParametersAll;
    }

    test('première page : ni curseur, tri par date puis id', () async {
      await source.getMessagesPaginated(conversationId: 'c1', limit: 31);

      final p = parametres();
      expect(p['conversation_id'], ['eq.c1']);
      expect(p.containsKey('or'), isFalse);
      expect(p.containsKey('created_at'), isFalse);
      expect(p['order'], ['created_at.desc.nullslast,id.desc.nullslast']);
      expect(p['limit'], ['32']);
    });

    test('page plus ancienne : le couple (date, id), jamais l\'id comme date',
        () async {
      final quand = DateTime.utc(2026, 9, 20, 14, 3, 7, 123, 456);
      await source.getMessagesPaginated(
        conversationId: 'c1',
        limit: 31,
        lastMessageKey: '6f1c2b8e-0000-4000-8000-000000000001',
        beforeCreatedAt: quand,
      );

      final p = parametres();
      expect(p['or'], [
        '(created_at.lt."2026-09-20T14:03:07.123456Z",'
            'and(created_at.eq."2026-09-20T14:03:07.123456Z",'
            'id.lt."6f1c2b8e-0000-4000-8000-000000000001"))',
      ]);
      // L'ancien filtre : un uuid passé pour une date.
      expect(p['created_at'], isNull);
    });

    test('un id sans sa date est refusé avant toute requête', () async {
      await expectLater(
        source.getMessagesPaginated(
          conversationId: 'c1',
          limit: 31,
          lastMessageKey: '6f1c2b8e-0000-4000-8000-000000000001',
        ),
        throwsArgumentError,
      );
      expect(requetes, isEmpty);
    });

    test('l\'arrivée du membre filtre dans la requête, pas après la limite',
        () async {
      await source.getMessagesPaginated(
        conversationId: 'c1',
        limit: 31,
        filterAfterDate: DateTime.utc(2026, 9, 1),
      );

      expect(parametres()['created_at'], ['gt.2026-09-01T00:00:00.000Z']);
    });
  });

  group('le repository', () {
    final t0 = DateTime.utc(2026, 9, 1, 8);
    MessageModel m(String id, int minute) => MessageModel(
          id: id,
          senderId: 'u2',
          senderName: 'Amina',
          content: 'message $id',
          createdAt: t0.add(Duration(minutes: minute)),
        );

    test('transmet le curseur complet à la source', () async {
      final source = _SourceEspion([m('a', 1), m('b', 2)]);
      final depot = _depot(source, _PasserelleEspion());
      final quand = t0.add(const Duration(minutes: 3));

      await depot.getMessagesPaginated(
        conversationId: 'c1',
        limit: 30,
        beforeMessageId: 'c',
        beforeCreatedAt: quand,
      );

      expect(source.cle, 'c');
      expect(source.avant, quand);
    });

    test('rend en curseur le plus ancien message de la page', () async {
      final source = _SourceEspion([m('a', 1), m('b', 2)]);
      final page = await _depot(source, _PasserelleEspion())
          .getMessagesPaginated(conversationId: 'c1', limit: 30);

      final p = page.getOrElse(() => throw StateError('échec'));
      expect(p.lastMessageId, 'a');
      expect(p.oldestMessageTimestamp, t0.add(const Duration(minutes: 1)));
    });

    test('première page : le fil MLS est fusionné', () async {
      final passerelle = _PasserelleEspion();
      await _depot(_SourceEspion([m('a', 1)]), passerelle)
          .getMessagesPaginated(conversationId: 'c1', limit: 30);

      expect(passerelle.consultations, 1);
    });

    test('page plus ancienne : pas de seconde fusion du fil MLS', () async {
      final passerelle = _PasserelleEspion();
      await _depot(_SourceEspion([m('a', 1)]), passerelle).getMessagesPaginated(
        conversationId: 'c1',
        limit: 30,
        beforeMessageId: 'b',
        beforeCreatedAt: t0.add(const Duration(minutes: 2)),
      );

      expect(passerelle.consultations, 0,
          reason: 'le fil chiffré est postérieur à tout l\'historique legacy');
    });
  });
}

class _SourceEspion implements MessageRemoteDataSource {
  _SourceEspion(this.page);

  final List<MessageModel> page;
  Object? cle;
  DateTime? avant;

  @override
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? beforeCreatedAt,
    DateTime? filterAfterDate,
  }) async {
    cle = lastMessageKey;
    avant = beforeCreatedAt;
    return (page, null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) =>
      const [];

  @override
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: (() async => true));
}

/// Compte les entrées dans la fusion : `enMls` est sa première question.
class _PasserelleEspion extends MlsGateway {
  _PasserelleEspion()
      : super(
          userId: 'u1',
          actif: () => false,
          service: MlsConversationService(
            userId: 'u1',
            moteur: () => throw StateError('inutile ici'),
            delivery: _Transport(),
            appareil: () => throw StateError('inutile ici'),
          ),
          delivery: _Transport(),
          metadonnees: MlsMetadonnees(userId: 'u1', ensureAuth: () async => true),
        );

  int consultations = 0;

  @override
  Future<bool> enMls(String conversationId) async {
    consultations++;
    return false;
  }
}

MessageRepositoryImpl _depot(
  MessageRemoteDataSource source,
  MlsGateway passerelle,
) =>
    MessageRepositoryImpl(
      remoteDataSource: source,
      networkInfo: _Reseau(),
      cacheService: _Cache(),
      mlsGateway: passerelle,
    );
