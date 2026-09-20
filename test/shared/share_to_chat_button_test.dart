import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/shared/widgets/share_to_chat_button.dart';

/// Le bouton « Envoyer dans une discussion » des fiches de partage occupe toute
/// la largeur du contenu (~313 dp). À l'échelle de police 1,3 — le réglage du
/// Pixel —, son libellé passait sur deux lignes, et l'icône touchait le bord
/// gauche : `padding` ne posait que le vertical, donc aucune marge horizontale.
///
/// Le libellé doit rester sur une ligne, et l'icône comme le texte garder leur
/// marge, à toute échelle.
void main() {
  const largeurBouton = 313.0;
  const margeHorizontale = 16.0;
  const libelle = 'Envoyer dans une discussion';

  Widget bouton({required double echelle, VoidCallback? onPressed}) {
    return MaterialApp(
      home: Builder(
        builder:
            (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(echelle)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: largeurBouton,
                    child: ShareToChatButton(
                      label: libelle,
                      color: Colors.orange,
                      onPressed: onPressed ?? () {},
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  for (final echelle in [1.0, 1.3, 2.0]) {
    testWidgets('échelle $echelle : le libellé tient sur une seule ligne', (
      tester,
    ) async {
      await tester.pumpWidget(bouton(echelle: echelle));

      // Hauteur propre du texte, avant toute réduction : deux lignes en font le
      // double. 14 sp est la taille de base du thème par défaut de ce banc ;
      // l'app pose 16 sp (`elevatedButtonTheme`), ce qui aggrave le défaut sans
      // changer la mesure.
      expect(
        tester.getSize(find.text(libelle)).height,
        lessThan(14 * echelle * 1.5),
        reason: 'le libellé passe sur plusieurs lignes à l\'échelle $echelle',
      );
    });

    testWidgets('échelle $echelle : l\'icône et le libellé gardent leur marge', (
      tester,
    ) async {
      await tester.pumpWidget(bouton(echelle: echelle));

      final gaucheBouton = tester.getTopLeft(find.byType(ElevatedButton)).dx;
      final droiteBouton =
          tester.getBottomRight(find.byType(ElevatedButton)).dx;

      // Coins passés par `localToGlobal` : ils suivent la réduction de
      // `FittedBox`, contrairement à `getSize`.
      final gaucheIcone = tester.getTopLeft(find.byIcon(Icons.forum_rounded)).dx;
      final droiteTexte = tester.getBottomRight(find.text(libelle)).dx;

      expect(
        gaucheIcone,
        greaterThanOrEqualTo(gaucheBouton + margeHorizontale - 0.01),
        reason: 'l\'icône colle au bord gauche (échelle $echelle)',
      );
      expect(
        droiteTexte,
        lessThanOrEqualTo(droiteBouton - margeHorizontale + 0.01),
        reason: 'le libellé colle au bord droit (échelle $echelle)',
      );
    });
  }

  testWidgets('un tap sur le bouton déclenche son action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(bouton(echelle: 1.3, onPressed: () => taps++));

    await tester.tap(find.text(libelle));

    expect(taps, 1);
  });

  // Le profil et le groupe avaient chacun leur copie du bouton, qui n'avaient
  // en commun que la couleur près : une seule source, ou elles rediffèrent.
  group('les fiches de partage passent par le bouton partagé', () {
    const fiches = [
      'lib/features/profile/presentation/widgets/share_profile_modal.dart',
      'lib/features/groups/presentation/widgets/share_group_modal.dart',
    ];

    for (final chemin in fiches) {
      test(chemin, () {
        final source = File(chemin).readAsStringSync();

        expect(source, contains('ShareToChatButton('));
        expect(
          source,
          isNot(contains('Icons.forum_rounded')),
          reason: '$chemin redéclare son propre bouton « discussion »',
        );
      });
    }
  });
}
