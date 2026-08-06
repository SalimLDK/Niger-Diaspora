import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/tablet_navigation_rail.dart';

/// Le rail latéral n'apparaît pas qu'en tablette : un téléphone en paysage
/// dépasse le seuil de 700 dp de large (SM A515F : 2400 px / 2.625 = 914 dp)
/// et bascule sur ce layout avec ~411 dp de haut seulement. Quand le clavier
/// monte, `resizeToAvoidBottomInset` réduit encore le corps, et la colonne de
/// cinq items (~352 dp incompressibles) débordait de ~190 px.
///
/// Le rail est monté ici comme `MainShell` le monte : premier enfant d'une
/// `Row`, donc contraint en hauteur par le corps du `Scaffold`.
void main() {
  Widget harness(double bodyHeight, {double textScale = 1.0}) {
    return MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        // Les libelles du rail viennent de l10n depuis 4d6bc1b : sans les
        // delegues, `AppLocalizations.of(context)!` leve et le rail ne se
        // construit pas. On force le francais, les assertions portant sur
        // « Profil ».
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: bodyHeight,
            child: Row(
              children: const [
                TabletNavigationRail(
                  currentIndex: 3,
                  onTap: _noop,
                  unreadMessagesCount: 4,
                ),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 411 dp = paysage sans clavier ; 172 dp = paysage clavier levé (le cas qui
  // débordait) ; 120 dp = marge de sécurité au-delà du pire cas mesuré.
  for (final height in [411.0, 172.0, 120.0]) {
    testWidgets('le rail ne déborde pas sur $height dp de haut', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(height));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('le rail ne déborde pas à font_scale 1.1, clavier levé', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(172, textScale: 1.1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('les cinq items restent atteignables en défilant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(172));
    await tester.pump(const Duration(milliseconds: 300));

    // « Profil » est le dernier item : hors écran à 172 dp, il doit pouvoir
    // être ramené par un défilement plutôt que rester coupé sous la bannière.
    expect(find.text('Profil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Profil'), 60);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Profil')).bottom,
      lessThanOrEqualTo(172.0),
    );
  });
}

void _noop(int _) {}
