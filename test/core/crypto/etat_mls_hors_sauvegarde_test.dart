import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 7.4)
/// -------------------------------------------
/// La base SQLite du moteur (`files/mls/`) porte la clé privée de signature de
/// l'appareil, les secrets d'epoch et les arbres de groupe. Le plan la veut
/// chiffrée sous une clé du Keystore ; ce n'est pas encore fait, et deux
/// obstacles mesurés le 2026-09-15 expliquent pourquoi (voir le commentaire de
/// `mls_engine_provider.dart`).
///
/// En attendant, le minimum est qu'elle ne QUITTE pas l'appareil. Sans les
/// deux fichiers de règles ci-dessous, `android:allowBackup` vaut `true` par
/// défaut : la base part dans la sauvegarde Google et dans le transfert vers un
/// téléphone neuf. C'est une exfiltration sans root, sans accès physique, et
/// que rien ne signale.
///
/// Ce que ces tests empêchent, concrètement : qu'un nettoyage de manifeste
/// retire les attributs, ou qu'on n'en corrige qu'un des deux — Android 12 a
/// séparé la sauvegarde cloud du transfert d'appareil, et ignore
/// `fullBackupContent` dès l'API 31. N'en garder qu'un laisse la moitié du
/// chemin ouverte, en silence.

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const manifeste = 'android/app/src/main/AndroidManifest.xml';
  const sauvegarde = 'android/app/src/main/res/xml/regles_sauvegarde.xml';
  const extraction =
      'android/app/src/main/res/xml/regles_extraction_donnees.xml';

  group("l'état MLS ne quitte pas l'appareil", () {
    test('le manifeste désigne les deux jeux de règles', () {
      final x = _lire(manifeste);
      expect(
        x.contains('android:fullBackupContent="@xml/regles_sauvegarde"'),
        isTrue,
        reason: 'sauvegarde cloud, Android 11 et avant',
      );
      expect(
        x.contains(
            'android:dataExtractionRules="@xml/regles_extraction_donnees"'),
        isTrue,
        reason: 'Android 12+, qui ignore fullBackupContent',
      );
    });

    test('la sauvegarde cloud exclut le dossier du moteur', () {
      final x = _lire(sauvegarde);
      expect(x.contains('<exclude domain="file" path="mls/" />'), isTrue);
    });

    test('le transfert d\'appareil l\'exclut AUSSI', () {
      // Les deux blocs comptent. Le transfert par câble ne passe pas par
      // `cloud-backup` : n'exclure que là laisserait la base partir vers un
      // téléphone neuf.
      final x = _lire(extraction);
      final cloud = x.indexOf('<cloud-backup>');
      final transfert = x.indexOf('<device-transfer>');
      expect(cloud, isNonNegative);
      expect(transfert, isNonNegative);
      for (final bloc in [
        x.substring(cloud, x.indexOf('</cloud-backup>')),
        x.substring(transfert, x.indexOf('</device-transfer>')),
      ]) {
        expect(bloc.contains('<exclude domain="file" path="mls/" />'), isTrue);
      }
    });

    test('les deux fichiers ont des commentaires XML légaux', () {
      // Un tiret double dans un commentaire XML est interdit, et `aapt2` le
      // refuse : le 2026-09-15 une ligne de séparation en tirets a fait
      // échouer `:app:mergeReleaseResources` après **sept minutes** de build,
      // alors que rien côté Dart ne bronchait. Le règlement de ces deux
      // fichiers se relit rarement ; qu'il coûte une seconde de test plutôt
      // qu'un build entier.
      for (final chemin in [sauvegarde, extraction]) {
        for (final m
            in RegExp(r'<!--(.*?)-->', dotAll: true).allMatches(_lire(chemin))) {
          expect(
            m.group(1)!.contains('--'),
            isFalse,
            reason: '$chemin : tiret double dans un commentaire XML',
          );
        }
      }
    });

    test('le chemin exclu est bien celui que le moteur utilise', () {
      // Si le provider changeait de dossier, les règles protégeraient un
      // chemin qui n'existe plus — et rien ne le dirait.
      final provider = _lire('lib/core/crypto/mls/mls_engine_provider.dart');
      expect(
        provider.contains("getApplicationSupportDirectory()") &&
            provider.contains("'\${support.path}/mls'"),
        isTrue,
        reason: 'le moteur doit écrire dans <support>/mls, exclu par les règles',
      );
    });
  });

  group('iOS : le meme dossier, par un drapeau', () {
    // Android l'obtient par deux fichiers de regles, declaratifs. iOS n'a pas
    // d'equivalent : c'est un drapeau pose sur le dossier a l'execution.
    // Sans lui, `Library/Application Support` part dans iCloud.
    test("le natif repond a la demande d'exclusion", () {
      final swift = _lire('ios/Runner/AppDelegate.swift');
      expect(swift.contains('case "exclureDeLaSauvegarde"'), isTrue);
      expect(swift.contains('isExcludedFromBackup = true'), isTrue);
    });

    test('il rend un booleen plutot que de lever', () {
      // Une exclusion qui echoue est un probleme de confidentialite ; empecher
      // l'application de demarrer serait une panne.
      final swift = _lire('ios/Runner/AppDelegate.swift');
      expect(
        swift.contains('private static func exclureDeLaSauvegarde(_ chemin: String) -> Bool'),
        isTrue,
      );
    });

    test("le moteur le demande a l'ouverture, et seulement sur iOS", () {
      final src = _lire('lib/core/crypto/mls/mls_engine_provider.dart');
      expect(src.contains('await _exclureDeLaSauvegardeIos(dossier);'), isTrue);
      expect(src.contains('if (!Platform.isIOS) return;'), isTrue);
      // L'appel precede l'ouverture de la base : le drapeau se pose sur un
      // dossier, pas sur un fichier deja ouvert.
      expect(
        src.indexOf('_exclureDeLaSauvegardeIos(dossier)') <
            src.indexOf('Moteur.ouvrir('),
        isTrue,
      );
    });
  });
}
