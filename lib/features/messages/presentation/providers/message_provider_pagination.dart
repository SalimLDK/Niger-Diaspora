part of 'message_provider.dart';

// PaginatedMessagesNotifier et le résultat d'une modification.

class PaginatedMessagesNotifier extends StateNotifier<MessagePaginationState> {
  final Ref _ref;
  final String conversationId;

  StreamSubscription<dynamic>? _newMessagesSubscription;
  StreamSubscription<dynamic>? _messageUpdatesSubscription;

  /// Date d'arrivée du membre dans un groupe privé : rien d'antérieur ne
  /// s'affiche. Voir [state].
  DateTime? _filterAfterDate;

  /// **Le seul endroit où la borne d'arrivée s'applique.**
  ///
  /// Elle n'était passée qu'à la page réseau (`getMessagesPaginated`) : le
  /// cache local, la fusion MLS, la pagination et le temps réel posaient
  /// leurs messages sans elle. Tant que la date n'était jamais lue — ce qui a
  /// duré jusqu'au 2026-09-16 —, ça ne se voyait pas. Dès qu'elle l'est, un
  /// membre voyait les messages d'avant son arrivée surgir du cache à chaque
  /// ouverture, puis disparaître au retour du réseau. Une vingtaine
  /// d'écritures de `state` dans ce notifier : filtrer chacune, c'était en
  /// oublier une.
  ///
  /// **Et le seul où un message supprimé pour tout le monde est vidé**, pour
  /// la même raison : un message MLS supprimé arrive déchiffré, drapeau posé
  /// mais texte intact, par le temps réel comme par le cache ou la
  /// pagination. Voir `sansContenuSupprime`.
  @override
  set state(MessagePaginationState valeur) {
    final borne = _filterAfterDate;
    final messages = sansContenuSupprime(
      sansMessagesAvantArrivee(valeur.messages, borne),
    );
    super.state = identical(messages, valeur.messages)
        ? valeur
        : valeur.copyWith(messages: messages);
  }
  final Map<String, Timer> _optimisticTimeouts = {};

  /// La lecture réseau initiale a abouti au moins une fois.
  ///
  /// Tant qu'elle n'a pas abouti, l'écran vit sur le cache **et n'a aucun
  /// abonnement temps réel** : `_loadNetworkData` sort avant de les poser.
  /// Une discussion ouverte hors ligne restait donc figée pour toujours — le
  /// retour du réseau n'y changeait rien, puisqu'il n'y avait rien pour
  /// l'écouter. C'est ce drapeau qui autorise les relances ci-dessous.
  bool _lectureReseauAboutie = false;

  /// Relances programmées, annulées à la disposition du notifier.
  final List<Timer> _relances = [];

  /// Écoute de [sessionSupabaseEtablieProvider], posée au premier échec et
  /// retirée dès que la lecture a abouti.
  StreamSubscription<void>? _attenteSession;

  PaginatedMessagesNotifier(this._ref, this.conversationId)
      : super(const MessagePaginationState(isLoadingInitial: true)) {
    // Load cache synchronously for instant display
    _loadCacheSync();
    // Then load network data in background
    unawaited(Future.microtask(() => _loadNetworkData()));

    // Retour du réseau : la discussion ouverte hors ligne n'a jamais chargé.
    _ref.listen(connectivityNotifierProvider, (_, connecte) {
      if (connecte == true && !_lectureReseauAboutie && mounted) {
        unawaited(_loadNetworkData());
      }
    });
  }

  /// Reprogramme la lecture initiale après un échec.
  ///
  /// Le retour du réseau ne couvre pas tout : au démarrage à froid la
  /// connectivité est déjà là, mais la session Supabase, elle, n'est pas
  /// encore établie — la lecture échoue alors sans qu'aucun événement ne
  /// vienne ensuite la relancer. Deux essais espacés suffisent ; au-delà,
  /// c'est à l'utilisateur de revenir sur l'écran.
  ///
  /// Et surtout, relire **dès que la session est établie** : c'est presque
  /// toujours elle qui manquait (démarrage à froid, jeton périmé au retour
  /// d'arrière-plan en ouvrant une notification). Le jeton neuf arrive en
  /// moins d'une seconde ; attendre les 4 s fixes laissait l'écran vide alors
  /// que la notification venait d'annoncer le message. Les relances à heure
  /// fixe ne sont plus qu'un filet, pour un échange qui échoue.
  void _programmerRelance() {
    _attenteSession ??= _ref.read(sessionSupabaseEtablieProvider).listen((_) {
      if (!_lectureReseauAboutie && mounted) unawaited(_loadNetworkData());
    });
    if (_relances.length >= 2) return;
    final delai = Duration(seconds: _relances.isEmpty ? 4 : 10);
    _relances.add(
      Timer(delai, () {
        if (!_lectureReseauAboutie && mounted) unawaited(_loadNetworkData());
      }),
    );
  }

