import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() async {
      encryptionService = EncryptionService();
      // Sans initialize(), encryptText retombe volontairement en passe-plat et
      // renvoie le texte clair : les assertions de chiffrement échouaient donc
      // sur un service jamais armé, pas sur un défaut de chiffrement.
      await encryptionService.initialize();
    });

    test('should encrypt and decrypt text correctly', () {
      const plainText = 'Hello World';
      final encrypted = encryptionService.encryptText(plainText);

      expect(encrypted, isNot(equals(plainText)));
      expect(encrypted, contains(':')); // Check format iv:ciphertext

      final decrypted = encryptionService.decryptText(encrypted);
      expect(decrypted, equals(plainText));
    });

    test(
      'should return original text if decryption fails (backward compatibility)',
      () {
        const plainText = 'Old Unencrypted Message';
        final decrypted = encryptionService.decryptText(plainText);

        expect(decrypted, equals(plainText));
      },
    );

    test('should handle empty string', () {
      const plainText = '';
      final encrypted = encryptionService.encryptText(plainText);
      expect(encrypted, isEmpty);

      final decrypted = encryptionService.decryptText(encrypted);
      expect(decrypted, isEmpty);
    });

    test('should generate different ciphertexts for same text (due to IV)', () {
      const plainText = 'Secret Message';
      final encrypted1 = encryptionService.encryptText(plainText);
      final encrypted2 = encryptionService.encryptText(plainText);

      expect(encrypted1, isNot(equals(encrypted2)));

      expect(encryptionService.decryptText(encrypted1), equals(plainText));
      expect(encryptionService.decryptText(encrypted2), equals(plainText));
    });
  });
}
