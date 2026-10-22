import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_defi_second_facteur_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_enrolement_totp_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:diaspo_niger/features/auth/domain/entities/second_facteur.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Un compte admin n'entre au tableau de bord qu'avec un second facteur
/// (`docs/deploiement/MFA_ADMIN.md`). Les parcours depuis l'écran de
/// connexion, avec un faux dépôt et sans Firebase :
///
/// - admin sans facteur : la connexion aboutit d'un coup → enrôlement, pas
///   le tableau de bord ;
/// - admin avec facteur : la connexion rend un défi → écran de défi ; le bon
///   code ouvre le tableau de bord, un mauvais s'affiche et laisse
///   réessayer ;
/// - compte sans droits derrière un défi : même refus et même déconnexion
///   qu'à la connexion (`admin_login_signout_test.dart`).

const _admin = UserEntity(id: 'a1', adminRole: AdminRole.superAdmin);
const _codeJuste = '123456';
const _messageCodeFaux =
    "Code incorrect. Vérifiez le code affiché par l'application.";

class _FauxDefi implements DefiSecondFacteur {
  @override
  List<FacteurEnrole> get facteurs => const [
        FacteurEnrole(
          id: 'f1',
          type: FacteurEnrole.typeTotp,
          libelle: 'Application',
        ),
      ];
}

class _FauxSecret implements SecretTotp {
  @override
  String get cle => 'ABCDEFGHIJKLMNOP';

  @override
  String get urlQr =>
      'otpauth://totp/DiaspoNiger%20Admin:a1?secret=ABCDEFGHIJKLMNOP'
      '&issuer=DiaspoNiger%20Admin';

  @override
  DateTime? get expireLe => null;
}

class _FauxAuth implements AuthRepository {
  _FauxAuth({
    required this.connexion,
    this.apresDefi = _admin,
  });

  /// Ce que `signInWithEmail` rend : l'usager, ou le défi.
  final Either<Failure, UserEntity> connexion;

  /// Qui sort d'un défi clos par le bon code.
  final UserEntity apresDefi;

  final codesRecus = <String>[];
  int signOutAppels = 0;

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async => connexion;

  @override
  Future<Either<Failure, List<FacteurEnrole>>> facteursEnroles() async =>
      const Right([]);

  @override
  Future<Either<Failure, UserEntity>> resoudreSecondFacteur({
    required DefiSecondFacteur defi,
    required String code,
  }) async {
    codesRecus.add(code);
    return code == _codeJuste
        ? Right(apresDefi)
        : const Left(
            AuthFailure(_messageCodeFaux, code: 'invalid-verification-code'),
          );
  }

  @override
  Future<Either<Failure, SecretTotp>> commencerEnrolementTotp() async =>
      Right(_FauxSecret());

  @override
  Future<Either<Failure, void>> signOut() async {
    signOutAppels++;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
            '/login': (_) => const Scaffold(body: Text('CONNEXION')),
          },
          home: const AdminLoginScreen(),
        ),
      ),
    );
  }

  Future<void> seConnecter(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  Future<void> entrerLeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets("admin sans facteur : l'enrôlement, pas le tableau de bord", (
    tester,
  ) async {
    final auth = _FauxAuth(connexion: const Right(_admin));
    await monter(tester, auth);

    await seConnecter(tester);

    expect(find.byType(AdminEnrolementTotpScreen), findsOneWidget);
    expect(
      find.text('TABLEAU DE BORD'),
      findsNothing,
      reason: "un admin sans second facteur n'entre pas au tableau de bord",
    );
    expect(auth.signOutAppels, 0);
  });

  testWidgets('admin avec facteur : le défi, puis le tableau de bord', (
    tester,
  ) async {
    final auth = _FauxAuth(
      connexion: Left(SecondFacteurRequisFailure(_FauxDefi())),
    );
    await monter(tester, auth);

    await seConnecter(tester);

    expect(find.byType(AdminDefiSecondFacteurScreen), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(find.byType(AdminEnrolementTotpScreen), findsNothing);

    await entrerLeCode(tester, _codeJuste);

    expect(auth.codesRecus, [_codeJuste]);
    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
    expect(auth.signOutAppels, 0);
  });

  testWidgets('code faux : le message, et le bouton redevient actif', (
    tester,
  ) async {
    final auth = _FauxAuth(
      connexion: Left(SecondFacteurRequisFailure(_FauxDefi())),
    );
    await monter(tester, auth);
    await seConnecter(tester);

    await entrerLeCode(tester, '000000');

    expect(find.text(_messageCodeFaux), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
      reason: 'un code faux se corrige : le bouton doit être réactivé',
    );

    // Et le bon code passe ensuite.
    await entrerLeCode(tester, _codeJuste);

    expect(auth.codesRecus, ['000000', _codeJuste]);
    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
  });

  testWidgets('code trop court : refusé sur place, sans appel au dépôt', (
    tester,
  ) async {
    final auth = _FauxAuth(
      connexion: Left(SecondFacteurRequisFailure(_FauxDefi())),
    );
    await monter(tester, auth);
    await seConnecter(tester);

    await entrerLeCode(tester, '12');

    expect(auth.codesRecus, isEmpty);
    expect(find.byType(AdminDefiSecondFacteurScreen), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('compte sans droits derrière un défi : refus et déconnexion', (
    tester,
  ) async {
    final auth = _FauxAuth(
      connexion: Left(SecondFacteurRequisFailure(_FauxDefi())),
      apresDefi: const UserEntity(id: 'u1'),
    );
    await monter(tester, auth);
    await seConnecter(tester);

    await entrerLeCode(tester, _codeJuste);

    expect(auth.signOutAppels, 1, reason: 'la session ouverte par le défi');
    expect(
      find.text('Accès refusé. Compte administrateur requis.'),
      findsOneWidget,
    );
    expect(find.text('TABLEAU DE BORD'), findsNothing);
  });

  testWidgets('connexion refusée : le message, ni défi ni enrôlement', (
    tester,
  ) async {
    final auth = _FauxAuth(
      connexion: const Left(ServerFailure('Email ou mot de passe incorrect')),
    );
    await monter(tester, auth);

    await seConnecter(tester);

    expect(find.text('Email ou mot de passe incorrect'), findsOneWidget);
    expect(find.byType(AdminDefiSecondFacteurScreen), findsNothing);
    expect(find.byType(AdminEnrolementTotpScreen), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