  /// Fire-and-forget: prepare E2EE sessions and Sender Keys for this conversation.
  ///   • 1:1   → pre-establish Signal session with the other participant
  ///   • Group → distribute this user's Sender Key to all members
  void _preEstablishE2EESessions() {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final crypto = _ref.read(messageCryptoServiceProvider);

    // Try the cached stream value first; if not yet loaded, wait for the first
    // emission so we never skip pre-establishment due to a loading race.
    final cached = _ref.read(conversationStreamProvider(conversationId)).valueOrNull;
    if (cached != null) {
      _doPreEstablish(crypto, cached, currentUser.id);
    } else {
      // Stream not loaded yet — listen for the first value then pre-establish.
      _ref.listen(conversationStreamProvider(conversationId), (_, next) {
        final conv = next.valueOrNull;
        if (conv != null) _doPreEstablish(crypto, conv, currentUser.id);
      });
    }
  }

  void _doPreEstablish(dynamic crypto, dynamic conversation, String currentUserId) {
    if (conversation.isIndividual == true) {
      final recipients = (conversation.participantIds as List<String>)
          .where((id) => id != currentUserId)
          .toList();
      if (recipients.isEmpty) return;
      crypto
          .preEstablishSessions(recipients)
          .catchError((e) => debugPrint('E2EE pre-establish error: $e'));
    } else {
      // Le compte rendu de la distribution alimente le cadenas de l'en-tête :
      // sans lui, un groupe pouvait rester en repli AES indéfiniment sans que
      // rien ne le signale (cf. group_encryption_status_provider.dart).
      crypto
          .distributeGroupSenderKey(
            groupId: conversationId,
            memberIds: conversation.participantIds,
          )
          .then((dynamic result) {
            // `null` = le chiffrement E2EE n'est pas prêt sur cet appareil,
            // donc rien n'a même pu être tenté. C'est un repli AES aussi, et
            // le taire était précisément le trou qu'on bouche ici.
            _ref
                .read(groupEncryptionStatusProvider(conversationId).notifier)
                .state = result is SenderKeyDistribution
                ? GroupEncryptionStatus.fromDistribution(result)
                : const GroupEncryptionStatus.keysUnavailable();
          })
          .catchError((e) => debugPrint('Sender Key distribution error: $e'));
    }
  }

  /// Load cached messages synchronously (instant)
  void _loadCacheSync() {
    final cachedResult = _ref
        .read(messageRepositoryProvider)
        .getCachedMessages(conversationId: conversationId, limit: _pageSize);

    cachedResult.fold(
      (failure) {
        // Cache failed, will load from network
      },
      (cachedMessages) {
        if (cachedMessages.isNotEmpty) {
          state = MessagePaginationState(
            messages: _avecMessagesJamaisPartis(
              _withPendingLocalMessages(cachedMessages),
            ),
            hasMore: cachedMessages.length >= _pageSize,
            lastMessageId: cachedMessages.first.id,
            oldestMessageTimestamp: cachedMessages.first.createdAt,
            isOffline: false,
            isLoadingInitial: false,
          );
          // Listeners will be configured in _loadNetworkData() to avoid duplicates
        }
      },
    );
  }

  /// Load data from network (async, background)
  Future<void> _loadNetworkData() async {
    if (!mounted) return;

    final isOffline = !_ref.read(connectivityNotifierProvider);
    if (isOffline) {
      // On sort sans poser les écouteurs temps réel : c'est voulu, ils ne
      // pourraient pas s'abonner. Mais l'écran ne doit pas rester ainsi — le
      // `_ref.listen` du constructeur repassera ici au retour du réseau.
      if (state.messages.isEmpty) {
        state = state.copyWith(isOffline: true, isLoadingInitial: false);
      }
      return;
    }

    // Pre-establish Signal sessions eagerly so the first outbound message is
    // already E2EE without waiting for lazy session setup at send time.
    _preEstablishE2EESessions();

    // Sync RTDB in background
    unawaited(RtdbSyncScript().syncConversationToRTDB(conversationId));

    // Load fresh data from network
    final result = await _ref
        .read(messageRepositoryProvider)
        .getMessagesPaginated(
          conversationId: conversationId,
          limit: _pageSize,
          filterAfterDate: _filterAfterDate,
        );

    if (!mounted) return;

    result.fold(
      (failure) {
        // Cache non vide : on le garde plutôt que d'afficher une erreur
        // par-dessus une discussion lisible. Mais sans relance, l'écran
        // restait muet **et sans abonnement** — aucune erreur, aucun message
        // nouveau, rien. La session Supabase pas encore établie au démarrage
        // à froid tombe exactement ici.
        if (state.messages.isEmpty) {
          state = MessagePaginationState(
            error: failure.message,
            isOffline: true,
          );
        }
        _programmerRelance();
      },
      (paginatedMessages) {
        _lectureReseauAboutie = true;
        unawaited(_attenteSession?.cancel());
        _attenteSession = null;
        state = MessagePaginationState(
          messages: _avecMessagesJamaisPartis(
            _withPendingLocalMessages(paginatedMessages.messages),
          ),
          hasMore: paginatedMessages.hasMore,
          lastMessageId: paginatedMessages.lastMessageId,
          oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
          isOffline: false,
          isLoadingInitial: false,
        );

        // Discussion vide : la borne du rattrapage était « l'horloge du
        // téléphone moins 10 s », comparée à des dates du serveur. Un
        // téléphone en avance la plaçait après les premiers messages. Rien
        // n'a été chargé, donc tout ce qui existe est à prendre — à partir de
        // l'arrivée dans le groupe s'il y en a une.
        final lastTimestamp = paginatedMessages.messages.isNotEmpty
            ? paginatedMessages.messages.last.createdAt
            : (_filterAfterDate ?? DateTime.utc(2000));
        _listenForNewMessages(lastTimestamp);
        _listenForMessageUpdates();
      },
    );
  }

