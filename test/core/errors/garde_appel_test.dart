import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase
    show AuthException, PostgrestException;

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/errors/garde_appel.dart';

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

    test('522 Cloudflare : le message porte déjà le code, pas de doublon',
        () async {
      final echec = echecDe(
        await leve(
          const supabase.PostgrestException(
            message: 'error code: 522',
            code: '522',
          ),
        ),
      );
      expect((echec as ServerFailure).code, '522');
      expect(echec.message, 'error code: 522');
    });

    test('une page HTML en guise de message est bornée et mise sur une ligne',
        () async {
      final page = '<!DOCTYPE html>\n<html>${'<p>x</p>\n' * 200}</html>';
      final echec = echecDe(
        await leve(supabase.PostgrestException(message: page, code: '503')),
      );
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
