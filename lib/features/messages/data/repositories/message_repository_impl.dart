import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
// import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/blurhash_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/paginated_messages.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;
  final BlurhashService blurhashService;

  // DocumentSnapshot? _lastDocument; // Removed: using stateless cursor via beforeMessageId (RTDB key)

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    CacheService? cacheService,
    BlurhashService? blurhashService,
  }) : cacheService = cacheService ?? CacheService.instance,
       blurhashService = blurhashService ?? BlurhashService();

  /// Collapse duplicate 1:1 conversations that share the same participant pair.
  ///
  /// Legacy data can hold two rows for the same two users: a 'request' row
  /// (accepted requests keep type='request') plus a plain 'individual' row
  /// created later because findIndividualConversation used to ignore request
  /// rows. Both map to [ConversationType.individual] here, so the same contact
  /// would appear twice in the list. We keep only the most recently active row
  /// per pair. Groups are never collapsed.
  List<ConversationEntity> _dedupConversationsByPair(
    List<ConversationEntity> conversations,
  ) {
    final indexByPair = <String, int>{};
    final result = <ConversationEntity>[];

    for (final c in conversations) {
      final key = _participantPairKey(c);
      if (key == null) {
        // Groups (or malformed pairs): never merged.
        result.add(c);
        continue;
      }

      final existingIndex = indexByPair[key];
      if (existingIndex == null) {
        indexByPair[key] = result.length;
        result.add(c);
      } else if (_isMoreRecentlyActive(c, result[existingIndex])) {
        // Keep the row that was actually used most recently.
        result[existingIndex] = c;
      }
    }
    return result;
  }

  /// Stable key for a 1:1 conversation's participant pair; null for groups
  /// or conversations without exactly two participants.
  String? _participantPairKey(ConversationEntity c) {
    if (c.isGroup) return null;
    if (c.participantIds.length != 2) return null;
    final ids = [...c.participantIds]..sort();
    return ids.join('|');
  }

  bool _isMoreRecentlyActive(ConversationEntity a, ConversationEntity b) {
    final aTime = a.lastMessageAt ?? a.createdAt;
    final bTime = b.lastMessageAt ?? b.createdAt;
    return aTime.isAfter(bTime);
  }

  @override
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId,
  ) {
    return remoteDataSource
        .getConversations(userId)
        .map((conversations) {
          // Filter out deleted conversations
          final filteredConversations =
              conversations.where((c) {
                return !c.deletedBy.containsKey(userId);
              }).toList();

          // Cache the conversations
          // Convert models to json maps for caching
          final conversationsMap =
              filteredConversations.map((c) => c.toJson()).toList();
          cacheService.cacheConversations(conversationsMap);

          return Right<Failure, List<ConversationEntity>>(
            _dedupConversationsByPair(
              filteredConversations.map((c) => c.toEntity()).toList(),
            ),
          );
        })
        .handleError((error) {
          return Left<Failure, List<ConversationEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Either<Failure, List<ConversationEntity>> getCachedConversations() {
    try {
      final cachedMap = cacheService.getAllCachedConversations();
      // Sort by lastMessageAt descending if needed, though cache might be unordered
      // Assuming cache service returns list, we sort it here to be safe
      cachedMap.sort((a, b) {
        final aTime = a['lastMessageAt'] as String?;
        final bTime = b['lastMessageAt'] as String?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // nulls sink to end
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending
      });

      final entities =
          cachedMap
              .map((map) => ConversationModel.fromJson(map))
              // Note: Cache is already filtered by userId during caching in getConversations()
              // Deleted conversations are filtered out before caching, so this is safe
              .map((model) => model.toEntity())
              .toList();

      return Right(_dedupConversationsByPair(entities));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
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
  Either<Failure, List<MessageEntity>> getCachedMessages({
    required String conversationId,
    int? limit,
    String? beforeMessageId,
  }) {
    try {
      final cachedMessages = cacheService.getCachedMessages(
        conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );

      final entities =
          cachedMessages
              .map((m) => MessageModel.fromJson(m).toEntity())
              .toList();

      return Right(entities);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
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
        senderIsVerified: senderIsVerified,
        content: content,
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
        productData: productData,
        postData: postData,
        eventData: eventData,
        sentWhileBlockedBy: sentWhileBlockedBy,
        linkPreviewData: linkPreviewData,
        isForwarded: isForwarded,
        mentionedUsers: mentionedUsers.map((m) => {'id': m.id, 'name': m.name}).toList(),
        clientMessageId: clientMessageId,
        recipientId: recipientId,
        participantIds: participantIds,
        selfNote: selfNote,
      );
      return Right(message.toEntity());
    } on E2EEException catch (e) {
      return Left(E2EEFailure(e.message));
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
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
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
        } else if (['mp3', 'm4a', 'aac', 'ogg', 'wav', 'flac'].contains(ext)) {
          mimeType = 'audio/$ext';
        }

        // Generate blurhash for images and videos
        String? blurhash;
        if (type == MessageType.image) {
          blurhash = await blurhashService.generateFromImage(file);
        } else if (type == MessageType.video) {
          blurhash = await blurhashService.generateFromVideo(file);
        }

        // Extract audio duration for audio files.
        int? audioDuration;
        if (type == MessageType.audio) {
          audioDuration = await AudioPlaybackService.getDurationFromFile(file.path);
        }

        // Map app MessageType to DB type string.
        final dbType = type == MessageType.audio ? 'audioFile' : type.name;

        final message = await remoteDataSource.sendMediaMessage(
          conversationId: conversationId,
          senderId: senderId,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          type: dbType,
          caption: caption,
          replyToId: replyToId,
          replyToMessageData: replyToMessageData,
          blurhash: blurhash,
          audioDuration: audioDuration,
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
  Future<Either<Failure, MessageEntity?>> getMessageById({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final model = await remoteDataSource.getMessageById(
        conversationId: conversationId,
        messageId: messageId,
      );
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('Erreur chargement message: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await remoteDataSource.markAsDelivered(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur livraison: ${e.toString()}'));
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
  Future<Either<Failure, void>> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      await remoteDataSource.clearUnreadMentions(
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
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  }) async {
    try {
      if (await networkInfo.isConnected) {
        await remoteDataSource.deleteConversation(
          conversationId: conversationId,
          userId: userId,
          forEveryone: forEveryone,
        );
        return const Right(null);
      } else {
        // Offline deletion not fully supported yet for sync,
        // but could implement local marking if needed.
        return const Left(NetworkFailure('Non disponible hors connexion'));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity?>> getConversationById(
    String conversationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final conversation = await remoteDataSource.getConversationById(
        conversationId,
      );
      return Right(conversation?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.restoreConversationForUser(
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
        // CORRECTION: Verifier si supprimee pour l'utilisateur actuel
        if (existing.deletedBy.containsKey(currentUserId)) {
          // Retirer le flag deletedBy pour "ressusciter" la conversation
          await remoteDataSource.restoreConversationForUser(
            conversationId: existing.id,
            userId: currentUserId,
          );
          // Retourner la conversation restauree
          final restored = existing.copyWith(
            deletedBy: Map.from(existing.deletedBy)..remove(currentUserId),
          );
          return Right(restored.toEntity());
        }
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
  Future<Either<Failure, ConversationEntity>> getOrCreateSelfConversation({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final conversation = await remoteDataSource.getOrCreateSelfConversation(
        userId: userId,
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
    DateTime? filterAfterDate,
  }) async {
    // debugPrint(
    //   '📥 Repository: getMessagesPaginated called for $conversationId',
    // );
    final isConnected = await networkInfo.isConnected;
    // debugPrint('📡 Repository: isConnected = $isConnected');

    if (isConnected) {
      try {
        // debugPrint('🌐 Repository: Fetching from remote data source...');
        // Fetch limit+1 to detect whether a next page exists without generating
        // a spurious empty page when the result count equals the page size.
        final (messages, _) = await remoteDataSource.getMessagesPaginated(
          conversationId: conversationId,
          limit: limit + 1,
          lastMessageKey: beforeMessageId,
          filterAfterDate: filterAfterDate,
        );

        final hasMore = messages.length > limit;
        // Drop the oldest probe item used to detect hasMore, keeping the
        // newest `limit` messages (datasource returns ascending order).
        final trimmed = hasMore ? messages.sublist(1) : messages;

        final entities = trimmed.map((m) => m.toEntity()).toList();

        // Cache the messages
        final messageMaps = trimmed.map((m) => m.toJson()).toList();
        await cacheService.cacheMessages(conversationId, messageMaps);

        // debugPrint('💾 Repository: Cached ${messageMaps.length} messages');

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
        // debugPrint('❌ Repository: ServerException - ${e.message}');
        return Left(ServerFailure(e.message));
      } catch (e) {
        // debugPrint('❌ Repository: Unexpected error - ${e.toString()}');
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

  @override
  Stream<Either<Failure, MessageEntity>> getMessageUpdatesStream({
    required String conversationId,
  }) {
    return remoteDataSource
        .getMessageUpdatesStream(conversationId: conversationId)
        .map((message) {
          return Right<Failure, MessageEntity>(message.toEntity());
        })
        .handleError((error) {
          return Left<Failure, MessageEntity>(ServerFailure(error.toString()));
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
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
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
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
        isForwarded: isForwarded,
      );
      return Right(message.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
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
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final message = await remoteDataSource.sendLocationMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        latitude: latitude,
        longitude: longitude,
        address: address,
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
      );
      return Right(message.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
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
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final message = await remoteDataSource.sendStickerMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        stickerPackId: stickerPackId,
        stickerId: stickerId,
        stickerUrl: stickerUrl,
        isAnimated: isAnimated,
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
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
    Duration? duration,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.muteConversation(
        conversationId: conversationId,
        userId: userId,
        duration: duration,
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

  @override
  Future<Either<Failure, void>> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.pinConversation(
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
  Future<Either<Failure, void>> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.unpinConversation(
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
  Future<Either<Failure, void>> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await remoteDataSource.toggleStarMessage(
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
  Future<Either<Failure, List<MessageEntity>>> getStarredMessages({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final models = await remoteDataSource.getStarredMessages(
        conversationId: conversationId,
        userId: userId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> searchMessagesInConversation({
    required String conversationId,
    required String query,
  }) async {
    try {
      final models = await remoteDataSource.searchMessagesInConversation(
        conversationId: conversationId,
        query: query,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.editMessage(
        conversationId: conversationId,
        messageId: messageId,
        newContent: newContent,
        oldContent: oldContent,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.setAutoDeleteSettings(
        conversationId: conversationId,
        durationSeconds: durationSeconds,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  /// Synchroniser les messages de maniere incrementale (sync differentielle)
  Future<Either<Failure, List<MessageEntity>>> syncMessagesIncremental({
    required String conversationId,
  }) async {
    try {
      // 1. Obtenir le dernier timestamp du cache
      final cachedMessages = cacheService.getCachedMessages(conversationId);

      DateTime lastTimestamp;
      if (cachedMessages.isNotEmpty) {
        // Prendre le timestamp du message le plus recent
        final timestamps =
            cachedMessages
                .map((m) => m['createdAt'] as String?)
                .where((t) => t != null)
                .map((t) => DateTime.parse(t!).toLocal())
                .toList();

        if (timestamps.isNotEmpty) {
          lastTimestamp = timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
        } else {
          lastTimestamp = DateTime.now().subtract(const Duration(days: 30));
        }
      } else {
        // Pas de cache, charger les 30 derniers jours
        lastTimestamp = DateTime.now().subtract(const Duration(days: 30));
      }

      // 2. Recuperer seulement les nouveaux messages
      final newMessages = await remoteDataSource.getMessagesSince(
        conversationId: conversationId,
        since: lastTimestamp,
      );

      // debugPrint('SyncIncremental: Found ${newMessages.length} new messages since $lastTimestamp');

      // 3. Merger avec le cache
      if (newMessages.isNotEmpty) {
        final newMessagesJson = newMessages.map((m) => m.toJson()).toList();
        await cacheService.cacheMessagesLRU(conversationId, newMessagesJson);
      }

      // 4. Retourner tous les messages du cache
      final allCachedMessages = cacheService.getCachedMessages(conversationId);
      final entities =
          allCachedMessages
              .map((json) => MessageModel.fromJson(json).toEntity())
              .toList();

      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur de synchronisation: $e'));
    }
  }

  // ============ MESSAGE REQUESTS (Zone Tampon) ============

  @override
  Stream<Either<Failure, List<ConversationEntity>>> getMessageRequests(
    String userId,
  ) {
    return remoteDataSource.getMessageRequests(userId).map((models) {
      try {
        final entities = models.map((m) => m.toEntity()).toList();
        return Right<Failure, List<ConversationEntity>>(entities);
      } catch (e) {
        return const Left<Failure, List<ConversationEntity>>(
          ServerFailure('Erreur lors de la recuperation des demandes'),
        );
      }
    });
  }

  @override
  Future<Either<Failure, void>> acceptMessageRequest({
    required String conversationId,
    required String recipientId,
  }) async {
    try {
      await remoteDataSource.updateRequestStatus(
        conversationId: conversationId,
        status: 'accepted',
        recipientId: recipientId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur lors de l\'acceptation: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> declineMessageRequest({
    required String conversationId,
    required String recipientId,
  }) async {
    try {
      await remoteDataSource.updateRequestStatus(
        conversationId: conversationId,
        status: 'declined',
        recipientId: recipientId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur lors du refus: $e'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createMessageRequest({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final model = await remoteDataSource.createIndividualConversationAsRequest(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la creation de la demande: $e'));
    }
  }
}
