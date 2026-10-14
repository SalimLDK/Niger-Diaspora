part of 'message_repository_impl.dart';

/// Messages d'une discussion : pagination, flux, suppression, réglages,
/// réactions, modification.
mixin _Messages on _MessageRepositoryBase, _Mls {
  @override
  Future<Either<Failure, PaginatedMessages>> getMessagesPaginated({
    required String conversationId,
    required int limit,
    String? beforeMessageId,
    DateTime? beforeCreatedAt,
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
          beforeCreatedAt: beforeCreatedAt,
          filterAfterDate: filterAfterDate,
        );

        final hasMore = messages.length > limit;
        // Drop the oldest probe item used to detect hasMore, keeping the
        // newest `limit` messages (datasource returns ascending order).
        final trimmed = hasMore ? messages.sublist(1) : messages;
        final healed = _healUndecryptableMessages(conversationId, trimmed);

        final entities = _signalerSupprimes(
          healed.map((m) => m.toEntity()).toList(),
        );

        // Cache the messages
        final messageMaps = healed.map((m) => m.toJson()).toList();
        await cacheService.cacheMessages(conversationId, messageMaps);

        // debugPrint('💾 Repository: Cached ${messageMaps.length} messages');

        // Coexistence (plan MLS § 2.3) : l'historique legacy est gelé, le
        // fil MLS est vivant. On les fusionne ici, une fois, plutôt que de
        // faire connaître deux sources aux 81 fichiers de la couche messages.
        // Première page seulement. Le fil MLS est postérieur à `mls_since`,
        // donc à tout l'historique legacy : une page plus ancienne n'en
        // contient rien. Le refusionner à chaque page ajoutait tout le fil
        // chiffré, une fois de plus, en tête de la liste affichée.
        final fusionnes = beforeMessageId == null
            ? await _fusionnerAvecMls(conversationId, entities)
            : entities;

        return Right(
          PaginatedMessages(
            messages: fusionnes,
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
        dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
        return Left(ServerFailure(AppErrorMessages.unexpectedError));
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

        final entities = _signalerSupprimes(
          cachedMessages.map((m) => MessageModel.fromJson(m).toEntity()).toList(),
        );

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
    final legacy = remoteDataSource
        .getNewMessagesStream(
          conversationId: conversationId,
          afterTimestamp: afterTimestamp,
        )
        .map<Either<Failure, List<MessageEntity>>>((messages) {
          // `cacheMessages` fusionne par id, et la nouvelle version l'emporte :
          // sans ce soin, l'écho d'un message qu'on vient d'envoyer écrasait
          // dans le cache le texte clair par son placeholder. Le rechargement
          // suivant n'avait alors plus rien de bon à récupérer.
          final healed = _healUndecryptableMessages(conversationId, messages);
          final messageMaps = healed.map((m) => m.toJson()).toList();
          unawaited(
            cacheService.cacheMessages(conversationId, messageMaps).catchError((e) {
              dev.log('Cache messages échoué: $e', name: 'MessageRepository');
            }),
          );

          return Right<Failure, List<MessageEntity>>(
            _signalerSupprimes(
              healed.map((m) => m.toEntity()).toList(),
            ),
          );
        })
        // `handleError` ignore la valeur de retour de son rappel : le `Left`
        // d'ici n'était jamais émis, l'erreur était avalée. Voir [_echecEmis].
        .transform(_echecEmis<List<MessageEntity>>());

    // Le temps réel n'écoutait que `messages`. Depuis la bascule MLS, les
    // messages vivants sont dans `mls_messages` : dans une conversation
    // chiffrée, plus RIEN n'arrivait en direct — il fallait ressortir de la
    // conversation et y revenir pour voir ce qu'on venait de recevoir.
    // Constaté à deux téléphones le 2026-09-15 : message envoyé du premier,
    // second resté ouvert sur la conversation, rien à l'écran.
    //
    // Le serveur était prêt (`mls_messages` est déjà dans la publication
    // `supabase_realtime`, avec sa politique SELECT) : il manquait seulement
    // l'abonnement.
    final passerelle = mlsGateway;
    if (passerelle == null) return legacy;

    final chiffres = remoteDataSource
        .mlsNouveauxMessages(conversationId)
        .asyncMap<Either<Failure, List<MessageEntity>>?>((_) async {
          try {
            if (!await passerelle.enMls(conversationId)) return null;
            // Relire le fil, pas la ligne : `catchUp` est incrémental, il ne
            // déchiffre que ce qui est nouveau depuis son curseur.
            // Le fil ENTIER, pas seulement ce qui est plus récent que
            // `afterTimestamp` : une modification porte la date d'ORIGINE du
            // message, pas celle du changement. La filtrer sur la date
            // revenait à ne jamais la délivrer — le texte modifié
            // n'apparaissait qu'à la réouverture.
            final fil = await passerelle.messages(conversationId);
            if (fil.isEmpty) return null;
            // **Mettre en cache, comme le fait la lecture.** Sans ça, un
            // message arrivé UNIQUEMENT par ce chemin vivait en mémoire et
            // nulle part ailleurs : il s'affichait, puis disparaissait dès
            // que la passerelle était recréée — le cache local, seul à
            // garder le clair d'un message chiffré, ne l'avait jamais vu.
            // Mesuré à deux téléphones le 2026-09-15 : message reçu « à
            // l'instant », absent du fil à la réouverture suivante.
            unawaited(cacheService.cacheMessages(
              conversationId,
              MessageRepositoryImpl.jsonPourCacheMls(fil),
            ));
            return Right<Failure, List<MessageEntity>>(fil);
          } catch (e) {
            // Un rattrapage raté ne doit pas tuer le flux : le suivant, ou la
            // prochaine ouverture, reprendra.
            dev.log('rattrapage MLS temps réel',
                name: 'message_repository_impl', error: e);
            return null;
          }
        })
        .where((e) => e != null)
        .cast<Either<Failure, List<MessageEntity>>>();

    // L'écran dédoublonne par identifiant : réémettre un message déjà présent
    // ne le duplique pas.
    return Rx.merge([legacy, chiffres]);
  }

  @override
  Stream<Either<Failure, MessageEntity>> getMessageUpdatesStream({
    required String conversationId,
  }) {
    return remoteDataSource
        .getMessageUpdatesStream(conversationId: conversationId)
        .map<Either<Failure, MessageEntity>>((message) {
          final entite = message.toEntity();
          _signalerSupprimes([entite]);
          return Right<Failure, MessageEntity>(entite);
        })
        // Même défaut que `getNewMessagesStream` : voir [_echecEmis].
        .transform(_echecEmis<MessageEntity>());
  }

  void resetPagination() {
    // _lastDocument = null;
  }

  @override
  Future<Either<Failure, void>> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    return _garde(() async {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        await passerelle.supprimerPourMoi(messageId);
        return const Right(null);
      }
      await remoteDataSource.deleteMessageForMe(
        conversationId: conversationId,
        messageId: messageId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    return _garde(() async {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        await passerelle.supprimerPourTous(messageId);
        await _marquerSupprimeDansLeCache(conversationId, messageId);
        oublierMedias?.call([messageId]);
        return const Right(null);
      }
      await remoteDataSource.deleteMessageForEveryone(
        conversationId: conversationId,
        messageId: messageId,
      );
      oublierMedias?.call([messageId]);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.archiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.unarchiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.muteConversation(
        conversationId: conversationId,
        userId: userId,
        duration: duration,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.unmuteConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.pinConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.unpinConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    return _garde(() async {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      bool? etoile;
      if (passerelle != null) {
        etoile = await passerelle.basculerEtoile(messageId);
      } else {
        await remoteDataSource.toggleStarMessage(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
        );
      }
      await reporterDansLeCache(cacheService, conversationId, messageId, (m) {
        final par = <String>[
          for (final u in (m['starredBy'] as List?) ?? const []) u.toString(),
        ];
        final maintenant = etoile ?? !par.contains(userId);
        par.remove(userId);
        if (maintenant) par.add(userId);
        if (par.isEmpty) {
          m.remove('starredBy');
        } else {
          m['starredBy'] = par;
        }
      });
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> toggleReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
    required bool retirer,
  }) async {
    return _garde(() async {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        if (retirer) {
          await passerelle.retirerReaction(messageId);
        } else {
          await passerelle.reagir(messageId, emoji);
        }
      } else if (retirer) {
        await remoteDataSource.removeReaction(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
        );
      } else {
        await remoteDataSource.addReaction(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
          emoji: emoji,
        );
      }
      await reporterDansLeCache(cacheService, conversationId, messageId, (m) {
        final reactions = <String, dynamic>{
          ...?(m['reactions'] as Map?)?.cast<String, dynamic>(),
        };
        if (retirer) {
          reactions.remove(userId);
        } else {
          reactions[userId] = emoji;
        }
        if (reactions.isEmpty) {
          m.remove('reactions');
        } else {
          m['reactions'] = reactions;
        }
      });
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getStarredMessages({
    required String conversationId,
    required String userId,
  }) async {
    return _garde(() async {
      final models = await remoteDataSource.getStarredMessages(
        conversationId: conversationId,
        userId: userId,
      );
      final trouves = <String, MessageEntity>{
        for (final m in models) m.id: m.toEntity(),
      };

      // Même défaut que la recherche, et plus visible encore : l'étoile d'un
      // message chiffré s'écrit bien (`mls_message_stars`) et le fil
      // l'affiche, mais la LISTE des favoris lisait `messages`, où ce message
      // n'a pas de ligne. On étoilait dans le vide.
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        final caches = <String, MessageEntity>{};
        for (final brut in cacheService.getCachedMessages(conversationId)) {
          try {
            final modele = MessageModel.fromJson(brut);
            caches[modele.id] = modele.toEntity();
          } catch (_) {
            // Une entrée illisible ne doit pas vider la liste entière.
          }
        }
        for (final id in await passerelle.favorisParmi(caches.keys)) {
          final m = caches[id];
          if (m != null) trouves[id] = m;
        }
      }

      final resultats = trouves.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(resultats);
    });
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> searchMessagesInConversation({
    required String conversationId,
    required String query,
  }) async {
    return _garde(() async {
      final models = await remoteDataSource.searchMessagesInConversation(
        conversationId: conversationId,
        query: query,
      );
      final trouves = <String, MessageEntity>{
        for (final m in models) m.id: m.toEntity(),
      };

      // Dans une conversation basculée, le serveur n'a que du ciphertext : son
      // `ilike` sur le contenu ne trouve RIEN, et la recherche renvoyait une
      // liste vide sans le dire — l'échec muet que ce chantier traque. Le
      // clair n'existe que sur l'appareil, donc la recherche aussi.
      //
      // On garde quand même le résultat serveur : au-dessus du séparateur de
      // bascule, l'historique est resté en clair et lui seul le couvre en
      // entier. Les deux sources se recouvrent, la clé de la table les
      // dédoublonne, et le cache gagne — c'est lui qui porte le texte déchiffré.
      if (await _passerellePour(conversationId) != null) {
        final aiguille = query.trim().toLowerCase();
        if (aiguille.isNotEmpty) {
          for (final brut in cacheService.getCachedMessages(conversationId)) {
            try {
              final modele = MessageModel.fromJson(brut);
              if (modele.content.toLowerCase().contains(aiguille)) {
                trouves[modele.id] = modele.toEntity();
              }
            } catch (_) {
              // Une entrée de cache illisible ne doit pas emporter la
              // recherche entière.
            }
          }
        }
      }

      final resultats = trouves.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(resultats);
    });
  }

  @override
  Future<Either<Failure, void>> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      // Le nouveau texte d'un message chiffré doit repartir chiffré, dans un
      // message de contrôle — rien ne l'émet encore. La passerelle lève, et
      // l'écran affiche une erreur : laisser passer écrirait dans `messages`,
      // sans cible, et le texte d'avant réapparaîtrait à la réouverture.
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        await passerelle.modifier(
          conversationId: conversationId,
          messageId: messageId,
          nouveauTexte: newContent,
        );
      } else {
        await remoteDataSource.editMessage(
          conversationId: conversationId,
          messageId: messageId,
          newContent: newContent,
          oldContent: oldContent,
        );
      }

      // Depuis que la modification est rechiffrée, l'expéditeur ne sait plus
      // relire son propre message depuis le serveur : les charges Signal d'un
      // 1:1 sont destinées aux appareils du DESTINATAIRE, jamais aux siens. Sa
      // bulle vient du cache, via `_healUndecryptableMessages`. Sans cette
      // mise à jour, rouvrir la conversation faisait **revenir le texte
      // d'avant** — le soin réécrivant l'ancien contenu par-dessus le nouveau,
      // sans la moindre erreur.
      final cached = cacheService.getCachedMessages(conversationId);
      final index = cached.indexWhere((m) => m['id'] == messageId);
      if (index != -1) {
        final mis = Map<String, dynamic>.from(cached[index]);
        mis['content'] = newContent;
        mis['editedAt'] = DateTime.now().toUtc().toIso8601String();
        await cacheService.cacheMessages(conversationId, [mis]);
      }
      // L'aperçu d'une conversation chiffrée vient de ce cache : sans rejeu,
      // la tuile garde le texte d'avant (voir [_marquerSupprimeDansLeCache]).
      _rejouerLaListe();

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // La garde d'entrée ne voit pas tout (portail captif, réseau qui tombe
      // pendant l'envoi) : une coupure doit se dire coupure, pas « erreur
      // inattendue ».
      if (estPanneReseau(e)) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    return _garde(() async {
      await remoteDataSource.setAutoDeleteSettings(
        conversationId: conversationId,
        durationSeconds: durationSeconds,
      );
      return const Right(null);
    });
  }
}
