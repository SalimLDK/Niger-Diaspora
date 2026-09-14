import 'dart:io';

import 'package:diaspo_niger/core/constants/profile_options.dart';
import 'package:diaspo_niger/core/models/country.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un groupe sans pays est invisible, pas « non filtré ».
///
/// `_applyFilters` (`groups_screen.dart`) filtre sur
/// `g.country == _selectedCountry`, et `_loadDefaultCountryFilter` pose un
/// filtre pays **tout seul** au premier affichage — celui du profil, ou le
/// Niger à défaut. Un groupe à `country_code` nul est donc écarté de
/// « Découvrir » sans que l'utilisateur ait rien demandé, et rien à l'écran ne
/// le dit. Un groupe était dans ce cas en base le 2026-08-06.
///
/// Décision : le pays par défaut est le Niger — en toutes lettres depuis le
/// 2026-09-13, comme tout pays en base.
void main() {
  test('le défaut est le Niger, écrit comme dans la liste des pays', () {
    expect(kDefaultCountry, 'Niger');
    expect(ProfileOptions.canonicalCountry(kDefaultCountry), kDefaultCountry);
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
      expect(source, contains('kDefaultCountry'));
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
      expect(source, contains('kDefaultCountry'));
    });
  });

  test('régression : plus de « NE » en dur dans l\'écran des groupes', () {
    // Trois endroits décidaient du Niger séparément. Le jour où le défaut
    // change, un littéral oublié fait diverger le filtre par défaut de la
    // valeur écrite en base — et le groupe redevient invisible.
    final source = File(
      'lib/features/groups/presentation/screens/groups_screen.dart',
    ).readAsStringSync();
    expect(RegExp(r"""['"](NE|Niger)['"]""").hasMatch(source), isFalse,
        reason: 'utiliser `kDefaultCountry`');
    expect(source, contains('kDefaultCountry'));
  });

  test('la base pose le même défaut', () {
    // Le `DEFAULT` de la colonne et le déclencheur couvrent les écrivains qui
    // ne passent pas par l'app. Ils valaient 'NE' (20260806170000).
    final sql = File(
      'supabase/migrations/20260913030000_pays_en_toutes_lettres.sql',
    ).readAsStringSync();
    expect(sql, contains("SET DEFAULT '$kDefaultCountry'"));
    expect(sql, contains('groups_country_code_defaut'));
    // Dernier repli du COALESCE du déclencheur. `\r?` : le dépôt est extrait
    // en CRLF sur ce poste.
    expect(RegExp("'$kDefaultCountry'\\r?\\n\\s*\\);").hasMatch(sql), isTrue);
  });
}
