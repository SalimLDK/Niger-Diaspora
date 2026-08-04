import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../supabase_auth_bridge.dart';
import 'models/e2ee_models.dart';
import 'secure_key_storage.dart';

/// Provider pour le service de gestion des clés E2EE
final keyManagerServiceProvider = Provider<KeyManagerService>((ref) {
  final storage = ref.watch(secureKeyStorageProvider);
  return KeyManagerService(storage: storage);
});

/// Service de gestion des clés pour le protocole E2EE
///
/// Responsabilités:
/// - Génération des paires de clés (Identity, Signed Pre-Key, One-Time Pre-Keys)
/// - Publication des clés publiques sur Supabase
/// - Rotation des Signed Pre-Keys
/// - Rechargement des One-Time Pre-Keys
class KeyManagerService {
  final SecureKeyStorage _storage;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Algorithmes cryptographiques
  final _x25519 = X25519();
  final _random = Random.secure();

  // Configuration
  static const int _oneTimePreKeyBatchSize = 100;

  /// Lot généré au TOUT PREMIER lancement, plus petit que [_oneTimePreKeyBatchSize].
  ///
  /// Chaque clé est une paire X25519 générée séquentiellement sur l'isolate
  /// principal : sur un appareil d'entrée de gamme, 100 clés retardent la fin
  /// de l'initialisation de plusieurs dizaines de secondes (bien plus en debug,
  /// où la crypto Dart n'est pas optimisée). 50 suffisent largement à démarrer —
  /// le rechargement automatique complète le stock ensuite, en arrière-plan.
  static const int _initialOneTimePreKeyBatchSize = 50;

  static const int _oneTimePreKeyMinThreshold = 20;
  static const Duration _signedPreKeyRotationPeriod = Duration(days: 7);

  KeyManagerService({required SecureKeyStorage storage}) : _storage = storage;

  /// Génère un Registration ID unique (1 à 16380)
  int _generateRegistrationId() {
    return _random.nextInt(16380) + 1;
  }

  /// Génère un ID de clé unique
  int _generateKeyId() {
    return _random.nextInt(0x7FFFFFFF);
  }

  /// Génère un Device ID unique
  String _generateDeviceId() {
    return const Uuid().v4();
  }

