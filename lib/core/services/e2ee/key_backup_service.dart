import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'eff_wordlist.dart';
import 'models/e2ee_models.dart';
import 'secure_key_storage.dart';

/// Provider pour le service de backup des clés
final keyBackupServiceProvider = Provider<KeyBackupService>((ref) {
  final storage = ref.watch(secureKeyStorageProvider);
  return KeyBackupService(storage: storage);
});

/// Service de sauvegarde et restauration des clés E2EE
///
/// Utilise une passphrase utilisateur pour chiffrer les clés avant
/// de les stocker sur Firebase Storage. Le serveur ne peut pas
/// déchiffrer les clés sans la passphrase.
///
/// Sécurité:
/// - PBKDF2 avec 200,000 itérations pour dériver la clé de chiffrement
/// - AES-256-GCM pour le chiffrement authentifié
/// - Salt aléatoire par backup
class KeyBackupService {
  final SecureKeyStorage _storage;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  // Algorithmes cryptographiques
  final _aesGcm = AesGcm.with256bits();
  final _random = Random.secure();

  // Configuration PBKDF2 — 200k iterations matches OWASP 2023 recommendation
  static const int _pbkdf2Iterations = 200000;
  static const int _saltLength = 32;
  static const int _keyLength = 32; // 256 bits

  KeyBackupService({required SecureKeyStorage storage}) : _storage = storage;

  // ============================================================
  // CRÉATION DE BACKUP
  // ============================================================

  /// Crée un backup chiffré des clés E2EE
  ///
  /// [userId] - L'ID de l'utilisateur
  /// [passphrase] - La passphrase pour chiffrer le backup (minimum 8 caractères)
  /// [deviceInfo] - Informations sur l'appareil source (optionnel)
  ///
  /// Returns: Le backup chiffré prêt à être uploadé
  Future<E2EEEncryptedBackup> createBackup(
    String userId,
    String passphrase, {
    String? deviceInfo,
  }) async {
    // Valider la passphrase
    if (passphrase.length < 8) {
      throw ArgumentError('Passphrase must be at least 8 characters');
    }

    // Exporter toutes les clés
    final keysData = await _storage.exportAllKeys(userId);
    final keysJson = jsonEncode(keysData);
    final keysBytes = utf8.encode(keysJson);

    // Générer un salt aléatoire
    final salt = _generateRandomBytes(_saltLength);

    // Dériver la clé de chiffrement avec PBKDF2
    final encryptionKey = await _deriveKeyFromPassphrase(passphrase, salt);

    // Chiffrer avec AES-GCM
    final secretBox = await _aesGcm.encrypt(
      keysBytes,
      secretKey: encryptionKey,
    );

    // Créer le backup
    final backup = E2EEEncryptedBackup(
      version: 1,
      saltBase64: base64Encode(salt),
      ivBase64: base64Encode(secretBox.nonce),
      ciphertextBase64: base64Encode(secretBox.cipherText),
      authTagBase64: base64Encode(secretBox.mac.bytes),
      deviceInfo: deviceInfo ?? _getDefaultDeviceInfo(),
      createdAt: DateTime.now(),
    );

    debugPrint('KeyBackupService: Created encrypted backup for $userId');
    return backup;
  }

  /// Crée et uploade un backup sur Firebase Storage
  Future<String> createAndUploadBackup(
    String userId,
    String passphrase, {
    String? deviceInfo,
  }) async {
    final backup = await createBackup(userId, passphrase, deviceInfo: deviceInfo);
    final path = await uploadBackup(userId, backup);
    return path;
  }

  // ============================================================
  // UPLOAD / DOWNLOAD
  // ============================================================

