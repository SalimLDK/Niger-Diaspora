import 'dart:convert';

import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deux abonnements au même flux temps réel, en même temps.
///
/// Quatre canaux avaient un nom fixe (`conversations:<user>`,
/// `conversation:<id>`, `msg_requests:<user>`, `mls_new:<id>`). `_channel`
/// rangeant les canaux par nom, le second abonnement récupérait le canal du
/// premier, encore vivant : son `subscribe` levait « tried to subscribe
/// multiple times », et l'`onCancel` du premier désabonnait le canal partagé.
/// Cas réel : la même discussion ouverte deux fois dans la pile de navigation
/// — l'écran du dessus n'avait plus de temps réel chiffré.
void main() {
  late SupabaseClient client;
  late MessageSupabaseDataSource source;

  setUp(() {
    client = SupabaseClient(
      'http://supabase.test',
      'cle-anon-de-test',
      httpClient: MockClient((r) async => http.Response(
            jsonEncode(const <Object>[]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: r,
          )),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    source = MessageSupabaseDataSource(
      client: client,
      ensureReadableAuth: () async => true,
    );
  });

  tearDown(() async {
    await client.removeAllChannels();
    await client.dispose();
  });

  final flux = <String, Stream<Object?> Function()>{
    'liste des discussions': () => source.getConversations('u1'),
    'une discussion': () => source.getConversationStream('c1'),
    'demandes de message': () => source.getMessageRequests('u1'),
    'messages chiffrés': () => source.mlsNouveauxMessages('c1'),
    'nouveaux messages': () =>
        source.getNewMessagesStream(conversationId: 'c1', afterTimestamp: DateTime(2026)),
    'mises à jour': () => source.getMessageUpdatesStream(conversationId: 'c1'),
  };

  for (final MapEntry(key: nom, value: ouvrir) in flux.entries) {
    test('$nom : deux abonnements, deux canaux, aucun ne lève', () async {
      final a = ouvrir().listen((_) {}, onError: (_) {});
      final b = ouvrir().listen((_) {}, onError: (_) {});
      expect(client.getChannels(), hasLength(2));

      // Le premier s'en va : le canal du second reste.
      await a.cancel();
      expect(client.getChannels(), hasLength(1));
      await b.cancel();
    });
  }
}
