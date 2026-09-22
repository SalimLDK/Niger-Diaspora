// Vu sur Pixel 10 Pro XL le 2026-09-22 (build Play 1.2.2+26), compte de
// Salim : hors du drapeau `mlsMessagesComptes`, mais dans un 1:1 chiffré que
// l'autre bout a basculé — deux appareils MLS actifs dans `mls_devices`.
// Réglages › Sécurité › Appareils ne montrait que la liste Signal, sans
// registre ni code de sécurité : aucune clé vérifiable. Voir
// TESTS_APPAREIL_A_FAIRE.md, « MLS ouvert pour un seul compte (phase 5) ».
import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/features/settings/presentation/screens/devices_screen.dart';
import 'package:flutter_test/flutter_test.dart';

MlsDeviceRecord _appareil({DateTime? revoque}) => MlsDeviceRecord(
      id: 'd',
      userId: 'salim',
      stableId: 's',
      name: 'Pixel',
      platform: 'android',
      mlsIdentity: 'salim:s',
      createdAt: DateTime.utc(2026, 9, 20),
      lastSeenAt: DateTime.utc(2026, 9, 22),
      revokedAt: revoque,
    );

void main() {
  group('Registre MLS en plus de la liste Signal', () {
    test('hors drapeau, un appareil MLS actif : le registre s\'ajoute', () {
      expect(
        registreMlsEnPlus(drapeauMls: false, appareilsMls: [_appareil()]),
        isTrue,
      );
    });

    test('hors drapeau, que des appareils révoqués : rien de plus', () {
      expect(
        registreMlsEnPlus(
          drapeauMls: false,
          appareilsMls: [_appareil(revoque: DateTime.utc(2026, 9, 21))],
        ),
        isFalse,
      );
    });

    test('hors drapeau, aucun appareil ou registre pas encore lu : rien', () {
      expect(registreMlsEnPlus(drapeauMls: false, appareilsMls: const []),
          isFalse);
      expect(registreMlsEnPlus(drapeauMls: false, appareilsMls: null),
          isFalse);
    });

    test('drapeau ouvert : jamais « en plus », le registre REMPLACE déjà', () {
      expect(
        registreMlsEnPlus(drapeauMls: true, appareilsMls: [_appareil()]),
        isFalse,
      );
    });
  });

  group('Branchement dans l\'écran', () {
    final src = File(
      'lib/features/settings/presentation/screens/devices_screen.dart',
    ).readAsStringSync();

    test('le drapeau garde son écran MLS seul', () {
      expect(src, contains('? _buildMlsBody(context)'));
    });

    test('hors drapeau, la liste reçoit le registre quand il sert', () {
      expect(src, contains('registreMlsEnPlus('));
      expect(src, contains('registreDe: avecRegistre ? uid : null'));
      expect(src, contains('_MlsRegistrySection(userId: registreDe)'));
    });

    test('une liste Signal vide ne cache pas le registre', () {
      // Sinon un compte qui n'a jamais chiffré en Signal retombait sur
      // « Aucun appareil inscrit » — exactement ce qu'on corrige.
      expect(src, contains('_devices.isEmpty && !avecRegistre'));
    });
  });
}
