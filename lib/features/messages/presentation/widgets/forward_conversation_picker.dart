import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class ForwardConversationPicker extends ConsumerStatefulWidget {
  final List<MessageEntity> messages;

  const ForwardConversationPicker({super.key, required this.messages});

  /// Show the picker as a modal bottom sheet.
  /// Returns true if messages were forwarded successfully.
  static Future<bool?> show(
    BuildContext context, {
    required List<MessageEntity> messages,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardConversationPicker(messages: messages),
    );
  }

  @override
  ConsumerState<ForwardConversationPicker> createState() =>
      _ForwardConversationPickerState();
}

class _ForwardConversationPickerState
    extends ConsumerState<ForwardConversationPicker> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _searchQuery = '';
  bool _isSending = false;

  // Pour la sélection multiple
  final Set<String> _selectedConversationIds = {};
  bool _isSelectionMode = false;

  // Pour tracker quel tile est en cours d'envoi (mode single)
  String? _sendingToConversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isMultiSelectMode = _isSelectionMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          const SheetHandle(),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.shortcut, color: context.textPrimaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.forwardTo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      Text(
                        isMultiSelectMode
                            ? 'Sélectionnez les conversations'
                            : 'Appuyez pour envoyer',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.messages.length > 1 && !isMultiSelectMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.messages.length} messages',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Bouton Sélectionner / Annuler
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_isSelectionMode) {
                        _isSelectionMode = false;
                        _selectedConversationIds.clear();
                      } else {
                        _isSelectionMode = true;
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    backgroundColor:
                        isMultiSelectMode
                            ? Colors.red.withValues(alpha: 0.1)
                            : context.adaptivePrimaryColor.withValues(
                              alpha: 0.1,
                            ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isMultiSelectMode ? l10n.cancel : l10n.selectAction,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isMultiSelectMode
                              ? Colors.red
                              : context.adaptivePrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchConversation,
                prefixIcon: AppIcon(AppIcon.search,
                  color: context.textTertiaryColor,
                ),
                filled: true,
                fillColor: context.surfaceVariantColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Selection info
          if (isMultiSelectMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  AppIcon(AppIcon.checkCircle,
                    size: 18,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedConversationIds.length} conversation(s) sélectionnée(s)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedConversationIds.clear();
                      });
                    },
                    child: Text(
                      l10n.deselectAll,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
                ],
              ),
            ),

          // Conversation list
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                final filtered =
                    conversations.where((conv) {
                      if (_searchQuery.isEmpty) return true;
                      final name = conv.name?.toLowerCase() ?? '';
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noConversationFound,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    final isSelected = _selectedConversationIds.contains(
                      conversation.id,
                    );
                    final isLoading =
                        _sendingToConversationId == conversation.id;

                    return _ConversationTile(
                      conversation: conversation,
                      currentUserId: currentUser?.id,
                      isLoading: isLoading,
                      isSelected: isSelected,
                      isMultiSelectMode: isMultiSelectMode,
                      onTap: () {
                        if (isMultiSelectMode) {
                          _toggleSelection(conversation.id);
                        } else {
                          _forwardTo([conversation]);
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      l10n.loadingError,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
            ),
          ),

          // Bouton d'envoi multiple
          if (isMultiSelectMode)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendToSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isSending
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  l10n.adminSending,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const AppIcon(AppIcon.send, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.sendToConversations(_selectedConversationIds.length),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_selectedConversationIds.contains(conversationId)) {
        _selectedConversationIds.remove(conversationId);
      } else {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _sendToSelected() async {
    if (_isSending || _selectedConversationIds.isEmpty) return;

    final conversationsAsync = ref.read(conversationsProvider);
    final conversations = conversationsAsync.valueOrNull ?? [];

    final selectedConversations =
        conversations
            .where((c) => _selectedConversationIds.contains(c.id))
            .toList();

    await _forwardTo(selectedConversations);
  }

  Future<void> _forwardTo(List<ConversationEntity> conversations) async {
    if (_isSending) return;

    final isSingleSend = conversations.length == 1;

    setState(() {
      _isSending = true;
      if (isSingleSend) {
        _sendingToConversationId = conversations.first.id;
      }
    });

    try {
      final sendNotifier = ref.read(sendMessageProvider.notifier);
      int successCount = 0;

      for (final conversation in conversations) {
        for (final message in widget.messages) {
          final success = await sendNotifier.forwardMessage(
            targetConversationId: conversation.id,
            originalMessage: message,
          );
          if (success) successCount++;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(successCount > 0);

        final totalExpected = conversations.length * widget.messages.length;
        final allSuccess = successCount == totalExpected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allSuccess
                  ? conversations.length == 1
                      ? widget.messages.length > 1
                          ? '${widget.messages.length} messages transférés'
                          : l10n.messageForwarded
                      : '${widget.messages.length} message(s) envoyé(s) à ${conversations.length} conversation(s)'
                  : 'Certains messages n\'ont pas pu être envoyés',
            ),
            backgroundColor:
                allSuccess ? context.adaptivePrimaryColor : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendingToConversationId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.forwardError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationEntity conversation;
  final String? currentUserId;
  final bool isLoading;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isLoading,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // For individual conversations, get the other user's profile
    String displayName = conversation.name ?? l10n.conversation;
    String? avatarUrl = conversation.imageUrl;

    if (conversation.isIndividual && currentUserId != null) {
      final otherUserId = conversation.getOtherParticipantId(currentUserId!);
      final otherUser = ref.watch(userStreamProvider(otherUserId)).valueOrNull;
      if (otherUser != null) {
        displayName = otherUser.displayName ?? displayName;
        avatarUrl = otherUser.photoUrl ?? avatarUrl;
      }
    }

    return ListTile(
      onTap: isLoading ? null : onTap,
      tileColor:
          isSelected
              ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
              : null,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                conversation.isGroup
                    ? context.adaptiveSecondaryColor.withValues(alpha: 0.2)
                    : context.adaptivePrimaryColor.withValues(alpha: 0.2),
            backgroundImage:
                avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
            child:
                avatarUrl == null || avatarUrl.isEmpty
                    ? (conversation.isGroup
                        ? AppIcon(
                          AppIcon.groups,
                          color: context.adaptiveSecondaryColor,
                        )
                        : AppIcon(
                          AppIcon.person,
                          color: context.adaptivePrimaryColor,
                        ))
                    : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surfaceColor, width: 2),
                ),
                child: const AppIcon(AppIcon.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textPrimaryColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.isGroup ? l10n.group : 'Message privé',
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      ),
      trailing:
          isLoading
              ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              )
              : isMultiSelectMode
              ? Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: context.adaptivePrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              )
              : AppIcon(AppIcon.send, size: 20, color: context.adaptivePrimaryColor),
    );
  }
}
