import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réplique la géométrie du rail de stories (`story_rail.dart`) sans dépendre
/// de Firebase ni de Riverpod : anneau 60 + écart 6 + libellé, dans un
/// `ListView` horizontal à padding vertical 8, borné par `_railHeight`.
///
/// Ce que le test verrouille : le libellé impose son propre interligne, donc sa
/// hauteur rendue vaut `ceil(fontSize × interligne)` — exactement ce que le
/// rail provisionne. Sans cet interligne figé, le libellé hérite du 1.55 de
/// `bodyMedium` (18 px rendus contre 15 réservés) et le rail déborde.
const double labelFontSize = 11.5;
const double labelLineHeight = 1.3;

/// La couche texte arrondit la ligne au pixel le plus proche (mesuré : 14.95 →
/// 15, 16.445 → 16, 19.435 → 19). `ceilToDouble` est donc toujours au moins
/// égal au rendu — au pire 1 px de mou, jamais de débordement.
double labelHeight(TextScaler scaler) =>
    (scaler.scale(labelFontSize) * labelLineHeight).ceilToDouble();

double railHeight(TextScaler scaler) => 16 + 60 + 6 + labelHeight(scaler);

Widget harness(
  TextScaler scaler, {
  required double height,
  double? lineHeight,
  int avatars = 3,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: scaler),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        // Ce que le rail hérite réellement de AppTheme : bodyMedium, height 1.55.
        style: const TextStyle(fontSize: 14, height: 1.55),
        // Le rail vit dans la Column du fil : contraintes verticales lâches,
        // sinon le SizedBox se ferait imposer la hauteur de l'écran.
        child: Column(
          children: [
            SizedBox(
              height: height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final label
                      in ['Ma story', 'Aïssa', 'Ibrahim'].take(avatars))
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          const SizedBox(width: 60, height: 60),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              height: lineHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // 1.0 = cas signalé (« Ma story » seule), 1.1 = réglage du SM A515F,
  // 1.3 = marge d'accessibilité au-delà.
  for (final scale in [1.0, 1.1, 1.3]) {
    final scaler = TextScaler.linear(scale);

    testWidgets('libellé tient dans la hauteur provisionnée (font_scale $scale)',
        (tester) async {
      await tester.pumpWidget(
        harness(scaler, height: railHeight(scaler), lineHeight: labelLineHeight),
      );
      // L'invariant qui protège du débordement : le rendu ne dépasse jamais ce
      // que `_railHeight` réserve. C'est faux dès que le libellé hérite d'un
      // interligne plus grand que celui provisionné (cf. test de régression).
      expect(
        tester.getSize(find.text('Ma story')).height,
        lessThanOrEqualTo(labelHeight(scaler)),
      );
    });

    testWidgets('rail sans débordement (font_scale $scale)', (tester) async {
      await tester.pumpWidget(
        harness(scaler, height: railHeight(scaler), lineHeight: labelLineHeight),
      );
      expect(tester.takeException(), isNull);
      // Le rail garde bien la hauteur annoncée : pas de compensation muette.
      expect(
        tester.getSize(find.byType(ListView)).height,
        railHeight(scaler),
      );
    });

    testWidgets('régression : interligne hérité => débordement (font_scale $scale)',
        (tester) async {
      // Ce que faisait l'ancien code : rail dimensionné sur un facteur estimé,
      // libellé rendu avec le 1.55 du thème.
      // Un seul avatar : le cas signalé (« Ma story » seule, 0 story publiée)
      // et une seule exception à inspecter.
      await tester.pumpWidget(
        harness(scaler, height: railHeight(scaler), lineHeight: null, avatars: 1),
      );
      final error = tester.takeException();
      expect(error, isFlutterError);
      expect('$error', contains('overflowed'));
    });
  }

  test('l\'écart signalé est bien de 2 px à font_scale 1.0', () {
    // Ancien calcul : ceil(11.5 × 1.35) = 16 réservés.
    final reserved = (labelFontSize * 1.35).ceilToDouble();
    // Rendu réel avec l'interligne de bodyMedium : ceil(11.5 × 1.55) = 18.
    final rendered = (labelFontSize * 1.55).ceilToDouble();
    expect(math.max(0, rendered - reserved), 2.0);
  });
}
