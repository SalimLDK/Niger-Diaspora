import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_moderation_service.dart';
import 'device_sync_service.dart';
import 'media_encryption_service.dart';
import 'messaging_e2ee_service.dart';
import 'models/e2ee_models.dart';
import 'sender_key_service.dart';

/// Provider pour le helper d'intégration E2EE
final messageE2EEHelperProvider = Provider<MessageE2EEHelper>((ref) {
  return MessageE2EEHelper(
    e2eeService: ref.watch(messagingE2EEServiceProvider),
    senderKeyService: ref.watch(senderKeyServiceProvider),
    mediaService: ref.watch(mediaEncryptionServiceProvider),
    moderationService: ref.watch(contentModerationServiceProvider),
    deviceSyncService: ref.watch(deviceSyncServiceProvider),
  );
});

/// Helper pour intégrer E2EE dans le datasource de messagerie
///
/// Ce helper gère:
/// - La détection du support E2EE (destinataire supporte-t-il E2EE?)
/// - Le chiffrement/déchiffrement des messages
/// - Le chiffrement des médias
/// - La modération côté client (avant chiffrement)
/// - La compatibilité avec l'ancien format (période de migration)
class MessageE2EEHelper {
  final MessagingE2EEService _e2eeService;
  final SenderKeyService _senderKeyService;
  final MediaEncryptionService _mediaService;
  final ContentModerationService _moderationService;
  final DeviceSyncService _deviceSyncService;

  // Cache du support E2EE par utilisateur
  final Map<String, bool> _e2eeSupportCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  MessageE2EEHelper({
    required MessagingE2EEService e2eeService,
    required SenderKeyService senderKeyService,
    required MediaEncryptionService mediaService,
    required ContentModerationService moderationService,
    required DeviceSyncService deviceSyncService,
  })  : _e2eeService = e2eeService,
        _senderKeyService = senderKeyService,
        _mediaService = mediaService,
        _moderationService = moderationService,
        _deviceSyncService = deviceSyncService;

  // ============================================================
  // VÉRIFICATION DU SUPPORT E2EE
  // ============================================================

  /// Vérifie si un utilisateur supporte E2EE
  Future<bool> recipientSupportsE2EE(String recipientId) async {
    // Vérifier le cache
    final cacheTime = _cacheTimestamps[recipientId];
    if (cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheDuration) {
      return _e2eeSupportCache[recipientId] ?? false;
    }

    // Vérifier sur Firebase
    final supports = await _deviceSyncService.recipientSupportsE2EE(recipientId);
    _e2eeSupportCache[recipientId] = supports;
    _cacheTimestamps[recipientId] = DateTime.now();

    return supports;
  }

  /// Vérifie si tous les membres d'un groupe supportent E2EE
  Future<bool> allGroupMembersSupportE2EE(List<String> memberIds) async {
    for (final memberId in memberIds) {
      if (!await recipientSupportsE2EE(memberId)) {
        return false;
      }
    }
    return true;
  }

  // ============================================================
  // CHIFFREMENT DES MESSAGES TEXTE
  // ============================================================

  /// Chiffre un message texte pour une conversation 1-1
  ///
  /// Returns: Le message chiffré E2EE ou null si E2EE non supporté
  Future<E2EEMessagePayload?> encryptTextMessage({
    required String senderId,
    required String recipientId,
    required String plaintext,
  }) async {
    // 1. Modération côté client
    final moderationResult = await _moderationService.analyzeTextContent(plaintext);
    if (!moderationResult.isAllowed) {
      throw ContentBlockedException(
        'Ce message contient du contenu non autorisé',
        issues: moderationResult.issues,
      );
    }

    // 2. Vérifier le support E2EE
    if (!await recipientSupportsE2EE(recipientId)) {
      return null; // Utiliser l'ancien chiffrement
    }

    // 3. Récupérer tous les appareils du destinataire
    final recipientDevices = await _deviceSyncService.getRecipientDevices(recipientId);
    if (recipientDevices.isEmpty) {
      return null; // Pas d'appareils E2EE
    }

    // 4. Récupérer nos autres appareils (pour self-messaging)
    final myOtherDevices = await _deviceSyncService.getMyOtherDevices(senderId);

    // 5. Chiffrer pour chaque appareil
    final encryptedMessages = <String, E2EEEncryptedMessage>{};

    // Chiffrer pour les appareils du destinataire
    for (final device in recipientDevices) {
      try {
        final encrypted = await _e2eeService.encryptMessage(
          recipientId,
          plaintext,
        );
        if (encrypted != null) {
          encryptedMessages['${device.userId}_${device.deviceId}'] = encrypted;
        }
      } catch (e) {
        debugPrint('E2EEHelper: Failed to encrypt for device ${device.deviceId}: $e');
      }
    }

    // Chiffrer pour nos autres appareils (self-messaging)
    for (final device in myOtherDevices) {
      try {
        final encrypted = await _e2eeService.encryptMessage(
          senderId, // Self
          plaintext,
        );
        if (encrypted != null) {
          encryptedMessages['${device.userId}_${device.deviceId}'] = encrypted;
        }
      } catch (e) {
        debugPrint('E2EEHelper: Failed to encrypt for own device ${device.deviceId}: $e');
      }
    }

    if (encryptedMessages.isEmpty) {
      return null;
    }

    return E2EEMessagePayload(
      encryptedMessages: encryptedMessages,
      moderationMetadata: _moderationService.generateModerationMetadata(moderationResult),
      e2eeVersion: 1,
    );
  }

