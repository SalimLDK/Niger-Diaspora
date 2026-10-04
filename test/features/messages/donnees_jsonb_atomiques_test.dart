import 'dart:convert';

import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les écritures dans `data` passent par une fonction serveur, en une
/// requête.
///
/// Le client lisait `data` entier, le modifiait en mémoire, puis le
/// réécrivait : toute écriture arrivée entre les deux était effacée (une
/// sourdine, un « Lu », un incrément de pastille — mesuré : 8 sur 30 pour
/// 40 envois simultanés). Les fonctions de 20261004100000 font la
/// modification DANS l'UPDATE ; leur sens est tenu par
/// tools/rls_tests/donnees_jsonb_atomiques.sql. Ici : que le client n'a plus
/// de fenêtre — aucune lecture de `data` avant l'écriture.
void main() {
  late List<http.Request> requetes;
  late MessageSupabaseDataSource source;

  setUp(() {
    requetes = [];
    final client = MockClient((requete) async {
      requetes.add(requete);
      return http.Response(
        jsonEncode(true),
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

  (String, Map<String, dynamic>) seulAppel() {
    expect(requetes, hasLength(1),
        reason: 'une requête, pas « lire puis réécrire »');
    final r = requetes.single;
    expect(r.method, 'POST');
    return (
      r.url.path.split('/').last,
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  }

  test('sourdine : fusion profonde côté serveur', () async {
    await source.muteConversation(conversationId: 'c1', userId: 'u1');

    final (fn, corps) = seulAppel();
    expect(fn, 'fusionner_donnees_conversation');
    expect(corps['p_conversation_id'], 'c1');
    expect(corps['p_profond'], isTrue);
    expect(corps['p_partiel'], {
      'mutedBy': {'u1': 'forever'},
    });
  });

  test('fin de sourdine : retrait de la sous-clé côté serveur', () async {
    await source.unmuteConversation(conversationId: 'c1', userId: 'u1');

    final (fn, corps) = seulAppel();
    expect(fn, 'retirer_cle_donnees_conversation');
    expect(corps, {
      'p_conversation_id': 'c1',
      'p_parent': 'mutedBy',
      'p_enfant': 'u1',
    });
  });

  test('signalement : ajout à la liste côté serveur', () async {
    try {
      await source.reportMessage(
        conversationId: 'c1',
        messageId: 'm1',
        userId: 'u1',
        reason: 'spam',
      );
    } catch (_) {
      // Une éventuelle écriture annexe (table des signalements) ne
      // concerne pas ce banc.
    }

    final appel = requetes.firstWhere(
      (r) => r.url.path.endsWith('/rpc/fusionner_donnees_message'),
    );
    expect(jsonDecode(appel.body), {
      'p_message_id': 'm1',
      'p_partiel': {'reportedBy': 'u1'},
      'p_ajout_liste': true,
    });
    expect(
      requetes.where((r) =>
          r.method == 'GET' && r.url.path.endsWith('/rest/v1/messages')),
      isEmpty,
      reason: 'plus de lecture de data avant l\'écriture',
    );
  });

  test('étoile : bascule côté serveur', () async {
    await source.toggleStarMessage(
      conversationId: 'c1',
      messageId: 'm1',
      userId: 'u1',
    );

    final (fn, corps) = seulAppel();
    expect(fn, 'basculer_dans_liste_message');
    expect(corps, {
      'p_message_id': 'm1',
      'p_cle': 'starredBy',
      'p_valeur': 'u1',
    });
  });
}
