import 'dart:convert';

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

  // Les clés dérivées : ce que la portée réduite achète réellement.
  group('EncryptionService — clés dérivées', () {
    late EncryptionService service;

    // 32 octets, comme ce que sert `crypto-keys`. Deux clés distinctes pour
    // pouvoir vérifier qu'elles ne se lisent pas entre elles.
    final cleA = base64Encode(List<int>.generate(32, (i) => i));
    final cleB = base64Encode(List<int>.generate(32, (i) => 255 - i));

    setUp(() async {
      service = EncryptionService();
      await service.initialize();
    });

    test('aller-retour avec une clé dérivée', () {
      const clair = 'Rendez-vous a Niamey mardi';

      final chiffre =
          service.encryptWithDerivedKey(clair, keyBase64: cleA, version: 1);

      expect(chiffre, isNot(equals(clair)));
      expect(service.decryptWithDerivedKey(chiffre, keyBase64: cleA),
          equals(clair));
    });

    test('le format porte la version et trois segments', () {
      final chiffre =
          service.encryptWithDerivedKey('x', keyBase64: cleA, version: 3);

      expect(chiffre.split(':'), hasLength(3));
      expect(chiffre, startsWith('v3:'));
      expect(EncryptionService.estFormatVersionne(chiffre), isTrue);
      expect(EncryptionService.versionDe(chiffre), equals(3));
    });

    // LA propriété de confidentialité de tout le chantier : deux portées
    // différentes ne se lisent pas. Avec la clé globale, n'importe qui lisait
    // le trafic AES de tout le monde.
    test('une clé ne déchiffre pas ce qu_une autre a chiffré', () {
      final chiffre = service.encryptWithDerivedKey(
        'secret de la conversation A',
        keyBase64: cleA,
        version: 1,
      );

      final relu = service.decryptWithDerivedKey(chiffre, keyBase64: cleB);

      expect(relu, equals('[Message illisible]'));
      expect(relu, isNot(contains('secret')));
    });

    // La lecture à deux clés : sans elle, la bascule rendrait illisible tout
    // l_existant chiffré avec la clé globale.
    test('un contenu hérité reste lisible par le même chemin', () {
      const clair = 'Message ecrit avant le chantier';
      final herite = service.encryptText(clair);

      expect(EncryptionService.estFormatVersionne(herite), isFalse);
      expect(service.decryptWithDerivedKey(herite, keyBase64: cleA),
          equals(clair));
    });

    test('sans clé, un contenu versionné ne rend jamais le ciphertext', () {
      final chiffre =
          service.encryptWithDerivedKey('donnee', keyBase64: cleA, version: 1);

      final relu = service.decryptWithDerivedKey(chiffre);

      expect(relu, equals('[Message illisible]'));
      expect(relu, isNot(contains(chiffre.split(':')[2])));
    });

    // Une clé mal dimensionnee doit ARRETER le chiffrement, pas le faire
    // retomber sur la cle globale : un repli silencieux annulerait la portee.
    test('une clé de mauvaise taille lève au lieu de se rabattre', () {
      final tropCourte = base64Encode(List<int>.filled(16, 7));

      expect(
        () => service.encryptWithDerivedKey('x',
            keyBase64: tropCourte, version: 1),
        throwsA(isA<EncryptionUnavailableException>()),
      );
    });

    test('une clé non base64 lève aussi', () {
      expect(
        () => service.encryptWithDerivedKey('x',
            keyBase64: 'pas du base64 !!', version: 1),
        throwsA(isA<EncryptionUnavailableException>()),
      );
    });

    test('estFormatVersionne ne confond pas les formats hérités', () {
      expect(EncryptionService.estFormatVersionne('gcm:abc:def'), isFalse);
      expect(EncryptionService.estFormatVersionne('aXY=:Zm9v'), isFalse);
      expect(EncryptionService.estFormatVersionne('texte en clair'), isFalse);
      expect(EncryptionService.estFormatVersionne('v1:aXY=:Zm9v'), isTrue);
    });
  });
}
