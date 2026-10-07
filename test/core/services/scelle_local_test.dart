import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_notification_preview.dart';
import 'package:diaspo_niger/core/services/background_reply_service.dart';
import 'package:diaspo_niger/core/services/crypto/scelle_local.dart';
import 'package:diaspo_niger/core/services/notification_pile_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le clair rangé dans `SharedPreferences` est scellé.
///
/// `SharedPreferences` part dans la sauvegarde du téléphone (Google, iCloud).
/// Trois magasins y gardaient du clair : la pile des bannières (24 h de
/// textes, messages chiffrés compris), les aperçus MLS déchiffrés, et la file
/// des réponses depuis la notification. Le chiffrement de bout en bout
/// s'arrêtait à la sauvegarde. Ils passent désormais par [ScelleLocal], sous
/// une clé du Keystore / Trousseau qui ne quitte pas l'appareil.
void main() {
  final cleIci = SecretKey(List<int>.generate(32, (i) => i));
  final cleAilleurs = SecretKey(List<int>.generate(32, (i) => 255 - i));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScelleLocal.remplacerClePourTests(() async => cleIci);
  });
  tearDown(() => ScelleLocal.remplacerClePourTests(null));

  /// Tout ce que `SharedPreferences` contient, comme le verrait une
  /// sauvegarde.
  Future<String> sauvegarde() async {
    final prefs = await SharedPreferences.getInstance();
    return [for (final k in prefs.getKeys()) '$k=${prefs.get(k)}'].join('\n');
  }

  group('le scellé', () {
    test('aller-retour, et rien du clair dans le scellé', () async {
      final s = await ScelleLocal.sceller('PA6SECRET');
      expect(ScelleLocal.estScelle(s), isTrue);
      expect(s, isNot(contains('PA6SECRET')));
      expect(await ScelleLocal.desceller(s), 'PA6SECRET');
    });

    test('deux scellés du même texte diffèrent (nonce)', () async {
      expect(await ScelleLocal.sceller('x'),
          isNot(await ScelleLocal.sceller('x')));
    });

    test('une valeur d\'avant le scellé se lit telle quelle', () async {
      expect(await ScelleLocal.desceller('[{"t":"ancien"}]'), '[{"t":"ancien"}]');
    });

    test('le scellé d\'un autre appareil ne se lit pas', () async {
      final s = await ScelleLocal.sceller('secret');
      ScelleLocal.remplacerClePourTests(() async => cleAilleurs);
      expect(await ScelleLocal.desceller(s), isNull);
    });

    test('sans clé : le clair passe, plutôt qu\'un message perdu', () async {
      ScelleLocal.remplacerClePourTests(() async => null);
      expect(await ScelleLocal.sceller('file'), 'file');
    });
  });

  group('les trois magasins', () {
    test('pile des bannières : scellée en base, lisible par l\'app', () async {
      await PileMessagesNotifiees.empiler(
        conversationId: 'c1',
        messageId: 'm1',
        texte: 'PA6SECRET',
        expediteur: 'Alice',
      );

      expect(await sauvegarde(), isNot(contains('PA6SECRET')));
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.map((m) => m.texte), ['PA6SECRET']);
    });

    test('pile restaurée depuis un autre appareil : vide, sans erreur',
        () async {
      await PileMessagesNotifiees.empiler(
        conversationId: 'c1',
        messageId: 'm1',
        texte: 'secret',
        expediteur: 'Alice',
      );
      ScelleLocal.remplacerClePourTests(() async => cleAilleurs);

      expect(await PileMessagesNotifiees.lire('c1'), isEmpty);
    });

    test('pile écrite avant le scellé : relue, puis réécrite scellée',
        () async {
      final maintenant = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        PileMessagesNotifiees.cleDe('c1'):
            '[{"i":"m0","t":"ancien clair","e":"Alice","q":$maintenant}]',
      });

      await PileMessagesNotifiees.empiler(
        conversationId: 'c1',
        messageId: 'm1',
        texte: 'nouveau',
        expediteur: 'Alice',
      );

      expect(await sauvegarde(), isNot(contains('ancien clair')));
      expect((await PileMessagesNotifiees.lire('c1')).map((m) => m.texte),
          containsAll(['ancien clair', 'nouveau']));
    });

    test('aperçu MLS et file des réponses : scellés à l\'écriture', () {
      // Les deux écritures passent par des chemins qui exigent Firebase,
      // Supabase ou le moteur Rust : on vérifie qu'elles scellent.
      String corps(String chemin, String ancre) {
        final source = File(chemin).readAsStringSync();
        final debut = source.indexOf(ancre);
        expect(debut, isNot(-1), reason: '$ancre introuvable');
        return source.substring(debut, source.indexOf('\n  }\n', debut));
      }

      expect(
        corps('lib/core/crypto/mls/mls_notification_preview.dart',
            'static Future<void> _cacher('),
        contains('ScelleLocal.sceller(texte)'),
      );
      expect(
        corps('lib/core/crypto/mls/mls_notification_preview.dart',
            'static Future<String?> apercuCache('),
        contains('ScelleLocal.desceller('),
      );
      expect(
        corps('lib/core/services/background_reply_service.dart',
            'static Future<void> _saveQueue('),
        contains('ScelleLocal.sceller('),
      );
    });

    test('file des réponses : relue depuis le scellé', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'background_pending_messages',
        await ScelleLocal.sceller(
          '[{"id":"q1","conversationId":"c1","content":"réponse","senderId":"u1",'
          '"senderName":"Moi","createdAt":"${DateTime.now().toIso8601String()}",'
          '"retryCount":0}]',
        ),
      );
      final file = await BackgroundReplyService.getPendingMessages();
      expect(file.map((m) => m.content), ['réponse']);
      // L'aperçu MLS se relit de même.
      await prefs.setString(
          'mls_apercu_m9', await ScelleLocal.sceller('Bonjour'));
      expect(await MlsNotificationPreview.apercuCache('m9'), 'Bonjour');
    });
  });

  test('les fichiers du stockage sécurisé sont hors sauvegarde', () {
    for (final chemin in [
      'android/app/src/main/res/xml/regles_sauvegarde.xml',
      'android/app/src/main/res/xml/regles_extraction_donnees.xml',
    ]) {
      final xml = File(chemin).readAsStringSync();
      for (final fichier in [
        'FlutterSecureStorage.xml',
        'FlutterSecureKeyStorage.xml',
      ]) {
        final regle = '<exclude domain="sharedpref" path="$fichier" />';
        // Une fois dans la sauvegarde complète, deux fois (cloud + transfert)
        // dans les règles d'Android 12.
        expect(regle.allMatches(xml).length,
            chemin.endsWith('extraction_donnees.xml') ? 2 : 1,
            reason: '$fichier dans $chemin');
      }
    }
  });
}
