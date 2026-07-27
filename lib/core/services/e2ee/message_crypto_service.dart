import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../encryption_service.dart';
import 'key_manager_service.dart';
import 'messaging_e2ee_service.dart';
import 'models/e2ee_models.dart';
import 'sender_key_service.dart';

final messageCryptoServiceProvider = Provider<MessageCryptoService>((ref) {
  return MessageCryptoService(
    aes: ref.watch(encryptionServiceProvider),
    e2ee: ref.watch(messagingE2EEServiceProvider),
    keyManager: ref.watch(keyManagerServiceProvider),
    senderKeys: ref.watch(senderKeyServiceProvider),
  );
});

// ── Wire-format constants ────────────────────────────────────────────────────
//
// 1:1  Signal  → e2eePayloads: {devId: payload},  encryptionLevel: 'e2ee'
// Group Signal → senderKeyPayload: <base64>,       encryptionLevel: 'e2ee'
// AES fallback → content: 'gcm:…',                encryptionLevel: 'aes'
//
// Legacy backward-compat keys kept for decrypt path:
//   e2eePayload  (single-device 1:1, old format)
// ────────────────────────────────────────────────────────────────────────────
const _payloadsKey       = 'e2eePayloads';     // map<deviceId, payload>
const _legacyKey         = 'e2eePayload';       // legacy single-device
const _senderKeyPayload  = 'senderKeyPayload';  // group Sender Key ciphertext
const _levelKey          = 'encryptionLevel';
const _e2eePlaceholder   = '[E2EE]';

/// Returned by all encrypt methods so callers know the actual security level.
class CryptoResult {
  final Map<String, dynamic> fields;
  final String encryptionLevel; // 'aes' | 'e2ee'
  const CryptoResult(this.fields, this.encryptionLevel);
}

/// Bridge between AES-256-GCM (global key, fallback) and Signal Protocol
/// (per-session 1:1, Sender Key for groups).
class MessageCryptoService {
  final EncryptionService _aes;
  final MessagingE2EEService _e2ee;
  final KeyManagerService _keyManager;
  final SenderKeyService _senderKeys;

  const MessageCryptoService({
    required EncryptionService aes,
    required MessagingE2EEService e2ee,
    required KeyManagerService keyManager,
    required SenderKeyService senderKeys,
  })  : _aes = aes,
        _e2ee = e2ee,
        _keyManager = keyManager,
        _senderKeys = senderKeys;

  // ── 1:1 Encryption ─────────────────────────────────────────────────────────

  /// Encrypt for all active devices of [recipientId] using Signal Protocol.
  /// Falls back to AES-GCM when no pre-keys are available.
  Future<CryptoResult> encrypt1to1({
    required String plaintext,
    required String recipientId,
  }) async {
    if (_e2ee.isInitialized) {
      try {
        final deviceIds = await _keyManager.getActiveDevices(recipientId);
        if (deviceIds.isNotEmpty) {
          final payloads = <String, String>{};
          for (final deviceId in deviceIds) {
            try {
              final enc = await _e2ee.encryptMessage(
                recipientId,
                plaintext,
                deviceId: int.tryParse(deviceId),
              );
              if (enc != null) payloads[deviceId] = jsonEncode(enc.toJson());
            } catch (e) {
              debugPrint('MessageCryptoService: Signal failed for device $deviceId: $e');
            }
          }
          if (payloads.isNotEmpty) {
            return CryptoResult(
              {'content': _e2eePlaceholder, _payloadsKey: payloads, _levelKey: 'e2ee'},
              'e2ee',
            );
          }
        }
        debugPrint('MessageCryptoService: No Signal sessions for $recipientId — AES fallback');
      } catch (e) {
        debugPrint('MessageCryptoService: Signal error, AES fallback: $e');
      }
    }
    return CryptoResult(
      {'content': _aes.encryptText(plaintext), _levelKey: 'aes'},
      'aes',
    );
  }

  /// Chiffre une note « Mes notes » (self-chat).
  ///
  /// Il n'y a pas de destinataire : le Double Ratchet de Signal suppose deux
  /// parties, on ne peut donc pas établir de session avec soi-même. La note est
  /// chiffrée **au repos** avec la clé AES globale — le même repli que celui
  /// déjà utilisé pour les aperçus, la localisation et les médias.
  CryptoResult encryptSelfNote(String plaintext) => CryptoResult(
        {'content': _aes.encryptText(plaintext), _levelKey: 'aes'},
        'aes',
      );

  // ── Group Encryption (Sender Keys) ─────────────────────────────────────────

  /// Encrypt for a group using Signal Sender Keys.
  /// Falls back to AES-GCM if E2EE is not initialized or Sender Key unavailable.
  Future<CryptoResult> encryptGroup(String plaintext, {String? groupId}) async {
    if (_e2ee.isInitialized && groupId != null) {
      try {
        final skMsg = await _senderKeys.encryptWithSenderKey(groupId, plaintext);
        if (skMsg != null) {
          return CryptoResult(
            {
              'content': _e2eePlaceholder,
              _senderKeyPayload: skMsg.toFirebaseString(),
              _levelKey: 'e2ee',
            },
            'e2ee',
          );
        }
      } catch (e) {
        debugPrint('MessageCryptoService: Sender Key encryption failed: $e');
      }
    }
    // AES-GCM fallback for groups without established Sender Keys
    return CryptoResult(
      {'content': _aes.encryptText(plaintext), _levelKey: 'aes'},
      'aes',
    );
  }

