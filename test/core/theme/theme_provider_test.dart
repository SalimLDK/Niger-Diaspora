import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/core/theme/theme_provider.dart';

/// Le thème choisi ne survivait jamais à un redémarrage à froid (constaté
/// sur SM A515F le 2026-08-25) : `Réglages` écrivait bien `light`/`green`
/// dans `SharedPreferences`, mais au prochain lancement l'état retombait
/// systématiquement sur `system`/`orange`.
///
/// Cause : `build()` appelait `_loadTheme()`/`_loadColor()`, des méthodes
/// `async` sans aucun `await` interne. Dart exécute un tel corps de façon
/// synchrone à l'appel — `state = mode` s'exécutait donc bien, mais
/// *pendant* `build()`, juste avant que `build()` ne retourne son propre
/// `AppThemeMode.system` par-dessus. Le correctif fait lire `build()`
/// directement dans les préférences, sans détour par `state`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> conteneur(Map<String, Object> prefsInitiales) async {
    SharedPreferences.setMockInitialValues(prefsInitiales);
    await PreferencesService.instance.initialize();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test(
    'un thème déjà enregistré est lu dès le premier build, pas après',
    () async {
      final c = await conteneur({
        'flutter.theme_mode': 'light',
        'flutter.theme_color': 'green',
      });

      // Lecture immédiate : avant le correctif, `build()` retournait encore
      // system/orange ici, et ne se corrigeait jamais.
      expect(c.read(themeModeNotifierProvider), AppThemeMode.light);
      expect(c.read(themeColorNotifierProvider), AppThemeColor.green);
    },
  );

  test('sans préférence enregistrée, le défaut reste système/orange', () async {
    final c = await conteneur({});

    expect(c.read(themeModeNotifierProvider), AppThemeMode.system);
    expect(c.read(themeColorNotifierProvider), AppThemeColor.orange);
  });

  test('changer le thème met à jour l\'état et le persiste', () async {
    final c = await conteneur({});

    await c
        .read(themeModeNotifierProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    await c
        .read(themeColorNotifierProvider.notifier)
        .setThemeColor(AppThemeColor.green);

    expect(c.read(themeModeNotifierProvider), AppThemeMode.dark);
    expect(c.read(themeColorNotifierProvider), AppThemeColor.green);

    // Relit via le même service que le code de prod, plutôt qu'un second
    // `SharedPreferences.getInstance()` — le plugin met en cache son
    // singleton, un second appel dans le même test ne revoit pas forcément
    // le magasin réinitialisé par `setMockInitialValues` de ce test-ci.
    expect(PreferencesService.instance.themeMode, 'dark');
    expect(PreferencesService.instance.themeColor, 'green');
  });
}