  /// Réinjecte les messages purement locaux (en cours d'envoi ou en échec)
  /// dans une liste fraîchement chargée.
  ///
  /// `_loadNetworkData` remplaçait l'état ENTIER par la réponse serveur : un
  /// message en échec, qui n'existe que côté client, disparaissait donc à la
  /// moindre recharge (changement de filtre de date, retour en ligne, nouvelle
  /// pagination initiale) sans que rien ne le signale. Il n'y a pas de file
  /// d'attente persistée : ces messages restent perdus si l'écran est quitté,
  /// mais ils ne doivent au moins pas s'évaporer sous les yeux de la personne.
  List<MessageEntity> _withPendingLocalMessages(List<MessageEntity> fresh) {
    final pending = state.messages
        .where((m) =>
            m.id.startsWith('temp_') &&
            (m.status == MessageStatus.sending ||
                m.status == MessageStatus.failed))
        .toList();
    if (pending.isEmpty) return fresh;

    return [...fresh, ...pending]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  void dispose() {
    unawaited(_newMessagesSubscription?.cancel());
    unawaited(_messageUpdatesSubscription?.cancel());
    for (final timer in _optimisticTimeouts.values) {
      timer.cancel();
    }
    _optimisticTimeouts.clear();
    for (final relance in _relances) {
      relance.cancel();
    }
    _relances.clear();
    unawaited(_attenteSession?.cancel());
    super.dispose();
  }

  void setFilterDate(DateTime? date) {
    if (_filterAfterDate != date) {
      _filterAfterDate = date;
      // Tout de suite, sur ce qui est déjà affiché — le cache s'est posé avant
      // que la date soit connue. Sans ça, les messages d'avant l'arrivée
      // restaient à l'écran le temps de la relecture réseau.
      if (mounted) state = state;
      unawaited(loadInitial());
    }
  }

  Future<void> loadInitial() async {
    _loadCacheSync();
    await _loadNetworkData();
  }

  Future<void> loadMore() async {
    if (!mounted || !state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await _ref
        .read(messageRepositoryProvider)
        .getMessagesPaginated(
          conversationId: conversationId,
          limit: _pageSize,
          beforeMessageId: state.lastMessageId,
          beforeCreatedAt: state.oldestMessageTimestamp,
          filterAfterDate: _filterAfterDate,
        );

    if (!mounted) return;

    result.fold(
      (failure) {
        if (mounted) {
          state = state.copyWith(isLoadingMore: false, error: failure.message);
        }
      },
      (paginatedMessages) {
        if (mounted) {
          state = state.copyWith(
            messages: [...paginatedMessages.messages, ...state.messages],
            hasMore: paginatedMessages.hasMore,
            lastMessageId: paginatedMessages.lastMessageId,
            oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
            isLoadingMore: false,
          );
        }
      },
    );
  }

  void _listenForNewMessages(DateTime afterTimestamp) {
    unawaited(_newMessagesSubscription?.cancel());
    _newMessagesSubscription = _ref
        .read(messageRepositoryProvider)
        .getNewMessagesStream(
          conversationId: conversationId,
          afterTimestamp: afterTimestamp,
        )
        .listen((either) {
          if (!mounted) return;
          either.fold(
            // Un message temps réel illisible : le flux continue, mais
            // l'échec ne disparaît plus dans un rappel vide.
            (failure) => signalerEchecSilencieux(
              failure.message,
              contexte: 'temps reel nouveaux messages',
            ),
            (newMessages) {
              if (!mounted) return;
              if (newMessages.isNotEmpty) {
                final existingMessages = List<MessageEntity>.from(state.messages);

                for (final newMessage in newMessages) {
                  // Priority 1: match by clientMessageId — que la copie locale soit
                  // encore optimiste (`temp_`) OU que son id ait déjà été remplacé
                  // par l'id réel via updateMessageStatusAndCancelTimeout(). Ne plus
                  // exiger le préfixe `temp_` ferme la course « l'INSERT temps réel
                  // arrive juste après le retour de send() » qui créait un doublon.
                  int optimisticIndex = -1;
                  if (newMessage.clientMessageId != null) {
                    optimisticIndex = existingMessages.indexWhere(
                      (m) => m.clientMessageId == newMessage.clientMessageId,
                    );
                  }

                  // Priority 2: heuristique temporelle pour les messages sans
                  // clientMessageId des deux côtés (stickers, GIF, localisation,
                  // anciens clients).
                  //
                  // L'âge de la copie locale, mesuré à SA propre horloge — et
                  // non plus l'écart entre sa date et celle de l'écho : l'écho
                  // est daté par le serveur (20261004090000), la copie par le
                  // téléphone, et un téléphone décalé de plus de quelques
                  // secondes aurait dupliqué chaque sticker. Une minute couvre
                  // un aller-retour lent (gros média, session Signal à établir).
                  if (optimisticIndex == -1) {
                    final maintenant = DateTime.now();
                    optimisticIndex = existingMessages.indexWhere((m) {
                      final idMatch = m.id.startsWith('temp_');
                      final senderMatch = m.senderId == newMessage.senderId;
                      final typeMatch = m.type == newMessage.type;
                      final timeMatch = maintenant
                              .difference(m.createdAt)
                              .abs() <
                          const Duration(minutes: 1);
                      final contentMatch = _matchesOptimisticMessage(m, newMessage);
                      final noClientId = m.clientMessageId == null &&
                          newMessage.clientMessageId == null;
                      return idMatch &&
                          senderMatch &&
                          typeMatch &&
                          timeMatch &&
                          contentMatch &&
                          noClientId;
                    });
                  }

                  if (optimisticIndex != -1) {
                    // Le message est bel et bien arrivé : il ne doit plus
                    // pouvoir repartir. Un message marqué « failed » par le
                    // délai de 30 s dont l'écho arrive en retard serait sinon
                    // renvoyé en double au retour du réseau.
                    _ref
                        .read(paginatedMessagesProvider(conversationId).notifier)
                        .oublierMessageEnAttente(
                          existingMessages[optimisticIndex].id,
                        );
                    _cancelOptimisticTimeout(existingMessages[optimisticIndex].id);
                    existingMessages[optimisticIndex] = _reconcileEcho(
                      existingMessages[optimisticIndex],
                      newMessage,
                    );
                  } else {
                    final connu = existingMessages
                        .indexWhere((m) => m.id == newMessage.id);
                    if (connu == -1) {
                      existingMessages.add(newMessage);
                    } else {
                      // Remplacer, au lieu d'ignorer. Ce flux porte du
                      // DÉCHIFFRÉ — contrairement à `getMessageUpdatesStream`,
                      // qui rend la ligne brute et doit donc préserver le
                      // contenu en place. Ignorer un identifiant connu faisait
                      // qu'une MODIFICATION n'arrivait jamais en direct : son
                      // entité garde l'identifiant d'origine, elle tombait
                      // donc toujours dans cette branche.
                      existingMessages[connu] = newMessage;
                    }
                  }
                }

                existingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                state = state.copyWith(messages: existingMessages);
              }
            },
          );
        });
  }

  void _listenForMessageUpdates() {
    unawaited(_messageUpdatesSubscription?.cancel());
    _messageUpdatesSubscription = _ref
        .read(messageRepositoryProvider)
        .getMessageUpdatesStream(conversationId: conversationId)
        .listen((either) {
          if (!mounted) return;
          either.fold(
            (failure) => signalerEchecSilencieux(
              failure.message,
              contexte: 'temps reel mises a jour',
            ),
            (updatedMessage) {
              if (!mounted) return;
              final existingMessages = List<MessageEntity>.from(state.messages);
              final index = existingMessages.indexWhere((m) => m.id == updatedMessage.id);

              if (index != -1) {
                // getMessageUpdatesStream fournit la ligne BRUTE (non déchiffrée) :
                // son `content` est le chiffré au repos. Re-déchiffrer ici est
                // impossible pour Signal — le Double Ratchet a déjà consommé la
                // clé du message au 1er déchiffrement, un 2e échouerait.
                // On conserve donc le contenu déjà déchiffré et on n'applique que
                // les métadonnées mutables portées par l'update (réactions, statut
                // lu/livré, épinglage, etc.). Les vrais changements de contenu
                // (suppression pour tous) passent par des chemins dédiés.
                //
                // Les charges annexes suivent la même règle depuis qu'elles sont
                // chiffrées au repos : la ligne brute ne porte que leur blob, que
                // ce chemin ne déchiffre pas. Sans ce rappel, le premier accusé
                // de lecture faisait disparaître la carte du post ou du groupe
                // partagé — sans erreur nulle part.
                final existing = existingMessages[index];
                existingMessages[index] = fusionnerLigneBrute(
                  affiche: existing,
                  brut: updatedMessage,
                );
                debugPrint(
                  'Message ${updatedMessage.id} read_by updated: ${updatedMessage.readBy}',
                );
                state = state.copyWith(messages: existingMessages);

                if (!updatedMessage.deletedForEveryone &&
                    modificationPlusRecente(
                      affichee: existing.editedAt,
                      recue: updatedMessage.editedAt,
                    )) {
                  unawaited(
                    _relireModification(
                      updatedMessage.id,
                      updatedMessage.editedAt!,
                    ),
                  );
                }
              }
            },
          );
        });
  }

  /// Relectures de modification en cours, par message : la version la plus
  /// récente annoncée pendant qu'elles tournent.
  ///
  /// Un même UPDATE arrive souvent deux fois (temps réel, puis rattrapage au
  /// rejoint) et un accusé de lecture sur un message modifié en redonne la
  /// date : sans ce registre, chaque passage relancerait un déchiffrement —
  /// et pour Signal, le second échoue.
  final Map<String, DateTime> _modificationsEnRelecture = {};

  /// Relit déchiffré un message dont le texte a été modifié, et l'applique.
  ///
  /// Voir `modification_recue.dart` pour la règle.
  Future<void> _relireModification(String messageId, DateTime annoncee) async {
    final enCours = _modificationsEnRelecture[messageId];
    if (enCours != null) {
      // Une relecture tourne déjà : noter la version, elle sera relue à la
      // suite si celle que rapporte la relecture en cours est plus ancienne.
      if (annoncee.isAfter(enCours)) {
        _modificationsEnRelecture[messageId] = annoncee;
      }
      return;
    }
    _modificationsEnRelecture[messageId] = annoncee;
    try {
      final resultat = await _ref
          .read(messageRepositoryProvider)
          .getMessageById(conversationId: conversationId, messageId: messageId);
      if (!mounted) return;
      final relu = resultat.fold((_) => null, (m) => m);
      if (relu == null) return;

      final messages = List<MessageEntity>.from(state.messages);
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return;
      final moi = _ref.read(currentUserAsyncProvider).valueOrNull?.id;
      final applique = appliquerModificationRelue(
        affiche: messages[index],
        relu: relu,
        estAMoi: moi != null && relu.senderId == moi,
      );
      if (identical(applique, messages[index])) return;
      messages[index] = applique;
      state = state.copyWith(messages: messages);
    } finally {
      final derniere = _modificationsEnRelecture.remove(messageId);
      if (mounted && derniere != null && derniere.isAfter(annoncee)) {
        final affiche = state.messages
            .where((m) => m.id == messageId)
            .firstOrNull;
        if (affiche != null &&
            modificationPlusRecente(
              affichee: affiche.editedAt,
              recue: derniere,
            )) {
          unawaited(_relireModification(messageId, derniere));
        }
      }
    }
  }

  Future<void> refresh() async {
    unawaited(_newMessagesSubscription?.cancel());
    await loadInitial();
  }

  void removeMessageOptimistically(String messageId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    existingMessages.removeWhere((m) => m.id == messageId);
    state = state.copyWith(messages: existingMessages);

    // Tout renvoi commence par retirer la copie ratee : c'est donc le point
    // ou l'entree de file correspondante cesse d'etre valable. Si l'envoi
    // echoue de nouveau, il repartira sous un nouvel identifiant temporaire,
    // que `updateMessageStatus` remettra de cote a son tour.
    oublierMessageEnAttente(messageId);
  }

  void markMessageDeletedForMe(String messageId, String userId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      final updatedMessage = message.copyWith(
        deletedFor: [...message.deletedFor, userId],
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
    }
  }

  void markMessageDeletedForEveryone(String messageId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      final updatedMessage = message.copyWith(
        content: 'Message supprimé',
        fileUrl: null,
        audioWaveform: null,
        thumbnailUrl: null,
        deletedForEveryone: true,
        deletedAt: DateTime.now(),
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
    }
  }

  void addOptimisticMessage(MessageEntity message) {
    if (!mounted) return;
    state = state.copyWith(messages: [...state.messages, message]);

    _optimisticTimeouts[message.id] = Timer(
      const Duration(seconds: 30),
      () => _handleOptimisticTimeout(message.id),
    );
  }

  void _handleOptimisticTimeout(String messageId) {
    _optimisticTimeouts.remove(messageId);
    if (!mounted) return;

    final messages = state.messages;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && messages[index].status == MessageStatus.sending) {
      updateMessageStatus(messageId, MessageStatus.failed);
    }
  }

  void _cancelOptimisticTimeout(String messageId) {
    _optimisticTimeouts[messageId]?.cancel();
    _optimisticTimeouts.remove(messageId);
  }

  /// Fusionne l'écho temps réel d'un message qu'on a envoyé dans sa copie locale.
  ///
  /// Adopte l'id réel et les métadonnées du serveur, mais conserve le contenu
  /// déjà déchiffré localement : un message Signal ne peut pas être re-déchiffré
  /// par son propre expéditeur, donc la ligne temps réel remplacerait sinon
  /// notre texte clair par un placeholder.
  ///
  /// ⚠️ Ce filtre ne connaissait QUE « 🔐 Message chiffré ». Les groupes
  /// remontent l'autre placeholder, `[🔐 E2EE — session requise]` : l'écho
  /// passait donc au travers et écrasait le texte clair. Vu sur appareil le
  /// 2026-08-23 — le premier message envoyé dans un groupe devenait illisible
  /// par son propre auteur, une seconde après l'envoi. La liste vit désormais
  /// dans `undecryptable_placeholders.dart`, avec le rechargement paginé qui
  /// s'appuyait déjà dessus (`_healUndecryptable`).
  MessageEntity _reconcileEcho(MessageEntity local, MessageEntity incoming) {
    final content = reconcileEchoContent(
      local: local.content,
      incoming: incoming.content,
    );
    return content == incoming.content
        ? incoming
        : incoming.copyWith(content: content);
  }

  /// Check if an optimistic message matches a new message from the server
  /// For location messages, compare coordinates; for others, compare content
  bool _matchesOptimisticMessage(MessageEntity optimistic, MessageEntity newMessage) {
    // For location messages, match by coordinates (more reliable than content)
    if (optimistic.type == MessageType.location && newMessage.type == MessageType.location) {
      final latMatch = optimistic.latitude != null &&
          newMessage.latitude != null &&
          (optimistic.latitude! - newMessage.latitude!).abs() < 0.0001;
      final lngMatch = optimistic.longitude != null &&
          newMessage.longitude != null &&
          (optimistic.longitude! - newMessage.longitude!).abs() < 0.0001;
      return latMatch && lngMatch;
    }

    // For text messages, content must match exactly
    if (optimistic.type == MessageType.text) {
      return optimistic.content == newMessage.content;
    }

    // For other message types (audio, image, video, file), just match by type
    // since they're already filtered by sender, type, and time window
    return true;
  }

  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    if (!mounted) return;
    MessageEntity? tombeEnEchec;
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        final maj = m.copyWith(status: newStatus);
        if (newStatus == MessageStatus.failed &&
            m.status != MessageStatus.failed) {
          tombeEnEchec = maj;
        }
        return maj;
      }
      return m;
    }).toList();

    state = state.copyWith(messages: messages);

    // Point de passage unique de l'échec : les six endroits qui marquent un
    // message « failed » passent tous par ici. Sans cette mise de côté, le
    // message n'existait qu'en mémoire — et `paginatedMessagesProvider` étant
    // `autoDispose`, quitter l'écran plus de cinq secondes l'effaçait pour de
    // bon, sans que rien ne le signale.
    final aSauver = tombeEnEchec;
    if (aSauver != null) {
      unawaited(mettreDeCoteEnEchec(
        _ref.read(offlineQueueServiceProvider),
        conversationId,
        aSauver,
      ));
    }
  }

  /// Retire un message de la file : il est parti, ou il part sous un autre
  /// identifiant (renvoi), ou l'écho serveur vient de le remplacer.
  void oublierMessageEnAttente(String messageId) {
    unawaited(
      _ref
          .read(offlineQueueServiceProvider)
          .dequeue(messageId)
          .catchError((Object e) => debugPrint('oubli file : $e')),
    );
  }

  /// Remet dans la liste les messages jamais partis, gardés par la file.
  ///
  /// Sans ça, ils disparaissaient de l'écran à la première recharge : leur
  /// identifiant commence par `pending_` ou `temp_`, et seul le second était
  /// réinjecté par [_withPendingLocalMessages] — encore fallait-il que l'état
  /// n'ait pas été jeté entre-temps.
  List<MessageEntity> _avecMessagesJamaisPartis(List<MessageEntity> fresh) {
    final List<PendingMessage> enAttente;
    try {
      enAttente = _ref
          .read(offlineQueueServiceProvider)
          .getPendingForConversation(conversationId);
    } catch (_) {
      return fresh;
    }
    if (enAttente.isEmpty) return fresh;

    final connus = fresh.map((m) => m.id).toSet();
    final rendus = <MessageEntity>[];
    for (final attente in enAttente) {
      if (connus.contains(attente.id)) continue;
      final entite = messageEnAttenteVersEntite(attente);
      if (entite != null) rendus.add(entite);
    }
    if (rendus.isEmpty) return fresh;

    return [...fresh, ...rendus]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Met à jour le statut du message et remplace l'ID optimiste par l'ID réel
  void updateMessageStatusAndCancelTimeout(
    String optimisticId,
    MessageStatus newStatus,
    String realId,
  ) {
    // Annuler le timer de timeout
    _cancelOptimisticTimeout(optimisticId);

    if (!mounted) return;

    final messages = state.messages.map((m) {
      if (m.id == optimisticId) {
        return m.copyWith(
          id: realId,
          status: newStatus,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: messages);
  }

  /// Une réaction par personne et par message : poser un nouvel emoji
  /// remplace le précédent de cet utilisateur ; reposer le même l'enlève.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;
    if (!mounted) return;

    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = state.messages[messageIndex];
    final wasMine = message.reactions[currentUser.id] == emoji;

    final updatedReactions = Map<String, String>.from(message.reactions);
    if (wasMine) {
      updatedReactions.remove(currentUser.id);
    } else {
      updatedReactions[currentUser.id] = emoji;
    }

    final updatedMessage = message.copyWith(reactions: updatedReactions);
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      // Par le repository, et non par la source de données : c'est lui qui
      // sait si ce message est chiffré, donc dans quelle table la réaction
      // doit aller. Écrire dans `messages` pour un message MLS ne touche
      // rien et ne lève rien — la réaction disparaîtrait au rechargement.
      final resultat =
          await _ref.read(messageRepositoryProvider).toggleReaction(
                conversationId: conversationId,
                messageId: messageId,
                userId: currentUser.id,
                emoji: emoji,
                retirer: wasMine,
              );
      resultat.fold((echec) => throw Exception(echec.message), (_) {});
    } catch (e) {
      if (!mounted) return;
      final revertedMessages = List<MessageEntity>.from(state.messages);
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message;
        state = state.copyWith(messages: revertedMessages);
      }
    }
  }

  Future<void> toggleStar(String messageId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = state.messages[messageIndex];
    final isCurrentlyStarred = message.starredBy.contains(currentUser.id);

    final updatedStarredBy = List<String>.from(message.starredBy);
    if (isCurrentlyStarred) {
      updatedStarredBy.remove(currentUser.id);
    } else {
      updatedStarredBy.add(currentUser.id);
    }

    final updatedMessage = message.copyWith(starredBy: updatedStarredBy);
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      // Même raison que pour les réactions : le favori d'un message chiffré
      // vit dans `mls_message_stars`, et seul le repository sait aiguiller.
      final resultat =
          await _ref.read(messageRepositoryProvider).toggleStarMessage(
                conversationId: conversationId,
                messageId: messageId,
                userId: currentUser.id,
              );
      resultat.fold((echec) => throw Exception(echec.message), (_) {});
      _ref.invalidate(starredMessagesProvider(conversationId));
    } catch (e) {
      final revertedMessages = List<MessageEntity>.from(state.messages);
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message;
        state = state.copyWith(messages: revertedMessages);
      }
    }
  }

  /// Mark all messages as read locally for instant UI feedback
  void markAllAsReadLocally(String userId) {
    if (!mounted) return;

    // Avoid any allocation when everything is already marked read.
    final needsUpdate = state.messages.any(
      (m) => !m.readBy.contains(userId) && m.senderId != userId,
    );
    if (!needsUpdate) return;

    final updatedMessages = state.messages.map((message) {
      if (message.readBy.contains(userId) || message.senderId == userId) {
        return message;
      }
      return message.copyWith(
        readBy: [...message.readBy, userId],
        readAt: {...message.readAt, userId: DateTime.now()},
      );
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// Edit a text message (within 25 minute time limit)
  Future<ResultatModification> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      return const ModificationRefusee(MotifModificationImpossible.pasLauteur);
    }

    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) {
      return const ModificationRefusee(
        MotifModificationImpossible.pasEncoreEnvoye,
      );
    }

    final message = state.messages[messageIndex];

    // Le motif, et non un `bool` : c'est lui que l'écran affichera. Refaire le
    // contrôle ici plutôt que se fier au menu — la fenêtre a pu expirer
    // pendant que le composeur était ouvert.
    final motif = message.motifModificationImpossible(currentUser.id);
    if (motif != null) return ModificationRefusee(motif);

    final oldContent = message.content;
    if (newContent == oldContent) return const ModificationSansChangement();

    // Optimistic update
    final updatedMessage = message.copyWith(
      content: newContent,
      editedAt: DateTime.now(),
    );
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      // Par le repository, et non par la source de données : lui seul sait si
      // ce message est chiffré. Le nouveau texte d'un message MLS doit repartir
      // dans un message de contrôle chiffré ; écrit dans `messages`, il ne
      // toucherait aucune ligne et ne lèverait rien — la bulle afficherait le
      // nouveau texte jusqu'au prochain chargement, puis reviendrait à
      // l'ancien.
      final resultat = await _ref.read(messageRepositoryProvider).editMessage(
            conversationId: conversationId,
            messageId: messageId,
            newContent: newContent,
            oldContent: oldContent,
          );
      return resultat.fold<ResultatModification>(
        // Le `Failure` remonte intact : réseau, refus serveur et échec de la
        // passerelle MLS portent chacun leur phrase. L'ancien code les
        // transformait tous en `false`, et l'écran les annonçait « délai de
        // modification expiré » — un mensonge sur trois causes distinctes.
        (echec) {
          _revenirAuTexteDavant(messageIndex, messageId, message);
          return ModificationEchouee(echec);
        },
        (_) => const ModificationReussie(),
      );
    } catch (e) {
      _revenirAuTexteDavant(messageIndex, messageId, message);
      return ModificationEchouee(
        ServerFailure(AppErrorMessages.unexpectedError),
      );
    }
  }

  /// Remet la bulle sur son texte d'avant après un échec.
  ///
  /// L'optimiste a déjà affiché le nouveau texte : sans ce retour en arrière,
  /// l'écran montrerait la modification à côté du message d'erreur qui dit
  /// qu'elle n'a pas eu lieu.
  void _revenirAuTexteDavant(
    int index,
    String messageId,
    MessageEntity avant,
  ) {
    final messages = List<MessageEntity>.from(state.messages);
    if (messages.length > index && messages[index].id == messageId) {
      messages[index] = avant;
      state = state.copyWith(messages: messages);
    }
  }
}