  // ── Decryption ─────────────────────────────────────────────────────────────

  /// Decrypt a RTDB message payload, handling all wire formats:
  ///   1. Group Sender Key (senderKeyPayload)
  ///   2. Multi-device 1:1  (e2eePayloads)
  ///   3. Legacy single-device 1:1 (e2eePayload)
  ///   4. AES-GCM fallback (content)
  Future<String> decrypt({
    required Map<String, dynamic> payload,
    required String senderId,
    String? currentDeviceId,
  }) async {
    // ── Format 1: Group Sender Key ──────────────────────────────────────────
    final skRaw = payload[_senderKeyPayload];
    if (skRaw is String && skRaw.isNotEmpty) {
      if (_e2ee.isInitialized) {
        try {
          final skMsg = SenderKeyEncryptedMessage.fromFirebaseString(skRaw);
          final plain = await _senderKeys.decryptWithSenderKey(
            skMsg.groupId,
            skMsg.senderId,
            skMsg.senderDeviceId,
            skMsg,
          );
          if (plain != null) return plain;
        } catch (e) {
          debugPrint('MessageCryptoService: Sender Key decrypt failed: $e');
        }
      }
      return '[🔐 E2EE — session requise]';
    }

    // ── Format 2: Multi-device 1:1 (e2eePayloads) ──────────────────────────
    final payloadsRaw = payload[_payloadsKey];
    if (payloadsRaw is Map) {
      if (_e2ee.isInitialized) {
        final payloads = Map<String, String>.from(
          payloadsRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        final candidates = [
          if (currentDeviceId != null && payloads.containsKey(currentDeviceId))
            currentDeviceId,
          ...payloads.keys.where((k) => k != currentDeviceId),
        ];
        for (final deviceId in candidates) {
          try {
            final enc = E2EEEncryptedMessage.fromJson(
              jsonDecode(payloads[deviceId]!) as Map<String, dynamic>,
            );
            final plain = await _e2ee.decryptMessage(senderId, enc);
            if (plain != null) return plain;
          } catch (e) {
            debugPrint('MessageCryptoService: 1:1 decrypt failed for device $deviceId: $e');
          }
        }
      }
      return '[🔐 E2EE — session requise]';
    }

    // ── Format 3: Legacy single-device 1:1 ─────────────────────────────────
    final legacyRaw = payload[_legacyKey];
    if (legacyRaw is String && legacyRaw.isNotEmpty) {
      if (_e2ee.isInitialized) {
        try {
          final enc = E2EEEncryptedMessage.fromJson(
            jsonDecode(legacyRaw) as Map<String, dynamic>,
          );
          final plain = await _e2ee.decryptMessage(senderId, enc);
          if (plain != null) return plain;
        } catch (e) {
          debugPrint('MessageCryptoService: legacy decrypt failed: $e');
        }
      }
      return '[🔐 E2EE — session requise]';
    }

    // ── Format 4: AES-GCM ──────────────────────────────────────────────────
    return _aes.decryptText(payload['content'] as String? ?? '');
  }

  String decryptLegacy(String encryptedContent) => _aes.decryptText(encryptedContent);

  // ── Session / key guards ────────────────────────────────────────────────────

  /// True when the Signal Protocol backend is ready for the current user.
  bool get isE2EEInitialized => _e2ee.isInitialized;

  /// True when a local Signal session already exists for [recipientId]
  /// (i.e. X3DH was completed and the session is stored on-device).
  Future<bool> hasSessionFor(String recipientId) =>
      _e2ee.hasSession(recipientId);

  /// True when [recipientId] has published pre-keys on Firebase,
  /// meaning they have opened the app and set up E2EE at least once.
  Future<bool> recipientHasKeys(String recipientId) async {
    final devices = await _keyManager.getActiveDevices(recipientId);
    return devices.isNotEmpty;
  }

  /// Pre-establish Signal sessions with [recipientIds] (fire-and-forget safe).
  Future<void> preEstablishSessions(List<String> recipientIds) async {
    if (!_e2ee.isInitialized) return;
    for (final uid in recipientIds) {
      try {
        await _e2ee.establishSession(uid);
      } catch (e) {
        debugPrint('MessageCryptoService: preEstablishSessions failed for $uid: $e');
      }
    }
  }

  /// Distribute this user's Sender Key to all group members and fetch any
  /// pending distributions from other members.
  /// Call when opening a group conversation (fire-and-forget).
  Future<void> distributeGroupSenderKey({
    required String groupId,
    required List<String> memberIds,
  }) async {
    if (!_e2ee.isInitialized) return;
    try {
      // First fetch distributions we may have missed while offline
      await _senderKeys.fetchPendingDistributions(groupId);
      // Then distribute our own Sender Key to all members
      await _senderKeys.distributeSenderKeyToGroup(groupId, memberIds);
    } catch (e) {
      debugPrint('MessageCryptoService: Sender Key setup failed: $e');
    }
  }

  /// Process an incoming Sender Key distribution message embedded in a Signal
  /// 1:1 message payload.  Call from the incoming message stream handler.
  Future<void> processSenderKeyDistribution({
    required String senderId,
    required int senderDeviceId,
    required Map<String, dynamic> distribution,
  }) async {
    try {
      await _senderKeys.processDistributionMessage(senderId, senderDeviceId, distribution);
    } catch (e) {
      debugPrint('MessageCryptoService: processDistributionMessage failed: $e');
    }
  }
}
