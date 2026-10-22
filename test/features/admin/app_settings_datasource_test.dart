import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/data/datasources/app_settings_datasource.dart';
import 'package:diaspo_niger/features/admin/data/models/app_settings_model.dart';

/// `getSettings` rendait les défauts sur **toute** erreur, refus de permission
/// compris : l'écran Réglages les affichait comme venus du serveur, et
/// « Enregistrer » écrasait la section serveur avec eux (audit du 2026-10-14,
/// § 5). Une lecture refusée doit lever ; seul un document absent vaut des
/// défauts.
const _lectureRefusee = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''';

const _lectureSeule = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
''';

void main() {
  test('lecture refusée : getSettings lève, ne rend pas les défauts', () async {
    final source = AppSettingsDataSourceImpl(
      firestore: FakeFirebaseFirestore(securityRules: _lectureRefusee),
    );

    await expectLater(
      source.getSettings(),
      throwsA(anything),
      reason: 'des défauts pris pour des réglages lus écrasaient le serveur',
    );
  });

  test('document absent : les défauts, sans lever', () async {
    final source = AppSettingsDataSourceImpl(firestore: FakeFirebaseFirestore());

    final reglages = await source.getSettings();

    expect(reglages.toJson().keys, AppSettingsModel().toJson().keys);
  });

  test('document absent, écriture refusée : les défauts quand même', () async {
    // L'app grand public lit app_config mais n'a pas le droit d'y écrire :
    // la création best-effort des défauts ne doit pas faire échouer la lecture.
    final source = AppSettingsDataSourceImpl(
      firestore: FakeFirebaseFirestore(securityRules: _lectureSeule),
    );

    final reglages = await source.getSettings();

    expect(reglages.toJson().keys, AppSettingsModel().toJson().keys);
  });

  test('document présent : lu tel quel', () async {
    final firestore = FakeFirebaseFirestore();
    final defauts = AppSettingsModel().toJson();
    await firestore.collection('app_config').doc('settings').set(defauts);
    final source = AppSettingsDataSourceImpl(firestore: firestore);

    final reglages = await source.getSettings();

    expect(reglages.toJson().keys, defauts.keys);
  });
}
