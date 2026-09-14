import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/villes_service.dart';

/// Le libellé d'une ville dans la liste de suggestions.
///
/// La région n'est là que pour distinguer deux homonymes d'un même pays. Vu
/// sur appareil le 2026-09-14, elle distinguait souvent d'elle-même :
/// « Niamey, Niamey », « Zinder, Zinder » — au Niger la région porte le nom
/// de son chef-lieu, donc la moitié du pays s'affichait en double.
Ville _ville(String nom, String? region) => Ville(
      id: 1,
      nom: nom,
      pays: 'Niger',
      region: region,
      latitude: 13.5,
      longitude: 2.1,
      population: 1,
    );

void main() {
  test('la région distingue quand elle distingue', () {
    expect(_ville('Montréal', 'Quebec').libelle, 'Montréal, Quebec');
    expect(_ville('Springfield', 'Missouri').libelle, 'Springfield, Missouri');
  });

  test('elle se tait quand elle répète le nom de la ville', () {
    expect(_ville('Niamey', 'Niamey').libelle, 'Niamey');
    expect(_ville('Zinder', 'Zinder').libelle, 'Zinder');
  });

  test('les accents ne font pas deux noms différents', () {
    // GeoNames ne donne les régions qu'en ASCII : sans pliage, la ville de
    // Québec s'afficherait « Québec, Quebec ».
    expect(_ville('Québec', 'Quebec').libelle, 'Québec');
  });

  test('sans région, le nom seul', () {
    expect(_ville('Bouza', null).libelle, 'Bouza');
    expect(_ville('Bouza', '').libelle, 'Bouza');
  });
}
