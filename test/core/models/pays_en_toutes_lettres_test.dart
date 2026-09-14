import 'dart:io';

import 'package:diaspo_niger/core/constants/profile_options.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/groups_map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pays s'écrit en toutes lettres, en base comme à l'écran.
///
/// `users.country_code` et `groups.country_code` mélangeaient deux formes :
/// `NE`, `CA`, `DZ` à côté de « Angola » et « Cap-Vert ». La conversion vers
/// l'ISO ne connaissait que 28 pays sur les 197 du sélecteur, et tout pays
/// hors de cette liste repartait en toutes lettres. Or l'unicité du groupe
/// officiel porte sur ce texte exact : `AO` et « Angola » faisaient deux
/// groupes officiels pour un même pays, et le groupe nommé d'après la valeur
/// relue s'appelait « Diaspora Niger — NE ».
///
/// Décision du 2026-09-13 : plus aucun code ISO écrit, noms accentués.
void main() {
  group('ProfileOptions.findCountry', () {
    test('ignore accents et casse', () {
      expect(ProfileOptions.findCountry('algerie')?.name, 'Algérie');
      expect(ProfileOptions.findCountry('ÉTATS-UNIS')?.name, 'États-Unis');
      expect(ProfileOptions.findCountry('  senegal ')?.name, 'Sénégal');
      expect(ProfileOptions.findCountry('iles salomon')?.name, 'Îles Salomon');
    });

    test('ignore tirets et apostrophes, typographique comprise', () {
      expect(ProfileOptions.findCountry("Cote d'Ivoire")?.name, "Côte d'Ivoire");
      expect(ProfileOptions.findCountry('Côte d’Ivoire')?.name, "Côte d'Ivoire");
      expect(ProfileOptions.findCountry('Etats Unis')?.name, 'États-Unis');
    });

    test('reconnaît encore les anciens codes ISO, en lecture', () {
      expect(ProfileOptions.findCountry('CA')?.name, 'Canada');
      expect(ProfileOptions.findCountry('ne')?.name, 'Niger');
      // Hors des 28 pays de l'ancienne conversion : le cas qui salissait la base.
      expect(ProfileOptions.findCountry('AO')?.name, 'Angola');
      expect(ProfileOptions.findCountry('CV')?.name, 'Cap-Vert');
    });

    test('rend null sur vide, null ou pays inconnu', () {
      expect(ProfileOptions.findCountry(null), isNull);
      expect(ProfileOptions.findCountry('   '), isNull);
      expect(ProfileOptions.findCountry('Atlantide'), isNull);
    });
  });

  group('ProfileOptions.canonicalCountry — la forme écrite en base', () {
    test('ramène toute écriture d\'un pays connu à son nom', () {
      expect(ProfileOptions.canonicalCountry('AO'), 'Angola');
      expect(ProfileOptions.canonicalCountry('Algerie'), 'Algérie');
      expect(ProfileOptions.canonicalCountry('Niger'), 'Niger');
    });

    test('garde une saisie libre inconnue, et ne produit jamais de chaîne vide',
        () {
      expect(ProfileOptions.canonicalCountry(' Atlantide '), 'Atlantide');
      expect(ProfileOptions.canonicalCountry(''), isNull);
      expect(ProfileOptions.canonicalCountry(null), isNull);
    });
  });

  group('la liste des pays', () {
    test('aucun nom n\'en recouvre un autre une fois plié', () {
      // Sinon deux pays distincts deviendraient le même en base.
      final plies = <String, String>{};
      for (final c in ProfileOptions.countries) {
        final p = foldCountryName(c.name);
        expect(plies.containsKey(p), isFalse,
            reason: '${c.name} et ${plies[p]} se confondent');
        plies[p] = c.name;
      }
    });

    test('aucun nom ne ressemble à un code ISO', () {
      for (final c in ProfileOptions.countries) {
        expect(RegExp(r'^[A-Z]{2}$').hasMatch(c.name), isFalse, reason: c.name);
      }
    });

    test('le libellé affiché garde le drapeau, anciennes valeurs comprises', () {
      expect(countryDisplayLabel('Canada'), '🇨🇦 Canada');
      expect(countryDisplayLabel('CA'), '🇨🇦 Canada');
      expect(countryDisplayLabel('Atlantide'), 'Atlantide');
    });
  });

  test('le référentiel SQL reprend exactement la liste de l\'app', () {
    // `pays_canonique` (base) et `canonicalCountry` (app) doivent reconnaître
    // les mêmes pays sous les mêmes noms : un nom qui diverge ferait écrire
    // deux valeurs pour un même pays, selon qui écrit.
    final sql = File(
      'supabase/migrations/20260913030000_pays_en_toutes_lettres.sql',
    ).readAsStringSync();
    final enBase = {
      for (final m in RegExp(r"^\s+\('((?:[^']|'')+)', '([A-Z]{2})'\)",
              multiLine: true)
          .allMatches(sql))
        m.group(1)!.replaceAll("''", "'"): m.group(2)!,
    };
    final dansApp = {
      for (final c in ProfileOptions.countries) c.name: c.code,
    };
    expect(enBase, dansApp);
  });

  test('la carte des groupes connaît ses pays sous leur nom', () {
    // Clés en ancienne orthographe = aucun marqueur, sans rien signaler.
    final noms = ProfileOptions.countries.map((c) => c.name).toSet();
    for (final cle in countryCentroids.keys) {
      expect(noms, contains(cle), reason: cle);
    }
  });
}
