import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  /// Stream des conversations de l'utilisateur
  Stream<List<ConversationModel>> getConversations(String userId);

  /// Stream des messages d'une conversation (RTDB)
  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? filterAfterDate,
  });

  /// Stream d'une conversation spécifique (pour détecter suppression/changements)
  Stream<ConversationModel?> getConversationStream(String conversationId);

  /// Récupérer les messages avec pagination.
  ///
  /// Le curseur d'une page plus ancienne est le plus ancien message déjà
  /// affiché : son id dans [lastMessageKey], sa date dans [beforeCreatedAt].
  /// Les deux ensemble — la date seule perdrait les ex-aequo, l'id seul ne se
  /// compare à rien.
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? beforeCreatedAt,
    DateTime? filterAfterDate,
  });

  /// Stream des nouveaux messages après un timestamp donné
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  });

  /// Un signal à chaque nouveau message CHIFFRÉ de la conversation.
  ///
  /// Le temps réel n'écoutait que `messages`. Depuis la bascule MLS, les
  /// messages vivants sont dans `mls_messages` : plus rien n'arrivait en
  /// direct dans une conversation chiffrée, il fallait ressortir et revenir
  /// pour voir ce qu'on venait de recevoir. Constaté à deux téléphones le
  /// 2026-09-15.
  ///
  /// Un simple signal, pas un message : la ligne est chiffrée, et seule la
  /// passerelle sait la lire. C'est au dépôt de relire le fil quand ça tombe.
  Stream<void> mlsNouveauxMessages(String conversationId);

  /// Stream pour écouter les modifications de messages existants (réactions, éditions)
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  });

  /// Récupérer un message précis (déchiffré), même hors de la fenêtre
  /// paginée — utilisé par le bandeau des messages épinglés.
  Future<MessageModel?> getMessageById({
    required String conversationId,
    required String messageId,
  });

  /// Envoyer un message texte
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    bool senderIsVerified = false,
    required String content,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    String? recipientId,
    List<String> participantIds = const [],
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<Map<String, String>> mentionedUsers = const [],
    String? clientMessageId,
    bool selfNote = false,
  });

  /// Envoyer un message avec fichier (Legacy - prefer split methods)
  Future<MessageModel> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Upload a media file and return the UploadTask for progress tracking
  UploadTask uploadMediaFile({
    required File file,
    required String conversationId,
    required String fileName,
  });

  /// Send a message with an already uploaded media URL
  Future<MessageModel> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
    String? thumbnailUrl,
    int? videoDuration,
    int? audioDuration,
    List<double>? audioWaveform,
    String? blurhash,
    Map<String, dynamic>? mediaChiffre,
  });

  /// Créer une conversation individuelle
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Obtenir ou créer la conversation « Mes notes » (self-chat) de l'utilisateur.
  Future<ConversationModel> getOrCreateSelfConversation({
    required String userId,
  });

  /// Créer une conversation de groupe
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  });

  /// Marquer comme livré (message reçu sur l'appareil du destinataire)
  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  });

  /// Marquer comme lu
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Remettre à zéro le compteur de mentions non lues pour un utilisateur
  Future<void> clearUnreadMentions({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  });

  /// Trouver une conversation individuelle existante
  Future<ConversationModel?> findIndividualConversation({
    required String userId1,
    required String userId2,
  });

  /// Envoyer un message audio
  Future<MessageModel> sendAudioMessage({
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
    Map<String, dynamic>? mediaChiffre,
  });

  /// Envoyer un message de localisation
  Future<MessageModel> sendLocationMessage({
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

  /// Publier un sondage dans la conversation.
  ///
  /// La bulle ne transporte que `pollId` et la question : les options et les
  /// votes vivent dans `post_polls` / `post_poll_options`, lus par `PollCard`.
  Future<MessageModel> sendPollMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String pollId,
    required String question,
  });

  /// Envoyer un sticker
  Future<MessageModel> sendStickerMessage({
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
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
    DateTime? beforeCreatedAt,
  });

  /// Trouver une conversation de groupe par nom
  Future<ConversationModel?> findGroupConversationByName({
    required String groupName,
    required String userId,
  });

  /// Trouver une conversation de groupe par ID du groupe
  Future<ConversationModel?> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  });

  /// Supprimer un message pour moi (ajoute l'ID utilisateur à deletedFor)
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Supprimer un message pour tous (met deletedForEveryone à true)
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  });

  /// Archiver une conversation
  Future<void> archiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Désarchiver une conversation
  Future<void> unarchiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Mettre en sourdine une conversation
  /// [duration] - Duration to mute for. null means mute forever.
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  });

  /// Réactiver les notifications pour une conversation
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  });

  /// Épingler une conversation
  Future<void> pinConversation({
    required String conversationId,
    required String userId,
  });

  /// Désépingler une conversation
  Future<void> unpinConversation({
    required String conversationId,
    required String userId,
  });

  /// Obtenir le nombre de conversations épinglées par un utilisateur
  Future<int> getPinnedConversationCount(String userId);

  /// Promouvoir un utilisateur comme admin du groupe
  Future<void> promoteToAdmin({
    required String conversationId,
    required String userId,
  });

  /// Retirer les droits d'admin du groupe
  Future<void> demoteFromAdmin({
    required String conversationId,
    required String userId,
  });

  /// Retirer un utilisateur du groupe
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  });

  /// Signaler un message
  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String reason,
  });

  /// Signaler un groupe
  Future<void> reportGroup({
    required String conversationId,
    required String userId,
    required String reason,
  });

  /// Set typing status for a user in a conversation
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  });

  /// Stream of users currently typing in a conversation
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId);

  /// Set this user's emoji reaction on a message. One reaction per person
  /// per message: replaces any reaction this user already had.
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  });

  /// Remove this user's reaction from a message
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Send a system message (e.g., "User joined the group")
  Future<MessageModel> sendSystemMessage({
    required String conversationId,
    required String content,
  });

  /// Rechercher des conversations par nom ou dernier message
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  );

  /// Toggle star status for a message
  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Edit a text message (within time limit)
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  });

  /// Set auto-delete settings for ephemeral messages
  Future<void> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  });

  /// Get auto-delete settings for a conversation
  Future<int?> getAutoDeleteSettings(String conversationId);

  /// Get starred messages for a conversation by user
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  });

  /// Search messages in a conversation by content
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  });

  /// Restaurer une conversation pour un utilisateur (retirer de deletedBy)
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  });

  /// Recuperer une conversation par son ID
  Future<ConversationModel?> getConversationById(String conversationId);

  /// Recuperer uniquement les messages depuis un timestamp (sync differentielle)
  Future<List<MessageModel>> getMessagesSince({
    required String conversationId,
    required DateTime since,
    int limit = 100,
  });

  /// Get pending message requests for a user (conversations where user is recipient)
  Stream<List<ConversationModel>> getMessageRequests(String userId);

  /// Update the request status of a conversation (accept or decline)
  Future<void> updateRequestStatus({
    required String conversationId,
    required String status,
    required String recipientId,
  });

  /// Create an individual conversation as a message request (for non-linked users)
  Future<ConversationModel> createIndividualConversationAsRequest({
    required String currentUserId,
    required String otherUserId,
  });
}
