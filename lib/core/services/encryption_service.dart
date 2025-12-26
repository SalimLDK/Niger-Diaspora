import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

class EncryptionService {
  // Clé statique pour l'application (normalement à mettre dans .env)
  // 32 chars for AES-256
  static final _keyString = 'DiaspoNigerSecureKey2025ForApps!';
  late final encrypt.Key _key;
  late final encrypt.Encrypter _encrypter;

  EncryptionService() {
    _key = encrypt.Key.fromUtf8(_keyString);
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
  }

  /// Chiffre le texte et retourne "iv:base64ciphertext"
  String encryptText(String plainText) {
    if (plainText.isEmpty) return plainText;

    final iv = encrypt.IV.fromLength(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }

  /// Déchiffre le texte à partir du format "iv:base64ciphertext"
  /// Retourne le texte original si le format est invalide ou si le déchiffrement échoue
  String decryptText(String encryptedFullText) {
    if (encryptedFullText.isEmpty) return encryptedFullText;

    try {
      final parts = encryptedFullText.split(':');
      if (parts.length != 2) {
        // Pas le bon format, on suppose que c'est un ancien message non chiffré
        return encryptedFullText;
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // En cas d'erreur (clé changée, données corrompues, format legacy bizarre), on retourne le texte tel quel
      return encryptedFullText;
    }
  }
}
