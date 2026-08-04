import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/map/domain/city_fallback.dart';

EmbassyEntity _embassy(String id, String city) => EmbassyEntity(
  id: id,
  name: 'Ambassade $id',
  country: 'France',
  city: city,
  address: '154 rue de Longchamp',
);

GroupEntity _group(
  String id, {
  required String? location,
  required bool isPrivate,
}) => GroupEntity(
  id: id,
  name: 'Groupe $id',
  description: '',
  creatorId: 'u1',
  memberIds: const ['u1', 'u2'],
  isPrivate: isPrivate,
  location: location,
);

void main() {
  group('Repli « explorez par ville » (§8c)', () {
    test('un groupe privé n\'est jamais proposé en découverte', () {
      final groups = [
        _group('public', location: 'Paris', isPrivate: false),
        _group('prive', location: 'Paris', isPrivate: true),
      ];

      final visible = CityFallback.groupsIn(groups, 'Paris');

      expect(visible.map((g) => g.id), ['public']);
    });

    test(
      "une ville qui n'a que des groupes privés ne reçoit pas de chip",
      () {
        // Sinon le chip existe et mène à une liste vide : on annonce du
        // contenu qui n'est pas proposable.
        final cities = CityFallback.cities(
          embassies: const [],
          groups: [_group('prive', location: 'Niamey', isPrivate: true)],
        );

        expect(cities, isEmpty);
      },
    );

    test('les villes viennent des ambassades et des groupes publics', () {
      final cities = CityFallback.cities(
        embassies: [_embassy('e1', 'Paris'), _embassy('e2', 'Niamey')],
        groups: [
          _group('g1', location: 'Montréal', isPrivate: false),
          _group('g2', location: 'Paris', isPrivate: false),
        ],
      );

      // Dédoublonnées et triées : Paris apparaît des deux côtés.
      expect(cities, ['Montréal', 'Niamey', 'Paris']);
    });

    test('une ville vide ou absente est ignorée', () {
      final cities = CityFallback.cities(
        embassies: [_embassy('e1', '   ')],
        groups: [
          _group('g1', location: null, isPrivate: false),
          _group('g2', location: '  ', isPrivate: false),
        ],
      );

      expect(cities, isEmpty);
    });

    test('le filtrage par ville tolère les espaces autour du libellé', () {
      final embassies = [_embassy('e1', ' Paris ')];

      expect(CityFallback.embassiesIn(embassies, 'Paris').map((e) => e.id), [
        'e1',
      ]);
    });
  });
}
