import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/licences_polices.dart';

/// La page « Licences » (Réglages → Licences open source) montre bien les
/// licences des polices embarquées.
///
/// Les polices sont redistribuées dans l'APK depuis `f6e85f4` ; la licence
/// SIL Open Font License exige que son texte les accompagne. Ce test charge
/// réellement chaque texte par le même chemin que la page — une faute dans un
/// nom de fichier `LICENCE-*.txt` et il échoue, là où l'app n'afficherait
/// qu'une entrée vide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les huit licences de police sont servies à la page Licences', () async {
    // On isole le registre : le binding y inscrit aussi les notices de Flutter,
    // qui ne concernent pas ce test.
    LicenseRegistry.reset();
    enregistrerLicencesPolices();

    final entrees = await LicenseRegistry.licenses.toList();
    final paquets = {for (final e in entrees) ...e.packages};

    for (final famille in famillesPoliceEmbarquees) {
      expect(paquets, contains(famille.nom), reason: '${famille.nom} absente');
    }
    for (final entree in entrees) {
      final texte = entree.paragraphs.map((p) => p.text).join('\n');
      expect(
        texte,
        contains('SIL OPEN FONT LICENSE'),
        reason: '${entree.packages.join()} : texte vide ou méconnaissable',
      );
      expect(
        texte,
        isNot(contains('\r')),
        reason: '${entree.packages.join()} : retour chariot résiduel',
      );
    }
  });

  test('un texte CRLF est rendu sans retour chariot', () {
    // Vu sur appareil le 2026-09-11 : chaque \r restant s'affichait comme un
    // carré. Texte écrit en dur, et non lu sur disque : une copie de travail
    // en LF ferait passer un test de fichier même sans correctif.
    const brut = 'SIL OPEN FONT LICENSE\r\nVersion 1.1\r\n\r\nPREAMBLE\r';
    expect(
      texteLicenceAffichable(brut),
      'SIL OPEN FONT LICENSE\nVersion 1.1\n\nPREAMBLE\n',
    );
  });

  test('les Réglages ouvrent bien cette page', () {
    // Sans point d'entrée, l'enregistrement ne sert à rien : c'était l'état
    // de l'app jusqu'au 2026-09-11.
    final reglages = File(
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ).readAsStringSync();
    expect(reglages, contains('showLicensePage('));
    expect(reglages, contains('l10n.openSourceLicenses'));
  });
}
