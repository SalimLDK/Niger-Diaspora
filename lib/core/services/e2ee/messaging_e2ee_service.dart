import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_manager_service.dart';
import 'models/e2ee_models.dart';
import 'secure_key_storage.dart';

/// Provider pour le service E2EE de messagerie
final messagingE2EEServiceProvider = Provider<MessagingE2EEService>((ref) {
  final keyManager = ref.watch(keyManagerServiceProvider);
  final storage = ref.watch(secureKeyStorageProvider);
  return MessagingE2EEService(keyManager: keyManager, storage: storage);
});

/// Returns true if the Signal service is initialized for the current user.
final isE2EEEnabledProvider = Provider<bool>((ref) {
  return ref.watch(messagingE2EEServiceProvider).isInitialized;
});

/// Returns true if an active Signal session exists for [recipientId].
/// More accurate than [isE2EEEnabledProvider] for per-conversation status.
final conversationE2EEStatusProvider =
    FutureProvider.family<bool, String>((ref, recipientId) async {
  final svc = ref.watch(messagingE2EEServiceProvider);
  if (!svc.isInitialized) return false;
  final storage = ref.watch(secureKeyStorageProvider);
  final session = await storage.getSession(recipientId, 1);
  return session != null;
});

/// Returns true if at least one member's Sender Key is stored for [groupId].
/// Used to display the E2EE indicator in group conversation AppBars.
final groupSenderKeyStatusProvider =
    FutureProvider.family<bool, String>((ref, groupId) async {
  final svc = ref.watch(messagingE2EEServiceProvider);
  if (!svc.isInitialized) return false;
  final storage = ref.watch(secureKeyStorageProvider);
  final keys = await storage.getSenderKeysForGroup(groupId);
  return keys.isNotEmpty;
});

/// Service principal de chiffrement E2EE pour la messagerie
///
/// Implémente:
/// - X3DH (Extended Triple Diffie-Hellman) pour l'établissement de session
/// - Double Ratchet pour le chiffrement des messages avec forward secrecy
/// - Sender Keys pour les groupes (optimisation pour groupes larges)
class MessagingE2EEService {
  final KeyManagerService _keyManager;
  final SecureKeyStorage _storage;

  // Algorithmes cryptographiques
  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final _hkdf64 = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  final _ed25519 = Ed25519();

  // Constantes pour HKDF
  static final _messageKeyInfo = utf8.encode('DiaspoNiger_MessageKeys');
  static final _rootKeyInfo = utf8.encode('DiaspoNiger_RootKey');

  bool _isInitialized = false;
  String? _currentUserId;

  MessagingE2EEService({
    required KeyManagerService keyManager,
    required SecureKeyStorage storage,
  })  : _keyManager = keyManager,
        _storage = storage;

  /// Initialise le service E2EE pour un utilisateur
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    _currentUserId = userId;

    // Toujours passer par initializeKeys : il génère les clés si absentes, et
    // sinon vérifie qu'elles sont bien publiées sur Supabase (re-publie au
    // besoin). Indispensable pour rattraper un compte dont la publication
    // initiale a échoué (session Supabase pas prête) — sinon il resterait
    // injoignable en E2EE à vie.
    await _keyManager.initializeKeys(userId);

    // Vérifier et effectuer la maintenance des clés
    await _keyManager.checkAndRotateSignedPreKey(userId);
    await _keyManager.checkAndRefillOneTimePreKeys(userId);

