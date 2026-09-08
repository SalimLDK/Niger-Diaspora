import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/embassies/domain/zone_geographique.dart';

/// Les coordonnées ci-dessous sont celles des postes réels de l'annuaire
/// (migration `20260908120000_coordonnees_postes_diplomatiques.sql`). Un
/// classement par zone ne se relit pas : il faut des points nommés pour voir
/// qu'Alger tombait en Europe et Riyad en Afrique.
void main() {
  group('ZoneGeographique.pourCoordonnees', () {
    test('les postes africains restent en Afrique, Alger compris', () {
      // Alger est à 36,78° N : il tombait dans la boîte « Europe » (34-72° N),
      // testée avant l'Afrique. L'écran l'affichait sous « Europe ».
      expect(ZoneGeographique.pourCoordonnees(36.775935, 3.010507),
          ZoneGeographique.afrique);
      expect(ZoneGeographique.pourCoordonnees(32.868841, 13.135106),
          ZoneGeographique.afrique); // Tripoli
      expect(ZoneGeographique.pourCoordonnees(14.698142, -17.468309),
          ZoneGeographique.afrique); // Dakar
      expect(ZoneGeographique.pourCoordonnees(-25.743449, 28.220634),
          ZoneGeographique.afrique); // Pretoria
      expect(ZoneGeographique.pourCoordonnees(34.020882, -6.841650),
          ZoneGeographique.afrique); // Rabat, à 34,02° N
    });

    test('la péninsule arabique est en Asie, pas en Afrique', () {
      // L'Afrique s'étendait jusqu'au 52e méridien : Riyad y tombait.
      expect(ZoneGeographique.pourCoordonnees(24.724452, 46.673971),
          ZoneGeographique.asie); // Riyad
      expect(ZoneGeographique.pourCoordonnees(21.485811, 39.192505),
          ZoneGeographique.asie); // Djeddah
      expect(ZoneGeographique.pourCoordonnees(29.375859, 47.977405),
          ZoneGeographique.asie); // Koweït
      expect(ZoneGeographique.pourCoordonnees(25.285447, 51.531040),
          ZoneGeographique.asie); // Doha
      expect(ZoneGeographique.pourCoordonnees(25.204849, 55.270782),
          ZoneGeographique.asie); // Dubaï
    });

    test("la mer Rouge ne coupe pas l'Afrique de l'Est en deux", () {
      // Une coupure verticale au 34e méridien les aurait envoyés en Asie.
      expect(ZoneGeographique.pourCoordonnees(19.617779, 37.216413),
          ZoneGeographique.afrique); // Port-Soudan
      expect(ZoneGeographique.pourCoordonnees(15.322865, 38.925050),
          ZoneGeographique.afrique); // Asmara
      expect(ZoneGeographique.pourCoordonnees(15.500654, 32.559899),
          ZoneGeographique.afrique); // Khartoum
      expect(ZoneGeographique.pourCoordonnees(30.044420, 31.235712),
          ZoneGeographique.afrique); // Le Caire
      expect(ZoneGeographique.pourCoordonnees(8.999161, 38.719148),
          ZoneGeographique.afrique); // Addis-Abeba
    });

    test("l'Europe garde Ankara et Moscou, a l'est de la mer Rouge", () {
      expect(ZoneGeographique.pourCoordonnees(48.868389, 2.275326),
          ZoneGeographique.europe); // Paris
      expect(ZoneGeographique.pourCoordonnees(55.722402, 12.573758),
          ZoneGeographique.europe); // Copenhague
      expect(ZoneGeographique.pourCoordonnees(41.913474, 12.460900),
          ZoneGeographique.europe); // Rome
      expect(ZoneGeographique.pourCoordonnees(39.890525, 32.874201),
          ZoneGeographique.europe); // Ankara
      expect(ZoneGeographique.pourCoordonnees(55.755826, 37.617300),
          ZoneGeographique.europe); // Moscou, à l'est du 32,5e méridien
    });

    test('les Amériques et le reste de l\'Asie', () {
      expect(ZoneGeographique.pourCoordonnees(38.912379, -77.049182),
          ZoneGeographique.ameriqueDuNord); // Washington
      expect(ZoneGeographique.pourCoordonnees(23.113592, -82.366592),
          ZoneGeographique.ameriqueDuNord); // La Havane
      expect(ZoneGeographique.pourCoordonnees(39.904200, 116.407396),
          ZoneGeographique.asie); // Pékin
      expect(ZoneGeographique.pourCoordonnees(28.613939, 77.209021),
          ZoneGeographique.asie); // New Delhi
    });

    test('toutes les zones produites sont affichables', () {
      // L'écran ne rend que les zones presentes dans `ordre` : une valeur
      // hors liste disparait de l'annuaire sans erreur ni trace.
      for (final point in const [
        [36.775935, 3.010507],
        [24.724452, 46.673971],
        [48.868389, 2.275326],
        [38.912379, -77.049182],
        [-23.550520, -46.633308],
        [39.904200, 116.407396],
        [-33.868820, 151.209290],
        [0.0, 0.0],
      ]) {
        expect(
          ZoneGeographique.ordre,
          contains(ZoneGeographique.pourCoordonnees(point[0], point[1])),
          reason: 'point ${point[0]}, ${point[1]}',
        );
      }
    });

    test('le repli des postes sans coordonnées figure dans l\'ordre', () {
      // Il venait de `l10n.otherConversations` : « Autres » en francais,
      // « Others » en anglais -- donc absent de `ordre`, donc invisible.
      expect(ZoneGeographique.ordre, contains(ZoneGeographique.autres));
    });
  });
}
