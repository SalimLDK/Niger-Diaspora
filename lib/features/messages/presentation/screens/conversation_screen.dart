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
import '../widgets/bandeau_chiffrement_bloque.dart';
import '../widgets/conversation_options_modal.dart';
import '../widgets/forward_conversation_picker.dart';
import '../widgets/message_bubble.dart';
import '../utils/message_copy_text.dart';
import '../utils/message_grouping.dart';
import '../utils/phrase_modification.dart';
import '../utils/accuse_de_groupe.dart';
import '../utils/releve_a_l_ecran.dart';
import '../utils/suivi_des_non_lus.dart';
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

part 'conversation_screen_lecture.dart';
part 'conversation_screen_actions.dart';
part 'conversation_screen_affichage.dart';
part 'conversation_screen_barre.dart';

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
    if (m.isSystem) continue;
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
    if (m.isSystem) continue;
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
    if (m.isSystem) continue;
    if (m.senderId == moi) continue;
    restant--;
    if (restant == 0) return i;
  }
  // Moins de messages d'autrui que le compteur n'en annonçait : le fil n'est
  // pas encore complet. On ne pose rien plutôt que de se tromper de rang.
  return null;
}

/// Parmi les bulles à l'écran, celle qui porte le curseur de lecture le plus
/// loin : le message d'autrui le plus récent, s'il est postérieur à
/// [dejaVu].
///
/// `null` quand rien n'avancerait le curseur — y compris quand le compte
/// courant est inconnu : sans lui, « d'autrui » ne se décide pas, et avancer
/// jusqu'à l'un de mes messages marquerait lu ce qui le précède sans qu'on
/// l'ait regardé.
///
/// Une seule cible pour tout ce qui est à l'écran : le serveur marque
/// « jusqu'à », donc une écriture suffit, en groupe comme en tête-à-tête.
MessageEntity? plusRecentALire(
  Iterable<MessageEntity> visibles, {
  required String? moi,
  DateTime? dejaVu,
}) {
  if (moi == null) return null;
  MessageEntity? cible;
  for (final m in visibles) {
    if (m.isSystem) continue;
    if (m.senderId == moi) continue;
    if (dejaVu != null && !m.createdAt.isAfter(dejaVu)) continue;
    if (cible == null || m.createdAt.isAfter(cible.createdAt)) cible = m;
  }
  return cible;
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

  /// Comptes à rebours en cours, par identifiant de message.
  final Map<String, Timer> _attentesDeVisibilite = {};

  /// Le message le plus récent effectivement vu depuis l'ouverture.
  DateTime? _vuJusqua;

  /// Son identifiant : c'est lui que le serveur reçoit comme borne, pas la
  /// date — il relit lui-même `created_at`, sans question d'horloge ni de
  /// précision.
  String? _vuJusquaId;
  Timer? _envoiCurseur;

  /// Nouvel essai après un envoi du curseur en échec — voir
  /// [_reessayerLeCurseur].
  StreamSubscription<void>? _attenteSessionCurseur;
  Timer? _filetCurseur;
  int _essaisCurseur = 0;

  /// Les bulles d'autrui **actuellement** à l'écran, et le moment où la vue
  /// est posée.
  ///
  /// `VisibilityDetector` ne rapporte que les **changements** : une bulle qui
  /// reste à l'écran ne se signale plus jamais. Sans ce relevé, rien ne
  /// pourrait dire ce qui est affiché au moment où la vue se pose, ni au retour
  /// au premier plan — et un message arrivé pendant que l'app était en
  /// arrière-plan restait non lu, sous les yeux, tant qu'on ne défilait pas.
  ///
  /// Avant que la vue soit posée, ce qui passe à l'écran n'est qu'un état
  /// transitoire — la liste s'ouvre en bas, puis saute au premier non-lu. Lire
  /// à ce moment-là marquerait les derniers messages, que personne n'a vus.
  final ReleveALEcran _aLEcran = ReleveALEcran(seuil: _visibiliteMinimale);

  /// Filet : si le placement n'arrive jamais (fil vide à l'ouverture, compte
  /// pas encore chargé), le curseur doit quand même pouvoir avancer.
  Timer? _filetPlacement;

  /// Le séparateur et le badge **après** l'ouverture (étape B). Voir
  /// [SuiviDesNonLus].
  final SuiviDesNonLus _suivi = SuiviDesNonLus();

  /// Numéro du dernier relevé de suivi lancé : deux avancées rapprochées
  /// lancent deux relevés, et le plus ancien peut répondre en dernier. Sans
  /// ce garde, il ferait remonter le badge.
  int _releveDeSuivi = 0;

  /// Un relevé après chaque avancée du curseur : le badge descend, et le
  /// séparateur part quand tout ce qui était non lu à l'ouverture est lu.
  ///
  /// Une lecture, pas une écriture, et seulement tant qu'il reste quelque
  /// chose à faire descendre ou à faire partir.
  Future<void> _suivreLaLecture() async {
    if (!_repereFaitFoi || _unreadCountOnOpen == 0 || !_suivi.doitSuivre) {
      return;
    }
    final numero = ++_releveDeSuivi;
    try {
      final maintenant = await ref
          .read(lectureServeurProvider)
          .relever(widget.conversationId);
      if (!mounted || numero != _releveDeSuivi) return;
      // `VisibilityDetector` rapporte par lots de 500 ms : un séparateur entré
      // à l'écran à l'instant passerait pour absent, et partirait sous les
      // yeux. On vide les rapports en attente avant de décider.
      VisibilityDetectorController.instance.notifyNow();
      if (_suivi.suivre(maintenant)) setState(() {});
    } catch (e) {
      debugPrint('ConversationScreen: suivi des non-lus indisponible ($e)');
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

  // Gardes d'idempotence : _runGroupOpenWork() est appelé à l'ouverture ET à
  // chaque réconciliation, chaque effet ne doit partir qu'une fois.
  bool _unreadMentionsCleared = false;
  bool _privateGroupFilterRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(_releverCurseur());
    // Au-delà de la fenêtre d'ouverture, la vue est posée quoi qu'il arrive —
    // sans quoi une discussion vide à l'ouverture, ou un compte chargé en
    // retard, n'avancerait jamais le curseur. Annulé dès le vrai placement.
    _filetPlacement = Timer(_fenetreRecompteNonLus, _apresPlacement);
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
      unawaited(ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId));
      unawaited(_loadChatBackground());
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

  @override
  void dispose() {
    for (final attente in _attentesDeVisibilite.values) {
      attente.cancel();
    }
    _attentesDeVisibilite.clear();
    _envoiCurseur?.cancel();
    _filetCurseur?.cancel();
    unawaited(_attenteSessionCurseur?.cancel());
    _filetPlacement?.cancel();
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
      // « Livré » vaut dès que l'appareil a le message. « Lu », c'est ce qui
      // est à l'écran au retour — lu tout de suite, comme à l'ouverture.
      //
      // Ça ne se fait pas tout seul : la visibilité d'une bulle ne change pas
      // pendant que l'app est en arrière-plan, donc `VisibilityDetector` ne
      // redit rien au retour. Un message arrivé pendant l'absence voyait son
      // compte à rebours refusé (app pas au premier plan), et restait non lu
      // sous les yeux tant qu'on ne défilait pas.
      unawaited(ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId));
      if (_aLEcran.vuePosee) _lireCeQuiEstALEcran();
      setState(() {
        // Force rebuild to update date labels like "Aujourd'hui", "Hier"
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
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
      unawaited(_scrollController.animateTo(
        estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ));

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

    unawaited(showModalBottomSheet(
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
            // Même oubli que le minuteur ci-dessus : sans lui, le menu disait
            // « Mettre en sourdine » pendant la sourdine et n'offrait jamais de
            // la lever. Vu le 2026-09-21 sur SM A515F : sourdine posée (en
            // base), menu inchangé ; seul l'appui long de la liste la levait.
            isMuted:
                currentUser != null &&
                (conversation?.isMutedBy(currentUser.id) ?? false),
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
    ));
  }

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
            unawaited(ref
                .read(markAsDeliveredProvider.notifier)
                .mark(widget.conversationId));
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
                // Chiffrement bloqué : toujours présent, vide hors blocage —
                // même règle que le bandeau ci-dessus.
                BandeauChiffrementBloque(
                  conversationId: widget.conversationId,
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'text',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                            'is_reply': replyTo != null ? 'true' : 'false',
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': type.name,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'audio',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'audio',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                            'duration': duration,
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'location',
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'sticker',
                            'sticker_pack': sticker.packId,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        ));
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
                        unawaited(AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'gif',
                            'gif_provider': gif.provider.name,
                            'conversation_id': widget.conversationId,
                            'is_group': _isGroup ? 'true' : 'false',
                          },
                        ));
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
                        // Descend à mesure qu'on lit (étape B) : il gardait le
                        // compte d'ouverture jusqu'à la fermeture de l'écran.
                        if (_suivi.restants(_unreadCountOnOpen) > 0)
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
                                _suivi.restants(_unreadCountOnOpen) > 99
                                    ? '99+'
                                    : _suivi
                                        .restants(_unreadCountOnOpen)
                                        .toString(),
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
                unawaited(ref
                    .read(
                      paginatedMessagesProvider(widget.conversationId).notifier,
                    )
                    .refresh());
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
        // Un 1:1 n'a pas d'administrateur. En tenir un pour « celui qui a
        // créé la conversation » offrait à ce seul participant « Supprimer pour
        // tous » sur les messages de L'AUTRE — refusé par le serveur, sans un
        // mot à l'écran. Vu le 2026-09-21 sur SM A515F (Sim, créateur du 1:1).
        final isAdmin =
            _isGroup &&
            currentUserId != null &&
            groupForAdminCheck != null &&
            (groupForAdminCheck.creatorId == currentUserId ||
                groupForAdminCheck.adminIds.contains(currentUserId));

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
        //
        // Une fois retiré (tout lu, et hors de l'écran), il ne revient pas :
        // un message qui arrive ensuite est reçu en direct, pas « non lu
        // depuis l'ouverture ». Voir [SuiviDesNonLus].
        final showUnreadSeparator =
            _firstUnreadMessageId != null &&
            message.id == _firstUnreadMessageId &&
            _unreadCountOnOpen > 0 &&
            !_suivi.separateurRetire;

        // With reverse: true, separators go BEFORE the message in the Column
        // so they appear visually ABOVE (Column still renders top-to-bottom within each item)
        final ligne = Column(
          children: [
            // Date separator (appears ABOVE message visually)
            if (needsSeparator) _buildDateSeparator(message.createdAt, l10n),

            // Unread messages separator (appears ABOVE message visually)
            if (showUnreadSeparator)
              // Il ne part jamais sous les yeux : c'est sa sortie de l'écran
              // qui le retire, une fois tout lu.
              VisibilityDetector(
                key: const ValueKey('separateur-non-lus'),
                onVisibilityChanged: (info) {
                  if (!mounted) return;
                  if (_suivi.signalerSeparateur(info.visibleFraction)) {
                    setState(() {});
                  }
                },
                child: _buildUnreadSeparator(_unreadCountOnOpen),
              ),

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
                            // Étape C : en groupe, « Lu » attend tous les
                            // membres présents et arrivés avant le message.
                            // `group_members` fait foi ; la liste des
                            // participants ne sert qu'à défaut de groupe
                            // Supabase (groupes hérités de Firestore), sans
                            // dates d'arrivée.
                            lecteursAttendus:
                                _isGroup && isMe
                                    ? (groupForAdminCheck != null
                                        ? lecteursAttendus(
                                          message,
                                          membres: groupForAdminCheck.memberIds,
                                          arrivees:
                                              groupForAdminCheck.memberJoinedAt,
                                        )
                                        : conversation != null
                                        ? lecteursAttendus(
                                          message,
                                          membres: conversation.participantIds,
                                        )
                                        : null)
                                    : null,
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
                              unawaited(ref
                                  .read(
                                    paginatedMessagesProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .toggleStar(msg.id));
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
                                unawaited(context.push('/profile/$userId'));
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
}

/// Fraction de la bulle qui doit être à l'écran pour que le compte à rebours
/// commence.
const _visibiliteMinimale = 0.6;

/// Durée pendant laquelle elle doit le rester. Un défilement rapide qui
/// traverse vingt messages n'en fait lire aucun.
const _dureeAvantVu = Duration(milliseconds: 400);

/// Le serveur n'est prévenu qu'une fois le défilement posé.
const _delaiAvantEnvoi = Duration(milliseconds: 700);

/// Au-delà, un message qui arrive est un message **reçu en direct** : il ne
/// doit pas se ranger sous un séparateur « nouveaux messages » sous les yeux
/// de quelqu'un qui regarde la discussion.
const _fenetreRecompteNonLus = Duration(seconds: 6);

/// Destination de repli quand il n'y a rien à dépiler.
const String _fallbackRoute = '/messages';


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
