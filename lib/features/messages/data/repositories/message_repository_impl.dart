import 'dart:developer' as dev;
import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:video_compress/video_compress.dart';

import '../../../../core/errors/classification_erreurs.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart' show NetworkInfo;
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

part 'message_repository_conversations.dart';
part 'message_repository_envoi.dart';
part 'message_repository_mls.dart';
part 'message_repository_messages.dart';

/// Reporte dans le cache Hive une métadonnée qui vient d'être écrite au
/// serveur (réaction, étoile).
///
/// Sans lui, réagir ou étoiler ne touchait que l'état en mémoire et le
/// serveur : hors ligne, le fil ressert le cache et montrait l'état d'avant —
/// une réaction retirée revenue, une réaction posée absente (SM A515F,
/// 2026-09-22). Un message absent du cache est laissé tel quel, et un échec
/// d'écriture locale ne fait pas échouer l'action, déjà faite côté serveur.
@visibleForTesting
Future<void> reporterDansLeCache(
  CacheService cache,
  String conversationId,
  String messageId,
  void Function(Map<String, dynamic> message) maj,
) async {
  try {
    final enCache = cache.getCachedMessages(conversationId);
    final i = enCache.indexWhere((m) => m['id'] == messageId);
    if (i == -1) return;
    final copie = Map<String, dynamic>.from(enCache[i]);
    maj(copie);
    await cache.cacheMessages(conversationId, [copie]);
  } catch (e) {
    dev.log('Cache non mis à jour', name: 'message_repository_impl', error: e);
  }
}

class MessageRepositoryImpl extends _MessageRepositoryBase
    with _Mls, _Conversations, _Envoi, _Messages {
  MessageRepositoryImpl({
    required super.remoteDataSource,
    required super.networkInfo,
    super.cacheService,
    super.blurhashService,
    super.mediaEncryptionService,
    super.mediasChiffresActifs,
    super.mlsGateway,
    super.oublierMedias,
  });

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

  /// Faut-il replanifier un rattrapage ? Oui dès qu'une conversation sans
  /// aperçu porte une date qu'on n'a pas encore tentée.
  ///
  /// La règle seule, sans réseau ni cache, pour pouvoir la tenir par un test.
  @visibleForTesting
  static bool rattrapageADeclencher({
    required Map<String, DateTime> candidats,
    required Map<String, DateTime> dejaTente,
  }) => candidats.entries.any((e) => dejaTente[e.key] != e.value);

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
}

/// Placeholders posés par la couche crypto quand un déchiffrement échoue —
/// voir la note sur leur rechargement dans [_MessageRepositoryBase].
const _undecryptablePlaceholders = kUndecryptablePlaceholders;

/// Ce que toutes les parties partagent : dépendances, état du rattrapage
/// MLS, et les aides communes. Chaque domaine vit dans son fichier `part`,
/// en mixin sur cette base.
abstract class _MessageRepositoryBase implements MessageRepository {
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
  // (`_undecryptablePlaceholders` : constante de bibliothèque, plus bas.)

  // DocumentSnapshot? _lastDocument; // Removed: using stateless cursor via beforeMessageId (RTDB key)

  _MessageRepositoryBase({
    required this.remoteDataSource,
    required this.networkInfo,
    CacheService? cacheService,
    BlurhashService? blurhashService,
    this.mediaEncryptionService,
    bool Function()? mediasChiffresActifs,
    this.mlsGateway,
    this.oublierMedias,
  }) : cacheService = cacheService ?? CacheService.instance,
       blurhashService = blurhashService ?? BlurhashService(),
       mediasChiffresActifs = mediasChiffresActifs ?? (() => false);

  /// Efface les copies locales en clair (média déchiffré, pièce jointe
  /// téléchargée) des messages qu'on lui nomme — `OubliMediasLocaux`.
  /// Nulle dans les tests qui n'en ont pas besoin.
  final void Function(Iterable<String> messageIds)? oublierMedias;

  /// Prévient [oublierMedias] des messages supprimés pour tous parmi
  /// [messages], et les rend tels quels.
  ///
  /// Posé sur les chemins par où un message en clair arrive à l'écran :
  /// c'est là qu'on apprend qu'il a été supprimé, que ce soit en direct, au
  /// rattrapage, ou au chargement d'une discussion restée fermée pendant la
  /// suppression. Les messages MLS, eux, sont signalés par la passerelle
  /// quand elle vide son fil.
  List<MessageEntity> _signalerSupprimes(List<MessageEntity> messages) {
    final oublier = oublierMedias;
    if (oublier == null || messages.isEmpty) return messages;
    final ids = [
      for (final m in messages)
        if (m.deletedForEveryone) m.id,
    ];
    if (ids.isNotEmpty) oublier(ids);
    return messages;
  }

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
}

/// Le filet commun des opérations du dépôt : une [ServerException] devient
/// son message, toute autre erreur est journalisée et rendue sous le message
/// générique. Une trentaine de méthodes répétaient ces six lignes à
/// l'identique (audit du 2026-10-03, dette du dépôt).
Future<Either<Failure, T>> _garde<T>(
  Future<Either<Failure, T>> Function() corps,
) async {
  try {
    return await corps();
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } catch (e) {
    dev.log('Erreur inattendue', name: 'message_repository_impl', error: e);
    return Left(ServerFailure(AppErrorMessages.unexpectedError));
  }
}

/// Transforme une erreur de flux en `Left(ServerFailure)` **réellement émis**.
///
/// Les cinq flux de ce fichier (liste des discussions, discussion, messages,
/// nouveaux messages, mises à jour) se terminaient par :
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
