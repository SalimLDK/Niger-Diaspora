import 'package:diaspo_niger/core/services/e2ee/message_crypto_service.dart';
import 'package:diaspo_niger/core/services/e2ee/messaging_e2ee_service.dart';
import 'package:diaspo_niger/core/services/e2ee/notification_decryption_service.dart';
import 'package:diaspo_niger/core/services/e2ee/undecryptable_placeholders.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/undecryptable_message_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

class _FauxE2ee implements MessagingE2EEService {
  @override
  String? get currentUserId => 'moi';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxCrypto implements MessageCryptoService {
  _FauxCrypto(this.rendu);

  final String rendu;

  @override
  Future<String> decrypt({
    required Map<String, dynamic> payload,
    required String senderId,
    String? currentDeviceId,
    String? conversationId,
  }) async => rendu;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Vu sur appareil le 2026-10-16 : la bannière de notification au premier plan
/// déchiffrait le message pour son corps, **consommait** la clé (ratchet à sens
/// unique) et jetait le texte. Le fil, qui retentait ensuite, affichait
/// « Message indisponible » pour un message pourtant lu dans l'aperçu.
void main() {
  group('NotificationDecryptionService.decryptPreview', () {
    test('garde le texte clair COMPLET sous l\'id du message', () async {
      final gardes = <String, String>{};
      final texte = 'x' * 140; // l'aperçu est tronqué à 100, pas ce qu'on garde
      final service = NotificationDecryptionService(
        e2eeService: _FauxE2ee(),
        cryptoService: _FauxCrypto(texte),
        conserver: (id, contenu) async => gardes[id] = contenu,
      );

      final apercu = await service.decryptPreview(
        senderId: 'saley',
        cryptoPayload: const {'e2eePayloads': {'d': '{}'}},
        messageType: 'text',
        messageId: 'm1',
      );

      expect(apercu.length, 103, reason: '100 caractères + « ... »');
      expect(gardes['m1'], texte);
    });

    test('ne garde jamais un marqueur d\'échec', () async {
      final gardes = <String, String>{};
      final service = NotificationDecryptionService(
        e2eeService: _FauxE2ee(),
        cryptoService: _FauxCrypto(kE2EESessionRequiredPlaceholder),
        conserver: (id, contenu) async => gardes[id] = contenu,
      );

      await service.decryptPreview(
        senderId: 'saley',
        cryptoPayload: const {'e2eePayloads': {'d': '{}'}},
        messageType: 'text',
        messageId: 'm1',
      );

      expect(gardes, isEmpty);
    });

    test('un échec de conservation ne casse pas la notification', () async {
      final service = NotificationDecryptionService(
        e2eeService: _FauxE2ee(),
        cryptoService: _FauxCrypto('Salut'),
        conserver: (id, contenu) async => throw StateError('box fermée'),
      );

      final apercu = await service.decryptPreview(
        senderId: 'saley',
        cryptoPayload: const {'e2eePayloads': {'d': '{}'}},
        messageType: 'text',
        messageId: 'm1',
      );

      expect(apercu, 'Salut');
    });
  });

  group('contenuCitationAffichable', () {
    test('remplace chaque marqueur technique par le libellé de la bulle', () {
      for (final marqueur in kUndecryptablePlaceholders) {
        expect(
          contenuCitationAffichable(marqueur),
          kLibelleMessageIndisponible,
        );
      }
      expect(contenuCitationAffichable(''), kLibelleMessageIndisponible);
    });

    test('laisse un texte lisible tel quel', () {
      expect(contenuCitationAffichable('Cool ça marche'), 'Cool ça marche');
    });
  });
}
