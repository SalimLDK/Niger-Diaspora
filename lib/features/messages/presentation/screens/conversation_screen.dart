import 'package:diaspo_niger/core/constants/deleted_account.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/crypto/mls/mls_providers.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import '../../data/datasources/lecture_serveur.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/media_upload_provider.dart';
import '../widgets/conversation_options_modal.dart';
import '../widgets/forward_conversation_picker.dart';
import '../widgets/message_bubble.dart';
import '../utils/message_copy_text.dart';
import '../utils/message_grouping.dart';
import '../utils/phrase_modification.dart';
import '../widgets/message_input.dart';
import '../widgets/note_poll_draft_sheet.dart';
import '../widgets/typing_indicator_widget.dart';
import '../widgets/messages_skeleton.dart';
import '../widgets/uploading_media_skeleton.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
// Fonctionnalité épingle mise en pause : `GroupPinnedItemType` n'est plus
// utilisé en dehors des blocs commentés ci-dessous.
// import '../../../groups/domain/entities/group_pinned_item_entity.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../groups/presentation/providers/group_pinned_providers.dart';
import '../../../groups/presentation/widgets/group_pinned_banner.dart';
import '../../../polls/domain/entities/poll_entity.dart';
import '../../../polls/presentation/widgets/create_poll_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../settings/data/models/chat_background_model.dart';
import '../../../settings/domain/entities/chat_background_entity.dart';
import '../widgets/chat_background_picker_modal.dart';
import '../widgets/chat_wallpapers.dart';
import 'dart:convert';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/in_app_notification_provider.dart';
import '../../domain/services/message_deletion_service.dart';
// Appels mis en pause (1-à-1 le 2026-08-14, groupe le 2026-09-14) :
// imports devenus inutilisés, conservés en commentaire pour réactivation.
// TODO(appels): réactiver après vérification à deux vrais téléphones —
// protocole dans TESTS_APPAREIL_A_FAIRE.md, section « Appels 1-à-1 mis en
// PAUSE (2026-08-14) ».
// import '../../../calls/domain/entities/call_entity.dart';
// import '../../../calls/presentation/providers/call_provider.dart';
// import '../../../group_calls/domain/entities/group_call_entity.dart';
// import '../../../group_calls/presentation/providers/group_call_provider.dart';
// import '../../../calls/presentation/screens/call_screen.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../feed/domain/entities/post_entity.dart'
    show MentionCandidate;
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? conversationName;
  final String? conversationImageUrl;
  final String? otherUserId;
  final bool isGroup;
  final String? groupId;

  /// « Mes notes » : conversation avec soi-même (brouillon/scratchpad).
  final bool isSelfNotes;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.conversationName,
    this.conversationImageUrl,
    this.otherUserId,
    this.isGroup = false,
    this.groupId,
    this.isSelfNotes = false,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

/// Les non-lus d'un fil, et le rang du premier.
///
/// **Un message système n'est pas du courrier.** Il n'a pas d'expéditeur à
/// qui répondre, personne ne le « lit », et rien ne viendra jamais le marquer
/// comme lu. Le compter donnait un bandeau « 1 message non lu » qui ne
/// s'effaçait plus — vu le 2026-09-15 sur SM A515F, dans la première
/// conversation basculée en MLS : le séparateur « Messages d'avant le
/// chiffrement de bout en bout » est un message système synthétique
/// (`senderId: 'system'`, `readBy` vide), donc éternellement non lu. Le
/// serveur, lui, disait bien zéro.
///
/// C'est d'ailleurs la règle du serveur : la vue `mls_unread_counts` ne
/// compte que `kind = 'content'` et exclut l'expéditeur. Ici, la même.
///
/// Sortie hors de l'État pour être tenue par un test : c'est une règle, pas
/// un morceau d'écran.
({int nombre, int? premier}) compterNonLus(
  List<MessageEntity> messages,
  String moi,
) {
  var nombre = 0;
  int? premier;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (m.type == MessageType.system) continue;
    if (m.senderId == moi) continue;
    if (m.readBy.contains(moi)) continue;
    nombre++;
    premier ??= i;
  }
  return (nombre: nombre, premier: premier);
}

/// Le rang du premier des [combien] derniers messages **d'autrui**, en
/// remontant depuis la fin.
///
/// Sert quand les messages reviennent du serveur **déjà marqués lus** et que
/// [compterNonLus] ne peut donc plus rien trouver : `markAsRead` part dès
/// `initState`, avant même que les messages chiffrés ne soient récupérés.
/// Mesuré le 2026-09-15 sur Pixel 10 Pro XL : `delivered_at` et `read_at`
/// posés à 7 ms d'écart à l'instant de l'ouverture. Le séparateur ne pouvait
/// alors **jamais** s'afficher sur une conversation chiffrée.
///
/// Le compte, lui, vient du serveur et a été relevé **avant** l'ouverture (la
/// tuile de la liste le portait déjà). Même exclusion que `compterNonLus` :
/// ni message système, ni les miens.
/// Ce qui est arrivé **depuis la dernière visite** : combien, et à quel rang
/// commence le premier.
///
/// C'est le seul repère fiable pour le séparateur « N messages non lus ».
/// Les deux autres candidats mentent :
///
/// - **l'état de lecture des messages** est déjà faussé quand le fil arrive :
///   `markAsRead` part au premier rendu, avant même que les messages chiffrés
///   ne soient récupérés, et ils reviennent marqués lus ;
/// - **le compteur de la liste** met quelques secondes à retomber à zéro après
///   lecture. S'y fier faisait réapparaître « 7 messages non lus » en rouvrant
///   la discussion aussitôt après l'avoir lue — signalé à l'usage le
///   2026-09-15, et c'est bien ce correctif-ci qui l'avait introduit.
///
/// La date de visite, elle, est écrite par cet appareil en quittant l'écran :
/// elle ne dépend d'aucun aller-retour.
({int nombre, int? premier}) compterDepuis(
  List<MessageEntity> messages,
  String moi,
  DateTime depuis,
) {
  var nombre = 0;
  int? premier;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (m.type == MessageType.system) continue;
    if (m.senderId == moi) continue;
    if (!m.createdAt.isAfter(depuis)) continue;
    nombre++;
    premier ??= i;
  }
  return (nombre: nombre, premier: premier);
}

