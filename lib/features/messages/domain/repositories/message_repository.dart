import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
import '../entities/paginated_messages.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

abstract class MessageRepository {
  /// Stream des conversations de l'utilisateur
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId,
  );

  /// Récupérer les conversations depuis le cache local (instantané)
  Either<Failure, List<ConversationEntity>> getCachedConversations();

  /// Stream d'une conversation spécifique (pour détecter suppression/changements)
  Stream<Either<Failure, ConversationEntity?>> getConversationStream(
    String conversationId,
  );

  /// Stream des messages d'une conversation
  Stream<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId,
  );

  /// Récupérer les messages avec pagination (pour infinite scroll)
  /// [filterAfterDate] - Si fourni, ne retourne que les messages créés après cette date
  /// (utilisé pour les groupes privés où les nouveaux membres ne voient pas les anciens messages)
  Future<Either<Failure, PaginatedMessages>> getMessagesPaginated({
    required String conversationId,
    required int limit,
    String? beforeMessageId,
    DateTime? filterAfterDate,
  });

  /// Récupérer les messages en cache pour une conversation
  Either<Failure, List<MessageEntity>> getCachedMessages({
    required String conversationId,
    int? limit,
    String? beforeMessageId,
  });

  /// Stream des nouveaux messages après un timestamp donné
  Stream<Either<Failure, List<MessageEntity>>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  });

  /// Stream pour écouter les modifications de messages existants (réactions, éditions)
  Stream<Either<Failure, MessageEntity>> getMessageUpdatesStream({
    required String conversationId,
  });

  /// Envoyer un message texte
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    bool senderIsVerified = false,
    required String content,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<MentionedUser> mentionedUsers = const [],
    String? clientMessageId,
    String? recipientId,
    List<String> participantIds = const [],
    bool selfNote = false,
  });

  /// Envoyer un message avec fichier (image ou document)
  Future<Either<Failure, MessageEntity>> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required MessageType type,
    String? caption,
    void Function(double)? onProgress,
    bool Function()? checkCancelled,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Créer une conversation individuelle
  Future<Either<Failure, ConversationEntity>> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Créer une conversation de groupe
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  });

  /// Récupérer un message précis (déchiffré), même hors fenêtre paginée.
  Future<Either<Failure, MessageEntity?>> getMessageById({
    required String conversationId,
    required String messageId,
  });

  /// Marquer les messages comme livrés
  Future<Either<Failure, void>> markAsDelivered({
    required String conversationId,
    required String userId,
  });

  /// Marquer les messages comme lus
  Future<Either<Failure, void>> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Remettre à zéro le compteur de mentions non lues
  Future<Either<Failure, void>> clearUnreadMentions({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  });

  /// Recuperer une conversation par son ID
  Future<Either<Failure, ConversationEntity?>> getConversationById(
    String conversationId,
  );

  /// Restaurer une conversation supprimee pour un utilisateur
  Future<Either<Failure, void>> restoreConversationForUser({
    required String conversationId,
    required String userId,
  });

  /// Obtenir ou créer une conversation individuelle existante
  Future<Either<Failure, ConversationEntity>>
  getOrCreateIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Obtenir ou créer la conversation « Mes notes » (self-chat) de l'utilisateur
  Future<Either<Failure, ConversationEntity>> getOrCreateSelfConversation({
    required String userId,
  });

  /// Envoyer un message audio
  Future<Either<Failure, MessageEntity>> sendAudioMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File audioFile,
    required int duration,
    required List<double> waveform,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
  });

  /// Envoyer un message de localisation
  Future<Either<Failure, MessageEntity>> sendLocationMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required double latitude,
    required double longitude,
    required String address,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Envoyer un sticker
  Future<Either<Failure, MessageEntity>> sendStickerMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String stickerPackId,
    required String stickerId,
    required String stickerUrl,
    bool isAnimated = false,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Récupérer les médias d'une conversation (images et fichiers, pas audio)
  Future<Either<Failure, List<MessageEntity>>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  });

  /// Trouver l'ID de la conversation avec un utilisateur donné
  Future<Either<Failure, String?>> findConversationWithUser({
    required String currentUserId,
    required String otherUserId,
  });

  /// Trouver l'ID de la conversation de groupe par nom
  Future<Either<Failure, String?>> findGroupConversationByName({
    required String groupName,
    required String userId,
  });

  /// Trouver l'ID de la conversation de groupe par ID du groupe
  Future<Either<Failure, String?>> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  });

  /// Supprimer un message pour moi uniquement
  Future<Either<Failure, void>> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Supprimer un message pour tous les participants
  Future<Either<Failure, void>> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  });

  /// Archiver une conversation
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Désarchiver une conversation
  Future<Either<Failure, void>> unarchiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Mettre en sourdine une conversation
  /// [duration] - Duration to mute for. null means mute forever.
  Future<Either<Failure, void>> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  });

  /// Réactiver les notifications pour une conversation
  Future<Either<Failure, void>> unmuteConversation({
    required String conversationId,
    required String userId,
  });

  /// Épingler une conversation
  Future<Either<Failure, void>> pinConversation({
    required String conversationId,
    required String userId,
  });

  /// Désépingler une conversation
  Future<Either<Failure, void>> unpinConversation({
    required String conversationId,
    required String userId,
  });

  /// Toggle star status for a message
  Future<Either<Failure, void>> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Get starred messages for a conversation
  Future<Either<Failure, List<MessageEntity>>> getStarredMessages({
    required String conversationId,
    required String userId,
  });

  /// Search messages in a conversation by content
  Future<Either<Failure, List<MessageEntity>>> searchMessagesInConversation({
    required String conversationId,
    required String query,
  });

  /// Edit a text message (within 25 minute time limit)
  Future<Either<Failure, void>> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  });

  /// Set auto-delete settings for ephemeral messages
  /// [durationSeconds] - null to disable, or duration in seconds (86400=24h, 604800=7d, 2592000=30d)
  Future<Either<Failure, void>> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  });

  // ============ MESSAGE REQUESTS (Zone Tampon) ============

  /// Get pending message requests for a user
  Stream<Either<Failure, List<ConversationEntity>>> getMessageRequests(
    String userId,
  );

  /// Accept a message request
  Future<Either<Failure, void>> acceptMessageRequest({
    required String conversationId,
    required String recipientId,
  });

  /// Decline a message request
  Future<Either<Failure, void>> declineMessageRequest({
    required String conversationId,
    required String recipientId,
  });

  /// Create a conversation as a message request (for non-linked users)
  Future<Either<Failure, ConversationEntity>> createMessageRequest({
    required String currentUserId,
    required String otherUserId,
  });
}
