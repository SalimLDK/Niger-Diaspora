import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/profile/data/datasources/profile_supabase_datasource.dart';

/// Une écriture de réglage qui ne touche **aucune ligne** n'est pas une
/// écriture.
///
/// PostgREST rend 200 sur un `UPDATE` qui ne matche rien — RLS qui cache la
/// ligne, ou ligne pas encore créée. `_requireAuth` n'écarte que la cause
/// « pas de session » (voir `profile_supabase_datasource_test.dart`). Sans le
/// contrôle du nombre de lignes, `NotificationPreferencesNotifier` prenait ce
/// faux succès pour une écriture faite : local et serveur divergeaient, et le
/// back-end continuait d'envoyer.
///
/// Un vrai `SupabaseClient` branché sur un `MockClient` : ce banc mesure ce que
/// le client fait de la réponse, il ne le suppose pas.
void main() {
  /// Requêtes reçues, pour vérifier ce qui part réellement.
  late List<http.Request> recues;

  /// Le corps que le « serveur » renvoie.
  late String corpsReponse;

  ProfileSupabaseDataSource source() {
    recues = [];
    final client = SupabaseClient(
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
    return ProfileSupabaseDataSource(
      supabase: client,
      ensureAuth: () async => true,
    );
  }

  final ecritures = <String, Future<void> Function(ProfileSupabaseDataSource)>{
    'updateNotificationPrefs': (ds) =>
        ds.updateNotificationPrefs('u1', const {'messages': false}),
    'updateNotifyLocalEvents': (ds) => ds.updateNotifyLocalEvents('u1', false),
  };

  ecritures.forEach((nom, appel) {
    group(nom, () {
      test('aucune ligne touchée : lève au lieu de « réussir » à vide',
          () async {
        corpsReponse = '[]';
        final ds = source();

        await expectLater(
          appel(ds),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              contains('aucun compte mis à jour'),
            ),
          ),
        );
        expect(recues, hasLength(1), reason: 'la requête devait bien partir');
      });

      test('une ligne touchée : l\'écriture aboutit', () async {
        corpsReponse = '[{"id":"u1"}]';
        final ds = source();

        await appel(ds);

        expect(recues, hasLength(1));
        expect(recues.single.method, 'PATCH');
        expect(recues.single.url.path, endsWith('/rest/v1/users'));
        expect(recues.single.url.queryParameters['id'], 'eq.u1');
      });
    });
  });

  test('la carte des préférences part telle quelle dans le corps', () async {
    corpsReponse = '[{"id":"u1"}]';
    final ds = source();

    await ds.updateNotificationPrefs('u1', const {
      'messages': false,
      'groups': true,
    });

    final corps = jsonDecode(recues.single.body) as Map<String, dynamic>;
    expect(corps['notification_prefs'], {'messages': false, 'groups': true});
  });
}
