import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/shared/widgets/share_icon_button.dart';

/// Les fiches de partage du profil et du groupe rangent quatre tuiles dans une
/// rangée d'environ 313 dp (dialogue de 380 dp au plus, ou l'écran moins 40 dp
/// de marge, moins 40 dp de remplissage) : ~69 dp par tuile.
///
/// À l'échelle de police 1,3 — le réglage du Pixel —, « WhatsApp » et
/// « Facebook » ne tenaient plus et se coupaient en plein mot
/// (« WhatsAp / p », « Faceboo / k »). Le libellé doit rester sur une ligne et
/// tenir dans sa tuile, à toute échelle.
void main() {
  const largeurRangee = 313.0;
  const libelles = ['WhatsApp', 'Facebook', 'X', 'Plus'];

  Widget rangee({required double echelle, VoidCallback? onTap}) {
    void rien() {}
    Widget tuile(IconData icone, Color couleur, String libelle) =>
        ShareIconButton(
          icon: icone,
          color: couleur,
          label: libelle,
          onTap: onTap ?? rien,
        );

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
                    width: largeurRangee,
                    child: Row(
                      children: [
                        tuile(Icons.message_rounded, Colors.green, libelles[0]),
                        const SizedBox(width: 12),
                        tuile(Icons.facebook_rounded, Colors.blue, libelles[1]),
                        const SizedBox(width: 12),
                        tuile(Icons.close_rounded, Colors.black, libelles[2]),
                        const SizedBox(width: 12),
                        tuile(Icons.more_horiz_rounded, Colors.orange, libelles[3]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  for (final echelle in [1.0, 1.3, 2.0]) {
    testWidgets('échelle $echelle : chaque libellé tient sur une seule ligne', (
      tester,
    ) async {
      await tester.pumpWidget(rangee(echelle: echelle));

      // Hauteur propre du texte, avant toute réduction : un libellé qui passe
      // à la ligne en fait au moins le double.
      for (final libelle in libelles) {
        expect(
          tester.getSize(find.text(libelle)).height,
          lessThan(11 * echelle * 1.5),
          reason: '« $libelle » passe sur plusieurs lignes à l\'échelle $echelle',
        );
      }
    });

    testWidgets('échelle $echelle : chaque libellé reste dans sa tuile', (
      tester,
    ) async {
      await tester.pumpWidget(rangee(echelle: echelle));

      final tuiles = find.byType(ShareIconButton);
      expect(tuiles, findsNWidgets(libelles.length));

      for (var i = 0; i < libelles.length; i++) {
        final tuile = tuiles.at(i);
        final texte = find.descendant(of: tuile, matching: find.byType(Text));

        // Coins passés par `localToGlobal` : ils suivent la réduction de
        // `FittedBox`, contrairement à `getSize`, qui rend la taille d'origine.
        final gauche = tester.getTopLeft(texte).dx;
        final droite = tester.getBottomRight(texte).dx;

        expect(
          gauche,
          greaterThanOrEqualTo(tester.getTopLeft(tuile).dx - 0.01),
          reason: '« ${libelles[i]} » déborde à gauche de sa tuile (échelle $echelle)',
        );
        expect(
          droite,
          lessThanOrEqualTo(tester.getBottomRight(tuile).dx + 0.01),
          reason: '« ${libelles[i]} » déborde à droite de sa tuile (échelle $echelle)',
        );
      }
    });
  }

  testWidgets('un tap sur la tuile déclenche son action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(rangee(echelle: 1.3, onTap: () => taps++));

    await tester.tap(find.text('WhatsApp'));

    expect(taps, 1);
  });

  testWidgets('avec `asset`, la tuile montre le logo SVG et non une icône Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ShareIconButton(
                asset: AppIcon.whatsapp,
                color: Colors.green,
                label: 'WhatsApp',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppIcon), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  // La fiche du profil montrait une bulle de chat générique pour WhatsApp et
  // une croix « fermer » pour X, pendant que celle du groupe avait les vrais
  // logos : deux copies de la même tuile qui avaient divergé.
  group('les feuilles de partage montrent les logos de marque', () {
    const feuilles = [
      'lib/features/profile/presentation/widgets/share_profile_modal.dart',
      'lib/features/groups/presentation/widgets/share_group_modal.dart',
      'lib/shared/widgets/share_options_sheet.dart',
      'lib/features/feed/presentation/widgets/share_post_sheet.dart',
    ];

    for (final chemin in feuilles) {
      test(chemin, () {
        final source = File(chemin).readAsStringSync();

        for (final logo in ['whatsapp', 'facebook', 'x']) {
          expect(
            source,
            contains('AppIcon.$logo'),
            reason: '$chemin doit utiliser le logo AppIcon.$logo',
          );
        }
      });
    }
  });
}
