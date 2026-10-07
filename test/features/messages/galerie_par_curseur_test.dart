import 'dart:convert';

import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// La galerie de médias d'une discussion, page après page.
///
/// `getMediaMessages` recevait le curseur `beforeMessageId` et ne s'en
/// servait nulle part : « charger plus » renvoyait les mêmes 50 médias, la
/// galerie les ajoutait en double, et `hasMore` restait vrai — une boucle de
/// doublons à chaque défilement. Le curseur est désormais le couple
/// `(created_at, id)`, comme pour les messages (`filtreAvantCurseur`).
void main() {
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

  test('première page : sans curseur, médias avec URL, tri date puis id',
      () async {
    await source.getMediaMessages(conversationId: 'c1', limit: 50);

    final p = parametres();
    expect(p['conversation_id'], ['eq.c1']);
    expect(p.containsKey('or'), isFalse);
    expect(p['data->>fileUrl'], ['not.is.null'],
        reason: 'filtrer après la limite ferait passer une page amputée '
            'pour la dernière');
    expect(p['order'], ['created_at.desc.nullslast,id.desc.nullslast']);
    expect(p['limit'], ['50']);
  });

  test('page suivante : le couple (date, id) part dans la requête', () async {
    final quand = DateTime.utc(2026, 10, 7, 9, 30, 1, 250);
    await source.getMediaMessages(
      conversationId: 'c1',
      limit: 50,
      beforeMessageId: 'm-42',
      beforeCreatedAt: quand,
    );

    expect(parametres()['or'], ['(${filtreAvantCurseur(quand, 'm-42')})']);
  });

  test('un id sans sa date est refusé avant toute requête', () async {
    await expectLater(
      source.getMediaMessages(conversationId: 'c1', beforeMessageId: 'm-42'),
      throwsArgumentError,
    );
    expect(requetes, isEmpty);
  });
}
