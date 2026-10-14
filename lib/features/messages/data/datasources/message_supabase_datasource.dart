import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/journal_echecs.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../../../core/services/notification_read_sync.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/utils/date_parsing.dart';
import '../../../../core/utils/lecture_sans_chevauchement.dart';
import '../../../../core/utils/realtime_rattrapage.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'message_remote_datasource.dart';

part 'message_supabase_flux.dart';
part 'message_supabase_envoi.dart';
part 'message_supabase_conversations.dart';
part 'message_supabase_retouches.dart';
part 'message_supabase_lectures.dart';

/// Champs de `data` qui portent du contenu utilisateur **sans passer par
/// `content`** — donc sans passer par Signal : la carte d'un post, d'un
/// événement, d'une annonce, l'aperçu d'un lien, et la citation d'un message
/// auquel on répond.
///
/// Ils partaient en clair dans `messages.data`. Le plus coûteux des cinq était
/// `replyToMessageData` : il recopie le **texte déjà déchiffré** du message
/// cité, si bien que chaque réponse reposait en clair à côté du message
/// chiffré qu'elle citait — et qu'une conversation active en laissait une
/// trace lisible message après message.
///
/// Ils sont désormais regroupés dans [_kAnnexesChiffrees], chiffré au repos
/// avec la clé dérivée de la conversation.
const _kChampsAnnexes = <String>[
  'postData',
  'eventData',
  'productData',
  'linkPreviewData',
  'replyToMessageData',
];

/// Clé du blob chiffré qui remplace les champs de [_kChampsAnnexes].
///
/// Un client plus ancien ne la connaît pas : il n'affichera pas la carte, mais
/// le texte du message reste lisible. Dégradation choisie — les deux formats
/// cohabitent sans migration, un message d'avant garde ses champs en clair et
/// se relit tel quel.
const _kAnnexesChiffrees = 'encAnnexes';

/// Clé du blob chiffré qui porte les métadonnées d'un média chiffré (chemin
/// du blob, clé de fichier, IV, nom d'origine — cf. `MediaChiffre`). Même
/// mécanisme que [_kAnnexesChiffrees], blob distinct : une annexe perdue coûte
/// une carte, un média perdu coûte la bulle entière.
const _kMediaChiffre = 'encMedia';

/// Clé, dans le modèle local seulement, de la forme EN CLAIR de ce blob.
const _kChampMediaChiffre = 'mediaChiffre';

/// Les deux marques de `conversations.data` qui disent **pourquoi** l'aperçu
/// de la liste des discussions est vide.
///
/// `lastMessage` porte le dernier message en clair. Deux choses le vident, et
/// elles ne se disent pas pareil à l'écran : « supprimer pour tout le monde »
/// (ici) et la purge des messages éphémères (`purger_messages_expires()`).
/// Sans marque, le client devait deviner — et il devinait « expiré » pour les
/// deux.
///
/// **Elles s'excluent, et tout écrivain d'aperçu les efface.** Poser l'une
/// retire l'autre ; un message qui arrive ensuite retire les deux. Une marque
/// oubliée sous un aperçu neuf ferait dire « Message supprimé » à une
/// conversation vivante, pour toujours.
///
/// `lastMessageDeleted` et `lastMessageExpired` ne s'écrivent plus d'ici :
/// les trois écrivains sont des fonctions SQL, chacune en une instruction —
/// `vider_apercu_si_dernier` (20261005100000), `purger_messages_expires` et
/// `apres_envoi_message` (qui retire les deux).

/// Forme du repli AES stocké : « iv:ct », ou « `v<n>:iv:ct` » avec une clé
/// dérivée. Filet pour le cas où le déchiffrement n'a pas eu lieu (service
/// crypto absent) : un contenu de cette forme n'est jamais du texte.
final _kFormeChiffre = RegExp(
  r'^(v\d+:)?[A-Za-z0-9+/]{16,}={0,2}:[A-Za-z0-9+/]{16,}={0,2}$',
);