int? rangDesDerniersDAutrui(
  List<MessageEntity> messages,
  String moi,
  int combien,
) {
  if (combien <= 0) return null;
  var restant = combien;
  for (var i = messages.length - 1; i >= 0; i--) {
    final m = messages[i];
    if (m.type == MessageType.system) continue;
    if (m.senderId == moi) continue;
    restant--;
    if (restant == 0) return i;
  }
  // Moins de messages d'autrui que le compteur n'en annonçait : le fil n'est
  // pas encore complet. On ne pose rien plutôt que de se tromper de rang.
  return null;
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;

  // Use ValueNotifier for scroll button visibility to avoid full rebuilds
  final ValueNotifier<bool> _showScrollToBottomButton = ValueNotifier(false);

  // Reply state
  MessageEntity? _replyToMessage;

  /// Message en cours de modification, saisi dans la barre du bas.
  MessageEntity? _editingMessage;

  /// Une modification est déjà partie : ne pas la relancer sur un double tap.
  bool _modificationEnCours = false;

  // Animation for scroll button
  late AnimationController _scrollButtonController;
  late Animation<double> _scrollButtonAnimation;

  // Chat background
  ChatBackgroundEntity? _chatBackground;

  // For highlighting a message when scrolling to it
  String? _highlightedMessageId;

  /// Ouverture de l'écran, pour borner le recompte des non-lus.
  final DateTime _ouvertA = DateTime.now();

  /// Le compteur de non-lus **tel que la liste l'affichait**, relevé avant que
  /// quoi que ce soit ne marque lu.
  ///
  /// C'est la seule source qui survit à l'ouverture : `markAsRead` part dès
  /// `initState`, donc les messages chiffrés reviennent du serveur déjà lus
  /// et `compterNonLus` ne trouve plus rien. Voir [rangDesDerniersDAutrui].
  int _nonLusAvantOuverture = 0;

  /// Date du dernier message **tel que la liste l'annonçait**, relevée en
  /// même temps que [_nonLusAvantOuverture].
  ///
  /// Sert de garde au repli par rang : tant que le fil chargé s'arrête avant
  /// cette date, il est incomplet, et compter « les N derniers messages
  /// d'autrui » désignerait les mauvais. Vu à l'écran le 2026-09-16 : le
  /// séparateur « 2 messages non lus » posé devant deux messages du matin,
  /// parce que le cache s'arrêtait là et que les deux vrais non-lus
  /// n'étaient pas encore arrivés.
  DateTime? _dernierMessageAnnonce;

  /// Le fil chargé va-t-il jusqu'au dernier message que la liste annonçait ?
  ///
  /// `_loadCacheSync` affiche d'abord le cache local, qui ne contient pas les
  /// messages reçus entre deux visites. Compter les non-lus sur ce fil-là donne
  /// un compte trop bas, et surtout un **rang faux**.
  bool _filVaJusquAuBout(List<MessageEntity> messages) {
    final annonce = _dernierMessageAnnonce;
    if (annonce == null) return true; // rien à quoi comparer (lien profond)
    if (messages.isEmpty) return false;
    return !messages.last.createdAt.isBefore(annonce);
  }

  /// **Le curseur de lecture, relevé à l'ouverture.**
  ///
  /// Le séparateur « nouveaux messages » en est la représentation : le premier
  /// non-lu est le message qui suit le curseur. Ni un compte (il ne dit pas
  /// **où**), ni une date de visite locale (elle ne survit ni à la pagination
  /// ni au fuseau) — un message précis, désigné par le serveur.
  ///
  /// Figé à l'ouverture, et **volontairement pas rafraîchi** ensuite : un
  /// message qui arrive pendant qu'on lit ne doit pas déplacer le repère.
  DateTime? _curseurALOuverture;
  bool _curseurReleve = false;

  /// Le repère tel que **le serveur** le désigne : l'identifiant du premier
  /// non-lu, et combien il y en a.
  ///
  /// C'est ce qui rend le séparateur compatible avec la pagination (§ 11 du
  /// modèle). Le chercher dans les messages **chargés** désignerait le plus
  /// ancien de la page quand le vrai premier non-lu est encore plus haut.
  /// L'identifiant, lui, attend simplement que la remontée du fil l'amène à
  /// l'écran, et le séparateur apparaît alors tout seul.
  ({String id, int nombre})? _repereServeur;

  // ── Avancée du curseur ────────────────────────────────────────────────
  //
  // Un message n'est pas « lu » parce qu'il est arrivé, ni parce qu'on a
  // ouvert la discussion : il l'est quand il a été **montré assez
  // longtemps**. Avant, `markAsRead` partait dès `initState` et marquait la
  // conversation entière — y compris ce qui restait sous le pli. L'expéditeur
  // recevait « Lu » sur des messages que personne n'avait vus, et il ne restait
  // plus rien à séparer.

  /// Fraction de la bulle qui doit être à l'écran pour que le compte à rebours
  /// commence.
  static const _visibiliteMinimale = 0.6;

  /// Durée pendant laquelle elle doit le rester. Un défilement rapide qui
  /// traverse vingt messages n'en fait lire aucun.
  static const _dureeAvantVu = Duration(milliseconds: 400);

  /// Le serveur n'est prévenu qu'une fois le défilement posé.
  static const _delaiAvantEnvoi = Duration(milliseconds: 700);

  /// Comptes à rebours en cours, par identifiant de message.
  final Map<String, Timer> _attentesDeVisibilite = {};

  /// Le message le plus récent effectivement vu depuis l'ouverture.
  DateTime? _vuJusqua;

  /// Son identifiant : c'est lui que le serveur reçoit comme borne, pas la
  /// date — il relit lui-même `created_at`, sans question d'horloge ni de
  /// précision.
  String? _vuJusquaId;
  Timer? _envoiCurseur;

  void _signalerVisibilite(MessageEntity message, double fraction) {
    // Ni mes propres messages, ni les repères système : personne ne les
    // « lit », et rien ne viendra jamais les marquer.
    if (message.senderId == ref.read(currentUserProvider).valueOrNull?.id) {
      return;
    }
    if (message.type == MessageType.system) return;

    if (fraction < _visibiliteMinimale) {
      _attentesDeVisibilite.remove(message.id)?.cancel();
      return;
    }
    if (_attentesDeVisibilite.containsKey(message.id)) return;

    _attentesDeVisibilite[message.id] = Timer(_dureeAvantVu, () {
      _attentesDeVisibilite.remove(message.id);
      if (!mounted) return;
      // Les deux gardes sont évaluées **à l'échéance**, pas à la réception de
      // l'événement de visibilité.
      //
      // À la réception, `_estAffichee` est encore faux : `VisibilityDetector`
      // rapporte la bulle pendant la transition de route, quand l'emplacement
      // du routeur n'est pas encore `/messages/<id>`. Refuser là annulait le
      // compte à rebours — et comme la visibilité ne change plus ensuite,
      // **aucun autre événement ne venait** : le curseur n'avançait jamais.
      // Constaté le 2026-09-16 sur Pixel 10 Pro XL, deux messages à l'écran
      // pendant deux minutes et `read_at` toujours nul.

      if (!_isAppInForeground || !_estAffichee) return;
      final vu = _vuJusqua;
      if (vu != null && !message.createdAt.isAfter(vu)) return;
      _vuJusqua = message.createdAt;
      _vuJusquaId = message.id;
      _envoiCurseur?.cancel();
      _envoiCurseur = Timer(_delaiAvantEnvoi, _pousserCurseur);
    });
  }

  Future<void> _pousserCurseur() async {
    final jusqua = _vuJusqua;
    final jusquaId = _vuJusquaId;
    if (jusqua == null || jusquaId == null || !mounted) return;

    // **Relever, puis marquer.** Dans l'autre ordre, le repère se lirait sur un
    // état déjà « lu » et le séparateur n'aurait plus rien à désigner. Les
    // délais de visibilité (1,1 s) le garantissaient presque toujours, pas sur
    // un réseau lent.
    await _releve.future;
    if (!mounted) return;

    final conversationId = widget.conversationId;
    final passerelle = ref.read(mlsGatewayProvider);

    // Basculée ou non se décide sur `mls_since`, pas sur `enMls` : ce dernier
    // est vrai pour TOUTE conversation dès que le drapeau du compte est
    // ouvert, et une conversation encore en clair n'avait alors jamais ses
    // messages marqués — le curseur MLS n'y trouvait rien.
    var basculee = false;
    try {
      basculee = passerelle != null &&
          await passerelle.mlsSince(conversationId) != null;
      if (basculee) {
        await passerelle.avancerCurseur(conversationId, jusqua);
      }
    } catch (e) {
      debugPrint('ConversationScreen: curseur MLS non avancé ($e)');
    }

    // Les messages en clair, **toujours** — y compris dans une conversation
    // basculée, qui peut porter des messages d'avant la bascule jamais lus.
    // La borne peut être un message MLS : le serveur relit sa date.
    try {
      await ref.read(lectureServeurProvider).avancerJusqua(conversationId, jusquaId);
    } on LectureServeurAbsente {
      // Migration pas encore appliquée : l'ancien chemin, qui marque la
      // conversation entière. C'est ce qui se faisait jusqu'ici — rien ne
      // régresse, et le « jusqu'à » arrive avec la migration.
      if (basculee || !mounted) return;
      final moi = ref.read(currentUserProvider).valueOrNull;
      if (moi == null) return;
      // `markAsRead` rend un `Either` et ne lève pas : rien à rattraper ici.
      await ref
          .read(messageRepositoryProvider)
          .markAsRead(conversationId: conversationId, userId: moi.id);
    } catch (e) {
      // Un refus ou une panne ne se rattrapent PAS par l'ancien chemin : il
      // marquerait aussi ce qui n'a pas été vu. Le prochain lot vu repassera.
      debugPrint('ConversationScreen: curseur non avancé ($e)');
    }
  }

  /// Se termine quand [_releverCurseur] a rendu la main, qu'il ait abouti ou
  /// non. [_pousserCurseur] l'attend.
  final Completer<void> _releve = Completer<void>();

  /// Le serveur a répondu au relevé : son repère **fait foi**, y compris
  /// quand il dit « rien à lire ». Les chemins fondés sur les messages chargés
  /// ne servent plus alors — ils ignorent tout de ce que la page ne montre
  /// pas.
  bool _repereFaitFoi = false;

  Future<void> _releverCurseur() async {
    try {
      // Un seul point d'entrée, pour les deux magasins : `repere_de_lecture`
      // lit `messages` ET `mls_messages` dans le même instantané.
      final repere = await ref
          .read(lectureServeurProvider)
          .relever(widget.conversationId);
      _curseurALOuverture = repere.curseurA?.toLocal();
      if (repere.aUnSeparateur) {
        _repereServeur = (id: repere.premierNonLuId!, nombre: repere.nonLus);
      }
      _repereFaitFoi = true;
    } catch (e) {
      debugPrint('ConversationScreen: repère serveur indisponible ($e)');
      await _releverCurseurMls();
    } finally {
      _curseurReleve = true;
      if (!_releve.isCompleted) _releve.complete();
    }
    // La lecture est asynchrone : le comptage a pu passer avant elle.
    if (mounted) _calculateUnreadOnOpen();
  }

  /// Repli quand `repere_de_lecture` ne répond pas : l'ancien relevé, par la
  /// passerelle, qui ne voit que les messages MLS. Au-delà, ce sont les
  /// messages chargés qui décident (voir [_calculateUnreadOnOpen]).
  Future<void> _releverCurseurMls() async {
    try {
      final passerelle = ref.read(mlsGatewayProvider);
      if (passerelle != null) {
        final curseur = await passerelle.curseurDeLecture(widget.conversationId);
        _curseurALOuverture = curseur?.quand.toLocal();

        // Le repère, pris au même instant que le curseur : les deux doivent
        // décrire le même état, sans quoi un message arrivé entre les deux
        // lectures décalerait le compte.
        final premier = await passerelle.premierNonLu(
          widget.conversationId,
          apres: curseur?.quand,
        );
        if (premier != null) {
          final compteurs = await passerelle.nonLus();
          final nombre = compteurs[widget.conversationId]?.nonLus ?? 0;
          if (nombre > 0) {
            _repereServeur = (id: premier.id, nombre: nombre);
          }
        }
      }
    } catch (_) {
      // Curseur indisponible : on retombe sur l'état de lecture des messages
      // chargés.
    }
  }

  /// Au-delà, un message qui arrive est un message **reçu en direct** : il ne
  /// doit pas se ranger sous un séparateur « nouveaux messages » sous les yeux
  /// de quelqu'un qui regarde la discussion.
  static const _fenetreRecompteNonLus = Duration(seconds: 6);

  /// Le placement initial ne se fait qu'une fois, même si le comptage des
  /// non-lus, lui, repasse : sinon la vue sauterait à chaque émission.
  bool _aFaitLePlacementInitial = false;

  // Unread messages separator
  /// **L'identifiant** du premier message non lu, pas son rang.
  ///
  /// Un index est calculé sur le fil tel qu'il était à l'instant du comptage.
  /// Dès que la lecture réseau ou la pagination complète la liste, tous les
  /// index glissent et la condition d'affichage ne tombe plus jamais juste :
  /// le compte reste bon — le bouton de défilement l'affichait — mais le
  /// repère n'est plus placé nulle part. Vu à l'écran le 2026-09-16.
  ///
  /// Un identifiant, lui, désigne le même message quelle que soit la page
  /// chargée.
  String? _firstUnreadMessageId;
  int _unreadCountOnOpen = 0;
  bool _hasCalculatedUnread = false;
  bool _hasScrolledToInitialPosition = false;

  // Multi-selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // Search mode
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track app lifecycle state to prevent marking as read when in background
  bool _isAppInForeground = true;

  /// Cette discussion est-elle **réellement à l'écran** ?
  ///
  /// `_isAppInForeground` ne suffit pas, et la différence coûtait un accusé de
  /// lecture mensonger. `StatefulShellRoute` garde les branches **montées**
  /// quand on change d'onglet : une discussion ouverte puis quittée par
  /// l'onglet Accueil reste vivante, son `didChangeAppLifecycleState` et son
  /// `ref.listen` continuent de tourner, et marquaient lu tout ce qui
  /// arrivait — sans que personne ne regarde.
  ///
  /// Mesuré le 2026-09-15 sur Pixel 10 Pro XL : `read_at` posé **une seconde
  /// après** `delivered_at`, en lot, sur trois messages dont la discussion
  /// n'était pas affichée. Côté expéditeur, « Lu » sur des messages jamais
  /// lus ; côté destinataire, plus aucune pastille de non-lus, jamais.
  ///
  /// **Mesuré, pas supposé.** J'ai d'abord interrogé l'emplacement global du
  /// routeur (`currentConfiguration.uri`), en craignant que
  /// `ModalRoute.isCurrent` ne soit vrai jusque dans une branche d'onglet
  /// inactive. Sur appareil, ce garde rendait **toujours faux** alors que la
  /// discussion était bien à l'écran — le curseur de lecture n'avançait donc
  /// jamais, en silence. Tracé le 2026-09-16 sur Pixel 10 Pro XL :
  /// `fraction=1.0` à chaque bulle, puis `affichee=false` à chaque échéance.
  ///
  /// La crainte ne s'appliquait pas : l'écran de discussion est poussé
  /// **au-dessus** du shell — c'est pourquoi la barre d'onglets disparaît —
  /// et non dans une branche. `ModalRoute.isCurrent` dit donc exactement
  /// « cette route est au sommet », y compris quand une feuille ou un
  /// visionneur passe par-dessus.
  bool get _estAffichee {
    if (!mounted) return false;
    // Absent hors navigateur (un test qui monte l'écran seul) : on ne bloque
    // pas le comportement historique.
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  // --- Nature réelle de la conversation --------------------------------
  // `widget.isGroup` / `widget.groupId` viennent de `state.extra`, posé par la
  // tuile de la liste des messages. Ouverte par LIEN PROFOND ou par
  // NOTIFICATION, `state.extra` est nul : le drapeau retombait à false et
  // l'écran rendait un groupe comme un 1-à-1 (en-tête « Utilisateur » et
  // boutons d'appel 1-à-1, nom de l'expéditeur masqué, et surtout bandeau
  // épinglé interrogeant conversationPinnedItemsProvider alors que les
  // épingles d'un groupe sont indexées par group_id — donc bandeau vide en
  // permanence). Le repli sur `conversation?.groupId` existait déjà par
  // endroits, mais jamais pour le drapeau lui-même.
  // On réconcilie donc les deux avec la donnée dès que la conversation est
  // chargée. Le passage de false à true survient APRÈS initState : le travail
  // d'ouverture réservé aux groupes est rejoué à ce moment (_runGroupOpenWork).
  // `widget.isSelfNotes` vient du même `state.extra` (posé par la tuile
  // épinglée « Mes notes ») et souffre du même défaut : par lien profond, la
  // conversation avec soi-même se rendait comme un fil ordinaire — titre tiré
  // du profil au lieu de « Mes notes », et menu « + » sans le brouillon de
  // sondage. `ConversationEntity.isSelfNotesFor()` tranche à partir de la
  // donnée (participant unique = moi).
  // `widget.otherUserId` souffre du même mal : absent par lien profond, l'écran
  // ne pouvait pas charger le profil du correspondant et l'en-tête d'un DM
  // affichait « Utilisateur ». La conversation connaît pourtant l'autre
  // participant (`getOtherParticipantId`).
  bool _isGroupFromConversation = false;
  String? _groupIdFromConversation;
  bool _isSelfNotesFromConversation = false;
  String? _otherUserIdFromConversation;

  /// Profil de l'interlocuteur tel que l'appareil le connaissait à l'ouverture.
  ///
  /// Sert de valeur de départ à l'en-tête, le temps que le flux de profil rende
  /// la sienne. Voir [_semerIdentiteConnue].
  dynamic _profilConnuAuDemarrage;

  /// La conversation telle que le cache local la connaissait à l'ouverture.
  ///
  /// Même rôle pour un groupe : son nom et son image sont dans la conversation,
  /// pas dans un profil. Voir [_semerIdentiteConnue].
  ConversationEntity? _conversationConnueAuDemarrage;

  bool get _isGroup => widget.isGroup || _isGroupFromConversation;
  String? get _effectiveGroupId => widget.groupId ?? _groupIdFromConversation;
  bool get _isSelfNotes => widget.isSelfNotes || _isSelfNotesFromConversation;
  String? get _effectiveOtherUserId =>
      widget.otherUserId ?? _otherUserIdFromConversation;

  // Gardes d'idempotence : _runGroupOpenWork() est appelé à l'ouverture ET à
  // chaque réconciliation, chaque effet ne doit partir qu'une fois.
  bool _unreadMentionsCleared = false;
  bool _privateGroupFilterRequested = false;

  /// Pose, **dès la première image**, ce que l'appareil sait déjà de
  /// l'interlocuteur : son identifiant, puis son profil.
  ///
  /// Les trois sources sont locales et synchrones — l'uid Firebase (tenu en
  /// mémoire dès l'initialisation, sans réseau), la conversation en cache et le
  /// profil en cache. Les providers, eux, ne peuvent pas répondre à temps : un
  /// flux n'émet jamais dans la même image que le premier rendu. L'en-tête
  /// passait donc par « Chargement… » alors que le nom était déjà sur le
  /// disque — d'autant plus visible hors ligne, où la suite ne vient jamais.
  ///
  /// Ne sème rien pour un groupe ou « Mes notes » : ils n'ont pas
  /// d'interlocuteur. Et rien non plus si le compte courant est inconnu — sans
  /// lui, « l'autre participant » ne se calcule pas.
  void _semerIdentiteConnue() {
    final moi = FirebaseAuth.instance.currentUser?.uid;

    // 1. La conversation, telle que le cache local la connaît. Elle porte le
    //    nom et l'image d'un groupe, et la liste des participants d'un DM.
    final connues = ref
        .read(messageRepositoryProvider)
        .getCachedConversations()
        .fold((_) => const <ConversationEntity>[], (liste) => liste);
    for (final conversation in connues) {
      if (conversation.id == widget.conversationId) {
        _conversationConnueAuDemarrage = conversation;
        break;
      }
    }
    final connue = _conversationConnueAuDemarrage;

    // 1 bis. Le compteur de non-lus, pris sur la liste **vivante** et non sur
    //        le cache : pour une conversation chiffrée, le serveur n'écrit
    //        jamais `data.unreadCount`, et la copie en cache dirait zéro. La
    //        liste, elle, l'a reconstitué depuis `mls_unread_counts` — c'est
    //        ce nombre-là qu'affichait la pastille juste avant le tap.
    //
    //        Il faut le prendre **maintenant** : `markAsRead` part au premier
    //        rendu, et tout sera lu quelques millisecondes plus tard.
    if (moi != null) {
      final vivantes = ref.read(conversationsProvider).valueOrNull;
      for (final c in vivantes ?? const <ConversationEntity>[]) {
        if (c.id == widget.conversationId) {
          _nonLusAvantOuverture = c.getUnreadCountFor(moi);
          _dernierMessageAnnonce = c.lastMessageAt;
          break;
        }
      }
    }

    // 2. Sa nature. « Mes notes » se décide par différence avec le compte
    //    courant, comme l'interlocuteur : sans lui, on ne tranche pas.
    if (connue != null) {
      if (connue.isGroup) {
        _isGroupFromConversation = true;
        _groupIdFromConversation = connue.groupId;
      } else if (moi != null && connue.isSelfNotesFor(moi)) {
        _isSelfNotesFromConversation = true;
      }
    }

    // 3. L'interlocuteur d'un tête-à-tête, puis son profil.
    if (_isGroup || _isSelfNotes) return;

    var autreId = widget.otherUserId;
    if (autreId == null && connue != null && moi != null) {
      final autre = connue.getOtherParticipantId(moi);
      if (autre.isNotEmpty) {
        autreId = autre;
        _otherUserIdFromConversation = autre;
      }
    }
    if (autreId == null) return;

    _profilConnuAuDemarrage = ref
        .read(profileRepositoryProvider)
        .getCachedProfile(autreId)
        .fold((_) => null, (profil) => profil);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(_releverCurseur());
    _semerIdentiteConnue();

    _scrollController.addListener(_onScroll);

    _scrollButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollButtonAnimation = CurvedAnimation(
      parent: _scrollButtonController,
      curve: Curves.easeOut,
    );

    // Mark as read and load background after frame is built
    // Note: _calculateUnreadOnOpen() is called via ref.listen in build() when messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // « Livré » vaut dès l'ouverture : l'appareil a bien reçu les messages.
      // « Lu », non : c'est le curseur qui le dira, quand les bulles auront
      // été montrées assez longtemps (voir [_signalerVisibilite]). Marquer
      // tout ici, c'était promettre à l'expéditeur une lecture qui n'avait pas
      // eu lieu — et ne rien laisser à séparer.
      ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId);
      _loadChatBackground();
      // Ne fait rien si la nature du fil n'est pas encore connue (lien
      // profond / notification) : _syncGroupIdentity le rappellera dès que la
      // conversation aura révélé son group_id.
      _runGroupOpenWork();

      // Signal this conversation is open to prevent in-app notifications
      NotificationService().setCurrentConversation(widget.conversationId);
      ref
          .read(inAppNotificationProvider.notifier)
          .setCurrentConversation(widget.conversationId);
    });
  }

  /// Aligne l'état local sur la conversation réellement chargée.
  ///
  /// Appelé depuis build() : sans effet tant que rien ne change, et diffère le
  /// setState d'une frame quand il y a du nouveau (on est en plein build).
  void _syncConversationIdentity(
    ConversationEntity? conversation,
    String? currentUserId,
  ) {
    if (conversation == null) return;

    // `type == group` est la donnée d'autorité ; un group_id renseigné suffit
    // néanmoins à trancher (conversations créées avant que le type soit posé).
    final resolvedIsGroup =
        conversation.isGroup || conversation.groupId != null;
    final resolvedGroupId = conversation.groupId;
    // Sans utilisateur courant (auth pas encore chargée) on ne peut pas
    // trancher « Mes notes » : garder la valeur connue plutôt que de conclure
    // « non » à tort, ce qui ferait clignoter le titre de l'en-tête.
    //
    // `isSelfNotesFor()` exclut les groupes depuis le 2026-08-05 : sans ça, un
    // groupe dont je suis le seul membre satisfaisait « un seul participant,
    // et c'est moi » et s'affichait « Mes notes » à la place de son nom
    // (constaté sur appareil en ouvrant `0ce4c63f-…` par lien profond).
    final resolvedIsSelfNotes =
        currentUserId == null
            ? _isSelfNotesFromConversation
            : conversation.isSelfNotesFor(currentUserId);

    // L'autre participant d'un DM : sans lui, `userStreamProvider` n'était
    // jamais souscrit et l'en-tête affichait « Utilisateur » (vérifié sur
    // appareil). Ne vaut que pour un vrai 1-à-1 — un groupe ou « Mes notes »
    // n'a pas de « correspondant », et `getOtherParticipantId` rend '' quand
    // il n'y en a pas.
    String? resolvedOtherUserId = _otherUserIdFromConversation;
    if (currentUserId != null && !resolvedIsGroup && !resolvedIsSelfNotes) {
      final other = conversation.getOtherParticipantId(currentUserId);
      resolvedOtherUserId = other.isEmpty ? null : other;
    }

    if (resolvedIsGroup == _isGroupFromConversation &&
        resolvedGroupId == _groupIdFromConversation &&
        resolvedIsSelfNotes == _isSelfNotesFromConversation &&
        resolvedOtherUserId == _otherUserIdFromConversation) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isGroupFromConversation = resolvedIsGroup;
        _groupIdFromConversation = resolvedGroupId;
        _isSelfNotesFromConversation = resolvedIsSelfNotes;
        _otherUserIdFromConversation = resolvedOtherUserId;
      });
      // La conversation vient (peut-être) de se révéler être un groupe :
      // rejouer ce qu'initState avait sauté faute de le savoir.
      _runGroupOpenWork();
    });
  }

  /// Travail d'ouverture réservé aux groupes. Idempotent : appelé à
  /// l'ouverture puis à chaque réconciliation, chaque effet ne part qu'une fois.
  void _runGroupOpenWork() {
    if (!_isGroup) return;

    // Clear unread mention badge when opening a group conversation
    if (!_unreadMentionsCleared) {
      final userId = ref.read(currentUserProvider).valueOrNull?.id;
      if (userId != null) {
        _unreadMentionsCleared = true;
        ref
            .read(messageRepositoryProvider)
            .clearUnreadMentions(
              conversationId: widget.conversationId,
              userId: userId,
            );
      }
    }

    if (!_privateGroupFilterRequested && _effectiveGroupId != null) {
      _privateGroupFilterRequested = true;
      _setupPrivateGroupFilter();
    }
  }

  /// Configure le filtre de messages pour les groupes privés
  /// Les nouveaux membres ne voient pas les messages envoyés avant leur adhésion
  Future<void> _setupPrivateGroupFilter() async {
    if (!_isGroup || _effectiveGroupId == null) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    try {
      // Récupérer les informations du groupe via le repository
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupById(_effectiveGroupId!);

      final group = result.fold((failure) => null, (group) => group);
      if (group == null) return;

      // Vérifier si c'est un groupe privé
      if (!group.isPrivate) return;

      // Récupérer la date d'adhésion de l'utilisateur
      final joinedAt = group.memberJoinedAt[currentUser.id];

      if (joinedAt != null) {
        // Appliquer le filtre pour ne montrer que les messages après l'adhésion
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .setFilterDate(joinedAt);
      }
    } catch (e) {
      // En cas d'erreur, ne pas appliquer de filtre (fail-safe)
      // debugPrint('⚠️ Error setting up private group filter: $e');
    }
  }

  /// Calculate unread messages count and first unread index on conversation open
  void _calculateUnreadOnOpen() {
    if (_hasCalculatedUnread) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final paginationState = ref.read(
      paginatedMessagesProvider(widget.conversationId),
    );
    final messages = paginationState.messages;

    if (messages.isEmpty) return;

    // Rien ne se décide avant le relevé serveur : les messages chargés
    // ignorent tout de ce que la page ne montre pas. Le relevé rappellera.
    if (!_curseurReleve) return;

    // Le serveur a désigné le repère : on le prend tel quel, sans rien
    // déduire des messages chargés. C'est le seul chemin qui reste juste quand
    // le premier non-lu est encore hors de la page.
    final repere = _repereServeur;
    if (repere != null) {
      if (_firstUnreadMessageId != repere.id) {
        setState(() {
          _unreadCountOnOpen = repere.nombre;
          _firstUnreadMessageId = repere.id;
        });
      }
      final rang = messages.indexWhere((m) => m.id == repere.id);
      if (rang == -1 &&
          !_filVaJusquAuBout(messages) &&
          DateTime.now().difference(_ouvertA) < _fenetreRecompteNonLus) {
        // Le fil affiché vient du cache et s'arrête avant le repère : la
        // lecture réseau va l'amener. Se placer en bas maintenant, c'était
        // se placer en bas pour de bon — le placement ne se rejoue pas.
        return;
      }
      _hasCalculatedUnread = true;
      if (!_aFaitLePlacementInitial) {
        _aFaitLePlacementInitial = true;
        // Le message peut ne pas être chargé : on ne se place alors pas
        // dessus, mais le séparateur apparaîtra en remontant.
        _scrollToUnreadOrBottom(rang == -1 ? null : rang, messages.length);
      }
      return;
    }

    // Le serveur a répondu « rien à lire » : pas de séparateur, et aucun repli
    // sur les messages chargés ne doit en inventer un.
    if (_repereFaitFoi) {
      _hasCalculatedUnread = true;
      if (!_aFaitLePlacementInitial) {
        _aFaitLePlacementInitial = true;
        _scrollToUnreadOrBottom(null, messages.length);
      }
      return;
    }

    // ── Replis : `repere_de_lecture` n'a pas répondu ─────────────────────────
    // (réseau, ou migration pas encore appliquée). Tout ce qui suit se fonde
    // sur les messages chargés, faute de mieux.

    final compte = compterNonLus(messages, currentUser.id);
    final unreadCount = compte.nombre;
    final firstUnreadIndex = compte.premier;

    if (unreadCount > 0 && firstUnreadIndex != null) {
      setState(() {
        _unreadCountOnOpen = unreadCount;
        _firstUnreadMessageId = messages[firstUnreadIndex].id;
        _hasCalculatedUnread = true;
      });
      if (!_aFaitLePlacementInitial) {
        _aFaitLePlacementInitial = true;
        _scrollToUnreadOrBottom(firstUnreadIndex, messages.length);
      }
      return;
    }

    if (!_filVaJusquAuBout(messages)) {
      // Fil incomplet : ne rien poser. La fenêtre de recompte repassera dès
      // que la lecture réseau l'aura complété.
      if (!_aFaitLePlacementInitial) {
        _aFaitLePlacementInitial = true;
        _scrollToUnreadOrBottom(null, messages.length);
      }
      return;
    }
    final depuis = _curseurALOuverture;
    if (depuis != null) {
      final vus = compterDepuis(messages, currentUser.id, depuis);
      if (vus.nombre > 0 && vus.premier != null) {
        setState(() {
          _unreadCountOnOpen = vus.nombre;
          _firstUnreadMessageId = messages[vus.premier!].id;
          _hasCalculatedUnread = true;
        });
        if (!_aFaitLePlacementInitial) {
          _aFaitLePlacementInitial = true;
          _scrollToUnreadOrBottom(vus.premier, messages.length);
        }
        return;
      }
      // Rien après le curseur : pas de séparateur. Et surtout pas celui du
      // compteur de la liste, qui met quelques secondes à retomber à zéro et
      // faisait réapparaître « N non lus » sur des messages qu'on venait de
      // lire — signalé à l'usage, c'est ce qui a mené au curseur.
      if (DateTime.now().difference(_ouvertA) >= _fenetreRecompteNonLus) {
        _hasCalculatedUnread = true;
      }
      if (!_aFaitLePlacementInitial) {
        _aFaitLePlacementInitial = true;
        _scrollToUnreadOrBottom(null, messages.length);
      }
      return;
    }

    // Première ouverture sur cet appareil : aucune visite antérieure à quoi se
    // comparer. Le compteur de la liste est alors frais (rien ne l'a encore
    // fait retomber), on peut s'y fier.
    // Zéro trouvé dans les messages, mais le serveur en annonçait : ils sont
    // revenus **déjà marqués lus**, parce que `markAsRead` est parti au premier
    // rendu, avant même que le fil chiffré ne soit récupéré. On retombe alors
    // sur le compteur relevé à l'ouverture, et on place le séparateur par le
    // rang plutôt que par l'état de lecture.
    if (_nonLusAvantOuverture > 0) {
      final rang = rangDesDerniersDAutrui(
        messages,
        currentUser.id,
        _nonLusAvantOuverture,
      );
      if (rang != null) {
        setState(() {
          _unreadCountOnOpen = _nonLusAvantOuverture;
          _firstUnreadMessageId = messages[rang].id;
          _hasCalculatedUnread = true;
        });
        if (!_aFaitLePlacementInitial) {
          _aFaitLePlacementInitial = true;
          _scrollToUnreadOrBottom(rang, messages.length);
        }
        return;
      }
      // Le fil n'est pas encore complet (moins de messages d'autrui que le
      // compteur n'en annonce) : on laisse la fenêtre de recompte repasser.
    }

    // Zéro non-lu — mais sur quoi a-t-on compté ?
    //
    // `_loadCacheSync` affiche le cache local immédiatement et pose
    // `isLoadingInitial: false` ; c'est voulu, l'écran ne doit pas rester
    // vide. Seulement, les messages neufs ne sont PAS dans ce cache : sur une
    // conversation chiffrée ils n'ont jamais été déchiffrés, et ils
    // n'arrivent qu'après la lecture réseau. Le compte tombait donc sur zéro,
    // `_hasCalculatedUnread` se fermait pour de bon, et rien ne recomptait
    // quand ils arrivaient : **le séparateur ne s'affichait jamais**.
    //
    // On ne ferme donc le verrou qu'une fois la fenêtre d'ouverture passée.
    // Le placement, lui, a déjà eu lieu : il ne se rejoue pas.
    if (DateTime.now().difference(_ouvertA) >= _fenetreRecompteNonLus) {
      _hasCalculatedUnread = true;
    }
    if (!_aFaitLePlacementInitial) {
      _aFaitLePlacementInitial = true;
      _scrollToUnreadOrBottom(null, messages.length);
    }
  }

  /// Scroll vers le premier message non lu (si nécessaire)
  /// Avec reverse: true, la liste démarre déjà au bas (position 0 = messages récents)
  void _scrollToUnreadOrBottom(int? unreadIndex, int totalMessages) {
    if (_hasScrolledToInitialPosition) return;
    _hasScrolledToInitialPosition = true;

    // Avec reverse: true, la liste démarre au bas (position 0)
    // Donc pas besoin de scroll si pas de messages non lus
    if (unreadIndex == null) return;

    // Attendre que le ListView soit complètement rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      // Avec reverse: true, l'index dans la liste inversée est:
      // reversedIndex = totalMessages - 1 - unreadIndex
      // Position = (reversedIndex / totalMessages) * maxExtent
      final reversedIndex = totalMessages - 1 - unreadIndex;
      final ratio = reversedIndex / totalMessages;
      final targetPosition = (maxExtent * ratio).clamp(0.0, maxExtent);

      _scrollController.jumpTo(targetPosition);
    });
  }

  @override
  void dispose() {
    for (final attente in _attentesDeVisibilite.values) {
      attente.cancel();
    }
    _attentesDeVisibilite.clear();
    _envoiCurseur?.cancel();
    // Clear current conversation to re-enable in-app notifications
    NotificationService().setCurrentConversation(null);
    // Note: We don't clear the provider here because dispose() may be called
    // after the widget is unmounted, and ref may no longer be valid.
    // The provider will be cleared when navigating to a new conversation.

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollButtonController.dispose();
    _showScrollToBottomButton.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Track foreground state to prevent marking messages as read when in background
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      // « Livré » vaut dès que l'appareil a le message. « Lu » repart du
      // curseur : les bulles redeviennent visibles, leurs comptes à rebours
      // reprennent, et le curseur avance de lui-même.
      ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId);
      setState(() {
        // Force rebuild to update date labels like "Aujourd'hui", "Hier"
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
    }
  }

  void _onScroll() {
    // With reverse: true, maxScrollExtent is at the TOP (oldest messages)
    // and pixels = 0 is at the BOTTOM (newest messages)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Check if we're near the top (oldest messages) to load more
    if ((maxScroll - currentScroll) <= 100) {
      final paginationState = ref.read(
        paginatedMessagesProvider(widget.conversationId),
      );
      if (paginationState.canLoadMore) {
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .loadMore();
      }
    }

    // Track if we're near bottom (newest messages = near pixels 0)
    _isNearBottom = currentScroll <= 100;

    // Show/hide scroll to bottom button (show when scrolled up from bottom)
    final shouldShowButton = currentScroll > 300;
    if (shouldShowButton != _showScrollToBottomButton.value) {
      _showScrollToBottomButton.value = shouldShowButton;
      if (shouldShowButton) {
        _scrollButtonController.forward();
      } else {
        _scrollButtonController.reverse();
      }
    }
  }

  /// Scroll to a specific message by ID
  void _scrollToMessage(String messageId) {
    final paginationState = ref.read(
      paginatedMessagesProvider(widget.conversationId),
    );
    final messages = paginationState.messages;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && _scrollController.hasClients) {
      // With reverse: true, convert to reversed index
      final reversedIndex = messages.length - 1 - index;
      // Estimate position - each message is roughly 80 pixels
      final estimatedPosition = reversedIndex * 80.0;
      _scrollController.animateTo(
        estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Highlight the message temporarily
      setState(() {
        _highlightedMessageId = messageId;
      });

      // Remove highlight after animation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  void _scrollToBottom() {
    // With reverse: true, position 0 is at the bottom (newest messages)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  MessageEntity? _getReplyEntity(MessageEntity message) {
    // Check for null or empty replyToMessageData
    if (message.replyToMessageData == null ||
        message.replyToMessageData!.isEmpty) {
      return null;
    }
    final data = message.replyToMessageData!;

    // Validate required fields exist
    if (data['id'] == null || data['senderId'] == null) {
      // debugPrint(
      //   '⚠️ Invalid reply data: missing id or senderId. Data: $data',
      // );
      return null;
    }

    try {
      return MessageEntity(
        id: data['id'] as String? ?? '',
        senderId: data['senderId'] as String? ?? '',
        senderName:
            data['senderName'] as String? ?? AppLocalizations.of(context)!.user,
        content: data['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => MessageType.text,
        ),
        createdAt: DateTime.now(),
        readBy: const [],
        readAt: const {},
        fileUrl: data['fileUrl'] as String?,
        fileName: data['fileName'] as String?,
      );
    } catch (e) {
      // debugPrint('❌ Error parsing reply entity: $e');
      // debugPrint('   Data: $data');
      return null;
    }
  }

  void _handleReply(MessageEntity message) {
    setState(() {
      // Réponse et modification partagent le même champ : entrer dans l'une
      // sort de l'autre, sinon le bandeau annoncerait un geste et le bouton en
      // ferait un autre.
      _editingMessage = null;
      _replyToMessage = message;
    });
  }

  void _handleEdit(MessageEntity message) {
    setState(() {
      _replyToMessage = null;
      _editingMessage = message;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
    });
  }

  /// Applique le texte saisi au message en cours de modification.
  ///
  /// Le mode ne se referme que si l'écriture a eu lieu. Refusée, la
  /// modification reste ouverte avec le texte saisi : le fermer obligerait à
  /// tout retaper pour réessayer.
  Future<void> _submitEdit(String nouveauTexte) async {
    final message = _editingMessage;
    if (message == null || _modificationEnCours) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _modificationEnCours = true);
    final resultat = await ref
        .read(paginatedMessagesProvider(widget.conversationId).notifier)
        .editMessage(messageId: message.id, newContent: nouveauTexte);
    if (!mounted) return;
    setState(() => _modificationEnCours = false);

    // Chaque cause a sa phrase. Avant, tout échec — coupure réseau, refus
    // serveur, passerelle MLS — s'annonçait « délai de modification expiré ».
    final (texte, succes) = switch (resultat) {
      ModificationReussie() => (l10n.messageEdited, true),
      ModificationSansChangement() => (l10n.editUnchanged, true),
      ModificationRefusee(:final motif) => (
        phraseModificationImpossible(l10n, motif),
        false,
      ),
      ModificationEchouee(:final echec) => (echec.message, false),
    };

    if (succes) _cancelEdit();

    messenger.showSnackBar(
      SnackBar(
        content: Text(texte),
        backgroundColor: succes ? Colors.green : Colors.red,
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  // --- Multi-selection & Forward ---

  void _handleForward(MessageEntity message) {
    ForwardConversationPicker.show(context, messages: [message]);
  }

  // Fonctionnalité épingle mise en pause (2026-08-14) : `_pinMessage`,
  // `_unpinMessage` et `_refreshPinnedBanner` n'ont plus d'appelant (`canPin`
  // figé à `false` plus bas fait retomber `onPin`/`onUnpin` sur `null`).
  // Gardées en commentaire pour réactivation plutôt que supprimées — voir
  // aussi group_pinned_banner.dart et `_GroupInfoCard` dans
  // group_detail_screen.dart pour le reste de la pause.
  //
  // Future<void> _pinMessage(MessageEntity message) async {
  //   final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  //   if (currentUserId == null) return;
  //
  //   // Un message encore optimiste porte un id local `temp_…` (message_provider)
  //   // qui n'existera JAMAIS côté serveur : l'épingler enregistrait une entrée
  //   // définitivement irrésolvable — le bandeau la lisait « Élément
  //   // indisponible », ou masquait tout quand c'était la seule épingle. Deux
  //   // orphelines de ce type ont été trouvées en base (16 et 17/07/2026).
  //   if (message.id.startsWith('temp_')) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Attendez l\'envoi du message pour l\'épingler'),
  //         ),
  //       );
  //     }
  //     return;
  //   }
  //
  //   // L'épingle est TOUJOURS portée par la conversation, groupe compris.
  //   //
  //   // `group_pinned_items.group_id` a une clé étrangère vers `groups(id)`, or
  //   // les groupes de l'app vivent encore dans Firestore : leur identifiant
  //   // (ex. `yflqsRLMMhTPpiW0NFHx`) n'existe pas dans `public.groups`, donc
  //   // l'insertion violait la contrainte et l'utilisateur voyait « Impossible
  //   // d'épingler ce message » — reproduit sur appareil le 2026-08-05. La
  //   // colonne `conversation_id` pointe, elle, sur une table réellement peuplée
  //   // dans les deux cas.
  //   //
  //   // ⚠ Contrepartie : ce sont alors les policies RLS « Conversation
  //   // participants » qui s'appliquent. La permission de groupe « qui peut
  //   // épingler » n'est plus vérifiée par la base — seul `canPin`, côté écran,
  //   // filtre encore. À revoir quand les groupes seront dans Supabase.
  //   final success = await ref
  //       .read(groupPinActionsNotifierProvider.notifier)
  //       .pinItem(
  //         conversationId: widget.conversationId,
  //         itemType: GroupPinnedItemType.message,
  //         itemId: message.id,
  //         pinnedBy: currentUserId,
  //       );
  //
  //   // Rafraîchit le bandeau immédiatement : le stream Supabase ne reçoit pas
  //   // toujours l'insert en temps réel (réplication realtime pas garantie sur
  //   // `group_pinned_items`), donc sans ça le bandeau ne s'affichait qu'au
  //   // prochain ouverture de la conversation.
  //   if (success) _refreshPinnedBanner();
  //
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           success ? 'Message épinglé' : 'Impossible d\'épingler ce message',
  //         ),
  //       ),
  //     );
  //   }
  // }
  //
  // /// Force le re-fetch de la liste des épingles (auto-dispose StreamProvider),
  // /// pour un affichage immédiat après épinglage/désépinglage local.
  // void _refreshPinnedBanner() {
  //   ref.invalidate(conversationPinnedItemsProvider(widget.conversationId));
  // }
  //
  // /// Détache un message épinglé depuis son menu contextuel : le bandeau ne
  // /// porte plus de croix, c'est le seul chemin de désépinglage (comme Telegram).
  // Future<void> _unpinMessage(MessageEntity message) async {
  //   final items =
  //       ref
  //           .read(conversationPinnedItemsProvider(widget.conversationId))
  //           .valueOrNull;
  //   final pin =
  //       items
  //           ?.where(
  //             (i) =>
  //                 i.itemType == GroupPinnedItemType.message &&
  //                 i.itemId == message.id,
  //           )
  //           .firstOrNull;
  //   if (pin == null) {
  //     // La liste d'épingles locale (ref.read, snapshot synchrone) ne
  //     // contenait pas ce message : sans ce retour explicite, l'utilisateur
  //     // tapait « Détacher » et rien ne se passait, sans le moindre signal.
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(l10n.messageUnpinFailed)),
  //       );
  //     }
  //     return;
  //   }
  //
  //   final success = await ref
  //       .read(groupPinActionsNotifierProvider.notifier)
  //       .unpinItem(pin.id);
  //
  //   // Idem épinglage : rafraîchit le bandeau immédiatement (le retrait n'est
  //   // pas garanti en temps réel via le stream Supabase).
  //   if (success) _refreshPinnedBanner();
  //
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           success ? 'Message détaché' : l10n.messageUnpinFailed,
  //         ),
  //       ),
  //     );
  //   }
  // }

  void _handleSelect(MessageEntity message) {
    setState(() {
      if (!_isSelectionMode) {
        // Enter selection mode with this message
        _isSelectionMode = true;
        _selectedMessageIds.clear();
        _selectedMessageIds.add(message.id);
      } else if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  /// Handle call back from a call message bubble
  // Appels 1-à-1 mis en pause (fiabilité en cours de vérification sur
  // appareil réel — 2026-08-14) : plus aucun appelant, code conservé pour
  // réactivation. Voir TESTS_APPAREIL_A_FAIRE.md.
  // TODO(appels): réactiver après vérification à deux vrais téléphones.
  // Future<void> _handleCallBack(MessageEntity message) async {
  //   // Only allow call back in 1:1 conversations
  //   if (_isGroup || _effectiveOtherUserId == null) {
  //     return;
  //   }
  //
  //   // Determine call type from the message
  //   final callType =
  //       message.callType == 'video' ? CallType.video : CallType.audio;
  //
  //   // Initiate call
  //   final l10n = AppLocalizations.of(context)!;
  //   final call = await ref
  //       .read(currentCallProvider.notifier)
  //       .initiateCall(
  //         calleeId: _effectiveOtherUserId!,
  //         calleeName: widget.conversationName ?? l10n.user,
  //         calleePhotoUrl: widget.conversationImageUrl,
  //         type: callType,
  //       );
  //
  //   if (call != null && mounted) {
  //     // Navigate to call screen
  //     context.push('/calls/${call.id}');
  //   } else if (mounted) {
  //     final callState = ref.read(currentCallProvider);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(callState.error ?? l10n.callError),
  //         backgroundColor: AppColors.error,
  //       ),
  //     );
  //   }
  // }

  /// Démarre un appel de groupe (audio/vidéo) avec tous les membres.
  // Appels de groupe mis en pause le 2026-09-14 (voir les boutons de
  // l'AppBar) : plus aucun appelant, code conservé pour réactivation.
  // TODO(appels): réactiver après vérification à deux vrais téléphones.
  // Future<void> _startGroupCall({required bool isVideo}) async {
  //   final l10n = AppLocalizations.of(context)!;
  //   final gid = _effectiveGroupId;
  //   if (gid == null) return;
  //   final group = ref.read(groupStreamProvider(gid)).valueOrNull;
  //   if (group == null) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text(l10n.loadingError)));
  //     return;
  //   }
  //   final call = await ref
  //       .read(currentGroupCallProvider.notifier)
  //       .createGroupCall(
  //         name: group.name,
  //         participantIds: group.memberIds,
  //         type: isVideo ? GroupCallType.video : GroupCallType.audio,
  //       );
  //   if (call != null && mounted) {
  //     context.push('/group-calls/${call.id}');
  //   } else if (mounted) {
  //     final st = ref.read(currentGroupCallProvider);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(st.error ?? l10n.callError),
  //         backgroundColor: AppColors.error,
  //       ),
  //     );
  //   }
  // }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  List<MessageEntity> _getSelectedMessages(List<MessageEntity> allMessages) {
    return allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _copySelectedMessages(List<MessageEntity> allMessages) {
    final texte = selectionCopyText(_getSelectedMessages(allMessages));
    if (texte == null) return;
    Clipboard.setData(ClipboardData(text: texte));
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.copiedToClipboard),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _forwardSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final result = await ForwardConversationPicker.show(
      context,
      messages: selected,
    );

    if (result == true && mounted) {
      _exitSelectionMode();
    }
  }

  Future<void> _deleteSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.surfaceColor,
            title: Text(
              l10n.deleteSelectedMessages(selected.length),
              style: TextStyle(color: ctx.textPrimaryColor),
            ),
            content: Text(
              l10n.messagesDeletedForYou,
              style: TextStyle(color: ctx.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(color: ctx.textSecondaryColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: TextStyle(
                    color:
                        ctx.isDarkMode ? AppColors.errorDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      // Utiliser la suppression batch pour de meilleures performances
      final service = ref.read(messageDeletionServiceProvider);
      final result = await service.deleteMultipleForMe(
        conversationId: widget.conversationId,
        messageIds: selected.map((m) => m.id).toList(),
        userId: currentUserId,
      );

      result.fold(
        (failure) {
          // Afficher un message d'erreur user-friendly
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  FailureMapper.toUserFriendlyString(failure.message, context),
                ),
                backgroundColor:
                    context.isDarkMode ? AppColors.errorDark : AppColors.error,
              ),
            );
          }
        },
        (deletedCount) {
          // Mettre à jour l'UI localement pour chaque message supprimé
          final notifier = ref.read(
            paginatedMessagesProvider(widget.conversationId).notifier,
          );
          for (final message in selected) {
            notifier.markMessageDeletedForMe(message.id, currentUserId);
          }
          // Afficher confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.messagesDeletedSuccess(deletedCount)),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
        },
      );
      _exitSelectionMode();
    }
  }

  void _starSelectedMessages(List<MessageEntity> allMessages) {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final notifier = ref.read(
      paginatedMessagesProvider(widget.conversationId).notifier,
    );
    for (final message in selected) {
      notifier.toggleStar(message.id);
    }
    _exitSelectionMode();
  }

  Future<void> _loadChatBackground() async {
    try {
      final prefs = PreferencesService.instance;

      // Try to load conversation-specific background first
      final customBgJson = prefs.getConversationBackground(
        widget.conversationId,
      );

      if (customBgJson != null && customBgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(customBgJson));
        setState(() {
          _chatBackground = model.toEntity();
        });
        return;
      }

      // Fall back to default background
      final defaultBgJson = prefs.defaultChatBackground;
      if (defaultBgJson != null && defaultBgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(defaultBgJson));
        setState(() {
          _chatBackground = model.toEntity();
        });
      }
    } catch (e) {
      // debugPrint('Error loading chat background: $e');
    }
  }

  Future<void> _showBackgroundPicker() async {
    final result = await ChatBackgroundPickerModal.show(
      context,
      conversationId: widget.conversationId,
      currentBackground: _chatBackground,
    );

    if (result != null) {
      setState(() {
        _chatBackground = result;
      });
    }
  }

  Future<void> _handleReact(MessageEntity message, String emoji) async {
    // debugPrint('🎭 _handleReact called');
    try {
      await ref
          .read(paginatedMessagesProvider(widget.conversationId).notifier)
          .toggleReaction(message.id, emoji);
      // debugPrint('   ✅ Reaction toggled (optimistic)');
    } catch (e) {
      // debugPrint('  ❌ Error toggling reaction: $e');
    }
  }

  void _showConversationOptions() {
    final conversation =
        ref.read(conversationStreamProvider(widget.conversationId)).valueOrNull;
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    bool isAdmin =
        conversation != null &&
        currentUser != null &&
        (conversation.createdBy == currentUser.id ||
            conversation.adminIds.contains(currentUser.id));

    // Get fallback data from providers if widget params are null
    String? displayName = widget.conversationName;
    String? displayImage = widget.conversationImageUrl;
    bool canPostEvents = false;
    bool canPostPolls = false;

    if (_isGroup && _effectiveGroupId != null) {
      final groupData =
          ref.read(groupStreamProvider(_effectiveGroupId!)).valueOrNull;
      displayName ??= groupData?.name;
      displayImage ??= groupData?.imageUrl;
      // Le rôle admin/modérateur (group_members.role, source de vérité côté
      // RLS) prime sur conversation.adminIds : ce dernier n'est qu'un
      // instantané figé au moment de la création de la conversation, jamais
      // mis à jour lors d'une promotion/rétrogradation dans le groupe.
      isAdmin =
          currentUser != null &&
          groupData != null &&
          (groupData.creatorId == currentUser.id ||
              groupData.adminIds.contains(currentUser.id));
      canPostEvents =
          groupData?.permissions.canPostEvents(isAdmin: isAdmin) ?? false;
      canPostPolls =
          groupData?.permissions.canPostPolls(isAdmin: isAdmin) ?? false;
    } else if (!_isGroup && _effectiveOtherUserId != null) {
      final otherUser =
          ref.read(userStreamProvider(_effectiveOtherUserId!)).valueOrNull;
      displayName ??= otherUser?.displayName;
      displayImage ??= otherUser?.photoUrl;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => ConversationOptionsModal(
            conversationId: widget.conversationId,
            // Sans cette ligne, le paramètre restait à `null` pour toujours :
            // le menu annonçait « Désactivé » quelle que soit la vraie valeur,
            // et la feuille de réglage s'ouvrait sur « Désactivé » déjà coché.
            // Choisir « Désactivé » ne changeait alors rien à ses yeux, son
            // garde « rien n'a changé » sortait avant d'écrire, et le minuteur
            // ne pouvait plus JAMAIS être éteint — activer 24 h passait (null
            // ≠ 86400), éteindre était un geste sans effet ni message.
            // Mesuré sur SM A515F le 2026-09-15 : base à 86400, écran à
            // « Désactivé », messages horodatés à 24 h malgré tout.
            autoDeleteAfterSeconds: conversation?.autoDeleteAfterSeconds,
            otherUserId: _effectiveOtherUserId,
            otherUserName: displayName,
            otherUserPhotoUrl: displayImage,
            isGroup: _isGroup,
            isAdmin: isAdmin,
            groupId: _effectiveGroupId,
            canPostEvents: canPostEvents,
            canPostPolls: canPostPolls,
            onChangeBackground: _showBackgroundPicker,
            onSearch: () {
              setState(() {
                _isSearchMode = true;
              });
            },
          ),
    );
  }

  // Get date separator label
  String _getDateLabel(DateTime date, AppLocalizations l10n) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return l10n.today('');
    } else if (messageDate == yesterday) {
      return l10n.yesterday('');
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.EEEE(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    } else {
      return DateFormat.yMMMd(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    }
  }

  // Check if we need a date separator for reversed list
  // In reversed list, index 0 = newest, higher index = older
  // Date separator should appear ABOVE (after in reversed index) the first message of a new date
  bool _needsDateSeparatorReversed(List<MessageEntity> messages, int index) {
    // Last item (oldest message) always needs separator
    if (index == messages.length - 1) {
      return true;
    }

    final currentMessage = messages[index];
    final olderMessage = messages[index + 1]; // Next index = older message

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );
    final olderDate = DateTime(
      olderMessage.createdAt.year,
      olderMessage.createdAt.month,
      olderMessage.createdAt.day,
    );

    return currentDate != olderDate;
  }

  // Get message group position for reversed list
  MessageGroupPosition _getMessageGroupPositionReversed(
    List<MessageEntity> messages,
    int index,
    String? currentUserId, {
    required bool hasDateBreak,
    required bool hasNextDateBreak,
  }) => positionDansRafale(
    messages,
    index,
    hasDateBreak: hasDateBreak,
    hasNextDateBreak: hasNextDateBreak,
  );

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final paginationState = ref.watch(
      paginatedMessagesProvider(widget.conversationId),
    );
    final sendMessageState = ref.watch(sendMessageProvider);

    // Watch conversation stream to detect changes/deletion
    final conversationAsync = ref.watch(
      conversationStreamProvider(widget.conversationId),
    );
    // Même raison que pour le profil : le flux n'émet pas dans la première
    // image. Sans ce repli, l'en-tête d'un groupe affichait « Groupe » et le
    // fil personnel un nom d'utilisateur, le temps d'un aller-retour.
    final conversation =
        conversationAsync.valueOrNull ?? _conversationConnueAuDemarrage;

    // Réconcilie isGroup/groupId/isSelfNotes avec la donnée : indispensable
    // quand l'écran est atteint sans `state.extra` (lien profond, notification).
    _syncConversationIdentity(conversation, currentUser?.id);

    // Watch blocked users
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final blockedUsers = blockedUsersAsync.valueOrNull ?? [];

    final l10n = AppLocalizations.of(context)!;

    // La conversation est réputée absente **seulement** si le flux a livré une
    // valeur nulle. `!isLoading && conversation == null` était aussi vrai en
    // cas d'**erreur** de lecture (permission, réseau) : une panne passagère
    // s'affichait « Ce groupe a été supprimé », le composeur disparaissait, et
    // rien ne permettait de réessayer.
    final isDeleted = conversationAsync.hasValue && conversation == null;
    // Une panne de lecture ne compte que si l'écran n'a rien d'autre à
    // montrer : une conversation déjà connue reste affichée (`AsyncError`
    // garde la dernière valeur). Et elle ne remplace plus le composeur — hors
    // ligne on doit pouvoir écrire, le message part en file d'attente.
    final hasLoadError = conversationAsync.hasError && conversation == null;

    // Check if this is a pending request from current user (hide read/delivered status)
    final isPendingRequestFromMe =
        conversation != null &&
        conversation.requestStatus == ConversationRequestStatus.pending &&
        conversation.requesterId == currentUser?.id;

    // Check if other user is blocked (I blocked them)
    bool isBlocked = false;
    if (!_isGroup && conversation != null) {
      final otherUserId = conversation.getOtherParticipantId(
        currentUser?.id ?? '',
      );
      isBlocked = blockedUsers.any((user) => user.id == otherUserId);
    }

    // Check if I am blocked by the other user.
    //
    // Le sens etait bon ici, contrairement aux neuf autres sites :
    // `monProfil.blockedByUserIds.contains(autre)` demande bien « l'autre
    // m'a-t-il bloque ». Mais ce champ vaut toujours `[]` depuis que les
    // profils viennent de Supabase, ou `_mapProfile` le code en dur. La
    // reponse etait donc toujours non, et le composeur restait actif : on
    // pouvait ecrire a quelqu'un qui nous avait bloque.
    //
    // `_isGroup` / `_effectiveOtherUserId` et non `widget.*` : par lien profond
    // ou par notification, `state.extra` est nul, donc `widget.otherUserId`
    // aussi — le test serait toujours faux et le blocage a nouveau ignore.
    final quiMOntBloque =
        ref.watch(usersWhoBlockedMeProvider).valueOrNull ?? const <String>{};
    final isBlockedByOther =
        !_isGroup &&
        _effectiveOtherUserId != null &&
        quiMOntBloque.contains(_effectiveOtherUserId);

    // Stream other user's profile if it's an individual chat
    AsyncValue<dynamic>? otherUserAsync;
    if (!_isGroup && _effectiveOtherUserId != null) {
      otherUserAsync = ref.watch(userStreamProvider(_effectiveOtherUserId!));
    }

    // Le profil semé à l'ouverture tient lieu de valeur tant que le flux n'a
    // rien rendu : un flux n'émet jamais dans la même image que le premier
    // rendu, si bien que l'en-tête passait par « Chargement… » même avec le
    // nom déjà sur le disque. Voir [_semerIdentiteConnue].
    final otherUser = otherUserAsync?.valueOrNull ?? _profilConnuAuDemarrage;

    // Vrai tant qu'on n'a pas encore de quoi nommer l'interlocuteur : par
    // lien profond/notification, `widget.conversationName` est nul, et il
    // faut DEUX allers-retours successifs (conversation, puis profil de
    // l'autre participant une fois son id connu) avant d'avoir un vrai nom.
    // Sans ce garde, l'en-tête affichait « Utilisateur » (repli final de
    // `displayName`) pendant cette fenêtre, avant de corriger tout seul —
    // lu par Salim comme un défaut, pas comme un chargement.
    //
    // `otherUser == null` en tête : dès qu'on tient un profil — y compris le
    // dernier connu, servi depuis le cache disque — il n'y a plus rien à
    // attendre, et c'est son nom qu'il faut afficher. Sans cette clause, une
    // discussion ouverte hors ligne restait sur « Conversation » alors que le
    // nom était là : le flux de la conversation, lui, n'avait pas de valeur,
    // et ce seul fait suffisait à déclarer l'identité « en chargement ».
    //
    // `currentUser == null` compte aussi : l'interlocuteur se déduit de la
    // conversation **par différence** avec le compte courant, donc tant que la
    // session n'est pas restaurée il n'y a personne à nommer. Hors ligne, cette
    // fenêtre dure plusieurs dizaines de secondes, et sans cette clause
    // l'en-tête affichait « Utilisateur » pendant tout ce temps — le repli
    // final, celui qui se lit comme un défaut — avant de se corriger tout seul.
    // Mesuré par lien profond, mode avion, le 2026-09-14.
    final identityLoading =
        !_isGroup &&
        !_isSelfNotes &&
        otherUser == null &&
        (!conversationAsync.hasValue ||
            currentUser == null ||
            (_effectiveOtherUserId != null &&
                !(otherUserAsync?.hasValue ?? false)));

    // Stream group data if it's a group chat and we have groupId
    // This ensures we can display group name/image even when navigating from notifications
    dynamic groupData;
    if (_isGroup && _effectiveGroupId != null) {
      final groupAsync = ref.watch(groupStreamProvider(_effectiveGroupId!));
      groupData = groupAsync.valueOrNull;
    }

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    // Membres proposés derrière un `@` dans un groupe. Porte aussi la poignée
    // publique, qui sert de pseudo de mention quand elle existe.
    //
    // Clé : l'identifiant du groupe. Passer la liste des membres créait une
    // nouvelle instance de provider à chaque build — voir le commentaire de
    // `groupMentionCandidatesProvider`.
    final List<MentionCandidate> mentionCandidates =
        _isGroup && _effectiveGroupId != null
            ? ref.watch(groupMentionCandidatesProvider(_effectiveGroupId!))
            : const [];

    // Création événement/sondage depuis le menu « + » du composer.
    // DM : événement toujours possible ; groupe : selon les permissions.
    // Sondage : groupes uniquement (PollContextType ne couvre pas les DM).
    final isConvAdmin =
        _isGroup
            ? (currentUserId != null &&
                groupData != null &&
                (groupData.creatorId == currentUserId ||
                    (groupData.adminIds as List<String>).contains(
                      currentUserId,
                    )))
            : (conversation != null &&
                currentUser != null &&
                (conversation.createdBy == currentUser.id ||
                    conversation.adminIds.contains(currentUser.id)));
    final canCreateEvent =
        _isSelfNotes
            ? false
            : _isGroup
            ? (_effectiveGroupId != null &&
                ((groupData?.permissions.canPostEvents(isAdmin: isConvAdmin)
                        as bool?) ??
                    false))
            : true;
    // Sondage : dans « Mes notes », un brouillon (note structurée) ; dans une
    // discussion privée, un vrai sondage entre ses participants (ouvert le
    // 2026-09-12) ; dans un groupe, selon ses permissions.
    final canCreatePoll =
        _isSelfNotes ||
        !_isGroup ||
        (_isGroup &&
            _effectiveGroupId != null &&
            ((groupData?.permissions.canPostPolls(isAdmin: isConvAdmin)
                    as bool?) ??
                false));

    // Determine display name for typing indicator
    // For groups: use passed name, fallback to loaded group data, then default
    // For individual: use loaded user profile, fallback to passed name, then default
    // Même repli que l'en-tête : `conversation.name` avant `groupData`, ce
    // dernier venant de Firestore et restant null pour un groupe Supabase.
    final displayName =
        _isGroup
            ? (widget.conversationName ??
                conversation?.name ??
                groupData?.name ??
                l10n.group)
            : (otherUser?.displayName ?? widget.conversationName ?? l10n.user);

    // Maintient vivant le notifier de frappe tant que l'écran l'est.
    //
    // Il n'était jamais observé : chaque frappe faisait un `ref.read` sur un
    // provider autoDispose sans auditeur, que Riverpod détruisait dans la
    // foulée — sa destruction effaçant aussitôt la présence qu'il venait de
    // poser. L'autre appareil ne voyait donc jamais « écrit… ». Cette ligne
    // fixe son cycle de vie sur celui de la discussion : vivant tant qu'on y
    // est, détruit (donc présence effacée) quand on en sort.
    ref.watch(typingIndicatorNotifierProvider);

    // Typing users for the in-list bubble
    final typingStatusValue = ref.watch(
      typingStatusProvider(widget.conversationId),
    );
    final typingUserIds =
        typingStatusValue
            .whenData(
              (map) =>
                  map.entries
                      .where((e) => e.key != currentUser?.id && e.value)
                      .map((e) => e.key)
                      .toList(),
            )
            .valueOrNull ??
        <String>[];
    final Map<String, String>? typingNames =
        _isGroup
            ? {for (final c in mentionCandidates) c.id: c.displayName}
            : (_effectiveOtherUserId != null
                ? {_effectiveOtherUserId!: displayName}
                : null);

    // Auto-scroll to bottom when new messages arrive & calculate unread on first load
    ref.listen(paginatedMessagesProvider(widget.conversationId), (
      previous,
      next,
    ) {
      // Calculate unread count and scroll to initial position when messages are first loaded
      if (!_hasCalculatedUnread &&
          next.messages.isNotEmpty &&
          !next.isLoadingInitial) {
        _calculateUnreadOnOpen();
      }

      // Un message qui arrive est **livré**, pas lu. S'il tombe sous les yeux,
      // son propre compte à rebours de visibilité fera avancer le curseur ;
      // s'il arrive sous le pli, il reste non lu — et le séparateur garde son
      // sens. Voir [_signalerVisibilite].
      if (previous != null &&
          next.messages.length > previous.messages.length &&
          _isAppInForeground &&
          _estAffichee) {
        final currentUserId = currentUser?.id;
        if (currentUserId != null) {
          final newMessagesFromOthers = next.messages
              .where((m) => !previous.messages.any((pm) => pm.id == m.id))
              .any((m) => m.senderId != currentUserId);

          if (newMessagesFromOthers) {
            ref
                .read(markAsDeliveredProvider.notifier)
                .mark(widget.conversationId);
          }
        }
      }

      if (previous != null &&
          next.messages.length > previous.messages.length &&
          _isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    // Affecté à une variable (au lieu d'un `return` direct) pour l'envelopper
    // dans le PopScope ci-dessous sans réindenter tout le corps de l'écran.
    final scaffold = Scaffold(
      backgroundColor:
          _chatBackground?.isDefault ?? true ? context.backgroundColor : null,
      extendBodyBehindAppBar:
          _chatBackground != null && !_chatBackground!.isDefault,
      appBar:
          _isSelectionMode
              ? _buildSelectionAppBar(paginationState.messages)
              : _isSearchMode
              ? _buildSearchAppBar()
              : _buildAppBar(
                otherUser,
                groupData,
                conversation,
                isDeleted,
                identityLoading,
              ),
      body: Container(
        decoration:
            _chatBackground != null && !_chatBackground!.isDefault
                ? BoxDecoration(
                  color:
                      _chatBackground!.isColor ? _chatBackground!.color : null,
                  image:
                      _chatBackground!.isImage &&
                              _chatBackground!.imageUrl != null
                          ? DecorationImage(
                            image: NetworkImage(_chatBackground!.imageUrl!),
                            fit: BoxFit.cover,
                          )
                          : _chatBackground!.isImage &&
                              _chatBackground!.localImagePath != null
                          ? DecorationImage(
                            image: FileImage(
                              File(_chatBackground!.localImagePath!),
                            ),
                            fit: BoxFit.cover,
                          )
                          : null,
                )
                : null,
        child: Stack(
          children: [
            // Fond d'écran nommé (§21c) rendu procéduralement, sous l'overlay.
            if (_chatBackground != null &&
                _chatBackground!.isPattern &&
                ChatWallpaper.byId(_chatBackground!.patternId) != null)
              ChatWallpaper.byId(
                _chatBackground!.patternId,
              )!.fill(context.isDarkMode),
            // Semi-transparent overlay for readability
            if (_chatBackground != null && !_chatBackground!.isDefault)
              Container(
                color:
                    context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.3),
              ),
            // Hauteur reellement disponible sous l'en-tete. `MediaQuery
            // .viewInsets` vaut deja 0 dans un `body` de Scaffold : il ne dirait
            // rien du clavier. `LayoutBuilder` est la seule mesure fiable, et il
            // couvre aussi le panneau ancre, qui n'est pas un inset systeme.
            //
            // En paysage, clavier ou panneau ouvert, il ne reste qu'une centaine
            // de dp — le bandeau epingle peut a lui seul depasser cette hauteur :
            // l'`Expanded` tombe a zero et la colonne deborde quand meme. Mesure
            // sur SM A515F : 17 px avec le clavier, 4 px avec le panneau emojis,
            // plus court. La mesure sert aussi a borner `MessageInput`, plus bas.
            //
            // Les enfants gardent volontairement leur indentation d'origine :
            // les reindenter aurait reecrit des centaines de lignes en cours de
            // modification par ailleurs, et rendu la fusion ingerable. A passer
            // au formateur quand le fichier sera libre.
            LayoutBuilder(
              builder: (context, zoneCorps) {
                return Column(
              children: [
                // Offline indicator
                if (paginationState.isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 14,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.offlineMode,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptivePrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Message request banner (pending request)
                if (conversation != null &&
                    conversation.isPendingRequest &&
                    currentUser != null)
                  _buildMessageRequestBanner(
                    l10n,
                    conversation,
                    currentUser.id,
                  ),
                // Bandeau des éléments épinglés (event/poll/message), façon
                // Telegram : ligne fine fixée sous l'en-tête, toujours visible.
                // Le widget porte sa propre marge : il ne laisse aucun espace
                // quand rien n'est épinglé.
                // Toujours indexé par la conversation, groupe compris : voir
                // `_pinMessage`. Ça supprime au passage la dépendance à
                // `widget.isGroup` et à `groupId`, tous deux absents quand
                // l'écran est atteint par notification ou par lien profond —
                // le bandeau restait alors invisible en permanence.
                // Corollaire utile : ce bandeau est inconditionnel, donc il ne
                // fait pas varier le nombre d'enfants de la Column quand
                // `_isGroup` passe de false à true en cours de vie (un tel
                // changement démonterait les éléments suivants, dont le
                // TextField du composer — deux taps pour lever le clavier).
                // La bascule ÉCO vivait à droite de cette ligne (fiche 6b), au
                // lieu d'occuper une sous-barre à elle. Le raccourci Médias a
                // rejoint le menu ⋮.
                // Bouton ÉCO désactivé temporairement (cf. settings_screen.dart,
                // fix(reglages) desactive temporairement le mode donnees reduites).
                GroupPinnedBanner(
                  conversationId: widget.conversationId,
                  messageConversationId: widget.conversationId,
                  onOpenMessage: _scrollToMessage,
                  // trailing: _ecoChip(context, conversation),
                ),
                // Messages
                Expanded(
                  child: _buildMessageList(
                    paginationState,
                    currentUser?.id,
                    l10n,
                    blockedUsers.map((u) => u.id).toSet(),
                    isPendingRequestFromMe,
                    (!isDeleted && !isBlocked) ? typingUserIds : const [],
                    typingNames,
                  ),
                ),

                // Panne de lecture et rien de connu sur la discussion : on le
                // dit, au-dessus du composeur et sans le remplacer. Le texte
                // disparaît de lui-même dès que la lecture repasse.
                if (hasLoadError)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: context.surfaceColor,
                    width: double.infinity,
                    child: Text(
                      l10n.loadingError,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            context.isDarkMode
                                ? AppColors.errorDark
                                : AppColors.error,
                      ),
                    ),
                  ),

                // Input or Blocked/Deleted Message
                if (isDeleted ||
                    (otherUser != null &&
                        otherUser.displayName == DeletedAccount.storedName))
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: context.surfaceColor,
                    width: double.infinity,
                    child: Text(
                      // « Ce groupe a été supprimé » s'affichait aussi sur un
                      // tête-à-tête et sur « Mes notes », qui n'en sont pas.
                      isDeleted
                          ? (widget.isGroup
                              ? l10n.thisGroupWasDeleted
                              : l10n.conversationDeleted)
                          : l10n.thisUserWasDeleted,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            context.isDarkMode
                                ? AppColors.errorDark
                                : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (isBlocked)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: context.surfaceColor,
                    width: double.infinity,
                    child: Text(
                      l10n.youBlockedThisUser,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            context.isDarkMode
                                ? AppColors.errorDark
                                : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  // Borne explicitement MessageInput a la hauteur mesuree par
                  // le LayoutBuilder englobant (`zoneCorps`) : sans ca,
                  // `RenderFlex` lui donne toujours `maxHeight: Infinity`
                  // (enfant non-flexible de cette Column), et son propre
                  // garde-fou interne (`_buildColumn`/`panneau` dans
                  // message_input.dart) ne s'active jamais -- cause du
                  // `BOTTOM OVERFLOWED` en paysage quand banniere(s) + brouillon
                  // depassent la hauteur restante. Voir TESTS_APPAREIL_A_FAIRE.md,
                  // section "Paysage -- overflow quand le chrome depasse la
                  // hauteur".
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: zoneCorps.maxHeight,
                    ),
                    child: MessageInput(
                    conversationId: widget.conversationId,
                    isLoading: sendMessageState.isLoading,
                    replyToMessage: _replyToMessage,
                    onCancelReply: _cancelReply,
                    editingMessage: _editingMessage,
                    onCancelEdit: _cancelEdit,
                    onSubmitEdit: _submitEdit,
                    mentionCandidates: mentionCandidates,
                    onCreateEvent:
                        canCreateEvent
                            ? () => context.push(
                              _isGroup
                                  ? '/groups/$_effectiveGroupId/events/create'
                                  : '/conversations/${widget.conversationId}/events/create',
                            )
                            : null,
                    onCreatePoll:
                        !canCreatePoll
                            ? null
                            : _isSelfNotes
                            ? () => _createPollDraft()
                            : _isGroup
                            ? () => _createAndPublishPoll(
                              PollContextType.group,
                              _effectiveGroupId!,
                            )
                            : () => _createAndPublishPoll(
                              PollContextType.conversation,
                              widget.conversationId,
                            ),
                    onTyping: () {
                      ref
                          .read(typingIndicatorNotifierProvider.notifier)
                          .onUserTyping(widget.conversationId);
                    },
                    onSendText: (text, mentions) async {
                      // Stop typing indicator when sending
                      ref
                          .read(typingIndicatorNotifierProvider.notifier)
                          .stopTyping();

                      // Clear reply
                      final replyTo = _replyToMessage;
                      _cancelReply();

                      // Generate unique message ID for tracking
                      final messageId =
                          'temp_${DateTime.now().millisecondsSinceEpoch}';

                      // Send with retry logic
                      // If blocked by other user, include their ID in sentWhileBlockedBy
                      final blockedByList =
                          isBlockedByOther && _effectiveOtherUserId != null
                              ? [_effectiveOtherUserId!]
                              : <String>[];

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendText(
                            conversationId: widget.conversationId,
                            content: text,
                            optimisticMessageId: messageId,
                            replyToMessage: replyTo,
                            sentWhileBlockedBy: blockedByList,
                            mentionedUsers: mentions,
                          );

                      if (!mounted) return;

                      if (!success) {
                        ref
                            .read(
                              paginatedMessagesProvider(
                                widget.conversationId,
                              ).notifier,
                            )
                            .updateMessageStatus(
                              messageId,
                              MessageStatus.failed,
                            );
                      }

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'text',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                            'is_reply': replyTo != null ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendFile: (
                      File file,
                      MessageType type, {
                      String? caption,
                    }) async {
                      // If blocked, don't send file (file messages don't support sentWhileBlockedBy yet)
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendFile(
                            conversationId: widget.conversationId,
                            file: file,
                            type: type,
                            caption: caption,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': type.name,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendAudioFile: (File file, {String? caption}) async {
                      // If blocked, don't send audio file.
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendFile(
                            conversationId: widget.conversationId,
                            file: file,
                            type: MessageType.audio,
                            caption: caption,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'audio',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendAudio: (
                      File audioFile,
                      int duration,
                      List<double> waveform,
                    ) async {
                      // If blocked, don't send audio (audio messages don't support sentWhileBlockedBy yet)
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendAudio(
                            conversationId: widget.conversationId,
                            audioFile: audioFile,
                            duration: duration,
                            waveform: waveform,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'audio',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                            'duration': duration,
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendLocation: (
                      double latitude,
                      double longitude,
                      String address,
                    ) async {
                      // If blocked, don't send location
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendLocation(
                            conversationId: widget.conversationId,
                            latitude: latitude,
                            longitude: longitude,
                            address: address,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'location',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendSticker: (StickerEntity sticker) async {
                      // If blocked, don't send sticker
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendSticker(
                            conversationId: widget.conversationId,
                            stickerPackId: sticker.packId,
                            stickerId: sticker.id,
                            stickerUrl: sticker.url,
                            isAnimated: sticker.isAnimated,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'sticker',
                            'sticker_pack': sticker.packId,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendGif: (GifEntity gif) async {
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      // Un GIF distant est un média flottant identifié par une
                      // URL : il réutilise le transport « sticker », en portant
                      // le fournisseur (tenor/giphy) comme identifiant de pack.
                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendSticker(
                            conversationId: widget.conversationId,
                            stickerPackId: gif.packId,
                            stickerId: gif.id,
                            stickerUrl: gif.url,
                            isAnimated: true,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'gif',
                            'gif_provider': gif.provider.name,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                  ),
                  ),
              ],
                );
              },
            ),

            // Search results overlay
            if (_isSearchMode && _searchQuery.length >= 2)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSearchResults(),
              ),

            // Scroll to bottom FAB with unread badge
            ValueListenableBuilder<bool>(
              valueListenable: _showScrollToBottomButton,
              builder: (context, showButton, child) {
                if (!showButton) return const SizedBox.shrink();
                return Positioned(
                  bottom: 100,
                  right: 16,
                  child: ScaleTransition(
                    scale: _scrollButtonAnimation,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: context.surfaceColor,
                          elevation: 4,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        // Unread count badge
                        if (_unreadCountOnOpen > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.adaptivePrimaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadCountOnOpen > 99
                                    ? '99+'
                                    : _unreadCountOnOpen.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    // Geste/bouton retour du système. Ouverte par lien profond ou par
    // notification, cette route est SEULE dans la pile : le pop la retirait
    // sans rien laisser derrière — écran noir. On refuse alors le pop et on
    // redirige, comme le fait la flèche de l'en-tête (_leaveConversation).
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) context.go(_fallbackRoute);
      },
      child: scaffold,
    );
  }

  /// Destination de repli quand il n'y a rien à dépiler.
  static const String _fallbackRoute = '/messages';

  /// Quitte la conversation. `context.pop()` seul produisait un écran noir
  /// lorsque l'écran avait été ouvert par lien profond ou par notification :
  /// sa route est alors seule dans la pile et le pop ne laisse rien derrière.
  void _leaveConversation() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_fallbackRoute);
    }
  }

  Widget _buildMessageList(
    dynamic paginationState,
    String? currentUserId,
    AppLocalizations l10n,
    Set<String> blockedUserIds,
    bool isPendingRequestFromMe,
    List<String> typingUserIds,
    Map<String, String>? typingNames,
  ) {
    if (paginationState.isLoadingInitial) {
      // Le fil rendait ici un `SizedBox.shrink()` : entre l'ouverture de la
      // discussion et la première page, l'espace entre l'en-tête et le
      // composeur était complètement vide — rien ne distinguait « ça
      // charge » de « cette discussion n'a aucun message ».
      return ConversationThreadSkeleton(isGroup: _isGroup);
    }

    if (paginationState.error != null && paginationState.messages.isEmpty) {
      // Convertir l'erreur technique en message user-friendly
      final userFriendlyError = FailureMapper.toUserFriendlyString(
        paginationState.error!,
        context,
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcon.error, size: 48, color: context.textTertiaryColor),
            const SizedBox(height: 16),
            Text(
              userFriendlyError,
              style: TextStyle(color: context.textSecondaryColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref
                    .read(
                      paginatedMessagesProvider(widget.conversationId).notifier,
                    )
                    .refresh();
              },
              icon: const AppIcon(AppIcon.refresh, color: AppColors.white),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (paginationState.messages.isEmpty) {
      return _buildEmptyState();
    }

    final allMessages = paginationState.messages as List<MessageEntity>;
    // Masquer ce que J'AI supprimé pour moi seul — pas ce qui est supprimé
    // pour tout le monde.
    //
    // Le filtre appelait `isDeletedFor`, qui vaut
    // `deletedForEveryone || deletedFor.contains(moi)`. Tout message supprimé
    // pour tous était donc retiré de la liste AVANT d'atteindre la bulle, et
    // le rendu de pierre tombale de `message_bubble.dart` (icône + « Message
    // supprimé » / « supprimé automatiquement ») était du code que rien ne
    // pouvait atteindre. Le message ne laissait aucune trace : il
    // disparaissait, ce qui fait soupçonner un bug plutôt qu'une suppression.
    //
    // Ça valait pour « supprimer pour tout le monde » comme pour un message
    // ÉPHÉMÈRE arrivé à échéance — `videeParExpiration` pose précisément
    // `deletedForEveryone`. Mesuré sur SM A515F le 2026-09-15 : entité bien
    // présente dans le fil avec les bons drapeaux (vérifié en pur sur
    // l'aller-retour complet du cache), et rien à l'écran.
    //
    // La bulle sait déjà se taire pour l'autre cas : `message_bubble.dart`
    // rend un `SizedBox.shrink()` quand le message est supprimé pour moi
    // seul. Les deux règles ne se marchent plus dessus.
    final messages =
        currentUserId != null
            ? allMessages
                .where(
                  (m) =>
                      !m.deletedFor.contains(currentUserId) &&
                      !blockedUserIds.contains(m.senderId) &&
                      !m.sentWhileBlockedBy.contains(currentUserId),
                )
                .toList()
            : allMessages
                .where((m) => !blockedUserIds.contains(m.senderId))
                .toList();

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    final uploadState = ref.watch(mediaUploadProvider);
    final isUploadingHere =
        uploadState.isUploading &&
        uploadState.conversationId == widget.conversationId;
    final typingCount = typingUserIds.isNotEmpty ? 1 : 0;
    final totalCount =
        messages.length +
        (paginationState.isLoadingMore ? 1 : 0) +
        (isUploadingHere ? 1 : 0) +
        typingCount;

    // Calculate top padding - add extra when body extends behind app bar
    final topPadding =
        (_chatBackground != null && !_chatBackground!.isDefault)
            ? MediaQuery.of(context).padding.top + kToolbarHeight + 16
            : 16.0;

    // Reverse messages so newest is at index 0 (for reverse: true ListView)
    final reversedMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: EdgeInsets.only(top: 16, bottom: topPadding),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Typing bubble at index 0 (bottom of reversed list = nearest to input)
        if (typingUserIds.isNotEmpty && index == 0) {
          return TypingBubble(
            typingUserIds: typingUserIds,
            userNames: typingNames,
          );
        }

        // Show uploading skeleton just above the typing bubble
        if (isUploadingHere && index == typingCount) {
          return const UploadingMediaSkeleton();
        }

        // Show loading indicator at the top when loading more (last index in reversed list)
        if (paginationState.isLoadingMore && index == totalCount - 1) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
          );
        }

        // Calculate message index in reversed list (accounting for typing + upload offsets)
        final messageIndex = index - typingCount - (isUploadingHere ? 1 : 0);

        // Safety check
        if (messageIndex < 0 || messageIndex >= reversedMessages.length) {
          return const SizedBox.shrink();
        }

        final message = reversedMessages[messageIndex];
        final isMe = message.senderId == currentUserId;

        // For reversed list, date separators appear AFTER the message (visually above)
        // Check if the NEXT message (older, higher index) has a different date
        final needsSeparator = _needsDateSeparatorReversed(
          reversedMessages,
          messageIndex,
        );
        final hasNextDateBreak =
            messageIndex > 0
                ? _needsDateSeparatorReversed(
                  reversedMessages,
                  messageIndex - 1,
                )
                : false;

        // Get group position for linked bubbles (pass pre-computed values)
        final groupPosition = _getMessageGroupPositionReversed(
          reversedMessages,
          messageIndex,
          currentUserId,
          hasDateBreak: needsSeparator,
          hasNextDateBreak: hasNextDateBreak,
        );

        // Only show sender info for the first message in a group (first or single)
        // In reversed list, "first" visually means the bottom-most of a group
        final showSenderInfo =
            _isGroup &&
            !isMe &&
            (groupPosition == MessageGroupPosition.first ||
                groupPosition == MessageGroupPosition.single);

        final conversation =
            ref
                .watch(conversationStreamProvider(widget.conversationId))
                .valueOrNull;
        // widget.groupId peut être absent (notification/deep link sans extra
        // complet) alors que la conversation connaît son group_id : ce repli
        // sert encore au contrôle des rôles (canPin ci-dessous). Les épingles,
        // elles, ne dépendent plus du groupe — elles sont indexées par
        // conversation, voir `_pinMessage`.
        final effectiveGroupId = _effectiveGroupId;
        // Le rôle admin/modérateur (group_members.role) est la source de
        // vérité côté RLS ; conversation.adminIds n'est qu'un instantané figé
        // à la création de la conversation (jamais mis à jour lors d'une
        // promotion), d'où un décrochage sinon entre ce que montre l'UI et ce
        // que les RLS Supabase autorisent réellement pour épingler/détacher.
        final groupForAdminCheck =
            effectiveGroupId != null
                ? ref.watch(groupStreamProvider(effectiveGroupId)).valueOrNull
                : null;
        final isAdmin =
            _isGroup
                ? (currentUserId != null &&
                    groupForAdminCheck != null &&
                    (groupForAdminCheck.creatorId == currentUserId ||
                        groupForAdminCheck.adminIds.contains(currentUserId)))
                : (conversation != null &&
                    currentUserId != null &&
                    (conversation.createdBy == currentUserId ||
                        conversation.adminIds.contains(currentUserId)));

        // L'expéditeur de CE message est-il admin/créateur du groupe ?
        // (Badge « Admin » à côté de son nom.)
        final senderIsAdmin =
            _isGroup &&
            !isMe &&
            groupForAdminCheck != null &&
            (groupForAdminCheck.creatorId == message.senderId ||
                groupForAdminCheck.adminIds.contains(message.senderId));

        // Fonctionnalité épingle mise en pause (2026-08-14) : `canPin` forcé
        // à `false` désactive d'un coup le bouton Épingler/Détacher du menu
        // contextuel (`message_bubble.dart` le gate déjà sur `widget.canPin`)
        // — `onPin`/`onUnpin` ci-dessous retombent sur `null` via
        // `canPin ? ... : null`, rien d'autre à toucher. Voir aussi
        // group_pinned_banner.dart et `_GroupInfoCard` dans
        // group_detail_screen.dart pour le reste de la pause.
        // En 1-a-1, les deux participants peuvent epingler ; en groupe, selon
        // les permissions du groupe.
        // final canPin =
        //     !_isGroup
        //         ? true
        //         : (groupForAdminCheck?.permissions.canPin(isAdmin: isAdmin) ??
        //             false);
        const canPin = false;

        // Fonctionnalité épingle mise en pause (2026-08-14) : plus besoin de
        // s'abonner à `conversationPinnedItemsProvider` ici tant que le
        // menu Épingler/Détacher est désactivé (`canPin` ci-dessus) —
        // `MessageBubble.isPinned` retombe sur son défaut `false`.
        // Ids des messages déjà épinglés : le menu contextuel bascule alors
        // « Épingler » en « Détacher » (le bandeau n'a plus de croix).
        // final pinnedMessageIds =
        //     (ref
        //                 .watch(
        //                   conversationPinnedItemsProvider(
        //                     widget.conversationId,
        //                   ),
        //                 )
        //                 .valueOrNull ??
        //             const [])
        //         .where((i) => i.itemType == GroupPinnedItemType.message)
        //         .map((i) => i.itemId)
        //         .toSet();

        // Le repère se reconnaît à l'identifiant du message, pas à son rang :
        // voir [_firstUnreadMessageId]. Il survit donc à la pagination et à
        // l'arrivée des messages manquants.
        final showUnreadSeparator =
            _firstUnreadMessageId != null &&
            message.id == _firstUnreadMessageId &&
            _unreadCountOnOpen > 0;

        // With reverse: true, separators go BEFORE the message in the Column
        // so they appear visually ABOVE (Column still renders top-to-bottom within each item)
        final ligne = Column(
          children: [
            // Date separator (appears ABOVE message visually)
            if (needsSeparator) _buildDateSeparator(message.createdAt, l10n),

            // Unread messages separator (appears ABOVE message visually)
            if (showUnreadSeparator) _buildUnreadSeparator(_unreadCountOnOpen),

            // Message bubble with highlight animation
            // RepaintBoundary isolates repaints for better performance
            RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color:
                      _highlightedMessageId == message.id
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            isMe: isMe,
                            showSenderInfo: showSenderInfo,
                            senderIsAdmin: senderIsAdmin,
                            groupPosition: groupPosition,
                            conversationId: widget.conversationId,
                            currentUserId: currentUserId,
                            isAdmin: isAdmin,
                            canPin: canPin,
                            // isPinned: pinnedMessageIds.contains(message.id),
                            // `canPin` est figé à `false` tant que la pause
                            // dure (voir plus haut) : `analyze` prouve alors
                            // que la branche `_pinMessage`/`_unpinMessage`
                            // est morte et la signale — mis directement à
                            // `null` pour rester propre sans perdre `_pinMessage`
                            // /`_unpinMessage`, réactivées avec `canPin`.
                            onPin: null,
                            onUnpin: null,
                            onReply: _handleReply,
                            onReact: _handleReact,
                            onForward: _handleForward,
                            onToggleStar: (msg) {
                              ref
                                  .read(
                                    paginatedMessagesProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .toggleStar(msg.id);
                            },
                            onEdit: _handleEdit,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedMessageIds.contains(
                              message.id,
                            ),
                            onSelect: _handleSelect,
                            // Rappel en un geste mis en pause avec les
                            // boutons d'appel ci-dessus (même correctif).
                            // TODO(appels): réactiver après vérification à
                            // deux vrais téléphones.
                            onCallBack: null,
                            skipAnimation: true,
                            isPendingRequest: isPendingRequestFromMe,
                            onRetry:
                                message.status == MessageStatus.failed
                                    ? () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final l10nMsg =
                                          AppLocalizations.of(context)!;
                                      final success = await ref
                                          .read(sendMessageProvider.notifier)
                                          .retryFailedMessage(
                                            conversationId:
                                                widget.conversationId,
                                            failedMessage: message,
                                          );
                                      if (!success && mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10nMsg.messageResendFailed,
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                    : null,
                            onSenderTap: (userId) {
                              if (_isGroup) {
                                context.push('/profile/$userId');
                              }
                            },
                            replyToMessage: _getReplyEntity(message),
                            onScrollToMessage: _scrollToMessage,
                            groupId:
                                _isGroup
                                    ? (_effectiveGroupId ??
                                        widget.conversationId)
                                    : null,
                          ),
                ),
              ),
            ),
          ],
        );

        // Le détecteur enveloppe la ligne entière : c'est lui qui fait avancer
        // le curseur de lecture. Un message n'est pas lu parce qu'il est
        // arrivé, ni parce qu'on a ouvert la discussion — il l'est quand il a
        // été montré assez longtemps. Voir [_signalerVisibilite].
        return VisibilityDetector(
          key: ValueKey('vu-${message.id}'),
          onVisibilityChanged:
              (info) => _signalerVisibilite(message, info.visibleFraction),
          child: ligne,
        );
      },
    );
  }

  /// Séparateur de jour : filet plein et pastille plate.
  ///
  /// Les dégradés en fondu, la bordure et l'ombre portée ont sauté : le fil de
  /// discussion est posé sur le fond crème, un repère de date n'a pas à se
  /// détacher du fond comme un élément cliquable.
  Widget _buildDateSeparator(DateTime date, AppLocalizations l10n) {
    return _buildThreadSeparator(
      label: _getDateLabel(date, l10n),
      background: context.surfaceVariantColor,
      foreground: context.textSecondaryColor,
      rule: context.dividerColor,
    );
  }

  /// Gabarit commun aux repères posés dans le fil (date, non-lus) : un filet
  /// de part et d'autre, une pastille au centre.
  Widget _buildThreadSeparator({
    required String label,
    required Color background,
    required Color foreground,
    required Color rule,
  }) {
    final trait = Expanded(child: Container(height: 1, color: rule));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          trait,
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(kDesignPillRadius),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
                letterSpacing: 0.3,
              ),
            ),
          ),
          trait,
        ],
      ),
    );
  }

  Widget _buildUnreadSeparator(int unreadCount) {
    final label =
        unreadCount == 1 ? '1 message non lu' : '$unreadCount messages non lus';

    // Même gabarit que le séparateur de date, mais en terracotta plein : c'est
    // le seul repère du fil qui doit accrocher l'œil.
    return _buildThreadSeparator(
      label: label,
      background: context.adaptivePrimaryColor,
      foreground: context.onPrimaryColor,
      rule: context.adaptivePrimaryColor.withValues(alpha: 0.35),
    );
  }

  /// Start a call with the other user
  // Appels 1-à-1 mis en pause avec _handleCallBack ci-dessus (même
  // correctif) : plus aucun appelant, code conservé pour réactivation.
  // TODO(appels): réactiver après vérification à deux vrais téléphones.
  // Future<void> _startCall({required bool isVideo}) async {
  //   if (_effectiveOtherUserId == null) return;
  //
  //   final l10n = AppLocalizations.of(context)!;
  //
  //   // Get other user info from watched data
  //   final otherUserAsync = ref.read(userStreamProvider(_effectiveOtherUserId!));
  //   final otherUser = otherUserAsync.valueOrNull;
  //
  //   final calleeName =
  //       otherUser?.displayName ?? widget.conversationName ?? l10n.user;
  //   final calleePhotoUrl = otherUser?.photoUrl ?? widget.conversationImageUrl;
  //
  //   // Vérifier si le destinataire peut recevoir des notifications (en ligne OU a un token FCM)
  //   final isCalleeOnline = otherUser?.canReceiveNotifications ?? false;
  //
  //   // Create the call in Firestore via CurrentCall provider
  //   final call = await ref
  //       .read(currentCallProvider.notifier)
  //       .initiateCall(
  //         calleeId: _effectiveOtherUserId!,
  //         calleeName: calleeName,
  //         calleePhotoUrl: calleePhotoUrl,
  //         type: isVideo ? CallType.video : CallType.audio,
  //       );
  //
  //   if (call == null) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(l10n.unableToStartCall),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //     return;
  //   }
  //
  //   // Navigate to call screen with the real call ID from Firestore
  //   if (mounted) {
  //     Navigator.of(context).push(
  //       MaterialPageRoute(
  //         builder:
  //             (context) => CallScreen(
  //               callId: call.id,
  //               isInitiator: true,
  //               isVideo: isVideo,
  //               calleeName: calleeName,
  //               calleePhotoUrl: calleePhotoUrl,
  //               isCalleeOnline: isCalleeOnline,
  //             ),
  //       ),
  //     );
  //   }
  //
  //   // Log analytics
  //   AnalyticsService.instance.logEvent(
  //     name: 'start_call',
  //     parameters: {
  //       'call_type': isVideo ? 'video' : 'audio',
  //       'callee_id': _effectiveOtherUserId!,
  //     },
  //   );
  // }

  /// Obtenir les initiales du nom
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  PreferredSizeWidget _buildSelectionAppBar(List<MessageEntity> allMessages) {
    return AppBar(
      backgroundColor: context.adaptivePrimaryColor,
      elevation: 0,
      leading: IconButton(
        onPressed: _exitSelectionMode,
        icon: const AppIcon(AppIcon.close, color: AppColors.white),
      ),
      title: Text(
        '${_selectedMessageIds.length} sélectionné${_selectedMessageIds.length > 1 ? 's' : ''}',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Select all
        IconButton(
          onPressed: () {
            setState(() {
              if (_selectedMessageIds.length == allMessages.length) {
                _selectedMessageIds.clear();
              } else {
                _selectedMessageIds
                  ..clear()
                  ..addAll(allMessages.map((m) => m.id));
              }
            });
          },
          icon: Icon(
            _selectedMessageIds.length == allMessages.length
                ? Icons.deselect
                : Icons.select_all,
            color: AppColors.white,
          ),
          tooltip:
              _selectedMessageIds.length == allMessages.length
                  ? AppLocalizations.of(context)!.deselectAll
                  : AppLocalizations.of(context)!.selectAll,
        ),
        // Copier la sélection (textes, légendes, positions, sondages).
        if (selectionCopyText(_getSelectedMessages(allMessages)) != null)
          IconButton(
            onPressed: () => _copySelectedMessages(allMessages),
            icon: const Icon(Icons.copy, color: AppColors.white),
            tooltip: AppLocalizations.of(context)!.copy,
          ),
        // Star selected
        IconButton(
          onPressed: () => _starSelectedMessages(allMessages),
          icon: const AppIcon(AppIcon.starBorder, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.favorites,
        ),
        // Forward selected
        IconButton(
          onPressed: () => _forwardSelectedMessages(allMessages),
          icon: const Icon(Icons.shortcut, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.forward,
        ),
        // Delete selected
        IconButton(
          onPressed: () => _deleteSelectedMessages(allMessages),
          icon: const AppIcon(AppIcon.delete, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.delete,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          setState(() {
            _isSearchMode = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
        icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: context.textPrimaryColor, fontSize: 16),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchMessages,
          hintStyle: TextStyle(color: context.textTertiaryColor, fontSize: 16),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
            icon: AppIcon(AppIcon.close, color: context.textTertiaryColor),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, _) {
        final resultsAsync = ref.watch(
          messageSearchProvider((
            conversationId: widget.conversationId,
            query: _searchQuery,
          )),
        );

        return GestureDetector(
          onTap: () {
            // Dismiss search on tap outside
            setState(() {
              _isSearchMode = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
          child: Container(
            color: context.surfaceColor.withValues(alpha: 0.95),
            child: resultsAsync.when(
              loading:
                  () => Center(
                    child: CircularProgressIndicator(
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
              error:
                  (_, __) => Center(
                    child: Text(
                      AppLocalizations.of(context)!.searchError,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcon.searchOff,
                          size: 48,
                          color: context.textTertiaryColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.noSearchResults,
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: context.dividerColor,
                      ),
                  itemBuilder: (context, index) {
                    final message = results[index];
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _isSearchMode = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _scrollToMessage(message.id);
                      },
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: context.adaptivePrimaryColor
                            .withValues(alpha: 0.15),
                        child: Text(
                          message.senderName.isNotEmpty
                              ? message.senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      subtitle: _buildHighlightedText(
                        context,
                        message.content,
                        _searchQuery,
                      ),
                      trailing: Text(
                        DateFormat.Hm().format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    // Show context around the match
    final start = (matchIndex - 20).clamp(0, text.length);
    final end = (matchIndex + query.length + 40).clamp(0, text.length);
    final snippet = text.substring(start, end);
    final snippetMatchStart = matchIndex - start;

    return Text.rich(
      TextSpan(
        children: [
          if (start > 0) const TextSpan(text: '...'),
          TextSpan(
            text: snippet.substring(0, snippetMatchStart),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          TextSpan(
            text: snippet.substring(
              snippetMatchStart,
              snippetMatchStart + query.length,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.adaptivePrimaryColor,
            ),
          ),
          TextSpan(
            text: snippet.substring(snippetMatchStart + query.length),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          if (end < text.length) const TextSpan(text: '...'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Cree le sondage puis le publie comme bulle de la conversation.
  ///
  /// Sans cette seconde etape, la ligne de `post_polls` n'etait lue par aucun
  /// ecran : le sondage existait en base et restait invisible partout.
  Future<void> _createAndPublishPoll(
    PollContextType contextType,
    String contextId,
  ) async {
    final poll = await showCreatePollSheet(
      context,
      contextType: contextType,
      contextId: contextId,
    );
    if (poll == null || !mounted) return;
    await _publishPollBubble(poll.id, poll.question);
  }

  /// Publie (ou republie) la bulle d'un sondage deja cree.
  ///
  /// « Reessayez » renvoyait vers la feuille de creation, qui aurait cree un
  /// SECOND sondage en laissant le premier invisible — une ligne de
  /// `post_polls` qu'aucun ecran ne lit. L'action rejoue donc l'envoi de la
  /// bulle, avec le meme identifiant.
  Future<void> _publishPollBubble(String pollId, String question) async {
    final published = await ref
        .read(sendMessageProvider.notifier)
        .sendPoll(
          conversationId: widget.conversationId,
          pollId: pollId,
          question: question,
        );

    if (!mounted || published) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.pollBubbleFailed),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () => _publishPollBubble(pollId, question),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  /// Compose un brouillon de sondage dans « Mes notes » et l'envoie comme note
  /// texte structurée (question + options). Pas de vote — c'est un aide-mémoire
  /// à recopier/publier ailleurs.
  Future<void> _createPollDraft() async {
    final draft = await showNotePollDraftSheet(context);
    if (draft == null || draft.isEmpty || !mounted) return;

    final success = await ref
        .read(sendMessageProvider.notifier)
        .sendText(conversationId: widget.conversationId, content: draft);
    if (mounted && success) _scrollToBottom();
  }

  // Sous-barre sous l'en-tête : tuiles « Médias » (galerie partagée) et
  // « ÉCO » (mode données réduites, lié à `PreferencesService.dataSaverMode`).
  // Ces deux lignes ouvraient le bloc de documentation du bandeau de clés, qui
  // n'existe plus ; elles décrivent en fait la sous-barre ci-dessous.
  // Bascule « données réduites », posée à droite de la ligne épinglée
  // (fiche 6b). Escamotée pour « Mes notes » et pour une demande de message
  // en attente, où elle n'aurait rien à réduire.
  // Désactivée temporairement (cf. settings_screen.dart) : le service et les
  // points de lecture ailleurs dans l'app restent intacts pour une
  // réactivation ultérieure.
  // Widget? _ecoChip(BuildContext context, dynamic conversation) {
  //   if (_isSelfNotes) return null;
  //   if (conversation?.isPendingRequest ?? false) return null;
  //
  //   final eco = PreferencesService.instance.dataSaverMode;
  //   // #F5F0E8 clair / #252119 sombre : c'est `surfaceVariant` en clair mais
  //   // `surfaceElevated` en nocturne — la pastille se pose sur le fond de la
  //   // conversation, pas sur une carte, et `surfaceVariantDark` (#2D2820) la
  //   // ferait ressortir davantage que la fiche ne le demande.
  //   final tileBg =
  //       context.isDarkMode
  //           ? AppColors.surfaceElevatedDark
  //           : AppColors.surfaceVariant;
  //   final repere = context.repereColor;
  //
  //   return _SubBarTile(
  //     bg: eco ? repere.withValues(alpha: 0.15) : tileBg,
  //     icon: Icon(
  //       Icons.data_saver_on,
  //       size: 15,
  //       color: eco ? repere : context.textSecondaryColor,
  //     ),
  //     label: l10n.messageEcoBadge,
  //     labelColor: eco ? repere : context.textSecondaryColor,
  //     onTap: () async {
  //       await PreferencesService.instance.setDataSaverMode(!eco);
  //       if (mounted) setState(() {});
  //     },
  //   );
  // }

  PreferredSizeWidget _buildAppBar(
    dynamic otherUser,
    dynamic groupData,
    ConversationEntity? conversation,
    bool isDeleted,
    bool identityLoading,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // For groups: use passed name, fallback to loaded group data, then default
    // For individual: use loaded user profile, fallback to passed name, then default
    //
    // `conversation?.name` s'intercale avant `groupData` : la conversation
    // porte déjà le nom du groupe (colonne `data->>'name'`), alors que
    // `groupData` vient de `groupStreamProvider`, encore câblé sur FIRESTORE
    // (`GroupRemoteDataSourceImpl`) — il rend donc null pour tout groupe créé
    // dans Supabase, et l'en-tête retombait sur « Groupe » quand aucun
    // `state.extra` n'était fourni (lien profond, notification). Vérifié sur
    // appareil le 2026-08-05 : « Diaspora Niger — Canada » s'affichait
    // « Groupe », alors que la liste des messages — qui lit `conversation.name`
    // — montrait le bon nom.
    //
    // `isDeleted` prime sur tout le reste : une conversation dont le flux a
    // livré `null` (supprimée, ou notification pointant vers un id détruit
    // par la purge du 2026-08-14 — voir
    // project_messages_conversations_purge_2026_08_14) n'a plus de nom à
    // dériver nulle part. Sans ce garde, l'en-tête retombait sur le
    // générique « Utilisateur », qui se lisait comme un blocage plutôt que
    // comme une conversation supprimée.
    //
    // `identityLoading` prime sur le repli `l10n.user` : ce dernier ne doit
    // dire « Utilisateur » qu'une fois l'attente terminée et le profil
    // effectivement introuvable, jamais pendant les deux allers-retours
    // encore en vol (conversation, puis profil de l'autre participant).
    final displayName =
        isDeleted
            ? (_isGroup ? l10n.thisGroupWasDeleted : l10n.conversationDeleted)
            : identityLoading
            ? (widget.conversationName ?? l10n.loading)
            : _isSelfNotes
            ? l10n.messagesMyNotes
            : _isGroup
            ? (widget.conversationName ??
                conversation?.name ??
                groupData?.name ??
                l10n.group)
            : (otherUser?.displayName ?? widget.conversationName ?? l10n.user);

    final displayImage =
        _isSelfNotes
            ? null
            : _isGroup
            ? (widget.conversationImageUrl ??
                conversation?.imageUrl ??
                groupData?.imageUrl)
            : (otherUser?.photoUrl ?? widget.conversationImageUrl);

    final initials = _getInitials(displayName);

    // Check if user is deleted
    final isDeletedUser =
        otherUser != null && otherUser.displayName == DeletedAccount.storedName;

    return AppBar(
      backgroundColor: context.surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 58,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        onPressed: _leaveConversation,
        icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
      ),
      title: InkWell(
        onTap: () async {
          // debugPrint('🔘 Tapped conversation header:');
          // debugPrint('   isGroup: ${_isGroup}');
          // debugPrint('   groupId: ${_effectiveGroupId}');
          // debugPrint('   otherUserId: ${_effectiveOtherUserId}');

          if (_isGroup) {
            // Use passed groupId, fallback to loaded groupData, then search by name
            String? groupIdToUse = _effectiveGroupId ?? groupData?.id;

            if (groupIdToUse == null && widget.conversationName != null) {
              final group = await ref.read(
                groupByNameProvider(widget.conversationName!).future,
              );
              groupIdToUse = group?.id;
            }

            if (!mounted) return;
            if (groupIdToUse != null) {
              context.push('/groups/$groupIdToUse');
            } else {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.loadingError)));
            }
          } else if (_effectiveOtherUserId != null) {
            if (isDeletedUser) {
              return;
            }
            // debugPrint('   ➡️ Navigating to /profile/${_effectiveOtherUserId}');
            context.push('/profile/$_effectiveOtherUserId');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Avatar + pastille de présence (fiche 4a). La pastille manquait :
              // l'en-tête ne disait « En ligne » qu'en toutes lettres, sous le
              // nom, là où la maquette la pose sur l'avatar.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      // Aplat, plus de dégradé : vert pour un groupe, terracotta
                      // pour une personne (§3b, §3c).
                      color:
                          _isGroup
                              ? context.adaptiveSecondaryColor
                              : context.adaptivePrimaryColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child:
                        displayImage != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: CachedNetworkImage(
                                imageUrl: displayImage,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => Center(
                                      child:
                                          _isGroup
                                              ? const AppIcon(
                                                AppIcon.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                                errorWidget:
                                    (_, __, ___) => Center(
                                      child:
                                          _isGroup
                                              ? const AppIcon(
                                                AppIcon.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                              ),
                            )
                            : Center(
                              child:
                                  _isSelfNotes
                                      ? const Icon(
                                        Icons.bookmark_rounded,
                                        color: AppColors.white,
                                        size: 22,
                                      )
                                      : _isGroup
                                      ? const AppIcon(
                                        AppIcon.groups,
                                        color: AppColors.white,
                                        size: 20,
                                      )
                                      : Text(
                                        initials,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                  ),
                  if (!_isGroup &&
                      _effectiveOtherUserId != null &&
                      !isDeletedUser)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      // Le liseré reprend le fond de l'en-tête : la pastille
                      // doit se détacher de l'avatar, pas s'y fondre.
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: OnlineStatusIndicator(
                          userId: _effectiveOtherUserId!,
                          showText: false,
                          dotSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom de la conversation, en serif comme tous les
                    // titres de la série (§3b, §4a).
                    DesignSectionTitle(
                      displayName ?? AppLocalizations.of(context)!.conversation,
                      size: 17,
                    ),
                    // Status text below name + cadenas chiffrement (§4a) —
                    // jamais affiché pour un compte supprimé, rien à protéger.
                    if (_isSelfNotes)
                      _buildStatusWithLock(
                        Text(
                          'Notes personnelles',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      )
                    else if (_isGroup)
                      Builder(
                        builder: (_) {
                          final count = groupData?.memberCount as int?;
                          final label =
                              (count != null && count > 0)
                                  ? '$count ${count > 1 ? 'membres' : 'membre'}'
                                  : AppLocalizations.of(context)!.group;
                          return _buildStatusWithLock(
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiaryColor,
                              ),
                            ),
                          );
                        },
                      )
                    else if (!_isGroup &&
                        _effectiveOtherUserId != null &&
                        !isDeletedUser)
                      // Online status text for individual chats
                      _buildStatusWithLock(
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: OnlineStatusIndicator(
                            key: ValueKey(_effectiveOtherUserId),
                            userId: _effectiveOtherUserId!,
                            showText: true,
                            showDot: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Appels 1-à-1 mis en pause (fiabilité en cours de vérification sur
        // appareil réel — 2026-08-14) : boutons masqués, code conservé pour
        // réactivation. Voir TESTS_APPAREIL_A_FAIRE.md.
        // TODO(appels): réactiver après vérification à deux vrais téléphones.
        // if (!_isGroup && !isDeletedUser && !_isSelfNotes) ...[
        //   IconButton(
        //     onPressed: () => _startCall(isVideo: false),
        //     icon: AppIcon(
        //       AppIcon.call,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.voiceCall,
        //   ),
        //   IconButton(
        //     onPressed: () => _startCall(isVideo: true),
        //     icon: AppIcon(
        //       AppIcon.video,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.videoCall,
        //   ),
        // ],
        // Appels de GROUPE mis en pause le 2026-09-14, comme le 1-à-1 avant
        // eux : sous 5 participants un appel de groupe tourne en maillage
        // flutter_webrtc — le MÊME `webrtc_service.dart` que le 1-à-1, et
        // non LiveKit (qui ne prend le relais qu'en SFU, à 5 participants
        // et plus). Les laisser actifs laissait la pile non vérifiée
        // atteignable depuis n'importe quel groupe. Boutons masqués, code
        // conservé. Voir TESTS_APPAREIL_A_FAIRE.md.
        // TODO(appels): réactiver après vérification à deux vrais téléphones.
        // if (_isGroup && !_isSelfNotes) ...[
        //   IconButton(
        //     onPressed: () => _startGroupCall(isVideo: false),
        //     icon: AppIcon(
        //       AppIcon.call,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.voiceCall,
        //   ),
        //   IconButton(
        //     onPressed: () => _startGroupCall(isVideo: true),
        //     icon: AppIcon(
        //       AppIcon.video,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.videoCall,
        //   ),
        // ],
        // More options button — icône nue, sans conteneur gris (§4a).
        IconButton(
          onPressed: () => _showConversationOptions(),
          icon: Icon(
            Icons.more_vert,
            color: context.textPrimaryColor,
            size: 21,
          ),
        ),
      ],
    );
  }

  /// Statut + cadenas chiffrement (§4a) : Signal pour 1-à-1/groupes, AES
  /// local pour « Mes notes » — jamais affiché pour un compte supprimé
  /// (géré en amont, cette méthode n'est pas appelée dans ce cas).
  ///
  /// ⚠️ Ce cadenas ne dit PAS le niveau de chiffrement réel. Un groupe peut
  /// tourner en repli AES — le cadenas reste le même. L'indicateur qui le
  /// signalait (cadenas ouvert + libellé + feuille explicative) a été retiré
  /// le 2026-08-23 à la demande de Salim.
  ///
  /// L'état reste mesuré et disponible dans `groupEncryptionStatusProvider`,
  /// et les journaux de `SenderKeyService` disent « repli AES maintenu » avec
  /// le compte de membres servis : c'est par là qu'il faut passer pour savoir
  /// où en est un groupe.
  Widget _buildStatusWithLock(Widget status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: status),
        const SizedBox(width: 4),
        AppIcon(AppIcon.lock, size: 11, color: context.textTertiaryColor),
      ],
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    // Scrollable : en paysage (ou clavier ouvert) la hauteur restante tombe
    // sous les ~317 px de l'illustration + textes → RenderFlex overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated chat illustration
            Container(
              width: 120,
              height: 120,
              // Pastille plate : le système n'utilise plus de dégradé
              // décoratif, l'illustration d'état vide est un aplat teinté.
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(
                    AppIcon.chatBubble,
                    size: 48,
                    color: context.adaptivePrimaryColor,
                  ),
                  // Small decorative elements
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.adaptiveSecondaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 25,
                    left: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.noMessages,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isGroup ? l10n.sendFirstMessageGroup : l10n.sendFirstMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Subtle hint with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: context.textTertiaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.typeYourMessageBelow,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRequestBanner(
    AppLocalizations l10n,
    ConversationEntity conversation,
    String currentUserId,
  ) {
    final isRecipient = conversation.isRequestRecipient(currentUserId);

    if (isRecipient) {
      // Show accept/decline banner for recipient
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: context.adaptivePrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.wantsToMessageYou,
                    style: TextStyle(
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleDeclineRequest(conversation.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(l10n.declineRequest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptRequest(conversation.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.acceptRequest),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Sender sees nothing special - conversation looks normal
    return const SizedBox.shrink();
  }

  Future<void> _handleAcceptRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.acceptRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestAccepted)));
        // Refresh conversation
        ref.invalidate(conversationStreamProvider(conversationId));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.declineRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestDeclined)));
        // Go back after declining (repli si la route est seule dans la pile)
        _leaveConversation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Pastille de la ligne épinglée (rayon 12, fond #F5F0E8 / #252119).
// Seule la bascule ÉCO l'utilisait ; commentée avec elle (voir _ecoChip
// ci-dessus) pour éviter un avertissement de déclaration inutilisée.
// class _SubBarTile extends StatelessWidget {
//   final Color bg;
//   final Widget icon;
//   final String label;
//   final Color labelColor;
//   final VoidCallback onTap;
//
//   const _SubBarTile({
//     required this.bg,
//     required this.icon,
//     required this.label,
//     required this.labelColor,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: bg,
//       borderRadius: BorderRadius.circular(12),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               icon,
//               const SizedBox(width: 6),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 12.5,
//                   fontWeight: FontWeight.w600,
//                   color: labelColor,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
