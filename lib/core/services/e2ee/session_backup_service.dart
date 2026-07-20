import 'dart:convert';
import 'dart:math' show Random;
// dart:typed_data is transitively available via flutter/foundation.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../encryption_service.dart';
import 'secure_key_storage.dart';

final sessionBackupServiceProvider = Provider<SessionBackupService>((ref) {
  return SessionBackupService(
    storage: ref.watch(secureKeyStorageProvider),
    aes: ref.watch(encryptionServiceProvider),
  );
});

/// Backs up Signal session state to Firestore and restores it on reinstall.
///
/// Two security modes:
///
///  1. **Password-protected** (recommended): the backup payload is encrypted
///     with a key derived from the user's chosen backup password via PBKDF2.
///     The server never sees the key — truly user-controlled.
///
///  2. **AES-GCM global key** (fallback / auto-backup): used for the
///     automatic push/restore flow when no password is set.  Less secure
///     (server holds the key) but better than losing all sessions on reinstall.
///
/// Firestore path:  users/{userId}/e2ee_backups/latest
class SessionBackupService {
  final SecureKeyStorage _storage;
  final EncryptionService _aes;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // PBKDF2 parameters — deliberately conservative for mobile
  static const _pbkdf2Iterations = 200000;
  static const _keyLength = 32; // AES-256
  static final _aesGcm = AesGcm.with256bits();

  SessionBackupService({
    required SecureKeyStorage storage,
    required EncryptionService aes,
  })  : _storage = storage,
        _aes = aes;

  DocumentReference _backupRef(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('e2ee_backups')
      .doc('latest');

  // ── PBKDF2 helpers ────────────────────────────────────────────────────────

  /// Derive a 256-bit AES key from [password] and [salt] using PBKDF2-HMAC-SHA256.
  Future<List<int>> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: _keyLength * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  Future<String> _encryptWithKey(String plaintext, List<int> keyBytes) async {
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );
    final combined = Uint8List.fromList([...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes]);
    return base64Encode(combined);
  }

  Future<String?> _decryptWithKey(String encoded, List<int> keyBytes) async {
    try {
      final combined = base64Decode(encoded);
      final nonceLength = _aesGcm.nonceLength;
      const macLength = 16;
      final nonce = combined.sublist(0, nonceLength);
      final cipherText = combined.sublist(nonceLength, combined.length - macLength);
      final mac = combined.sublist(combined.length - macLength);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final plain = await _aesGcm.decrypt(secretBox, secretKey: SecretKey(keyBytes));
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Export local Signal keys + sessions and store them encrypted in Firestore.
  /// Safe to call repeatedly — overwrites the previous backup.
  Future<void> push(String userId) async {
    try {
      final raw = await _storage.exportAllKeys(userId);
      final plaintext = jsonEncode(raw);
      // Variante async : garantit l'init de l'EncryptionService avant le chiffrement
      // (push est lancé en arrière-plan et peut précéder l'init au démarrage).
      final encrypted = await _aes.encryptTextAsync(plaintext);

      await _backupRef(userId).set({
        'payload': encrypted,
        'backedUpAt': FieldValue.serverTimestamp(),
        'deviceId': raw['deviceId'],
        'version': raw['version'] ?? 1,
      });
      debugPrint('SessionBackupService: pushed backup for $userId');
    } catch (e) {
      // Never block the main flow — backup is best-effort.
      debugPrint('SessionBackupService: push failed: $e');
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  /// Restore Signal keys + sessions from Firestore if no local keys exist.
  ///
  /// Call this right after [MessagingE2EEService.initialize] on first launch
  /// (or after reinstall).  Returns true when a backup was restored.
  Future<bool> restoreIfNeeded(String userId) async {
    try {
      final hasLocal = await _storage.hasE2EEKeys(userId);
      if (hasLocal) return false; // nothing to restore

      final doc = await _backupRef(userId).get();
      if (!doc.exists) {
        debugPrint('SessionBackupService: no remote backup for $userId');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>?;
      final encrypted = data?['payload'] as String?;
      if (encrypted == null || encrypted.isEmpty) return false;

      final plaintext = await _aes.decryptTextAsync(encrypted);
      if (plaintext.startsWith('[Message illisible]')) {
        debugPrint('SessionBackupService: decryption failed — key mismatch');
        return false;
      }

      final backup = jsonDecode(plaintext) as Map<String, dynamic>;
      await _storage.importAllKeys(userId, backup);
      debugPrint('SessionBackupService: restored backup for $userId');
      return true;
    } catch (e) {
      debugPrint('SessionBackupService: restore failed: $e');
      return false;
    }
  }

  // ── Password-protected backup ─────────────────────────────────────────────

  /// Backup with a user-supplied [password].
  ///
  /// A random salt is stored alongside the ciphertext in Firestore.
  /// The key is derived via PBKDF2 and never sent to the server.
  Future<void> pushWithPassword(String userId, String password) async {
    if (password.isEmpty) throw ArgumentError('Password must not be empty');
    try {
      final raw = await _storage.exportAllKeys(userId);
      final plaintext = jsonEncode(raw);

      final rng = Random.secure();
      final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));

      final keyBytes = await _deriveKey(password, salt);
      final encrypted = await _encryptWithKey(plaintext, keyBytes);

      await _backupRef(userId).set({
        'payloadPw': encrypted,
        'salt': base64Encode(salt),
        'backedUpAt': FieldValue.serverTimestamp(),
        'deviceId': raw['deviceId'],
        'version': raw['version'] ?? 1,
        'keyDerivation': 'pbkdf2-hmac-sha256',
        'iterations': _pbkdf2Iterations,
      }, SetOptions(merge: true),);
      debugPrint('SessionBackupService: password-protected backup pushed for $userId');
    } catch (e) {
      debugPrint('SessionBackupService: pushWithPassword failed: $e');
      rethrow;
    }
  }

  /// Restore from a password-protected backup.
  ///
  /// Returns `true` on success, throws [ArgumentError] on wrong password.
  Future<bool> restoreWithPassword(String userId, String password) async {
    try {
      final doc = await _backupRef(userId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      final encrypted = data?['payloadPw'] as String?;
      final saltB64 = data?['salt'] as String?;
      if (encrypted == null || saltB64 == null) return false;

      final salt = Uint8List.fromList(base64Decode(saltB64));
      final keyBytes = await _deriveKey(password, salt);
      final plaintext = await _decryptWithKey(encrypted, keyBytes);
      if (plaintext == null) {
        throw ArgumentError('Mot de passe incorrect — impossible de déchiffrer le backup');
      }

      final backup = jsonDecode(plaintext) as Map<String, dynamic>;
      await _storage.importAllKeys(userId, backup);
      debugPrint('SessionBackupService: restored password-protected backup for $userId');
      return true;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      debugPrint('SessionBackupService: restoreWithPassword failed: $e');
      return false;
    }
  }
}

