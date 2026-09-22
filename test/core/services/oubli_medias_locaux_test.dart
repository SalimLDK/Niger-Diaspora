import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/media_dechiffre_cache.dart';
import 'package:diaspo_niger/core/services/e2ee/media_encryption_service.dart';
import 'package:diaspo_niger/core/services/oubli_medias_locaux.dart';

/// Un média chiffré, une fois affiché, était écrit en clair dans
/// `medias_dechiffres/<messageId>.<ext>` — et plus jamais effacé : ni à la
/// suppression pour tous, ni à la déconnexion (`vider` n'était appelé nulle
/// part), ni à la suppression du compte.
void main() {
  late Directory dossier;
  late MediaDechiffreCache cache;

  File poser(String nom) =>
      File('${dossier.path}/$nom')..writeAsBytesSync([1, 2, 3]);

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('medias_dechiffres_');
    cache = MediaDechiffreCache(
      MediaEncryptionService(),
      racine: () async => dossier,
    );
  });

  tearDown(() {
    if (dossier.existsSync()) dossier.deleteSync(recursive: true);
  });

  group('MediaDechiffreCache.oublier', () {
    test('efface le fichier du message, quelle que soit son extension', () async {
      // La coquille d'un message supprimé n'a plus de type MIME : le fichier
      // se retrouve par l'identifiant seul.
      final photo = poser(MediaDechiffreCache.nomDeFichier('m1', 'image/jpeg'));
      final voisin = poser(MediaDechiffreCache.nomDeFichier('m10', 'image/png'));
      final autre = poser(MediaDechiffreCache.nomDeFichier('m2', 'audio/mp4'));

      await cache.oublier('m1');

      expect(photo.existsSync(), isFalse);
      expect(voisin.existsSync(), isTrue,
          reason: '« m10 » commence par « m1 » : il ne doit pas partir');
      expect(autre.existsSync(), isTrue);
    });

    test('un identifiant à caractères spéciaux retrouve son fichier', () async {
      const id = 'abc.def/ghi';
      final f = poser(MediaDechiffreCache.nomDeFichier(id, 'video/mp4'));
      expect(MediaDechiffreCache.soucheDe(id), isNot(contains('.')));

      await cache.oublier(id);

      expect(f.existsSync(), isFalse);
    });

    test('rien à effacer, ou dossier absent : sans erreur', () async {
      await cache.oublier('inconnu');
      dossier.deleteSync(recursive: true);
      await cache.oublier('m1');
    });
  });

  group('effacer tout le dossier', () {
    test('vider efface tous les fichiers', () async {
      poser('m1.jpg');
      poser('m2.pdf');
      expect(await cache.vider(), 2);
      expect(dossier.listSync(), isEmpty);
    });

    test('effacerTout lève si le dossier résiste — MaterielLocal retentera',
        () async {
      await expectLater(
        MediaDechiffreCache.effacerTout(
          racine: () async => throw const FileSystemException('refusé'),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('vider, lui, ne lève pas : la déconnexion doit aboutir', () async {
      final fragile = MediaDechiffreCache(
        MediaEncryptionService(),
        racine: () async => throw const FileSystemException('refusé'),
      );
      expect(await fragile.vider(), 0);
    });
  });

  group('OubliMediasLocaux', () {
    test('un identifiant n\'est traité qu\'une fois', () async {
      final appels = <String>[];
      final oubli = OubliMediasLocaux(oublierUn: (id) async => appels.add(id));

      oubli.oublier(['m1', 'm2']);
      oubli.oublier(['m1', '', 'm3']);
      await Future<void>.delayed(Duration.zero);

      expect(appels, ['m1', 'm2', 'm3']);
    });

    test('un échec est retenté au passage suivant', () async {
      var essais = 0;
      final oubli = OubliMediasLocaux(oublierUn: (id) async {
        essais++;
        if (essais == 1) throw const FileSystemException('occupé');
      });

      oubli.oublier(['m1']);
      await Future<void>.delayed(Duration.zero);
      oubli.oublier(['m1']);
      await Future<void>.delayed(Duration.zero);

      expect(essais, 2);
    });
  });
}
