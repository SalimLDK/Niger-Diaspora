part of 'message_provider.dart';

// Actions ponctuelles : création de discussion, notes, lecture, suppression,
// demandes de message.

final createConversationProvider = StateNotifierProvider<CreateConversationNotifier, AsyncValue<ConversationEntity?>>(
  (ref) => CreateConversationNotifier(ref),
);

class CreateConversationNotifier extends StateNotifier<AsyncValue<ConversationEntity?>> {
  final Ref _ref;

  CreateConversationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<ConversationEntity?> createIndividual(String otherUserId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return null;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).getOrCreateIndividualConversation(
      currentUserId: currentUser.id,
      otherUserId: otherUserId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (conversation) {
        state = AsyncValue.data(conversation);
        return conversation;
      },
    );
  }

  Future<ConversationEntity?> createGroup({
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId,
  }) async {
    // `currentUserAsyncProvider` est un StreamProvider **autoDispose** que cet
    // appel ne regarde jamais : `read(...).valueOrNull` démarrait l'abonnement
    // à l'instant du tap et rendait `AsyncLoading`, donc `null`. « Ouvrir la
    // discussion » (fiche de groupe) était alors un bouton MORT — abandon
    // silencieux, `state` jamais mis en erreur, donc un SnackBar « Erreur lors
    // de l'ouverture de la discussion » sans la moindre cause, et rien dans
    // logcat. Vérifié sur appareil le 2026-08-05. Même piège, déjà rencontré et
    // commenté, que `_createGroup` de `create_group_screen.dart` : on attend la
    // première émission.
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = AsyncValue.error(
        'Session expirée — reconnectez-vous.',
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).createGroupConversation(
      creatorId: currentUser.id,
      participantIds: participantIds,
      groupName: groupName,
      groupImageUrl: groupImageUrl,
      groupId: groupId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (conversation) {
        state = AsyncValue.data(conversation);
        return conversation;
      },
    );
  }
}

// ============ Mes notes (self-chat) ============

/// Renvoie la conversation « Mes notes » déjà existante dans la liste, sans
/// déclencher de création. Sert à l'affichage instantané (badge, aperçu).
final selfNotesConversationProvider = Provider<ConversationEntity?>((ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) return null;
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
  for (final conv in conversations) {
    if (conv.isSelfNotesFor(currentUser.id)) return conv;
  }
  return null;
});

/// Obtient ou crée la conversation « Mes notes » de l'utilisateur (self-chat).
/// Appelé à la demande (au tap sur l'entrée « Mes notes »).
final ensureSelfNotesProvider =
    StateNotifierProvider<EnsureSelfNotesNotifier, AsyncValue<ConversationEntity?>>(
  (ref) => EnsureSelfNotesNotifier(ref),
);

class EnsureSelfNotesNotifier extends StateNotifier<AsyncValue<ConversationEntity?>> {
  final Ref _ref;

  EnsureSelfNotesNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Ouvre « Mes notes » : sans attendre quand le serveur a déjà confirmé,
  /// par [ensure] sinon.
  ///
  /// Toutes les autres discussions de la liste s'ouvrent d'un `context.push`
  /// synchrone. « Mes notes » était la seule à faire un aller-retour **avant**
  /// de pousser l'écran : un spinner sur la tuile à chaque ouverture, et la
  /// tuile intouchable le temps de la requête.
  ///
  /// Le raccourci d'origine, retiré le 2026-08-06, faisait confiance au
  /// **cache Hive** : une conversation effacée côté serveur y reste, on
  /// ouvrait un document fantôme, et tout envoi échouait ensuite
  /// (« Non envoyé · Réessayer »). C'est cette source-là qui était fautive,
  /// pas le principe du raccourci — [conversationsDepuisReseauProvider]
  /// distingue maintenant les deux, et seule celle du serveur fait passer.
  Future<ConversationEntity?> ouvrir() async {
    final sure = conversationSure(
      listeDepuisReseau: _ref.read(conversationsDepuisReseauProvider),
      deLaListe: _ref.read(selfNotesConversationProvider),
      deLaDerniereReponse: state.valueOrNull,
    );
    if (sure != null) return sure;
    return ensure();
  }

  /// La règle seule, sans providers — pour pouvoir la tenir par un test.
  ///
  /// `null` = rien de sûr sous la main, il faut interroger le serveur.
  @visibleForTesting
  static ConversationEntity? conversationSure({
    required bool listeDepuisReseau,
    required ConversationEntity? deLaListe,
    required ConversationEntity? deLaDerniereReponse,
  }) {
    // La liste vivante d'abord : c'est la seule des deux sources qui sache
    // qu'une conversation vient d'être supprimée. Son `null` n'est donc pas
    // une ignorance, c'est une absence constatée — à [ensure] de créer.
    if (listeDepuisReseau) return deLaListe;
    // Liste encore sur sa copie Hive (démarrage à froid, hors ligne) : la
    // dernière réponse du serveur obtenue dans cette session fait foi. Le
    // notifier n'est pas `autoDispose`, elle vaut pour tout le processus.
    return deLaDerniereReponse;
  }