  /// Chiffre un message pour un groupe avec Sender Keys
  Future<E2EEGroupMessagePayload?> encryptGroupMessage({
    required String senderId,
    required String groupId,
    required List<String> memberIds,
    required String plaintext,
  }) async {
    // 1. Modération côté client
    final moderationResult = await _moderationService.analyzeTextContent(plaintext);
    if (!moderationResult.isAllowed) {
      throw ContentBlockedException(
        'Ce message contient du contenu non autorisé',
        issues: moderationResult.issues,
      );
    }

    // 2. Vérifier que tous les membres supportent E2EE
    if (!await allGroupMembersSupportE2EE(memberIds)) {
      return null; // Fallback à l'ancien chiffrement
    }

    // 3. Chiffrer avec Sender Key
    try {
      final encryptedMessage = await _senderKeyService.encryptWithSenderKey(
        groupId,
        plaintext,
      );

      if (encryptedMessage == null) {
        return null;
      }

      return E2EEGroupMessagePayload(
        encryptedMessage: encryptedMessage,
        keyId: encryptedMessage.keyId,
        moderationMetadata: _moderationService.generateModerationMetadata(moderationResult),
        e2eeVersion: 1,
      );
    } catch (e) {
      debugPrint('E2EEHelper: Failed to encrypt group message: $e');
      return null;
    }
  }

  // ============================================================
  // DÉCHIFFREMENT DES MESSAGES
  // ============================================================

