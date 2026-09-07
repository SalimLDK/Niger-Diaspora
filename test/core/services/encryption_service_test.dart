import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() async {
      encryptionService = EncryptionService();
      // Le service est un singleton : sans initialize(), il n'est pas armé et
      // encryptText refuse de travailler (il levait autrefois en passe-plat le
      // texte clair — voir le groupe « refus de dégrader » plus bas).
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

  // Ces trois tests sont la garantie que le repli AES ne peut plus dégrader en
  // écriture en clair. C'est la propriété qui compte : `encryptText` était
  // synchrone et renvoyait `plainText` sur ses deux chemins d'échec, donc un
  // message pouvait finir en clair en base sans qu'aucune erreur ne remonte.
  //
  // Le jour où la clé viendra d'une Edge Function (au lieu d'être une constante
  // du binaire), ces chemins deviendront atteignables pour de bon.
  group('EncryptionService — refus de dégrader en clair', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService();
      service.resetForTests();
    });

    tearDown(() async {
      // Rendre le singleton utilisable aux tests suivants, quel que soit
      // l'ordre d'exécution.
      await service.initialize();
    });

    test('sans clé, encryptText lève au lieu de rendre le texte clair', () {
      const secret = 'Mon numero de compte';

      expect(
        () => service.encryptText(secret),
        throwsA(isA<EncryptionUnavailableException>()),
      );
    });

    test('sans clé, aucun appel ne peut rendre le texte initial', () {
      const secret = 'IBAN NE0000000000';

      String? renvoye;
      try {
        renvoye = service.encryptText(secret);
      } on EncryptionUnavailableException {
        renvoye = null;
      }

      expect(renvoye, isNull, reason: 'un retour non nul serait le clair');
    });

    test('la chaîne vide reste tolérée sans clé (rien à protéger)', () {
      expect(service.encryptText(''), isEmpty);
    });
  });
}
