part of 'message_supabase_datasource.dart';

/// Flux temps réel des discussions et des messages, indicateur de saisie.
mixin _Flux on _MessageSupabaseBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<ConversationModel>> getConversations(String userId) {
    final controller = StreamController<List<ConversationModel>>.broadcast();

    // Écran ouvert hors ligne : la lecture initiale échoue et rien ne la
    // retente. Le rejoint du canal, au retour du réseau, devient sa première
    // occasion de charger — voir [rattrapageAuRejoint].
    var echecInitial = false;

    // Attente d'une session, armée au plus une fois à la fois.
    StreamSubscription<void>? attenteSession;
    Timer? filet;
    late final LectureSansChevauchement lecture;

    void relancerApresSession() {
      filet?.cancel();
      filet = null;
      unawaited(attenteSession?.cancel());
      attenteSession = null;
      if (!controller.isClosed) unawaited(lecture.lire());
    }

    Future<void> fetch() async {
      try {
        // Session non confirmée (fenêtre `_startFromLocalSession`,
        // auth_provider.dart, ou jeton périmé au retour d'arrière-plan) : ne
        // pas interroger en anon. `conversationsProvider` aura déjà émis son
        // cache ; sans nouvel essai, le stream resterait bloqué dessus
        // jusqu'au prochain événement realtime (potentiellement jamais).
        //
        // On relit **dès que la session est établie**. On ne réessayait
        // qu'au bout de 5 s fixes : le jeton neuf arrivait bien avant, et la
        // liste restait figée pendant que la notification du message, elle,
        // était déjà affichée. Les 5 s ne sont plus qu'un filet, pour le cas
        // où l'échange échoue et ne signale donc rien.
        if (!await _ensureReadableAuth()) {
          if (!controller.isClosed && attenteSession == null) {
            attenteSession =
                _sessionEtablie.listen((_) => relancerApresSession());
            filet = Timer(const Duration(seconds: 5), relancerApresSession);
          }
          return;
        }
        final rows = await _supabase
            .from('conversations')
            .select()
            .contains('participant_ids', [userId])
            .order('last_message_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(rows.map(_convFromRow).toList());
        }
        echecInitial = false;
      } catch (e) {
        echecInitial = true;
        if (!controller.isClosed) {
          controller.addError(ServerException('getConversations error: $e'));
        }
      }
    }

    // Toutes les lectures passent par là : une seule à la fois, sinon une
    // réponse ancienne revenue la dernière figeait la liste sur un état
    // périmé. Voir [LectureSansChevauchement].
    lecture = LectureSansChevauchement(fetch);

    // Initial load
    unawaited(lecture.lire());

    // Real-time updates — regroupés : un seul message réécrit la ligne
    // plusieurs fois (aperçu, accusé, lecture), inutile de tout relire à
    // chaque fois.
    // Suffixe unique, comme `new_msgs` et `msg_updates` : sous un nom fixe,
    // `_channel` rendait le canal d'un abonnement encore vivant — le second
    // `subscribe` levait « tried to subscribe multiple times », et l'`onCancel`
    // du premier désabonnait le canal du second, resté muet. Le sujet d'un
    // canal de changements Postgres est local : rien n'impose qu'il soit
    // partagé (contrairement à `typing:`, salon de présence commun).
    final channelName = 'conversations:$userId:${_channelSeq++}';
    final ch = _channel(channelName);
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => lecture.planifier(),
        )
        .subscribe(
          rattrapageAuRejoint(
            lecture.lire,
            lectureInitialeEnEchec: () => echecInitial,
            etiquette: 'conversations',
          ),
        );

    controller.onCancel = () {
      lecture.fermer();
      filet?.cancel();
      unawaited(attenteSession?.cancel());
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    final controller = StreamController<ConversationModel?>.broadcast();

    // Même raison que dans `getConversations` : discussion ouverte hors ligne.
    var echecInitial = false;

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .limit(1);
        if (!controller.isClosed) {
          controller.add(rows.isEmpty ? null : _convFromRow(rows.first));
        }
        echecInitial = false;
      } catch (e) {
        echecInitial = true;
        if (!controller.isClosed) controller.addError(e);
      }
    }

    unawaited(fetch());

    // Suffixe unique : voir `getConversations`.
    final channelName = 'conversation:$conversationId:${_channelSeq++}';
    final ch = _channel(channelName);
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: conversationId,
          ),
          callback: (_) => fetch(),
        )
        .subscribe(
          rattrapageAuRejoint(
            fetch,
            lectureInitialeEnEchec: () => echecInitial,
            etiquette: 'conversation',
          ),
        );

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? filterAfterDate,
  }) {
    var query = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');

    return query.map((rows) {
      var models = rows.map(_msgFromRow).toList();
      if (filterAfterDate != null) {
        models =
            models
                .where(
                  (m) =>
                      m.createdAt != null &&
                      m.createdAt!.isAfter(filterAfterDate),
                )
                .toList();
      }
      return models;
    });
  }

  @override
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId) {
    final channelName = 'typing:$conversationId';
    final ch = _channel(channelName);

    final controller = StreamController<Map<String, bool>>.broadcast();

    ch.onPresenceSync((_) {
      final presenceList = ch.presenceState();
      final result = <String, bool>{};
      for (final singleState in presenceList) {
        for (final presence in singleState.presences) {
          final payload = presence.payload;
          final userId = payload['user_id'] as String?;
          final isTyping = payload['is_typing'] as bool? ?? false;
          if (userId != null) {
            result[userId] = isTyping;
          }
        }
      }
      if (!controller.isClosed) controller.add(result);
    });
    // Passe par _ensureJoined pour que l'état « rejoint » soit enregistré :
    // c'est lui que consulte setTypingStatus avant de publier la présence.
    unawaited(_ensureJoined(channelName));

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _forgetChannel(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<List<ConversationModel>> getMessageRequests(String userId) {
    final controller = StreamController<List<ConversationModel>>.broadcast();

    // Même raison que dans `getConversations` : écran ouvert hors ligne.
    var echecInitial = false;

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('conversations')
            .select()
            .contains('participant_ids', [userId])
            .eq('type', 'request')
            .order('created_at', ascending: false);

        final requests =
            rows
                .map(_convFromRow)
                .where(
                  (c) =>
                      c.requestStatus == 'pending' && c.requesterId != userId,
                )
                .toList();

        if (!controller.isClosed) controller.add(requests);
        echecInitial = false;
      } catch (e) {
        echecInitial = true;
        if (!controller.isClosed) {
          controller.addError(ServerException('getMessageRequests error: $e'));
        }
      }
    }

    unawaited(fetch());

    // Suffixe unique : voir `getConversations`.
    final channelName = 'msg_requests:$userId:${_channelSeq++}';
    final ch = _channel(channelName);
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => fetch(),
        )
        .subscribe(
          rattrapageAuRejoint(
            fetch,
            lectureInitialeEnEchec: () => echecInitial,
            etiquette: 'demandes',
          ),
        );

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  }) {
    final controller = StreamController<MessageModel>.broadcast();
    // Suffixe unique : rouvrir la discussion recrée ce flux pendant que le
    // `unsubscribe` de l'ancien (asynchrone) n'a pas fini. Deux canaux de même
    // sujet se marchent dessus, et c'est le NEUF qui reste muet — les
    // réactions et accusés de l'autre ne s'affichaient plus jusqu'au retour.
    final channelName = 'msg_updates:$conversationId:${_channelSeq++}';
    final ch = _channel(channelName);

    /// Relit les dernières lignes de la discussion au rejoint du canal.
    ///
    /// Un abonnement nu perdait tout UPDATE survenu pendant l'arrière-plan
    /// (`supabase_flutter` coupe le socket, Postgres ne rejoue rien) : accusés
    /// de lecture, réactions, épinglage restaient figés sur l'écran ouvert
    /// jusqu'à sa réouverture. `messages` n'a pas de colonne `updated_at` : on
    /// ne sait pas QUELLES lignes ont bougé, on relit donc la dernière page —
    /// là où tombent presque tous les UPDATE d'une discussion affichée.
    ///
    /// Relire sans risque : chaque ligne sort brute par `_msgFromRow`, comme
    /// dans le rappel temps réel, et l'écouteur (`_listenForMessageUpdates`)
    /// ne touche qu'aux messages déjà affichés, par identifiant, en gardant
    /// leur contenu déjà déchiffré. Rien n'est déchiffré ici — pas de second
    /// déchiffrement Signal à craindre, contrairement au canal `messages`.
    Future<void> rattraper() async {
      try {
        final rows = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(50);
        for (final row in rows) {
          if (controller.isClosed) return;
          controller.add(_msgFromRow(row));
        }
      } catch (e) {
        debugPrint('rattrapage msg_updates $conversationId : $e');
      }
    }

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && !controller.isClosed) {
              controller.add(_msgFromRow(newRecord));
            }
          },
        )
        .subscribe(
          rattrapageAuRejoint(rattraper, etiquette: 'msg_updates'),
        );

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  }) {
    final controller = StreamController<List<MessageModel>>.broadcast();
    // Même suffixe unique que `msg_updates` (voir getMessageUpdatesStream).
    final channelName = 'new_msgs:$conversationId:${_channelSeq++}';
    final ch = _channel(channelName);

    // Borne du rattrapage : avance avec les messages reçus, pour ne pas
    // relire toute la discussion à chaque reconnexion.
    var dernierVu = afterTimestamp;

    // Identifiants déjà livrés, par le temps réel ou par le rattrapage.
    // Depuis que le rattrapage court aussi au PREMIER `subscribed`, les deux
    // chemins peuvent rapporter la même ligne à quelques millisecondes
    // d'intervalle — et la déchiffrer deux fois échoue (Signal a consommé sa
    // clé à la première). Une ligne n'est livrée, donc déchiffrée, qu'une fois.
    final livres = <String>{};

    /// Relit les messages postés pendant que le canal était coupé.
    ///
    /// Postgres ne rejoue pas les INSERT manqués : sans ça, les messages
    /// arrivés pendant une coupure de quelques secondes n'apparaissaient
    /// jamais dans la discussion ouverte, même après le retour du réseau.
    ///
    /// La borne avance avec ce qui est relu, et pas seulement avec ce qui
    /// arrive en temps réel. Ce n'est pas qu'une économie de requête : ce
    /// chemin **déchiffre**, et pour Signal un second déchiffrement du même
    /// message échoue — le Double Ratchet a consommé sa clé au premier. Deux
    /// reconnexions d'affilée sans message entre elles rapporteraient donc un
    /// illisible ; `reconcileEchoContent` sauve le texte déjà déchiffré, mais
    /// pas les charges annexes (carte de post, d'événement). Une ligne n'est
    /// relue qu'une fois.
    Future<void> rattraper() async {
      try {
        final rows = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .gt('created_at', toIsoUtc(dernierVu))
            .order('created_at')
            // Borne de sûreté : ce chemin déchiffre message par message.
            // Un retard de plus de cent messages dans une discussion restée
            // ouverte n'arrive pas — et s'il arrivait, c'est la pagination de
            // `getMessages` qui doit le rattraper, pas ce flux.
            .limit(100);
        if (rows.isEmpty || controller.isClosed) return;
        final messages = <MessageModel>[];
        for (final row in rows) {
          final id = row['id'].toString();
          if (!livres.add(id)) continue;
          // Ligne par ligne : une ligne illisible abandonnait tout le lot —
          // et les lignes déjà notées « livrées » ne l'étaient jamais.
          try {
            final msg = await _msgFromRowAsync(row);
            final cree = msg.createdAt;
            if (cree != null && cree.isAfter(dernierVu)) dernierVu = cree;
            messages.add(msg);
          } catch (e) {
            livres.remove(id);
            if (!controller.isClosed) {
              controller.addError(ServerException('rattrapage $id : $e'));
            }
          }
        }
        if (!controller.isClosed && messages.isNotEmpty) {
          controller.add(messages);
        }
      } catch (e) {
        debugPrint('rattrapage new_msgs $conversationId : $e');
      }
    }

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          // Pas de filtre sur la date. Un INSERT reçu après l'abonnement est
          // nouveau par définition ; le comparer à [afterTimestamp] mêlait
          // deux horloges — celle du téléphone de l'expéditeur, qui datait le
          // message, et celle du dernier message chargé. Une horloge en retard
          // de deux minutes faisait jeter le message en direct ; il ne
          // reparaissait qu'au rechargement, rangé dans le passé. La date est
          // désormais posée par le serveur (20261004090000), et l'écran
          // dédoublonne par identifiant.
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty || controller.isClosed) return;
            final id = newRecord['id'].toString();
            if (!livres.add(id)) return;
            // Un rappel asynchrone qui lève perd son exception dans la zone :
            // le message, déjà noté « livré », ne revenait plus jamais — ni
            // par le temps réel, ni par le rattrapage. Il redevient
            // rattrapable, et l'échec remonte dans le flux.
            try {
              final msg = await _msgFromRowAsync(newRecord);
              final cree = msg.createdAt;
              if (cree != null && cree.isAfter(dernierVu)) dernierVu = cree;
              if (!controller.isClosed) controller.add([msg]);
            } catch (e) {
              livres.remove(id);
              if (!controller.isClosed) {
                controller.addError(ServerException('temps réel $id : $e'));
              }
            }
          },
        )
        // Rattrapage dès le PREMIER `subscribed`, pas seulement aux reprises.
        // Rejoindre le canal prend de 100 ms à quelques secondes après la
        // lecture initiale : un message écrit dans cet intervalle n'était
        // ni dans la page lue, ni livré par le temps réel — absent jusqu'à
        // la réouverture. La requête de plus au démarrage coûte une ligne
        // vide dans le cas ordinaire.
        .subscribe(
          rattrapageAuRejoint(
            rattraper,
            desLePremier: true,
            etiquette: 'messages',
          ),
        );

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<void> mlsNouveauxMessages(String conversationId) {
    // Suffixe unique : la même discussion ouverte deux fois dans la pile de
    // navigation (discussion → profil → « Envoyer un message ») faisait
    // lever la seconde ouverture — plus de temps réel chiffré sur l'écran du
    // dessus. Voir `getConversations`.
    final channelName = 'mls_new:$conversationId:${_channelSeq++}';
    final ch = _channel(channelName);
    final controller = StreamController<void>.broadcast();

    ch
        // Deux événements, nommés un par un plutôt qu'un `all` fourre-tout.
        //
        // `insert` porte un nouveau message ET une MODIFICATION (qui voyage
        // dans un message de contrôle, donc une ligne de plus).
        //
        // `update` porte les SUPPRESSIONS : « supprimer pour tout le monde »
        // comme une expiration purgée ne sont qu'un passage de `is_deleted` à
        // vrai. Le filtre sur `conversation_id` fonctionne ici parce qu'il
        // s'évalue sur la NOUVELLE ligne, qui le porte — `REPLICA IDENTITY
        // FULL` n'est nécessaire que pour un `delete`, où seule l'ancienne
        // ligne existe et ne contient que la clé primaire. On ne supprime
        // jamais de ligne, donc `delete` n'a rien à faire ici : l'inclure
        // (via `all`) n'apporterait qu'un événement infiltrable.
        //
        // La preuve que ça tient : `getMessageUpdatesStream` s'abonne depuis
        // toujours à `update` sur `messages` avec le même filtre, et c'est ce
        // qui fait arriver les accusés de lecture en direct.
        //
        // Rien à faire de plus pour la tombe : la relecture la pose déjà,
        // `_avecMetadonnees` marquant `deletedForEveryone` depuis la requête
        // `is_deleted = true`.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mls_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          // On ne transmet RIEN de la ligne : elle est chiffrée, et la lire
          // ici n'apprendrait rien. Le signal suffit — le dépôt relit le fil
          // par la passerelle, qui seule sait déchiffrer.
          callback: (payload) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mls_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (!controller.isClosed) controller.add(null);
          },
        );

    // Accusés et réactions : ils vivent dans leurs propres tables (décision
    // J), que rien n'écoutait. L'expéditeur ne voyait donc jamais « Lu » ni la
    // réaction de l'autre en direct — seulement à la réouverture ou au message
    // suivant. Vu le 2026-09-21 à deux téléphones : « Envoyé » plus d'une
    // minute après la lecture, discussion ouverte.
    //
    // Sans filtre : ces tables n'ont pas de `conversation_id`. Le RLS
    // (`mls_message_participant`) ne laisse passer que les conversations dont
    // on est membre ; un événement d'une autre discussion coûte une relecture
    // incrémentale de celle-ci, rien de plus. Pas de `delete` : le temps réel
    // n'applique pas le RLS aux suppressions — un retrait de réaction se voit
    // donc au prochain rafraîchissement, pas en direct.
    for (final table in const ['mls_message_receipts', 'mls_message_reactions']) {
      for (final evenement in const [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        ch.onPostgresChanges(
          event: evenement,
          schema: 'public',
          table: table,
          callback: (_) {
            if (!controller.isClosed) controller.add(null);
          },
        );
      }
    }

    ch
        // Le rattrapage au rejoint, comme le canal `messages` : un abonnement
        // nu laissait perdu tout message arrivé pendant l'arrière-plan. Vu le
        // 2026-09-21 sur SM A515F : discussion affichée, HOME, un message
        // reçu, retour — livré, mais absent du fil jusqu'à la réouverture.
        // Le signal suffit : l'écouteur relit le fil par la passerelle.
        //
        // Dès le PREMIER `subscribed`, pas seulement aux suivants : ouverte
        // hors ligne, la discussion s'affiche depuis le cache, et ce premier
        // `subscribed` n'arrive qu'au retour du réseau — c'est lui qui doit
        // rattraper. Vu le 2026-09-21 sur SM A515F : discussion ouverte en
        // mode avion, message reçu entre-temps, réseau rétabli — rien pendant
        // 2 min, le message n'apparaissant qu'en rouvrant. La relecture est
        // incrémentale (`catchUp`) : presque gratuite quand rien n'a bougé.
        .subscribe(
          rattrapageAuRejoint(
            () {
              if (!controller.isClosed) controller.add(null);
            },
            lectureInitialeEnEchec: () => true,
            etiquette: 'mls_new',
          ),
        );

    controller.onCancel = () {
      unawaited(ch.unsubscribe());
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPING
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final channelName = 'typing:$conversationId';
      final ch = _channel(channelName);

      // `track` sur un canal pas encore rejoint est perdu sans erreur. En
      // pratique le canal est déjà rejoint par getTypingStatusStream (l'écran
      // l'observe dès son build), mais les premières frappes peuvent tomber
      // pendant le join : on l'attend plutôt que d'écrire dans le vide.
      if (!await _ensureJoined(channelName)) return;

      if (isTyping) {
        await ch.track({'user_id': userId, 'is_typing': true});
      } else {
        await ch.untrack();
      }
    } catch (e) {
      throw ServerException('setTypingStatus error: $e');
    }
  }
}
