import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/errors/journal_echecs.dart';
import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../../../core/services/e2ee/models/e2ee_models.dart';
import 'group_encryption_status_provider.dart';
import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import 'modification_recue.dart';
import '../../data/datasources/message_supabase_datasource.dart';
import '../../data/datasources/lecture_serveur.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/utils/rtdb_sync_script.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/services/link_preview_service.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;
import 'message_pagination_state.dart';
import 'media_upload_provider.dart';
import '../../../../core/services/e2ee/media_encryption_service.dart';
import 'media_dechiffre_provider.dart';
import '../../../../core/crypto/mls/mls_providers.dart';
import '../../../../core/services/oubli_medias_locaux.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/nom_de_fichier_sur.dart';
import '../utils/image_locale_ou_reseau.dart';

const int _pageSize = 30;

// ============ Providers de base ============

/// Émet quand une session Supabase neuve est en place — voir
/// [SupabaseAuthBridge.sessionEtablie]. Provider pour être remplacé en test.
final sessionSupabaseEtablieProvider = Provider<Stream<void>>(
  (ref) => SupabaseAuthBridge.instance.sessionEtablie,
);

/// Provider pour le datasource de messages
final messageRemoteDataSourceProvider = Provider<MessageRemoteDataSource>((ref) {
  return MessageSupabaseDataSource(
    cryptoService: ref.watch(messageCryptoServiceProvider),
  );
});

/// Provider pour le repository de messages
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(
    remoteDataSource: ref.watch(messageRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    mediaEncryptionService: ref.watch(mediaEncryptionServiceProvider),
    // `read` dans une fermeture : la valeur est relue à chaque envoi, et
    // un changement de drapeau ne reconstruit pas le repository.
    mediasChiffresActifs: () => ref.read(mediasChiffresActifsProvider),
    // Messagerie MLS (plan MLS, phase 5) : nulle tant qu'aucun compte n'est
    // connecté, et inerte tant que le drapeau est fermé ET qu'aucune
    // conversation n'a basculé.
    mlsGateway: ref.watch(mlsGatewayProvider),
    // Copies locales en clair d'un message supprimé pour tous : média
    // déchiffré, pièce jointe téléchargée. `read` à l'appel, comme ci-dessus.
    oublierMedias: (ids) => ref.read(oubliMediasLocauxProvider).oublier(ids),
  );
});

/// Les RPC de lecture par curseur : le repère du séparateur et l'avancée du
/// « Lu », pour les conversations en clair comme basculées.
final lectureServeurProvider = Provider<LectureServeur>((ref) => LectureServeur());

// ============ Stream Providers ============

/// La dernière émission de [conversationsProvider] vient-elle du **réseau** ?
///
/// `false` tant que seule la copie Hive a été rendue, `true` dès la première
/// émission du flux Supabase. La distinction ne sert qu'à une décision, celle
/// de `EnsureSelfNotesNotifier.ouvrir` : une conversation portée par le flux
/// vivant existe encore côté serveur — il la retire dès qu'elle disparaît —
/// alors qu'une conversation venue du cache peut être un fantôme, et c'est
/// exactement ce fantôme qui a coûté la panne du 2026-08-06.
///
/// Remis à `false` à chaque (re)construction du flux : le tirer-pour-
/// rafraîchir de `messages_screen.dart` invalide [conversationsProvider], qui
/// repart alors sur son cache. Sans cette remise à zéro, la fenêtre entre le
/// cache et le réseau se lirait comme une confirmation du serveur.
final conversationsDepuisReseauProvider = StateProvider<bool>((ref) => false);