/// Ne garde des résultats de recherche que ceux dont le CLAIR contient
/// [recherche] (sans casse).
///
/// Le serveur cherche dans ce qu'il stocke, donc dans le chiffré : ses
/// réponses comptent des faux positifs (« Yo » dans le base64), et des
/// messages indéchiffrables dont le marqueur contient lui-même le mot
/// (« message » trouve « [Message illisible] »). Ni l'un ni l'autre n'est
/// une réponse.
List<MessageModel> garderSiLeClairContient(
  Iterable<MessageModel> resultats,
  String recherche,
) {
  final aiguille = recherche.trim().toLowerCase();
  if (aiguille.isEmpty) return const [];
  return [
    for (final m in resultats)
      if (!isUndecryptableContent(m.content) &&
          !m.content.startsWith('gcm:') &&
          !_kFormeChiffre.hasMatch(m.content.trim()) &&
          m.content.toLowerCase().contains(aiguille))
        m,
  ];
}

/// Supabase implementation of [MessageRemoteDataSource].
///
/// Uses a NoSQL-like schema where minimal typed columns are indexed (id,
/// participant_ids, sender_id, type, created_at) and all other payload lives
/// in a JSONB `data` column. This lets us reuse [ConversationModel.fromJson]
/// and [MessageModel.fromJson] directly with minor key remapping.
class MessageSupabaseDataSource extends _MessageSupabaseBase
    with _Flux, _Envoi, _Conversations, _Retouches, _Lectures {
  MessageSupabaseDataSource({
    super.client,
    super.cryptoService,
    super.ensureReadableAuth,
    super.sessionEtablie,
  });

  /// Nom de fichier écrit en base à la place du nom d'origine d'un média
  /// chiffré : le vrai nom voyage dans le blob, comme la légende.
  @visibleForTesting
  static String nomGeneriquePour(String type) {
    switch (type) {
      case 'image':
        return 'photo';
      case 'video':
        return 'video';
      case 'voiceNote':
        return 'note-vocale';
      case 'audioFile':
        return 'audio';
      default:
        return 'document';
    }
  }
}

const _uuid = Uuid();

/// Compteur des suffixes de sujet des flux par discussion : partagé par
/// toutes les instances, puisque le client realtime l'est aussi.
int _channelSeq = 0;

/// Ce que toutes les parties partagent : client, canaux, conversions de
/// lignes, chiffrement des charges et écritures JSONB. Chaque domaine vit
/// dans son propre fichier `part`, en mixin sur cette base.
abstract class _MessageSupabaseBase implements MessageRemoteDataSource {
  _MessageSupabaseBase({
    SupabaseClient? client,
    MessageCryptoService? cryptoService,
    Future<bool> Function()? ensureReadableAuth,
    Stream<void>? sessionEtablie,
  }) : _supabase = client ?? Supabase.instance.client,
       _crypto = cryptoService,
       _ensureReadableAuth =
           ensureReadableAuth ?? SupabaseAuthBridge.instance.ensureReadableSession,
       _sessionEtablie =
           sessionEtablie ?? SupabaseAuthBridge.instance.sessionEtablie;

  final SupabaseClient _supabase;
  final MessageCryptoService? _crypto;

  /// Garde bornée avant une lecture — voir
  /// [SupabaseAuthBridge.ensureReadableSession] et le même motif dans
  /// `profile_supabase_datasource.dart`. Injectable pour les tests.
  final Future<bool> Function() _ensureReadableAuth;

  /// Une session neuve vient d'être établie — voir
  /// [SupabaseAuthBridge.sessionEtablie]. Injectable pour les tests.
  final Stream<void> _sessionEtablie;

  // ── Channel registry ─────────────────────────────────────────────────────

  /// Active realtime channels keyed by channel name so we can re-use them
  /// and avoid leaking subscriptions.
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeChannel _channel(String name) {
    return _channels.putIfAbsent(name, () => _supabase.channel(name));
  }

  /// Canaux dont l'abonnement realtime a été confirmé par le serveur.
  ///
  /// `RealtimeChannel.isJoined` existe mais est marqué `@internal` par le
  /// paquet : on tient donc l'information nous-mêmes, depuis le rappel de
  /// `subscribe`. Publier une présence sur un canal pas encore rejoint est
  /// perdu sans la moindre erreur.
  final Set<String> _joinedChannels = {};

