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

  /// Stream des nouveaux messages après un timestamp donné
  Stream<Either<Failure, List<MessageEntity>>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  });

  /// Envoyer un message texte
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
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
  });

  /// Marquer les messages comme lus
  Future<Either<Failure, void>> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<Either<Failure, void>> deleteConversation(String conversationId);

  /// Obtenir ou créer une conversation individuelle existante
  Future<Either<Failure, ConversationEntity>>
  getOrCreateIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });
}
