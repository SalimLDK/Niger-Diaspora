import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/file_download_service.dart';
import 'package:diaspo_niger/core/services/nom_de_fichier_sur.dart';

/// Banc des noms de fichier venus d'un message.
///
/// `message.fileName` est écrit par l'expéditeur, et le téléchargement
/// automatique l'utilisait tel quel derrière le répertoire documents — dès
/// l'affichage de la bulle, sans geste de l'utilisateur. Un `../` sortait du
/// répertoire ; un simple nom de boîte Hive écrasait la boîte, rangée au même
/// endroit par `Hive.initFlutter()`.
void main() {
  group('nomDeFichierSur', () {
    test('un nom ordinaire passe intact', () {
      expect(nomDeFichierSur('Compte rendu de la réunion.pdf'),
          'Compte rendu de la réunion.pdf');
      expect(nomDeFichierSur('photo.jpg'), 'photo.jpg');
    });

    test('aucun composant de chemin ne survit', () {
      expect(nomDeFichierSur('../../shared_prefs/x.xml'), 'x.xml');
      expect(nomDeFichierSur('/data/user/0/app/files/boite.hive'), 'boite.hive');
      expect(nomDeFichierSur(r'..\..\evil.dll'), 'evil.dll');
      expect(nomDeFichierSur('a/b\\c/d.txt'), 'd.txt');
    });

    test('ni `..`, ni `.`, ni fichier caché', () {
      expect(nomDeFichierSur('..'), 'fichier');
      expect(nomDeFichierSur('.'), 'fichier');
      expect(nomDeFichierSur('../..'), 'fichier');
      expect(nomDeFichierSur('.bashrc'), 'bashrc');
      expect(nomDeFichierSur('...hive'), 'hive');
    });

    test('vide ou nul : le repli, lui-même nettoyé', () {
      expect(nomDeFichierSur(null, repli: 'm1.mp4'), 'm1.mp4');
      expect(nomDeFichierSur('', repli: 'm1.mp4'), 'm1.mp4');
      expect(nomDeFichierSur('   ', repli: '../m1.mp4'), 'm1.mp4');
      expect(nomDeFichierSur('/', repli: ''), 'fichier');
    });

    test('caractères de contrôle et réservés retirés', () {
      expect(nomDeFichierSur('a\u0000b\nc.txt'), 'abc.txt');
      expect(nomDeFichierSur('fac*ture?<1>|.pdf'), 'facture1.pdf');
      expect(nomDeFichierSur('C:evil.txt'), 'Cevil.txt');
    });

    test('tronqué en gardant l\'extension, sans couper un emoji', () {
      final long = '${'a' * 300}.pdf';
      final sur = nomDeFichierSur(long);
      expect(sur.runes.length, longueurMaxNomDeFichier);
      expect(sur, endsWith('.pdf'));

      final emojis = '${'😀' * 200}.png';
      final surEmojis = nomDeFichierSur(emojis);
      expect(surEmojis.runes.length, longueurMaxNomDeFichier);
      expect(surEmojis, endsWith('.png'));
      // Aucune moitié de paire de substitution orpheline.
      expect(() => surEmojis.runes.toList(), returnsNormally);
      expect(surEmojis.runes.where((r) => r >= 0xD800 && r <= 0xDFFF), isEmpty);
    });
  });

  group('FileDownloadService.downloadToAppDirectory', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late Directory racine;
    late Directory documents;
    late HttpServer serveur;

    setUp(() async {
      // Le binding de test répond 400 à tout HTTP ; le serveur est local.
      HttpOverrides.global = null;
      racine = Directory.systemTemp.createTempSync('nom_sur_test');
      documents = Directory('${racine.path}/documents')..createSync();
      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => documents.path,
      );

      serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serveur.listen((requete) async {
        requete.response.add('contenu choisi par l\'expéditeur'.codeUnits);
        await requete.response.close();
      });
    });

    tearDown(() async {
      await serveur.close(force: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      if (racine.existsSync()) racine.deleteSync(recursive: true);
    });

    String url() => 'http://127.0.0.1:${serveur.port}/f';

    test('un nom en ../ ne sort pas du dossier du message', () async {
      final fichier = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: '../../victime.txt',
        messageId: 'm1',
      );

      expect(fichier, isNotNull);
      expect(fichier!.path, '${documents.path}/pieces_jointes/m1/victime.txt');
      expect(File('${racine.path}/victime.txt').existsSync(), isFalse);
      expect(File('${documents.path}/victime.txt').existsSync(), isFalse);
    });

    test('un nom de boîte Hive n\'écrase pas la boîte', () async {
      final boite = File('${documents.path}/messages.hive')
        ..writeAsStringSync('boîte intacte');

      final fichier = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: 'messages.hive',
        messageId: 'm2',
      );

      expect(fichier, isNotNull);
      expect(boite.readAsStringSync(), 'boîte intacte');
      expect(fichier!.path, '${documents.path}/pieces_jointes/m2/messages.hive');
    });

    test('deux pièces jointes de même nom ne s\'écrasent pas', () async {
      final a = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: 'contrat.pdf',
        messageId: 'legitime',
      );
      final b = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: 'contrat.pdf',
        messageId: 'autre',
      );

      expect(a!.path, isNot(b!.path));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('media_dl_legitime'), a.path);
      expect(prefs.getString('media_dl_autre'), b.path);
    });

    test('un identifiant de message hostile ne sort pas non plus', () async {
      final fichier = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: 'x.bin',
        messageId: '../..',
      );

      expect(fichier, isNotNull);
      expect(
        fichier!.path.startsWith('${documents.path}/pieces_jointes/'),
        isTrue,
        reason: fichier.path,
      );
      expect(fichier.parent.parent.path, '${documents.path}/pieces_jointes');
    });

    test('oublier efface le fichier et son dossier, pas la racine', () async {
      final fichier = await FileDownloadService().downloadToAppDirectory(
        url(),
        fileName: 'doc.pdf',
        messageId: 'm3',
      );
      expect(fichier!.existsSync(), isTrue);

      await FileDownloadService().oublier('m3');

      expect(fichier.existsSync(), isFalse);
      expect(fichier.parent.existsSync(), isFalse,
          reason: 'le dossier par message vide doit partir');
      expect(Directory('${documents.path}/pieces_jointes').existsSync(), isTrue);
      expect(documents.existsSync(), isTrue);
    });
  });
}
