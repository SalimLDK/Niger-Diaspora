import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/shared/widgets/photo_crop_screen.dart';

/// Ce que l'écran de recadrage montre doit être exactement ce qu'il découpe.
/// La transformation vit en coordonnées d'**affichage** (l'image mise à la
/// taille du cadre), le découpage en **pixels** du fichier : c'est le passage
/// d'un repère à l'autre qui se vérifie ici.
void main() {
  // Un portrait 3000×4000 posé dans un cadre de 300 : à l'échelle de
  // couverture (0,1), il s'affiche en 300×400.
  const taillePixels = Size(3000, 4000);
  const tailleAffichee = Size(300, 400);
  const coteCadre = 300.0;

  group('rectRecadrage', () {
    test('le cadrage initial reprend le carré central', () {
      // Ce que posait `BoxFit.cover` avant qu'on puisse choisir : la photo
      // centrée, donc 500 px rognés en haut et 500 en bas.
      final rect = rectRecadrage(
        transformation: Matrix4.translationValues(0, -50, 0),
        coteCadre: coteCadre,
        tailleAffichee: tailleAffichee,
        taillePixels: taillePixels,
      );

      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(500, 0.01));
      expect(rect.width, closeTo(3000, 0.01));
      expect(rect.height, closeTo(3000, 0.01));
    });

    test('déplacer vers le haut découpe plus bas dans la photo', () {
      // L'utilisateur fait glisser la photo vers le haut de 100 px affichés,
      // soit 1000 px de l'image : il garde le bas.
      final rect = rectRecadrage(
        transformation: Matrix4.translationValues(0, -100, 0),
        coteCadre: coteCadre,
        tailleAffichee: tailleAffichee,
        taillePixels: taillePixels,
      );

      expect(rect.top, closeTo(1000, 0.01));
      expect(rect.bottom, closeTo(4000, 0.01));
    });

    test('zoomer ×2 découpe deux fois moins large', () {
      final rect = rectRecadrage(
        transformation: Matrix4.diagonal3Values(2, 2, 1),
        coteCadre: coteCadre,
        tailleAffichee: tailleAffichee,
        taillePixels: taillePixels,
      );

      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(0, 0.01));
      expect(rect.width, closeTo(1500, 0.01));
      expect(rect.height, closeTo(1500, 0.01));
    });

    test('un débordement est ramené dans la photo', () {
      // `boundaryMargin: EdgeInsets.zero` l'empêche à l'écran, mais un arrondi
      // suffirait à sortir de l'image : `copyCrop` lèverait une exception et
      // le recadrage échouerait sans que l'utilisateur comprenne pourquoi.
      final rect = rectRecadrage(
        transformation: Matrix4.translationValues(50, 50, 0),
        coteCadre: coteCadre,
        tailleAffichee: tailleAffichee,
        taillePixels: taillePixels,
      );

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.right, lessThanOrEqualTo(taillePixels.width));
      expect(rect.bottom, lessThanOrEqualTo(taillePixels.height));
    });

    test('une photo paysage se cadre sur sa hauteur', () {
      // 4000×3000 dans un cadre de 300 : affichée en 400×300, c'est la
      // largeur qui déborde.
      final rect = rectRecadrage(
        transformation: Matrix4.translationValues(-50, 0, 0),
        coteCadre: coteCadre,
        tailleAffichee: const Size(400, 300),
        taillePixels: const Size(4000, 3000),
      );

      expect(rect.left, closeTo(500, 0.01));
      expect(rect.width, closeTo(3000, 0.01));
      expect(rect.height, closeTo(3000, 0.01));
    });
  });
}
