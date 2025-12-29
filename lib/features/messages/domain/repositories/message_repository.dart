import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
import '../entities/paginated_messages.dart';

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
  Future<Either<Failure, PaginatedMessages>> getMessagesPaginated({
    required String conversationId,
    required int limit,
    String? beforeMessageId,
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
    required String content,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? productData,
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

  /// Marquer les messages comme lus
  Future<Either<Failure, void>> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  });

  /// Obtenir ou créer une conversation individuelle existante
  Future<Either<Failure, ConversationEntity>>
  getOrCreateIndividualConversation({
    required String currentUserId,
    required String otherUserId,
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
  Future<Either<Failure, void>> muteConversation({
    required String conversationId,
    required String userId,
  });

  /// Réactiver les notifications pour une conversation
  Future<Either<Failure, void>> unmuteConversation({
    required String conversationId,
    required String userId,
  });
}
