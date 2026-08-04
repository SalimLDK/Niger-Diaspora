import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/e2ee_models.dart';

/// Provider pour le service de stockage sécurisé des clés E2EE
final secureKeyStorageProvider = Provider<SecureKeyStorage>((ref) {
  return SecureKeyStorage.instance;
});

/// Service de stockage sécurisé pour les clés E2EE
///
/// Utilise:
/// - flutter_secure_storage pour les clés privées (chiffrement matériel)
/// - Hive pour le cache des sessions et métadonnées
class SecureKeyStorage {
  static final SecureKeyStorage _instance = SecureKeyStorage._internal();
  factory SecureKeyStorage() => _instance;
  SecureKeyStorage._internal();

  static SecureKeyStorage get instance => _instance;

  // Storage sécurisé pour les clés privées
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Hive boxes pour les données non-sensibles
  Box<String>? _sessionsBox;
  Box<String>? _senderKeysBox;
  Box<String>? _metadataBox;

  bool _isInitialized = false;

  // Préfixes pour les clés dans secure storage
  static const String _prefixIdentityKey = 'e2ee_identity_';
  static const String _prefixSignedPreKey = 'e2ee_signed_prekey_';
  static const String _prefixOneTimePreKey = 'e2ee_otp_';
  static const String _prefixRegistrationId = 'e2ee_registration_';
  static const String _prefixDeviceId = 'e2ee_device_id_';
  static const String _prefixSession = 'e2ee_session_';

  /// Initialise le stockage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ouvrir les boxes Hive pour les sessions et metadata
      _sessionsBox = await Hive.openBox<String>('e2ee_sessions');
      _senderKeysBox = await Hive.openBox<String>('e2ee_sender_keys');
      _metadataBox = await Hive.openBox<String>('e2ee_metadata');

