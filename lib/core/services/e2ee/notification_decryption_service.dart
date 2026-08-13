import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_crypto_service.dart';
import 'messaging_e2ee_service.dart';

/// Provider pour le service de déchiffrement des notifications
final notificationDecryptionServiceProvider =
    Provider<NotificationDecryptionService>((ref) {
  final e2eeService = ref.watch(messagingE2EEServiceProvider);
  final cryptoService = ref.watch(messageCryptoServiceProvider);
  return NotificationDecryptionService(
    e2eeService: e2eeService,
    cryptoService: cryptoService,
  );
});

/// Marqueur interne de MessageCryptoService.decrypt() quand aucune session
/// Signal locale ne permet de déchiffrer (pas une vraie donnée de message).
const _kE2EESessionRequise = '[🔐 E2EE — session requise]';

/// Service de déchiffrement des notifications E2EE
///
/// Ce service permet de déchiffrer les previews de messages dans les
/// notifications push quand l'app est au premier plan.
///
/// Note: Le déchiffrement en arrière-plan n'est pas supporté car il
/// nécessite l'initialisation de Hive et des services E2EE complets.
/// Les notifications en arrière-plan utilisent des previews génériques.
class NotificationDecryptionService {
  final MessagingE2EEService _e2eeService;
  final MessageCryptoService _cryptoService;

  NotificationDecryptionService({
    required MessagingE2EEService e2eeService,
    required MessageCryptoService cryptoService,
  })  : _e2eeService = e2eeService,
        _cryptoService = cryptoService;

  /// Tente de déchiffrer le preview d'un message pour une notification
  ///
  /// [senderId] - L'ID de l'expéditeur du message
  /// [cryptoPayload] - Les champs chiffrés bruts reçus dans la donnée FCM
  ///   (`e2eePayloads`, `e2eePayload` ou `senderKeyPayload` — mêmes formats
  ///   que ceux écrits par MessageCryptoService côté envoi)
  /// [messageType] - Le type de message (text, image, video, etc.)
  ///
  /// Retourne le texte déchiffré ou un fallback générique si le déchiffrement échoue
  Future<String> decryptPreview({
    required String senderId,
    required Map<String, dynamic> cryptoPayload,
    required String messageType,
  }) async {
    if (cryptoPayload.isEmpty) {
      return getFallbackPreview(messageType);
    }

    // Vérifier si le service E2EE est initialisé
    if (_e2eeService.currentUserId == null) {
      debugPrint('NotificationDecryption: E2EE service not initialized');
      return getFallbackPreview(messageType);
    }

    try {
      final decrypted = await _cryptoService.decrypt(
        payload: cryptoPayload,
        senderId: senderId,
      );

      if (decrypted.isNotEmpty && decrypted != _kE2EESessionRequise) {
        // Limiter la longueur pour la notification
        if (decrypted.length > 100) {
          return '${decrypted.substring(0, 100)}...';
        }
        return decrypted;
      }

      return getFallbackPreview(messageType);
    } catch (e) {
      debugPrint('NotificationDecryption: Error decrypting: $e');
      return getFallbackPreview(messageType);
    }
  }

  /// Reconstruit la charge utile de déchiffrement à partir de la donnée FCM
  /// brute (où les valeurs objet ont été json-encodées côté serveur pour
  /// respecter le format `data` de FCM, qui n'accepte que des chaînes).
  static Map<String, dynamic> cryptoPayloadFromFcmData(
    Map<String, dynamic> fcmData,
  ) {
    final payload = <String, dynamic>{};

    final senderKeyPayload = fcmData['senderKeyPayload'];
    if (senderKeyPayload is String && senderKeyPayload.isNotEmpty) {
      payload['senderKeyPayload'] = senderKeyPayload;
    }

    final e2eePayload = fcmData['e2eePayload'];
    if (e2eePayload is String && e2eePayload.isNotEmpty) {
      payload['e2eePayload'] = e2eePayload;
    }

    final e2eePayloadsRaw = fcmData['e2eePayloads'];
    if (e2eePayloadsRaw is String && e2eePayloadsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(e2eePayloadsRaw);
        if (decoded is Map) payload['e2eePayloads'] = decoded;
      } catch (e) {
        debugPrint('NotificationDecryption: e2eePayloads parse error: $e');
      }
    }

    return payload;
  }

  /// Retourne un preview générique basé sur le type de message
  static String getFallbackPreview(String messageType) {
    switch (messageType) {
      case 'image':
        return '📸 Photo';
      case 'video':
        return '🎥 Vidéo';
      case 'voiceNote':
      case 'audio':
        return '🎙️ Message vocal';
      case 'audioFile':
        return '🎵 Audio';
      case 'file':
        return '📄 Document';
      case 'call':
        return '📞 Appel';
      case 'location':
        return '📍 Position';
      default:
        return '🔒 Nouveau message';
    }
  }

  /// Prépare les données de notification pour l'affichage (foreground)
  ///
  /// Cette méthode prend les données FCM brutes et retourne les données
  /// prêtes pour l'affichage, avec le contenu déchiffré si possible.
  Future<NotificationDisplayData> prepareNotificationData(
    Map<String, dynamic> fcmData,
  ) async {
    final type = fcmData['type'] as String? ?? '';
    final messageType = fcmData['messageType'] as String? ?? 'text';
    final senderId = fcmData['senderId'] as String? ?? '';
    final cryptoPayload = cryptoPayloadFromFcmData(fcmData);
    final isE2EE = fcmData['isE2EE'] == 'true';

    String title = fcmData['title'] as String? ?? 'Nouvelle notification';
    String body = fcmData['body'] as String? ?? '';
    bool wasDecrypted = false;

    // Si c'est un message E2EE avec un payload chiffré exploitable
    if (type == 'message' && isE2EE && cryptoPayload.isNotEmpty) {
      final decryptedBody = await decryptPreview(
        senderId: senderId,
        cryptoPayload: cryptoPayload,
        messageType: messageType,
      );

      // Vérifier si le déchiffrement a réussi (pas un fallback)
      wasDecrypted = !decryptedBody.startsWith('🔒') &&
          !decryptedBody.startsWith('📸') &&
          !decryptedBody.startsWith('🎥') &&
          !decryptedBody.startsWith('🎙️') &&
          !decryptedBody.startsWith('📄') &&
          !decryptedBody.startsWith('📞') &&
          !decryptedBody.startsWith('📍');

      // Remplacer le body générique par le contenu déchiffré
      body = decryptedBody;

      // Pour les groupes, inclure le nom de l'expéditeur
      final senderName = fcmData['senderName'] as String?;
      if (senderName != null && fcmData['conversationType'] == 'group') {
        body = '$senderName: $decryptedBody';
      }
    }

    return NotificationDisplayData(
      title: title,
      body: body,
      type: type,
      targetId: fcmData['targetId'] as String? ?? '',
      conversationId: fcmData['conversationId'] as String?,
      messageId: fcmData['messageId'] as String?,
      senderId: senderId,
      wasDecrypted: wasDecrypted,
      rawData: fcmData,
    );
  }
}

/// Données préparées pour l'affichage d'une notification
class NotificationDisplayData {
  final String title;
  final String body;
  final String type;
  final String targetId;
  final String? conversationId;
  final String? messageId;
  final String? senderId;
  final bool wasDecrypted;
  final Map<String, dynamic> rawData;

  const NotificationDisplayData({
    required this.title,
    required this.body,
    required this.type,
    required this.targetId,
    this.conversationId,
    this.messageId,
    this.senderId,
    this.wasDecrypted = false,
    required this.rawData,
  });
}
