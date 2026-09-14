import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

/// L'en-tête de l'écran Groupes porte désormais TROIS actions carrées —
/// recherche, carte, créer — à côté d'un grand titre serif.
///
/// C'est la configuration la plus chargée de l'app, et la famille de
/// débordements que ce projet paie régulièrement : une rangée non flexible
/// qui tient à la police par défaut et casse dès que l'appareil grossit le
/// texte. Le titre est bien dans un `Expanded`, donc il se replie au lieu de
/// pousser — ce banc vérifie que c'est vrai aux échelles relevées sur les
/// appareils du projet (1,0 / 1,1 / 1,3) et à la largeur du plus étroit.
///
/// Les largeurs de texte ne sont pas asserties en dp : la police des tests
/// rend un carré de `fontSize` par caractère, sans rapport avec la police
/// réelle. Ce qui est mesuré est ce qui casserait — le débordement lui-même.
void main() {
  Widget banc({required double largeur, required double echelle}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(largeur, 800),
          textScaler: TextScaler.linear(echelle),
        ),
        child: Scaffold(
          body: DesignScreenHeader(
            // Le titre réel de l'écran, avec son sous-titre le plus long.
            title: 'Groupes',
            subtitle: '5 rejoints · 3 invitations en attente',
            actions: [
              DesignSquareAction(
                icon: Icons.search,
                tooltip: 'Rechercher',
                onPressed: () {},
              ),
              DesignSquareAction(
                icon: Icons.public,
                tooltip: 'Groupes sur la carte',
                onPressed: () {},
              ),
              DesignSquareAction(
                icon: Icons.add,
                filled: true,
                tooltip: 'Créer',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final largeur in [320.0, 360.0, 411.0]) {
    for (final echelle in [1.0, 1.1, 1.3]) {
      testWidgets('trois actions tiennent à ${largeur}dp, échelle $echelle',
          (tester) async {
        tester.view.physicalSize = Size(largeur, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(banc(largeur: largeur, echelle: echelle));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'un débordement lève ici même sans être visible');
        // Les trois actions sont bien toutes rendues : un en-tête qui se
        // « répare » en rognant une action serait pire qu'un débordement.
        expect(find.byType(DesignSquareAction), findsNWidgets(3));
      });
    }
  }
}