  /// Déchiffre un message E2EE reçu
  Future<String?> decryptMessage({
    required String currentUserId,
    required String senderId,
    required Map<String, dynamic> messageData,
  }) async {
    // Vérifier si c'est un message E2EE
    if (!_isE2EEMessage(messageData)) {
      return null; // C'est un message ancien format
    }

    try {
      // Récupérer notre deviceId
      final myDevices = await _deviceSyncService.getMyDevices(currentUserId);
      if (myDevices.isEmpty) return null;

      final currentDevice = await _deviceSyncService.getCurrentDevice(currentUserId);
      if (currentDevice == null) return null;

      // Trouver le message chiffré pour notre appareil
      final encryptedMessages = messageData['e2ee'] as Map<String, dynamic>?;
      if (encryptedMessages == null) return null;

      final deviceKey = '${currentUserId}_${currentDevice.deviceId}';
      final encryptedData = encryptedMessages[deviceKey] as Map<String, dynamic>?;

      if (encryptedData == null) {
        debugPrint('E2EEHelper: No encrypted message for this device');
        return null;
      }

      // Reconstruire le message chiffré
      final encryptedMessage = E2EEEncryptedMessage(
        ciphertext: encryptedData['ciphertext'] as String,
        messageType: E2EEMessageType.fromValue(
          encryptedData['messageType'] as int? ?? 2,
        ),
        senderIdentityKey: encryptedData['senderIdentityKey'] as String? ?? '',
        senderDeviceId: encryptedData['senderDeviceId'] as int? ?? 0,
        senderRegistrationId: encryptedData['senderRegistrationId'] as int? ?? 0,
        createdAt: DateTime.tryParse(encryptedData['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

      // Déchiffrer
      return await _e2eeService.decryptMessage(senderId, encryptedMessage);
    } catch (e) {
      debugPrint('E2EEHelper: Failed to decrypt message: $e');
      return null;
    }
  }

  /// Déchiffre un message de groupe avec Sender Key
  Future<String?> decryptGroupMessage({
    required String groupId,
    required String senderId,
    required Map<String, dynamic> messageData,
  }) async {
    if (!_isE2EEGroupMessage(messageData)) {
      return null;
    }

    try {
      final e2eeData = messageData['e2ee'] as Map<String, dynamic>;

      final encryptedMessage = SenderKeyEncryptedMessage(
        groupId: groupId,
        senderId: senderId,
        senderDeviceId: e2eeData['senderDeviceId'] as int,
        keyId: e2eeData['keyId'] as int,
        chainIndex: e2eeData['chainIndex'] as int,
        ciphertext: e2eeData['ciphertext'] as String,
        createdAt: DateTime.tryParse(e2eeData['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

      return await _senderKeyService.decryptWithSenderKey(
        groupId,
        senderId,
        encryptedMessage.senderDeviceId,
        encryptedMessage,
      );
    } catch (e) {
      debugPrint('E2EEHelper: Failed to decrypt group message: $e');
      return null;
    }
  }

  // ============================================================
  // CHIFFREMENT DES MÉDIAS
  // ============================================================

  /// Chiffre et uploade un fichier média
  Future<EncryptedMediaResult?> encryptAndUploadMedia({
    required File file,
    required String conversationId,
    required String senderId,
    required MediaType mediaType,
  }) async {
    // 1. Modération du média (si image)
    if (mediaType == MediaType.image) {
      final bytes = await file.readAsBytes();
      final moderationResult = await _moderationService.analyzeMediaContent(
        bytes,
        MediaContentType.image,
      );

      if (!moderationResult.isAllowed) {
        throw ContentBlockedException(
          'Ce média contient du contenu non autorisé',
          issues: moderationResult.issues,
        );
      }
    }

    // 2. Chiffrer et uploader
    return await _mediaService.encryptAndUploadFile(
      file: file,
      conversationId: conversationId,
      senderId: senderId,
      mediaType: mediaType,
    );
  }

  /// Télécharge et déchiffre un fichier média
  Future<File> downloadAndDecryptMedia(EncryptedMediaInfo mediaInfo) async {
    return await _mediaService.downloadAndDecryptFile(mediaInfo);
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Vérifie si un message est au format E2EE
  bool _isE2EEMessage(Map<String, dynamic> messageData) {
    return messageData['e2eeVersion'] != null &&
           messageData['e2ee'] != null;
  }

  /// Vérifie si c'est un message de groupe E2EE
  bool _isE2EEGroupMessage(Map<String, dynamic> messageData) {
    return _isE2EEMessage(messageData) &&
           messageData['keyId'] != null;
  }

  /// Génère les données E2EE pour stocker dans RTDB
  Map<String, dynamic> buildE2EEMessageData(E2EEMessagePayload payload) {
    final e2eeData = <String, dynamic>{};

    payload.encryptedMessages.forEach((deviceKey, encrypted) {
      e2eeData[deviceKey] = {
        'ciphertext': encrypted.ciphertext,
        'messageType': encrypted.messageType.value,
        'senderIdentityKey': encrypted.senderIdentityKey,
        'senderDeviceId': encrypted.senderDeviceId,
        'senderRegistrationId': encrypted.senderRegistrationId,
        'createdAt': encrypted.createdAt.toIso8601String(),
      };
    });

    return {
      'e2eeVersion': payload.e2eeVersion,
      'e2ee': e2eeData,
      'moderationFlags': payload.moderationMetadata,
    };
  }

  /// Génère les données E2EE pour un message de groupe
  Map<String, dynamic> buildE2EEGroupMessageData(E2EEGroupMessagePayload payload) {
    return {
      'e2eeVersion': payload.e2eeVersion,
      'e2ee': {
        'ciphertext': payload.encryptedMessage.ciphertext,
        'senderDeviceId': payload.encryptedMessage.senderDeviceId,
        'keyId': payload.encryptedMessage.keyId,
        'chainIndex': payload.encryptedMessage.chainIndex,
        'createdAt': payload.encryptedMessage.createdAt.toIso8601String(),
      },
      'keyId': payload.keyId,
      'moderationFlags': payload.moderationMetadata,
    };
  }
}

/// Payload pour un message E2EE 1-1
class E2EEMessagePayload {
  /// Messages chiffrés par appareil (clé: "userId_deviceId")
  final Map<String, E2EEEncryptedMessage> encryptedMessages;

  /// Métadonnées de modération (non chiffrées)
  final Map<String, dynamic> moderationMetadata;

  /// Version du protocole E2EE
  final int e2eeVersion;

  const E2EEMessagePayload({
    required this.encryptedMessages,
    required this.moderationMetadata,
    required this.e2eeVersion,
  });
}

/// Payload pour un message de groupe E2EE
class E2EEGroupMessagePayload {
  /// Message chiffré avec Sender Key
  final SenderKeyEncryptedMessage encryptedMessage;

  /// ID de la clé utilisée
  final int keyId;

  /// Métadonnées de modération
  final Map<String, dynamic> moderationMetadata;

  /// Version du protocole
  final int e2eeVersion;

  const E2EEGroupMessagePayload({
    required this.encryptedMessage,
    required this.keyId,
    required this.moderationMetadata,
    required this.e2eeVersion,
  });
}

/// Exception pour contenu bloqué par la modération
class ContentBlockedException implements Exception {
  final String message;
  final List<ModerationIssue> issues;

  ContentBlockedException(this.message, {this.issues = const []});

  @override
  String toString() => 'ContentBlockedException: $message';
}
