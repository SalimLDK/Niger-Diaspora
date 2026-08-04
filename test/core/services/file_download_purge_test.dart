import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/file_download_service.dart';

/// Purge des pièces jointes téléchargées à la déconnexion.
///
/// `FileDownloadService` écrit les pièces jointes **en clair** dans le
/// répertoire documents, et les indexe par `media_dl_<messageId>` dans les
/// préférences. Rien ne les effaçait : les fichiers d'un compte survivaient à
/// une déconnexion, alors même que les conversations dont ils proviennent sont
/// chiffrées de bout en bout.
///
/// Ces clés sont dynamiques : la purge par constantes de `PreferencesService`
/// ne pouvait pas les couvrir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dl_purge_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File creerFichier(String nom) =>
      File('${tempDir.path}/$nom')..writeAsStringSync('contenu de la piece jointe');

  test('les fichiers et leur index disparaissent', () async {
    final piece = creerFichier('Compte rendu de la reunion.pdf');
    final note = creerFichier('voice_note_m2.m4a');
    SharedPreferences.setMockInitialValues({
      'media_dl_m1': piece.path,
      'media_dl_m2': note.path,
      // Une clé étrangère, qui ne doit pas être touchée.
      'theme_mode': 'dark',
    });

    final supprimes = await FileDownloadService().clearDownloadedFiles();

    expect(supprimes, 2);
    expect(piece.existsSync(), isFalse, reason: 'pièce jointe en clair');
    expect(note.existsSync(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('media_dl_')), isEmpty);
    expect(prefs.getString('theme_mode'), 'dark',
        reason: 'la purge ne doit toucher que son propre préfixe');
  });

  test('un index orphelin est nettoyé sans faire échouer la purge', () async {
    final present = creerFichier('present.bin');
    SharedPreferences.setMockInitialValues({
      'media_dl_m1': '${tempDir.path}/deja_supprime.bin', // n'existe plus
      'media_dl_m2': present.path,
    });

    final supprimes = await FileDownloadService().clearDownloadedFiles();

    // Un seul fichier existait réellement…
    expect(supprimes, 1);
    expect(present.existsSync(), isFalse);
    // …mais les DEUX clés partent, sinon l'index pointerait dans le vide.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('media_dl_')), isEmpty);
  });
}