  /// Uploade un backup chiffré sur Firebase Storage
  Future<String> uploadBackup(String userId, E2EEEncryptedBackup backup) async {
    final path = 'key_backups/$userId/backup.enc';
    final ref = _firebaseStorage.ref(path);

    final backupJson = jsonEncode(backup.toJson());
    final backupBytes = utf8.encode(backupJson);

    await ref.putData(
      Uint8List.fromList(backupBytes),
      SettableMetadata(
        contentType: 'application/json',
        customMetadata: {
          'version': backup.version.toString(),
          'createdAt': backup.createdAt.toUtc().toIso8601String(),
          'deviceInfo': backup.deviceInfo,
        },
      ),
    );

    debugPrint('KeyBackupService: Uploaded backup to $path');
    return path;
  }

  /// Télécharge un backup depuis Firebase Storage
  Future<E2EEEncryptedBackup?> downloadBackup(String userId) async {
    try {
      final path = 'key_backups/$userId/backup.enc';
      final ref = _firebaseStorage.ref(path);

      final data = await ref.getData();
      if (data == null) {
        debugPrint('KeyBackupService: No backup found for $userId');
        return null;
      }

      final backupJson = utf8.decode(data);
      final backupMap = jsonDecode(backupJson) as Map<String, dynamic>;

      debugPrint('KeyBackupService: Downloaded backup for $userId');
      return E2EEEncryptedBackup.fromJson(backupMap);
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        debugPrint('KeyBackupService: No backup exists for $userId');
        return null;
      }
      debugPrint('KeyBackupService: Error downloading backup: $e');
      return null;
    }
  }

  /// Détermine l'état de présence du backup distant en distinguant « absent »
  /// de « injoignable ».
  ///
  /// [BackupPresence.absent] n'est renvoyé que si le stockage confirme
  /// explicitement l'absence de l'objet (`object-not-found`). Toute autre
  /// erreur (réseau, permission, quota…) donne [BackupPresence.unknown] : le
  /// backup peut exister, l'appelant ne doit alors PAS supposer son absence
  /// (sous peine d'écraser une identité restaurable).
  Future<BackupPresence> checkBackupPresence(String userId) async {
    try {
      final path = 'key_backups/$userId/backup.enc';
      final ref = _firebaseStorage.ref(path);
      await ref.getMetadata();
      return BackupPresence.present;
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        return BackupPresence.absent;
      }
      debugPrint(
        'KeyBackupService: backup presence unknown (${e.runtimeType}): $e',
      );
      return BackupPresence.unknown;
    }
  }

  /// Vrai si un backup existe de façon confirmée.
  ///
  /// Note : renvoie `false` aussi bien pour « absent » que pour « injoignable ».
  /// Pour prendre une décision destructrice (générer de nouvelles clés),
  /// utiliser [checkBackupPresence] et traiter `unknown` prudemment.
  Future<bool> hasBackup(String userId) async {
    return (await checkBackupPresence(userId)) == BackupPresence.present;
  }

  /// Récupère les métadonnées du backup sans le télécharger
  Future<BackupMetadata?> getBackupMetadata(String userId) async {
    try {
      final path = 'key_backups/$userId/backup.enc';
      final ref = _firebaseStorage.ref(path);
      final metadata = await ref.getMetadata();

      return BackupMetadata(
        createdAt: DateTime.tryParse(metadata.customMetadata?['createdAt'] ?? '')?.toLocal(),
        deviceInfo: metadata.customMetadata?['deviceInfo'],
        sizeBytes: metadata.size,
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // RESTAURATION DE BACKUP
  // ============================================================

  /// Restaure les clés depuis un backup chiffré
  ///
  /// [userId] - L'ID de l'utilisateur
  /// [backup] - Le backup chiffré
  /// [passphrase] - La passphrase pour déchiffrer
  ///
  /// Throws: Exception si la passphrase est incorrecte
  Future<void> restoreBackup(
    String userId,
    E2EEEncryptedBackup backup,
    String passphrase,
  ) async {
    // Dériver la clé de déchiffrement
    final salt = base64Decode(backup.saltBase64);
    final encryptionKey = await _deriveKeyFromPassphrase(passphrase, salt);

    // Reconstruire le SecretBox
    final secretBox = SecretBox(
      base64Decode(backup.ciphertextBase64),
      nonce: base64Decode(backup.ivBase64),
      mac: Mac(base64Decode(backup.authTagBase64)),
    );

    // Déchiffrer
    List<int> keysBytes;
    try {
      keysBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: encryptionKey,
      );
    } catch (e) {
      throw PassphraseException('Invalid passphrase or corrupted backup');
    }

    // Parser et importer les clés
    final keysJson = utf8.decode(keysBytes);
    final keysData = jsonDecode(keysJson) as Map<String, dynamic>;

    await _storage.importAllKeys(userId, keysData);

    debugPrint('KeyBackupService: Restored backup for $userId');
  }

  /// Télécharge et restaure un backup depuis Firebase Storage
  Future<void> downloadAndRestoreBackup(String userId, String passphrase) async {
    final backup = await downloadBackup(userId);
    if (backup == null) {
      throw BackupNotFoundException('No backup found for user');
    }

    await restoreBackup(userId, backup, passphrase);
  }

  /// Vérifie si une passphrase est correcte pour un backup
  Future<bool> verifyPassphrase(
    E2EEEncryptedBackup backup,
    String passphrase,
  ) async {
    try {
      final salt = base64Decode(backup.saltBase64);
      final encryptionKey = await _deriveKeyFromPassphrase(passphrase, salt);

      final secretBox = SecretBox(
        base64Decode(backup.ciphertextBase64),
        nonce: base64Decode(backup.ivBase64),
        mac: Mac(base64Decode(backup.authTagBase64)),
      );

      // Tenter de déchiffrer
      await _aesGcm.decrypt(secretBox, secretKey: encryptionKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GESTION DU BACKUP
  // ============================================================

  /// Supprime le backup d'un utilisateur
  Future<void> deleteBackup(String userId) async {
    try {
      final path = 'key_backups/$userId/backup.enc';
      final ref = _firebaseStorage.ref(path);
      await ref.delete();
      debugPrint('KeyBackupService: Deleted backup for $userId');
    } catch (e) {
      debugPrint('KeyBackupService: Error deleting backup: $e');
    }
  }

  /// Met à jour le backup existant avec une nouvelle passphrase
  Future<void> updateBackupPassphrase(
    String userId,
    String oldPassphrase,
    String newPassphrase,
  ) async {
    // Télécharger et déchiffrer avec l'ancienne passphrase
    final backup = await downloadBackup(userId);
    if (backup == null) {
      throw BackupNotFoundException('No backup found');
    }

    // Vérifier l'ancienne passphrase
    final isValid = await verifyPassphrase(backup, oldPassphrase);
    if (!isValid) {
      throw PassphraseException('Invalid old passphrase');
    }

    // Restaurer temporairement pour obtenir les clés
    final salt = base64Decode(backup.saltBase64);
    final oldKey = await _deriveKeyFromPassphrase(oldPassphrase, salt);

    final secretBox = SecretBox(
      base64Decode(backup.ciphertextBase64),
      nonce: base64Decode(backup.ivBase64),
      mac: Mac(base64Decode(backup.authTagBase64)),
    );

    final keysBytes = await _aesGcm.decrypt(secretBox, secretKey: oldKey);
    final keysJson = utf8.decode(keysBytes);

    // Créer un nouveau backup avec la nouvelle passphrase
    final newSalt = _generateRandomBytes(_saltLength);
    final newKey = await _deriveKeyFromPassphrase(newPassphrase, newSalt);

    final newSecretBox = await _aesGcm.encrypt(
      utf8.encode(keysJson),
      secretKey: newKey,
    );

    final newBackup = E2EEEncryptedBackup(
      version: backup.version,
      saltBase64: base64Encode(newSalt),
      ivBase64: base64Encode(newSecretBox.nonce),
      ciphertextBase64: base64Encode(newSecretBox.cipherText),
      authTagBase64: base64Encode(newSecretBox.mac.bytes),
      deviceInfo: backup.deviceInfo,
      createdAt: DateTime.now(),
    );

    // Uploader le nouveau backup
    await uploadBackup(userId, newBackup);
    debugPrint('KeyBackupService: Updated backup passphrase for $userId');
  }

  // ============================================================
  // UTILITAIRES CRYPTOGRAPHIQUES
  // ============================================================

  /// Dérive une clé de chiffrement à partir d'une passphrase avec PBKDF2
  Future<SecretKey> _deriveKeyFromPassphrase(String passphrase, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: _keyLength * 8,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    return secretKey;
  }

  /// Génère des bytes aléatoires sécurisés
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Obtient les informations de l'appareil par défaut
  String _getDefaultDeviceInfo() {
    return '${defaultTargetPlatform.name} Device';
  }

  // ============================================================
  // VALIDATION DE PASSPHRASE
  // ============================================================

  /// Évalue la force d'une passphrase
  PassphraseStrength evaluatePassphraseStrength(String passphrase) {
    if (passphrase.length < 8) {
      return PassphraseStrength.weak;
    }

    int score = 0;

    // Longueur
    if (passphrase.length >= 12) score++;
    if (passphrase.length >= 16) score++;

    // Complexité
    if (RegExp(r'[a-z]').hasMatch(passphrase)) score++;
    if (RegExp(r'[A-Z]').hasMatch(passphrase)) score++;
    if (RegExp(r'[0-9]').hasMatch(passphrase)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(passphrase)) score++;

    if (score >= 5) return PassphraseStrength.strong;
    if (score >= 3) return PassphraseStrength.medium;
    return PassphraseStrength.weak;
  }

  /// Génère une passphrase aléatoire sécurisée de style Diceware.
  ///
  /// Les mots sont tirés (avec `Random.secure`) dans la liste EFF « large »
  /// de 7776 mots ([kEffLargeWordlist]), soit ~12.9 bits d'entropie par mot.
  /// Le défaut de 6 mots donne ~77 bits, très au-dessus du seuil de force
  /// brute exploitable — l'EFF recommande 6 mots minimum.
  ///
  /// Un chiffre à deux positions est ajouté à la fin pour satisfaire les
  /// vérificateurs de complexité qui exigent un caractère numérique
  /// ([evaluatePassphraseStrength]) ; il ne constitue pas la sécurité.
  String generateSecurePassphrase({int wordCount = 6}) {
    final selectedWords = <String>[];
    for (var i = 0; i < wordCount; i++) {
      selectedWords.add(kEffLargeWordlist[_random.nextInt(kEffLargeWordlist.length)]);
    }

    // Ajouter un chiffre aléatoire (complexité, pas entropie principale)
    final number = _random.nextInt(100).toString().padLeft(2, '0');

    return '${selectedWords.join('-')}-$number';
  }
}

/// Force de la passphrase
enum PassphraseStrength {
  weak,
  medium,
  strong,
}

/// État de présence d'un backup distant, avec distinction « injoignable ».
enum BackupPresence {
  /// Le backup existe (confirmé).
  present,

  /// Le backup n'existe pas (confirmé par le stockage : `object-not-found`).
  absent,

  /// Impossible de déterminer (réseau, permission, quota…). Ne PAS supposer
  /// l'absence : le backup peut exister.
  unknown,
}

/// Métadonnées d'un backup
class BackupMetadata {
  final DateTime? createdAt;
  final String? deviceInfo;
  final int? sizeBytes;

  const BackupMetadata({
    this.createdAt,
    this.deviceInfo,
    this.sizeBytes,
  });
}

/// Exception pour passphrase invalide
class PassphraseException implements Exception {
  final String message;
  PassphraseException(this.message);

  @override
  String toString() => 'PassphraseException: $message';
}

/// Exception pour backup non trouvé
class BackupNotFoundException implements Exception {
  final String message;
  BackupNotFoundException(this.message);

  @override
  String toString() => 'BackupNotFoundException: $message';
}
