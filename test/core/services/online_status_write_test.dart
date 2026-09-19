import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/services/online_status_service.dart';

/// Se masquer ne doit pas « réussir » à vide.
///
/// PostgREST rend 200 sur un `UPDATE` qui ne matche aucune ligne — RLS qui
/// cache la ligne, ou ligne pas encore créée. `updateOnlineStatusVisibility`
/// n'écartait que « pas de session » : dans ce cas l'interrupteur gardait la
/// nouvelle valeur, la présence était alignée dessus, et le serveur gardait
/// l'ancienne — un compte qui croyait s'être masqué repartait visible au
/// lancement suivant.
///
/// Même garde et même méthode que `profile_notification_writes_test.dart` :
/// un vrai `SupabaseClient` branché sur un `MockClient`. Le service lui-même
/// tient des singletons Firebase et ne se monte pas en test ; l'écriture, elle,
/// est une fonction statique qui prend le client.
void main() {
  late List<http.Request> recues;
  late String corpsReponse;

  SupabaseClient client() {
    recues = [];
    return SupabaseClient(
      'http://localhost:54321',
      'cle-anon-de-test',
      httpClient: MockClient((request) async {
        recues.add(request);
        return http.Response(
          corpsReponse,
          200,
          // PostgREST lit `response.request!` : `MockClient` rend la réponse du
          // handler telle quelle, il faut donc la lui rattacher.
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  test('aucune ligne touchée : lève au lieu de « réussir » à vide', () async {
    corpsReponse = '[]';

    await expectLater(
      OnlineStatusService.writeShowOnlineStatus(client(), 'u1', false),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('aucun compte mis à jour'),
        ),
      ),
    );
    expect(recues, hasLength(1), reason: 'la requête devait bien partir');
  });

  test('une ligne touchée : l\'écriture aboutit et part telle quelle', () async {
    corpsReponse = '[{"id":"u1"}]';

    await OnlineStatusService.writeShowOnlineStatus(client(), 'u1', false);

    expect(recues, hasLength(1));
    expect(recues.single.method, 'PATCH');
    expect(recues.single.url.path, endsWith('/rest/v1/users'));
    expect(recues.single.url.queryParameters['id'], 'eq.u1');
    expect(
      jsonDecode(recues.single.body),
      {'show_online_status': false},
      reason: 'seule la colonne visée doit partir',
    );
  });
}
