import 'package:diaspo_niger/features/auth/presentation/screens/splash_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le sous-titre du splash était écrit en dur, sans accent
/// (« Connecter la diaspora nigerienne »), et restait en français sur un
/// téléphone en anglais. Vu sur SM A515F le 2026-09-22, build Play 1.2.2+26.
void main() {
  Future<void> poser(WidgetTester tester, Locale langue) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: langue,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('en français : accentué', (tester) async {
    await poser(tester, const Locale('fr'));
    expect(find.text('Connecter la diaspora nigérienne'), findsOneWidget);
    expect(find.textContaining('nigerienne'), findsNothing);
  });

  testWidgets('en anglais : traduit', (tester) async {
    await poser(tester, const Locale('en'));
    expect(find.text('Connecting the Nigerien diaspora'), findsOneWidget);
    expect(find.textContaining('diaspora nig'), findsNothing);
  });
}
