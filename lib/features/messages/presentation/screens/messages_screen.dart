import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/conversation_actions_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/message_provider.dart';
import '../widgets/conversation_item.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Filtres rapides de la liste, en puces sous l'en-tête.
enum _MessagesFilter { all, unread, groups }

/// Pastille d'action de l'en-tête : carré arrondi sombre sur le dégradé.
class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(width: 46, height: 46, child: Center(child: icon)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  bool _showArchived = false;
  _MessagesFilter _filter = _MessagesFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConversationEntity> _filterConversations(
    List<ConversationEntity> conversations, {
    required String currentUserId,
    required bool showArchived,
    required Set<String> blockedUserIds,
    required Map<String, String> participantNames,
  }) {
    // Filter by archived status
    var filtered = conversations;
    filtered =
        filtered.where((conv) {
          final isArchived = conv.isArchivedBy(currentUserId);
          return showArchived ? isArchived : !isArchived;
        }).toList();

    // « Mes notes » (self-chat) a sa propre tuile épinglée en tête de liste :
    // on la retire d'ici, sinon elle apparaîtrait deux fois.
    filtered =
        filtered.where((conv) => !conv.isSelfNotesFor(currentUserId)).toList();

    // Puces de filtre rapide (ne s'appliquent pas aux archives, qui ont déjà
    // leur propre vue).
    if (!showArchived) {
      switch (_filter) {
        case _MessagesFilter.all:
          break;
        case _MessagesFilter.unread:
          filtered =
              filtered.where((conv) => conv.hasUnreadFor(currentUserId)).toList();
        case _MessagesFilter.groups:
          filtered = filtered.where((conv) => conv.isGroup).toList();
      }
    }

    // Then filter by search query if any
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((conv) {
            // Search by conversation name (for groups)
            final name = (conv.name ?? '').toLowerCase();
            if (name.contains(query)) {
              return true;
            }

            // Search by last message
            final lastMessage = (conv.lastMessage ?? '').toLowerCase();
            if (lastMessage.contains(query)) {
              return true;
            }

            // For individual conversations, search by other participant's name
            if (conv.isIndividual) {
              final otherUserId = conv.getOtherParticipantId(currentUserId);
              if (otherUserId.isNotEmpty) {
                final displayName = (participantNames[otherUserId] ?? '').toLowerCase();
                if (displayName.contains(query)) {
                  return true;
                }
              }
            }

            return false;
          }).toList();
    }

    return filtered;
  }

  void _showConversationOptions(
    BuildContext context,
    ConversationEntity conversation,
    String currentUserId,
  ) {
    if (conversation.isGroup &&
        !conversation.participantIds.contains(currentUserId)) {
      // User left group logic if needed, but for now just actions
    }

    final isArchived = conversation.isArchivedBy(currentUserId);
    final isMuted = conversation.isMutedBy(currentUserId);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.textTertiaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: isArchived
                      ? Icon(
                          Icons.unarchive_outlined,
                          color: context.adaptivePrimaryColor,
                        )
                      : AppIcon(
                          AppIcon.archive,
                          color: context.adaptivePrimaryColor,
                        ),
                  title: Text(
                    isArchived ? l10n.unarchive : l10n.archive,
                    style: TextStyle(color: context.textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .archiveConversation(conversation.id, !isArchived);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isMuted
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_outlined,
                    color: context.adaptivePrimaryColor,
                  ),
                  title: Text(
                    isMuted ? l10n.unmute : l10n.mute,
                    style: TextStyle(color: context.textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .muteConversation(conversation.id, !isMuted);
                  },
                ),
                ListTile(
                  leading: const AppIcon(AppIcon.delete, color: Colors.red),
                  title: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, conversation);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ConversationEntity conversation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteConversation),
            content: Text(l10n.confirmDeleteConversation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref
                      .read(conversationActionsNotifierProvider.notifier)
                      .deleteConversation(conversation.id);
                },
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

    // Total de non-lus affiché sous le titre. Les archives en sont exclues :
    // ce compteur décrit ce qui attend l'utilisateur dans sa liste courante.
    final headerUserId = currentUser?.id ?? '';
    final unreadTotal = (conversationsAsync.valueOrNull ?? [])
        .where((conv) => !conv.isArchivedBy(headerUserId))
        .fold<int>(
          0,
          (sum, conv) => sum + conv.getUnreadCountFor(headerUserId),
        );

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // Pas d'AppBar : l'en-tête dégradé est rendu en tête du body, pour que le
      // dégradé remonte jusque sous la barre d'état comme sur Accueil et Profil.
      // Plus de FAB : « nouvelle conversation » est désormais une action de
      // l'en-tête (bouton compose), pour un rendu épuré aligné sur Profil.
      body: Column(
        children: [
          _buildGradientHeader(context, l10n, unreadTotal),
          _buildFilterChips(context, l10n),
          Expanded(
            child: conversationsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (conversations) {
          final currentUserId = currentUser?.id ?? '';

          if (conversations.isEmpty) {
            return _buildEmptyState(context);
          }

          // Build participant names map for individual conversations
          final participantNames = <String, String>{};
          for (final conv in conversations) {
            if (conv.isIndividual) {
              final otherUserId = conv.getOtherParticipantId(currentUserId);
              if (otherUserId.isNotEmpty && !participantNames.containsKey(otherUserId)) {
                final profileAsync = ref.watch(userStreamProvider(otherUserId));
                final profile = profileAsync.valueOrNull;
                if (profile != null) {
                  participantNames[otherUserId] = profile.displayName ?? '';
                }
              }
            }
          }

          return _buildConversationList(
            conversations: conversations,
            currentUserId: currentUserId,
            showArchived: _showArchived,
            blockedUserIds: blockedUserIds,
            participantNames: participantNames,
          );
        },
        loading:
            () => Center(
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            ),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    AppIcon.error,
                    size: 48,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingError,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(conversationsProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcon.chatBubble,
              size: 64,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noConversation,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.startChatting,
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/messages/new'),
            icon: const AppIcon(AppIcon.add),
            label: Text(l10n.newConversation),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.adaptivePrimaryColor,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// En-tête façon « hero » : bandeau dégradé, grand titre, compteur de non-lus
  /// et actions en pastilles. Aligné sur Accueil et Profil, qui utilisent déjà
  /// `context.adaptivePrimaryGradient` — la messagerie était le seul onglet
  /// resté sur une AppBar plate.
  Widget _buildGradientHeader(
    BuildContext context,
    AppLocalizations l10n,
    int unreadTotal,
  ) {
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(gradient: context.adaptivePrimaryGradient),
        child: Stack(
          children: [
            ..._buildHeaderDecorations(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showArchived)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: AppIcon(
                            AppIcon.arrowBack,
                            color: AppColors.white,
                          ),
                          onPressed: () =>
                              setState(() => _showArchived = false),
                        ),
                      ),
                    Expanded(
                      child: _isSearching
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: const TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                hintText: l10n.searchPlaceholder,
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: AppColors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showArchived
                                      ? l10n.archives
                                      : l10n.messagesTitle,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                                if (!_showArchived && unreadTotal > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.unreadConversations(unreadTotal),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    if (_isSearching)
                      _HeaderActionButton(
                        icon: const AppIcon(
                          AppIcon.close,
                          color: AppColors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    else ...[
                      _HeaderActionButton(
                        icon: const Icon(
                          Icons.add_comment_outlined,
                          color: AppColors.white,
                        ),
                        onPressed: () => context.push('/messages/new'),
                        tooltip: l10n.newConversation,
                      ),
                      const SizedBox(width: 10),
                      _HeaderActionButton(
                        icon: const AppIcon(
                          AppIcon.search,
                          color: AppColors.white,
                        ),
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                      const SizedBox(width: 10),
                      _HeaderActionButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.white,
                        ),
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        tooltip: _showArchived
                            ? l10n.messagesTitle
                            : l10n.archives,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Motifs décoratifs (cercles blancs translucides) en fond de l'en-tête,
  /// repris du style de l'écran Profil. Clippés au bandeau par le ClipRect.
  List<Widget> _buildHeaderDecorations() {
    Widget circle(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: alpha),
          ),
        );
    return [
      Positioned(top: -45, right: -35, child: circle(170, 0.06)),
      Positioned(top: 25, right: 55, child: circle(90, 0.05)),
      Positioned(bottom: -35, left: -25, child: circle(120, 0.04)),
    ];
  }

  /// Puces de filtre rapide. Masquées en recherche et dans les archives, où
  /// elles n'auraient pas de sens.
  Widget _buildFilterChips(BuildContext context, AppLocalizations l10n) {
    if (_showArchived || _isSearching) return const SizedBox.shrink();

    final entries = <(_MessagesFilter, String)>[
      (_MessagesFilter.all, l10n.filterAll),
      (_MessagesFilter.unread, l10n.filterUnread),
      (_MessagesFilter.groups, l10n.filterGroups),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final (value, label) = entries[index];
            final isSelected = _filter == value;
            return GestureDetector(
              onTap: () => setState(() => _filter = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.18)
                          : context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      AppIcon(
                        AppIcon.check,
                        size: 16,
                        color: context.adaptivePrimaryColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isSelected
                                ? context.adaptivePrimaryColor
                                : context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ouvre « Mes notes » : récupère (ou crée à la volée) la conversation dont
  /// l'utilisateur est l'unique participant, puis navigue avec le flag dédié
  /// qui désactive les appels et bascule le menu « + » en brouillon de sondage.
  Future<void> _openSelfNotes() async {
    final conversation =
        await ref.read(ensureSelfNotesProvider.notifier).ensure();
    if (!mounted) return;

    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir Mes notes pour le moment"),
        ),
      );
      return;
    }

    context.push(
      '/messages/${conversation.id}',
      extra: {
        'name': 'Mes notes',
        'isGroup': false,
        'isSelfNotes': true,
      },
    );
  }

  /// Tuile épinglée « Mes notes », toujours en tête de liste (hors recherche
  /// et hors archives). L'aperçu reprend le dernier contenu noté s'il existe.
  Widget _buildSelfNotesTile(BuildContext context) {
    final selfConversation = ref.watch(selfNotesConversationProvider);
    final lastNote = selfConversation?.lastMessage?.trim();
    final subtitle =
        (lastNote != null && lastNote.isNotEmpty)
            ? lastNote
            : 'Notes, brouillons et sondages';
    final isOpening = ref.watch(ensureSelfNotesProvider).isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOpening ? null : _openSelfNotes,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: context.adaptivePrimaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: isOpening
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.push_pin,
                            size: 24,
                            color: AppColors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Mes notes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.adaptivePrimaryColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.push_pin,
                                  size: 11,
                                  color: context.adaptivePrimaryColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Épinglé',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.adaptivePrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.textTertiaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList({
    required List<ConversationEntity> conversations,
    required String currentUserId,
    required bool showArchived,
    required Set<String> blockedUserIds,
    required Map<String, String> participantNames,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filterConversations(
      conversations,
      currentUserId: currentUserId,
      showArchived: showArchived,
      blockedUserIds: blockedUserIds,
      participantNames: participantNames,
    );

    // La tuile « Mes notes » n'a de sens que sur la liste principale : ni dans
    // les archives, ni au milieu de résultats de recherche.
    final showSelfNotesTile = !showArchived && _searchQuery.isEmpty;

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcon.searchOff,
                size: 64,
                color: context.textTertiaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noResults(_searchQuery),
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      }

      // Empty state for archives
      if (showArchived) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcon.archive,
                size: 64,
                color: context.textTertiaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noArchivedConversation,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      }

      // Empty state for messages - use _buildEmptyState. La tuile « Mes notes »
      // reste accessible même si aucune conversation n'existe encore.
      if (!showSelfNotesTile) return _buildEmptyState(context);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: _buildSelfNotesTile(context),
          ),
          Expanded(child: _buildEmptyState(context)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(conversationsProvider);
      },
      color: context.adaptivePrimaryColor,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: filtered.length + (showSelfNotesTile ? 1 : 0),
        itemBuilder: (context, index) {
          if (showSelfNotesTile && index == 0) {
            return _buildSelfNotesTile(context);
          }
          final conversation =
              filtered[showSelfNotesTile ? index - 1 : index];

          return ConversationItem(
            conversation: conversation,
            currentUserId: currentUserId,
            onTap: () {
              context.push(
                '/messages/${conversation.id}',
                extra: {
                  'name': conversation.name ?? 'Conversation',
                  'imageUrl': conversation.imageUrl,
                  'isGroup': conversation.isGroup,
                  'groupId': conversation.groupId,
                  'otherUserId':
                      conversation.isGroup
                          ? null
                          : conversation.getOtherParticipantId(currentUserId),
                },
              );
            },
            onLongPress:
                () => _showConversationOptions(
                  context,
                  conversation,
                  currentUserId,
                ),
          );
        },
      ),
    );
  }
}
