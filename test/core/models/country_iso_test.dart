import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/models/country.dart';

/// Garde-fou sur la normalisation des pays en ISO-2.
///
/// Les colonnes `users.country_code` et `groups.country_code` mélangeaient
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

  group('CountryExtension.toIsoCode', () {
    test('convertit le libellé en code — le cas qui salissait la base', () {
      expect(CountryExtension.toIsoCode('Niger'), 'NE');
      expect(CountryExtension.toIsoCode('Canada'), 'CA');
      expect(CountryExtension.toIsoCode('États-Unis'), 'US');
    });

    test('est idempotent : un code déjà ISO ressort inchangé', () {
      expect(CountryExtension.toIsoCode('NE'), 'NE');
      expect(CountryExtension.toIsoCode('CA'), 'CA');
    });

    test('rend null sur un pays non reconnu, pour que l\'appelant garde la '
        'valeur brute plutôt que de la perdre', () {
      expect(CountryExtension.toIsoCode('Atlantide'), isNull);
      expect(CountryExtension.toIsoCode(null), isNull);
    });

    test('chaque pays connu a un code à deux lettres, sauf le fourre-tout', () {
      for (final c in Country.values) {
        if (c == Country.other) continue;
        expect(c.code.length, 2, reason: 'code ISO-2 attendu pour ${c.name}');
        // Et il doit se reconnaître lui-même, dans les trois écritures.
        expect(CountryExtension.toIsoCode(c.code), c.code);
        expect(CountryExtension.toIsoCode(c.label), c.code);
        expect(CountryExtension.toIsoCode(c.name), c.code);
      }
    });
  });
}