  /// Génère une paire de clés Curve25519
  Future<E2EEIdentityKeyPair> _generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    return E2EEIdentityKeyPair(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
    );
  }

  /// Signs data using Ed25519 for proper asymmetric digital signatures.
  /// Security: replaced HMAC-SHA256 (symmetric) with Ed25519 (asymmetric)
  /// to provide actual sender authenticity guarantees.
  Future<Uint8List> _sign(Uint8List data, Uint8List privateKey) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(privateKey);
    final signature = await algorithm.sign(data, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 signature against the signer's public key.
  Future<bool> verifySignature(
    Uint8List data,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    final algorithm = Ed25519();
    final sig = Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519));
    return algorithm.verify(data, signature: sig);
  }

  // ============================================================
  // INITIALISATION DES CLÉS
  // ============================================================

  /// Initialise les clés E2EE pour un nouvel utilisateur/appareil
  ///
  /// Génère:
  /// - Identity Key Pair
  /// - Signed Pre-Key
  /// - Batch de One-Time Pre-Keys
  /// - Registration ID
  /// - Device ID
  Future<void> initializeKeys(String userId) async {
    debugPrint('KeyManagerService: Initializing keys for user $userId');

    // Vérifier si des clés existent déjà localement
    final existingKeys = await _storage.hasE2EEKeys(userId);
    if (existingKeys) {
      debugPrint('KeyManagerService: Keys already exist for $userId');
      // Keys exist locally but may not be published to Supabase yet
      // (e.g. first launch after migrating from Firebase key storage).
      await _ensurePublishedToSupabase(userId);
      return;
    }

    // 1. Générer Registration ID
    final registrationId = _generateRegistrationId();
    await _storage.storeRegistrationId(userId, registrationId);

    // 2. Générer Device ID
    final deviceId = _generateDeviceId();
    await _storage.storeDeviceId(userId, deviceId);

    // 3. Générer Identity Key Pair
    final identityKeyPair = await _generateKeyPair();
    await _storage.storeIdentityKeyPair(userId, identityKeyPair);

    // 4. Générer Signed Pre-Key
    await _generateAndStoreSignedPreKey(userId, identityKeyPair);

    // 5. Générer batch de One-Time Pre-Keys (lot initial réduit — cf. constante)
    await _generateAndStoreOneTimePreKeys(
      userId,
      _initialOneTimePreKeyBatchSize,
    );

    // 6. Publier les clés publiques sur Supabase (avec retry + garde d'auth)
    await _publishWithRetry(userId);

    debugPrint('KeyManagerService: Keys initialized for $userId');
  }

  /// Génère et stocke une nouvelle Signed Pre-Key
  Future<E2EESignedPreKey> _generateAndStoreSignedPreKey(
    String userId,
    E2EEIdentityKeyPair identityKeyPair,
  ) async {
    final keyPair = await _generateKeyPair();
    final keyId = _generateKeyId();

    // Signer la clé publique avec l'Identity Key
    final signature = await _sign(
      keyPair.publicKey,
      identityKeyPair.privateKey,
    );

    final signedPreKey = E2EESignedPreKey(
      keyId: keyId,
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
      signature: signature,
      createdAt: DateTime.now(),
    );

    await _storage.storeSignedPreKey(userId, signedPreKey);
    return signedPreKey;
  }

  /// Génère et stocke un batch de One-Time Pre-Keys
  Future<List<E2EEOneTimePreKey>> _generateAndStoreOneTimePreKeys(
    String userId,
    int count,
  ) async {
    final keys = <E2EEOneTimePreKey>[];

    for (var i = 0; i < count; i++) {
      final keyPair = await _generateKeyPair();
      final keyId = _generateKeyId();

      final oneTimePreKey = E2EEOneTimePreKey(
        keyId: keyId,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
      );

      keys.add(oneTimePreKey);
    }

    await _storage.storeOneTimePreKeys(userId, keys);
    debugPrint('KeyManagerService: Generated $count one-time pre-keys');
    return keys;
  }

  /// Re-publishes local keys to Supabase if no server record exists yet.
  /// Called on first launch after migrating from Firebase key storage.
  Future<void> _ensurePublishedToSupabase(String userId) async {
    try {
      // Lecture aussi soumise au RLS : sans session valide, elle renverrait
      // null et déclencherait une re-publication (qui elle-même retentera).
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        debugPrint('KeyManagerService: session non prête — publication différée');
        await _publishWithRetry(userId);
        return;
      }
      // La table qui fait autorité pour « le destinataire a des clés » est
      // e2ee_user_keys.active_devices (cf. fetchPreKeyBundle) : on vérifie
      // qu'une ligne existe ET qu'un appareil actif y figure.
      final row = await _supabase
          .from('e2ee_user_keys')
          .select('active_devices')
          .eq('user_id', userId)
          .maybeSingle();
      final activeDevices =
          List<String>.from((row?['active_devices'] as List?) ?? []);
      if (row == null || activeDevices.isEmpty) {
        debugPrint('KeyManagerService: Keys not on Supabase — re-publishing');
        await _publishWithRetry(userId);
      }
    } catch (e) {
      debugPrint('KeyManagerService: _ensurePublishedToSupabase error: $e');
    }
  }

  // ============================================================
  // PUBLICATION SUR SUPABASE
  // ============================================================

  /// Publie les clés publiques sur Supabase avec retry.
  ///
  /// La publication échouait silencieusement quand elle partait avant que le
  /// pont de session Supabase (Firebase→JWT) ne soit établi : les écritures
  /// étaient bloquées par RLS (session anon), l'erreur avalée, et l'utilisateur
  /// restait sans clés publiées (donc injoignable en E2EE). On garantit ici une
  /// session valide et on réessaie pour couvrir la fenêtre de démarrage.
  Future<void> _publishWithRetry(String userId) async {
    const maxAttempts = 4;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _publishKeysToSupabase(userId);
        return;
      } catch (e) {
        debugPrint(
          'KeyManagerService: publish attempt $attempt/$maxAttempts failed: $e',
        );
        if (attempt == maxAttempts) rethrow;
        // Backoff progressif : laisse le temps au pont de session de s'établir.
        await Future.delayed(Duration(seconds: attempt * 3));
      }
    }
  }

  /// Publie les clés publiques sur Supabase
  Future<void> _publishKeysToSupabase(String userId) async {
    // Toute écriture Supabase exige une session valide (RLS bloque l'anon).
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw StateError('Session Supabase non établie — publication différée');
    }

    final identityKeyPair = await _storage.getIdentityKeyPair(userId);
    final signedPreKey = await _storage.getCurrentSignedPreKey(userId);
    final registrationId = await _storage.getRegistrationId(userId);
    final deviceId = await _storage.getDeviceId(userId);

    if (identityKeyPair == null ||
        signedPreKey == null ||
        registrationId == null) {
      throw StateError('Missing keys for publishing');
    }

    // 1. Upsert device row
    await _supabase.from('e2ee_devices').upsert({
      'user_id': userId,
      'device_id': deviceId,
      'registration_id': registrationId,
      'identity_key': identityKeyPair.publicKeyBase64,
      'signed_pre_key': {
        'keyId': signedPreKey.keyId,
        'publicKey': signedPreKey.publicKeyBase64,
        'signature': signedPreKey.signatureBase64,
        'createdAt': signedPreKey.createdAt.toUtc().toIso8601String(),
      },
      'platform': defaultTargetPlatform.name,
      'last_active': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,device_id',);

    // 2. Atomically add device to active_devices
    await _supabase.rpc('e2ee_add_active_device', params: {
      'p_user_id': userId,
      'p_device_id': deviceId,
    },);

    // 3. Publish OTPs
    await _publishOneTimePreKeysToSupabase(userId, deviceId!);

    debugPrint('KeyManagerService: Published keys to Supabase');
  }

  /// Publie les One-Time Pre-Keys sur Supabase
  Future<void> _publishOneTimePreKeysToSupabase(
    String userId,
    String deviceId,
  ) async {
    // Garde d'auth : appelé aussi hors _publishKeysToSupabase (refill OTP).
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw StateError('Session Supabase non établie — OTP non publiées');
    }
    // Supprimer les anciennes clés pour cet appareil
    await _supabase
        .from('e2ee_one_time_prekeys')
        .delete()
        .eq('user_id', userId)
        .eq('device_id', deviceId);

    // Générer un nouveau batch (clés privées stockées localement)
    final newKeys = await _generateAndStoreOneTimePreKeys(
      userId,
      _oneTimePreKeyBatchSize,
    );

    // Insérer seulement les clés publiques (batch)
    await _supabase.from('e2ee_one_time_prekeys').insert(
      newKeys.map((k) => {
        'user_id': userId,
        'device_id': deviceId,
        'key_id': k.keyId,
        'public_key': k.publicKeyBase64,
      },).toList(),
    );

    debugPrint(
      'KeyManagerService: Published ${newKeys.length} one-time pre-keys',
    );
  }

  // ============================================================
  // RÉCUPÉRATION DES PRE-KEY BUNDLES
  // ============================================================

  /// Returns all active device IDs registered for [userId].
  /// Used by [MessageCryptoService] to encrypt for every device.
  Future<List<String>> getActiveDevices(String userId) async {
    try {
      final row = await _supabase
          .from('e2ee_user_keys')
          .select('active_devices')
          .eq('user_id', userId)
          .maybeSingle();
      return List<String>.from((row?['active_devices'] as List?) ?? []);
    } catch (e) {
      debugPrint('KeyManagerService: getActiveDevices error: $e');
      return [];
    }
  }

  /// Récupère le Pre-Key Bundle d'un destinataire pour établir une session
  Future<E2EEPreKeyBundle?> fetchPreKeyBundle(
    String recipientId, {
    int? deviceId,
  }) async {
    try {
      // 1. Get active devices
      final userRow = await _supabase
          .from('e2ee_user_keys')
          .select('active_devices')
          .eq('user_id', recipientId)
          .maybeSingle();

      if (userRow == null) {
        debugPrint('KeyManagerService: No keys found for $recipientId');
        return null;
      }

      final activeDevices = List<String>.from(
        (userRow['active_devices'] as List?) ?? [],
      );
      if (activeDevices.isEmpty) {
        debugPrint('KeyManagerService: No active devices for $recipientId');
        return null;
      }

      // Sélectionner l'appareil (premier par défaut ou spécifié)
      final targetDeviceId = deviceId?.toString() ?? activeDevices.first;

      // 2. Fetch device bundle
      final deviceRow = await _supabase
          .from('e2ee_devices')
          .select()
          .eq('user_id', recipientId)
          .eq('device_id', targetDeviceId)
          .maybeSingle();

      if (deviceRow == null) {
        debugPrint(
          'KeyManagerService: Device $targetDeviceId not found for $recipientId',
        );
        return null;
      }

      // 3. Consume OTP atomically via RPC
      final dynamic otpRaw = await _supabase.rpc('consume_one_time_prekey', params: {
        'p_user_id': recipientId,
        'p_device_id': targetDeviceId,
      },);

      final otpMap = otpRaw as Map<String, dynamic>?;
      final String? otpPublicKey = otpMap?['publicKey'] as String?;
      final int? otpKeyId = otpMap?['keyId'] as int?;

      // Build bundle from deviceRow
      final signedPreKey = deviceRow['signed_pre_key'] as Map<String, dynamic>;

      return E2EEPreKeyBundle(
        userId: recipientId,
        deviceId: int.tryParse(targetDeviceId) ?? 1,
        registrationId: deviceRow['registration_id'] as int,
        identityKey: deviceRow['identity_key'] as String,
        signedPreKeyId: signedPreKey['keyId'] as int,
        signedPreKeyPublic: signedPreKey['publicKey'] as String,
        signedPreKeySignature: signedPreKey['signature'] as String,
        oneTimePreKeyId: otpKeyId,
        oneTimePreKeyPublic: otpPublicKey,
      );
    } catch (e) {
      debugPrint('KeyManagerService: Error fetching pre-key bundle: $e');
      return null;
    }
  }

  /// Récupère les Pre-Key Bundles de tous les appareils d'un destinataire
  Future<List<E2EEPreKeyBundle>> fetchAllPreKeyBundles(
    String recipientId,
  ) async {
    final bundles = <E2EEPreKeyBundle>[];

    try {
      final userRow = await _supabase
          .from('e2ee_user_keys')
          .select('active_devices')
          .eq('user_id', recipientId)
          .maybeSingle();

      if (userRow == null) return bundles;

      final activeDevices = List<String>.from(
        (userRow['active_devices'] as List?) ?? [],
      );

      for (final deviceId in activeDevices) {
        final bundle = await fetchPreKeyBundle(
          recipientId,
          deviceId: int.tryParse(deviceId.toString()),
        );
        if (bundle != null) {
          bundles.add(bundle);
        }
      }
    } catch (e) {
      debugPrint('KeyManagerService: Error fetching all pre-key bundles: $e');
    }

    return bundles;
  }

  // ============================================================
  // ROTATION ET MAINTENANCE DES CLÉS
  // ============================================================

  /// Vérifie et effectue la rotation de la Signed Pre-Key si nécessaire
  Future<void> checkAndRotateSignedPreKey(String userId) async {
    final currentSignedPreKey = await _storage.getCurrentSignedPreKey(userId);
    if (currentSignedPreKey == null) return;

    final age = DateTime.now().difference(currentSignedPreKey.createdAt);
    if (age > _signedPreKeyRotationPeriod) {
      await rotateSignedPreKey(userId);
    }
  }

  /// Effectue la rotation de la Signed Pre-Key
  Future<void> rotateSignedPreKey(String userId) async {
    final identityKeyPair = await _storage.getIdentityKeyPair(userId);
    if (identityKeyPair == null) {
      throw StateError('No identity key pair found');
    }

    final newSignedPreKey = await _generateAndStoreSignedPreKey(
      userId,
      identityKeyPair,
    );

    // Publier la nouvelle Signed Pre-Key sur Supabase
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId != null) {
      await _supabase.from('e2ee_devices').update({
        'signed_pre_key': {
          'keyId': newSignedPreKey.keyId,
          'publicKey': newSignedPreKey.publicKeyBase64,
          'signature': newSignedPreKey.signatureBase64,
          'createdAt': newSignedPreKey.createdAt.toUtc().toIso8601String(),
        },
        'last_active': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).eq('device_id', deviceId);
    }

    debugPrint('KeyManagerService: Rotated signed pre-key');
  }

  /// Vérifie et recharge les One-Time Pre-Keys si nécessaire
  Future<void> checkAndRefillOneTimePreKeys(String userId) async {
    final localCount = await _storage.getOneTimePreKeyCount(userId);

    // Le compteur local ne dit rien de ce que le serveur expose réellement.
    // Un appareil dont la publication initiale a échoué — session Supabase pas
    // prête, ou policy RLS qui refusait l'insertion — garde ses clés en local
    // et ne repasse donc jamais sous le seuil : il resterait sans aucune
    // prékey publiée à vie, et ses correspondants ouvriraient leurs sessions
    // sans DH4, donc sans la protection du message initial.
    final publishedCount = await _countPublishedOneTimePreKeys(userId);

    final localTooLow = localCount < _oneTimePreKeyMinThreshold;
    // `null` = comptage impossible (réseau, session) : on ne republie pas sur
    // une simple incertitude, sinon une coupure suffirait à régénérer un lot
    // complet à chaque démarrage.
    final serverTooLow = publishedCount != null &&
        publishedCount < _oneTimePreKeyMinThreshold;

    if (localTooLow || serverTooLow) {
      if (serverTooLow && !localTooLow) {
        debugPrint(
          'KeyManagerService: $localCount prékeys en local mais '
          '$publishedCount publiées — republication',
        );
      }
      await refillOneTimePreKeys(userId);
    }
  }

  /// Nombre de prékeys réellement exposées par le serveur pour l'appareil
  /// courant, ou `null` si le compte n'a pas pu être établi.
  Future<int?> _countPublishedOneTimePreKeys(String userId) async {
    try {
      final deviceId = await _storage.getDeviceId(userId);
      if (deviceId == null) return null;

      final rows = await _supabase
          .from('e2ee_one_time_prekeys')
          .select('key_id')
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      return (rows as List).length;
    } catch (e) {
      debugPrint('KeyManagerService: comptage serveur des prékeys impossible: $e');
      return null;
    }
  }

  /// Recharge les One-Time Pre-Keys
  Future<void> refillOneTimePreKeys(String userId) async {
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId != null) {
      await _publishOneTimePreKeysToSupabase(userId, deviceId);
    }
    debugPrint('KeyManagerService: Refilled one-time pre-keys');
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Vérifie si l'utilisateur a des clés E2EE initialisées
  Future<bool> hasKeys(String userId) async {
    return _storage.hasE2EEKeys(userId);
  }

  /// Récupère les informations de l'appareil actuel
  Future<E2EEDeviceInfo?> getCurrentDeviceInfo(String userId) async {
    final deviceId = await _storage.getDeviceId(userId);
    final identityKeyPair = await _storage.getIdentityKeyPair(userId);

    if (deviceId == null || identityKeyPair == null) return null;

    return E2EEDeviceInfo(
      deviceId: deviceId,
      deviceName: 'This Device', // À personnaliser
      platform: defaultTargetPlatform.name,
      identityKeyPublic: identityKeyPair.publicKeyBase64,
      createdAt: DateTime.now(), // À récupérer du storage
      lastActive: DateTime.now(),
    );
  }

  /// Supprime toutes les clés et données E2EE
  Future<void> clearAllKeys(String userId) async {
    // Supprimer de Supabase
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId != null) {
      await _supabase
          .from('e2ee_devices')
          .delete()
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      await _supabase.rpc('e2ee_remove_active_device', params: {
        'p_user_id': userId,
        'p_device_id': deviceId,
      },);
    }

    // Supprimer du storage local
    await _storage.clearAllData(userId);

    debugPrint('KeyManagerService: Cleared all keys for $userId');
  }
}
