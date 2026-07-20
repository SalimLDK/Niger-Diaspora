import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

/// Service for managing End-to-End Encryption (E2EE) for calls
///
/// Supports both:
/// - 1:1 calls using flutter_webrtc FrameCryptor
/// - Group calls (mesh) with shared symmetric key
/// - LiveKit E2EE (handled by livekit_client)
class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  static E2EEService get instance => _instance;

  // AES-GCM for symmetric encryption
  final _algorithm = AesGcm.with256bits();

  // Key providers for WebRTC FrameCryptor
  final Map<String, FrameCryptorFactory> _frameCryptorFactories = {};
  final Map<String, FrameCryptor> _senderCryptors = {};
  final Map<String, FrameCryptor> _receiverCryptors = {};

  // Current encryption key for the call
  SecretKey? _currentKey;
  String? _currentKeyId;

  /// Generate a new encryption key for a call
  Future<E2EEKeyData> generateCallKey() async {
    // Generate a random 256-bit key
    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();

    // Generate a unique key ID
    final keyId = const Uuid().v4();

    _currentKey = key;
    _currentKeyId = keyId;

    return E2EEKeyData(
      keyId: keyId,
      keyBase64: base64Encode(keyBytes),
    );
  }

  /// Import an encryption key from Base64
  Future<void> importKey(String keyBase64, String keyId) async {
    final keyBytes = base64Decode(keyBase64);
    _currentKey = SecretKey(keyBytes);
    _currentKeyId = keyId;
    debugPrint('E2EEService: Key imported with ID: $keyId');
  }

  /// Enable E2EE for a WebRTC sender (outgoing media)
  Future<void> enableE2EEForSender({
    required String participantId,
    required RTCRtpSender sender,
    required RTCPeerConnection peerConnection,
  }) async {
    if (_currentKey == null) {
      debugPrint('E2EEService: No key available for E2EE');
      return;
    }

    try {
      final keyBytes = await _currentKey!.extractBytes();

      // Create key provider with current key
      final keyProvider = await frameCryptorFactory.createDefaultKeyProvider(
        KeyProviderOptions(
          sharedKey: true,
          ratchetSalt: Uint8List.fromList(utf8.encode('diasponiger-e2ee')),
          ratchetWindowSize: 16,
          failureTolerance: 5,
        ),
      );

      await keyProvider.setSharedKey(
        key: Uint8List.fromList(keyBytes),
        index: 0,
      );

      // Create FrameCryptor for sender
      final cryptor = await frameCryptorFactory.createFrameCryptorForRtpSender(
        participantId: participantId,
        sender: sender,
        algorithm: Algorithm.kAesGcm,
        keyProvider: keyProvider,
      );

      await cryptor.setEnabled(true);
      await cryptor.setKeyIndex(0);

      _senderCryptors[participantId] = cryptor;
      debugPrint('E2EEService: E2EE enabled for sender $participantId');
    } catch (e) {
      debugPrint('E2EEService: Error enabling E2EE for sender: $e');
    }
  }

  /// Enable E2EE for a WebRTC receiver (incoming media)
  Future<void> enableE2EEForReceiver({
    required String participantId,
    required RTCRtpReceiver receiver,
    required RTCPeerConnection peerConnection,
  }) async {
    if (_currentKey == null) {
      debugPrint('E2EEService: No key available for E2EE');
      return;
    }

    try {
      final keyBytes = await _currentKey!.extractBytes();

      // Create key provider with current key
      final keyProvider = await frameCryptorFactory.createDefaultKeyProvider(
        KeyProviderOptions(
          sharedKey: true,
          ratchetSalt: Uint8List.fromList(utf8.encode('diasponiger-e2ee')),
          ratchetWindowSize: 16,
          failureTolerance: 5,
        ),
      );

      await keyProvider.setSharedKey(
        key: Uint8List.fromList(keyBytes),
        index: 0,
      );

      // Create FrameCryptor for receiver
      final cryptor = await frameCryptorFactory.createFrameCryptorForRtpReceiver(
        participantId: participantId,
        receiver: receiver,
        algorithm: Algorithm.kAesGcm,
        keyProvider: keyProvider,
      );

      await cryptor.setEnabled(true);
      await cryptor.setKeyIndex(0);

      _receiverCryptors[participantId] = cryptor;
      debugPrint('E2EEService: E2EE enabled for receiver $participantId');
    } catch (e) {
      debugPrint('E2EEService: Error enabling E2EE for receiver: $e');
    }
  }

  /// Encrypt data (for signaling/metadata)
  Future<String> encryptData(String plaintext) async {
    if (_currentKey == null) {
      throw Exception('No encryption key available');
    }

    final secretBox = await _algorithm.encryptString(
      plaintext,
      secretKey: _currentKey!,
    );

    // Combine nonce + ciphertext + mac for transmission
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64Encode(combined);
  }

  /// Decrypt data (for signaling/metadata)
  Future<String> decryptData(String encryptedBase64) async {
    if (_currentKey == null) {
      throw Exception('No encryption key available');
    }

    final combined = base64Decode(encryptedBase64);

    // AES-GCM: 12 bytes nonce, rest is ciphertext + 16 bytes MAC
    final nonce = combined.sublist(0, 12);
    final cipherTextWithMac = combined.sublist(12);
    final cipherText = cipherTextWithMac.sublist(
      0,
      cipherTextWithMac.length - 16,
    );
    final mac = cipherTextWithMac.sublist(cipherTextWithMac.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );

    return await _algorithm.decryptString(
      secretBox,
      secretKey: _currentKey!,
    );
  }

  /// Encrypt the E2EE key using a derived key (for sharing in Firebase)
  ///
  /// Uses a combination of call ID and participant IDs to derive a key
  /// that only call participants can reconstruct
  Future<String> encryptKeyForSharing({
    required String callId,
    required List<String> participantIds,
  }) async {
    if (_currentKey == null) {
      throw Exception('No key to share');
    }

    // Derive a wrapping key from call metadata
    final derivationInput = '$callId:${participantIds.sorted().join(':')}';
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final wrappingKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(derivationInput)),
      nonce: Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256))), // Security: random salt instead of static
    );
    final keyBytes = await _currentKey!.extractBytes();
    final secretBox = await _algorithm.encrypt(
      keyBytes,
      secretKey: wrappingKey,
    );

    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64Encode(combined);
  }

  /// Decrypt a shared E2EE key
  Future<void> decryptSharedKey({
    required String encryptedKey,
    required String keyId,
    required String callId,
    required List<String> participantIds,
  }) async {
    // Derive the same wrapping key
    final derivationInput = '$callId:${participantIds.sorted().join(':')}';
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final wrappingKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(derivationInput)),
      nonce: utf8.encode('diasponiger-key-wrap'),
    );

    // Decrypt the key
    final combined = base64Decode(encryptedKey);
    final nonce = combined.sublist(0, 12);
    final cipherTextWithMac = combined.sublist(12);
    final cipherText = cipherTextWithMac.sublist(
      0,
      cipherTextWithMac.length - 16,
    );
    final mac = cipherTextWithMac.sublist(cipherTextWithMac.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );

    final keyBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: wrappingKey,
    );

    _currentKey = SecretKey(keyBytes);
    _currentKeyId = keyId;
    debugPrint('E2EEService: Shared key decrypted with ID: $keyId');
  }

  /// Check if E2EE is currently active
  bool get isE2EEEnabled => _currentKey != null;

  /// Get current key ID (for verification UI)
  String? get currentKeyId => _currentKeyId;

  /// Generate a verification code for key verification
  /// Users can compare this to confirm they have the same key
  Future<String> generateVerificationCode() async {
    if (_currentKey == null) return '------';

    final keyBytes = await _currentKey!.extractBytes();
    // Take first 6 bytes and convert to hex pairs
    final code = keyBytes
        .take(3)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');

    return code;
  }

  /// Disable E2EE for a participant
  Future<void> disableE2EE(String participantId) async {
    try {
      final senderCryptor = _senderCryptors.remove(participantId);
      if (senderCryptor != null) {
        await senderCryptor.setEnabled(false);
        await senderCryptor.dispose();
      }

      final receiverCryptor = _receiverCryptors.remove(participantId);
      if (receiverCryptor != null) {
        await receiverCryptor.setEnabled(false);
        await receiverCryptor.dispose();
      }

      debugPrint('E2EEService: E2EE disabled for $participantId');
    } catch (e) {
      debugPrint('E2EEService: Error disabling E2EE: $e');
    }
  }

  /// Clean up all E2EE resources
  Future<void> dispose() async {
    for (final entry in _senderCryptors.entries) {
      try {
        await entry.value.setEnabled(false);
        await entry.value.dispose();
      } catch (_) {}
    }
    _senderCryptors.clear();

    for (final entry in _receiverCryptors.entries) {
      try {
        await entry.value.setEnabled(false);
        await entry.value.dispose();
      } catch (_) {}
    }
    _receiverCryptors.clear();

    _frameCryptorFactories.clear();
    _currentKey = null;
    _currentKeyId = null;

    debugPrint('E2EEService: Disposed');
  }
}

/// Data class for E2EE key information
class E2EEKeyData {
  final String keyId;
  final String keyBase64;

  const E2EEKeyData({
    required this.keyId,
    required this.keyBase64,
  });

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'keyBase64': keyBase64,
      };

  factory E2EEKeyData.fromJson(Map<String, dynamic> json) => E2EEKeyData(
        keyId: json['keyId'] as String,
        keyBase64: json['keyBase64'] as String,
      );
}

/// Extension for sorting strings
extension SortedList<T extends Comparable> on List<T> {
  List<T> sorted() => [...this]..sort();
}
