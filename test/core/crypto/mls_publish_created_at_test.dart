import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce que ces tests protègent
/// --------------------------
/// `publishMessage` ne se contente plus d'insérer : il relit `created_at` dans
/// la même requête, parce que `toInsert` ne l'envoie pas et que le serveur
/// date la ligne lui-même. Deux choses comptent sur cette valeur — l'échéance
/// des messages éphémères et l'aperçu de la liste (voir
/// `mls_horodatage_envoi_test.dart`).
///
/// Le RLS de cette relecture a été prouvé côté base (rôle `authenticated`,
/// `INSERT … RETURNING` accepté). **Ce que la base ne dit pas**, c'est si le
/// client Dart demande vraiment la relecture et sait parser la réponse : le
/// `Prefer: return=representation` que `.select()` doit poser, le
/// `select=created_at` dans l'URL, et le tableau JSON qui revient. C'est ce
/// que ces tests tiennent, contre un vrai PostgREST de façade.
///
/// Ils tiennent aussi le repli : serveur muet → `null`, et l'appelant garde
/// son heure locale. Un envoi ne doit jamais échouer parce que la relecture
/// n'a rien donné.
void main() {
  late HttpServer serveur;
  late SupabaseClient client;

  /// Ce que la façade a reçu au dernier appel.
  String? methode;
  String? chemin;
  String? requete;
  String? prefer;
  Object? corps;

  /// Ce que la façade répondra.
  late int statut;
  late String reponse;

  setUp(() async {
    methode = chemin = requete = prefer = null;
    corps = null;
    statut = 201;
    reponse = '[{"created_at":"2026-09-16T02:59:01.602934+00:00"}]';

    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serveur.listen((HttpRequest r) async {
      methode = r.method;
      chemin = r.uri.path;
      requete = r.uri.query;
      prefer = r.headers.value('prefer');
      final brut = await utf8.decoder.bind(r).join();
      corps = brut.isEmpty ? null : jsonDecode(brut);
      r.response
        ..statusCode = statut
        ..headers.contentType = ContentType.json
        ..write(reponse);
      await r.response.close();
    });

    client = SupabaseClient('http://127.0.0.1:${serveur.port}', 'cle-de-facade');
  });

  tearDown(() async {
    await client.dispose();
    await serveur.close(force: true);
  });

  MlsDelivery livraison() => MlsDelivery(
    client: client,
    // Le pont Firebase→Supabase n'a rien à faire ici : ce qu'on teste est en
    // aval de la session.
    ensureAuth: () async => true,
  );

  MlsMessageRow ligne() => MlsMessageRow(
    id: 'm-1',
    conversationId: 'c-1',
    senderId: 'u-1',
    senderDeviceId: 'd-1',
    epoch: 7,
    kind: 'content',
    contentType: 'text',
    ciphertext: Uint8List.fromList(const [9, 8, 7]),
    createdAt: DateTime.utc(2026, 9, 16, 2, 58),
  );

  test('la relecture est bien demandée, et sur la seule colonne utile', () async {
    await livraison().publishMessage(ligne());

    expect(methode, 'POST');
    expect(chemin, '/rest/v1/mls_messages');
    // Sans ce `Prefer`, PostgREST répond 201 avec un corps vide : la relecture
    // ne coûterait rien et ne rendrait rien.
    expect(prefer, contains('return=representation'));
    expect(requete, contains('select=created_at'));
  });

  test("l'insertion n'envoie toujours pas created_at", () async {
    // C'est la prémisse de toute la correction : la colonne a son défaut
    // serveur. Si le client se remettait à la poser, il redeviendrait maître
    // d'un horodatage qu'il ne doit pas choisir.
    await livraison().publishMessage(ligne());

    // `insert` d'une seule ligne envoie l'objet nu, pas un tableau.
    final envoye = corps as Map<String, dynamic>;
    expect(envoye.containsKey('created_at'), isFalse);
    expect(envoye['id'], 'm-1');
    expect(envoye['epoch'], 7);
  });

  test("l'horodatage du serveur est rendu, en UTC", () async {
    final quand = await livraison().publishMessage(ligne());

    expect(quand, isNotNull);
    expect(quand!.isUtc, isTrue);
    expect(quand, DateTime.utc(2026, 9, 16, 2, 59, 1, 602, 934));
  });

  test('un fuseau non-UTC dans la réponse est ramené en UTC', () async {
    // PostgREST rend l'horodatage dans le fuseau de la session ; la valeur
    // doit être comparable à celle d'un message reçu, qui est en UTC.
    reponse = '[{"created_at":"2026-09-16T04:59:01.602934+02:00"}]';

    final quand = await livraison().publishMessage(ligne());

    expect(quand, DateTime.utc(2026, 9, 16, 2, 59, 1, 602, 934));
  });

  group('replis — un envoi ne doit jamais échouer sur la relecture', () {
    test('réponse vide : null, et l’appelant garde son heure', () async {
      reponse = '[]';
      expect(await livraison().publishMessage(ligne()), isNull);
    });

    test('colonne absente de la réponse : null', () async {
      reponse = '[{}]';
      expect(await livraison().publishMessage(ligne()), isNull);
    });

    test('horodatage illisible : null, pas une exception', () async {
      reponse = '[{"created_at":"pas une date"}]';
      expect(await livraison().publishMessage(ligne()), isNull);
    });
  });
}
