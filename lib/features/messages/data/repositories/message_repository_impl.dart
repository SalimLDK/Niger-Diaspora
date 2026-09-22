import 'dart:developer' as dev;
import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:video_compress/video_compress.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/blurhash_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/crypto/mls/mls_gateway.dart';
import '../../../../core/crypto/mls/mls_message_mapper.dart';
import '../../../../core/crypto/mls/mls_source_merger.dart';
import '../../../../core/services/e2ee/media_encryption_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/paginated_messages.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;
  final BlurhashService blurhashService;

  /// Chiffrement des pièces jointes (plan MLS, C4). Nul dans les tests qui
  /// ne s'y intéressent pas ; l'envoi reste alors en clair.
  final MediaEncryptionService? mediaEncryptionService;

  /// Interrupteur serveur, lu à chaque envoi (pas au démarrage) : ouvrir le
  /// drapeau prend effet sans relancer l'app.
  final bool Function() mediasChiffresActifs;

  /// Messagerie MLS (plan MLS, phase 5). Nulle tant que rien ne l'injecte :
  /// le comportement est alors **exactement** celui d'avant, sans un appel
  /// réseau de plus. C'est ce qui rend ce branchement sûr à livrer avant
  /// d'avoir pu le vérifier sur deux téléphones.
  final MlsGateway? mlsGateway;

  /// Placeholders posés par la couche crypto quand un déchiffrement échoue.
  /// Signal (1:1) et Sender Key (groupes) consomment la clé de message au
  /// premier déchiffrement réussi — aucun cache de clés sautées côté client —
  /// donc retenter sur le MÊME message échoue toujours après coup. Ceci couvre
  /// le rechargement paginé (réouverture de conversation, pull-to-refresh,
  /// pagination) ; `_reconcileEcho` dans message_provider.dart fait le même
  /// constat côté écho temps réel.
  ///
  /// La liste elle-même vit dans `undecryptable_placeholders.dart` : elle
  /// existait ici en double et a divergé, au prix d'un message de groupe rendu
  /// illisible à son propre auteur.
  static const _undecryptablePlaceholders = kUndecryptablePlaceholders;

  // DocumentSnapshot? _lastDocument; // Removed: using stateless cursor via beforeMessageId (RTDB key)

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    CacheService? cacheService,
    BlurhashService? blurhashService,
    this.mediaEncryptionService,
    bool Function()? mediasChiffresActifs,
    this.mlsGateway,
  }) : cacheService = cacheService ?? CacheService.instance,
       blurhashService = blurhashService ?? BlurhashService(),
       mediasChiffresActifs = mediasChiffresActifs ?? (() => false);

  /// Collapse duplicate 1:1 conversations that share the same participant pair.
  ///
  /// Legacy data can hold two rows for the same two users: a 'request' row
  /// (accepted requests keep type='request') plus a plain 'individual' row
  /// created later because findIndividualConversation used to ignore request
  /// rows. Both map to [ConversationType.individual] here, so the same contact
  /// would appear twice in the list. We keep only the most recently active row
  /// per pair. Groups are never collapsed.
  List<ConversationEntity> _dedupConversationsByPair(
    List<ConversationEntity> conversations,
  ) {
    final indexByPair = <String, int>{};
    final result = <ConversationEntity>[];

    for (final c in conversations) {
      final key = _participantPairKey(c);
      if (key == null) {
        // Groups (or malformed pairs): never merged.
        result.add(c);
        continue;
      }

      final existingIndex = indexByPair[key];
      if (existingIndex == null) {
        indexByPair[key] = result.length;
        result.add(c);
      } else if (_isMoreRecentlyActive(c, result[existingIndex])) {
        // Keep the row that was actually used most recently.
        result[existingIndex] = c;
      }
    }
    return result;
  }

  /// Stable key for a 1:1 conversation's participant pair; null for groups
  /// or conversations without exactly two participants.
  String? _participantPairKey(ConversationEntity c) {
    if (c.isGroup) return null;
    if (c.participantIds.length != 2) return null;
    final ids = [...c.participantIds]..sort();
    return ids.join('|');
  }

  bool _isMoreRecentlyActive(ConversationEntity a, ConversationEntity b) {
    final aTime = a.lastMessageAt ?? a.createdAt;
    final bTime = b.lastMessageAt ?? b.createdAt;
    return aTime.isAfter(bTime);
  }

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
          for (final c in avecApercu) apercuDepuisNotification(c, apercus[c.id]),
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
      apercuDepuisCache(c, () => cacheService.getCachedMessages(c.id));

  /// Complète l'aperçu avec le texte déchiffré par l'isolate de notification,
  /// et seulement quand il n'y a rien d'autre à montrer.
  ///
  /// La règle seule, sans réseau. Trois refus, chacun pour une raison :
  ///
  /// - **un aperçu existe déjà** : le cache du fil est prioritaire, il
  ///   connaît les éditions que l'aperçu de notification ignore ;
  /// - **la base dit pourquoi l'aperçu est vide** (`apercuEfface`) : un
  ///   message supprimé ou expiré ne doit surtout pas revenir par cette
  ///   porte. L'aperçu de notification a été posé à la **réception**, avant
  ///   la suppression : c'est exactement le texte qu'on vient de retirer ;
  /// - **rien n'a jamais été envoyé** (`lastMessageAt` nul) : il n'y a pas de
  ///   dernier message à résumer.
  @visibleForTesting
  static ConversationEntity apercuDepuisNotification(
    ConversationEntity c,
    String? texte,
  ) {
    if (texte == null || texte.isEmpty) return c;
    if ((c.lastMessage ?? '').isNotEmpty) return c;
    if (c.lastMessageAt == null) return c;
    if (c.apercuEfface != ApercuEfface.aucun) return c;
    return c.copyWith(lastMessage: texte);
  }

  /// La règle seule, sans cache ni base — pour pouvoir la tenir par un test.
  /// Le cache n'est lu que si la conversation en a besoin.
  ///
  /// **Le cache est en retard sur une suppression, par construction.** Le
  /// serveur vide `messages.data->>'content'`, mais la copie locale garde le
  /// texte jusqu'au prochain rechargement de la discussion — et pour un
  /// message MLS, le serveur n'a jamais eu le clair à vider. Sans les deux
  /// gardes ci-dessous, ce passage rendrait à la liste le texte que
  /// « supprimer pour tout le monde » venait d'en retirer : la fuite refermée
  /// en base, rouverte depuis l'appareil.
  @visibleForTesting
  static ConversationEntity apercuDepuisCache(
    ConversationEntity c,
    List<Map<String, dynamic>> Function() messagesCaches,
  ) {
    final quand = c.lastMessageAt;
    if (quand == null) return c;
    if ((c.lastMessage ?? '').isNotEmpty) return c;
    // Garde 1 : la base dit déjà pourquoi l'aperçu est vide (chemin legacy).
    // Rien à reconstituer — le cache n'aurait que le texte à ne pas montrer.
    if (c.apercuEfface != ApercuEfface.aucun) return c;

    Map<String, dynamic>? dernier;
    DateTime? dernierQuand;
    for (final m in messagesCaches()) {
      final t = DateTime.tryParse(m['createdAt'] as String? ?? '');
      if (t == null) continue;
      if (dernierQuand == null || t.isAfter(dernierQuand)) {
        dernier = m;
        dernierQuand = t;
      }
    }
    if (dernier == null || dernierQuand == null) return c;
    if (dernierQuand.toUtc().difference(quand.toUtc()).inSeconds != 0) return c;

    // Garde 2 : le chemin MLS. Le serveur ne porte aucune marque — le trigger
    // d'aperçu retire `lastMessage` à chaque message chiffré, et la
    // suppression n'écrit que dans `mls_messages`. C'est donc le message
    // caché lui-même qui dit qu'il a été supprimé, et il le dit : la
    // passerelle recolle `deletedForEveryone` sur le fil avant de le mettre
    // en cache.
    if (dernier['deletedForEveryone'] == true) {
      return c.copyWith(lastMessageDeleted: true);
    }

    final texte = dernier['content'] as String? ?? '';
    if (texte.isEmpty) return c;
    // Un message que cet appareil n'a pas su déchiffrer est mis en cache avec
    // son placeholder. Le reprendre comme aperçu afficherait « 🔐 Message
    // chiffré » dans la liste des discussions — vu sur le SM A515F le
    // 2026-09-15. Mieux vaut le libellé de type, que l'écran dérive tout seul.
    if (texte == MlsMessageMapper.placeholderIllisible) return c;
    return c.copyWith(lastMessage: texte);
  }

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

      return Right(entities);
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
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
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
        );
        return Right(message.toEntity());
      });
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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
    );
    return Right(message.toEntity());
  }

  /// La passerelle MLS si — et seulement si — cette conversation doit
  /// passer par elle. Nulle sinon, et l'appelant reprend son chemin habituel.
  ///
  /// Centralisée parce qu'elle est appelée par les six méthodes d'envoi : un
  /// type de message oublié ici, et il partirait vers `messages` que le
  /// serveur refuse désormais pour une conversation basculée — l'envoi
  /// échouerait sans que rien n'explique pourquoi.
  Future<MlsGateway?> _passerellePour(String conversationId) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return null;
    return await passerelle.enMls(conversationId) ? passerelle : null;
  }

  /// Dernier déclenchement du rattrapage de fond.
  DateTime? _dernierRattrapage;

  /// Plancher entre deux planifications. Il ne régule plus grand-chose depuis
  /// que [rattrapageADeclencher] filtre sur « quelque chose a bougé » : ce qui
  /// reste est un garde-fou contre une conversation qui échoue en boucle.
  ///
  /// Il valait 20 s, et c'était trop : plusieurs messages reçus d'affilée —
  /// le cas de toute conversation vivante — voyaient le deuxième et le
  /// troisième bloqués par le premier, donc affichés « Message chiffré »
  /// pendant tout ce temps.
  ///
  /// **Un rattrapage retenu par ce plancher est reporté, jamais abandonné.**
  /// Il rendait la main sans rien reprogrammer : un message reçu moins de 5 s
  /// après le précédent — le premier échange de toute conversation — gardait
  /// « Message chiffré » dans la liste jusqu'à la prochaine émission du
  /// serveur, c'est-à-dire, liste immobile, jusqu'au message suivant ou à un
  /// tirer-pour-rafraîchir. Signalé par Salim le 2026-09-21.
  @visibleForTesting
  Duration espacementRattrapage = const Duration(seconds: 5);

  /// Combien la liste attend le déchiffrement avant d'émettre sans lui. Un
  /// déchiffrement normal prend ~2 s (réseau + MLS, mesuré le 2026-09-21).
  @visibleForTesting
  Duration attenteDechiffrementMax = const Duration(seconds: 3);

  /// La reprise programmée à la fin du plancher, s'il en faut une. Une seule
  /// à la fois : elle repart de la dernière liste reçue, pas de celle qui l'a
  /// demandée, puisque d'autres messages ont pu arriver entre-temps.
  Timer? _rattrapageReporte;
  ({MlsGateway passerelle, List<ConversationEntity> conversations})?
      _listeAReprendre;

  void _reporterRattrapage(
    MlsGateway passerelle,
    List<ConversationEntity> conversations,
    Duration delai,
  ) {
    _listeAReprendre = (passerelle: passerelle, conversations: conversations);
    if (_rattrapageReporte?.isActive ?? false) return;
    _rattrapageReporte = Timer(delai, () {
      _rattrapageReporte = null;
      final reprise = _listeAReprendre;
      _listeAReprendre = null;
      if (reprise == null || _rattrapageFini.isClosed) return;
      unawaited(
        _rattraperMlsEnArrierePlan(reprise.passerelle, reprise.conversations),
      );
    });
  }

  /// Ce pour quoi un rattrapage a déjà été **tenté** : conversation →
  /// `lastMessageAt` de la tentative. Une date neuve rouvre la tentative ; la
  /// même, non — sinon un fil qui refuse de se déchiffrer serait redemandé à
  /// chaque émission de la liste.
  final Map<String, DateTime> _rattrapageTente = {};

  /// Émis quand une passe de rattrapage a déchiffré et mis en cache : la
  /// liste se rejoue alors (voir [getConversations]). Sans ce signal, le
  /// rattrapage faisait tout le travail et personne ne le regardait.
  final StreamController<void> _rattrapageFini =
      StreamController<void>.broadcast();

  /// Fait recalculer la liste des discussions depuis sa dernière version
  /// serveur, sans attendre que la ligne `conversations` change.
  ///
  /// Pour une conversation chiffrée, l'aperçu est reconstitué depuis le cache
  /// local du fil (`apercuDepuisCache`) : tout geste qui modifie ce cache sans
  /// toucher `conversations` doit le signaler, sinon la liste garde ce qu'elle
  /// avait calculé avant.
  void _rejouerLaListe() {
    if (!_rattrapageFini.isClosed) _rattrapageFini.add(null);
  }

  /// Après « supprimer pour tous » d'un message chiffré : le message caché
  /// porte la marque, perd son texte, et la liste se recalcule.
  ///
  /// La suppression n'écrit que dans `mls_messages`. Le serveur n'a jamais eu
  /// le clair ; l'appareil, lui, le garde dans son cache, et la liste n'était
  /// pas rejouée. Vu le 2026-09-21 sur Pixel 10 Pro XL : la tuile de
  /// l'expéditeur affichait « Vous: PA6SECRET » deux minutes après la
  /// suppression, et jusqu'à la relance de l'app — le seul moment où la liste
  /// relisait le cache.
  ///
  /// L'entrée est vidée, pas seulement marquée : c'est la copie qui fuyait.
  /// La relecture du fil par la passerelle réécrira cette entrée de toute
  /// façon, avec la même marque — mais seulement au prochain passage, et
  /// une app tuée entre les deux laissait sur le disque ce que cette
  /// écriture n'avait pas retiré (voir [entreeCacheSupprimee]).
  Future<void> _marquerSupprimeDansLeCache(
    String conversationId,
    String messageId,
  ) async {
    try {
      final cached = cacheService.getCachedMessages(conversationId);
      final index = cached.indexWhere((m) => m['id'] == messageId);
      if (index != -1) {
        await cacheService.cacheMessages(
          conversationId,
          [entreeCacheSupprimee(cached[index])],
        );
      }
    } catch (e) {
      // La suppression serveur a réussi : un cache récalcitrant ne doit pas
      // la faire passer pour un échec.
      dev.log('Cache après suppression', name: 'message_repository_impl', error: e);
    }
    _rejouerLaListe();
  }

  /// Faut-il replanifier un rattrapage ? Oui dès qu'une conversation sans
  /// aperçu porte une date qu'on n'a pas encore tentée.
  ///
  /// La règle seule, sans réseau ni cache, pour pouvoir la tenir par un test.
  @visibleForTesting
  static bool rattrapageADeclencher({
    required Map<String, DateTime> candidats,
    required Map<String, DateTime> dejaTente,
  }) => candidats.entries.any((e) => dejaTente[e.key] != e.value);

  /// Déchiffre en tâche de fond les conversations dont le dernier message
  /// n'a jamais été lu sur cet appareil, et met le résultat en cache.
  ///
  /// Le cache est le point : c'est lui que `_loadCacheSync` affiche
  /// instantanément à l'ouverture. Déchiffrer sans mettre en cache ne ferait
  /// gagner que la moitié du temps.
  ///
  /// Ne lève jamais : un rattrapage raté coûte l'attente qu'on avait avant.
  ///
  /// [attente] : la liste qui attend cette passe (voir `_completerAvecMls`).
  /// Tant qu'elle ne l'a pas abandonnée, c'est elle qui relit le cache — la
  /// faire rejouer en plus émettrait deux fois la même chose. Nulle pour une
  /// passe reportée, que personne n'attend.
  Future<void> _rattraperMlsEnArrierePlan(
    MlsGateway passerelle,
    List<ConversationEntity> conversations, {
    _AttenteRattrapage? attente,
  }) async {
    // Ce qui reste à montrer : les conversations sans aperçu, avec la date du
    // message qu'on n'arrive pas à afficher.
    final candidats = {
      for (final c in conversations)
        if ((c.lastMessage ?? '').isEmpty && c.lastMessageAt != null)
          c.id: c.lastMessageAt!,
    };
    // Une conversation qui a retrouvé son aperçu sort de la mémoire des
    // tentatives : elle n'a plus rien à rattraper, et la table reste bornée.
    _rattrapageTente.removeWhere((id, _) => !candidats.containsKey(id));

    if (!rattrapageADeclencher(
      candidats: candidats,
      dejaTente: _rattrapageTente,
    )) {
      return;
    }

    final maintenant = DateTime.now();
    final precedent = _dernierRattrapage;
    if (precedent != null) {
      final ecoule = maintenant.difference(precedent);
      if (ecoule < espacementRattrapage) {
        _reporterRattrapage(passerelle, conversations,
            espacementRattrapage - ecoule);
        return;
      }
    }
    // Cette passe part de la liste la plus récente : une reprise en attente
    // n'aurait plus rien à ajouter.
    _rattrapageReporte?.cancel();
    _rattrapageReporte = null;
    _listeAReprendre = null;
    _dernierRattrapage = maintenant;

    var dechiffre = false;
    try {
      final aFaire = await passerelle.conversationsARattraper(
        [for (final c in conversations) c.id],
      );
      for (final id in aFaire) {
        // Retenue **avant** la tentative, et gardée même si elle échoue : une
        // conversation qui ne se déchiffre pas ne doit pas être redemandée à
        // chaque émission de la liste. Le prochain message y rouvrira la
        // tentative, puisque sa date changera.
        if (candidats[id] case final quand?) _rattrapageTente[id] = quand;
        try {
          final mls = await passerelle.messages(id);
          if (mls.isEmpty) continue;
          await cacheService.cacheMessages(
            id,
            jsonPourCacheMls(mls),
          );
          dechiffre = true;
        } catch (e) {
          dev.log('Rattrapage MLS impossible',
              name: 'message_repository_impl', error: e);
        }
      }
    } catch (e) {
      dev.log('Rattrapage MLS non planifié',
          name: 'message_repository_impl', error: e);
    }

    // Hors du `try`, et c'est tout l'objet du passage : sans ce signal, le
    // clair est en cache et la tuile continue d'afficher « Message chiffré ».
    final dejaRelu = attente != null && !attente.abandonnee;
    if (dechiffre && !dejaRelu && !_rattrapageFini.isClosed) {
      _rattrapageFini.add(null);
    }
  }

  /// La passerelle si **ce message-là** est un message MLS.
  ///
  /// L'aiguillage se fait par message, pas par conversation : une discussion
  /// basculée garde son historique en clair juste au-dessus du séparateur, et
  /// réagir à l'un de ces anciens messages doit continuer d'écrire dans
  /// `messages`. Se tromper de table ne lève rien — un `update … where id`
  /// sans cible réussit avec zéro ligne — et l'action paraîtrait juste « ne
  /// pas prendre ».
  Future<MlsGateway?> _passerelleMessage(
    String conversationId,
    String messageId,
  ) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return null;
    return await passerelle.estMlsMessage(conversationId, messageId)
        ? passerelle
        : null;
  }

  /// Exécute un envoi MLS, avec la règle du repli : avant la bascule, un
  /// échec peut encore emprunter le chemin d'aujourd'hui ; après, il remonte.
  ///
  /// **Et met le message en cache, comme le fait le chemin legacy.** Le clair
  /// de nos propres messages n'existe que sur cet appareil ; le chemin legacy
  /// le met en cache juste après l'envoi pour cette raison, le chemin MLS
  /// l'oubliait. Le cache ne le recevait qu'au prochain chargement du fil
  /// (`_fusionnerAvecMls`), c'est-à-dire en rouvrant la discussion.
  ///
  /// Ce que ça coûtait, entre l'envoi et cette réouverture : la liste des
  /// discussions perdait son aperçu. Le serveur avance `last_message_at` sur
  /// la note qu'on vient d'écrire, mais n'a pas son texte — il ne l'aura
  /// jamais — et `apercuDepuisCache` ne trouvait, côté cache, que le message
  /// d'AVANT. Les deux horodatages ne concordant pas, elle refusait, à raison.
  /// La discussion retombait donc sur son libellé de type. Constaté sur
  /// SM A515F le 2026-09-15, tuile « Mes notes » : « Notes, brouillons et
  /// sondages » à la place de la note écrite trente secondes plus tôt.
  ///
  /// L'égalité que cette garde exige n'est atteignable que parce que
  /// `MlsDelivery.publishMessage` relit `created_at` : le message mis en cache
  /// ici porte l'horodatage **du serveur**, celui-là même qui vient d'être
  /// écrit dans `last_message_at`. Les deux correctifs ne valent qu'ensemble.
  ///
  /// `cacheMessages` fusionne par id, donc ajouter une seule entrée est sans
  /// risque pour le reste du fil.
  Future<Either<Failure, MessageEntity>?> _tenterEnvoiMls(
    MlsGateway passerelle,
    String conversationId,
    Future<MessageEntity> Function() envoi,
  ) async {
    try {
      final envoye = await envoi();
      unawaited(cacheService.cacheMessages(
        conversationId,
        [MessageModel.fromEntity(envoye).toJson()],
      ));
      return Right(envoye);
    } catch (e) {
      if (!await passerelle.repliLegacyPossible(conversationId)) rethrow;
      dev.log('MLS indisponible, envoi en clair (conversation non basculée)',
          name: 'message_repository_impl', error: e);
      return null;
    }
  }

  /// Fusionne l'historique legacy déjà chargé avec le fil MLS.
  ///
  /// Rend la liste inchangée dès que MLS n'est pas concerné : pas de
  /// passerelle injectée, ou conversation jamais basculée et drapeau fermé.
  /// Un échec de lecture MLS ne coûte pas l'historique — il coûte les
  /// messages chiffrés, et se voit dans `mls_diagnostics`.
  Future<List<MessageEntity>> _fusionnerAvecMls(
    String conversationId,
    List<MessageEntity> legacy,
  ) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return legacy;
    try {
      if (!await passerelle.enMls(conversationId)) return legacy;
      // Le moteur ne sait pas relire ce qu'il a déjà déchiffré : au
      // lancement, le serveur n'a plus rien de lisible à offrir pour les
      // messages d'hier. Le cache de l'appareil, lui, a le clair — on le rend
      // à la passerelle avant de lui demander le fil.
      passerelle.amorcer(
        conversationId,
        _mlsDuCache(conversationId, await passerelle.mlsSince(conversationId)),
      );
      final mls = await passerelle.messages(conversationId);
      if (mls.isEmpty) return legacy;
      // Sans ce cache, rouvrir la discussion hors ligne ferait disparaître
      // les messages chiffrés : le serveur ne saura jamais les rendre en
      // clair, et le cliquet ne se rejoue pas.
      unawaited(cacheService.cacheMessages(
        conversationId,
        jsonPourCacheMls(mls),
      ));
      return MlsSourceMerger.fusionner(
        legacy: legacy,
        mls: mls,
        mlsSince: await passerelle.mlsSince(conversationId),
      );
    } catch (e) {
      dev.log('Fusion MLS impossible', name: 'message_repository_impl', error: e);
      return legacy;
    }
  }

  /// Les messages chiffrés déjà en cache sur cet appareil.
  ///
  /// Reconnus à leur date : une fois `mls_since` posé, le serveur refuse
  /// toute écriture en clair pour cette conversation — tout ce qui vient
  /// après la bascule est donc chiffré, et rien d'autre ne l'est.
  ///
  /// Les placeholders sont écartés : un « 🔐 Message chiffré » mis en cache
  /// par un passage précédent ne doit pas revenir prendre la place du clair
  /// qu'un autre passage avait obtenu.
  List<MessageEntity> _mlsDuCache(String conversationId, DateTime? depuis) =>
      mlsDuCache(cacheService.getCachedMessages(conversationId), depuis);

  /// Le fil chiffré, tel qu'il peut entrer dans le cache local.
  ///
  /// **Un message supprimé pour tous n'y entre que vidé.** Le cache est le
  /// seul endroit de l'appareil où le clair d'un message MLS survit d'un
  /// lancement à l'autre ; y écrire le texte, le chemin du fichier ou la clé
  /// du média d'un message supprimé, c'était garder sur le disque ce que le
  /// geste venait de retirer. `cacheMessages` remplace par identifiant : une
  /// entrée écrite en clair par un passage antérieur est réécrite vidée au
  /// passage suivant.
  ///
  /// La passerelle rend déjà un fil vidé ; la garde est répétée ici parce que
  /// c'est ici qu'on écrit.
  @visibleForTesting
  static List<Map<String, dynamic>> jsonPourCacheMls(
    List<MessageEntity> fil,
  ) => [
    for (final m in fil)
      MessageModel.fromEntity(
        m.deletedForEveryone ? m.videPourSuppression() : m,
      ).toJson(),
  ];

  /// Une entrée du cache local, réduite à la coquille d'un message supprimé
  /// pour tous (`MessageEntity.videPourSuppression`).
  ///
  /// Elle ne vidait que `content` : la clé du média, l'URL et le chemin local
  /// du fichier, les cartes partagées et la citation restaient sur le disque
  /// jusqu'au passage suivant du fil. Même aller-retour que toute écriture
  /// du cache (`MessageModel.toJson`, relu par `fromJson`), donc même liste
  /// d'inclusion que l'écran et la passerelle.
  @visibleForTesting
  static Map<String, dynamic> entreeCacheSupprimee(
    Map<String, dynamic> entree,
  ) => MessageModel.fromEntity(
    MessageModel.fromJson(entree).toEntity().videPourSuppression(),
  ).toJson();

  /// La règle seule, sans cache — pour pouvoir la tenir par un test.
  @visibleForTesting
  static List<MessageEntity> mlsDuCache(
    List<Map<String, dynamic>> caches,
    DateTime? depuis,
  ) {
    if (depuis == null) return const [];
    final sortie = <MessageEntity>[];
    for (final brut in caches) {
      try {
        final m = MessageModel.fromJson(brut).toEntity();
        if (m.createdAt.isBefore(depuis)) continue;
        if (MlsMessageMapper.estSeparateur(m)) continue;
        if (m.content == MlsMessageMapper.placeholderIllisible) continue;
        // Une entrée écrite avant que le fil ne soit vidé porte encore son
        // clair à côté du drapeau : elle n'en sort que vidée.
        sortie.add(m.deletedForEveryone ? m.videPourSuppression() : m);
      } catch (_) {
        // Une entrée de cache illisible ne coûte que ce message.
        continue;
      }
    }
    return sortie;
  }

  /// Lit la durée d'une vidéo locale sans la compresser (juste ses métadonnées),
  /// pour le badge de durée de `VideoBubble`.
  Future<int?> _getVideoDurationSeconds(String path) async {
    try {
      final info = await VideoCompress.getMediaInfo(path);
      final durationMs = info.duration;
      if (durationMs == null) return null;
      return (durationMs / 1000).round();
    } catch (e) {
      dev.log(
        'Impossible de lire la durée vidéo',
        name: 'message_repository_impl',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      final conversation = await remoteDataSource.createIndividualConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
      final conversation = await remoteDataSource.createGroupConversation(
        creatorId: creatorId,
        participantIds: participantIds,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        groupId: groupId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
      final passerelle = await _passerellePour(conversationId);
      if (passerelle != null) {
        await passerelle.marquerLus(conversationId);
      }
      await remoteDataSource.markAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.clearUnreadMentions(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  }) async {
    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity?>> getConversationById(
    String conversationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      final conversation = await remoteDataSource.getConversationById(
        conversationId,
      );
      return Right(conversation?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.restoreConversationForUser(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateSelfConversation({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      final conversation = await remoteDataSource.getOrCreateSelfConversation(
        userId: userId,
      );
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, PaginatedMessages>> getMessagesPaginated({
    required String conversationId,
    required int limit,
    String? beforeMessageId,
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
          filterAfterDate: filterAfterDate,
        );

        final hasMore = messages.length > limit;
        // Drop the oldest probe item used to detect hasMore, keeping the
        // newest `limit` messages (datasource returns ascending order).
        final trimmed = hasMore ? messages.sublist(1) : messages;
        final healed = _healUndecryptableMessages(conversationId, trimmed);

        final entities = healed.map((m) => m.toEntity()).toList();

        // Cache the messages
        final messageMaps = healed.map((m) => m.toJson()).toList();
        await cacheService.cacheMessages(conversationId, messageMaps);

        // debugPrint('💾 Repository: Cached ${messageMaps.length} messages');

        // Coexistence (plan MLS § 2.3) : l'historique legacy est gelé, le
        // fil MLS est vivant. On les fusionne ici, une fois, plutôt que de
        // faire connaître deux sources aux 81 fichiers de la couche messages.
        final fusionnes = await _fusionnerAvecMls(conversationId, entities);

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

        final entities =
            cachedMessages
                .map((m) => MessageModel.fromJson(m).toEntity())
                .toList();

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

  /// Restaure, depuis le cache local, le texte clair des messages qu'un
  /// rechargement réseau vient de rendre indéchiffrables.
  ///
  /// Symptôme observé : une conversation de groupe se déchiffre correctement
  /// à la première ouverture, puis affiche « 🔐 Message chiffré » /
  /// « session requise » sur les MÊMES messages dès qu'on la rouvre, fait un
  /// pull-to-refresh, ou charge une page plus ancienne. Cause : Signal (1:1)
  /// et Sender Key (groupes) font avancer un ratchet à sens unique à chaque
  /// déchiffrement réussi, sans conserver les clés de message déjà
  /// consommées — `getMessagesPaginated` re-fetch pourtant le même ciphertext
  /// depuis Supabase et retente `_crypto.decrypt` à chaque appel (voir
  /// `SenderKeyService.decryptWithSenderKey` : `chainIndex < senderKey.chainIndex`
  /// renvoie `null` sans jamais réussir une seconde fois). Le cache local,
  /// qui contient le texte déjà déchiffré avec succès la première fois, se
  /// faisait alors écraser par ce résultat en échec.
  List<MessageModel> _healUndecryptableMessages(
    String conversationId,
    List<MessageModel> freshMessages,
  ) {
    final hasFailure = freshMessages.any(
      (m) => _undecryptablePlaceholders.contains(m.content),
    );
    if (!hasFailure) return freshMessages;

    final knownGoodContent = <String, String>{};
    for (final cached in cacheService.getCachedMessages(conversationId)) {
      final id = cached['id'] as String?;
      final content = cached['content'] as String?;
      if (id != null &&
          content != null &&
          content.isNotEmpty &&
          !_undecryptablePlaceholders.contains(content)) {
        knownGoodContent[id] = content;
      }
    }
    if (knownGoodContent.isEmpty) return freshMessages;

    return freshMessages.map((m) {
      if (!_undecryptablePlaceholders.contains(m.content)) return m;
      final healedContent = knownGoodContent[m.id];
      return healedContent == null ? m : m.copyWith(content: healedContent);
    }).toList();
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
        .map((messages) {
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
            healed.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<MessageEntity>>(
            ServerFailure(error.toString()),
          );
        });

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
              jsonPourCacheMls(fil),
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
        .map((message) {
          return Right<Failure, MessageEntity>(message.toEntity());
        })
        .handleError((error) {
          return Left<Failure, MessageEntity>(ServerFailure(error.toString()));
        });
  }

  void resetPagination() {
    // _lastDocument = null;
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

    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      final messages = await remoteDataSource.getMediaMessages(
        conversationId: conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
      final trouves = <String, MessageEntity>{
        for (final m in messages) m.id: m.toEntity(),
      };

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
            if (estMedia && (e.fileUrl?.isNotEmpty ?? false)) {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, String?>> findConversationWithUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final conversation = await remoteDataSource.findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    try {
      final conversation = await remoteDataSource.findGroupConversationByName(
        groupName: groupName,
        userId: userId,
      );
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, String?>> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    try {
      final conversation = await remoteDataSource
          .findGroupConversationByGroupId(groupId: groupId, userId: userId);
      return Right(conversation?.id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        await passerelle.supprimerPourTous(messageId);
        await _marquerSupprimeDansLeCache(conversationId, messageId);
        return const Right(null);
      }
      await remoteDataSource.deleteMessageForEveryone(
        conversationId: conversationId,
        messageId: messageId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.archiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.unarchiveConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
      await remoteDataSource.muteConversation(
        conversationId: conversationId,
        userId: userId,
        duration: duration,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.unmuteConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.pinConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }

    try {
      await remoteDataSource.unpinConversation(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        await passerelle.basculerEtoile(messageId);
        return const Right(null);
      }
      await remoteDataSource.toggleStarMessage(
        conversationId: conversationId,
        messageId: messageId,
        userId: userId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> toggleReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
    required bool retirer,
  }) async {
    try {
      final passerelle = await _passerelleMessage(conversationId, messageId);
      if (passerelle != null) {
        if (retirer) {
          await passerelle.retirerReaction(messageId);
        } else {
          await passerelle.reagir(messageId, emoji);
        }
        return const Right(null);
      }
      if (retirer) {
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
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getStarredMessages({
    required String conversationId,
    required String userId,
  }) async {
    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> searchMessagesInConversation({
    required String conversationId,
    required String query,
  }) async {
    try {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

    try {
      await remoteDataSource.setAutoDeleteSettings(
        conversationId: conversationId,
        durationSeconds: durationSeconds,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
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

/// Transforme une erreur de flux en `Left(ServerFailure)` **réellement émis**.
///
/// Les trois flux de ce fichier (liste des discussions, discussion, messages)
/// se terminaient par :
///
/// ```dart
/// .handleError((error) { return Left(ServerFailure(error.toString())); });
/// ```
///
/// `Stream.handleError` **ignore la valeur de retour** de son callback : ce
/// `Left` n'a jamais été émis. L'erreur était donc purement avalée — aucun
/// événement, le provider restait en chargement pour toujours (rond de
/// chargement sans fin sur la liste, mesuré hors ligne le 2026-09-14), ni
/// bandeau ni réessai, et `conversationStreamProvider(...).future` — que lit
/// l'export d'une discussion — attendait indéfiniment.
///
/// `StreamTransformer.fromHandlers` pousse dans le sink : c'est déjà l'idiome
/// de `ProfileRepositoryImpl.getUserStream`.
StreamTransformer<Either<Failure, T>, Either<Failure, T>> _echecEmis<T>() {
  return StreamTransformer<Either<Failure, T>, Either<Failure, T>>.fromHandlers(
    handleData: (donnee, sink) => sink.add(donnee),
    handleError: (erreur, trace, sink) {
      sink.add(Left<Failure, T>(ServerFailure(erreur.toString())));
    },
  );
}

/// Une liste qui attend une passe de rattrapage, et si elle a cessé
/// d'attendre. Voir `MessageRepositoryImpl._completerAvecMls`.
class _AttenteRattrapage {
  bool abandonnee = false;
}
