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

part 'message_provider_pagination.dart';
part 'message_provider_envoi.dart';
part 'message_provider_actions.dart';
part 'message_provider_renvoi.dart';

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
