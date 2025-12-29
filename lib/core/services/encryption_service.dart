import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

class EncryptionService {
  static const String _keyStorageKey = 'diaspo_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  encrypt.Key? _key;
  encrypt.Encrypter? _encrypter;
  bool _isInitialized = false;

  /// Initialize the encryption service by loading or generating the key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      String? storedKey = await _secureStorage.read(key: _keyStorageKey);

      if (storedKey == null || storedKey.isEmpty) {
        // Generate a new random 32-byte key for AES-256
        storedKey = _generateSecureKey();
        await _secureStorage.write(key: _keyStorageKey, value: storedKey);
        debugPrint('🔐 Generated new encryption key');
      } else {
        debugPrint('🔐 Loaded existing encryption key');
      }

      _key = encrypt.Key.fromBase64(storedKey);
      _encrypter = encrypt.Encrypter(
        encrypt.AES(_key!, mode: encrypt.AESMode.cbc),
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing encryption service: $e');
      // Fallback to a derived key if secure storage fails
      _useFallbackKey();
    }
  }

  /// Generate a cryptographically secure random 32-byte key
  String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Fallback key derivation (only used if secure storage fails)
  void _useFallbackKey() {
    // Use a deterministic but unique key based on a salt
    // This is less secure but ensures the app doesn't crash
    const fallbackSalt = 'diaspo_niger_fallback_2025';
    final bytes = utf8.encode(fallbackSalt.padRight(32, 'x').substring(0, 32));
    _key = encrypt.Key(Uint8List.fromList(bytes));
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key!, mode: encrypt.AESMode.cbc),
    );
    _isInitialized = true;
    debugPrint('⚠️ Using fallback encryption key');
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

  /// Déchiffre le texte à partir du format "iv:base64ciphertext"
  /// Retourne le texte original si le format est invalide ou si le déchiffrement échoue
  String decryptText(String encryptedFullText) {
    if (encryptedFullText.isEmpty) return encryptedFullText;

    if (!_isInitialized || _encrypter == null) {
      debugPrint('⚠️ EncryptionService not initialized, returning encrypted text as-is');
      return encryptedFullText;
    }

    try {
      final parts = encryptedFullText.split(':');
      if (parts.length != 2) {
        // Pas le bon format, on suppose que c'est un ancien message non chiffré
        return encryptedFullText;
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      // En cas d'erreur (clé changée, données corrompues, format legacy bizarre), on retourne le texte tel quel
      debugPrint('⚠️ Decryption failed, returning original text: $e');
      return encryptedFullText;
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
