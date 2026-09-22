import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/feed/presentation/theme/feed_tokens.dart';
import 'package:diaspo_niger/features/feed/presentation/widgets/feed_segmented_control.dart';

/// Régression : « Suivis » est devenu « Abonnements » (fiche 6a) et le segment
/// débordait — le `Row` était en `MainAxisSize.min`, donc rien ne contraignait
/// le libellé. Trois segments à trois mots sur un écran étroit reproduisent le
/// cas.
void main() {
  Future<void> poser(WidgetTester tester, double largeur) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: largeur,
              child: FeedSegmentedControl<int>(
                tokens: FeedTokens.organic,
                fullWidth: true,
                selected: 0,
                onChanged: (_) {},
                segments: const [
                  FeedSegment(value: 0, icon: _icone, label: 'Pour toi'),
                  FeedSegment(value: 1, icon: _icone, label: 'Abonnements'),
                  FeedSegment(value: 2, icon: _icone, label: 'Récent'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('trois segments tiennent sur un écran étroit', (tester) async {
    await poser(tester, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un libellé très long est tronqué, pas débordé', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: FeedSegmentedControl<int>(
                tokens: FeedTokens.nocturne,
                fullWidth: true,
                selected: 1,
                onChanged: (_) {},
                segments: const [
                  FeedSegment(value: 0, icon: _icone, label: 'Pour toi'),
                  FeedSegment(
                    value: 1,
                    icon: _icone,
                    label: 'Un libellé beaucoup trop long pour ce segment',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // Vu sur Pixel 10 Pro XL le 2026-09-22 (police 1,3 + texte en gras) :
  // « Abonneme… ». Le libellé est désormais réduit pour tenir, jusqu'à 80 %.
  group('Réduire plutôt que tronquer', () {
    test('la règle', () {
      expect(reductionPourTenir(90, 100), 1);
      expect(reductionPourTenir(100, 90), closeTo(0.9, 1e-9));
      expect(reductionPourTenir(100, 80), closeTo(0.8, 1e-9));
      expect(reductionPourTenir(100, 79), isNull,
          reason: 'illisible en dessous de 80 % : la troncature reprend');
      expect(reductionPourTenir(100, 0), isNull);
    });

    Future<void> poserUn(WidgetTester tester, double largeur, {bool gras = false}) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(boldText: gras),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: largeur,
                  child: FeedSegmentedControl<int>(
                    tokens: FeedTokens.nocturne,
                    fullWidth: true,
                    selected: 0,
                    onChanged: (_) {},
                    segments: const [
                      FeedSegment(value: 0, icon: _icone, label: 'Abonnements'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Ahem : 13 px par lettre à l'échelle 1 → « Abonnements » = 143 px ;
    // marges, bordures et contour actif du segment prennent 48 px (mesuré).
    Text libelle(WidgetTester tester) =>
        tester.widget<Text>(find.text('Abonnements'));

    testWidgets('assez de place : le texte tel quel', (tester) async {
      await poserUn(tester, 400);
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un peu court : réduit, entier, sans ellipse', (tester) async {
      await poserUn(tester, 180); // 132 px pour 143 : ~92 %
      expect(find.byType(FittedBox), findsOneWidget);
      expect(libelle(tester).overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });

    testWidgets('beaucoup trop court : tronqué, jamais minuscule', (tester) async {
      await poserUn(tester, 100); // 52 px pour 143 : ~36 %
      expect(find.byType(FittedBox), findsNothing);
      expect(libelle(tester).overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gras d\'accessibilité : aucun débordement', (tester) async {
      await poserUn(tester, 180, gras: true);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _icone(Color couleur) => Icon(Icons.circle, color: couleur, size: 16);
