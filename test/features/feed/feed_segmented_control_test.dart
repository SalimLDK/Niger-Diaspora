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
}

Widget _icone(Color couleur) => Icon(Icons.circle, color: couleur, size: 16);