  Future<ConversationEntity?> ensure() async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return null;

    // ⚠ Ne PAS court-circuiter avec la conversation déjà en cache.
    //
    // Ce raccourci existait pour éviter un aller-retour : si « Mes notes »
    // figurait dans la liste, on la renvoyait telle quelle. Mais la liste et le
    // document peuvent diverger — document effacé côté serveur, liste encore
    // chaude. On ouvrait alors l'écran sur un document fantôme : la lecture
    // rendait « Ce groupe a été supprimé » et **tout envoi échouait**
    // (« Non envoyé · Réessayer », observé sur appareil le 2026-08-06).
    //
    // `getOrCreateSelfConversation` est justement idempotent : il retrouve la
    // conversation si elle existe, la recrée sinon.
    //
    // Ce garde-fou vaut toujours, et [ouvrir] ne le contredit pas : le
    // raccourci qu'elle rétablit ne lit jamais le cache, seulement une liste
    // dont [conversationsDepuisReseauProvider] atteste qu'elle vient du flux
    // vivant. Quand cette attestation manque, on retombe ici.
    state = const AsyncValue.loading();
    final result = await _ref
        .read(messageRepositoryProvider)
        .getOrCreateSelfConversation(userId: currentUser.id);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (conversation) {
        state = AsyncValue.data(conversation);
        // Invalider reconstruit tout l'abonnement temps réel de la liste :
        // ne le faire que lorsqu'elle ignore la conversation, c'est-à-dire
        // quand `getOrCreate` vient réellement de la créer. Le cas courant —
        // elle existait déjà — ne coûte plus rien.
        if (_ref.read(selfNotesConversationProvider)?.id != conversation.id) {
          _ref.invalidate(conversationsProvider);
        }
        return conversation;
      },
    );
  }
}

// ============ Message par id ============

/// Message précis (déchiffré), même hors de la fenêtre paginée — utilisé par
/// le bandeau épinglé pour résoudre le contenu d'un message épinglé ancien.
final messageByIdProvider = FutureProvider.family<
    MessageEntity?, ({String conversationId, String messageId})>((ref, params) async {
  final result = await ref.watch(messageRepositoryProvider).getMessageById(
        conversationId: params.conversationId,
        messageId: params.messageId,
      );
  return result.fold((_) => null, (m) => m);
});

// ============ Marquer comme lu ============

final markAsReadProvider = StateNotifierProvider<MarkAsReadNotifier, AsyncValue<void>>(
  (ref) => MarkAsReadNotifier(ref),
);

class MarkAsReadNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MarkAsReadNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> mark(String conversationId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final userId = currentUser.id;

    // Update local state immediately for instant UI feedback
    try {
      final notifier = _ref.read(paginatedMessagesProvider(conversationId).notifier);
      notifier.markAllAsReadLocally(userId);
    } catch (_) {
      // Provider might not be active, that's OK
    }

    // Then sync to server
    await _ref.read(messageRepositoryProvider).markAsRead(
      conversationId: conversationId,
      userId: userId,
    );

    // Sync notification dismiss to other devices
    _syncDismissToOtherDevices(conversationId);
  }

  /// Syncs notification dismiss to other devices via Cloud Function
  /// This is fire-and-forget - we don't wait for the result
  void _syncDismissToOtherDevices(String conversationId) {
    // Run in background without awaiting
    unawaited(Future(() async {
      try {
        // Get current FCM token
        final currentToken = await FirebaseMessaging.instance.getToken();

        // Call Cloud Function to sync dismiss to other devices
        await FirebaseFunctions.instance
            .httpsCallable('dismissConversationNotifications')
            .call({
          'conversationId': conversationId,
          'currentToken': currentToken,
        });

        debugPrint('MarkAsRead: Synced dismiss to other devices for $conversationId');
      } catch (e) {
        // Silently fail - this is best-effort sync
        debugPrint('MarkAsRead: Failed to sync dismiss: $e');
      }
    }));
  }
}

// ============ Marquer comme livré ============

final markAsDeliveredProvider = StateNotifierProvider<MarkAsDeliveredNotifier, AsyncValue<void>>(
  (ref) => MarkAsDeliveredNotifier(ref),
);

class MarkAsDeliveredNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MarkAsDeliveredNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> mark(String conversationId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    await _ref.read(messageRepositoryProvider).markAsDelivered(
      conversationId: conversationId,
      userId: currentUser.id,
    );
  }
}

// ============ Nombre total de messages non lus ============

final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
  final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
  final quiMOntBloque =
      ref.watch(usersWhoBlockedMeProvider).valueOrNull ?? const <String>{};

  if (currentUser == null) return 0;

  return conversations.fold<int>(0, (total, conv) {
    if (conv.isIndividual) {
      final otherUserId = conv.getOtherParticipantId(currentUser.id);

      if (blockedUserIds.contains(otherUserId)) {
        return total;
      }

      // `otherProfile.blockedByUserIds.contains(moi)` disait « j'ai bloque
      // l'autre » — deja teste juste au-dessus — sur un champ toujours vide.
      if (quiMOntBloque.contains(otherUserId)) {
        return total;
      }
    }

    return total + conv.getUnreadCountFor(currentUser.id);
  });
});

