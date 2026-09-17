import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Exclure un membre d'un groupe (fiche des membres → « Retirer du groupe »)
/// passait par `removeUserFromGroup`, qui commençait par `sendSystemMessage` :
/// un INSERT `sender_id = 'system'` dans `messages`. Le serveur le refuse
/// **partout** — la policy `messages_insert` exige `firebase_uid() =
/// sender_id`, et une conversation basculée en MLS refuse même avant, par
/// déclencheur (23514). L'exception remontait avant la mise à jour de
/// `participant_ids` : aucune exclusion n'a jamais abouti, et l'écran disait
/// « Erreur lors du retrait ». Mesuré en base le 2026-09-17 par
/// `tools/rls_tests/retrait_membre_groupe.sql` : la table `messages` ne
/// contenait pas une seule ligne système.
///
/// Le faux serveur ci-dessous répond comme PostgREST en production : il
/// refuse l'INSERT système comme la vraie base le refuse. Remettre l'appel,
/// avant ou après le retrait, fait tomber le premier test.
void main() {
  const conv = 'd41d4ea0-cc03-4f23-9bc2-9b4987989658';
  const admin = 'U64HKfrjM5NwR6HO00XPKo6168z2';
  const membre = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2';

  late List<http.Request> requetes;

  (Object, int) refus(String code, String message) =>
      ({'code': code, 'message': message, 'details': null, 'hint': null},
          code == '42501' ? 403 : 400);

  /// [lignesConversation] : ce que rend la lecture de la conversation.
  /// [miseAJour] : ce que rend le PATCH (lignes modifiées, ou un refus).
  MessageSupabaseDataSource source({
    List<Map<String, dynamic>>? lignesConversation,
    (Object, int)? miseAJour,
  }) {
    (Object, int) repondre(http.Request requete) {
      final chemin = requete.url.path;
      if (chemin.endsWith('/rest/v1/messages')) {
        // Ce que répond la base à `sendSystemMessage` sur une conversation
        // basculée.
        return refus(
          '23514',
          "conversation passée au chiffrement de bout en bout : mettez "
              "l'application à jour",
        );
      }
      if (chemin.endsWith('/rest/v1/conversations') &&
          requete.method == 'GET') {
        return (
          lignesConversation ??
              [
                {
                  'participant_ids': [admin, membre],
                  'data': {
                    'adminIds': [admin, membre],
                    'name': 'Groupe',
                  },
                },
              ],
          200,
        );
      }
      if (chemin.endsWith('/rest/v1/conversations') &&
          requete.method == 'PATCH') {
        return miseAJour ??
            (
              [
                {'id': conv},
              ],
              200,
            );
      }
      return ({'message': 'inattendu : ${requete.method} $chemin'}, 500);
    }

    final client = MockClient((requete) async {
      requetes.add(requete);
      final (corps, statut) = repondre(requete);
      // postgrest lit `response.request!.method` : sans la requête rattachée,
      // toute réponse lève « Null check operator » — et les tests d'échec
      // passeraient pour cette mauvaise raison.
      return http.Response(
        jsonEncode(corps),
        statut,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: requete,
      );
    });

    return MessageSupabaseDataSource(
      client: SupabaseClient(
        'http://supabase.test',
        'cle-anon-de-test',
        httpClient: client,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
  }

  setUp(() => requetes = []);

  group('removeUserFromGroup', () {
    test("le retrait n'écrit jamais dans `messages`, et il a lieu", () async {
      await source().removeUserFromGroup(conversationId: conv, userId: membre);

      expect(
        requetes.where((r) => r.url.path.endsWith('/rest/v1/messages')),
        isEmpty,
        reason: 'un INSERT système est refusé par la base dans toutes les '
            'conversations : sur le chemin du retrait, il l’empêche',
      );

      final patchs = requetes.where((r) => r.method == 'PATCH').toList();
      expect(patchs, hasLength(1));
      expect(patchs.single.url.path, endsWith('/rest/v1/conversations'));
      expect(patchs.single.url.queryParameters['id'], 'eq.$conv');

      final corps = jsonDecode(patchs.single.body) as Map<String, dynamic>;
      expect(corps['participant_ids'], [admin]);
      final data = corps['data'] as Map<String, dynamic>;
      expect(data['adminIds'], [admin]);
      expect(data['name'], 'Groupe', reason: 'le reste de `data` est conservé');
    });

    test('une mise à jour qui ne touche aucune ligne est un échec', () async {
      // RLS qui filtre la ligne : PostgREST répond 200 avec un tableau vide.
      // L'écran aurait annoncé « Membre retiré » pour un retrait qui n'a pas
      // eu lieu.
      await expectLater(
        source(miseAJour: (<Object>[], 200))
            .removeUserFromGroup(conversationId: conv, userId: membre),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('aucune ligne modifiée'),
          ),
        ),
      );
    });

    test('une conversation illisible est un échec, pas un succès muet',
        () async {
      await expectLater(
        source(lignesConversation: const [])
            .removeUserFromGroup(conversationId: conv, userId: membre),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('introuvable'),
          ),
        ),
      );
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test("le refus d'un non-administrateur remonte", () async {
      // `conversations_guard_admin_fields` : 42501.
      await expectLater(
        source(
          miseAJour: refus(
            '42501',
            'Seul un administrateur du groupe peut modifier les membres ou '
                'les droits admin de cette conversation',
          ),
        ).removeUserFromGroup(conversationId: conv, userId: membre),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Seul un administrateur'),
          ),
        ),
      );
    });
  });
}
