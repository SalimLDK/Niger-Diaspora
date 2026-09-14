import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/profile/data/models/profile_model.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';

/// `villeId` traverse quatre conversions entre la ligne Postgres et l'écran :
/// `fromJson`, `toEntity`, `fromEntity`, `toJson`. En oublier une ne casse
/// rien de visible — le profil s'enregistre, l'écran affiche la bonne ville —
/// mais `users.ville_id` repart à `null` au premier enregistrement, et le
/// groupe de ville ne s'ouvre jamais pour personne. C'est le genre de panne
/// qu'on ne voit qu'en regardant la base.
void main() {
  test('villeId survit à l\'aller-retour modèle ↔ entité', () {
    const modele = ProfileModel(id: 'u1', villeId: 7, currentCity: 'Montréal');

    final entite = modele.toEntity();
    expect(entite.villeId, 7);
    expect(entite.currentCity, 'Montréal');

    final retour = ProfileModel.fromEntity(entite);
    expect(retour.villeId, 7);
  });

  test('villeId survit à l\'aller-retour JSON', () {
    const modele = ProfileModel(id: 'u1', villeId: 7);
    expect(ProfileModel.fromJson(modele.toJson()).villeId, 7);
  });

  test('« Autre ville » : pas de ville retenue, le texte reste', () {
    const entite = ProfileEntity(id: 'u1', currentCity: 'Almoustapha');

    final modele = ProfileModel.fromEntity(entite);
    expect(modele.villeId, isNull);
    expect(modele.currentCity, 'Almoustapha');
    expect(modele.toEntity().villeId, isNull);
  });
}