      _isInitialized = true;
      // Migrate existing sessions from Hive to FlutterSecureStorage
      await _migrateSessionsFromHive();
      debugPrint('SecureKeyStorage: Initialized successfully');
    } catch (e) {
      debugPrint('SecureKeyStorage: Error initializing: $e');
      rethrow;
    }
  }

  /// Vérifie si le stockage est initialisé
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'SecureKeyStorage not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // IDENTITY KEY PAIR
  // ============================================================

  /// Stocke la paire de clés d'identité
  Future<void> storeIdentityKeyPair(
    String userId,
    E2EEIdentityKeyPair keyPair,
  ) async {
    _ensureInitialized();
    final key = '$_prefixIdentityKey$userId';
    await _secureStorage.write(key: key, value: jsonEncode(keyPair.toJson()));
    debugPrint('SecureKeyStorage: Stored identity key pair for $userId');
  }

  /// Récupère la paire de clés d'identité
  Future<E2EEIdentityKeyPair?> getIdentityKeyPair(String userId) async {
    _ensureInitialized();
    final key = '$_prefixIdentityKey$userId';
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;

    return E2EEIdentityKeyPair.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  /// Supprime la paire de clés d'identité
  Future<void> deleteIdentityKeyPair(String userId) async {
    _ensureInitialized();
    final key = '$_prefixIdentityKey$userId';
    await _secureStorage.delete(key: key);
    debugPrint('SecureKeyStorage: Deleted identity key pair for $userId');
  }

  // ============================================================
  // REGISTRATION ID
  // ============================================================

  /// Stocke le registration ID
  Future<void> storeRegistrationId(String userId, int registrationId) async {
    _ensureInitialized();
    final key = '$_prefixRegistrationId$userId';
    await _secureStorage.write(key: key, value: registrationId.toString());
  }

  /// Récupère le registration ID
  Future<int?> getRegistrationId(String userId) async {
    _ensureInitialized();
    final key = '$_prefixRegistrationId$userId';
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  // ============================================================
  // DEVICE ID
  // ============================================================

  /// Stocke le device ID
  Future<void> storeDeviceId(String userId, String deviceId) async {
    _ensureInitialized();
    final key = '$_prefixDeviceId$userId';
    await _secureStorage.write(key: key, value: deviceId);
  }

  /// Récupère le device ID
  Future<String?> getDeviceId(String userId) async {
    _ensureInitialized();
    final key = '$_prefixDeviceId$userId';
    return await _secureStorage.read(key: key);
  }

  // ============================================================
  // SIGNED PRE-KEY
  // ============================================================

  /// Stocke une Signed Pre-Key
  Future<void> storeSignedPreKey(
    String userId,
    E2EESignedPreKey signedPreKey,
  ) async {
    _ensureInitialized();
    final key = '$_prefixSignedPreKey${userId}_${signedPreKey.keyId}';
    await _secureStorage.write(
      key: key,
      value: jsonEncode(signedPreKey.toJson()),
    );

    // Stocker aussi l'ID actuel dans metadata
    await _metadataBox?.put(
      'current_signed_prekey_$userId',
      signedPreKey.keyId.toString(),
    );
    debugPrint(
      'SecureKeyStorage: Stored signed pre-key ${signedPreKey.keyId} for $userId',
    );
  }

  /// Récupère une Signed Pre-Key par ID
  Future<E2EESignedPreKey?> getSignedPreKey(String userId, int keyId) async {
    _ensureInitialized();
    final key = '$_prefixSignedPreKey${userId}_$keyId';
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;

    return E2EESignedPreKey.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  /// Récupère la Signed Pre-Key actuelle
  Future<E2EESignedPreKey?> getCurrentSignedPreKey(String userId) async {
    _ensureInitialized();
    final keyIdStr = _metadataBox?.get('current_signed_prekey_$userId');
    if (keyIdStr == null) return null;

    final keyId = int.tryParse(keyIdStr);
    if (keyId == null) return null;

    return getSignedPreKey(userId, keyId);
  }

  /// Supprime une Signed Pre-Key
  Future<void> deleteSignedPreKey(String userId, int keyId) async {
    _ensureInitialized();
    final key = '$_prefixSignedPreKey${userId}_$keyId';
    await _secureStorage.delete(key: key);
  }

  // ============================================================
  // ONE-TIME PRE-KEYS
  // ============================================================

  /// Stocke une One-Time Pre-Key
  Future<void> storeOneTimePreKey(
    String userId,
    E2EEOneTimePreKey oneTimePreKey,
  ) async {
    _ensureInitialized();
    final key = '$_prefixOneTimePreKey${userId}_${oneTimePreKey.keyId}';
    await _secureStorage.write(
      key: key,
      value: jsonEncode(oneTimePreKey.toJson()),
    );
  }

  /// Stocke plusieurs One-Time Pre-Keys
  Future<void> storeOneTimePreKeys(
    String userId,
    List<E2EEOneTimePreKey> keys,
  ) async {
    _ensureInitialized();
    for (final key in keys) {
      await storeOneTimePreKey(userId, key);
    }

    // Stocker la liste des IDs disponibles
    final ids = keys.map((k) => k.keyId.toString()).toList();
    final existingIds = await _getOneTimePreKeyIds(userId);
    final allIds = {...existingIds, ...ids}.toList();
    await _metadataBox?.put('otp_ids_$userId', jsonEncode(allIds));

    debugPrint(
      'SecureKeyStorage: Stored ${keys.length} one-time pre-keys for $userId',
    );
  }

  /// Récupère une One-Time Pre-Key par ID
  Future<E2EEOneTimePreKey?> getOneTimePreKey(String userId, int keyId) async {
    _ensureInitialized();
    final key = '$_prefixOneTimePreKey${userId}_$keyId';
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;

    return E2EEOneTimePreKey.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  /// Récupère et supprime une One-Time Pre-Key (consommation)
  Future<E2EEOneTimePreKey?> consumeOneTimePreKey(
    String userId,
    int keyId,
  ) async {
    _ensureInitialized();
    final preKey = await getOneTimePreKey(userId, keyId);
    if (preKey != null) {
      await deleteOneTimePreKey(userId, keyId);
    }
    return preKey;
  }

  /// Supprime une One-Time Pre-Key
  Future<void> deleteOneTimePreKey(String userId, int keyId) async {
    _ensureInitialized();
    final key = '$_prefixOneTimePreKey${userId}_$keyId';
    await _secureStorage.delete(key: key);

    // Mettre à jour la liste des IDs
    final ids = await _getOneTimePreKeyIds(userId);
    ids.remove(keyId.toString());
    await _metadataBox?.put('otp_ids_$userId', jsonEncode(ids));
  }

  /// Récupère le nombre de One-Time Pre-Keys disponibles
  Future<int> getOneTimePreKeyCount(String userId) async {
    _ensureInitialized();
    final ids = await _getOneTimePreKeyIds(userId);
    return ids.length;
  }

  /// Récupère les IDs des One-Time Pre-Keys disponibles
  Future<List<String>> _getOneTimePreKeyIds(String userId) async {
    final idsJson = _metadataBox?.get('otp_ids_$userId');
    if (idsJson == null) return [];
    return List<String>.from(jsonDecode(idsJson) as List);
  }

  // ============================================================
  // SESSIONS (stored in FlutterSecureStorage for hardware-backed encryption)
  // ============================================================

  /// Migrates existing sessions from Hive to FlutterSecureStorage.
  /// Called once during initialization for backward compatibility.
  Future<void> _migrateSessionsFromHive() async {
    const migratedKey = 'sessions_migrated_to_secure_storage';
    if (_metadataBox?.get(migratedKey) == 'true') return;

    final keys = _sessionsBox?.keys.toList() ?? [];
    for (final key in keys) {
      final value = _sessionsBox?.get(key);
      if (value != null && value.isNotEmpty) {
        await _secureStorage.write(
          key: '$_prefixSession$key',
          value: value,
        );
        // Keep key in Hive as index, but clear the value
        await _sessionsBox?.put(key.toString(), '');
      }
    }

    if (keys.isNotEmpty) {
      debugPrint(
        'SecureKeyStorage: Migrated ${keys.length} sessions to FlutterSecureStorage',
      );
    }
    await _metadataBox?.put(migratedKey, 'true');
  }

  /// Stocke l'état d'une session dans FlutterSecureStorage (hardware-backed).
  Future<void> storeSession(
    String recipientId,
    int deviceId,
    E2EESessionState session,
  ) async {
    _ensureInitialized();
    final key = '${recipientId}_$deviceId';
    await _secureStorage.write(
      key: '$_prefixSession$key',
      value: jsonEncode(session.toJson()),
    );
    // Keep key index in Hive for enumeration
    await _sessionsBox?.put(key, '');
    debugPrint(
      'SecureKeyStorage: Stored session for $recipientId device $deviceId',
    );
  }

  /// Récupère l'état d'une session
  Future<E2EESessionState?> getSession(String recipientId, int deviceId) async {
    _ensureInitialized();
    final key = '${recipientId}_$deviceId';
    final value = await _secureStorage.read(key: '$_prefixSession$key');
    if (value == null) return null;

    return E2EESessionState.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  /// Supprime une session
  Future<void> deleteSession(String recipientId, int deviceId) async {
    _ensureInitialized();
    final key = '${recipientId}_$deviceId';
    await _secureStorage.delete(key: '$_prefixSession$key');
    await _sessionsBox?.delete(key);
    debugPrint(
      'SecureKeyStorage: Deleted session for $recipientId device $deviceId',
    );
  }

  /// Récupère toutes les sessions d'un destinataire
  Future<List<E2EESessionState>> getSessionsForRecipient(
    String recipientId,
  ) async {
    _ensureInitialized();
    final sessions = <E2EESessionState>[];

    for (final key in _sessionsBox?.keys ?? []) {
      if (key.toString().startsWith('${recipientId}_')) {
        final value = await _secureStorage.read(
          key: '$_prefixSession${key.toString()}',
        );
        if (value != null) {
          sessions.add(
            E2EESessionState.fromJson(
              jsonDecode(value) as Map<String, dynamic>,
            ),
          );
        }
      }
    }

    return sessions;
  }

  /// Vérifie si une session existe
  Future<bool> hasSession(String recipientId, int deviceId) async {
    _ensureInitialized();
    final key = '${recipientId}_$deviceId';
    final value = await _secureStorage.read(key: '$_prefixSession$key');
    return value != null;
  }

  // ============================================================
  // SENDER KEYS (GROUPES)
  // ============================================================

  /// Stocke une Sender Key
  Future<void> storeSenderKey(E2EESenderKey senderKey) async {
    _ensureInitialized();
    final key =
        '${senderKey.groupId}_${senderKey.senderId}_${senderKey.senderDeviceId}';
    await _senderKeysBox?.put(key, jsonEncode(senderKey.toJson()));
    debugPrint(
      'SecureKeyStorage: Stored sender key for group ${senderKey.groupId}',
    );
  }

  /// Récupère une Sender Key
  Future<E2EESenderKey?> getSenderKey(
    String groupId,
    String senderId,
    int senderDeviceId,
  ) async {
    _ensureInitialized();
    final key = '${groupId}_${senderId}_$senderDeviceId';
    final value = _senderKeysBox?.get(key);
    if (value == null) return null;

    return E2EESenderKey.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  /// Supprime une Sender Key
  Future<void> deleteSenderKey(
    String groupId,
    String senderId,
    int senderDeviceId,
  ) async {
    _ensureInitialized();
    final key = '${groupId}_${senderId}_$senderDeviceId';
    await _senderKeysBox?.delete(key);
  }

  /// Récupère toutes les Sender Keys d'un groupe
  Future<List<E2EESenderKey>> getSenderKeysForGroup(String groupId) async {
    _ensureInitialized();
    final senderKeys = <E2EESenderKey>[];

    for (final key in _senderKeysBox?.keys ?? []) {
      if (key.toString().startsWith('${groupId}_')) {
        final value = _senderKeysBox?.get(key);
        if (value != null) {
          senderKeys.add(
            E2EESenderKey.fromJson(jsonDecode(value) as Map<String, dynamic>),
          );
        }
      }
    }

    return senderKeys;
  }

  /// Supprime toutes les Sender Keys d'un groupe
  Future<void> deleteAllSenderKeysForGroup(String groupId) async {
    _ensureInitialized();
    final keysToDelete = <String>[];

    for (final key in _senderKeysBox?.keys ?? []) {
      if (key.toString().startsWith('${groupId}_')) {
        keysToDelete.add(key.toString());
      }
    }

    for (final key in keysToDelete) {
      await _senderKeysBox?.delete(key);
    }

    debugPrint(
      'SecureKeyStorage: Deleted ${keysToDelete.length} sender keys for group $groupId',
    );
  }

  // ============================================================
  // METADATA & UTILS
  // ============================================================

  /// Stocke une métadonnée
  Future<void> storeMetadata(String key, String value) async {
    _ensureInitialized();
    await _metadataBox?.put(key, value);
  }

  /// Récupère une métadonnée
  String? getMetadata(String key) {
    _ensureInitialized();
    return _metadataBox?.get(key);
  }

  /// Vérifie si des clés E2EE existent pour un utilisateur
  Future<bool> hasE2EEKeys(String userId) async {
    _ensureInitialized();
    final identityKey = await getIdentityKeyPair(userId);
    return identityKey != null;
  }

  /// Exporte toutes les clés pour backup
  Future<Map<String, dynamic>> exportAllKeys(String userId) async {
    _ensureInitialized();

    final identityKeyPair = await getIdentityKeyPair(userId);
    final registrationId = await getRegistrationId(userId);
    final currentSignedPreKey = await getCurrentSignedPreKey(userId);
    final deviceId = await getDeviceId(userId);

    // Récupérer toutes les one-time pre-keys
    final otpIds = await _getOneTimePreKeyIds(userId);
    final oneTimePreKeys = <Map<String, dynamic>>[];
    for (final idStr in otpIds) {
      final id = int.tryParse(idStr);
      if (id != null) {
        final otp = await getOneTimePreKey(userId, id);
        if (otp != null) {
          oneTimePreKeys.add(otp.toJson());
        }
      }
    }

    // Récupérer toutes les sessions
    final sessions = <Map<String, dynamic>>[];
    for (final key in _sessionsBox?.keys ?? []) {
      final value = await _secureStorage.read(
        key: '$_prefixSession${key.toString()}',
      );
      if (value != null) {
        sessions.add(jsonDecode(value) as Map<String, dynamic>);
      }
    }

    return {
      'version': 1,
      'userId': userId,
      'deviceId': deviceId,
      'registrationId': registrationId,
      'identityKeyPair': identityKeyPair?.toJson(),
      'signedPreKey': currentSignedPreKey?.toJson(),
      'oneTimePreKeys': oneTimePreKeys,
      'sessions': sessions,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Importe toutes les clés depuis un backup
  Future<void> importAllKeys(String userId, Map<String, dynamic> backup) async {
    _ensureInitialized();

    // Identity Key Pair
    if (backup['identityKeyPair'] != null) {
      final identityKeyPair = E2EEIdentityKeyPair.fromJson(
        backup['identityKeyPair'] as Map<String, dynamic>,
      );
      await storeIdentityKeyPair(userId, identityKeyPair);
    }

    // Registration ID
    if (backup['registrationId'] != null) {
      await storeRegistrationId(userId, backup['registrationId'] as int);
    }

    // Device ID
    if (backup['deviceId'] != null) {
      await storeDeviceId(userId, backup['deviceId'] as String);
    }

    // Signed Pre-Key
    if (backup['signedPreKey'] != null) {
      final signedPreKey = E2EESignedPreKey.fromJson(
        backup['signedPreKey'] as Map<String, dynamic>,
      );
      await storeSignedPreKey(userId, signedPreKey);
    }

    // One-Time Pre-Keys
    final oneTimePreKeys = backup['oneTimePreKeys'] as List<dynamic>?;
    if (oneTimePreKeys != null) {
      for (final otpJson in oneTimePreKeys) {
        final otp = E2EEOneTimePreKey.fromJson(otpJson as Map<String, dynamic>);
        await storeOneTimePreKey(userId, otp);
      }

      // Mettre à jour la liste des IDs
      final ids =
          oneTimePreKeys
              .map((otp) => (otp as Map<String, dynamic>)['keyId'].toString())
              .toList();
      await _metadataBox?.put('otp_ids_$userId', jsonEncode(ids));
    }

    // Sessions
    final sessions = backup['sessions'] as List<dynamic>?;
    if (sessions != null) {
      for (final sessionJson in sessions) {
        final session = E2EESessionState.fromJson(
          sessionJson as Map<String, dynamic>,
        );
        await storeSession(
          session.recipientId,
          session.recipientDeviceId,
          session,
        );
      }
    }

    debugPrint('SecureKeyStorage: Imported keys for $userId');
  }

  /// Supprime toutes les données E2EE d'un utilisateur
  Future<void> clearAllData(String userId) async {
    _ensureInitialized();

    // Supprimer identity key
    await deleteIdentityKeyPair(userId);

    // Supprimer registration ID
    await _secureStorage.delete(key: '$_prefixRegistrationId$userId');

    // Supprimer device ID
    await _secureStorage.delete(key: '$_prefixDeviceId$userId');

    // Supprimer toutes les signed pre-keys
    final allKeys = await _secureStorage.readAll();
    for (final key in allKeys.keys) {
      if (key.startsWith('$_prefixSignedPreKey$userId') ||
          key.startsWith('$_prefixOneTimePreKey$userId')) {
        await _secureStorage.delete(key: key);
      }
    }

    // Security: only clear data for the specific user, not all users
    // Sessions: clear from both secure storage and Hive index
    final sessionKeysToDelete = <String>[];
    for (final key in _sessionsBox?.keys ?? []) {
      sessionKeysToDelete.add(key.toString());
    }
    for (final key in sessionKeysToDelete) {
      await _secureStorage.delete(key: '$_prefixSession$key');
      await _sessionsBox?.delete(key);
    }

    // Sender keys: filter by keys containing this userId
    final senderKeysToDelete = <String>[];
    for (final key in _senderKeysBox?.keys ?? []) {
      final keyStr = key.toString();
      if (keyStr.contains(userId)) {
        senderKeysToDelete.add(keyStr);
      }
    }
    for (final key in senderKeysToDelete) {
      await _senderKeysBox?.delete(key);
    }

    // Metadata: clear user-specific metadata only
    final metadataKeysToDelete = <String>[];
    for (final key in _metadataBox?.keys ?? []) {
      final keyStr = key.toString();
      if (keyStr.contains(userId)) {
        metadataKeysToDelete.add(keyStr);
      }
    }
    for (final key in metadataKeysToDelete) {
      await _metadataBox?.delete(key);
    }

    debugPrint('SecureKeyStorage: Cleared all data for $userId');
  }

  /// Ferme le stockage
  Future<void> close() async {
    await _sessionsBox?.close();
    await _senderKeysBox?.close();
    await _metadataBox?.close();
    _isInitialized = false;
    debugPrint('SecureKeyStorage: Closed');
  }
}
