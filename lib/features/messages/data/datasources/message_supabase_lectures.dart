part of 'message_supabase_datasource.dart';

/// Lectures ponctuelles : pagination, recherche, minuteur, demandes de message.
mixin _Lectures on _MessageSupabaseBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? beforeCreatedAt,
    DateTime? filterAfterDate,
  }) async {
    // Un id sans sa date ne se compare à rien. C'était le défaut : l'id
    // (uuid) du plus ancien message partait dans `.lt('created_at', …)`,
    // Postgres refusait (22007), et aucune page plus ancienne ne se chargeait
    // jamais — au-delà de 30 messages, l'historique était inaccessible.
    if (lastMessageKey != null && beforeCreatedAt == null) {
      throw ArgumentError(
        'getMessagesPaginated : curseur incomplet, beforeCreatedAt requis '
        'avec lastMessageKey',
      );
    }
    // Garde obligatoire, et la conséquence de son absence est une perte de
    // données, pas seulement un écran vide : `messages_select` vaut pour le
    // rôle `public`, donc une lecture sans session **réussit** en ne renvoyant
    // aucune ligne. Le repository prend ce vide pour la vérité, le met en
    // cache par-dessus la discussion réelle (`cacheMessages`), et l'écran
    // affiche une discussion vide. Même piège que `users_select` côté profil.
    if (!await _ensureReadableAuth()) {
      throw ServerException('Session non établie – réessayez');
    }
    try {
      // Les filtres précèdent order/limit.
      var query = _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      // Dans la requête, pas après la limite : filtrée côté client, une page
      // d'un groupe privé pouvait revenir vide alors que des messages plus
      // récents que l'arrivée du membre existaient encore plus loin.
      if (filterAfterDate != null) {
        query = query.gt(
          'created_at',
          filterAfterDate.toUtc().toIso8601String(),
        );
      }

      if (lastMessageKey != null) {
        query = query.or(
          filtreAvantCurseur(beforeCreatedAt!, lastMessageKey.toString()),
        );
      }

      // L'id départage les ex-aequo : sans lui, deux messages de même
      // `created_at` de part et d'autre d'une page en perdaient un.
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit + 1);

      final messages = await Future.wait(rows.map(_msgFromRowAsync));

      final hasMore = messages.length > limit;
      if (hasMore) messages.removeLast();

      // Return oldest message's createdAt as cursor for next page
      final newCursor =
          messages.isNotEmpty
              ? messages.last.createdAt?.toUtc().toIso8601String()
              : null;

      // Reverse to oldest-first for display
      return (messages.reversed.toList(), newCursor);
    } catch (e) {
      throw ServerException('getMessagesPaginated error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH / FETCH
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) return [];

      final rows = await _supabase
          .from('conversations')
          .select()
          .contains('participant_ids', [userId])
          .order('last_message_at', ascending: false)
          .limit(50);

      final lowerQuery = query.toLowerCase();
      return rows
          .map(_convFromRow)
          .where(
            (c) =>
                (c.name ?? '').toLowerCase().contains(lowerQuery) ||
                (c.lastMessage ?? '').toLowerCase().contains(lowerQuery),
          )
          .take(20)
          .toList();
    } catch (e) {
      throw ServerException('searchConversations error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
    DateTime? beforeCreatedAt,
  }) async {
    // Même curseur `(created_at, id)` que `getMessagesPaginated`. Avant,
    // [beforeMessageId] n'était lu nulle part : « charger plus » renvoyait
    // les mêmes médias, la galerie les ajoutait en double et `hasMore`
    // restait vrai — une boucle sans fin de doublons au défilement.
    if (beforeMessageId != null && beforeCreatedAt == null) {
      throw ArgumentError(
        'getMediaMessages : curseur incomplet, beforeCreatedAt requis '
        'avec beforeMessageId',
      );
    }
    try {
      var query = _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .inFilter('type', ['image', 'video', 'file'])
          // Filtré ici plutôt qu'après coup : une page amputée de ses médias
          // sans URL passerait pour la dernière.
          .not('data->>fileUrl', 'is', null);
      if (beforeMessageId != null) {
        query = query.or(filtreAvantCurseur(beforeCreatedAt!, beforeMessageId));
      }

      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      return rows.map(_msgFromRow).where((m) => m.fileUrl != null).toList();
    } catch (e) {
      throw ServerException('getMediaMessages error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(500);

      return rows
          .map(_msgFromRow)
          .where((m) => m.starredBy.contains(userId))
          .take(limit)
          .toList();
    } catch (e) {
      throw ServerException('getStarredMessages error: $e');
    }
  }

  @override
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  }) async {
    try {
      if (query.trim().length < 2) return [];

      // Use Postgres ILIKE on the JSONB content field
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .ilike('data->>content', '%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      // L'`ilike` porte sur ce qui est STOCKÉ : pour un message chiffré, le
      // ciphertext. « Yo » y trouvait « v1:/YO6lTZ8e… » (base64, sans casse),
      // et l'écran affichait le chiffré brut (SM A515F, 2026-09-22). On
      // déchiffre comme pour le fil, puis on ne garde que ce dont le CLAIR
      // contient la recherche.
      final modeles = await Future.wait(rows.map(_msgFromRowAsync));
      return garderSiLeClairContient(modeles, query);
    } catch (e) {
      throw ServerException('searchMessagesInConversation error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMessagesSince({
    required String conversationId,
    required DateTime since,
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .gte('created_at', since.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(_msgFromRow).toList();
    } catch (e) {
      throw ServerException('getMessagesSince error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-DELETE / EPHEMERAL
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    await _mergeConvData(conversationId, {
      'autoDeleteAfterSeconds': durationSeconds,
    });
  }

  @override
  Future<int?> getAutoDeleteSettings(String conversationId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return null;
      final data = (rows.first['data'] as Map<String, dynamic>?) ?? {};
      return data['autoDeleteAfterSeconds'] as int?;
    } catch (e) {
      throw ServerException('getAutoDeleteSettings error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> updateRequestStatus({
    required String conversationId,
    required String status,
    required String recipientId,
  }) async {
    await _mergeConvData(conversationId, {
      'requestStatus': status,
      'respondedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
