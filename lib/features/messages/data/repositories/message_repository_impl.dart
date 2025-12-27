import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/paginated_messages.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';
import '../models/message_model.dart';

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;

  // DocumentSnapshot? _lastDocument; // Removed: using stateless cursor via beforeMessageId (RTDB key)

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    CacheService? cacheService,
  }) : cacheService = cacheService ?? CacheService.instance;

  @override
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId,
  ) {
    return remoteDataSource
        .getConversations(userId)
        .map((conversations) {
          return Right<Failure, List<ConversationEntity>>(
            conversations.map((c) => c.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<ConversationEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Stream<Either<Failure, ConversationEntity?>> getConversationStream(
    String conversationId,
  ) {
    return remoteDataSource
        .getConversationStream(conversationId)
        .map((model) {
          if (model == null) {
            return const Right<Failure, ConversationEntity?>(null);
          }
          return Right<Failure, ConversationEntity?>(model.toEntity());
        })
        .handleError((error) {
          return Left<Failure, ConversationEntity?>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Stream<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId,
  ) {
    return remoteDataSource
        .getMessages(conversationId)
        .map((messages) {
          return Right<Failure, List<MessageEntity>>(
            messages.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<MessageEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final message = await remoteDataSource.sendTextMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
      );
      return Right(message.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required MessageType type,
    String? caption,
    void Function(double customProgress)? onProgress,
    bool Function()? checkCancelled,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final fileName = file.path.split('/').last;

      // 1. Start Upload
      final uploadTask = remoteDataSource.uploadMediaFile(
        file: file,
        conversationId: conversationId,
        fileName: fileName,
      );

      // 2. Monitor Progress & Cancellation
      // Use a Completer to bridge Stream/Callback to Future
      final completer = Completer<Either<Failure, String>>();

      // Subscribe to task stream
      final subscription = uploadTask.snapshotEvents.listen(
        (event) {
          // Check cancellation
          if (checkCancelled?.call() == true) {
            uploadTask.cancel();
            if (!completer.isCompleted) {
              completer.complete(const Left(ServerFailure('Envoi annulé')));
            }
            return;
          }

          // Report progress
          if (onProgress != null && event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            onProgress(progress);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            if (e.code == 'canceled') {
              completer.complete(const Left(ServerFailure('Envoi annulé')));
            } else {
              completer.complete(Left(ServerFailure(e.toString())));
            }
          }
        },
      );

      // Wait for completion
      try {
        await uploadTask;
        if (!completer.isCompleted) {
          final url = await uploadTask.snapshot.ref.getDownloadURL();
          completer.complete(Right(url));
        }
      } catch (e) {
        // Task failure (including cancellation)
        if (!completer.isCompleted) {
          // Check if it was purely cancellation
          if (e.toString().contains('canceled')) {
            completer.complete(const Left(ServerFailure('Envoi annulé')));
          } else {
            completer.complete(Left(ServerFailure(e.toString())));
          }
        }
      } finally {
        await subscription.cancel();
      }

      final startResult = await completer.future;

      return startResult.fold((failure) => Left(failure), (fileUrl) async {
        // 3. Send Message to DB
        // Get necessary file info that we already have or can get easily
        final fileSize = await file.length();
        // Simple mime type logic (or use package:mime)
        final ext = fileName.split('.').last.toLowerCase();
        String mimeType = 'application/octet-stream';
        if (['jpg', 'jpeg', 'png'].contains(ext)) {
          mimeType = 'image/$ext';
        } else if (ext == 'pdf') {
          mimeType = 'application/pdf';
        }

        final message = await remoteDataSource.sendMediaMessage(
          conversationId: conversationId,
          senderId: senderId,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          type: type.name,
          caption: caption,
        );
        return Right(message.toEntity());
      });
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final conversation = await remoteDataSource.createIndividualConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final conversation = await remoteDataSource.createGroupConversation(
        creatorId: creatorId,
        participantIds: participantIds,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        groupId: groupId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.markAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation(
    String conversationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.deleteConversation(conversationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>>
  getOrCreateIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      // D'abord chercher une conversation existante
      final existing = await remoteDataSource.findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );

      if (existing != null) {
        return Right(existing.toEntity());
      }

      // Sinon, en créer une nouvelle
      final conversation = await remoteDataSource.createIndividualConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, PaginatedMessages>> getMessagesPaginated({
    required String conversationId,
    required int limit,
    String? beforeMessageId,
  }) async {
    final isConnected = await networkInfo.isConnected;

    if (isConnected) {
      try {
        final (messages, _) = await remoteDataSource.getMessagesPaginated(
          conversationId: conversationId,
          limit: limit,
          lastMessageKey: beforeMessageId,
        );

        // _lastDocument = lastDoc; // Not needed anymore

        final entities = messages.map((m) => m.toEntity()).toList();
        final hasMore = messages.length >= limit;

        // Cache the messages
        final messageMaps = messages.map((m) => m.toJson()).toList();
        await cacheService.cacheMessages(conversationId, messageMaps);

        return Right(
          PaginatedMessages(
            messages: entities,
            hasMore: hasMore,
            lastMessageId: entities.isNotEmpty ? entities.first.id : null,
            oldestMessageTimestamp:
                entities.isNotEmpty ? entities.first.createdAt : null,
          ),
        );
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
      }
    } else {
      // Offline mode - load from cache
      try {
        final cachedMessages = cacheService.getCachedMessages(
          conversationId,
          limit: limit,
          beforeMessageId: beforeMessageId,
        );

        if (cachedMessages.isEmpty) {
          return const Left(CacheFailure('Aucun message en cache'));
        }

        final entities =
            cachedMessages
                .map((m) => MessageModel.fromJson(m).toEntity())
                .toList();

        final totalCached = cacheService.getCachedMessagesCount(conversationId);
        final hasMore = entities.length < totalCached;

        return Right(
          PaginatedMessages(
            messages: entities,
            hasMore: hasMore,
            lastMessageId: entities.isNotEmpty ? entities.first.id : null,
            oldestMessageTimestamp:
                entities.isNotEmpty ? entities.first.createdAt : null,
          ),
        );
      } catch (e) {
        return Left(CacheFailure('Erreur lecture cache: ${e.toString()}'));
      }
    }
  }

  @override
  Stream<Either<Failure, List<MessageEntity>>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  }) {
    return remoteDataSource
        .getNewMessagesStream(
          conversationId: conversationId,
          afterTimestamp: afterTimestamp,
        )
        .map((messages) {
          // Cache new messages
          final messageMaps = messages.map((m) => m.toJson()).toList();
          cacheService.cacheMessages(conversationId, messageMaps);

          return Right<Failure, List<MessageEntity>>(
            messages.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<MessageEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  void resetPagination() {
    // _lastDocument = null;
  }

  @override
  Future<Either<Failure, MessageEntity>> sendAudioMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File audioFile,
    required int duration,
    required List<double> waveform,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final message = await remoteDataSource.sendAudioMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        audioFile: audioFile,
        duration: duration,
        waveform: waveform,
      );
      return Right(message.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final messages = await remoteDataSource.getMediaMessages(
        conversationId: conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
      return Right(messages.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String?>> findConversationWithUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final conversation = await remoteDataSource.findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    try {
      final conversation = await remoteDataSource.findGroupConversationByName(
        groupName: groupName,
        userId: userId,
      );
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    try {
      final conversation = await remoteDataSource
          .findGroupConversationByGroupId(groupId: groupId, userId: userId);
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await remoteDataSource.deleteMessageForMe(
        conversationId: conversationId,
        messageId: messageId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await remoteDataSource.deleteMessageForEveryone(
        conversationId: conversationId,
        messageId: messageId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.archiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.unarchiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> muteConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.muteConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.unmuteConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }
}