/// Ce qu'a donné une modification de message.
///
/// Un `bool` forçait l'écran à inventer la raison de l'échec : il annonçait
/// « délai expiré » aussi bien pour une coupure réseau que pour un refus
/// serveur ou un échec de la passerelle MLS. Chaque cas remonte désormais
/// tel quel.
sealed class ResultatModification {
  const ResultatModification();
}

/// Le texte est parti et la ligne est à jour.
class ModificationReussie extends ResultatModification {
  const ModificationReussie();
}

/// Rien à faire : le texte est identique à celui d'avant.
class ModificationSansChangement extends ResultatModification {
  const ModificationSansChangement();
}

/// Le geste n'était pas permis — voir [motif].
class ModificationRefusee extends ResultatModification {
  final MotifModificationImpossible motif;
  const ModificationRefusee(this.motif);
}

/// Le geste était permis mais l'écriture a échoué — voir [echec].
class ModificationEchouee extends ResultatModification {
  final Failure echec;
  const ModificationEchouee(this.echec);
}

// ============ Notifier pour envoyer des messages ============

/// Enregistre un message en échec dans la file hors ligne, pour qu'il
/// survive à la fermeture de l'écran et puisse repartir plus tard.
///
/// Ouvre la file avant de la consulter : `isInQueue` lit la boîte Hive, qui
/// n'est ouverte que par `init()` — sans lui, la question « déjà en file ? »
/// répondait toujours non, et un même message pouvait entrer deux fois.
///
/// [ecritLe] : quand le message a été écrit, s'il l'a été avant cet envoi —
/// c'est la date que compare [kFenetreRenvoiAutomatique]. Un renvoi recrée le
/// message sous un nouvel identifiant, daté de maintenant ; sans cette date
/// d'origine, chaque essai raté repoussait la fenêtre de 24 h, et un message
/// écrit il y a trois jours pouvait partir à l'improviste. Une entrée déjà en
/// file avec une date plus récente (mise de côté par le délai de 30 s de
/// l'écran, avant l'échec définitif) est corrigée.
Future<void> mettreDeCoteEnEchec(
  OfflineQueueService file,
  String conversationId,
  MessageEntity message, {
  DateTime? ecritLe,
}) async {
  try {
    await file.init();
    if (file.isInQueue(message.id)) {
      if (ecritLe == null) return;
      final deja = file.getQueue().firstWhere((m) => m.id == message.id);
      if (!deja.createdAt.isAfter(ecritLe)) return;
      await file.dequeue(deja.id);
      await file.enqueue(PendingMessage(
        id: deja.id,
        conversationId: deja.conversationId,
        senderId: deja.senderId,
        senderName: deja.senderName,
        senderPhotoUrl: deja.senderPhotoUrl,
        content: deja.content,
        type: deja.type,
        filePath: deja.filePath,
        createdAt: ecritLe,
        retryCount: deja.retryCount,
        messageJson: deja.messageJson,
      ));
      return;
    }
    await file.enqueue(
      PendingMessage(
        id: message.id,
        conversationId: conversationId,
        senderId: message.senderId,
        senderName: message.senderName,
        senderPhotoUrl: message.senderPhotoUrl,
        content: message.content,
        type: message.type.name,
        filePath: message.localFilePath,
        createdAt: ecritLe ?? message.createdAt,
        messageJson: jsonEncode(MessageModel.fromEntity(message).toJson()),
      ),
    );
  } catch (e) {
    debugPrint('mise de côté du message en échec : $e');
  }
}

