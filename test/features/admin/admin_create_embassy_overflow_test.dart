import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_create_embassy_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Débordement du formulaire « Créer une ambassade » (route
/// /admin/embassies/create), constaté sur SM A515F (1080x2400, thème sombre) :
/// bandeau « RIGHT OVERFLOWED BY 54 PIXELS » sur le champ « Type * ».
///
/// Cause : `DropdownButtonFormField` empile **tous** ses éléments dans un
/// `IndexedStack`, y compris le `hintText` de la décoration que Flutter
/// convertit en `hint` (dropdown.dart, `DropdownButtonFormField.builder`).
/// Un `IndexedStack` se dimensionne sur son plus **grand** enfant, pas sur
/// l'enfant affiché : la largeur du champ replié est donc dictée par
/// « Sélectionnez le type d'établissement » — invisible — et non par
/// « Ambassade ». Sans `isExpanded`, cette pile n'est pas `Expanded` dans la
/// `Row` interne, donc rien ne la contraint.
///
/// La police de test rend chaque glyphe carré (1 em), donc les largeurs sont
/// plus grandes qu'à l'écran : l'écart mesuré ici n'est pas les 54 px de
/// l'appareil, mais le débordement est le même et se reproduit à coup sûr.
void main() {
  Widget boot() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const AdminCreateEmbassyScreen(),
        ),
      );

  for (final scale in [1.0, 1.1]) {
    testWidgets(
      'Le formulaire de création d\'ambassade ne déborde pas (échelle $scale)',
      (tester) async {
        // Géométrie du SM A515F.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(boot());
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Le formulaire est plus haut que l'écran : on le fait défiler
        // entièrement pour que chaque champ soit réellement disposé.
        final scroller = find.byType(SingleChildScrollView);
        for (var i = 0; i < 12; i++) {
          await tester.drag(scroller, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
