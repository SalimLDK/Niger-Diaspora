import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/position_partagee.dart';

/// La position PARTAGÉE (celle que les autres voient sur la carte) doit être
/// arrondie à ~100 m : « position approximative, jamais l'adresse exacte ».
void main() {
  group('arrondirPositionPartagee', () {
    test('arrondit à 3 décimales (~100 m)', () {
      expect(arrondirPositionPartagee(13.5123456), 13.512);
      expect(arrondirPositionPartagee(2.1109), 2.111);
      expect(arrondirPositionPartagee(2.11049), 2.110);
    });

    test('gère les coordonnées négatives (hémisphère/ouest)', () {
      expect(arrondirPositionPartagee(-13.5126), -13.513);
      expect(arrondirPositionPartagee(-0.00049), 0.0);
    });

    test('une valeur déjà grossière est inchangée', () {
      expect(arrondirPositionPartagee(13.5), 13.5);
      expect(arrondirPositionPartagee(0), 0);
    });

    test('deux points à moins de ~50 m tombent dans la même cellule', () {
      // ~11 m d'écart en latitude (0.0001°) : même valeur arrondie.
      expect(
        arrondirPositionPartagee(13.51201),
        arrondirPositionPartagee(13.51199),
      );
    });

    test('le résultat ne révèle jamais plus de 3 décimales', () {
      for (final v in [13.512345, 2.110987, -0.000123, 48.856614]) {
        final arrondi = arrondirPositionPartagee(v);
        // arrondi * 1000 est un entier (à l'epsilon flottant près).
        final mille = arrondi * 1000;
        expect((mille - mille.roundToDouble()).abs() < 1e-6, isTrue,
            reason: 'plus de 3 décimales pour $v → $arrondi');
      }
    });
  });
}
