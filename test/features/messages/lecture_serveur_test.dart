import 'dart:convert';
import 'dart:io';

import 'package:diaspo_niger/features/messages/data/datasources/lecture_serveur.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Les conversations en clair n'avaient que `mark_messages_as_read`, qui marque
/// **toute** la conversation. Depuis que l'écran ne marque plus à l'ouverture
/// (8d81cce), il l'appelait au premier coup d'œil : ce qui restait sous le pli
/// partait « Lu » chez l'expéditeur, et le séparateur « N messages non lus » se
/// calculait sur les seuls messages chargés — faux dès que le premier non-lu
/// est plus haut que la page.
///
/// Deux RPC le remplacent (migration `20260916224700`), éprouvées en base par
/// `tools/rls_tests/lecture_par_curseur.sql` (30 cas). Ce que la base ne dit
/// pas, c'est si le client Dart les appelle correctement et lit ce qui revient.
/// C'est ce que ces tests tiennent, contre un PostgREST de façade.
///
/// Et le point le plus sensible : **distinguer « fonction absente » des autres
/// échecs.** Sur une fonction absente (migration pas encore appliquée),
/// l'écran reprend l'ancien chemin, qui marchait. Sur un refus ou une panne, il
/// ne doit PAS le reprendre : l'ancien chemin marque tout, y compris ce qui n'a
/// pas été vu.
void main() {
  group('RepereDeLecture.depuisReponse', () {
    test('PostgREST rend une fonction RETURNS TABLE sous forme de liste', () {
      final r = RepereDeLecture.depuisReponse([
        {
          'curseur_id': 'c45c4ed1',
          'curseur_a': '2026-09-16T10:00:00.123456+00:00',
          'premier_non_lu_id': '85f2da79',
          'premier_non_lu_a': '2026-09-16T10:05:00+00:00',
          'non_lus': 8,
        },
      ]);

      expect(r.curseurId, 'c45c4ed1');
      expect(r.curseurA, DateTime.utc(2026, 9, 16, 10, 0, 0, 123, 456));
      expect(r.premierNonLuId, '85f2da79');
      expect(r.premierNonLuA, DateTime.utc(2026, 9, 16, 10, 5));
      expect(r.nonLus, 8);
      expect(r.aUnSeparateur, isTrue);
    });

    test('le dernier non-lu, quand la fonction le rend (20260917002300)', () {
      final r = RepereDeLecture.depuisReponse([
        {
          'premier_non_lu_id': 'p',
          'non_lus': 3,
          'dernier_non_lu_id': 'd',
          'dernier_non_lu_a': '2026-09-17T10:05:00.5+00:00',
        },
      ]);
      expect(r.dernierNonLuId, 'd');
      expect(r.dernierNonLuA, DateTime.utc(2026, 9, 17, 10, 5, 0, 500));
    });

    test('une fonction plus ancienne, sans ces colonnes, reste lisible', () {
      final r = RepereDeLecture.depuisReponse([
        {'premier_non_lu_id': 'p', 'non_lus': 3},
      ]);
      expect(r.dernierNonLuId, isNull);
      expect(r.dernierNonLuA, isNull);
      expect(r.aUnSeparateur, isTrue);
    });

    test('rien jamais lu : pas de curseur, et tout ce qui vient est nouveau', () {
      final r = RepereDeLecture.depuisReponse([
        {
          'curseur_id': null,
          'curseur_a': null,
          'premier_non_lu_id': 'a',
          'premier_non_lu_a': '2026-09-16T10:05:00+00:00',
          'non_lus': 3,
        },
      ]);

      expect(r.curseurId, isNull);
      expect(r.curseurA, isNull);
      expect(r.aUnSeparateur, isTrue);
    });

    test('tout est lu : aucun séparateur', () {
      final r = RepereDeLecture.depuisReponse([
        {
          'curseur_id': 'x',
          'curseur_a': '2026-09-16T10:00:00+00:00',
          'premier_non_lu_id': null,
          'premier_non_lu_a': null,
          'non_lus': 0,
        },
      ]);

      expect(r.aUnSeparateur, isFalse);
    });

    test('une carte seule est acceptée', () {
      final r = RepereDeLecture.depuisReponse({'premier_non_lu_id': 'a', 'non_lus': 1});
      expect(r.aUnSeparateur, isTrue);
    });

    test('un compte sans message désigné ne pose pas de séparateur', () {
      // Il ne dit pas OÙ. Poser le séparateur « quelque part » est ce qui a
      // mené au curseur.
      final r = RepereDeLecture.depuisReponse([
        {'premier_non_lu_id': null, 'non_lus': 4},
      ]);
      expect(r.aUnSeparateur, isFalse);
    });

    test('un identifiant vide vaut absent', () {
      final r = RepereDeLecture.depuisReponse([
        {'premier_non_lu_id': '', 'non_lus': 2},
      ]);
      expect(r.premierNonLuId, isNull);
      expect(r.aUnSeparateur, isFalse);
    });

    test('une réponse illisible est une erreur, pas « rien à lire »', () {
      // Les deux ne doivent pas se confondre : l'écran ne tombe sur ses replis
      // que s'il SAIT que le serveur n'a pas répondu.
      expect(() => RepereDeLecture.depuisReponse(null), throwsFormatException);
      expect(() => RepereDeLecture.depuisReponse(const []), throwsFormatException);
      expect(
        () => RepereDeLecture.depuisReponse([{}, {}]),
        throwsFormatException,
      );
      expect(() => RepereDeLecture.depuisReponse('8'), throwsFormatException);
    });
  });

  group('estFonctionAbsente', () {
    test('PGRST202 (cache de schéma) et 42883 (Postgres)', () {
      expect(estFonctionAbsente(const PostgrestException(message: '', code: 'PGRST202')), isTrue);
      expect(estFonctionAbsente(const PostgrestException(message: '', code: '42883')), isTrue);
    });

    test('un refus ou une borne inconnue ne sont PAS une fonction absente', () {
      // Sinon l'écran reprendrait l'ancien chemin — qui marque tout — sur un
      // simple refus.
      expect(estFonctionAbsente(const PostgrestException(message: '', code: '42501')), isFalse);
      expect(estFonctionAbsente(const PostgrestException(message: '', code: 'P0002')), isFalse);
      expect(estFonctionAbsente(const PostgrestException(message: '')), isFalse);
    });
  });

  group('contre un PostgREST de façade', () {
    late HttpServer serveur;
    late SupabaseClient client;

    String? methode;
    String? chemin;
    Object? corps;
    var appels = 0;

    late int statut;
    late String reponse;

    setUp(() async {
      methode = chemin = null;
      corps = null;
      appels = 0;
      statut = 200;
      reponse = '[]';

      serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serveur.listen((HttpRequest r) async {
        appels++;
        methode = r.method;
        chemin = r.uri.path;
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

    LectureServeur lecture({bool session = true}) =>
        LectureServeur(client: client, ensureAuth: () async => session);

    test('relever appelle repere_de_lecture avec la seule conversation', () async {
      reponse = jsonEncode([
        {
          'curseur_id': 'c',
          'curseur_a': '2026-09-16T10:00:00+00:00',
          'premier_non_lu_id': 'p',
          'premier_non_lu_a': '2026-09-16T10:01:00+00:00',
          'non_lus': 2,
        },
      ]);

      final repere = await lecture().relever('conv-1');

      expect(methode, 'POST');
      expect(chemin, '/rest/v1/rpc/repere_de_lecture');
      // Pas d'identifiant d'utilisateur : le serveur le tient de la session.
      // C'est ce qui ferme la faille des anciennes RPC d'accusés.
      expect(corps, {'p_conversation_id': 'conv-1'});
      expect(repere.premierNonLuId, 'p');
      expect(repere.nonLus, 2);
    });

    test('avancer envoie un IDENTIFIANT de borne, jamais une date ni un uid', () async {
      reponse = '5';

      final reste = await lecture().avancerJusqua('conv-1', 'msg-42');

      expect(chemin, '/rest/v1/rpc/marquer_lus_jusqua');
      expect(corps, {'p_conversation_id': 'conv-1', 'p_message_id': 'msg-42'});
      expect(reste, 5);
    });

    test('fonction absente : LectureServeurAbsente, que l\'écran sait replier', () async {
      statut = 404;
      reponse = jsonEncode({
        'code': 'PGRST202',
        'details': null,
        'hint': null,
        'message': 'Could not find the function public.marquer_lus_jusqua in the schema cache',
      });

      await expectLater(
        lecture().avancerJusqua('conv-1', 'msg-42'),
        throwsA(isA<LectureServeurAbsente>()),
      );
      await expectLater(
        lecture().relever('conv-1'),
        throwsA(isA<LectureServeurAbsente>()),
      );
    });

    test('un refus reste un refus : il ne se déguise pas en fonction absente', () async {
      statut = 403;
      reponse = jsonEncode({
        'code': '42501',
        'details': null,
        'hint': null,
        'message': 'marquer_lus_jusqua: pas participant',
      });

      await expectLater(
        lecture().avancerJusqua('conv-1', 'msg-42'),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    });

    test('une borne inconnue remonte, au lieu de passer pour un succès', () async {
      statut = 400;
      reponse = jsonEncode({
        'code': 'P0002',
        'details': null,
        'hint': null,
        'message': 'marquer_lus_jusqua: message inconnu dans cette conversation',
      });

      await expectLater(
        lecture().avancerJusqua('conv-1', 'inconnu'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('sans session, rien ne part', () async {
      // En `anon`, ces fonctions sont refusées : l'échec serait un 42501 qui
      // tairait sa vraie cause.
      await expectLater(
        lecture(session: false).relever('conv-1'),
        throwsStateError,
      );
      await expectLater(
        lecture(session: false).avancerJusqua('conv-1', 'm'),
        throwsStateError,
      );
      expect(appels, 0);
    });
  });
}
