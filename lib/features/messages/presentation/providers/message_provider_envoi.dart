part of 'message_provider.dart';

// Envoi et transfert des messages : SendMessageNotifier.

/// Une copie EN CLAIR du média de [m], sous son nom d'origine, prête à
/// repartir — ou `null` s'il n'y a plus rien à copier.
///
/// Sources, dans l'ordre : le fichier local d'un envoi (`localFilePath`), le
/// média chiffré déchiffré par le cache, un `file://`, un téléchargement.
/// La copie vit dans un dossier temporaire à elle : son nom est celui que
/// le destinataire verra (le cache de déchiffrement nomme ses fichiers
/// d'après l'identifiant du message), nettoyé par [nomDeFichierSur].
Future<File?> fichierEnClairPourTransfert(Ref ref, MessageEntity m) async {
  try {
    File? source;
    final local = m.localFilePath;
    final url = m.fileUrl;
    final media = m.mediaChiffre;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      source = File(local);
    } else if (media != null) {
      final chemin = await ref.read(
        mediaDechiffreProvider(DemandeMediaDechiffre(m.id, media)).future,
      );
      source = File(chemin);
    } else if (url != null && estUrlLocale(url)) {
      source = File(cheminDepuisUrlLocale(url));
    }

    final base = await getTemporaryDirectory();
    final dossier = await Directory(
      '${base.path}/transferts/${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    if (source == null) {
      if (url == null || !(url.startsWith('http://') || url.startsWith('https://'))) {
        return null;
      }
      final nom = nomDeFichierSur(m.fileName, repli: m.id);
      final chemin = '${dossier.path}/$nom';
      await Dio().download(url, chemin);
      return File(chemin);
    }
    if (!source.existsSync()) return null;
    final nom = nomDeFichierSur(
      m.fileName,
      repli: source.uri.pathSegments.last,
    );
    return await source.copy('${dossier.path}/$nom');
  } catch (e) {
    debugPrint('transfert : copie du média impossible ($e)');
    return null;
  }
}

/// Une pièce jointe dont l'envoi a échoué : posée en bulle d'échec si la
/// discussion est ouverte, et mise de côté pour « Renvoyer », le renvoi
/// automatique et le prochain lancement.
///
/// L'entité porte le fichier local deux fois : `fileUrl = file://…`, la forme
/// que toutes les bulles média savent afficher, et `localFilePath`, d'où
/// `retryFailedMessage` le renverra.
Future<void> pieceJointeEnEchec(
  Ref ref,
  String conversationId,
  MessageEntity echec, {
  DateTime? ecritLe,
}) async {
  final ecran = paginatedMessagesProvider(conversationId);
  if (ref.exists(ecran)) {
    ref.read(ecran.notifier).addOptimisticMessage(echec);
  }
  await signalerEnvoiEnEchec(ref, conversationId, echec, ecritLe: ecritLe);
}

final sendMessageProvider = StateNotifierProvider<SendMessageNotifier, AsyncValue<void>>(
  (ref) => SendMessageNotifier(ref),
);

const _uuid = Uuid();

class SendMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SendMessageNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> sendText({
    required String conversationId,
    required String content,
    String? optimisticMessageId,
    String? clientMessageId,
    int attempt = 1,
    int maxAttempts = 3,
    MessageEntity? replyToMessage,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<MentionedUser> mentionedUsers = const [],
    DateTime? ecritLe,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    final senderProfile = _ref.read(userStreamProvider(currentUser.id)).valueOrNull;
    final senderIsVerified = senderProfile?.isPhoneVerified ?? false;

    // Verifier la connectivite
    final isOnline = _ref.read(connectivityNotifierProvider);

    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    // Mode offline: ajouter a la queue et afficher message optimiste
    if (!isOnline && attempt == 1) {
      // Un seul identifiant pour la copie affichée ET l'entrée de file.
      // Ils divergeaient (`pending_<uuid>` d'un côté, `<uuid>` de l'autre) :
      // la réinjection au chargement recréait donc un doublon, et le retrait
      // après envoi ne trouvait jamais son entrée.
      final id = 'pending_${_uuid.v4()}';

      final optimisticMessage = MessageEntity(
        id: id,
        // Hors ligne aussi : un message mis en file dans une conversation à
        // minuteur est éphémère comme les autres, et doit le montrer.
        expiresAt: _echeanceOptimiste(_ref, conversationId),
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? 'Utilisateur',
        senderPhotoUrl: currentUser.photoUrl,
        content: content,
        type: MessageType.text,
        status: MessageStatus.sending, // Sera affiche comme "En attente"
        createdAt: DateTime.now(),
        readBy: [],
        readAt: {},
        replyToId: replyToMessage?.id,
        replyToMessageData: replyToMessageData,
        productData: productData,
        postData: postData,
        eventData: eventData,
        sentWhileBlockedBy: sentWhileBlockedBy,
      );

      // `messageJson` transporte le message entier : la réponse citée et les
      // cartes ci-dessus étaient purement et simplement perdues par les champs
      // plats de `PendingMessage`, qui codaient même le type « text » en dur.
      await _ref.read(offlineQueueServiceProvider).enqueue(
            PendingMessage(
              id: id,
              conversationId: conversationId,
              senderId: currentUser.id,
              senderName: currentUser.displayName ?? 'Utilisateur',
              senderPhotoUrl: currentUser.photoUrl,
              content: content,
              type: MessageType.text.name,
              createdAt: ecritLe ?? optimisticMessage.createdAt,
              messageJson: jsonEncode(
                MessageModel.fromEntity(optimisticMessage).toJson(),
              ),
            ),
          );

      _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);
      return true; // Retourner true car le message est en queue
    }

    if (linkPreviewData == null && attempt == 1 && !isForwarded) {
      final url = LinkPreviewService.extractFirstUrl(content);
      if (url != null) {
        try {
          final preview = await _ref.read(linkPreviewServiceProvider).fetchLinkPreview(url);
          if (preview != null && preview.hasContent) {
            linkPreviewData = preview.toMap();
          }
        } catch (_) {}
      }
    }

    final tempId = optimisticMessageId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    // Generate once on first attempt; preserve across retries for stable matching.
    final cid = clientMessageId ?? _uuid.v4();

    final optimisticMessage = MessageEntity(
      id: tempId,
      expiresAt: _echeanceOptimiste(_ref, conversationId),
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      senderIsVerified: senderIsVerified,
      content: content,
      type: MessageType.text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      productData: productData,
      postData: postData,
      eventData: eventData,
      sentWhileBlockedBy: sentWhileBlockedBy,
      linkPreviewData: linkPreviewData,
      isForwarded: isForwarded,
      mentionedUsers: mentionedUsers,
      clientMessageId: cid,
    );

    if (attempt == 1) {
      _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);
    }

    // Resolve E2EE target on every attempt so retries don't lose the recipient.
    String? recipientId;
    List<String> participantIds = const [];
    bool selfNote = false;
    final conversation = _ref.read(conversationStreamProvider(conversationId)).valueOrNull;
    if (conversation != null) {
      if (conversation.isSelfNotesFor(currentUser.id)) {
        // « Mes notes » : pas de destinataire → chiffrement AES au repos.
        selfNote = true;
      } else if (conversation.isIndividual) {
        recipientId = conversation.getOtherParticipantId(currentUser.id);
      } else {
        participantIds = conversation.participantIds
            .where((id) => id != currentUser.id)
            .toList();
        // Un groupe dont on est le seul membre — celui qu'on vient de créer,
        // avant d'inviter qui que ce soit — laissait cette liste VIDE. La
        // garde « Destinataire manquant » du datasource refusait alors tout
        // envoi : chaque message repartait en « Non envoyé · Réessayer », sans
        // un mot sur la cause, sous un état vide qui invite pourtant à
        // « Soyez le premier à envoyer un message dans ce groupe ! ».
        // Vérifié sur Pixel 10 Pro XL et SM A515F le 2026-09-09.
        //
        // Se remettre soi-même dans la liste suffit : `encryptGroup` chiffre
        // avec NOTRE Sender Key, et `distributeSenderKeyToGroup` écarte déjà
        // l'expéditeur de ses destinataires — la distribution ne vise donc
        // personne, sans rien casser.
        if (participantIds.isEmpty) {
          participantIds = [currentUser.id];
        }
      }
    }

    final result = await _ref.read(messageRepositoryProvider).sendTextMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      senderIsVerified: senderIsVerified,
      content: content,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      productData: productData,
      postData: postData,
      eventData: eventData,
      sentWhileBlockedBy: sentWhileBlockedBy,
      linkPreviewData: linkPreviewData,
      isForwarded: isForwarded,
      mentionedUsers: mentionedUsers,
      clientMessageId: cid,
      recipientId: recipientId,
      participantIds: participantIds,
      selfNote: selfNote,
    );

    return result.fold(
      (failure) async {
        // Sans cette trace, un échec d'envoi ne laisse qu'un triangle rouge à
        // l'écran et rien dans les logs — indiagnosticable sur appareil.
        debugPrint(
          'sendText FAILED (selfNote=$selfNote, recipientId=$recipientId, '
          'participants=${participantIds.length}, conv=${conversation != null}) '
          ': ${failure.message}',
        );
        if (attempt < maxAttempts && failure is! E2EEFailure) {
          await Future.delayed(Duration(seconds: attempt * 2));
          return await sendText(
            conversationId: conversationId,
            content: content,
            optimisticMessageId: tempId,
            clientMessageId: cid,
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
            replyToMessage: replyToMessage,
            productData: productData,
            postData: postData,
            eventData: eventData,
            sentWhileBlockedBy: sentWhileBlockedBy,
            linkPreviewData: linkPreviewData,
            isForwarded: isForwarded,
            mentionedUsers: mentionedUsers,
            ecritLe: ecritLe,
          );
        }

        unawaited(signalerEnvoiEnEchec(_ref, conversationId, optimisticMessage,
            ecritLe: ecritLe));
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  /// Renvoie un message dont l'envoi a échoué.
  ///
  /// La bulle en échec n'est retirée QUE sur un chemin qui sait effectivement
  /// renvoyer, et juste avant de le faire. Auparavant le retrait était en tête
  /// de méthode, avant même le `switch` : pour un média, la branche retournait
  /// `false` sans rien renvoyer, et le message avait déjà disparu de l'écran.
  /// Taper « réessayer » était donc le moyen le plus sûr de perdre le message.
  Future<bool> retryFailedMessage({
    required String conversationId,
    required MessageEntity failedMessage,
    /// Date d'écriture d'origine, pour le renvoi automatique : voir
    /// [mettreDeCoteEnEchec]. Absente pour un renvoi à la main, qui est une
    /// intention neuve.
    DateTime? ecritLe,
  }) async {
    final pagination =
        _ref.read(paginatedMessagesProvider(conversationId).notifier);

    MessageEntity? replyToMessage;
    if (failedMessage.replyToId != null && failedMessage.replyToMessageData != null) {
      final replyData = failedMessage.replyToMessageData!;
      replyToMessage = MessageEntity(
        id: replyData['id'] as String? ?? '',
        senderId: replyData['senderId'] as String? ?? '',
        senderName: replyData['senderName'] as String? ?? '',
        content: replyData['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (t) => t.name == (replyData['type'] as String? ?? 'text'),
          orElse: () => MessageType.text,
        ),
        createdAt: DateTime.now(),
        readBy: [],
        readAt: {},
        fileUrl: replyData['fileUrl'] as String?,
        fileName: replyData['fileName'] as String?,
      );
    }

    switch (failedMessage.type) {
      case MessageType.text:
        pagination.removeMessageOptimistically(failedMessage.id);
        return sendText(
          conversationId: conversationId,
          content: failedMessage.content,
          replyToMessage: replyToMessage,
          productData: failedMessage.productData,
          eventData: failedMessage.eventData,
          ecritLe: ecritLe,
        );
      case MessageType.voiceNote:
        // Le fichier enregistré est encore là tant que l'envoi n'a pas abouti :
        // sendAudioMessage ne le supprime qu'après un téléversement réussi.
        final path = failedMessage.localFilePath;
        if (path != null && File(path).existsSync()) {
          pagination.removeMessageOptimistically(failedMessage.id);
          return sendAudio(
            conversationId: conversationId,
            audioFile: File(path),
            duration: failedMessage.audioDuration ?? 0,
            waveform: failedMessage.audioWaveform ?? const [],
            replyToMessage: replyToMessage,
            ecritLe: ecritLe,
          );
        }
        // Plus de fichier local (message d'une session précédente) : on garde
        // la bulle, elle est tout ce qui reste de ce message.
        state = AsyncValue.error(
          "Impossible de renvoyer ce message vocal : l'enregistrement n'est "
          'plus disponible.',
          StackTrace.current,
        );
        return false;
      // Pièces jointes : repartent de leur fichier local, mis de côté par
      // `_pieceJointeEnEchec`. Elles étaient refusées ici — et comme rien ne
      // les mettait de côté non plus, une pièce jointe ratée disparaissait.
      case MessageType.image:
      case MessageType.file:
      case MessageType.video:
      case MessageType.audio:
        final chemin = failedMessage.localFilePath;
        if (chemin != null && File(chemin).existsSync()) {
          pagination.removeMessageOptimistically(failedMessage.id);
          final legende = failedMessage.content;
          return sendFile(
            conversationId: conversationId,
            file: File(chemin),
            type: failedMessage.type,
            caption: legende.isEmpty ? null : legende,
            replyToMessage: replyToMessage,
            isForwarded: failedMessage.isForwarded,
            ecritLe: ecritLe,
          );
        }
        state = AsyncValue.error(
          "Impossible de renvoyer ce média : le fichier n'est plus disponible "
          'sur cet appareil.',
          StackTrace.current,
        );
        return false;
      case MessageType.location:
        if (failedMessage.latitude != null && failedMessage.longitude != null) {
          pagination.removeMessageOptimistically(failedMessage.id);
          return sendLocation(
            conversationId: conversationId,
            latitude: failedMessage.latitude!,
            longitude: failedMessage.longitude!,
            address: failedMessage.locationAddress ?? '',
            replyToMessage: replyToMessage,
            ecritLe: ecritLe,
          );
        }
        return false;
      case MessageType.system:
      case MessageType.call:
        return false;
      case MessageType.poll:
        // Le sondage lui-meme est deja en base : seule la bulle a echoue,
        // il suffit donc de la republier avec le meme id.
        if (failedMessage.pollId != null) {
          pagination.removeMessageOptimistically(failedMessage.id);
          return sendPoll(
            conversationId: conversationId,
            pollId: failedMessage.pollId!,
            question: failedMessage.content,
            ecritLe: ecritLe,
          );
        }
        return false;
      case MessageType.sticker:
        if (failedMessage.stickerPackId != null && failedMessage.stickerId != null && failedMessage.fileUrl != null) {
          pagination.removeMessageOptimistically(failedMessage.id);
          return sendSticker(
            conversationId: conversationId,
            stickerPackId: failedMessage.stickerPackId!,
            stickerId: failedMessage.stickerId!,
            stickerUrl: failedMessage.fileUrl!,
            isAnimated: failedMessage.isAnimatedSticker,
            replyToMessage: replyToMessage,
            ecritLe: ecritLe,
          );
        }
        return false;
    }
  }

  Future<bool> sendFile({
    required String conversationId,
    required File file,
    required MessageType type,
    String? caption,
    MessageEntity? replyToMessage,
    bool isForwarded = false,
    DateTime? ecritLe,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    final uploadNotifier = _ref.read(mediaUploadProvider.notifier);
    uploadNotifier.startUpload(
      file: file,
      conversationId: conversationId,
      type: type,
      caption: caption,
    );

    final result = await _ref.read(messageRepositoryProvider).sendFileMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      file: file,
      type: type,
      caption: caption,
      onProgress: (progress) {
        uploadNotifier.updateProgress(progress);
      },
      checkCancelled: () {
        return _ref.read(mediaUploadProvider).status == MediaUploadStatus.cancelled;
      },
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      isForwarded: isForwarded,
    );

    return result.fold(
      (failure) {
        if (failure.message == 'Envoi annulé') {
          uploadNotifier.cancel();
        } else {
          uploadNotifier.markError(failure.message);
          state = AsyncValue.error(failure.message, StackTrace.current);
          // Annulé : c'est un choix. Raté : la bulle de progression
          // disparaît, et rien ne la remplaçait — ni bulle en échec, ni
          // « Renvoyer », ni file d'attente. La pièce jointe était perdue.
          unawaited(pieceJointeEnEchec(
            _ref,
            conversationId,
            MessageEntity(
              id: 'temp_file_${DateTime.now().microsecondsSinceEpoch}',
              senderId: currentUser.id,
              senderName: currentUser.displayName ?? 'Utilisateur',
              senderPhotoUrl: currentUser.photoUrl,
              content: caption ?? '',
              type: type,
              status: MessageStatus.failed,
              createdAt: DateTime.now(),
              readBy: const [],
              readAt: const {},
              fileUrl: 'file://${file.path}',
              localFilePath: file.path,
              fileName: file.uri.pathSegments.last,
              replyToId: replyToMessage?.id,
              replyToMessageData: replyToMessageData,
              isForwarded: isForwarded,
            ),
            ecritLe: ecritLe,
          ));
        }
        return false;
      },
      (message) {
        uploadNotifier.markSuccess();
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendAudio({
    required String conversationId,
    required File audioFile,
    required int duration,
    required List<double> waveform,
    MessageEntity? replyToMessage,
    DateTime? ecritLe,
    bool isForwarded = false,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    final tempId = 'temp_audio_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      expiresAt: _echeanceOptimiste(_ref, conversationId),
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: '',
      type: MessageType.voiceNote,
      status: MessageStatus.sending,
      // Retenu pour le renvoi : sans le chemin du fichier, un vocal en échec
      // n'avait plus rien à téléverser (cf. retryFailedMessage).
      localFilePath: audioFile.path,
      audioDuration: duration,
      audioWaveform: waveform,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendAudioMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      audioFile: audioFile,
      duration: duration,
      waveform: waveform,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      isForwarded: isForwarded,
    );

    return result.fold(
      (failure) {
        unawaited(signalerEnvoiEnEchec(_ref, conversationId, optimisticMessage,
            ecritLe: ecritLe));
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendLocation({
    required String conversationId,
    required double latitude,
    required double longitude,
    required String address,
    MessageEntity? replyToMessage,
    DateTime? ecritLe,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    final tempId = 'temp_location_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      expiresAt: _echeanceOptimiste(_ref, conversationId),
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: address.isNotEmpty ? address : 'Position partagée',
      type: MessageType.location,
      status: MessageStatus.sending,
      latitude: latitude,
      longitude: longitude,
      locationAddress: address,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    debugPrint('📍 sendLocation: Adding optimistic message tempId=$tempId');
    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendLocationMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    return result.fold(
      (failure) {
        debugPrint('❌ sendLocation: Failed - ${failure.message}');
        unawaited(signalerEnvoiEnEchec(_ref, conversationId, optimisticMessage,
            ecritLe: ecritLe));
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        // Pas de coordonnées ici : `debugPrint` écrit aussi en release (logcat).
        debugPrint('✅ sendLocation: Success - real message id=${message.id}');
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  /// Publie un sondage deja cree (post_polls) comme bulle de la conversation.
  ///
  /// La bulle ne porte que l'id : `PollCard` lit options et votes en direct,
  /// donc le message n'a jamais a etre reecrit quand quelqu'un vote.
  Future<bool> sendPoll({
    required String conversationId,
    required String pollId,
    required String question,
    DateTime? ecritLe,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    final tempId = 'temp_poll_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      expiresAt: _echeanceOptimiste(_ref, conversationId),
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: question,
      type: MessageType.poll,
      status: MessageStatus.sending,
      pollId: pollId,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
    );

    _ref
        .read(paginatedMessagesProvider(conversationId).notifier)
        .addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendPollMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          senderName: currentUser.displayName ?? 'Utilisateur',
          senderPhotoUrl: currentUser.photoUrl,
          pollId: pollId,
          question: question,
        );

    return result.fold(
      (failure) {
        unawaited(signalerEnvoiEnEchec(_ref, conversationId, optimisticMessage,
            ecritLe: ecritLe));
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        _ref
            .read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(
              tempId,
              MessageStatus.sent,
              message.id,
            );
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendSticker({
    required String conversationId,
    required String stickerPackId,
    required String stickerId,
    required String stickerUrl,
    bool isAnimated = false,
    MessageEntity? replyToMessage,
    DateTime? ecritLe,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    final tempId = 'temp_sticker_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      expiresAt: _echeanceOptimiste(_ref, conversationId),
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: 'Sticker',
      type: MessageType.sticker,
      status: MessageStatus.sending,
      fileUrl: stickerUrl,
      stickerPackId: stickerPackId,
      stickerId: stickerId,
      isAnimatedSticker: isAnimated,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    debugPrint('🎭 sendSticker: Adding optimistic message with packId=$stickerPackId, stickerId=$stickerId, tempId=$tempId');
    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendStickerMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      stickerPackId: stickerPackId,
      stickerId: stickerId,
      stickerUrl: stickerUrl,
      isAnimated: isAnimated,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    return result.fold(
      (failure) {
        debugPrint('❌ sendSticker: Failed - ${failure.message}');
        unawaited(signalerEnvoiEnEchec(_ref, conversationId, optimisticMessage,
            ecritLe: ecritLe));
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        debugPrint('✅ sendSticker: Success - real message id=${message.id}');
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> forwardMessage({
    required String targetConversationId,
    required MessageEntity originalMessage,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    switch (originalMessage.type) {
      case MessageType.text:
        return sendText(
          conversationId: targetConversationId,
          content: originalMessage.content,
          linkPreviewData: originalMessage.linkPreviewData,
          isForwarded: true,
        );

      // Un média transféré repart par le chemin d'envoi normal, à partir
      // d'une copie EN CLAIR sur l'appareil. Il recopiait l'URL dans une
      // ligne legacy écrite directement par la source de données : un média
      // chiffré partait donc sans sa clé (blob illisible chez le
      // destinataire), et vers une conversation basculée en MLS, le serveur
      // refusait l'écriture. Ré-émis ici, il est chiffré et routé selon la
      // conversation CIBLE, comme s'il venait d'être choisi.
      case MessageType.image:
      case MessageType.video:
      case MessageType.file:
      case MessageType.audio:
      case MessageType.voiceNote:
        final copie = await fichierEnClairPourTransfert(_ref, originalMessage);
        if (copie == null) {
          state = AsyncValue.error(
            'Ce média n\'est plus disponible : impossible de le transférer.',
            StackTrace.current,
          );
          return false;
        }
        if (originalMessage.type == MessageType.voiceNote) {
          // Pas d'effacement de la copie : c'est elle que le renvoi relira
          // en cas d'échec, et l'envoi la retire lui-même une fois parti.
          return sendAudio(
            conversationId: targetConversationId,
            audioFile: copie,
            duration: originalMessage.audioDuration ?? 0,
            waveform: originalMessage.audioWaveform ?? const [],
            isForwarded: true,
          );
        }
        final legende = originalMessage.content;
        final parti = await sendFile(
          conversationId: targetConversationId,
          file: copie,
          type: originalMessage.type,
          caption: legende.isNotEmpty &&
                  legende != originalMessage.fileName &&
                  legende != originalMessage.fileUrl
              ? legende
              : null,
          isForwarded: true,
        );
        // Une copie en clair n'a rien à faire sur le disque une fois chiffrée
        // et partie. Ratée, elle reste : c'est d'elle que le renvoi repartira.
        if (parti) {
          try {
            await copie.parent.delete(recursive: true);
          } catch (_) {}
        }
        return parti;

      case MessageType.location:
        if (originalMessage.latitude == null || originalMessage.longitude == null) return false;
        return sendLocation(
          conversationId: targetConversationId,
          latitude: originalMessage.latitude!,
          longitude: originalMessage.longitude!,
          address: originalMessage.locationAddress ?? '',
        );

      case MessageType.system:
      case MessageType.call:
        return false;

      case MessageType.poll:
        // Un sondage de groupe n'est lisible que par ses membres (RLS) :
        // transfere ailleurs, la bulle n'afficherait rien. On refuse.
        state = AsyncValue.error(
          'Un sondage ne peut pas être transféré : il appartient à son groupe.',
          StackTrace.current,
        );
        return false;

      case MessageType.sticker:
        if (originalMessage.stickerPackId == null ||
            originalMessage.stickerId == null ||
            originalMessage.fileUrl == null) {
          return false;
        }
        return sendSticker(
          conversationId: targetConversationId,
          stickerPackId: originalMessage.stickerPackId!,
          stickerId: originalMessage.stickerId!,
          stickerUrl: originalMessage.fileUrl!,
          isAnimated: originalMessage.isAnimatedSticker,
        );
    }
  }
}

// ============ Notifier pour creer des conversations ============
