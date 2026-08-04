import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_state.dart';
import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';

/// Démarrage hors ligne (régression constatée sur appareil le 2026-08-04 :
/// ~2 min bloqué sur le splash, mode avion réel).
///
/// Le routeur maintient `/splash` tant que `isAuthLoading`, et
/// `_loadUserData` attendait `getCurrentUser()` sans borne — or cette méthode
/// enchaîne trois allers-retours Supabase qui, hors ligne, ne rendent jamais
/// la main.
///
/// Le délai réel est de 8 s ; les tests le raccourcissent en surchargeant le
/// dépôt, pas la constante : ils vérifient donc la *décision* prise à
/// l'expiration, pas sa durée.
class _FakeUser implements User {
  _FakeUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final String? phoneNumber;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dépôt dont `getCurrentUser()` ne se complète jamais : c'est le
/// comportement d'un socket qui pend, pas d'une erreur franche.
class _RepoQuiPend implements AuthRepository {
  final _completer = Completer<Either<Failure, UserEntity?>>();

  /// Permet de simuler le retour du réseau après coup.
  void resoudre(Either<Failure, UserEntity?> value) => _completer.complete(value);

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() => _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mêmes dérivations que le `redirect` du routeur (app_router.dart) : on
  // teste ce que lui voit, pas une reformulation.
  bool splashMaintenu(AuthState s) => s.maybeWhen(
        initial: () => true,
        loading: () => true,
        orElse: () => false,
      );
  UserEntity? utilisateur(AuthState s) =>
      s.maybeWhen(authenticated: (u) => u, orElse: () => null);

  ProviderContainer conteneur({required User? user, required AuthRepository repo}) {
    final c = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth(user)),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    // `authNotifierProvider` est auto-dispose : sans abonnement, il est détruit
    // dès la fin du `read` et le notifier cesse de publier son état.
    c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);
    return c;
  }

  /// Laisse le notifier dérouler son `_initAuthState` jusqu'à l'expiration.
  Future<void> laisserExpirer(ProviderContainer c) async {
    await Future<void>.delayed(const Duration(seconds: 9));
  }

  test(
    'profil serveur injoignable : on démarre quand même, sur la session locale',
    () async {
      final c = conteneur(
        user: _FakeUser(
          uid: 'uid-1',
          email: 'sim@example.com',
          displayName: 'Sim A',
          photoURL: 'https://example.com/a.png',
          phoneNumber: '+15145550100',
        ),
        repo: _RepoQuiPend(),
      );

      await laisserExpirer(c);
      final state = c.read(authNotifierProvider);

      // Le point de la régression : on ne reste pas en chargement.
      expect(splashMaintenu(state), isFalse,
          reason: 'le routeur serait resté sur /splash');
      expect(utilisateur(state), isNotNull,
          reason: 'renvoyer vers /auth/login enfermerait dehors un utilisateur '
              'hors ligne : se reconnecter exige le réseau');
      expect(utilisateur(state)!.id, 'uid-1');
      expect(utilisateur(state)!.displayName, 'Sim A');
      expect(utilisateur(state)!.phoneNumber, '+15145550100');
      // Aucun privilège accordé sur la seule foi d'une session locale.
      expect(utilisateur(state)!.adminRole, AdminRole.none);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'sans session Firebase locale, on reste non authentifié',
    () async {
      final c = conteneur(user: null, repo: _RepoQuiPend());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = c.read(authNotifierProvider);
      expect(splashMaintenu(state), isFalse);
      expect(utilisateur(state), isNull);
    },
  );

  test(
    'une réponse tardive en échec ne déconnecte pas : la décision est prise',
    () async {
      final repo = _RepoQuiPend();
      final c = conteneur(user: _FakeUser(uid: 'uid-1'), repo: repo);

      await laisserExpirer(c);
      expect(utilisateur(c.read(authNotifierProvider)), isNotNull);

      // Le réseau finit par répondre… par un échec.
      repo.resoudre(const Left(ServerFailure('hors ligne')));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(utilisateur(c.read(authNotifierProvider)), isNotNull,
          reason: 'un échec tardif jetterait dehors quelqu\'un déjà entré');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
