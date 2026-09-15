import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_notification_preview.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, phase 4)
/// ----------------------------------------------
/// L'aperçu de notification est le seul endroit où un SECOND processus
/// touche à l'état MLS. Le piège du § 8 — deux processus ne peuvent pas
/// faire avancer le même cliquet — ne se voit pas à la relecture : le code
/// « marche », et c'est la conversation qui devient illisible plus tard.
///
/// Le comportement lui-même est vérifié côté Rust
/// (`l_apercu_ne_consomme_pas_le_cliquet`, qui rejoue un déchiffrement
/// d'aperçu puis exige que l'application relise le même message). Ici, on
/// garde le câblage : que l'isolate passe bien par la copie jetable, et que
/// tout échec retombe sur le repli au lieu de faire disparaître la
/// notification.

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('résumé affiché', () {
    MlsPayload payload(String type, [Map<String, dynamic>? body]) => MlsPayload(
          id: 'm1',
          type: type,
          sentAt: 0,
          body: body ?? const {},
        );

    test('un texte s’affiche tel quel, vidé de ses espaces', () {
      expect(
        MlsNotificationPreview.resume(payload('text', {'content': '  Salut  '})),
        'Salut',
      );
    });

    test('un texte vide ne remplace pas le repli', () {
      expect(MlsNotificationPreview.resume(payload('text', {'content': '   '})), isNull);
    });

    test('les médias ont un libellé, pas leur nom de fichier', () {
      expect(MlsNotificationPreview.resume(payload('image')), 'Photo');
      expect(MlsNotificationPreview.resume(payload('voiceNote')), 'Note vocale');
      expect(MlsNotificationPreview.resume(payload('location')), 'Position');
      // Un type inconnu d'un ancien build ne doit pas inventer un aperçu.
      expect(MlsNotificationPreview.resume(payload('type_futur')), isNull);
    });
  });

  group('ce push me concerne-t-il', () {
    test('il faut le drapeau de protocole ET un ciphertext', () {
      expect(MlsNotificationPreview.concerne({'protocol': 'mls', 'mlsCiphertext': 'AAA'}), isTrue);
      expect(MlsNotificationPreview.concerne({'protocol': 'mls'}), isFalse);
      expect(MlsNotificationPreview.concerne({'protocol': 'mls', 'mlsCiphertext': ''}), isFalse);
      // Un message legacy garde son chemin : le serveur a déjà mis l'aperçu.
      expect(MlsNotificationPreview.concerne({'type': 'message'}), isFalse);
    });

    test('le réglage « aperçu des messages » vaut aussi pour MLS', () {
      // `send-push` transmet ce drapeau. Sans cette garde, le réglage aurait
      // cessé de s'appliquer au moment où le déchiffrement a changé de côté —
      // un réglage qui s'éteint en silence est pire qu'un réglage absent.
      expect(
        MlsNotificationPreview.concerne({
          'protocol': 'mls',
          'mlsCiphertext': 'AAA',
          'showMessagePreview': 'false',
        }),
        isFalse,
      );
      expect(
        MlsNotificationPreview.concerne({
          'protocol': 'mls',
          'mlsCiphertext': 'AAA',
          'showMessagePreview': 'true',
        }),
        isTrue,
      );
    });
  });

  group('câblage — le piège du cliquet', () {
    test('l’isolate passe par la copie jetable, jamais par le moteur', () {
      final source = _source('lib/core/crypto/mls/mls_notification_preview.dart');
      expect(source, contains('apercuSansEtat('));
      // `Moteur.ouvrir` ferait avancer l'état qui fait foi : interdit ici.
      expect(source.contains('Moteur.ouvrir'), isFalse);
      expect(source.contains('mlsEngineProvider'), isFalse);
    });

    test('le déchiffrement d’aperçu ne persiste rien, côté Rust', () {
      final source = _source('rust/src/engine.rs');
      final i = source.indexOf('pub fn preview_without_state');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('impl MlsEngine {', i));
      // La copie est produite par VACUUM INTO (cohérente en WAL) puis jetée.
      expect(corps, contains('VACUUM INTO'));
      expect(corps, contains('nettoyer(&copie)'));
    });

    test('tout échec retombe sur le repli, sans faire tomber la notification', () {
      final source = _source('lib/core/crypto/mls/mls_notification_preview.dart');
      final i = source.indexOf('static Future<String?> texte(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('\n  }', i));
      expect(corps, contains('} catch (e) {'));
      expect(corps, contains('return null;'));
    });

    test('le handler background préfère l’aperçu déchiffré au repli', () {
      final source = _source('lib/core/services/notification_service.dart');
      expect(source, contains('await MlsNotificationPreview.texte(data)'));
      expect(source, contains('final body = apercuMls ??'));
    });

    test('l’identifiant d’appareil est mémorisé pour l’isolate', () {
      // Un `MethodChannel` ne répond pas dans un isolate frais : sans cette
      // mémorisation, l'aperçu viserait une autre base et échouerait toujours.
      final source = _source('lib/core/crypto/mls/mls_device_registry.dart');
      expect(source, contains('MlsNotificationPreview.cleStableId(userId)'));
    });

    test('le serveur n’envoie qu’un repli générique et le ciphertext', () {
      final sql = _source('supabase/migrations/20260915140000_mls_notifications.sql');
      expect(sql, contains("'protocol',             'mls'"));
      expect(sql, contains("encode(NEW.ciphertext, 'base64')"));
      expect(sql, contains('octet_length(NEW.ciphertext) <= 2500'));
      // Aucun appel au déchiffrement serveur : il ne le peut plus.
      expect(sql.contains('decrypt_aes_fallback'), isFalse);
      expect(sql.contains('message_preview_for_notification'), isFalse);
      // Les messages de contrôle ne notifient personne.
      expect(sql, contains("IF NEW.kind <> 'content' THEN"));
    });
  });
}
