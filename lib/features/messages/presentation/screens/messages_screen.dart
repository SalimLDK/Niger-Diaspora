import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/message_provider.dart';
import '../widgets/conversation_item.dart';
import '../../../../core/theme/adaptive_colors.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<ConversationEntity> _filterConversations(
    List<ConversationEntity> conversations, {
    required String currentUserId,
    required bool showArchived,
    required Set<String> blockedUserIds,
  }) {
    // Filter out conversations with blocked users (for individual chats)
    var filtered =
        conversations.where((conv) {
          if (conv.isIndividual) {
            final otherUserId = conv.getOtherParticipantId(currentUserId);
            if (blockedUserIds.contains(otherUserId)) {
              return false;
            }
          }
          return true;
        }).toList();

    // Filter by archived status
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
            final name = (conv.name ?? '').toLowerCase();
            final lastMessage = (conv.lastMessage ?? '').toLowerCase();
            return name.contains(query) || lastMessage.contains(query);
          }).toList();
    }

    return filtered;
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
                : Text(l10n.messagesTitle),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
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
                child: Icon(Icons.search, color: context.textPrimaryColor),
              ),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit, color: context.textPrimaryColor),
              ),
              onPressed: () => context.push('/messages/new'),
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.adaptivePrimaryColor,
          unselectedLabelColor: context.textSecondaryColor,
          indicatorColor: context.adaptivePrimaryColor,
          tabs: [Tab(text: l10n.messagesTitle), Tab(text: l10n.archives)],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/messages/new'),
        backgroundColor: context.adaptivePrimaryColor,
        child: const Icon(Icons.message, color: AppColors.white),
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          final currentUserId = currentUser?.id ?? '';

          if (conversations.isEmpty) {
            return _buildEmptyState(context);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Messages tab (non-archived)
              _buildConversationList(
                conversations: conversations,
                currentUserId: currentUserId,
                showArchived: false,
                blockedUserIds: blockedUserIds,
              ),
              // Archives tab
              _buildConversationList(
                conversations: conversations,
                currentUserId: currentUserId,
                showArchived: true,
                blockedUserIds: blockedUserIds,
              ),
            ],
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
                  Icon(
                    Icons.error_outline,
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
            child: Icon(
              Icons.chat_bubble_outline,
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
            icon: const Icon(Icons.add),
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
  }) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filterConversations(
      conversations,
      currentUserId: currentUserId,
      showArchived: showArchived,
      blockedUserIds: blockedUserIds,
    );

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
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
              Icon(
                Icons.archive_outlined,
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final conversation = filtered[index];

        String? otherUserName;
        String? otherUserPhotoUrl;

        if (conversation.isIndividual) {
          otherUserName = conversation.name;
        }

        return ConversationItem(
          conversation: conversation,
          currentUserId: currentUserId,
          otherUserName: otherUserName ?? conversation.name,
          otherUserPhotoUrl: otherUserPhotoUrl ?? conversation.imageUrl,
          onTap: () {
            context.push(
              '/messages/${conversation.id}',
              extra: {
                'name':
                    conversation.isGroup
                        ? conversation.name
                        : (otherUserName ?? 'Conversation'),
                'imageUrl': conversation.imageUrl,
                'isGroup': conversation.isGroup,
                'otherUserId':
                    conversation.isGroup
                        ? null
                        : conversation.getOtherParticipantId(currentUserId),
              },
            );
          },
        );
      },
    );
  }
}
