import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';

/// « On a une position » et « on lui fait confiance » sont deux choses
/// différentes, et les confondre a déjà coûté deux fois sur cet écran :
///
/// - `toEntity()` remplaçait une latitude nulle par `0.0`, ce qui rendait
///   `latitude != null` toujours vrai : le bouton « Y aller » était actif sur
///   les 32 postes et ouvrait la carte dans le golfe de Guinée ;
/// - puis, une fois les fiches géocodées, Copenhague s'est retrouvée avec des
///   coordonnées à 5 km d'une autre source. Le bouton restait actif et orange,
///   exactement comme sur une fiche sûre, pendant que la réserve juste
///   au-dessus prévenait du contraire.
///
/// Ce test verrouille la règle : tout bouton d'itinéraire teste [canNavigate],
/// jamais `latitude != null`.
void main() {
  EmbassyEntity poste({
    double? lat,
    double? lon,
    bool douteuse = false,
  }) => EmbassyEntity(
    id: 'x',
    name: 'Ambassade du Niger',
    country: 'Danemark',
    city: 'Copenhague',
    address: 'Niels Juels Gade 5',
    latitude: lat,
    longitude: lon,
    isPositionUncertain: douteuse,
  );

  group('canNavigate', () {
    test('vrai quand la position est connue et fiable', () {
      expect(poste(lat: 55.72, lon: 12.57).canNavigate, isTrue);
    });

    test('faux sans coordonnées — le cas des 2 postes non géocodés', () {
      expect(poste().canNavigate, isFalse);
      expect(poste().hasCoordinates, isFalse);
    });

    test('faux quand la position est douteuse, MÊME avec des coordonnées', () {
      final p = poste(lat: 55.72, lon: 12.57, douteuse: true);
      // C'est tout l'intérêt du drapeau : la position existe...
      expect(p.hasCoordinates, isTrue);
      // ...mais on refuse d'y envoyer quelqu'un.
      expect(p.canNavigate, isFalse);
    });

    test('une longitude seule ne suffit pas', () {
      expect(poste(lat: 55.72).canNavigate, isFalse);
      expect(poste(lon: 12.57).canNavigate, isFalse);
    });

    test('la position est fiable par défaut', () {
      // Les 29 autres fiches géocodées ne portent pas le drapeau : leur bouton
      // ne doit pas être grisé par accident.
      expect(poste(lat: 1, lon: 1).isPositionUncertain, isFalse);
    });
  });

  group('(0, 0) reste une position réelle', () {
    test('le golfe de Guinée est navigable, il ne faut pas le filtrer', () {
      // Garde-fou contre un « correctif » tentant : traiter (0, 0) comme
      // absent. C'est une vraie coordonnée ; le défaut d'origine était le
      // `?? 0.0` qui l'inventait, pas le point lui-même.
      expect(poste(lat: 0, lon: 0).canNavigate, isTrue);
    });
  });
}
