import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:diaspo_niger/features/auth/data/models/user_model.dart';
import 'package:diaspo_niger/features/auth/data/repositories/auth_repository_impl.dart';

/// Appuyer sur « Déconnexion » laissait l'écran figé plusieurs secondes.
///
/// Le repository attendait, en série : `getCurrentUser()` — trois
/// allers-retours Supabase (échange du jeton Firebase, upsert du compte,
/// lecture du profil) pour obtenir un uid déjà en mémoire —, puis le retrait
/// du jeton FCM, puis la révocation de la session Supabase et l'oubli du
/// compte Google (init Play Services comprise).
///
/// Rien là-dedans ne décide du fait d'être déconnecté : seul l'effacement du
/// jeton Firebase le fait, et il est local. Ces tests verrouillent la
/// séparation — `signOut()` rend la main sur le geste local, le reste part en
/// tâche de fond.
class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  bool signOutAppele = false;
  bool getCurrentUserAppele = false;
  bool revocationLancee = false;
  bool revocationTerminee = false;

  final Completer<void> _revocation = Completer<void>();

  /// Nul volontairement : le retrait du jeton FCM passe par
  /// `NotificationService`, un singleton qui touche SharedPreferences et
  /// Supabase — hors de portée d'un test unitaire. Ce que ces tests
  /// verrouillent est en amont : d'où vient l'uid, et ce que `signOut()`
  /// attend avant de rendre la main.
  @override
  String? get currentUserId => null;

  @override
  Future<void> signOut() async {
    signOutAppele = true;
  }

  @override
  Future<void> revokeRemoteSessions() async {
    revocationLancee = true;
    await _revocation.future;
    revocationTerminee = true;
  }

  /// Le réseau lent d'autrefois, sous une forme qu'un test peut observer :
  /// tant qu'il n'est pas débloqué, le ménage distant n'aboutit pas.
  void debloquerRevocation() => _revocation.complete();

  @override
  Future<UserModel?> getCurrentUser() async {
    getCurrentUserAppele = true;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Déconnexion', () {
    test('rend la main sans attendre le ménage distant', () async {
      final source = _FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(remoteDataSource: source);

      final resultat = await repository.signOut().timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('signOut a attendu la révocation distante'),
      );

      expect(resultat.isRight(), isTrue);
      expect(
        source.signOutAppele,
        isTrue,
        reason: 'le jeton Firebase local doit être effacé, lui, avant de rendre '
            'la main : c\'est le seul geste qui déconnecte',
      );
      expect(
        source.revocationLancee,
        isTrue,
        reason: 'le ménage distant doit bien être lancé, pas abandonné',
      );
      expect(
        source.revocationTerminee,
        isFalse,
        reason: 'mais signOut ne doit pas l\'attendre',
      );

      // Et il aboutit tout de même, une fois le réseau revenu.
      source.debloquerRevocation();
      await pumpEventQueue();
      expect(source.revocationTerminee, isTrue);
    });

    test('ne passe plus par getCurrentUser pour connaître l\'uid', () async {
      final source = _FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(remoteDataSource: source);

      await repository.signOut().timeout(const Duration(seconds: 2));

      expect(
        source.getCurrentUserAppele,
        isFalse,
        reason: 'trois allers-retours Supabase pour un uid que '
            'FirebaseAuth.currentUser a en mémoire',
      );

      source.debloquerRevocation();
      await pumpEventQueue();
    });
  });
}
