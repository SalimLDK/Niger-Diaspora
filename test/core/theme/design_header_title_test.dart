import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:diaspo_niger/core/theme/design_kit.dart';

/// Le grand titre d'en-tête ne coupe jamais un mot.
///
/// Mesuré sur Pixel 10 Pro XL le 2026-09-12 : « Notificatio / ns », parce que
/// « Tout lire » et ⚙ ne laissent qu'environ 150 dp au titre à `font_scale`
/// 1.3. Le test rejoue cette largeur et cette échelle.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  Future<TextStyle> rendre(
    WidgetTester tester, {
    required String titre,
    required double largeur,
    required double echelle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(echelle)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: largeur, child: DesignHeaderTitle(titre)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<Text>(find.text(titre)).style!;
  }

  int lignes(String texte, TextStyle style, double largeur, double echelle) {
    final painter = TextPainter(
      text: TextSpan(text: texte, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(echelle),
    )..layout(maxWidth: largeur);
    final n = painter.computeLineMetrics().length;
    painter.dispose();
    return n;
  }

  testWidgets('un mot trop long se réduit au lieu de se couper', (tester) async {
    final style = await rendre(
      tester,
      titre: 'Notifications',
      largeur: 150,
      echelle: 1.3,
    );
    expect(style.fontSize, lessThan(30));
    expect(lignes('Notifications', style, 150, 1.3), 1);
  });

  testWidgets('un titre qui tient garde sa taille', (tester) async {
    final style = await rendre(
      tester,
      titre: 'Groupes',
      largeur: 300,
      echelle: 1.0,
    );
    expect(style.fontSize, 30);
  });

  testWidgets('plusieurs mots passent à la ligne entre les mots, à 30',
      (tester) async {
    final style = await rendre(
      tester,
      titre: 'Mon profil',
      largeur: 160,
      echelle: 1.0,
    );
    expect(style.fontSize, 30);
  });
}