/// Stream des conversations de l'utilisateur (cache-first)
final conversationsProvider = StreamProvider<List<ConversationEntity>>((ref) async* {
  // Attendre que l'utilisateur soit completement resolu
  // Utiliser .future pour attendre la premiere valeur du stream
  final currentUser = await ref.watch(currentUserProvider.future);

  // Après l'`await` : on n'est plus dans la phase de construction synchrone,
  // écrire dans un autre provider est sans danger ici.
  ref.read(conversationsDepuisReseauProvider.notifier).state = false;

  if (currentUser == null) {
    yield [];
    return;
  }

  final repository = ref.watch(messageRepositoryProvider);

  // 1. Yield cached conversations immediately (Cache First)
  final cachedResult = repository.getCachedConversations();
  final cachedData = cachedResult.fold(
    (failure) => <ConversationEntity>[],
    (data) => data,
  );

  if (cachedData.isNotEmpty) {
    yield cachedData;
  }

  // 2. Yield from live stream (Network/Live)
  //
  // L'échec est propagé, pas plié en liste vide : une panne de lecture ferait
  // sinon disparaître les discussions déjà affichées (le cache rendu juste
  // au-dessus), ce qui se lit comme une perte de données. En erreur,
  // `AsyncValue` garde la dernière liste connue et l'écran continue de
  // l'afficher (`skipError` dans `messages_screen.dart`).
  yield* repository
      .getConversations(currentUser.id)
      .map(
        (either) => either.fold((failure) => throw failure, (conversations) {
          ref.read(conversationsDepuisReseauProvider.notifier).state = true;
          return conversations;
        }),
      );
});

/// Stream d'une conversation specifique
///
/// Sémantique de la valeur émise, calquée sur `userStreamProvider` :
///   - ConversationEntity → conversation chargée
///   - null               → conversation RÉELLEMENT absente (le flux a rendu
///                          `Right(null)`) → « Conversation supprimée »
///   - AsyncError         → panne de lecture (réseau, RLS, session) → surtout
///                          PAS « supprimée »
///
/// Plier l'échec en `null` faisait dire « Conversation supprimée » à l'écran
/// sur une simple coupure. Tant que l'erreur était avalée en amont, ça ne se
/// voyait pas ; maintenant qu'elle arrive, la distinction compte.
final conversationStreamProvider = StreamProvider.family<ConversationEntity?, String>((ref, conversationId) async* {
  final depot = ref.watch(messageRepositoryProvider);

  // La conversation déjà en cache part la première, comme pour la liste.
  // Sans elle, un écran ouvert hors ligne ne sait même pas QUI est en face :
  // `_effectiveOtherUserId` se déduit de la conversation quand l'écran est
  // atteint sans `state.extra` (lien profond, notification), donc aucun profil
  // n'était demandé et l'en-tête gardait son repli — cache du profil ou pas.
  ConversationEntity? connue;
  final enCache = depot.getCachedConversations().fold(
    (_) => const <ConversationEntity>[],
    (liste) => liste,
  );
  for (final c in enCache) {
    if (c.id == conversationId) {
      connue = c;
      break;
    }
  }
  if (connue != null) yield connue;

  yield* depot
      .getConversationStream(conversationId)
      .map(
        (either) => either.fold(
          (failure) => throw failure,
          (conversation) => conversation,
        ),
      );
});

/// Stream des messages d'une conversation
///
/// Même règle : une panne est une erreur, pas une conversation vide.
final messagesProvider = StreamProvider.family<List<MessageEntity>, String>((ref, conversationId) {
  return ref
      .watch(messageRepositoryProvider)
      .getMessages(conversationId)
      .map(
        (either) =>
            either.fold((failure) => throw failure, (messages) => messages),
      );
});

// ============ Notifiers ============

/// Notifier pour les messages pagines avec support offline
/// autoDispose: libere la memoire quand le provider n'est plus utilise
final paginatedMessagesProvider = StateNotifierProvider.autoDispose.family<
    PaginatedMessagesNotifier, MessagePaginationState, String>(
  (ref, conversationId) {
    // Keep alive briefly to allow preloading before navigation
    final link = ref.keepAlive();

    // Auto-dispose after 5 seconds if no active listeners
    final timer = Timer(const Duration(seconds: 5), () {
      link.close();
    });

    ref.onDispose(() {
      timer.cancel();
    });

    return PaginatedMessagesNotifier(ref, conversationId);
  },
);

