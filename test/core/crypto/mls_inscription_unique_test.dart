import 'dart:async';

import 'package:diaspo_niger/core/crypto/mls/mls_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// La passerelle inscrit l'appareil à la première opération MLS. Elle ne
/// mémorisait qu'une inscription TERMINÉE : le 2026-09-16, trois opérations
/// arrivées ensemble sur le Pixel ont lancé trois inscriptions, et trois
/// lignes `mls_devices` sont nées en 190 ms.
void main() {
  test('trois appels simultanés ne lancent qu une inscription', () async {
    var inscriptions = 0;
    final fin = Completer<String>();
    final appareil = volUnique(() {
      inscriptions++;
      return fin.future;
    });

    final appels = [appareil(), appareil(), appareil()];
    fin.complete('fiche');

    expect(await Future.wait(appels), ['fiche', 'fiche', 'fiche']);
    expect(inscriptions, 1);
  });

  test('une inscription réussie est gardée', () async {
    var inscriptions = 0;
    final appareil = volUnique(() async {
      inscriptions++;
      return 'fiche';
    });

    await appareil();
    await appareil();

    expect(inscriptions, 1);
  });

  test('un échec est oublié : l appel suivant réessaie', () async {
    // Le pont de session Supabase n'est pas prêt dans les premières secondes :
    // un échec mémorisé rendrait MLS inutilisable pour tout le processus.
    var inscriptions = 0;
    final appareil = volUnique<String>(() async {
      if (++inscriptions == 1) throw StateError('Session non établie');
      return 'fiche';
    });

    await expectLater(appareil(), throwsStateError);
    expect(await appareil(), 'fiche');
    expect(inscriptions, 2);
  });
}
