import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Un compte authentifié mais sans droits d'administration doit être
/// **déconnecté** — et l'écran doit savoir si cela a marché.
///
/// `signOut` rend un `Either`, et un `Left` veut dire que la session est
/// toujours ouverte. Il était lancé en `unawaited(...)`, son résultat jeté, et
/// « Accès refusé » s'affichait avant même que la déconnexion ait un résultat :
/// un compte sans droits pouvait rester connecté sur le panneau sans que
/// personne le sache.
class _FauxAuth implements AuthRepository {
  _FauxAuth(this.utilisateur);

  final UserEntity utilisateur;

  /// Ce que `signOut` rend. Remplaçable pour tenir le résultat en suspens.
  Future<Either<Failure, void>> Function() signOutImpl = () async =>
      const Right(null);

  int signOutAppels = 0;

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async => Right(utilisateur);

  @override
  Future<Either<Failure, void>> signOut() {
    signOutAppels++;
    return signOutImpl();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const refus = 'Accès refusé. Compte administrateur requis.';
  const nonFermee = "La session n'a pas pu être fermée";

  Future<void> monter(WidgetTester tester, _FauxAuth auth) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/dashboard': (_) => const Scaffold(body: Text('TABLEAU DE BORD')),
          },
          home: const AdminLoginScreen(),
        ),
      ),
    );
  }

  Future<void> seConnecter(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    // Pas de `pumpAndSettle` : le bouton porte un indicateur de chargement
    // animé tant que la connexion est en cours.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('non-admin, déconnexion réussie : simple refus', (tester) async {
    final auth = _FauxAuth(const UserEntity(id: 'u1'));
    await monter(tester, auth);

    await seConnecter(tester);

    expect(auth.signOutAppels, 1);
    expect(find.text(refus), findsOneWidget);
    expect(find.textContaining(nonFermee), findsNothing);
  });

  testWidgets('non-admin, déconnexion en échec : l\'écran le dit', (
    tester,
  ) async {
    final auth = _FauxAuth(const UserEntity(id: 'u1'))
      ..signOutImpl = () async => const Left(ServerFailure('réseau coupé'));
    await monter(tester, auth);

    await seConnecter(tester);

    expect(auth.signOutAppels, 1);
    expect(
      find.textContaining(nonFermee),
      findsOneWidget,
      reason:
          'le compte sans droits reste connecté : afficher un simple « Accès '
          'refusé » laissait croire l\'inverse',
    );
    // Et le bouton est rendu : l'utilisateur peut réessayer.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('le refus n\'est écrit qu\'une fois la déconnexion terminée', (
    tester,
  ) async {
    final enCours = Completer<Either<Failure, void>>();
    final auth = _FauxAuth(const UserEntity(id: 'u1'))
      ..signOutImpl = () => enCours.future;
    await monter(tester, auth);

    await seConnecter(tester);

    expect(auth.signOutAppels, 1);
    expect(
      find.textContaining('Accès refusé'),
      findsNothing,
      reason:
          'le message partait avant le résultat de signOut : il ne pouvait '
          'donc pas en tenir compte',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'la connexion est encore en cours',
    );

    enCours.complete(const Left(ServerFailure('réseau coupé')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining(nonFermee), findsOneWidget);
  });

  testWidgets('admin : aucune déconnexion, on entre au tableau de bord', (
    tester,
  ) async {
    final auth = _FauxAuth(
      const UserEntity(id: 'a1', adminRole: AdminRole.superAdmin),
    );
    await monter(tester, auth);

    await seConnecter(tester);
    await tester.pumpAndSettle();

    expect(auth.signOutAppels, 0);
    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
  });
}
