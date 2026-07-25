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

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchPlaceholder,
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: context.textTertiaryColor),
                  ),
                  style: TextStyle(color: context.textPrimaryColor),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
                : Text(_showArchived ? l10n.archives : l10n.messagesTitle),
        leading: _showArchived
            ? IconButton(
                icon: const AppIcon(AppIcon.arrowBack),
                onPressed: () {
                  setState(() => _showArchived = false);
                },
              )
            : null,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const AppIcon(AppIcon.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcon(AppIcon.search, color: context.textPrimaryColor),
              ),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.more_vert, color: context.textPrimaryColor),
              ),
              onSelected: (value) {
                if (value == 'archives') {
                  setState(() => _showArchived = !_showArchived);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'archives',
                  child: Row(
                    children: [
                      _showArchived
                          ? AppIcon(
                              AppIcon.chatBubble,
                              color: context.textPrimaryColor,
                            )
                          : AppIcon(
                              AppIcon.archive,
                              color: context.textPrimaryColor,
                            ),
                      const SizedBox(width: 12),
                      Text(_showArchived ? l10n.messagesTitle : l10n.archives),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/messages/new'),
              backgroundColor: context.adaptivePrimaryColor,
              child: const Icon(Icons.message, color: AppColors.white),
            ),
      body: conversationsAsync.when(
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

      // Empty state for messages - use _buildEmptyState
      return _buildEmptyState(context);
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
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final conversation = filtered[index];

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