// ============ Notifier pour supprimer des messages ============

final deleteMessageProvider = StateNotifierProvider<DeleteMessageNotifier, AsyncValue<void>>(
  (ref) => DeleteMessageNotifier(ref),
);

class DeleteMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DeleteMessageNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> deleteForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    _ref.read(paginatedMessagesProvider(conversationId).notifier).markMessageDeletedForMe(messageId, currentUser.id);

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).deleteMessageForMe(
      conversationId: conversationId,
      messageId: messageId,
      userId: currentUser.id,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        _ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  /// « Supprimer pour moi » sur une sélection : le même chemin que
  /// [deleteForMe], message par message.
  ///
  /// La sélection passait par `MessageDeletionService.deleteMultipleForMe`,
  /// qui écrivait `deletedFor` dans **Firebase RTDB** — que plus rien ne lit
  /// depuis la migration vers Supabase. L'écran masquait localement, puis les
  /// messages revenaient au rechargement.
  ///
  /// Rend le nombre de messages réellement supprimés. Au premier échec,
  /// l'écran est relu (les masquages locaux non suivis d'effet disparaissent)
  /// et l'erreur est posée dans [state].
  Future<int> deleteManyForMe({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return 0;

    state = const AsyncValue.loading();
    final ecran = _ref.read(paginatedMessagesProvider(conversationId).notifier);
    var supprimes = 0;
    for (final messageId in messageIds) {
      ecran.markMessageDeletedForMe(messageId, currentUser.id);
      final result = await _ref.read(messageRepositoryProvider).deleteMessageForMe(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUser.id,
      );
      final echec = result.fold((f) => f, (_) => null);
      if (echec != null) {
        state = AsyncValue.error(echec.message, StackTrace.current);
        _ref.invalidate(paginatedMessagesProvider(conversationId));
        return supprimes;
      }
      supprimes++;
    }
    state = const AsyncValue.data(null);
    return supprimes;
  }

  Future<bool> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    _ref.read(paginatedMessagesProvider(conversationId).notifier).markMessageDeletedForEveryone(messageId);

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).deleteMessageForEveryone(
      conversationId: conversationId,
      messageId: messageId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        _ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

// ============ Messages favoris ============

/// `autoDispose` : sans lui, la liste était calculée une fois par processus.
/// Retirer une étoile laissait le message dans la liste jusqu'à la relance
/// de l'app (vu sur SM A515F le 2026-09-22). [PaginatedMessagesNotifier.toggleStar]
/// l'invalide aussi, pour le cas où l'écran des favoris reste dans la pile.
final starredMessagesProvider = FutureProvider.autoDispose.family<List<MessageEntity>, String>((ref, conversationId) async {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return [];

  final result = await ref.read(messageRepositoryProvider).getStarredMessages(
    conversationId: conversationId,
    userId: currentUser.id,
  );

  return result.fold(
    (failure) => <MessageEntity>[],
    (messages) => messages,
  );
});

// ============ Recherche de messages ============

final messageSearchProvider = FutureProvider.family<List<MessageEntity>, ({String conversationId, String query})>((ref, params) async {
  if (params.query.length < 2) return [];

  final result = await ref.read(messageRepositoryProvider).searchMessagesInConversation(
    conversationId: params.conversationId,
    query: params.query,
  );

  return result.fold(
    (failure) => <MessageEntity>[],
    (messages) => messages,
  );
});

// ============ MESSAGE REQUESTS (Zone Tampon) ============

/// Stream of pending message requests for the current user
final messageRequestsProvider = StreamProvider<List<ConversationEntity>>((ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(messageRepositoryProvider);
  return repository.getMessageRequests(currentUser.id).map((result) {
    return result.fold(
      (failure) => <ConversationEntity>[],
      (requests) => requests,
    );
  });
});

/// Count of pending message requests
final messageRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(messageRequestsProvider).valueOrNull ?? [];
  return requests.length;
});

/// Notifier for message request actions (accept/decline)
final messageRequestActionsProvider =
    StateNotifierProvider<MessageRequestActionsNotifier, AsyncValue<void>>((ref) {
  return MessageRequestActionsNotifier(ref);
});

class MessageRequestActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MessageRequestActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Accept a message request
  Future<bool> acceptRequest(String conversationId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).acceptMessageRequest(
      conversationId: conversationId,
      recipientId: currentUser.id,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Invalidate conversations to refresh the list
        _ref.invalidate(conversationsProvider);
        return true;
      },
    );
  }

  /// Decline a message request
  Future<bool> declineRequest(String conversationId) async {
    final currentUser = await _ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).declineMessageRequest(
      conversationId: conversationId,
      recipientId: currentUser.id,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

// ============ Messages jamais partis : garde et renvoi ============
