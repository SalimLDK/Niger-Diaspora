import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:diaspo_niger/features/admin/presentation/admin_app.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_login_screen.dart';

/// `AdminApp` monté tel quel, sans délégués ajoutés par le test.
///
/// L'audit du 2026-10-14 (§ 1) l'a mesuré avec un test jetable : première
/// image, « Null check operator used on a null value » — `AdminApp` n'avait
/// ni `localizationsDelegates` ni `supportedLocales`, et l'écran de connexion
/// fait `AppLocalizations.of(context)!`. `admin_login_signout_test.dart`
/// passait parce qu'il monte l'écran dans son propre `MaterialApp`, délégués
/// compris : un vert trompeur. Ce test monte l'application entière, comme
/// `lib/features/admin/main.dart` le fait.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  testWidgets("AdminApp démarre sur l'écran de connexion, sans exception", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason:
          "sans délégués de localisation, l'écran de connexion plante à la "
          'première image',
    );
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    // Les champs e-mail et mot de passe sont là : les libellés, qui viennent
    // des délégués, ont pu se rendre.
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
