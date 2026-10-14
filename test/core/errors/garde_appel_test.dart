import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase
    show AuthException, PostgrestException;

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/errors/garde_appel.dart';
import 'package:diaspo_niger/core/errors/message_erreur.dart';

/// Les trois formes de la fiche Crashlytics du 2026-10-13 — contrainte
/// `23514`, « JWT expired » `PGRST303`, « error code: 522 » — doivent sortir
/// d'un dépôt en `Failure`, jamais en exception. Les libellés ci-dessous sont
/// ceux de la console, pas des exemples inventés.
void main() {
  late int resynchronisations;
  late bool sessionNeuve;

  setUp(() {
    resynchronisations = 0;
    sessionNeuve = true;
    resynchroniserSession = () async {
      resynchronisations++;
      return sessionNeuve;
    };
  });

  Future<Either<Failure, int>> leve(Object e) =>
      garderAppel<int>(() async => throw e);

  Failure echecDe(Either<Failure, Object?> r) => r.fold(
    (l) => l,
    (droit) => fail('attendu un Left, reçu Right($droit)'),
  );

  const jwtExpire = supabase.PostgrestException(
    message: 'JWT expired',
    code: 'PGRST303',
  );

  group('les exceptions de la couche données deviennent des Failure', () {
    test('ServerException → ServerFailure, message intact', () async {
      final echec = echecDe(await leve(ServerException('Session non établie')));
      expect(echec, isA<ServerFailure>());
      expect(echec.message, 'Session non établie');
      expect((echec as ServerFailure).code, isNull);
    });

    test('contrainte 23514 à la création d\'un commerce (11 évts le 11/10)',
        () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message:
                'new row for relation "businesses" violates check constraint '
                '"businesses_phone_check"',
            code: '23514',
          ),
        ),
      );
      expect(echec, isA<ServerFailure>());
      expect((echec as ServerFailure).code, '23514');
      expect(echec.message, contains('violates check constraint'));
      // Le code est dans le message aussi : les notifiers ne lisent que lui.
      expect(echec.message, contains('23514'));
    });

    test('522 Cloudflare (13/10, SM-N976U) : la passerelle est une panne '
        'de réseau, pas une ServerFailure', () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message: 'error code: 522',
            code: '522',
          ),
        ),
      );
      expect(echec, isA<NetworkFailure>());
      // Le message porte déjà le code : pas de doublon.
      expect(echec.message, 'error code: 522');
    });

    test('502, 503, 504 et 520 à 524 : NetworkFailure, code dans le message',
        () async {
      for (final code in const ['502', '503', '504', '520', '521', '523', '524']) {
        final echec = echecDe(
          await leve(supabase.PostgrestException(message: 'x', code: code)),
        );
        expect(echec, isA<NetworkFailure>(), reason: 'code $code');
        expect(echec.message, contains(code), reason: 'code $code');
      }
    });

    test('le corps Cloudflare suffit, même sans code', () async {
      final echec = echecDe(
        await leve(const supabase.PostgrestException(message: 'error code: 521')),
      );
      expect(echec, isA<NetworkFailure>());
    });

    test('un 500 vient de l\'origine : ServerFailure, code conservé', () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message: 'Internal Server Error',
            code: '500',
          ),
        ),
      );
      expect(echec, isA<ServerFailure>());
      expect((echec as ServerFailure).code, '500');
    });

    test('une page HTML en guise de message est bornée et mise sur une ligne',
        () async {
      final page = '<!DOCTYPE html>\n<html>${'<p>x</p>\n' * 200}</html>';
      final echec = echecDe(
        await leve(supabase.PostgrestException(message: page, code: '503')),
      );
      expect(echec, isA<NetworkFailure>());
      expect(echec.message.length, lessThan(320));
      expect(echec.message, isNot(contains('\n')));
      expect(echec.message, endsWith('(code 503)'));
    });

    test('AuthException Supabase → AuthFailure avec son code', () async {
      final echec = echecDe(
        await leve(
          const supabase.AuthException(
            'Invalid Refresh Token',
            statusCode: '400',
            code: 'refresh_token_not_found',
          ),
        ),
      );
      expect(echec, isA<AuthFailure>());
      expect((echec as AuthFailure).code, 'refresh_token_not_found');
    });

    test('AuthException du projet → AuthFailure, code conservé', () async {
      final echec = echecDe(
        await leve(AuthException('Reconnectez-vous', code: 'requires-recent-login')),
      );
      expect(echec, isA<AuthFailure>());
      expect((echec as AuthFailure).code, 'requires-recent-login');
    });

    test('NotFoundException → NotFoundFailure, distinct d\'une panne', () async {
      final echec = echecDe(await leve(NotFoundException('Publication supprimée')));
      expect(echec, isA<NotFoundFailure>());
    });

    test('E2EEException → E2EEFailure, pas ServerFailure', () async {
      final echec = echecDe(await leve(E2EEException('Clés absentes')));
      expect(echec, isA<E2EEFailure>());
    });

    test('un succès passe tel quel', () async {
      final r = await garderAppel<int>(() async => const Right(7));
      expect(r.fold((l) => fail('$l'), (d) => d), 7);
    });
  });

  group('le texte du serveur n\'atteint jamais l\'écran tel quel', () {
    // PostgREST recopie parfois la requête dans son message : l'hôte du
    // projet et l'identifiant du compte y figurent. Le Failure garde ce texte
    // (borné) pour classer la panne et la journaliser ; ce que l'usager lit
    // sort de `messageErreurUsager`, à qui les notifiers passent
    // `failure.message`. Même liste d'interdits que message_erreur_test.dart.
    const interdits = [
      'supabase.co',
      'vQZE49dTdyRtLwSG6lMIbhAqoFG2',
      'rest/v1',
      'uri=',
      'PostgrestException',
    ];

    void rienDeBrut(String affiche, List<String> enPlus) {
      for (final interdit in [...interdits, ...enPlus]) {
        expect(
          affiche.toLowerCase(),
          isNot(contains(interdit.toLowerCase())),
          reason: '« $interdit » ne doit pas atteindre l\'écran',
        );
      }
    }

    test('refus de droits 42501 : classé « droits », ni URL ni uid', () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message: 'permission denied for table users '
                '(uri=https://zyrfkcjjrhddpfxcgezo.supabase.co/rest/v1/users'
                '?select=%2A&id=eq.vQZE49dTdyRtLwSG6lMIbhAqoFG2)',
            code: '42501',
          ),
        ),
      );
      // Le texte est bien là pour le journal et le classement…
      expect(echec.message, contains('42501'));
      // …mais pas à l'écran.
      final affiche = messageErreurUsager(echec.message);
      expect(affiche, contains('droits'));
      rienDeBrut(affiche, const ['42501', 'permission denied']);
    });

    test('522 : l\'usager lit une panne de connexion, pas « error code »',
        () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message: 'error code: 522',
            code: '522',
          ),
        ),
      );
      final affiche = messageErreurUsager(echec.message);
      expect(affiche, contains('réseau'));
      rienDeBrut(affiche, const ['522', 'error code']);
    });

    test('23514 : le conseil de réessayer, sans la contrainte ni la table',
        () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message:
                'new row for relation "businesses" violates check constraint '
                '"businesses_description_non_vide"',
            code: '23514',
          ),
        ),
      );
      final affiche = messageErreurUsager(echec.message);
      expect(affiche, contains('Réessayez'));
      rienDeBrut(affiche, const ['23514', 'businesses', 'constraint']);
    });
  });

  group('l\'inconnu n\'est pas avalé', () {
    test('remonte intact sans `sinon`', () async {
      expect(() => leve(StateError('défaut de code')), throwsStateError);
    });

    test('passe par `sinon` quand le dépôt en fournit un', () async {
      final r = await garderAppel<int>(
        () async => throw StateError('défaut de code'),
        sinon: (e) => ServerFailure('inattendu : ${e.runtimeType}'),
      );
      expect(echecDe(r).message, 'inattendu : StateError');
    });

    test('`sinon` ne voit pas les familles connues', () async {
      var appele = false;
      final r = await garderAppel<int>(
        () async => throw ServerException('connu'),
        sinon: (_) {
          appele = true;
          return const ServerFailure('ne doit pas servir');
        },
      );
      expect(appele, isFalse);
      expect(echecDe(r).message, 'connu');
    });
  });

  group('JWT expiré (PGRST303)', () {
    test('re-synchronise puis rejoue une fois', () async {
      var appels = 0;
      final r = await garderAppel<int>(() async {
        appels++;
        if (appels == 1) throw jwtExpire;
        return const Right(42);
      });
      expect(r.fold((l) => fail('$l'), (d) => d), 42);
      expect(resynchronisations, 1);
      expect(appels, 2);
    });

    test('un second PGRST303 sort en Failure, sans troisième essai', () async {
      var appels = 0;
      final r = await garderAppel<int>(() async {
        appels++;
        throw jwtExpire;
      });
      expect(appels, 2);
      expect(resynchronisations, 1);
      expect((echecDe(r) as ServerFailure).code, 'PGRST303');
    });

    test('sans session neuve, pas de rejeu', () async {
      sessionNeuve = false;
      var appels = 0;
      final r = await garderAppel<int>(() async {
        appels++;
        throw jwtExpire;
      });
      expect(appels, 1);
      expect(resynchronisations, 1);
      expect(echecDe(r), isA<ServerFailure>());
    });

    test('rejouerSiJwtExpire: false re-synchronise quand même, sans rejouer',
        () async {
      var appels = 0;
      final r = await garderAppel<int>(
        () async {
          appels++;
          throw jwtExpire;
        },
        rejouerSiJwtExpire: false,
      );
      expect(appels, 1);
      expect(resynchronisations, 1);
      expect(echecDe(r), isA<ServerFailure>());
    });

    test('une ServerException qui dit « JWT expired » compte aussi', () async {
      // Plusieurs datasources ré-emballent la PostgrestException et perdent
      // le code en route.
      var appels = 0;
      final r = await garderAppel<int>(() async {
        appels++;
        if (appels == 1) {
          throw ServerException('Lecture de l\'annuaire refusée : JWT expired');
        }
        return const Right(1);
      });
      expect(r.isRight(), isTrue);
      expect(resynchronisations, 1);
    });

    test('une re-synchro qui lève ne masque pas l\'erreur d\'origine', () async {
      resynchroniserSession = () async => throw StateError('Supabase absent');
      final r = await leve(jwtExpire);
      expect((echecDe(r) as ServerFailure).code, 'PGRST303');
    });

    test('un 23514 ne déclenche aucune re-synchro', () async {
      await leve(
        const supabase.PostgrestException(message: 'violates', code: '23514'),
      );
      expect(resynchronisations, 0);
    });
  });

  group('estJwtExpire', () {
    test('reconnaît le code PGRST303', () {
      expect(estJwtExpire(jwtExpire), isTrue);
    });

    test('ne confond pas un autre code PostgREST', () {
      expect(
        estJwtExpire(
          const supabase.PostgrestException(
            message: 'JSON object requested, multiple (or no) rows returned',
            code: 'PGRST116',
          ),
        ),
        isFalse,
      );
    });

    test('ignore ce qui ne vient pas de la couche données', () {
      expect(estJwtExpire(StateError('JWT expired')), isFalse);
    });
  });
}
