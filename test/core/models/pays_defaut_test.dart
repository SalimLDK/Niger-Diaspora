import 'dart:io';

import 'package:diaspo_niger/core/models/country.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un groupe sans pays est invisible, pas « non filtré ».
///
/// `_applyFilters` (`groups_screen.dart`) filtre sur
/// `g.country == _selectedCountry`, et `_loadDefaultCountryFilter` pose un
/// filtre pays **tout seul** au premier affichage — celui du profil, ou `NE` à
/// défaut. Un groupe à `country_code` nul est donc écarté de « Découvrir »
/// sans que l'utilisateur ait rien demandé, et rien à l'écran ne le dit.
/// Un groupe était dans ce cas en base le 2026-08-06.
///
/// Décision : le pays par défaut est le Niger.
void main() {
  test('le défaut vaut bien le code du Niger', () {
    // `Country.niger.code` est un getter d'extension, donc pas une constante :
    // il ne peut pas servir de valeur par défaut. Les deux sont donc écrits
    // séparément, et c'est ce test qui interdit qu'ils divergent.
    expect(kDefaultCountryCode, Country.niger.code);
    expect(kDefaultCountryCode, 'NE');
  });

  test('le défaut est un code ISO-2, pas un libellé', () {
    // Le mélange `Canada`/`CA` en base venait exactement de là.
    expect(kDefaultCountryCode.length, 2);
    expect(kDefaultCountryCode, kDefaultCountryCode.toUpperCase());
    expect(CountryExtension.toIsoCode('Niger'), kDefaultCountryCode);
  });

  group('le défaut est posé sur les deux chemins de création', () {
    String lire(String chemin) {
      final f = File(chemin);
      expect(f.existsSync(), isTrue, reason: '$chemin introuvable');
      return f.readAsStringSync();
    }

    test('le datasource Supabase — point de passage de toute création', () {
      final source = lire(
        'lib/features/groups/data/datasources/group_supabase_datasource.dart',
      );
      expect(source, contains('kDefaultCountryCode'));
      expect(
        source,
        isNot(contains("'p_country_code': group.country,")),
        reason: 'le pays nul repartirait tel quel vers `insert_group`',
      );
    });

    test('l\'écran de création', () {
      final source = lire(
        'lib/features/groups/presentation/screens/create_group_screen.dart',
      );
      expect(source, contains('kDefaultCountryCode'));
    });
  });

  test('régression : plus de « NE » en dur dans l\'écran des groupes', () {
    // Trois endroits décidaient du Niger séparément. Le jour où le défaut
    // change, un littéral oublié fait diverger le filtre par défaut de la
    // valeur écrite en base — et le groupe redevient invisible.
    final source = File(
      'lib/features/groups/presentation/screens/groups_screen.dart',
    ).readAsStringSync();
    expect(
      RegExp(r"""(?<!kDefaultCountryCode)['"]NE['"]""").hasMatch(source),
      isFalse,
      reason: 'utiliser `kDefaultCountryCode`',
    );
    expect(source, contains('kDefaultCountryCode'));
  });

  test('la migration qui reprend l\'existant est versionnée', () {
    // Elle n'a PAS pu être appliquée depuis cette session : l'écriture en base
    // a été refusée par le garde-fou de permissions. Tant qu'elle n'est pas
    // passée, le groupe déjà nul reste invisible — le côté app ne couvre que
    // les créations à venir.
    final migration = File(
      'supabase/migrations/20260806170000_groups_country_code_defaut_ne.sql',
    );
    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();
    expect(sql, contains('SET country_code = \'NE\''));
    expect(sql, contains('SET DEFAULT \'NE\''));
    expect(sql, contains('trg_groups_country_code_defaut'));
  });
}
