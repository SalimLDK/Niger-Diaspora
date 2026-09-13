import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/models/country.dart';

/// Reconnaissance d'un pays de l'énumération `Country` (marketplace) écrit
/// sous l'une de ses formes.
///
/// Historique : ces tests gardaient la normalisation vers l'ISO-2, abandonnée
/// le 2026-09-13 au profit des noms en toutes lettres. À l'origine,
/// les colonnes `users.country_code` et `groups.country_code` mélangeaient
/// codes et libellés — `CA` à côté de `Canada`, `NE` à côté de `Niger` — parce
/// que deux écrans y écrivaient un libellé : le profil (issu du géocodage
/// inverse) et la création de groupe (sa liste `_hostCountries` codée en dur).
/// Toute comparaison d'égalité échouait alors en silence : le filtre par pays
/// de la liste des groupes ne retenait qu'une partie des groupes du pays visé,
/// et le repli sur `'NE'` de `_loadDefaultCountryFilter` ne se déclenchait
/// jamais.
///
/// Les cas d'accents et de ponctuation ne sont pas théoriques : la liste de
/// `create_group_screen` propose « États-Unis » quand [CountryExtension.label]
/// rend « Etats-Unis », et « Côte d'Ivoire » s'écrit des deux façons selon la
/// source. Une comparaison stricte les rate sans rien signaler.
void main() {
  group('Country.fromString', () {
    test('reconnaît un code ISO, quelle que soit la casse', () {
      expect(CountryExtension.fromString('NE'), Country.niger);
      expect(CountryExtension.fromString('ne'), Country.niger);
      expect(CountryExtension.fromString('CA'), Country.canada);
    });

    test('reconnaît le nom d\'énumération', () {
      expect(CountryExtension.fromString('niger'), Country.niger);
      expect(CountryExtension.fromString('burkinaFaso'), Country.burkinaFaso);
    });

    test('reconnaît le libellé, y compris composé', () {
      expect(CountryExtension.fromString('Canada'), Country.canada);
      expect(CountryExtension.fromString('Burkina Faso'), Country.burkinaFaso);
      expect(CountryExtension.fromString('Royaume-Uni'), Country.unitedKingdom);
    });

    test('ignore les accents — « États-Unis » vs le libellé « Etats-Unis »', () {
      expect(CountryExtension.fromString('États-Unis'), Country.usa);
      expect(CountryExtension.fromString('Etats-Unis'), Country.usa);
    });

    test('ignore tirets et apostrophes — « Côte d\'Ivoire »', () {
      expect(CountryExtension.fromString('Côte d\'Ivoire'), Country.coteDIvoire);
      expect(CountryExtension.fromString('Cote d\'Ivoire'), Country.coteDIvoire);
      // Apostrophe typographique, celle que produisent les claviers iOS et
      // certains presse-papiers.
      expect(CountryExtension.fromString('Côte d’Ivoire'), Country.coteDIvoire);
      // En revanche « cote divoire », sans séparateur du tout, n'est PAS
      // reconnu — et c'est voulu : la normalisation ramène la ponctuation à un
      // espace, elle ne devine pas les mots collés.
      expect(CountryExtension.fromString('cote divoire'), isNull);
    });

    test('tolère les espaces superflus', () {
      expect(CountryExtension.fromString('  Niger  '), Country.niger);
    });

    test('rend null sur vide, null, ou pays inconnu', () {
      expect(CountryExtension.fromString(null), isNull);
      expect(CountryExtension.fromString(''), isNull);
      expect(CountryExtension.fromString('Atlantide'), isNull);
    });
  });

  // `CountryExtension.toIsoCode` a disparu le 2026-09-13 : plus aucune
  // colonne ne porte de code ISO. Il ne connaissait que ces 28 pays, et tout
  // pays du sélecteur hors de la liste repartait en toutes lettres à côté des
  // codes. La forme écrite en base est désormais
  // `ProfileOptions.canonicalCountry` — voir `pays_en_toutes_lettres_test.dart`.
}
