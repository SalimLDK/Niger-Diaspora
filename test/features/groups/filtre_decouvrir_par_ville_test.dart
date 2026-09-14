import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/lieux_des_groupes_provider.dart';

/// Le filtre Découvrir enchaîne pays puis ville.
///
/// Les deux règles qui comptent ne se voient pas à la relecture, et l'écran
/// des groupes a déjà eu **trois causes indistinguables d'écran blanc** :
///
///   1. tant que les lieux ne sont pas chargés, le filtre ne filtre RIEN.
///      Répondre « aucun groupe » parce qu'on ne sait pas encore où ils sont
///      viderait l'onglet le temps d'un aller-retour, sans un mot ;
///   2. la rangée des villes n'apparaît pas tant qu'il n'y a rien à y mettre.
///
/// Le troisième garde-fou — changer de pays remet la ville à zéro — vit dans
/// le `setState` de l'écran : « Montréal » sous « Algérie » ne filtrerait
/// rien, et c'est exactement l'écran blanc sans cause visible.
GroupEntity _groupe(String id, String? pays) => GroupEntity(
      id: id,
      name: 'Groupe $id',
      description: '',
      creatorId: 'u1',
      country: pays,
      createdAt: DateTime(2026, 9, 14),
    );

LieuDeGroupe _ville(String id, String nom) => LieuDeGroupe(
      groupId: id,
      latitude: 45.5,
      longitude: -73.5,
      estUneVille: true,
      villeNom: nom,
    );

LieuDeGroupe _pays(String id) => LieuDeGroupe(
      groupId: id,
      latitude: 56.1,
      longitude: -106.3,
      estUneVille: false,
    );

void main() {
  final groupes = [
    _groupe('g-ca', 'Canada'), // le groupe du pays
    _groupe('g-mtl', 'Canada'),
    _groupe('g-tor', 'Canada'),
    _groupe('g-dz', 'Algérie'),
    _groupe('g-sans', null),
  ];
  final lieux = {
    'g-ca': _pays('g-ca'),
    'g-mtl': _ville('g-mtl', 'Montréal'),
    'g-tor': _ville('g-tor', 'Toronto'),
    'g-dz': _pays('g-dz'),
  };

  group('les villes proposées', () {
    test('sont celles du pays choisi, et seulement les villes', () {
      // « g-ca » est le groupe du Canada : un pays, pas une ville. Il ne doit
      // pas apparaître comme une marche du filtre.
      expect(villesDuPays(groupes, 'Canada', lieux), ['Montréal', 'Toronto']);
      expect(villesDuPays(groupes, 'Algérie', lieux), isEmpty);
    });

    test('aucune sans pays choisi — la rangée n\'existe pas', () {
      expect(villesDuPays(groupes, null, lieux), isEmpty);
    });

    test('aucune tant que les lieux ne sont pas chargés', () {
      expect(villesDuPays(groupes, 'Canada', null), isEmpty);
      expect(villesDuPays(groupes, 'Canada', const {}), isEmpty);
    });
  });

  group('le filtre par ville', () {
    test('ne garde que les groupes de cette ville', () {
      final filtres = filtrerParVille(groupes, 'Montréal', lieux);
      expect(filtres.map((g) => g.id), ['g-mtl']);
    });

    test('sans ville choisie, ne retire rien', () {
      expect(filtrerParVille(groupes, null, lieux), hasLength(groupes.length));
    });

    test('lieux non chargés : ne filtre RIEN, surtout pas tout', () {
      // La faute serait de rendre une liste vide : l'onglet Découvrir se
      // viderait pendant le chargement, sans message, et le premier
      // diagnostic serait « il n'y a aucun groupe ».
      expect(filtrerParVille(groupes, 'Montréal', null),
          hasLength(groupes.length));
      expect(filtrerParVille(groupes, 'Montréal', const {}),
          hasLength(groupes.length));
    });

    test('une ville sans groupe rend une liste vide, pas la liste entière', () {
      expect(filtrerParVille(groupes, 'Niamey', lieux), isEmpty);
    });
  });
}
