part of 'message_repository_impl.dart';

/// Envoi des messages : texte, fichiers (chiffrés ou non), audio, position,
/// sondage, sticker.
mixin _Envoi on _MessageRepositoryBase, _Mls {
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      // Envoi chiffré de bout en bout, quand cette conversation est passée à
      // MLS (ou que le drapeau vient de l'y faire passer). Une conversation
      // DÉJÀ basculée n'a pas de chemin de retour : si MLS échoue, l'envoi
      // échoue — c'est le repli muet qui a laissé Signal envoyer en clair
      // pendant des semaines. Avant la bascule, rien n'est engagé : on peut
      // encore emprunter le chemin d'aujourd'hui, et ça se lit en base.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        final envoye = await _tenterEnvoiMls(
          passerelle,
          conversationId,
          () => passerelle.envoyerTexte(
            conversationId: conversationId,
            texte: content,
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            replyToId: replyToId,
            replyToMessageData: replyToMessageData,
          ),
        );
        if (envoye != null) return envoye;
      }

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

      // Le texte clair de NOS messages n'existe que localement : le serveur ne
      // saura jamais nous le rendre — Signal comme Sender Key font avancer le
      // ratchet à l'émission sans garder la clé du message envoyé. On le met en
      // cache tout de suite, sinon l'écho temps réel (qui arrive, lui, avec le
      // placeholder) devient la seule version persistée, et le message
      // redevient illisible à la réouverture de la discussion.
      unawaited(
        cacheService.cacheMessages(conversationId, [message.toJson()]),
      );

      return Right(message.toEntity());
    } on E2EEException catch (e) {
      return Left(E2EEFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
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
    bool isForwarded = false,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final fileName = file.path.split('/').last;

      // C4 : pièces jointes chiffrées — images, documents, audio. Pas la
      // vidéo, qui attend un déchiffrement par morceaux
      // (CHIFFREMENT_MEDIAS_PLAN.md). Le blob part sur Storage, la clé
      // voyage dans le message, scellée par le datasource.
      // Dans une conversation passée à MLS, un média **doit** être chiffré,
      // que le drapeau des pièces jointes soit ouvert ou non : le serveur
      // refuse désormais d'y écrire en clair, et l'envoi échouerait sans
      // cause lisible. Le drapeau ne décide donc que des conversations
      // encore en clair.
      final chiffrement = mediaEncryptionService;
      final conversationChiffree = await _passerellePour(conversationId) != null;
      // La video n'est plus ecartee. Elle l'etait pour une raison precise et
      // desormais levee : le chiffrement passait par la memoire, avec un pic
      // proche de trois fois la taille du fichier, et le telechargement
      // plafonnait a 10 Mo. Les deux sens vont maintenant d'un fichier vers
      // un autre, un morceau a la fois.
      if (chiffrement != null &&
          (mediasChiffresActifs() || conversationChiffree)) {
        return _envoyerMediaChiffre(
          chiffrement,
          conversationId: conversationId,
          senderId: senderId,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
          file: file,
          type: type,
          caption: caption,
          onProgress: onProgress,
          checkCancelled: checkCancelled,
          replyToId: replyToId,
          replyToMessageData: replyToMessageData,
          isForwarded: isForwarded,
        );
      }

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
            unawaited(uploadTask.cancel());
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

        // Extract video duration for the VideoBubble duration badge.
        int? videoDuration;
        if (type == MessageType.video) {
          videoDuration = await _getVideoDurationSeconds(file.path);
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
          videoDuration: videoDuration,
          audioDuration: audioDuration,
          isForwarded: isForwarded,
        );
        return Right(message.toEntity());
      });
    });
  }

  /// Envoi d'une pièce jointe chiffrée (C4, tranche 1).
  ///
  /// Un échec de scellement de la clé fait échouer l'envoi avec un message
  /// lisible — jamais de repli en clair : ce serait annuler tout le bénéfice
  /// sans le dire.
  Future<Either<Failure, MessageEntity>> _envoyerMediaChiffre(
    MediaEncryptionService chiffrement, {
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
    bool isForwarded = false,
  }) async {
    final resultat = await chiffrement.encryptAndUploadFile(
      file: file,
      conversationId: conversationId,
      senderId: senderId,
      mediaType: switch (type) {
        MessageType.image => MediaType.image,
        MessageType.audio => MediaType.audio,
        MessageType.video => MediaType.video,
        _ => MediaType.document,
      },
      onProgress: onProgress,
      checkCancelled: checkCancelled,
    );
    if (checkCancelled?.call() == true) {
      return const Left(ServerFailure('Envoi annulé'));
    }

    // Vignette et duree se calculent sur le fichier EN CLAIR, avant qu'il ne
    // parte chiffre. Sans elles, une video chiffree arriverait sans apercu ni
    // badge de duree, et se lirait comme un defaut d'affichage.
    String? blurhash;
    if (type == MessageType.image) {
      blurhash = await blurhashService.generateFromImage(file);
    } else if (type == MessageType.video) {
      blurhash = await blurhashService.generateFromVideo(file);
    }
    int? audioDuration;
    if (type == MessageType.audio) {
      audioDuration = await AudioPlaybackService.getDurationFromFile(file.path);
    }
    int? videoDuration;
    if (type == MessageType.video) {
      videoDuration = await _getVideoDurationSeconds(file.path);
    }
    final dbType = type == MessageType.audio ? 'audioFile' : type.name;

    final media = MediaChiffre(
      storagePath: resultat.storagePath,
      encryptedUrl: resultat.encryptedUrl,
      fileKeyBase64: resultat.fileKeyBase64,
      ivBase64: resultat.ivBase64,
      fileName: resultat.originalFileName,
      mimeType: resultat.mimeType,
      size: resultat.originalSize,
    );

    // Conversation chiffrée : la clé du fichier entre dans le payload MLS
    // (plan § 9) au lieu du blob `encAnnexes`, que le serveur sait ouvrir
    // puisqu'il détient la racine dont la clé de conversation est dérivée.
    // C'est ce qui achève le chiffrement des pièces jointes commencé en C4.
    final passerelle = await _passerellePour(conversationId);
    if (passerelle != null) {
      final envoye = await _tenterEnvoiMls(
        passerelle,
        conversationId,
        () => passerelle.envoyer(
          conversationId: conversationId,
          type: dbType == 'audioFile' ? 'audio' : dbType,
          body: MlsGateway.corpsMedia(
            legende: caption,
            storagePath: resultat.storagePath,
            fileName: resultat.originalFileName,
            mimeType: resultat.mimeType,
            fileSize: resultat.originalSize,
            fileKey: resultat.fileKeyBase64,
            fileNonce: resultat.ivBase64,
            blurhash: blurhash,
            duration: audioDuration,
            dureeVideo: videoDuration,
          ),
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
          replyToId: replyToId,
          replyToMessageData: replyToMessageData,
          forwarded: isForwarded,
        ),
      );
      if (envoye != null) return envoye;
    }

    final message = await remoteDataSource.sendMediaMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      fileUrl: resultat.encryptedUrl,
      fileName: resultat.originalFileName,
      fileSize: resultat.originalSize,
      mimeType: resultat.mimeType,
      type: dbType,
      caption: caption,
      replyToId: replyToId,
      replyToMessageData: replyToMessageData,
      blurhash: blurhash,
      audioDuration: audioDuration,
      videoDuration: videoDuration,
      mediaChiffre: media.toJson(),
      isForwarded: isForwarded,
    );
    return Right(message.toEntity());
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      // C4 : note vocale chiffrée avant le téléversement.
      //
      // **Le drapeau ne décide que des conversations encore en clair.** Dans
      // une conversation basculée il faut chiffrer QUOI QU'IL ARRIVE : le
      // corps de la note doit entrer dans le payload MLS, faute de quoi
      // l'envoi retombe sur `messages`, que le déclencheur
      // `messages_refuse_conversation_mls_trg` refuse — et l'écran affiche
      // « Non envoyé · Réessayer » sans jamais dire pourquoi.
      //
      // `sendFileMessage` applique cette règle depuis toujours (images,
      // documents, vidéo) ; la note vocale avait été oubliée. Mesuré sur
      // SM A515F le 2026-09-15 dans le groupe « Testeurs » : la note vocale
      // n'arrivait NULLE PART — ni `mls_messages`, ni `messages`.
      Map<String, dynamic>? mediaChiffre;
      final chiffrement = mediaEncryptionService;
      final conversationChiffree =
          await _passerellePour(conversationId) != null;
      if (chiffrement != null &&
          (mediasChiffresActifs() || conversationChiffree)) {
        final r = await chiffrement.encryptAndUploadFile(
          file: audioFile,
          conversationId: conversationId,
          senderId: senderId,
          mediaType: MediaType.voiceNote,
        );
        mediaChiffre = MediaChiffre(
          storagePath: r.storagePath,
          encryptedUrl: r.encryptedUrl,
          fileKeyBase64: r.fileKeyBase64,
          ivBase64: r.ivBase64,
          fileName: r.originalFileName,
          mimeType: r.mimeType,
          size: r.originalSize,
        ).toJson();
      }

      // Conversation chiffrée : le corps de la note vocale (clé du fichier,
      // durée, forme d'onde) entre dans le payload MLS. Sans ce branchement,
      // l'envoi partirait vers `messages`, que le serveur refuse pour une
      // conversation basculée — et l'utilisateur verrait un échec sans cause.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null && mediaChiffre != null) {
        final envoye = await _tenterEnvoiMls(
          passerelle,
          conversationId,
          () => passerelle.envoyer(
            conversationId: conversationId,
            type: 'voiceNote',
            body: MlsGateway.corpsMedia(
              storagePath: mediaChiffre!['storagePath'] as String? ?? '',
              fileName: mediaChiffre['fileName'] as String? ?? '',
              mimeType: mediaChiffre['mimeType'] as String? ?? 'audio/mp4',
              fileSize: (mediaChiffre['size'] as num?)?.toInt() ?? 0,
              fileKey: mediaChiffre['fileKey'] as String?,
              fileNonce: mediaChiffre['iv'] as String?,
              duration: duration,
              waveform: waveform,
            ),
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            replyToId: replyToId,
            replyToMessageData: replyToMessageData,
            forwarded: isForwarded,
          ),
        );
        if (envoye != null) return envoye;
      }

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
        mediaChiffre: mediaChiffre,
      );
      return Right(message.toEntity());
    });
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      // La position est une donnée sensible que le legacy écrivait en clair
      // (latitude, longitude et adresse, relevés en production le
      // 2026-09-14) : elle entre ici dans le payload chiffré.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        final envoye = await _tenterEnvoiMls(
          passerelle,
          conversationId,
          () => passerelle.envoyer(
            conversationId: conversationId,
            type: 'location',
            body: {
              'latitude': latitude,
              'longitude': longitude,
              'address': address,
            },
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            replyToId: replyToId,
            replyToMessageData: replyToMessageData,
          ),
        );
        if (envoye != null) return envoye;
      }

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
    });
  }

  @override
  Future<Either<Failure, MessageEntity>> sendPollMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String pollId,
    required String question,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      // Le sondage vit en Postgres et le restera : voter demande un arbitre,
      // et l'anonymat des votants est une garantie serveur (plan § 6.3). Le
      // message ne porte donc que son identifiant et sa question — cette
      // dernière étant chiffrée ici, alors qu'elle partait en clair.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        final envoye = await _tenterEnvoiMls(
          passerelle,
          conversationId,
          () => passerelle.envoyer(
            conversationId: conversationId,
            type: 'poll',
            body: {'pollId': pollId, 'content': question},
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
          ),
        );
        if (envoye != null) return envoye;
      }

      final message = await remoteDataSource.sendPollMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        pollId: pollId,
        question: question,
      );
      return Right(message.toEntity());
    });
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        final envoye = await _tenterEnvoiMls(
          passerelle,
          conversationId,
          () => passerelle.envoyer(
            conversationId: conversationId,
            type: 'sticker',
            body: {
              'stickerPackId': stickerPackId,
              'stickerId': stickerId,
              // L'URL du sticker reste une requête réseau visible du
              // fournisseur ; c'est une limite connue, pas une fuite de ce
              // dépôt (plan § 6.3).
              'stickerUrl': stickerUrl,
              'isAnimated': isAnimated,
            },
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            replyToId: replyToId,
            replyToMessageData: replyToMessageData,
          ),
        );
        if (envoye != null) return envoye;
      }

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
    });
  }
}
