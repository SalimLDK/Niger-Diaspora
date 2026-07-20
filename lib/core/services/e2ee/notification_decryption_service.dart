import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messaging_e2ee_service.dart';
import 'models/e2ee_models.dart';

/// Provider pour le service de déchiffrement des notifications
final notificationDecryptionServiceProvider =
    Provider<NotificationDecryptionService>((ref) {
  final e2eeService = ref.watch(messagingE2EEServiceProvider);
  return NotificationDecryptionService(e2eeService: e2eeService);
});

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

  NotificationDecryptionService({
    required MessagingE2EEService e2eeService,
  }) : _e2eeService = e2eeService;

  /// Tente de déchiffrer le preview d'un message pour une notification
  ///
  /// [senderId] - L'ID de l'expéditeur du message
  /// [encryptedPreview] - Le preview chiffré (format E2EE Firebase string)
  /// [messageType] - Le type de message (text, image, video, etc.)
  ///
  /// Retourne le texte déchiffré ou un fallback générique si le déchiffrement échoue
  Future<String> decryptPreview({
    required String senderId,
    required String? encryptedPreview,
    required String messageType,
  }) async {
    // Si pas de preview chiffré, retourner le fallback
    if (encryptedPreview == null || encryptedPreview.isEmpty) {
      return getFallbackPreview(messageType);
    }

    // Vérifier si le service E2EE est initialisé
    if (_e2eeService.currentUserId == null) {
      debugPrint('NotificationDecryption: E2EE service not initialized');
      return getFallbackPreview(messageType);
    }

    try {
      // Parser le message chiffré
      final encryptedMessage = E2EEEncryptedMessage.fromFirebaseString(
        encryptedPreview,
      );

      // Déchiffrer le message
      final decrypted = await _e2eeService.decryptMessage(
        senderId,
        encryptedMessage,
      );

      if (decrypted != null && decrypted.isNotEmpty) {
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
    final encryptedPreview = fcmData['encryptedPreview'] as String?;
    final isE2EE = fcmData['isE2EE'] == 'true';

    String title = fcmData['title'] as String? ?? 'Nouvelle notification';
    String body = fcmData['body'] as String? ?? '';
    bool wasDecrypted = false;

    // Si c'est un message E2EE avec un preview chiffré
    if (type == 'message' && isE2EE && encryptedPreview != null) {
      final decryptedBody = await decryptPreview(
        senderId: senderId,
        encryptedPreview: encryptedPreview,
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
