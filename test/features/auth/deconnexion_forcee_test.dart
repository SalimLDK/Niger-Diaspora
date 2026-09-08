import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/services/session_service.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';

/// La déconnexion forcée « Connecté ailleurs » ne signait que la sortie de
/// Firebase : ni purge des caches Hive, ni effacement des préférences
/// personnelles, ni retrait du jeton FCM — et `AuthState` restait sur
/// `authenticated` alors que Firebase était sorti, si bien que le garde du
/// routeur ne voyait rien. Le compte suivant sur ce téléphone héritait des
/// données du précédent, et l'appareil continuait de recevoir ses
/// notifications.
///
/// Elle délègue désormais à la déconnexion complète d'`AuthNotifier`. Ces
/// tests verrouillent les deux moitiés du contrat : le câblage côté notifier,
/// et la délégation côté service — repli compris, parce qu'une sortie
/// incomplète vaut mieux que pas de sortie.
class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepoQuiPend implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() =>
      Completer<Either<Failure, UserEntity?>>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => SessionService.instance.onForceLogout = null);

  group('Câblage côté AuthNotifier', () {
    test('construire le notifier branche la déconnexion complète', () async {
      SessionService.instance.onForceLogout = null;

      final c = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth()),
          authRepositoryProvider.overrideWithValue(_RepoQuiPend()),
        ],
      );
      addTearDown(c.dispose);
      // `authNotifierProvider` est auto-dispose : sans abonnement il est
      // détruit dès la fin du `read`.
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      expect(
        SessionService.instance.onForceLogout,
        isNotNull,
        reason: 'sans ce branchement, la déconnexion forcée retombe sur le '
            'repli et laisse caches, préférences et jeton FCM en place',
      );
    });

    test('détruire le notifier retire son branchement', () async {
      final c = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth()),
          authRepositoryProvider.overrideWithValue(_RepoQuiPend()),
        ],
      );
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);
      expect(SessionService.instance.onForceLogout, isNotNull);

      c.dispose();

      expect(
        SessionService.instance.onForceLogout,
        isNull,
        reason: 'une fermeture pointant un notifier détruit lèverait sur son '
            '`ref`',
      );
    });
  });

  group('Délégation côté SessionService', () {
    test('la déconnexion complète est appelée quand elle est branchée', () async {
      var appels = 0;
      SessionService.instance.onForceLogout = () async {
        appels++;
        return true;
      };

      await SessionService.instance.forcerDeconnexionPourTest();

      expect(appels, 1);
    });

    test('sans branchement, le repli s\'applique sans lever', () async {
      SessionService.instance.onForceLogout = null;

      // Le repli touche Firebase et les préférences, indisponibles ici : ce
      // qui est vérifié est qu'il avale ses échecs au lieu de laisser une
      // levée s'échapper d'un écouteur de flux, où elle ne remonterait nulle
      // part.
      await expectLater(
        SessionService.instance.forcerDeconnexionPourTest(),
        completes,
      );
    });

    test('une déconnexion complète en échec retombe sur le repli', () async {
      SessionService.instance.onForceLogout =
          () async => throw StateError('conteneur détruit');

      await expectLater(
        SessionService.instance.forcerDeconnexionPourTest(),
        completes,
      );
    });
  });
}
