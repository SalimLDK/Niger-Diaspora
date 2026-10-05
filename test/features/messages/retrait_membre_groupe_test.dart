import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Trois gestes de la fiche des membres — « Retirer du groupe », « Nommer
/// admin », « Retirer le rôle d'admin » — passent par une RPC serveur
/// (migration `20260917013200`) au lieu d'écrire les tables depuis le client.
///
/// 1. **Le retrait ne pouvait pas aboutir.** `removeUserFromGroup` commençait
///    par `sendSystemMessage` : un INSERT `sender_id = 'system'` dans
///    `messages`. Le serveur le refuse **partout** — `messages_insert` exige
///    `firebase_uid() = sender_id`, et une conversation basculée refuse même
///    avant, par déclencheur (23514). L'exception remontait avant la mise à
///    jour de `participant_ids` : aucune exclusion n'a jamais abouti, et
///    l'écran disait « Erreur lors du retrait ». Mesuré le 2026-09-17 par
///    `tools/rls_tests/retrait_membre_groupe.sql` : la table `messages` ne
///    contenait pas une seule ligne système. 7b3794f a retiré l'appel ; la RPC
///    rend la notice, écrite côté serveur et seulement hors MLS.
///
/// 2. **Promouvoir et rétrograder ne changeaient rien de visible** : seul
///    `conversations.data.adminIds` était écrit, alors que le badge « admin »
///    de la fiche et `is_group_admin()` lisent `group_members.role`.
///
/// 3. **Exclure quelqu'un absent de `participant_ids` réussissait à vide.**
///
/// Le faux serveur répond comme PostgREST : il refuse l'INSERT système comme
/// la vraie base le refuse. Remettre cet appel fait tomber le premier test.
///
/// Le comportement **serveur** de ces RPC (droits, notice, MLS, les deux
/// listes d'admins) est mesuré par `tools/rls_tests/notices_de_groupe.sql` ;
/// ici on ne vérifie que ce que le client envoie, et ce qu'il fait des
/// réponses.
void main() {
  const conv = 'd41d4ea0-cc03-4f23-9bc2-9b4987989658';
  const admin = 'U64HKfrjM5NwR6HO00XPKo6168z2';
  const membre = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2';

  late List<http.Request> requetes;

  (Object, int) refus(String code, String message) => (
    {'code': code, 'message': message, 'details': null, 'hint': null},
    switch (code) {
      '42501' => 403,
      // PostgREST quand la fonction n'existe pas : la migration n'est pas
      // encore appliquée.
      'PGRST202' => 404,
      _ => 400,
    },
  );

  /// La réponse de PostgREST quand la fonction est absente du schéma.
  final fonctionAbsente = refus(
    'PGRST202',
    'Could not find the function public.exclure_du_groupe',
  );

  /// [rpc] : ce que rend l'appel de fonction (par défaut `true`).
  MessageSupabaseDataSource source({(Object, int)? rpc}) {
    (Object, int) repondre(http.Request requete) {
      final chemin = requete.url.path;
      if (chemin.contains('/rest/v1/rpc/')) return rpc ?? (true, 200);
      if (chemin.endsWith('/rest/v1/messages')) {
        // Ce que répond la base à `sendSystemMessage` sur une conversation
        // basculée.
        return refus(
          '23514',
          "conversation passée au chiffrement de bout en bout : mettez "
              "l'application à jour",
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

  http.Request seulAppelRpc(String nom) {
    final appels = requetes
        .where((r) => r.url.path.endsWith('/rest/v1/rpc/$nom'))
        .toList();
    expect(appels, hasLength(1), reason: 'un seul appel à $nom');
    return appels.single;
  }

  setUp(() => requetes = []);

  group('removeUserFromGroup', () {
    test("le retrait passe par la RPC, et n'écrit jamais dans `messages`", () async {
      await source().removeUserFromGroup(conversationId: conv, userId: membre);

      expect(
        jsonDecode(seulAppelRpc('exclure_du_groupe').body),
        {'p_conversation_id': conv, 'p_user_id': membre},
      );

      expect(
        requetes.where((r) => r.url.path.endsWith('/rest/v1/messages')),
        isEmpty,
        reason: 'un INSERT système est refusé par la base dans toutes les '
            'conversations : sur le chemin du retrait, il l’empêche',
      );
      expect(
        requetes.where((r) => r.method == 'PATCH'),
        isEmpty,
        reason: 'la RPC écrit les tables ; le client ne double pas le travail',
      );
    });

    test('`false` n\'est pas une erreur : la personne n\'était plus là', () async {
      // Double appui, ou un autre administrateur plus rapide. L'état voulu est
      // atteint : annoncer « Erreur lors du retrait » serait faux.
      await expectLater(
        source(rpc: (false, 200))
            .removeUserFromGroup(conversationId: conv, userId: membre),
        completes,
      );
    });

    test("le refus d'un non-administrateur remonte", () async {
      await expectLater(
        source(
          rpc: refus(
            '42501',
            'Seul un administrateur du groupe peut retirer un membre',
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
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('un retrait sur soi-même remonte, il ne retombe pas sur le chemin direct',
        () async {
      // 22023 : « quittez le groupe ». Basculer en repli ici ferait aboutir en
      // silence ce que le serveur vient de refuser.
      await expectLater(
        source(
          rpc: refus('22023', 'pour partir vous-même, quittez le groupe'),
        ).removeUserFromGroup(conversationId: conv, userId: admin),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('quittez le groupe'),
          ),
        ),
      );
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('fonction absente : erreur, plus de repli par écriture directe',
        () async {
      // Le repli relisait `participant_ids` et `data` puis réécrivait les
      // deux : un départ ou une sourdine croisés s'effaçaient. 20260917013200
      // précède 20261004100000, dont l'app dépend déjà.
      await expectLater(
        source(rpc: fonctionAbsente)
            .removeUserFromGroup(conversationId: conv, userId: membre),
        throwsA(isA<ServerException>()),
      );
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
      expect(requetes.where((r) => r.method == 'GET'), isEmpty);
    });
  });

  group('promoteToAdmin / demoteFromAdmin', () {
    test('nommer un admin passe par la RPC', () async {
      await source().promoteToAdmin(conversationId: conv, userId: membre);

      expect(
        jsonDecode(seulAppelRpc('nommer_admin_du_groupe').body),
        {'p_conversation_id': conv, 'p_user_id': membre},
      );
      expect(
        requetes.where((r) => r.method == 'PATCH'),
        isEmpty,
        reason: 'c\'est la RPC qui écrit `adminIds` ET `group_members.role` ; '
            'le client n\'écrivait que le premier, donc rien de visible',
      );
    });

    test('rétrograder passe par la RPC', () async {
      await source().demoteFromAdmin(conversationId: conv, userId: membre);

      expect(
        jsonDecode(seulAppelRpc('retirer_admin_du_groupe').body),
        {'p_conversation_id': conv, 'p_user_id': membre},
      );
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('le refus du serveur remonte au lieu de retomber sur le chemin direct',
        () async {
      // Le chemin direct aurait écrit `adminIds` sans droit ; RLS l'aurait
      // refusé, mais après avoir laissé croire que la promotion partait.
      await expectLater(
        source(
          rpc: refus(
            '42501',
            'Seul un administrateur du groupe peut modifier les droits admin',
          ),
        ).promoteToAdmin(conversationId: conv, userId: membre),
        throwsA(isA<ServerException>()),
      );
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('fonction absente : erreur, plus de repli sur `data.adminIds`',
        () async {
      // Le repli n'écrivait que `adminIds` (ni badge, ni `is_group_admin()`),
      // en « lire, modifier, réécrire » — une écriture croisée s'effaçait.
      // 20260917013200 précède 20261004100000, dont l'app dépend déjà :
      // l'absence de la fonction n'est plus une étape de déploiement.
      for (final geste in [
        () => source(rpc: fonctionAbsente)
            .promoteToAdmin(conversationId: conv, userId: membre),
        () => source(rpc: fonctionAbsente)
            .demoteFromAdmin(conversationId: conv, userId: membre),
      ]) {
        await expectLater(geste(), throwsA(isA<ServerException>()));
      }
      expect(requetes.where((r) => r.method == 'PATCH'), isEmpty);
      expect(requetes.where((r) => r.method == 'GET'), isEmpty);
    });
  });
}
