part of 'message_repository_impl.dart';

/// Discussions : liste, cache, création, lecture, recherche, demandes de
/// message.
mixin _Conversations on _MessageRepositoryBase, _Mls {
  @override
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId,
  ) {
    // La dernière liste reçue du serveur, gardée pour pouvoir la rejouer
    // telle quelle : le rattrapage de fond déchiffre APRÈS coup, et sans ce
    // rejeu son travail n'atteint l'écran qu'à la prochaine émission du
    // serveur. C'est ce qui laissait « Message chiffré » sur la tuile d'un
    // message reçu, app ouverte sur la liste, jusqu'à un tirer-pour-
    // rafraîchir ou l'ouverture de la discussion.
    List<ConversationModel>? derniere;

    final duServeur = remoteDataSource.getConversations(userId).map((
      conversations,
    ) {
      derniere = conversations;
      return conversations;
    });
    // Une lecture chiffrée ne touche pas la ligne `conversations` : sans ce
    // signal, la pastille gardait l'ancien compte en sortant de la
    // discussion (voir `MlsGateway.lecturesAvancees`). Groupé : l'écran
    // avance le curseur par lots rapprochés, une relecture suffit.
    final lectures =
        mlsGateway?.lecturesAvancees
            .debounceTime(const Duration(milliseconds: 300)) ??
        const Stream<void>.empty();
    final rejeu = Rx.merge([_rattrapageFini.stream, lectures])
        .map((_) => derniere)
        .where((c) => c != null)
        .cast<List<ConversationModel>>();

    return Rx.merge([duServeur, rejeu])
        .asyncMap<Either<Failure, List<ConversationEntity>>>((
          conversations,
        ) async {
          // Filter out deleted conversations
          final filteredConversations =
              conversations.where((c) {
                return !c.deletedBy.containsKey(userId);
              }).toList();

          // Cache the conversations
          // Convert models to json maps for caching
          final conversationsMap =
              filteredConversations.map((c) => c.toJson()).toList();
          unawaited(
            cacheService.cacheConversations(conversationsMap).catchError((e) {
              dev.log('Cache conversations échoué: $e', name: 'MessageRepository');
            }),
          );

          final liste = _dedupConversationsByPair(
            filteredConversations.map((c) => c.toEntity()).toList(),
          );

          return Right<Failure, List<ConversationEntity>>(
            await _completerAvecMls(userId, liste),
          );
        })
        .transform(_echecEmis<List<ConversationEntity>>());
  }

  /// Ce qu'une conversation basculée ne porte plus en base, et qu'il faut
  /// donc reconstituer ici : sa pastille de non-lus, et le texte de son
  /// aperçu.
  ///
  /// Le serveur n'écrit ni `data.unreadCount` (il ne sait pas le
  /// décrémenter : `mark_messages_as_read` ne connaît que `messages`) ni
  /// `data.lastMessage` (ce serait du clair). Sans ce passage, une
  /// discussion chiffrée n'a jamais de pastille et affiche « Nouveau
  /// message » à vie.
  ///
  /// Un échec ne coûte pas la liste : il coûte la pastille.
  Future<List<ConversationEntity>> _completerAvecMls(
    String userId,
    List<ConversationEntity> liste,
  ) async {
    var avecApercu = [for (final c in liste) _apercuDepuisLeCache(c)];

    final passerelle = mlsGateway;
    // Avant le garde, pas après : c'est lui qui a besoin de savoir. Sans cette
    // amorce, `aDesConversationsBasculees` reste faux tant qu'aucun fil
    // chiffré n'a été ouvert, et la liste sort sans pastille ni aperçu après
    // chaque démarrage à froid.
    if (passerelle != null) {
      await passerelle.amorcerBascules([for (final c in avecApercu) c.id]);
    }
    // Inerte tant que rien n'est basculé et que le drapeau est fermé : pas
    // un appel réseau de plus sur un flux qui émet à chaque changement de
    // conversation.
    if (passerelle == null ||
        (!passerelle.actif && !passerelle.aDesConversationsBasculees)) {
      return avecApercu;
    }
    // Ce que le cache local ne pouvait pas donner : l'aperçu d'un message
    // reçu **sans que la discussion ait été ouverte**. Le fil est le seul à
    // déchiffrer, donc ces messages-là restaient « Message chiffré » pour
    // toujours — dix minutes vérifiées le 2026-09-15 sur Pixel 10 Pro XL,
    // app ouverte. L'isolate de notification, lui, les a déchiffrés à leur
    // arrivée sur une copie jetable ; on relit son résultat.
    //
    // Appliqué **après** `_apercuDepuisLeCache` et seulement là où il n'a rien
    // trouvé : le cache du fil reste prioritaire, car il connaît les
    // suppressions et les expirations que l'aperçu de notification ignore.
    try {
      // Ne demander que pour celles qui n'ont toujours rien à montrer : le
      // cache du fil a déjà servi juste au-dessus.
      final enAttente = [
        for (final c in avecApercu)
          if ((c.lastMessage ?? '').isEmpty &&
              c.lastMessageAt != null &&
              c.apercuEfface == ApercuEfface.aucun)
            c.id,
      ];
      final apercus = await passerelle.apercusDejaDechiffres(enAttente);
      if (apercus.isNotEmpty) {
        avecApercu = [
          for (final c in avecApercu)
            MessageRepositoryImpl.apercuDepuisNotification(c, apercus[c.id]),
        ];
      }
    } catch (e) {
      dev.log('Aperçus MLS indisponibles',
          name: 'message_repository_impl', error: e);
    }

    // Déchiffrer **avant** qu'on ouvre, et non pendant. Sans ça, le fil
    // s'affiche depuis le cache local — donc sans les messages reçus entre
    // deux visites — et il faut attendre réseau + déchiffrement pour les voir
    // apparaître. Mesuré le 2026-09-15 sur Pixel 10 Pro XL : 2,5 à 3 secondes.
    //
    // **Attendu, mais borné.** La liste émettait d'abord, puis déchiffrait :
    // un message reçu liste à l'écran faisait remonter sa tuile sur
    // « Message chiffré », remplacé ~2 s plus tard par le texte — vu sur
    // SM A515F le 2026-09-21. Attendre la passe fait remonter la tuile
    // directement avec son texte. Au-delà de [attenteDechiffrementMax], la
    // liste sort quand même : un réseau lent ou un fil qui refuse de se
    // déchiffrer ne doit jamais la figer. La passe continue alors seule et
    // la fait rejouer une fois finie, comme avant.
    //
    // Ne coûte rien quand il n'y a rien à déchiffrer : la passe rend la main
    // tout de suite (rien de neuf, ou plancher entre deux passes).
    final attente = _AttenteRattrapage();
    try {
      await _rattraperMlsEnArrierePlan(passerelle, avecApercu, attente: attente)
          .timeout(attenteDechiffrementMax);
      avecApercu = [for (final c in avecApercu) _apercuDepuisLeCache(c)];
    } on TimeoutException {
      attente.abandonnee = true;
    }

    try {
      final compteurs = await passerelle.nonLus();
      if (compteurs.isEmpty) return avecApercu;
      return [
        for (final c in avecApercu)
          if (compteurs[c.id] case final compteur?)
            c.copyWith(
              unreadCount: {...c.unreadCount, userId: compteur.nonLus},
              unreadMentions: {...c.unreadMentions, userId: compteur.mentions},
            )
          else
            c,
      ];
    } catch (e) {
      dev.log('Compteurs MLS indisponibles',
          name: 'message_repository_impl', error: e);
      return avecApercu;
    }
  }

  /// Le texte de l'aperçu d'une conversation chiffrée, repris du cache local
  /// déchiffré (décision G) — le serveur, lui, ne porte que le type.
  ///
  /// **L'horodatage doit correspondre exactement.** Le cache peut être en
  /// retard : si la discussion n'a pas été rouverte depuis, son dernier
  /// message caché n'est pas le dernier message. Afficher celui-là serait
  /// pire qu'un libellé générique — ce serait un aperçu faux, et rien ne le
  /// dirait. `last_message_at` vient du même `created_at` serveur que le
  /// message caché : l'égalité est franche, pas approchée.
  ConversationEntity _apercuDepuisLeCache(ConversationEntity c) =>
      MessageRepositoryImpl.apercuDepuisCache(
        c,
        () => cacheService.getCachedMessages(c.id),
      );

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

      // Même reconstruction d'aperçu que le chemin live
      // (`_completerAvecMls`), et pour la même raison : une conversation
      // basculée n'a **jamais** de `lastMessage` en base — le serveur n'en
      // voit pas le clair. Le texte vient du cache local déchiffré.
      //
      // Sans ce passage ici, c'est l'émission du cache qui s'affiche en
      // premier au démarrage — elle gagne toujours, le flux réseau arrive
      // 1 à 3 s plus tard — et chaque discussion chiffrée annonçait
      // « Message chiffré » pendant tout ce temps, alors que l'appareil
      // avait le texte sous la main. Mesuré le 2026-09-15 sur Pixel 10 Pro
      // XL : encore faux à t+0,8 s, juste à t+3,2 s.
      //
      // Purement local et synchrone : aucune lecture réseau n'est ajoutée au
      // chemin hors ligne.
      final avecApercu = [
        for (final c in _dedupConversationsByPair(entities))
          _apercuDepuisLeCache(c),
      ];
      return Right(avecApercu);
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
        .map<Either<Failure, ConversationEntity?>>((model) {
          if (model == null) {
            return const Right<Failure, ConversationEntity?>(null);
          }
          final entite = model.toEntity();
          // Le serveur vient d'annoncer l'appartenance. C'est le seul signal
          // qui voit TOUS les chemins — y compris ceux où un déclencheur
          // recopie `group_members` dans `participant_ids` sans qu'aucun code
          // Dart ne passe. On ne l'attend pas : la réconciliation MLS est un
          // travail de fond, l'écran ne doit rien lui devoir.
          unawaited(
            mlsGateway?.appartenanceChangee(
                  conversationId,
                  entite.participantIds,
                ) ??
                Future<void>.value(),
          );
          return Right<Failure, ConversationEntity?>(entite);
        })
        .transform(_echecEmis<ConversationEntity?>());
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

      return Right(_signalerSupprimes(entities));
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
        .map<Either<Failure, List<MessageEntity>>>((messages) {
          return Right<Failure, List<MessageEntity>>(
            messages.map((m) => m.toEntity()).toList(),
          );
        })
        .transform(_echecEmis<List<MessageEntity>>());
  }

  @override
  Future<Either<Failure, ConversationEntity>> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final conversation = await remoteDataSource.createIndividualConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(conversation.toEntity());
    });
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final conversation = await remoteDataSource.createGroupConversation(
        creatorId: creatorId,
        participantIds: participantIds,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        groupId: groupId,
      );
      return Right(conversation.toEntity());
    });
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
      // Une conversation basculée n'a plus de ligne dans `messages` : son
      // reçu vit dans `mls_message_receipts`. Les deux sont appelés tant que
      // l'historique legacy est là — chacun ne touche que ses propres lignes.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        await passerelle.marquerLivres(conversationId);
      }
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        await passerelle.marquerLus(conversationId);
      }
      await remoteDataSource.markAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return _garde(() async {
      await remoteDataSource.clearUnreadMentions(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  }) async {
    return _garde(() async {
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
    });
  }

  @override
  Future<Either<Failure, ConversationEntity?>> getConversationById(
    String conversationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final conversation = await remoteDataSource.getConversationById(
        conversationId,
      );
      return Right(conversation?.toEntity());
    });
  }

  @override
  Future<Either<Failure, void>> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.restoreConversationForUser(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, ConversationEntity>>
  getOrCreateIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
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
    });
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateSelfConversation({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final conversation = await remoteDataSource.getOrCreateSelfConversation(
        userId: userId,
      );
      return Right(conversation.toEntity());
    });
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
    DateTime? beforeCreatedAt,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      final messages = await remoteDataSource.getMediaMessages(
        conversationId: conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
        beforeCreatedAt: beforeCreatedAt,
      );
      final trouves = <String, MessageEntity>{
        for (final m in messages) m.id: m.toEntity(),
      };

      // La fenêtre de CETTE page : du curseur (exclu) jusqu'au plus ancien
      // média du serveur — sans borne basse si c'est la dernière page. Les
      // médias du cache n'entrent que dans leur fenêtre : sans elle, chaque
      // page les reprenait tous (doublons), et un média chiffré plus ancien
      // que la page devenait son curseur, faisant sauter les médias du
      // serveur compris entre les deux.
      final derniere = messages.length < limit;
      final borneBasse = derniere
          ? null
          : messages
              .map((m) => m.toEntity().createdAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
      bool dansLaPage(MessageEntity e) =>
          (beforeCreatedAt == null || e.createdAt.isBefore(beforeCreatedAt)) &&
          (borneBasse == null || !e.createdAt.isBefore(borneBasse));

      // Troisième occurrence du même défaut : la galerie d'une conversation
      // basculée ne montrait que les médias d'AVANT la bascule. Le descripteur
      // d'un média chiffré (URL, clé du fichier) voyage dans le payload MLS,
      // donc le serveur ne sait pas dire qu'il s'agit d'un média. Le cache,
      // lui, porte l'entité déjà déchiffrée et son type.
      if (await _passerellePour(conversationId) != null) {
        for (final brut in cacheService.getCachedMessages(conversationId)) {
          try {
            final modele = MessageModel.fromJson(brut);
            final e = modele.toEntity();
            // Mêmes types et même exigence d'URL que le chemin serveur
            // (`inFilter('type', …)` puis `fileUrl != null`) : la galerie
            // d'une conversation basculée doit contenir la même chose, pas
            // davantage.
            final estMedia = e.type == MessageType.image ||
                e.type == MessageType.video ||
                e.type == MessageType.file;
            if (estMedia &&
                (e.fileUrl?.isNotEmpty ?? false) &&
                dansLaPage(e)) {
              trouves[e.id] = e;
            }
          } catch (_) {
            // Une entrée illisible ne doit pas vider la galerie entière.
          }
        }
      }

      final resultats = trouves.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(resultats);
    });
  }

  @override
  Future<Either<Failure, String?>> findConversationWithUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    return _garde(() async {
      final conversation = await remoteDataSource.findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      return Right(conversation?.id);
    });
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    return _garde(() async {
      final conversation = await remoteDataSource.findGroupConversationByName(
        groupName: groupName,
        userId: userId,
      );
      return Right(conversation?.id);
    });
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    return _garde(() async {
      final conversation = await remoteDataSource
          .findGroupConversationByGroupId(groupId: groupId, userId: userId);
      return Right(conversation?.id);
    });
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
        // Soigner AVANT d'écrire : `cacheMessagesLRU` fusionne par id et la
        // nouvelle version l'emporte, donc un placeholder écrit ici efface le
        // texte clair déjà en cache — définitivement, le serveur ne pouvant pas
        // le rendre une seconde fois. Les deux autres chemins de rechargement
        // soignaient déjà ; celui-ci était le seul à ne pas le faire.
        final healed = _healUndecryptableMessages(conversationId, newMessages);
        final newMessagesJson = healed.map((m) => m.toJson()).toList();
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
      return Left(NetworkFailure(AppErrorMessages.networkError));
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
