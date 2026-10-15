// Les briques de `design_kit.dart` que les écrans Utilisateurs et Signalements
// posent, rendues sous le `ThemeData` nu de `AdminApp` (pas le thème de l'app
// mobile) : le kit lit ses couleurs par des extensions de `BuildContext`, et un
// thème qui ne les porte pas ferait lever le rendu — sur un écran admin, donc
// sans que personne ne le voie avant la mise en ligne.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';

Widget _sousThemeAdmin(Widget child, {Brightness b = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: b),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('les briques se rendent sans erreur (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = TextEditingController(text: 'aminata');
      addTearDown(controller.dispose);
      var charge = 0;
      var efface = 0;

      await tester.pumpWidget(_sousThemeAdmin(
        Column(
          children: [
            DesignSearchField(
              controller: controller,
              hintText: 'Rechercher',
              onClear: () => efface++,
              active: true,
            ),
            Wrap(children: [
              DesignFilterChip(
                  label: 'Tous', selected: true, compact: true, onTap: () {}),
              DesignFilterChip(
                  label: 'Utilisateur', selected: false, compact: true, onTap: () {}),
            ]),
            const DesignBadge('En attente', tone: DesignBadgeTone.review),
            const DesignBadge('Résolu', tone: DesignBadgeTone.verified),
            const DesignBadge('Rejeté', tone: DesignBadgeTone.archived),
            const DesignBadge('Banni', tone: DesignBadgeTone.failed),
            const DesignTag('Admin', tone: DesignTagTone.accent),
            DesignEmptyState(
              icon: Icons.report_off_rounded,
              title: 'Aucun signalement',
              body: 'Rien à traiter ici pour le moment.',
              children: [
                Center(
                  child: DesignSecondaryButton(label: 'Effacer', onPressed: () {}),
                ),
              ],
            ),
            AdminChargerPlus(enCours: false, onPressed: () => charge++),
          ],
        ),
        b: b,
      ));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Charger plus'));
      expect(charge, 1);
      await tester.tap(find.byIcon(Icons.close));
      expect(efface, 1);
    });
  }

  testWidgets('AdminChargerPlus montre un sablier pendant le chargement',
      (tester) async {
    await tester.pumpWidget(
      _sousThemeAdmin(AdminChargerPlus(enCours: true, onPressed: () {})),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Charger plus'), findsNothing);
  });
}
