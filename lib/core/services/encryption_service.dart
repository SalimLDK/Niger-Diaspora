import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService.instance;
});

class EncryptionService {
  // Singleton pattern
  static final EncryptionService instance = EncryptionService._internal();
  factory EncryptionService() => instance;
  EncryptionService._internal();

  // Shared key with Firebase Cloud Functions (functions/encryption.js)
  // IMPORTANT: This key must match the KEY_STRING in functions/encryption.js
  static const String _sharedKeyString = 'DiaspoNigerSecureKey2025ForApps!';

  encrypt.Key? _key;
  encrypt.Encrypter? _encrypter;
  bool _isInitialized = false;

  /// Initialize the encryption service with the shared key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use the same fixed key as the server (Cloud Functions)
      // This ensures messages can be decrypted by both client and server
      final keyBytes = utf8.encode(_sharedKeyString);
      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _encrypter = encrypt.Encrypter(
        encrypt.AES(_key!, mode: encrypt.AESMode.cbc),
      );
      _isInitialized = true;
      debugPrint('🔐 Encryption service initialized with shared key');
    } catch (e) {
      debugPrint('❌ Error initializing encryption service: $e');
      _isInitialized = false;
    }
  }

  /// Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Chiffre le texte et retourne "iv:base64ciphertext"
  /// Cette méthode est synchrone mais nécessite une initialisation préalable
  String encryptText(String plainText) {
    if (plainText.isEmpty) return plainText;

    if (!_isInitialized || _encrypter == null) {
      debugPrint('⚠️ EncryptionService not initialized, returning plain text');
      return plainText;
    }

    try {
      final iv = encrypt.IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);

      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('❌ Error encrypting text: $e');
      return plainText;
    }
  }

  /// Version asynchrone qui garantit l'initialisation
  Future<String> encryptTextAsync(String plainText) async {
    await _ensureInitialized();
    return encryptText(plainText);
  }

  /// Vérifie si une chaîne est du base64 valide
  bool _isValidBase64(String str) {
    if (str.isEmpty) return false;
    // Base64 ne contient que A-Za-z0-9+/= et sa longueur doit être multiple de 4 (avec padding)
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64Regex.hasMatch(str) && str.length % 4 == 0;
  }

  /// Vérifie si le texte a le format d'un message chiffré valide
  bool _looksLikeEncryptedText(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return false;

    final ivPart = parts[0];
    final ciphertextPart = parts[1];

    // L'IV en base64 pour 16 bytes doit faire exactement 24 caractères (avec padding ==)
    // ou 22-24 caractères selon le padding
    if (ivPart.length < 22 || ivPart.length > 24) return false;

    // Les deux parties doivent être du base64 valide
    if (!_isValidBase64(ivPart) || !_isValidBase64(ciphertextPart)) return false;

    // Le ciphertext doit avoir une longueur minimale (au moins un bloc AES = 16 bytes = ~24 chars en base64)
    if (ciphertextPart.length < 20) return false;

    return true;
  }

  /// Déchiffre le texte à partir du format "iv:base64ciphertext"
  /// Retourne le texte original si le format est invalide ou si le déchiffrement échoue
  String decryptText(String encryptedFullText) {
    if (encryptedFullText.isEmpty) return encryptedFullText;

    if (!_isInitialized || _encrypter == null) {
      debugPrint('⚠️ EncryptionService not initialized, returning encrypted text as-is');
      return encryptedFullText;
    }

    // Vérifier si le texte ressemble vraiment à du contenu chiffré
    if (!_looksLikeEncryptedText(encryptedFullText)) {
      // Pas le bon format, c'est probablement un ancien message non chiffré
      return encryptedFullText;
    }

    try {
      final parts = encryptedFullText.split(':');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      // En cas d'erreur de déchiffrement (clé changée, données corrompues)
      // Le message a été chiffré avec une autre clé et ne peut pas être récupéré
      debugPrint('⚠️ Decryption failed (likely different key): $e');
      return '[Message illisible]';
    }
  }

  /// Version asynchrone qui garantit l'initialisation
  Future<String> decryptTextAsync(String encryptedFullText) async {
    await _ensureInitialized();
    return decryptText(encryptedFullText);
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
}