/// L'échéance à afficher sur un message qu'on vient d'envoyer.
///
/// Le signe « message éphémère » (l'icône minuteur de `_buildMetaRow`) se
/// lit sur `expiresAt`. Les entités optimistes n'en portaient aucune : le
/// signe n'apparaissait donc **pas à l'envoi**, alors que c'est précisément
/// le moment où il dit quelque chose. Côté MLS c'était même définitif tant
/// qu'on restait dans la conversation : `catchUp` saute nos propres
/// messages, aucun écho ne vient remplacer l'optimiste, `_reconcileEcho` ne
/// s'exécute jamais. Mesuré sur SM A515F le 2026-09-15 — minuteur à 24 h,
/// `mls_messages.expires_at` correctement posé côté serveur, et aucune
/// icône à l'écran jusqu'à ce qu'on ressorte de la conversation.
///
/// **Valeur d'affichage seulement.** L'échéance qui fait foi est recalculée
/// par le destinataire depuis le `ttl` du payload chiffré, jamais depuis
/// ici ni depuis la colonne du serveur.
DateTime? _echeanceOptimiste(Ref ref, String conversationId) {
  final secondes = ref
      .read(conversationStreamProvider(conversationId))
      .valueOrNull
      ?.autoDeleteAfterSeconds;
  return secondes == null
      ? null
      : DateTime.now().add(Duration(seconds: secondes));
}

