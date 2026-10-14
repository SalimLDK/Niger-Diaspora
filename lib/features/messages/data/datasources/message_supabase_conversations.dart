part of 'message_supabase_datasource.dart';

/// Discussions : création, recherche, lecture, réglages, administration de groupe.
mixin _Conversations on _MessageSupabaseBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATIONS — CREATE / FIND
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session introuvable');
      }

      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      if (existing != null) return existing;

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final convData = <String, dynamic>{
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'individual',
        'participant_ids': [currentUserId, otherUserId],
        'created_by': currentUserId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'individual',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createIndividualConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> getOrCreateSelfConversation({
    required String userId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session introuvable');
      }

      // Cherche la conversation dont l'utilisateur est le SEUL participant.
      //
      // La requête demandait auparavant `contains` — donc toute conversation
      // individuelle où l'utilisateur figure — bornée à 20 et **sans tri**,
      // puis parcourait le lot à la recherche de celle à un seul participant.
      // Passé 20 conversations individuelles, la bonne pouvait ne pas être
      // dans le lot : le code concluait alors qu'elle n'existait pas et en
      // créait une **seconde**, juste en dessous. Sans tri, le lot changeait
      // d'un appel à l'autre, donc le défaut était intermittent — le pire
      // profil pour être remarqué.
      //
      // `eq` sur une colonne tableau est une égalité exacte côté PostgREST
      // (`participant_ids=eq.{uid}`, voir `postgrest`) : elle isole la ligne
      // cherchée, sans troncature ni parcours.
      //
      // Le tri et le `limit(1)` ne servent pas à choisir : ils tolèrent les
      // doublons que ce bug a pu créer par le passé, en retenant toujours le
      // plus ancien — c'est-à-dire la conversation d'origine.
      final row = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'individual')
          .eq('participant_ids', [userId])
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        final data = Map<String, dynamic>.from(row['data'] as Map? ?? {});
        return ConversationModel.fromJson({
          ...data,
          'id': row['id'],
          'type': row['type'],
          'participantIds': [userId],
          'createdBy': row['created_by'],
          'createdAt': row['created_at'],
        });
      }

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final convData = <String, dynamic>{
        'unreadCount': {userId: 0},
        'name': 'Mes notes',
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'individual',
        'participant_ids': [userId],
        'created_by': userId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'individual',
        'participantIds': [userId],
        'createdBy': userId,
        'createdAt': now,
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('getOrCreateSelfConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session introuvable');
      }

      // Priority 1: find by groupId
      if (groupId != null) {
        final existing = await findGroupConversationByGroupId(
          groupId: groupId,
          userId: creatorId,
        );
        if (existing != null) return existing;
      }

      final allParticipants = ({...participantIds, creatorId}).toList()..sort();
      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final unreadCount = <String, int>{
        for (final id in allParticipants) id: 0,
      };

      final convData = <String, dynamic>{
        'name': groupName,
        if (groupImageUrl != null) 'imageUrl': groupImageUrl,
        if (groupId != null) 'groupId': groupId,
        'adminIds': [creatorId],
        'unreadCount': unreadCount,
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'group',
        'participant_ids': allParticipants,
        'group_id': groupId,
        'created_by': creatorId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'group',
        'participantIds': allParticipants,
        'createdBy': creatorId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createGroupConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> createIndividualConversationAsRequest({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session introuvable');
      }

      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );

      if (existing != null) {
        if (existing.requestStatus == 'declined') {
          await _mergeConvData(existing.id, {
            'requestStatus': 'pending',
            'requesterId': currentUserId,
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
            'respondedAt': null,
          });
          return existing.copyWith(
            requestStatus: 'pending',
            requesterId: currentUserId,
          );
        }
        return existing;
      }

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final convData = <String, dynamic>{
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'requestStatus': 'pending',
        'requesterId': currentUserId,
        'requestedAt': now,
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'request',
        'participant_ids': [currentUserId, otherUserId],
        'created_by': currentUserId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'request',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createIndividualConversationAsRequest error: $e');
    }
  }

  @override
  Future<ConversationModel?> findIndividualConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // On cherche parmi les 1:1 « normales » (individual) ET les demandes
      // (request) : une demande acceptée garde type='request', et sans ça
      // getOrCreateIndividualConversation en recréerait une seconde ligne
      // 'individual' → le même contact apparaîtrait deux fois dans la liste.
      final rows = await _supabase
          .from('conversations')
          .select()
          .inFilter('type', ['individual', 'request'])
          .contains('participant_ids', [userId1, userId2]);

      ConversationModel? requestMatch;
      for (final row in rows) {
        final ids = List<String>.from(row['participant_ids'] as List? ?? []);
        if (ids.length == 2 && ids.contains(userId1) && ids.contains(userId2)) {
          // Une vraie conversation 'individual' est prioritaire ; sinon on
          // réutilise la ligne 'request' au lieu d'en créer une nouvelle.
          if (row['type'] == 'individual') {
            return _convFromRow(row);
          }
          requestMatch ??= _convFromRow(row);
        }
      }
      return requestMatch;
    } catch (e) {
      throw ServerException('findIndividualConversation error: $e');
    }
  }

  @override
  Future<ConversationModel?> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'group')
          .contains('participant_ids', [userId]);

      for (final row in rows) {
        final data = (row['data'] as Map<String, dynamic>?) ?? {};
        if (data['name'] == groupName) return _convFromRow(row);
      }
      return null;
    } catch (e) {
      throw ServerException('findGroupConversationByName error: $e');
    }
  }

  /// Vrai si [value] est un UUID. Les groupes créés avant la migration vers
  /// Supabase portent un identifiant Firestore de 20 caractères, que les
  /// colonnes et fonctions typées `uuid` refusent.
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String value) => _uuidPattern.hasMatch(value);

  @override
  Future<ConversationModel?> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException(
          'Session non établie – reconnectez-vous',
        );
      }
      // `join_group_conversation` compare `group_members.group_id` (UUID) à
      // son paramètre TEXT via un cast inconditionnel `p_group_id::uuid`. Un
      // groupe hérité de Firestore porte un id de 20 caractères qui n'est pas
      // un UUID : le cast lève `22P02` et l'exception remontait jusqu'en haut,
      // rendant la discussion de ces groupes impossible à ouvrir. Ces groupes
      // n'ont de toute façon aucune ligne dans `group_members`, donc la RPC
      // aurait rendu NULL — on la court-circuite au lieu de la faire échouer.
      //
      // Mais rendre `null` ici ne suffisait pas : l'appelant
      // (`createGroupConversation`) enchaîne alors sur un INSERT, donc CHAQUE
      // ouverture de la discussion créait une conversation de plus et
      // fragmentait l'historique — l'écran affichait « Aucun message » alors
      // que les messages vivaient dans une conversation précédente (constaté
      // le 2026-08-05 sur `yflqsRLMMhTPpiW0NFHx` : 3 lignes en une session).
      // `conversations.group_id` étant TEXT, la conversation existante se
      // retrouve directement, sans cast et sans RPC.
      if (!_isUuid(groupId)) {
        return await _findLegacyGroupConversation(groupId);
      }

      // RPC SECURITY DEFINER : localise la conversation du groupe SANS filtrer
      // par participant_ids (sinon un membre ayant rejoint le groupe après sa
      // création — le cas courant — ne la retrouvait jamais, et
      // createGroupConversation en recréait une par-dessus, en double).
      // La fonction vérifie l'appartenance réelle (group_members) puis
      // (ré)ajoute userId aux participants si besoin.
      final convId =
          await _supabase.rpc(
                'join_group_conversation',
                params: {'p_group_id': groupId},
              )
              as String?;
      // La RPC rend NULL aussi bien quand la conversation n'existe pas que
      // quand l'appelant n'est pas (encore) dans `group_members` — cas d'un
      // groupe dont l'appartenance vit encore côté Firestore. Dernier filet
      // avant création : si l'appelant est déjà participant d'une conversation
      // de ce groupe, on la réutilise au lieu d'en ajouter une en double.
      if (convId == null) return await _findLegacyGroupConversation(groupId);

      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('id', convId)
          .limit(1);
      if (rows.isEmpty) return null;
      return _convFromRow(rows.first);
    } catch (e) {
      throw ServerException('findGroupConversationByGroupId error: $e');
    }
  }

  /// Conversation d'un groupe hérité de Firestore (id non-UUID), retrouvée par
  /// la colonne TEXT `conversations.group_id` — ni la RPC ni `group_members`
  /// (tous deux typés `uuid`) ne peuvent servir pour ces groupes.
  ///
  /// La plus ANCIENNE est retenue : c'est celle qui porte l'historique, les
  /// éventuels doublons déjà en base ayant été créés par-dessus.
  ///
  /// Limite assumée : la policy SELECT de `conversations` est
  /// `participant_ids @> [firebase_uid()]`, donc un membre qui n'est pas encore
  /// participant ne verra RIEN ici et l'appelant recréera une conversation.
  /// La RPC SECURITY DEFINER règle ce cas pour les groupes Supabase en
  /// vérifiant `group_members` ; pour un groupe hérité cette table est vide
  /// (appartenance restée côté Firestore), et une RPC qui ajouterait l'appelant
  /// sans pouvoir vérifier son appartenance ouvrirait n'importe quelle
  /// conversation de groupe hérité à n'importe qui. À traiter avec la
  /// migration des groupes hérités, pas ici.
  Future<ConversationModel?> _findLegacyGroupConversation(
    String groupId,
  ) async {
    final rows = await _supabase
        .from('conversations')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .limit(1);
    if (rows.isEmpty) return null;
    return _convFromRow(rows.first);
  }

  @override
  Future<ConversationModel?> getConversationById(String conversationId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .limit(1);

      if (rows.isEmpty) return null;
      return _convFromRow(rows.first);
    } catch (e) {
      throw ServerException('getConversationById error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARK AS READ / UNREAD MENTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase.rpc(
        'mark_messages_as_delivered',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );

      // Et l'aperçu de la conversation, dans la même instruction que la
      // lecture (`modifier_donnees_conversation`, 20261005100000) : relire
      // la liste pour y ajouter [userId] effaçait un autre destinataire
      // livré au même moment.
      await _supabase.rpc('modifier_donnees_conversation', params: {
        'p_conversation_id': conversationId,
        'p_ajouts': {'lastMessageDeliveredTo': userId},
      });
    } catch (e) {
      // Non-critical: delivery tracking best-effort
      debugPrint('markAsDelivered error: $e');
    }
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    // Accusés de lecture par message (data.readBy/readAt), distincts des
    // accusés de livraison écrits par markAsDelivered. Best-effort et isolé
    // du reste : ne doit pas faire échouer la mise à jour lastMessageReadBy
    // ci-dessous si la RPC est indisponible (ex. migration pas encore
    // déployée).
    try {
      await _supabase.rpc(
        'mark_messages_as_read',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('mark_messages_as_read RPC error: $e');
    }

    // Les notifications de la discussion : la RPC le fait aussi depuis
    // 20260912200000, ceci couvre la base tant que la migration n'est pas
    // appliquée. Idempotent.
    unawaited(
      // Sans filtre de type : messages ET réactions (`messageReaction`)
      // portent `conversationId`, rien d'autre ne le porte.
      NotificationReadSync.markTargetRead(
        conversationId,
        keys: const ['conversationId'],
      ),
    );

    // Une instruction (`modifier_donnees_conversation`, 20261005100000) :
    // relire `lastMessageReadBy` pour y ajouter [userId] puis réécrire
    // effaçait un lecteur — ou un message — arrivé entre les deux.
    try {
      await _supabase.rpc('modifier_donnees_conversation', params: {
        'p_conversation_id': conversationId,
        'p_fusion': {
          'unreadCount': {userId: 0},
        },
        'p_ajouts': {'lastMessageReadBy': userId},
      });
    } catch (e) {
      throw ServerException('markAsRead error: $e');
    }
  }

  @override
  Future<void> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _mergeConvData(conversationId, {
        'unreadMentions': {userId: 0},
      }, merge: true);
    } catch (e) {
      throw ServerException('clearUnreadMentions error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATION MUTATIONS (archive, mute, pin, delete, restore)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _mergeConvData(conversationId, {
      'archivedBy': {userId: true},
    }, merge: true);
  }

  @override
  Future<void> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'archivedBy', userId);
  }

  @override
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  }) async {
    final muteValue =
        duration == null
            ? 'forever'
            : DateTime.now().add(duration).toUtc().toIso8601String();
    await _mergeConvData(conversationId, {
      'mutedBy': {userId: muteValue},
    }, merge: true);
  }

  @override
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'mutedBy', userId);
  }

  @override
  Future<void> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    final count = await getPinnedConversationCount(userId);
    if (count >= 5) {
      throw ServerException(
        'Vous ne pouvez pas épingler plus de 5 conversations',
      );
    }
    await _mergeConvData(conversationId, {
      'pinnedBy': {userId: DateTime.now().toUtc().toIso8601String()},
    }, merge: true);
  }

  @override
  Future<void> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'pinnedBy', userId);
  }

  @override
  Future<int> getPinnedConversationCount(String userId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .contains('participant_ids', [userId]);

      return rows.where((row) {
        final data = (row['data'] as Map<String, dynamic>?) ?? {};
        final pinnedBy = data['pinnedBy'] as Map?;
        return pinnedBy != null && pinnedBy.containsKey(userId);
      }).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  }) async {
    try {
      if (forEveryone) {
        final conv = await getConversationById(conversationId);
        if (conv == null) return;

        final isAdmin = conv.adminIds.contains(userId);
        final isCreator = conv.createdBy == userId;
        if (!isAdmin && !isCreator) {
          throw ServerException(
            "Seul l'administrateur ou le créateur peut supprimer pour tout le monde.",
          );
        }

        // Hard delete (cascade deletes messages)
        await _supabase.from('conversations').delete().eq('id', conversationId);
      } else {
        final now = DateTime.now().toUtc().toIso8601String();
        await _mergeConvData(conversationId, {
          'deletedBy': {userId: now},
          'unreadCount': {userId: 0},
        }, merge: true);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('deleteConversation error: $e');
    }
  }

  @override
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'deletedBy', userId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP ADMIN
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Les trois actions de gestion des membres passent par une RPC
  // `SECURITY DEFINER` (migration `20260917013200`). Trois raisons, et aucune
  // n'est cosmétique :
  //
  // 1. **La notice dans le fil ne peut venir que du serveur.** La policy
  //    `messages_insert` exige `firebase_uid() = sender_id` et aucun compte ne
  //    s'appelle `system` ; une conversation basculée refuse même avant, par
  //    `messages_refuse_conversation_mls_trg` (23514). `sendSystemMessage`,
  //    placé en tête de `removeUserFromGroup`, empêchait donc TOUTE exclusion —
  //    7b3794f l'a retiré, sans notice de remplacement. La RPC l'écrit sous son
  //    propriétaire, et **seulement hors MLS** : en clair dans une conversation
  //    chiffrée, la notice dirait au serveur ce que le chiffrement lui tait.
  //
  // 2. **Promouvoir et rétrograder ne changeaient rien de visible.** Ce code
  //    n'écrivait que `conversations.data.adminIds`. Or la fiche des membres
  //    lit le badge « admin » dans `group_members.role`, et c'est aussi ce que
  //    lit `is_group_admin()` — donc les droits réels. Mesuré le 2026-09-17 :
  //    les deux listes divergent déjà en production. Un membre « promu »
  //    n'avait ni badge ni menu de gestion ; un « rétrogradé » gardait tous ses
  //    droits. La RPC écrit les deux.
  //
  // 3. **Exclure quelqu'un qui n'a jamais ouvert la discussion réussissait à
  //    vide** : absent de `participant_ids`, la mise à jour ne retirait rien et
  //    `conversations_sync_group_removal` ne voyait aucun départ. La RPC
  //    supprime aussi la ligne `group_members`.
  //
  // Plus de repli sur `PGRST202` (fonction absente) : il réécrivait
  // `participant_ids` et `data` en « lire, modifier, réécrire ». La migration
  // 20260917013200 précède 20261004100000, dont l'app dépend déjà — `db push`
  // les applique dans l'ordre : l'absence n'est plus une étape de déploiement.
  //
  // Banc serveur : `tools/rls_tests/notices_de_groupe.sql`.

  @override
  Future<void> promoteToAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase.rpc(
        'nommer_admin_du_groupe',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw ServerException('promoteToAdmin error: ${e.message}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('promoteToAdmin error: $e');
    }
  }

  @override
  Future<void> demoteFromAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase.rpc(
        'retirer_admin_du_groupe',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw ServerException('demoteFromAdmin error: ${e.message}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('demoteFromAdmin error: $e');
    }
  }

  /// Exclut [userId] du groupe : `participant_ids`, `data.adminIds` **et** la
  /// ligne `group_members`, plus la notice dans le fil si la conversation n'est
  /// pas basculée en MLS. Tout est fait par `exclure_du_groupe`, en une seule
  /// transaction serveur (voir le pavé de la section).
  ///
  /// La RPC rend `false` quand il n'y avait plus personne à retirer — double
  /// appui, ou un autre administrateur plus rapide. Ce n'est pas une erreur :
  /// l'état voulu est atteint. Elle **lève** en revanche 42501 si l'appelant
  /// n'a pas le droit et 22023 sur soi-même ; l'écran affiche alors « Erreur
  /// lors du retrait », ce qui est juste.
  ///
  /// `MlsGateway.appartenanceChangee` reste au client : l'arbre MLS ne se
  /// réécrit pas en SQL.
  @override
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase.rpc(
        'exclure_du_groupe',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw ServerException('removeUserFromGroup error: ${e.message}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('removeUserFromGroup error: $e');
    }
  }
}