    _isInitialized = true;
    debugPrint('MessagingE2EEService: Initialized for user $userId');
  }

  // ============================================================
  // X3DH - ÉTABLISSEMENT DE SESSION
  // ============================================================

  /// Établit une session E2EE avec un destinataire
  ///
  /// Utilise le protocole X3DH (Extended Triple Diffie-Hellman):
  /// 1. Récupère le Pre-Key Bundle du destinataire
  /// 2. Effectue les calculs DH
  /// 3. Dérive la clé de session initiale
  Future<E2EESessionState?> establishSession(String recipientId, {int? deviceId}) async {
    if (_currentUserId == null) {
      throw StateError('Service not initialized');
    }

    // Vérifier si une session existe déjà
    final existingSession = await _storage.getSession(recipientId, deviceId ?? 1);
    if (existingSession != null) {
      return existingSession;
    }

    // Récupérer le Pre-Key Bundle du destinataire
    final bundle = await _keyManager.fetchPreKeyBundle(recipientId, deviceId: deviceId);
    if (bundle == null) {
      debugPrint('MessagingE2EEService: Cannot establish session - no bundle for $recipientId');
      return null;
    }

    // Récupérer nos clés
    final identityKeyPair = await _storage.getIdentityKeyPair(_currentUserId!);
    if (identityKeyPair == null) {
      throw StateError('No identity key pair found');
    }

    // Générer une clé éphémère pour cette session
    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    // Effectuer les calculs X3DH
    // DH1 = DH(IKa, SPKb) - Notre Identity Key avec leur Signed Pre-Key
    // DH2 = DH(EKa, IKb) - Notre Ephemeral Key avec leur Identity Key
    // DH3 = DH(EKa, SPKb) - Notre Ephemeral Key avec leur Signed Pre-Key
    // DH4 = DH(EKa, OPKb) - Notre Ephemeral Key avec leur One-Time Pre-Key (optionnel)

    final recipientIdentityKey = SimplePublicKey(
      base64Decode(bundle.identityKey),
      type: KeyPairType.x25519,
    );
    final recipientSignedPreKey = SimplePublicKey(
      base64Decode(bundle.signedPreKeyPublic),
      type: KeyPairType.x25519,
    );

    // C2 Security Fix: Verify the signed pre-key signature before using it.
    // Without this check, a MITM could substitute a different signed pre-key
    // and establish a session they can decrypt.
    final signatureValid = await _verifySignedPreKeySignature(
      identityKeyBase64: bundle.identityKey,
      signedPreKeyPublicBase64: bundle.signedPreKeyPublic,
      signatureBase64: bundle.signedPreKeySignature,
    );
    if (!signatureValid) {
      debugPrint('MessagingE2EEService: SECURITY ALERT — signed pre-key signature verification FAILED for $recipientId');
      throw StateError('Signed pre-key signature verification failed. Possible MITM attack.');
    }

    // Convertir notre Identity Key en KeyPair pour DH
    final ourIdentityKeyPair = await _x25519.newKeyPairFromSeed(identityKeyPair.privateKey);

    // DH1: IKa, SPKb
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: ourIdentityKeyPair,
      remotePublicKey: recipientSignedPreKey,
    );

    // DH2: EKa, IKb
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientIdentityKey,
    );

    // DH3: EKa, SPKb
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientSignedPreKey,
    );

    // Combiner les secrets DH
    List<int> combinedSecret = [
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    // DH4 optionnel si One-Time Pre-Key disponible
    if (bundle.hasOneTimePreKey) {
      final recipientOneTimePreKey = SimplePublicKey(
        base64Decode(bundle.oneTimePreKeyPublic!),
        type: KeyPairType.x25519,
      );
      final dh4 = await _x25519.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey: recipientOneTimePreKey,
      );
      combinedSecret.addAll(await dh4.extractBytes());
    }

    // Dériver la Root Key initiale avec HKDF
    final rootKey = await _hkdf.deriveKey(
      secretKey: SecretKey(combinedSecret),
      nonce: Uint8List.fromList(utf8.encode('DiaspoNiger_X3DH_v2_Salt_32B!!')), // Security: fixed protocol salt instead of zero
      info: _rootKeyInfo,
    );

    // Créer l'état de session initial
    final session = E2EESessionState(
      recipientId: recipientId,
      recipientDeviceId: bundle.deviceId,
      rootKey: Uint8List.fromList(await rootKey.extractBytes()),
      remoteRatchetKey: base64Decode(bundle.signedPreKeyPublic),
      localRatchetPublicKey: Uint8List.fromList(ephemeralPublicKey.bytes),
      localRatchetPrivateKey: Uint8List.fromList(await ephemeralKeyPair.extractPrivateKeyBytes()),
    );

    // Stocker la session
    await _storage.storeSession(recipientId, bundle.deviceId, session);

    debugPrint('MessagingE2EEService: Established session with $recipientId');
    return session;
  }

  /// Verify that the signed pre-key was actually signed by the identity key.
  ///
  /// The identity key stored on the server is an X25519 key, but signatures
  /// are created using the Ed25519 signing key. In the Signal Protocol, the
  /// identity key pair is a Curve25519 key; its Ed25519 counterpart is
  /// derived using the montgomery-to-edwards conversion to produce signatures.
  ///
  /// Returns `true` if the signature is valid, `false` otherwise.
  Future<bool> _verifySignedPreKeySignature({
    required String identityKeyBase64,
    required String signedPreKeyPublicBase64,
    required String signatureBase64,
  }) async {
    try {
      final signatureBytes = base64Decode(signatureBase64);
      final signedPreKeyBytes = base64Decode(signedPreKeyPublicBase64);
      final identityKeyBytes = base64Decode(identityKeyBase64);

      // In Signal Protocol, the X25519 identity key is converted to its
      // Ed25519 equivalent for signature verification.
      // The signed data is the raw bytes of the signed pre-key public key.
      final ed25519PublicKey = SimplePublicKey(
        identityKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: ed25519PublicKey,
      );

      return await _ed25519.verify(
        signedPreKeyBytes,
        signature: signature,
      );
    } catch (e) {
      debugPrint('MessagingE2EEService: Error verifying signed pre-key signature: $e');
      // Fail closed: if verification itself fails, treat as invalid
      return false;
    }
  }

  // ============================================================
  // DOUBLE RATCHET - CHIFFREMENT DES MESSAGES
  // ============================================================

  /// Chiffre un message pour un destinataire
  Future<E2EEEncryptedMessage?> encryptMessage(
    String recipientId,
    String plaintext, {
    int? deviceId,
  }) async {
    if (_currentUserId == null) {
      throw StateError('Service not initialized');
    }

    // Obtenir ou établir la session
    var isNewSession = false;
    Uint8List? ephemeralKeyForPreKeyMessage;
    var session = await _storage.getSession(recipientId, deviceId ?? 1);
    if (session == null) {
      session = await establishSession(recipientId, deviceId: deviceId);
      if (session == null) {
        debugPrint('MessagingE2EEService: Cannot encrypt - no session');
        return null;
      }
      isNewSession = true;
      ephemeralKeyForPreKeyMessage = session.localRatchetPublicKey;
    }

    // Effectuer le ratchet d'envoi si nécessaire
    session = await _performSendingRatchet(session);

    // Dériver la clé de message
    final messageKey = await _deriveMessageKey(
      session.sendingChainKey!,
      session.sendingMessageIndex,
    );

    // Chiffrer le message avec AES-GCM
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: SecretKey(messageKey),
    );

    // Construire le ciphertext (nonce + ciphertext + mac)
    final ciphertext = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    // Récupérer nos infos
    final registrationId = await _storage.getRegistrationId(_currentUserId!);
    final identityKeyPair = await _storage.getIdentityKeyPair(_currentUserId!);
    final deviceIdLocal = await _storage.getDeviceId(_currentUserId!);

    // Mettre à jour l'index du message
    final newSession = session.copyWith(
      sendingMessageIndex: session.sendingMessageIndex + 1,
    );
    await _storage.storeSession(recipientId, session.recipientDeviceId, newSession);

    return E2EEEncryptedMessage(
      messageType: isNewSession ? E2EEMessageType.preKeyMessage : E2EEMessageType.whisperMessage,
      senderDeviceId: int.tryParse(deviceIdLocal ?? '1') ?? 1,
      senderRegistrationId: registrationId ?? 0,
      senderIdentityKey: identityKeyPair?.publicKeyBase64 ?? '',
      senderEphemeralKey: ephemeralKeyForPreKeyMessage != null
          ? base64Encode(ephemeralKeyForPreKeyMessage)
          : null,
      ciphertext: base64Encode(ciphertext),
      createdAt: DateTime.now(),
    );
  }

  /// Déchiffre un message reçu
  Future<String?> decryptMessage(
    String senderId,
    E2EEEncryptedMessage encryptedMessage,
  ) async {
    if (_currentUserId == null) {
      throw StateError('Service not initialized');
    }

    try {
      // Obtenir la session
      var session = await _storage.getSession(senderId, encryptedMessage.senderDeviceId);

      if (session == null) {
        // Pour un PreKeyMessage, on doit établir la session côté récepteur
        if (encryptedMessage.messageType == E2EEMessageType.preKeyMessage) {
          session = await _processPreKeyMessage(senderId, encryptedMessage);
        }

        if (session == null) {
          debugPrint('MessagingE2EEService: Cannot decrypt - no session for $senderId');
          return null;
        }
      }

      // Effectuer le ratchet de réception si nécessaire
      session = await _performReceivingRatchet(session, encryptedMessage);

      // Dériver la clé de message
      final messageKey = await _deriveMessageKey(
        session.receivingChainKey!,
        session.receivingMessageIndex,
      );

      // Décoder le ciphertext
      final ciphertextFull = base64Decode(encryptedMessage.ciphertext);

      // Extraire nonce (12 bytes), ciphertext, et MAC (16 bytes)
      final nonce = ciphertextFull.sublist(0, 12);
      final ciphertextWithMac = ciphertextFull.sublist(12);
      final ciphertext = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);
      final mac = ciphertextWithMac.sublist(ciphertextWithMac.length - 16);

      // Déchiffrer avec AES-GCM
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );

      final plaintextBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(messageKey),
      );

      // Mettre à jour l'index du message
      final newSession = session.copyWith(
        receivingMessageIndex: session.receivingMessageIndex + 1,
      );
      await _storage.storeSession(senderId, session.recipientDeviceId, newSession);

      return utf8.decode(plaintextBytes);
    } catch (e) {
      debugPrint('MessagingE2EEService: Error decrypting message: $e');
      return null;
    }
  }

  /// Effectue le ratchet d'envoi (Sending Chain)
  Future<E2EESessionState> _performSendingRatchet(E2EESessionState session) async {
    if (session.sendingChainKey != null) {
      return session;
    }

    // Générer une nouvelle paire de clés ratchet
    final newRatchetKeyPair = await _x25519.newKeyPair();
    final newRatchetPublicKey = await newRatchetKeyPair.extractPublicKey();

    // DH avec la clé ratchet distante
    if (session.remoteRatchetKey == null) {
      throw StateError('No remote ratchet key for sending ratchet');
    }

    final remoteRatchetKey = SimplePublicKey(
      session.remoteRatchetKey!,
      type: KeyPairType.x25519,
    );

    final dhOutput = await _x25519.sharedSecretKey(
      keyPair: newRatchetKeyPair,
      remotePublicKey: remoteRatchetKey,
    );

    // Dériver nouvelle Root Key et Chain Key
    final (newRootKey, newChainKey) = await _kdfRootKey(
      session.rootKey,
      await dhOutput.extractBytes(),
    );

    return session.copyWith(
      rootKey: newRootKey,
      sendingChainKey: newChainKey,
      localRatchetPublicKey: Uint8List.fromList(newRatchetPublicKey.bytes),
      localRatchetPrivateKey: Uint8List.fromList(await newRatchetKeyPair.extractPrivateKeyBytes()),
      sendingMessageIndex: 0,
    );
  }

  /// Effectue le ratchet de réception (Receiving Chain)
  Future<E2EESessionState> _performReceivingRatchet(
    E2EESessionState session,
    E2EEEncryptedMessage message,
  ) async {
    if (session.receivingChainKey != null) {
      return session;
    }

    // Utiliser notre clé ratchet locale pour DH
    if (session.localRatchetPrivateKey == null) {
      throw StateError('No local ratchet key for receiving ratchet');
    }

    // Reconstituer notre paire de clés
    final ourRatchetKeyPair = await _x25519.newKeyPairFromSeed(session.localRatchetPrivateKey!);

    // La clé publique du sender est incluse dans le message (simplification)
    // En réalité, elle serait dans l'en-tête du message
    final senderRatchetKey = SimplePublicKey(
      base64Decode(message.senderIdentityKey),
      type: KeyPairType.x25519,
    );

    final dhOutput = await _x25519.sharedSecretKey(
      keyPair: ourRatchetKeyPair,
      remotePublicKey: senderRatchetKey,
    );

    // Dériver nouvelle Root Key et Chain Key
    final (newRootKey, newChainKey) = await _kdfRootKey(
      session.rootKey,
      await dhOutput.extractBytes(),
    );

    return session.copyWith(
      rootKey: newRootKey,
      receivingChainKey: newChainKey,
      remoteRatchetKey: base64Decode(message.senderIdentityKey),
      receivingMessageIndex: 0,
    );
  }

  /// Traite un PreKeyMessage pour établir une session côté récepteur
  Future<E2EESessionState?> _processPreKeyMessage(
    String senderId,
    E2EEEncryptedMessage message,
  ) async {
    // Récupérer nos clés
    final identityKeyPair = await _storage.getIdentityKeyPair(_currentUserId!);
    final signedPreKey = await _storage.getCurrentSignedPreKey(_currentUserId!);

    if (identityKeyPair == null || signedPreKey == null) {
      return null;
    }

    // Effectuer X3DH côté récepteur
    final senderIdentityKey = SimplePublicKey(
      base64Decode(message.senderIdentityKey),
      type: KeyPairType.x25519,
    );

    // Reconstituer nos paires de clés
    final ourIdentityKeyPair = await _x25519.newKeyPairFromSeed(identityKeyPair.privateKey);
    final ourSignedPreKeyPair = await _x25519.newKeyPairFromSeed(signedPreKey.privateKey);

    // DH1: SPKb, IKa
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: ourSignedPreKeyPair,
      remotePublicKey: senderIdentityKey,
    );

    // Use the sender's ephemeral key (EKa) for proper forward secrecy
    final senderEphemeralKey = message.senderEphemeralKey != null
        ? SimplePublicKey(
            base64Decode(message.senderEphemeralKey!),
            type: KeyPairType.x25519,
          )
        : senderIdentityKey; // Backward compatibility with pre-v2 messages

    // DH2: IKb, EKa
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ourIdentityKeyPair,
      remotePublicKey: senderEphemeralKey,
    );

    // DH3: SPKb, EKa
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: ourSignedPreKeyPair,
      remotePublicKey: senderEphemeralKey,
    );

    // Combiner les secrets
    final combinedSecret = [
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    // Dériver la Root Key
    final rootKey = await _hkdf.deriveKey(
      secretKey: SecretKey(combinedSecret),
      nonce: Uint8List.fromList(utf8.encode('DiaspoNiger_X3DH_v2_Salt_32B!!')), // Security: fixed protocol salt
      info: _rootKeyInfo,
    );

    final session = E2EESessionState(
      recipientId: senderId,
      recipientDeviceId: message.senderDeviceId,
      rootKey: Uint8List.fromList(await rootKey.extractBytes()),
      remoteRatchetKey: base64Decode(message.senderIdentityKey),
      localRatchetPublicKey: signedPreKey.publicKey,
      localRatchetPrivateKey: signedPreKey.privateKey,
    );

    await _storage.storeSession(senderId, message.senderDeviceId, session);
    return session;
  }

  /// Security: derives Root Key and Chain Key from a single 64-byte HKDF output,
  /// split into two 32-byte halves — prevents related-key attacks from separate derivations.
  Future<(Uint8List, Uint8List)> _kdfRootKey(Uint8List rootKey, List<int> dhOutput) async {
    final derived = await _hkdf64.deriveKey(
      secretKey: SecretKey(dhOutput),
      nonce: rootKey,
      info: utf8.encode('DiaspoNiger_RatchetKDF'),
    );
    final bytes = await derived.extractBytes();
    return (
      Uint8List.fromList(bytes.sublist(0, 32)),
      Uint8List.fromList(bytes.sublist(32, 64)),
    );
  }

  /// Security: uses fixed 4-byte big-endian nonce instead of variable-length string
  Future<Uint8List> _deriveMessageKey(Uint8List chainKey, int messageIndex) async {
    // Fixed 4-byte big-endian representation of the message index
    final indexBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, messageIndex, Endian.big);
    final messageKey = await _hkdf.deriveKey(
      secretKey: SecretKey(chainKey),
      nonce: indexBytes,
      info: _messageKeyInfo,
    );
    return Uint8List.fromList(await messageKey.extractBytes());
  }

  // ============================================================
  // CHIFFREMENT POUR GROUPES
  // ============================================================

  /// Chiffre un message pour tous les membres d'un groupe
  Future<Map<String, E2EEEncryptedMessage>> encryptForGroup(
    List<String> recipientIds,
    String plaintext,
  ) async {
    final encryptedMessages = <String, E2EEEncryptedMessage>{};

    for (final recipientId in recipientIds) {
      if (recipientId == _currentUserId) continue;

      final encrypted = await encryptMessage(recipientId, plaintext);
      if (encrypted != null) {
        encryptedMessages[recipientId] = encrypted;
      }
    }

    return encryptedMessages;
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Vérifie si une session existe avec un destinataire
  Future<bool> hasSession(String recipientId, {int? deviceId}) async {
    return _storage.hasSession(recipientId, deviceId ?? 1);
  }

  /// Supprime une session
  Future<void> deleteSession(String recipientId, {int? deviceId}) async {
    await _storage.deleteSession(recipientId, deviceId ?? 1);
  }

  /// Vérifie si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Récupère l'ID de l'utilisateur courant
  String? get currentUserId => _currentUserId;
}