/// Le fil tel qu'un membre arrivé à [arrivee] peut le voir : rien de ce qui
/// a été dit avant lui.
///
/// `null` : pas de borne (discussion hors groupe privé, ou date inconnue).
List<MessageEntity> sansMessagesAvantArrivee(
  List<MessageEntity> messages,
  DateTime? arrivee,
) {
  if (arrivee == null) return messages;
  if (messages.every((m) => m.createdAt.isAfter(arrivee))) return messages;
  return [
    for (final m in messages)
      if (m.createdAt.isAfter(arrivee)) m,
  ];
}

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
      return resultat.fold(
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

/// Au-delà de ce délai, un message en attente ne repart plus tout seul.
///
/// Il n'est pas perdu pour autant : il reste affiché en échec, avec son
/// bouton « Renvoyer ». Le but est d'éviter qu'un message écrit et oublié
/// il y a trois jours parte à l'improviste au premier retour de réseau.
/// Une fenêtre **nulle** (`Duration.zero`) désactive la condition d'âge : tout
/// ce qui attend repart, quel que soit son âge.
const Duration kFenetreRenvoiAutomatique = Duration(hours: 24);

/// Reconstruit le message tel qu'il doit repartir.
///
/// `messageJson` porte l'entité complète — réponse citée, carte de
/// publication ou d'événement, mentions. Les entrées écrites par les versions
/// précédentes ne l'ont pas : on retombe alors sur les champs plats, qui ne
/// décrivent qu'un texte.
MessageEntity? messageEnAttenteVersEntite(PendingMessage attente) {
  final blob = attente.messageJson;
  if (blob != null) {
    try {
      final json = jsonDecode(blob) as Map<String, dynamic>;
      final entite = MessageModel.fromJson(json).toEntity();
      return entite.copyWith(
        status: MessageStatus.failed,
        // `MessageModel` ne porte pas le chemin local du média : il ne vit que
        // sur l'entité, et c'est lui qu'il faudra re-téléverser.
        localFilePath: attente.filePath,
      );
    } catch (e) {
      debugPrint('message en attente illisible (${attente.id}) : $e');
    }
  }

  if (attente.content.isEmpty) return null;
  return MessageEntity(
    id: attente.id,
    senderId: attente.senderId,
    senderName: attente.senderName,
    senderPhotoUrl: attente.senderPhotoUrl,
    content: attente.content,
    type: MessageType.values.firstWhere(
      (t) => t.name == attente.type,
      orElse: () => MessageType.text,
    ),
    status: MessageStatus.failed,
    createdAt: attente.createdAt,
    readBy: const [],
    readAt: const {},
    localFilePath: attente.filePath,
  );
}

/// Renvoie tout seul les messages jamais partis.
///
/// Tenu en vie par un `ref.watch` dans `app.dart` : sans lui Riverpod ne le
/// construirait jamais, et la file resterait pleine — c'est exactement ce qui
/// se passait avant, `processQueue` n'étant appelé de nulle part.
///
/// ⚠️ N'utilise **pas** `OfflineQueueService.processQueue` : celui-ci
/// **supprime** le message après cinq tentatives. C'est précisément la perte
/// qu'on cherche à éviter — passé les tentatives, le message doit rester
/// affiché et attendre un geste, pas disparaître.
class RenvoiMessagesEnAttente {
  RenvoiMessagesEnAttente(this._ref);

  /// Intervalle du filet de sécurité. Voir [_battement] : c'est lui qui fait
  /// le travail quand le signal de connectivité ment.
  static const Duration intervalleDeControle = Duration(seconds: 60);

  final Ref _ref;
  ProviderSubscription<bool>? _abonnement;
  Timer? _battement;
  bool _enCours = false;

  void demarrer() {
    _abonnement = _ref.listen<bool>(
      connectivityNotifierProvider,
      (avant, apres) {
        if (apres == true && avant != true) unawaited(renvoyerCeQuiPeutPartir());
      },
    );

    // ⚠️ **Le retour du réseau ne suffit pas comme déclencheur**, et c'est
    // vérifié : `ConnectivityService.isConnected` vaut
    // `!results.contains(none)`, or `connectivity_plus` liste `vpn` tant que
    // le tunnel est debout. Sur le SM A515F, qui porte un VPN permanent,
    // couper les deux radios laisse donc l'app **se croire en ligne** : aucune
    // transition `false → true` n'est émise au retour, et ce qui attendait
    // n'est jamais reparti (mesuré le 2026-09-14). La même illusion vaut pour
    // un portail captif ou une connexion qui répond sans router.
    //
    // D'où ce battement, qui ne demande rien à personne : il relit la file et
    // sort immédiatement si elle est vide, ce qui est le cas ordinaire.
    _battement = Timer.periodic(
      intervalleDeControle,
      (_) => unawaited(renvoyerCeQuiPeutPartir()),
    );

    // Un démarrage d'app en ligne n'émet aucune transition : la file laissée
    // par la session précédente doit partir quand même.
    unawaited(renvoyerCeQuiPeutPartir());
  }

  void arreter() {
    _abonnement?.close();
    _abonnement = null;
    _battement?.cancel();
    _battement = null;
  }

  /// Tente un envoi pour chaque message en attente encore éligible.
  ///
  /// Un message est laissé dans la file — donc toujours visible et renvoyable
  /// à la main — quand il est trop vieux, quand son média local a disparu, ou
  /// quand l'envoi échoue encore.
  Future<void> renvoyerCeQuiPeutPartir() async {
    if (_enCours) return;
    _enCours = true;
    try {
      final file = _ref.read(offlineQueueServiceProvider);
      await file.init();
      final enAttente = file.getQueue();
      // Cas ordinaire : rien n'attend, le battement ne coûte qu'une lecture.
      if (enAttente.isEmpty) return;

      const fenetre = kFenetreRenvoiAutomatique;
      final maintenant = DateTime.now();

      for (final attente in enAttente) {
        if (fenetre > Duration.zero &&
            maintenant.difference(attente.createdAt) > fenetre) {
          continue;
        }
        final chemin = attente.filePath;
        if (chemin != null && chemin.isNotEmpty && !File(chemin).existsSync()) {
          // Android a purgé le fichier temporaire : il n'y a plus rien à
          // téléverser. Le message reste en file pour rester visible, mais le
          // renvoyer n'aboutirait qu'à un échec de plus.
          debugPrint('renvoi impossible, média absent : $chemin');
          continue;
        }

        final entite = messageEnAttenteVersEntite(attente);
        if (entite == null) {
          await file.dequeue(attente.id);
          continue;
        }

        try {
          final parti = await _ref
              .read(sendMessageProvider.notifier)
              .retryFailedMessage(
                conversationId: attente.conversationId,
                failedMessage: entite,
                ecritLe: attente.createdAt,
              );
          if (parti) await file.dequeue(attente.id);
        } catch (e) {
          debugPrint('renvoi du message ${attente.id} : $e');
        }
      }
    } catch (e) {
      debugPrint('renvoi des messages en attente : $e');
    } finally {
      _enCours = false;
    }
  }
}

final renvoiMessagesEnAttenteProvider = Provider<RenvoiMessagesEnAttente>((ref) {
  final renvoi = RenvoiMessagesEnAttente(ref)..demarrer();
  ref.onDispose(renvoi.arreter);
  return renvoi;
});
