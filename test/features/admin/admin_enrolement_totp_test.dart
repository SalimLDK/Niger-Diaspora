import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_enrolement_totp_screen.dart';
import 'package:diaspo_niger/features/auth/domain/entities/second_facteur.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// L'écran d'enrôlement du second facteur, avec un faux dépôt et sans
/// Firebase : le secret généré est montré en QR et en clé ; le premier code
/// l'enrôle sous son libellé et ouvre le tableau de bord ; un code faux
/// s'affiche et laisse réessayer ; une génération refusée (connexion trop
/// ancienne, TOTP non activé) se dit et se relance.

const _codeJuste = '123456';
const _messageCodeFaux =
    "Code incorrect. Vérifiez le code affiché par l'application.";

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
  _FauxAuth({required this.secrets});

  /// Les réponses successives de `commencerEnrolementTotp` ; la dernière se
  /// répète.
  final List<Either<Failure, SecretTotp>> secrets;

  int generations = 0;
  final codesRecus = <String>[];
  SecretTotp? secretRecu;
  String? libelleRecu;
  int signOutAppels = 0;

  @override
  Future<Either<Failure, SecretTotp>> commencerEnrolementTotp() async {
    generations++;
    return secrets[generations - 1 < secrets.length
        ? generations - 1
        : secrets.length - 1];
  }

  @override
  Future<Either<Failure, void>> terminerEnrolementTotp({
    required SecretTotp secret,
    required String code,
    required String libelle,
  }) async {
    secretRecu = secret;
    libelleRecu = libelle;
    codesRecus.add(code);
    return code == _codeJuste
        ? const Right(null)
        : const Left(
            AuthFailure(_messageCodeFaux, code: 'invalid-verification-code'),
          );
  }

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
          home: const AdminEnrolementTotpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> entrerLeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('le QR et la clé viennent du secret généré', (tester) async {
    final secret = _FauxSecret();
    final auth = _FauxAuth(secrets: [Right(secret)]);
    await monter(tester, auth);

    expect(auth.generations, 1);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text('ABCD EFGH IJKL MNOP'),
      findsOneWidget,
      reason: 'la clé se recopie par blocs de quatre',
    );
    expect(find.text('TABLEAU DE BORD'), findsNothing);
  });

  testWidgets('code faux : le message, le bouton réactivé, pas de tableau '
      'de bord', (tester) async {
    final auth = _FauxAuth(secrets: [Right(_FauxSecret())]);
    await monter(tester, auth);

    await entrerLeCode(tester, '000000');

    expect(auth.codesRecus, ['000000']);
    expect(find.text(_messageCodeFaux), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('code juste : enrôlé sous son libellé, tableau de bord', (
    tester,
  ) async {
    final secret = _FauxSecret();
    final auth = _FauxAuth(secrets: [Right(secret)]);
    await monter(tester, auth);

    await entrerLeCode(tester, _codeJuste);

    expect(auth.codesRecus, [_codeJuste]);
    expect(identical(auth.secretRecu, secret), isTrue);
    expect(auth.libelleRecu, libelleFacteurTotp);
    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
  });

  testWidgets('secret impossible à générer : le motif, puis « Réessayer » '
      'regénère', (tester) async {
    final auth = _FauxAuth(
      secrets: [
        const Left(ServerFailure('Connexion trop ancienne pour cette '
            'opération : reconnectez-vous, puis réessayez.')),
        Right(_FauxSecret()),
      ],
    );
    await monter(tester, auth);

    expect(find.textContaining('Connexion trop ancienne'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(auth.generations, 2);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Connexion trop ancienne'), findsNothing);
  });

  testWidgets('« Se déconnecter » ferme la session et revient à la connexion',
      (tester) async {
    final auth = _FauxAuth(secrets: [Right(_FauxSecret())]);
    await monter(tester, auth);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(auth.signOutAppels, 1);
    expect(find.text('CONNEXION'), findsOneWidget);
  });
}