/// L'échec **définitif** d'un envoi — point de passage unique des cinq
/// méthodes d'envoi de [SendMessageNotifier].
///
/// L'échec arrive après les nouvelles tentatives, donc souvent des secondes
/// après le tap. Si l'utilisateur a quitté la discussion entre-temps,
/// l'écran (`paginatedMessagesProvider`, autoDispose) n'existe plus : le lire
/// en recréait une instance **vide**, `updateMessageStatus` n'y trouvait pas
/// le message, et rien ne le mettait de côté. Le message était perdu sans
/// aucune trace — ni bulle rouge à la réouverture, ni nouvel essai.
///
/// Désormais le message part d'abord dans la file, puis l'écran — s'il
/// existe encore — passe la bulle en échec ; sa propre mise de côté trouve
/// alors l'entrée déjà là. On ne lit l'écran que s'il existe : le lire sinon
/// en ressusciterait un, vide, avec tout son chargement réseau.
///
/// [ecritLe] : voir [mettreDeCoteEnEchec].
Future<void> signalerEnvoiEnEchec(
  Ref ref,
  String conversationId,
  MessageEntity optimiste, {
  DateTime? ecritLe,
}) async {
  await mettreDeCoteEnEchec(
    ref.read(offlineQueueServiceProvider),
    conversationId,
    optimiste.copyWith(status: MessageStatus.failed),
    ecritLe: ecritLe,
  );
  final ecran = paginatedMessagesProvider(conversationId);
  if (ref.exists(ecran)) {
    ref.read(ecran.notifier).updateMessageStatus(
          optimiste.id,
          MessageStatus.failed,
        );
  }
}
