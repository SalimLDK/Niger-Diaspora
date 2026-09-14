import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/feed/presentation/widgets/post_image_frame.dart';

/// Une image seule du fil était posée dans une bande de 205 px de haut en
/// `BoxFit.cover` : une photo portrait y perdait la moitié de sa hauteur. Le
/// cadre prend maintenant la forme de la photo — mais pas n'importe laquelle.
void main() {
  group('cadreRatio', () {
    test('une photo paysage garde sa forme', () {
      expect(cadreRatio(16 / 9), closeTo(16 / 9, 0.001));
      expect(cadreRatio(4 / 3), closeTo(4 / 3, 0.001));
    });

    test('une photo carrée reste carrée', () {
      expect(cadreRatio(1), 1);
    });

    test('un portrait 4:5 passe entier, un 9:16 est borné', () {
      expect(cadreRatio(4 / 5), closeTo(4 / 5, 0.001));
      // 0,5625 : sans borne, la carte ferait presque deux écrans de haut.
      expect(cadreRatio(9 / 16), ratioMiniPortrait);
    });

    test('un panorama est borné aussi', () {
      expect(cadreRatio(3), ratioMaxiPaysage);
    });

    test('une valeur absurde retombe sur le défaut', () {
      // Sans ce garde, la mise en page reçoit une contrainte insoluble : le
      // fil entier tombe en erreur de rendu pour une seule image cassée.
      expect(cadreRatio(0), ratioParDefaut);
      expect(cadreRatio(-2), ratioParDefaut);
      expect(cadreRatio(double.nan), ratioParDefaut);
      expect(cadreRatio(double.infinity), ratioParDefaut);
    });

    test('les bornes encadrent bien le défaut', () {
      expect(ratioMiniPortrait, lessThan(ratioParDefaut));
      expect(ratioParDefaut, lessThan(ratioMaxiPaysage));
    });
  });
}
