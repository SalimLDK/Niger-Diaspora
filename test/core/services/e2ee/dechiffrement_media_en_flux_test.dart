import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:diaspo_niger/core/services/e2ee/media_encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 9, décision C4)
/// ------------------------------------------------------
/// Le déchiffrement d'un média passait **entièrement par la mémoire** : les
/// octets chiffrés en entier, puis la liste des morceaux déchiffrés, puis leur
/// concaténation — près de trois fois la taille du fichier au pic. C'est la
/// raison pour laquelle la vidéo était écartée du chiffrement.
///
/// Et le téléchargement lui-même plafonnait : `ref.getData()` sans argument
/// s'arrête à **10 Mo**, défaut de `firebase_storage`. Au-delà, un média
/// chiffré était tout simplement illisible — une photo lourde, un document,
/// un audio long. Le drapeau étant fermé, personne ne l'avait rencontré.
///
/// Le format n'a pas changé : en-tête `[version][nombre de morceaux]`, puis
/// pour chaque morceau `[taille sur 4 octets][ciphertext][étiquette sur 16]`,
/// avec un IV dérivé de l'index. Ce qui change est qu'on le lit **d'un fichier
/// vers un autre**, un morceau à la fois.
///
/// Ce que ces tests empêchent : qu'on retombe sur un déchiffrement qui
/// assemble tout en mémoire, que le format versionné et le format simple se
/// confondent, et qu'un fichier tronqué ou une mauvaise clé passent pour un
/// déchiffrement réussi.

/// Construit un conteneur versionné, comme le fait l'envoi.
Future<Uint8List> _conteneurVersionne(
  MediaEncryptionService service,
  List<Uint8List> morceaux,
  SecretKey cle,
  Uint8List iv,
) async {
  final aes = AesGcm.with256bits();
  final sortie = <int>[1, (morceaux.length >> 24) & 0xFF, (morceaux.length >> 16) & 0xFF,
      (morceaux.length >> 8) & 0xFF, morceaux.length & 0xFF];
  for (var i = 0; i < morceaux.length; i++) {
    final boite = await aes.encrypt(morceaux[i],
        secretKey: cle, nonce: service.deriveChunkIv(iv, i));
    final n = boite.cipherText.length + 16;
    sortie.addAll([(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF]);
    sortie.addAll(boite.cipherText);
    sortie.addAll(boite.mac.bytes);
  }
  return Uint8List.fromList(sortie);
}

Uint8List _octets(int n, int graine) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 31 + graine) & 0xFF));

void main() {
  late Directory dossier;
  late MediaEncryptionService service;
  late SecretKey cle;
  late Uint8List iv;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('media_flux');
    service = MediaEncryptionService();
    cle = await AesGcm.with256bits().newSecretKey();
    iv = Uint8List.fromList(List.generate(12, (i) => i + 7));
  });

  tearDown(() async {
    if (await dossier.exists()) await dossier.delete(recursive: true);
  });

  group('format versionné', () {
    test('trois morceaux se recollent dans le bon ordre', () async {
      final a = _octets(1000, 1);
      final b = _octets(1000, 2);
      final c = _octets(333, 3);
      final chiffre = File('${dossier.path}/c.bin');
      await chiffre.writeAsBytes(
          await _conteneurVersionne(service, [a, b, c], cle, iv));

      final clair = File('${dossier.path}/clair.bin');
      await service.dechiffrerFichierVersFichier(chiffre, clair, cle, iv);

      expect(await clair.readAsBytes(), [...a, ...b, ...c]);
    });

    test('un seul morceau', () async {
      final a = _octets(64, 9);
      final chiffre = File('${dossier.path}/c1.bin');
      await chiffre.writeAsBytes(await _conteneurVersionne(service, [a], cle, iv));

      final clair = File('${dossier.path}/clair1.bin');
      await service.dechiffrerFichierVersFichier(chiffre, clair, cle, iv);

      expect(await clair.readAsBytes(), a);
    });

    test('une mauvaise clé lève, elle ne rend pas des octets faux', () async {
      final chiffre = File('${dossier.path}/c2.bin');
      await chiffre.writeAsBytes(
          await _conteneurVersionne(service, [_octets(200, 4)], cle, iv));
      final autre = await AesGcm.with256bits().newSecretKey();

      await expectLater(
        service.dechiffrerFichierVersFichier(
            chiffre, File('${dossier.path}/x.bin'), autre, iv),
        throwsA(isA<MediaDecryptionException>()),
      );
    });

    test('un fichier tronqué lève au lieu de rendre un clair partiel',
        () async {
      final complet =
          await _conteneurVersionne(service, [_octets(500, 5)], cle, iv);
      final chiffre = File('${dossier.path}/c3.bin');
      // On coupe la fin : l'étiquette d'authentification manque.
      await chiffre.writeAsBytes(complet.sublist(0, complet.length - 30));

      await expectLater(
        service.dechiffrerFichierVersFichier(
            chiffre, File('${dossier.path}/y.bin'), cle, iv),
        throwsA(isA<MediaDecryptionException>()),
      );
    });
  });

  group('format simple, celui d\'avant', () {
    test('reste lisible : un seul bloc, sans en-tête', () async {
      // Rien n'a encore été écrit dans ce format en production, mais une
      // version précédente pourrait l'avoir fait entre-temps. Le refuser
      // rendrait ce média illisible pour toujours.
      final clairAttendu = _octets(300, 6);
      final boite = await AesGcm.with256bits()
          .encrypt(clairAttendu, secretKey: cle, nonce: iv);
      final chiffre = File('${dossier.path}/s.bin');
      await chiffre
          .writeAsBytes([...boite.cipherText, ...boite.mac.bytes]);

      final clair = File('${dossier.path}/clairs.bin');
      await service.dechiffrerFichierVersFichier(chiffre, clair, cle, iv);

      expect(await clair.readAsBytes(), clairAttendu);
    });
  });

  group('câblage', () {
    test('le téléchargement ne passe plus par getData', () {
      // `getData()` sans argument plafonne à 10 Mo : c'est ce plafond qui
      // rendait illisible tout média chiffré un peu lourd.
      // Sans les commentaires : le nôtre parle justement de `getData`, et un
      // test qui se laisse prendre à sa propre explication ne garde rien.
      final code = File('lib/core/services/e2ee/media_encryption_service.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('getData('), isFalse);
      expect(code.contains('writeToFile('), isTrue);
    });
  });
}
