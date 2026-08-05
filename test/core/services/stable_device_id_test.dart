import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/stable_device_id.dart';

/// Identifiant d'appareil E2EE stable entre deux vidages de données.
///
/// Constaté sur appareil le 2026-08-04 (SM A515F) : la liste des appareils
/// connectés est passée de 2 à 3 entrées, parce que l'identifiant était un UUID
/// aléatoire rangé dans le stockage sécurisé — perdu au vidage, donc recréé.
/// Les identités mortes s'accumulaient, et tout message destiné au compte doit
/// être chiffré pour chacune.
void main() {
  group('deviceIdFromInstallation', () {
    const installation = 'a1b2c3d4e5f60718';
    const user = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2';

    test('déterministe : même appareil + même compte = même identifiant', () {
      final first = deviceIdFromInstallation(installation, user);
      final second = deviceIdFromInstallation(installation, user);

      expect(first, second,
          reason: 'sans ça, la ligne e2ee_devices serait dupliquée à chaque '
              'régénération de clés — le bug qu on corrige');
    });

    test('cloisonné par compte : deux comptes sur le même téléphone diffèrent',
        () {
      final a = deviceIdFromInstallation(installation, 'compte-a');
      final b = deviceIdFromInstallation(installation, 'compte-b');

      expect(a, isNot(b),
          reason: 'le serveur ne doit pas pouvoir rapprocher deux comptes '
              'partageant un appareil');
    });

    test('deux appareils distincts donnent des identifiants distincts', () {
      final a = deviceIdFromInstallation('aaaaaaaaaaaaaaaa', user);
      final b = deviceIdFromInstallation('bbbbbbbbbbbbbbbb', user);

      expect(a, isNot(b));
    });

    test('l identifiant brut ne transparaît pas dans le résultat', () {
      final id = deviceIdFromInstallation(installation, user);

      expect(id.contains(installation), isFalse,
          reason: 'seul un condensé est publié, jamais le SSAID lui-même');
      expect(id, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });
  });
}