  /// Canaux pour lesquels un `subscribe()` est déjà parti : le rappeler sur le
  /// même canal lève « tried to subscribe multiple times ».
  final Set<String> _subscribingChannels = {};

  /// S'abonne au canal si besoin, et attend la confirmation du serveur.
  ///
  /// Renvoie `false` si le canal n'a pas rejoint dans le délai : l'appelant
  /// abandonne alors son écriture plutôt que de la perdre en silence.
  Future<bool> _ensureJoined(String name) async {
    if (_joinedChannels.contains(name)) return true;

    final ch = _channel(name);
    if (_subscribingChannels.add(name)) {
      ch.subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _joinedChannels.add(name);
        }
      });
    }

    for (var i = 0; i < 20 && !_joinedChannels.contains(name); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _joinedChannels.contains(name);
  }

  void _forgetChannel(String name) {
    _channels.remove(name);
    _joinedChannels.remove(name);
    _subscribingChannels.remove(name);
  }

  // ── Row → Model helpers ───────────────────────────────────────────────────

  /// Convert a `conversations` row to a [ConversationModel].
  ///
  /// The row has typed columns (id, type, participant_ids, group_id,
  /// last_message_at, created_at, created_by) plus a JSONB `data` column
  /// that holds everything else. We merge them so [ConversationModel.fromJson]
  /// sees a single flat map.
  ConversationModel _convFromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return ConversationModel.fromJson({
      ...data,
      'id': row['id'],
      'type': row['type'],
      'participantIds': row['participant_ids'],
      'groupId': row['group_id'],
      'lastMessageAt': row['last_message_at'],
      'createdAt': row['created_at'],
      'createdBy': row['created_by'] ?? '',
    });
  }

  /// Union défensive avec d'éventuelles colonnes top-level `read_by`/
  /// `delivered_to` — aucune migration n'en crée à ce jour, seul le JSONB
  /// `data` (écrit par mark_messages_as_delivered/mark_messages_as_read) fait
  /// foi. `row['read_by']`/`row['delivered_to']` valent donc `null` et cette
  /// union se réduit à `data['readBy']`/`data['deliveredTo']`.
  Map<String, dynamic> _mergedReceipts(
    Map<String, dynamic> row,
    Map<String, dynamic> data,
  ) {
    List<String> uni(dynamic a, dynamic b) =>
        {
          ...((a as List?)?.map((e) => e.toString()) ?? const <String>[]),
          ...((b as List?)?.map((e) => e.toString()) ?? const <String>[]),
        }.toList();
    return {
      'readBy': uni(row['read_by'], data['readBy']),
      'deliveredTo': uni(row['delivered_to'], data['deliveredTo']),
    };
  }

  /// Convert a `messages` row to a [MessageModel] (sync, no decryption).
  MessageModel _msgFromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return MessageModel.fromJson({
      ...data,
      ..._mergedReceipts(row, data),
      'id': row['id'],
      'senderId': row['sender_id'],
      'type': row['type'],
      'createdAt': row['created_at'],
      'deletedForEveryone': row['is_deleted'] ?? false,
    });
  }

  /// Async variant that decrypts E2EE content before building the model.
  Future<MessageModel> _msgFromRowAsync(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );

    // Always decrypt when crypto is available — handles all 3 formats:
    //   'e2ee' → Signal (e2eePayloads / senderKeyPayload)
    //   'aes'  → clé dérivée (« v<n>:… »), clé globale (« iv:ct »), ou clair
    if (_crypto != null) {
      try {
        final senderId = (row['sender_id'] as String?) ?? '';
        // `conversationId` est indispensable au repli AES chiffré avec une clé
        // DÉRIVÉE : c'est de lui que la clé est reconstruite. Sans lui, un
        // message au format « v<n>:… » s'affiche « [Message illisible] » — et
        // rien d'autre ne le signale, puisque ce n'est pas une erreur.
        data['content'] = await _crypto.decrypt(
          payload: data,
          senderId: senderId,
          conversationId: row['conversation_id'] as String?,
        );
      } catch (e) {
        debugPrint('MessageSupabaseDataSource: decrypt error: $e');
        if (data['encryptionLevel'] == 'e2ee') {
          data['content'] = kEncryptedMessagePlaceholder;
        }
      }

      await _fusionnerAnnexes(data, row['conversation_id'] as String?);
      await _fusionnerMedia(data, row['conversation_id'] as String?);
    }

    return MessageModel.fromJson({
      ...data,
      ..._mergedReceipts(row, data),
      'id': row['id'],
      'senderId': row['sender_id'],
      'type': row['type'],
      'createdAt': row['created_at'],
      'deletedForEveryone': row['is_deleted'] ?? false,
    });
  }

  /// Chiffre les charges annexes d'un message en un seul blob.
  ///
  /// Rend la map à fusionner dans `data` : soit vide, soit le seul
  /// [_kAnnexesChiffrees] — **jamais** les champs en clair. Un chiffrement
  /// impossible fait donc perdre la carte, pas le message : le contraire
  /// (retomber en clair) annulerait tout le bénéfice sans rien dire.
  Future<Map<String, dynamic>> _chiffrerAnnexes(
    Map<String, Map<String, dynamic>?> annexes,
    String conversationId,
  ) async {
    final presentes = <String, dynamic>{
      for (final entree in annexes.entries)
        if (entree.value != null) entree.key: entree.value,
    };
    if (presentes.isEmpty) return const {};

    final crypto = _crypto;
    if (crypto == null) return const {};

    try {
      return {
        _kAnnexesChiffrees: await crypto.chiffrerAnnexe(
          jsonEncode(presentes),
          conversationId: conversationId,
        ),
      };
    } catch (e) {
      debugPrint('MessageSupabaseDataSource: annexes non chiffrées ($e)');
      return const {};
    }
  }

  /// Forme **chiffrée** des charges annexes, à étaler dans `msgData`.
  ///
  /// Les cinq méthodes d'envoi passent par ici : c'est ce qui garantit qu'une
  /// citation ou une carte ne peut pas repartir en clair par un chemin oublié.
  Future<Map<String, dynamic>> _annexesChiffreesPour(
    String conversationId, {
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? linkPreviewData,
  }) {
    return _chiffrerAnnexes({
      'replyToMessageData': replyToMessageData,
      'postData': postData,
      'eventData': eventData,
      'productData': productData,
      'linkPreviewData': linkPreviewData,
    }, conversationId);
  }

  /// Forme **en clair** des mêmes charges, pour le modèle rendu à
  /// l'expéditeur : celui-là ne quitte pas l'appareil, et sans lui l'auteur
  /// verrait sa propre citation ou sa propre carte disparaître de sa bulle
  /// jusqu'au prochain chargement.
  Map<String, dynamic> _annexesEnClair({
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? linkPreviewData,
  }) {
    return {
      if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
      if (postData != null) 'postData': postData,
      if (eventData != null) 'eventData': eventData,
      if (productData != null) 'productData': productData,
      if (linkPreviewData != null) 'linkPreviewData': linkPreviewData,
    };
  }

  /// Résout la cible de chiffrement d'un message depuis sa conversation.
  ///
  /// L'envoi la reçoit déjà résolue par le provider ; [editMessage], lui, n'a
  /// que l'identifiant de la conversation — faute de cette résolution, il
  /// n'avait aucun moyen de rechiffrer et réécrivait le texte modifié en clair.
  ///
  /// Mêmes règles que l'envoi, dans le même ordre : « Mes notes », puis 1:1,
  /// puis groupe.
  Future<({String? recipientId, List<String> participantIds, bool selfNote})>
  _cibleChiffrement(String conversationId, String senderId) async {
    const aucune = (
      recipientId: null,
      participantIds: <String>[],
      selfNote: false,
    );

    final rows = await _supabase
        .from('conversations')
        .select('type, participant_ids, group_id')
        .eq('id', conversationId)
        .limit(1);
    if (rows.isEmpty) return aucune;

    final row = rows.first;
    final participants = <String>[
      ...?(row['participant_ids'] as List?)?.map((e) => e.toString()),
    ];
    final estGroupe = row['type'] == 'group' || row['group_id'] != null;

    if (!estGroupe &&
        participants.length == 1 &&
        participants.first == senderId) {
      return (
        recipientId: null,
        participantIds: <String>[],
        selfNote: true,
      );
    }

    if (!estGroupe) {
      final autre = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );
      return (
        recipientId: autre.isEmpty ? null : autre,
        participantIds: <String>[],
        selfNote: false,
      );
    }

    return (
      recipientId: null,
      participantIds: participants.where((id) => id != senderId).toList(),
      selfNote: false,
    );
  }

  /// Remet les charges annexes déchiffrées dans `data`, à leur place d'origine.
  ///
  /// Ne touche pas aux champs déjà présents en clair : un message d'avant la
  /// bascule les porte tels quels, et c'est lui qui fait foi. Un échec de
  /// déchiffrement laisse simplement la carte absente — le texte du message,
  /// lui, a déjà été résolu par le chemin de `content`.
  Future<void> _fusionnerAnnexes(
    Map<String, dynamic> data,
    String? conversationId,
  ) async {
    final chiffre = data[_kAnnexesChiffrees];
    if (chiffre is! String || chiffre.isEmpty) return;

    final crypto = _crypto;
    if (crypto == null) return;

    try {
      final clair = await crypto.dechiffrerAnnexe(
        chiffre,
        conversationId: conversationId,
      );
      final decode = jsonDecode(clair);
      if (decode is! Map) return;

      for (final champ in _kChampsAnnexes) {
        final valeur = decode[champ];
        if (valeur is Map && !data.containsKey(champ)) {
          data[champ] = Map<String, dynamic>.from(valeur);
        }
      }
    } catch (e) {
      // Clé indisponible, version inconnue, marqueur d'illisibilité renvoyé à
      // la place du JSON : aucune de ces situations ne doit coûter le message.
      debugPrint('MessageSupabaseDataSource: annexes illisibles ($e)');
    }
  }

  /// Scelle les métadonnées d'un média chiffré dans [_kMediaChiffre].
  ///
  /// Contrairement aux annexes, un échec ici **fait échouer l'envoi** : sans
  /// sa clé, le destinataire n'aurait qu'un blob ; et cette clé ne doit
  /// jamais partir en clair, ni en repli.
  Future<Map<String, dynamic>> _scellerMedia(
    Map<String, dynamic>? media,
    String conversationId,
  ) async {
    if (media == null) return const {};
    final crypto = _crypto;
    if (crypto == null) {
      throw ServerException('Chiffrement du média indisponible');
    }
    final scelle = await crypto.chiffrerAnnexe(
      jsonEncode(media),
      conversationId: conversationId,
    );
    // `chiffrerAnnexe` retombe sur la clé globale de l'APK quand la clé
    // dérivée manque (format `iv:ct`, deux segments, contre `v<n>:iv:ct`).
    // Acceptable pour une carte de partage, pas pour la clé d'un fichier :
    // elle serait lisible par tout porteur de l'APK. On refuse, et l'envoi
    // échoue visiblement.
    if (scelle.isEmpty || scelle.split(':').length < 3) {
      throw ServerException(
        'Clé de conversation indisponible : média non envoyé',
      );
    }
    return {_kMediaChiffre: scelle};
  }

  /// Relit [_kMediaChiffre] et pose la forme en clair sous
  /// [_kChampMediaChiffre], en restaurant le nom d'origine du fichier.
  Future<void> _fusionnerMedia(
    Map<String, dynamic> data,
    String? conversationId,
  ) async {
    final chiffre = data[_kMediaChiffre];
    if (chiffre is! String || chiffre.isEmpty) return;

    final crypto = _crypto;
    if (crypto == null) return;

    try {
      final clair = await crypto.dechiffrerAnnexe(
        chiffre,
        conversationId: conversationId,
      );
      final decode = jsonDecode(clair);
      if (decode is! Map) return;
      final media = Map<String, dynamic>.from(decode);
      data[_kChampMediaChiffre] = media;
      final nom = media['fileName'];
      if (nom is String && nom.isNotEmpty) data['fileName'] = nom;
    } catch (e) {
      // Clé indisponible ou blob illisible : la bulle affichera l'état
      // « média chiffré illisible », pas un blob brut.
      debugPrint('MessageSupabaseDataSource: média chiffré illisible ($e)');
    }
  }

  /// Encrypt plaintext using Signal Protocol (E2EE mandatory — no AES fallback).
  ///
  /// Guards (checked in order, each throws [ServerException] with a specific
  /// user-visible message on failure):
  ///  1. Crypto service present
  ///  2. E2EE service initialized for the current user
  ///  3. Recipient / group target provided
  ///  4. [1:1 only] Recipient has published pre-keys on Firebase
  ///  5. [1:1 only] Session established locally (fast path if already exists)
  ///  6. Result is actually E2EE — not AES fallback
  Future<Map<String, dynamic>> _encryptContent({
    required String plaintext,
    String? recipientId,
    List<String> participantIds = const [],
    required String conversationId,
    bool selfNote = false,
  }) async {
    if (_crypto == null) {
      throw E2EEException('Service de chiffrement non initialisé.');
    }

    // « Mes notes » : self-chat, donc aucun destinataire par construction — et
    // aucune session Signal possible avec soi-même. On court-circuite AVANT les
    // deux gardes ci-dessous : ni l'initialisation E2EE ni la présence d'un
    // destinataire ne sont pertinentes ici. Chiffrement au repos — désormais
    // avec la clé dérivée de l'UTILISATEUR quand elle est disponible (une note
    // n'a pas de destinataire, sa portée naturelle est le compte), et la clé
    // globale en repli.
    if (selfNote) {
      final selfResult = await _crypto.encryptSelfNote(plaintext);
      unawaited(
        AnalyticsService.instance.logMessageEncryption(
          level: selfResult.encryptionLevel,
          scope: 'self',
          fallbackReason: null,
        ),
      );
      return selfResult.fields;
    }

    // Volontairement PAS de garde sur `isE2EEInitialized` ici.
    //
    // `encrypt1to1()` et `encryptGroup()` retombent déjà d'eux-mêmes sur l'AES
    // global quand Signal n'est pas disponible — c'est le repli prévu par
    // l'architecture, celui-là même qui sert quand le destinataire n'a jamais
    // publié ses clés. Une garde qui lève ici contredisait ce design et rendait
    // l'envoi de texte totalement impossible tant que l'initialisation Signal
    // n'était pas terminée (soit, avant le correctif d'initialisation : à vie).
    //
    // Le niveau réellement obtenu ('e2ee' ou 'aes') est remonté dans
    // `encryptionLevel` et tracé dans l'analytics : on dégrade en le sachant,
    // on ne bloque pas l'utilisateur.

    if (recipientId == null && participantIds.isEmpty) {
      throw E2EEException('Destinataire manquant — chiffrement impossible.');
    }

    try {
      final CryptoResult result;
      bool recipientHadKeys = false;

      if (recipientId != null) {
        // On tente d'établir une session Signal seulement si le destinataire a
        // publié ses pré-clés. Sinon (jamais activé E2EE), on n'attend pas :
        // encrypt1to1() retombe automatiquement sur AES (clé globale), le
        // repli prévu par l'architecture — le message part quand même.
        recipientHadKeys = await _crypto.recipientHasKeys(recipientId);
        if (recipientHadKeys) {
          // Fast path: if a local session already exists, skip X3DH entirely.
          final sessionExists = await _crypto.hasSessionFor(recipientId);
          if (!sessionExists) {
            // No local session — run X3DH with a 10 s safety timeout.
            try {
              await _crypto
                  .preEstablishSessions([recipientId])
                  .timeout(const Duration(seconds: 10));
            } on TimeoutException {
              debugPrint(
                'MessageSupabaseDataSource: Signal session setup timed out',
              );
            }
          }
        }

        result = await _crypto.encrypt1to1(
          plaintext: plaintext,
          recipientId: recipientId,
          conversationId: conversationId,
        );
      } else {
        // Groups: distribute Sender Key to all members before encrypting.
        try {
          await _crypto
              .distributeGroupSenderKey(
                groupId: conversationId,
                memberIds: participantIds,
              )
              .timeout(const Duration(seconds: 10));
        } on TimeoutException {
          debugPrint('MessageSupabaseDataSource: Sender Key setup timed out');
        }
        // `conversationId` est passé explicitement en plus de `groupId` : ici
        // les deux coïncident, mais c'est de l'identifiant de CONVERSATION que
        // la clé est dérivée — et c'est lui que Postgres a sous la main pour
        // reconstruire la même clé côté aperçu de notification.
        result = await _crypto.encryptGroup(
          plaintext,
          groupId: conversationId,
          conversationId: conversationId,
        );
      }

      // Instrumentation continue du taux de repli AES (fire-and-forget, non
      // bloquant). Ne jamais laisser l'analytics impacter l'envoi.
      final isDirect = recipientId != null;
      String? fallbackReason;
      if (result.encryptionLevel == 'aes') {
        fallbackReason =
            isDirect
                ? (recipientHadKeys ? 'session_failed' : 'recipient_no_keys')
                : 'sender_key_failed';
      }
      unawaited(
        AnalyticsService.instance.logMessageEncryption(
          level: result.encryptionLevel,
          scope: isDirect ? 'direct' : 'group',
          fallbackReason: fallbackReason,
        ),
      );

      // On accepte le résultat quel que soit son niveau : 'e2ee' si une session
      // Signal a pu être établie, 'aes' (repli clé globale) sinon. Ne jamais
      // bloquer l'envoi ici — le repli AES est le comportement prévu.
      return result.fields;
    } on E2EEException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw E2EEException('Erreur de chiffrement : $e');
    }
  }

  // ── Conversation last-message helper ─────────────────────────────────────

  /// Fetch, merge, and update the `data` JSONB of a conversation row.
  Future<void> _updateConversationLastMessage(
    String convId, {
    required String? text,
    required String senderId,
    required String type,
    required String messageId,
  }) async {
    // Une seule instruction côté serveur (`apres_envoi_message`,
    // 20261004100000) au lieu de « lire data, incrémenter unreadCount en
    // mémoire, réécrire data » : deux envois simultanés perdaient un
    // incrément (mesuré : 8 pastilles sur 30 pour 40 envois concurrents), et
    // une sourdine posée pendant l'envoi disparaissait. L'expéditeur est lu
    // dans le jeton par le serveur : [senderId] ne sert plus qu'à la
    // signature.
    //
    // [messageId] : `last_message_at` recopie le `created_at` DE CE MESSAGE
    // (20261005090000). C'est à cette égalité que « supprimer pour tout le
    // monde » et la purge des éphémères reconnaissent le dernier message ;
    // deux `now()` de deux requêtes ne sont jamais égaux, et l'aperçu en
    // clair d'un message supprimé restait affiché dans la liste.
    try {
      await _supabase.rpc('apres_envoi_message', params: {
        'p_conversation_id': convId,
        'p_message_id': messageId,
        'p_apercu': {
          if (text != null) 'lastMessage': text,
          'lastMessageType': type,
        },
      });
    } catch (e) {
      // Non-critical: message is already persisted
      debugPrint(
        'MessageSupabaseDataSource: _updateConversationLastMessage error: $e',
      );
    }
  }

  // ── Messages éphémères ───────────────────────────────────────────────────

  /// Insère un message utilisateur et, si la conversation porte un minuteur,
  /// y pose son `expiresAt`.
  ///
  /// **Le calcul vit ici, au seul point d'insertion.** Il vivait recopié dans
  /// chacune des cinq méthodes d'envoi de l'ancien datasource Firestore, et
  /// c'est exactement pour ça qu'il a disparu en entier au portage vers
  /// Supabase : cinq copies à reporter, zéro reportée, aucune erreur nulle
  /// part. L'écran de réglage a continué d'écrire `autoDeleteAfterSeconds`,
  /// `MessageModel.expiresAt` a continué de se sérialiser, et plus rien
  /// n'expirait. Une septième méthode d'envoi ajoutée demain passera par ici
  /// ou n'insérera pas.
  ///
  /// Les messages **système** ne passent pas par ce chemin : « X a rejoint le
  /// groupe » décrit la conversation, pas son contenu, et disparaîtrait en
  /// laissant un trou inexplicable.
  ///
  /// [data] est **muté** avant l'insertion : l'appelant rend ensuite
  /// `MessageModel.fromJson({...msgData, …})` à l'expéditeur, et sans cette
  /// mutation sa propre bulle ignorerait l'échéance jusqu'au prochain
  /// chargement.
  Future<void> _insererMessageUtilisateur({
    required String id,
    required String conversationId,
    required String senderId,
    required String type,
    required String createdAt,
    required Map<String, dynamic> data,
  }) async {
    final secondes = await _minuteurDe(conversationId);
    if (secondes != null && secondes > 0) {
      data['expiresAt'] = DateTime.parse(createdAt)
          .add(Duration(seconds: secondes))
          .toUtc()
          .toIso8601String();
    }

    await _supabase.from('messages').insert({
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': type,
      'created_at': createdAt,
      'data': data,
    });
  }

  /// Le minuteur de la conversation en secondes, `null` s'il est coupé.
  ///
  /// Relu à chaque envoi plutôt que mémorisé : un minuteur qu'on vient
  /// d'activer doit mordre dès le message suivant, et un qu'on vient de
  /// couper ne doit plus rien marquer.
  ///
  /// **Une lecture en échec fait échouer l'envoi**, volontairement : elle ne
  /// sait pas distinguer « pas de minuteur » d'« impossible de savoir », et
  /// livrer un message permanent dans une conversation que l'utilisateur
  /// croit éphémère est le pire des deux dénouements. Le coût en fiabilité
  /// est faible : ce SELECT vise le même Postgres que l'INSERT qui suit, les
  /// deux tombent ensemble.
  Future<int?> _minuteurDe(String conversationId) =>
      getAutoDeleteSettings(conversationId);


  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Merge a partial update into the `data` JSONB of a conversation row.
  ///
  /// If [merge] is true, sub-keys of nested maps are merged rather than
  /// replaced entirely (useful for unreadCount, mutedBy, etc.).
  Future<void> _mergeConvData(
    String conversationId,
    Map<String, dynamic> partial, {
    bool merge = false,
  }) async {
    // Fusion faite DANS l'UPDATE (`fusionner_donnees_conversation`,
    // 20261004100000) : lire puis réécrire `data` entier effaçait toute
    // écriture concurrente — une sourdine, un épinglage, un compteur.
    try {
      await _supabase.rpc('fusionner_donnees_conversation', params: {
        'p_conversation_id': conversationId,
        'p_partiel': partial,
        'p_profond': merge,
      });
    } catch (e) {
      throw ServerException('_mergeConvData error: $e');
    }
  }

  /// Remove a single key from a nested map inside `data` JSONB.
  Future<void> _removeNestedConvDataKey(
    String conversationId,
    String parentKey,
    String childKey,
  ) async {
    try {
      await _supabase.rpc('retirer_cle_donnees_conversation', params: {
        'p_conversation_id': conversationId,
        'p_parent': parentKey,
        'p_enfant': childKey,
      });
    } catch (e) {
      throw ServerException('_removeNestedConvDataKey error: $e');
    }
  }

  /// Merge a partial update into the `data` JSONB of a message row.
  ///
  /// If [appendToList] is true, [partial] must be `{key: singleValue}` and
  /// the value is appended to the existing list at that key.
  Future<void> _mergeMsgData(
    String messageId,
    Map<String, dynamic> partial, {
    bool appendToList = false,
  }) async {
    // Fusion faite DANS l'UPDATE (`fusionner_donnees_message`) : réécrire
    // `data` entier effaçait un accusé de lecture arrivé entre la lecture et
    // l'écriture — et `messages_garde_update` l'acceptait, `readBy` étant une
    // clé autorisée.
    try {
      await _supabase.rpc('fusionner_donnees_message', params: {
        'p_message_id': messageId,
        'p_partiel': partial,
        'p_ajout_liste': appendToList,
      });
    } catch (e) {
      throw ServerException('_mergeMsgData error: $e');
    }
  }
}

/// Filtre PostgREST des messages strictement plus anciens que le curseur
/// `(createdAt, id)`, dans l'ordre `created_at desc, id desc` de la page.
///
/// Valeurs entre guillemets : une date porte `:` et `.`, que la syntaxe des
/// arbres logiques de PostgREST réserve.
@visibleForTesting
String filtreAvantCurseur(DateTime createdAt, String id) {
  final date = createdAt.toUtc().toIso8601String();
  return 'created_at.lt."$date",'
      'and(created_at.eq."$date",id.lt."$id")';
}
