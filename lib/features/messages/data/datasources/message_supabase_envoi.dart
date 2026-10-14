part of 'message_supabase_datasource.dart';

/// Envoi des messages : texte, médias, notes vocales, transferts.
mixin _Envoi on _MessageSupabaseBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<MessageModel?> getMessageById({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException(
          'Session non établie – reconnectez-vous',
        );
      }
      final row =
          await _supabase
              .from('messages')
              .select()
              .eq('id', messageId)
              .eq('conversation_id', conversationId)
              .maybeSingle();
      if (row == null) return null;
      // Déchiffre le contenu (E2EE / AES) comme le flux de pagination : sans
      // ça, un message épinglé résolu hors de la fenêtre chargée renvoyait du
      // texte chiffré brut (affiché tel quel dans le bandeau épinglé).
      return await _msgFromRowAsync(Map<String, dynamic>.from(row));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('getMessageById error: $e');
    }
  }

  @override
  Future<MessageModel> sendTextMessage({
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
    List<Map<String, String>> mentionedUsers = const [],
    String? clientMessageId,
    String? recipientId,
    List<String> participantIds = const [],
    bool selfNote = false,
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      // Encrypt with Signal Protocol (throws if E2EE unavailable)
      final cryptoFields = await _encryptContent(
        plaintext: content,
        recipientId: recipientId,
        participantIds: participantIds,
        conversationId: conversationId,
        selfNote: selfNote,
      );

      final annexes = await _annexesChiffreesPour(
        conversationId,
        replyToMessageData: replyToMessageData,
        postData: postData,
        eventData: eventData,
        productData: productData,
        linkPreviewData: linkPreviewData,
      );

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': content, // base (overridden by cryptoFields)
        'encryptionLevel': 'aes', // base (overridden by cryptoFields)
        ...cryptoFields, // encrypted content + encryptionLevel + e2ee payload
        'status': 'sent',
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        if (replyToId != null) 'replyToId': replyToId,
        ...annexes,
        if (sentWhileBlockedBy.isNotEmpty)
          'sentWhileBlockedBy': sentWhileBlockedBy,
        if (isForwarded) 'isForwarded': isForwarded,
        if (mentionedUsers.isNotEmpty) 'mentionedUsers': mentionedUsers,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (selfNote) 'selfNote': selfNote,
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: 'text',
        createdAt: now,
        data: msgData,
      );

      final displayText =
          postData != null
              ? '📌 ${postData['authorName'] ?? 'Post partagé'}'
              : productData != null
              ? '🛒 ${productData['title'] ?? 'Produit'}'
              : content;

      await _updateConversationLastMessage(
        conversationId,
        text: displayText,
        senderId: senderId,
        type: 'text',
        messageId: msgId,
      );

      // Always return plaintext to the sender's local state — les charges
      // annexes comme le contenu : `msgData` ne porte que leur forme chiffrée,
      // et sans ce rappel l'expéditeur verrait sa propre carte disparaître de
      // sa bulle jusqu'au prochain chargement.
      return MessageModel.fromJson({
        ...msgData,
        'content': content,
        ..._annexesEnClair(
          replyToMessageData: replyToMessageData,
          postData: postData,
          eventData: eventData,
          productData: productData,
          linkPreviewData: linkPreviewData,
        ),
        'id': msgId,
        'senderId': senderId,
        'type': 'text',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendTextMessage error: $e');
    }
  }

  @override
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
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final annexes = await _annexesChiffreesPour(
        conversationId,
        replyToMessageData: replyToMessageData,
      );
      final mediaScelle = await _scellerMedia(mediaChiffre, conversationId);

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': caption ?? '',
        'status': 'sent',
        'fileUrl': fileUrl,
        'fileName': mediaChiffre == null
            ? fileName
            : MessageSupabaseDataSource.nomGeneriquePour(type),
        'fileSize': fileSize,
        'mimeType': mimeType,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        ...annexes,
        ...mediaScelle,
        if (isForwarded) 'isForwarded': isForwarded,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (videoDuration != null) 'videoDuration': videoDuration,
        if (audioDuration != null) 'audioDuration': audioDuration,
        if (audioWaveform != null) 'audioWaveform': audioWaveform,
        if (blurhash != null) 'blurhash': blurhash,
        'mediaExpiresAt':
            DateTime.now()
                .add(const Duration(days: 15))
                .toUtc()
                .toIso8601String(),
        'mediaExpired': false,
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        createdAt: now,
        data: msgData,
      );

      final String lastMsg;
      switch (type) {
        case 'image':
          lastMsg = '📷 Photo';
        case 'video':
          lastMsg = '🎬 Vidéo';
        case 'audioFile':
          lastMsg = '🎵 Audio';
        default:
          lastMsg = '📎 Fichier';
      }

      await _updateConversationLastMessage(
        conversationId,
        text: lastMsg,
        senderId: senderId,
        type: type,
        messageId: msgId,
      );

      return MessageModel.fromJson({
        ...msgData,
        ..._annexesEnClair(replyToMessageData: replyToMessageData),
        // Le modèle rendu à l'expéditeur porte le vrai nom et la clé en
        // clair : ils ne quittent pas l'appareil, et sans eux sa propre bulle
        // serait illisible jusqu'au prochain chargement.
        'fileName': fileName,
        if (mediaChiffre != null) _kChampMediaChiffre: mediaChiffre,
        'id': msgId,
        'senderId': senderId,
        'type': type,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendMediaMessage error: $e');
    }
  }

  /// Envoi d'un message vocal.
  ///
  /// Cette méthode levait `UnimplementedError` : le repository l'attrapait dans
  /// son `catch (e)` générique et renvoyait un `ServerFailure`, donc TOUT
  /// message vocal échouait sans que rien ne dise pourquoi. Le chemin est le
  /// même que `sendMediaMessage` (le média part toujours sur Firebase Storage,
  /// cf. [uploadMediaFile]), avec le type `voiceNote` et les métadonnées audio.
  @override
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
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session introuvable');
      }

      final fileName = audioFile.path.split(RegExp(r'[/\\]')).last;
      final dotIndex = fileName.lastIndexOf('.');
      final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '.m4a';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Média déjà chiffré et téléversé par le repository : rien à envoyer
      // en clair, l'URL est celle du blob.
      final String fileUrl;
      if (mediaChiffre != null) {
        fileUrl = (mediaChiffre['encryptedUrl'] as String?) ?? '';
      } else {
        final storageRef = FirebaseStorage.instance.ref().child(
          'messages/$conversationId/audio_$timestamp$extension',
        );
        await storageRef.putFile(audioFile);
        fileUrl = await storageRef.getDownloadURL();
      }
      final mediaScelle = await _scellerMedia(mediaChiffre, conversationId);

      final fileSize = await audioFile.length();
      final msgId = _uuid.v4();
      final nowDateTime = DateTime.now();
      final now = nowDateTime.toUtc().toIso8601String();

      final annexes = await _annexesChiffreesPour(
        conversationId,
        replyToMessageData: replyToMessageData,
      );

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': '',
        'status': 'sent',
        'fileUrl': fileUrl,
        'fileName': mediaChiffre == null
            ? fileName
            : MessageSupabaseDataSource.nomGeneriquePour('voiceNote'),
        'fileSize': fileSize,
        'mimeType': _audioMimeType(extension),
        'audioDuration': duration,
        'audioWaveform': waveform,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        ...annexes,
        ...mediaScelle,
        if (isForwarded) 'isForwarded': true,
        'mediaExpiresAt':
            nowDateTime.add(const Duration(days: 15)).toUtc().toIso8601String(),
        'mediaExpired': false,
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: 'voiceNote',
        createdAt: now,
        data: msgData,
      );

      await _updateConversationLastMessage(
        conversationId,
        text: '\u{1F399}\u{FE0F} Message vocal',
        senderId: senderId,
        type: 'voiceNote',
        messageId: msgId,
      );

      // Le fichier temporaire de l'enregistreur n'a plus de raison d'être une
      // fois téléversé. Best-effort : un échec de suppression ne doit pas faire
      // rater un envoi réussi.
      try {
        if (await audioFile.exists()) await audioFile.delete();
      } catch (_) {}

      return MessageModel.fromJson({
        ...msgData,
        ..._annexesEnClair(replyToMessageData: replyToMessageData),
        'fileName': fileName,
        if (mediaChiffre != null) _kChampMediaChiffre: mediaChiffre,
        'id': msgId,
        'senderId': senderId,
        'type': 'voiceNote',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendAudioMessage error: $e');
    }
  }

  /// Type MIME d'un enregistrement, d'après son extension.
  static String _audioMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      case '.wav':
        return 'audio/wav';
      case '.webm':
        return 'audio/webm';
      default:
        return 'audio/mp4';
    }
  }

  @override
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
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final annexes = await _annexesChiffreesPour(
        conversationId,
        replyToMessageData: replyToMessageData,
      );

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': address.isNotEmpty ? address : 'Position partagée',
        'status': 'sent',
        'latitude': latitude,
        'longitude': longitude,
        'locationAddress': address,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        ...annexes,
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: 'location',
        createdAt: now,
        data: msgData,
      );

      await _updateConversationLastMessage(
        conversationId,
        text: '📍 Position partagée',
        senderId: senderId,
        type: 'location',
        messageId: msgId,
      );

      return MessageModel.fromJson({
        ...msgData,
        ..._annexesEnClair(replyToMessageData: replyToMessageData),
        'id': msgId,
        'senderId': senderId,
        'type': 'location',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendLocationMessage error: $e');
    }
  }

  @override
  Future<MessageModel> sendPollMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String pollId,
    required String question,
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': question,
        'status': 'sent',
        'pollId': pollId,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: 'poll',
        createdAt: now,
        data: msgData,
      );

      await _updateConversationLastMessage(
        conversationId,
        text: '📊 $question',
        senderId: senderId,
        type: 'poll',
        messageId: msgId,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': senderId,
        'type': 'poll',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendPollMessage error: $e');
    }
  }

  @override
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
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final annexes = await _annexesChiffreesPour(
        conversationId,
        replyToMessageData: replyToMessageData,
      );

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': 'Sticker',
        'status': 'sent',
        'fileUrl': stickerUrl,
        'stickerPackId': stickerPackId,
        'stickerId': stickerId,
        'isAnimatedSticker': isAnimated,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        ...annexes,
      };

      await _insererMessageUtilisateur(
        id: msgId,
        conversationId: conversationId,
        senderId: senderId,
        type: 'sticker',
        createdAt: now,
        data: msgData,
      );

      await _updateConversationLastMessage(
        conversationId,
        text: '🎭 Sticker',
        senderId: senderId,
        type: 'sticker',
        messageId: msgId,
      );

      return MessageModel.fromJson({
        ...msgData,
        ..._annexesEnClair(replyToMessageData: replyToMessageData),
        'id': msgId,
        'senderId': senderId,
        'type': 'sticker',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendStickerMessage error: $e');
    }
  }

  /// ⚠️ **Ne réussit jamais depuis le client.** La policy `messages_insert`
  /// exige `firebase_uid() = sender_id`, et aucun compte ne s'appelle
  /// `system` ; une conversation basculée en MLS refuse même avant, par
  /// déclencheur. Appelée en tête de `removeUserFromGroup`, elle y a empêché
  /// toute exclusion (voir ce commentaire-là). Ne pas la mettre sur le chemin
  /// d'une action : un message système doit être écrit côté serveur.
  @override
  Future<MessageModel> sendSystemMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': 'Système',
        'content': content,
        'status': 'sent',
        'readBy': <String>[],
        'readAt': <String, dynamic>{},
        'encryptionLevel': 'aes',
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': 'system',
        'type': 'system',
        'created_at': now,
        'data': msgData,
      });

      await _updateConversationLastMessage(
        conversationId,
        text: content,
        senderId: 'system',
        type: 'system',
        messageId: msgId,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': 'system',
        'type': 'system',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendSystemMessage error: $e');
    }
  }

  @override
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
  }) async {
    throw UnimplementedError(
      'sendFileMessage: upload via Firebase Storage then call sendMediaMessage.',
    );
  }

  @override
  UploadTask uploadMediaFile({
    required File file,
    required String conversationId,
    required String fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'messages/$conversationId/${timestamp}_$fileName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    return ref.putFile(file);
  }
}
