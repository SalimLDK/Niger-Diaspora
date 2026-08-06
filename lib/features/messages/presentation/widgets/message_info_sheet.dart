import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/services/message_action_service.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Sheet affichant les informations de statut d'un message :
/// - qui l'a lu et quand
/// - qui l'a reçu et quand
/// - qui a réagi et avec quel emoji
class MessageInfoSheet extends ConsumerStatefulWidget {
  final MessageEntity message;
  final String conversationId;
  final String? currentUserId;

  const MessageInfoSheet({
    super.key,
    required this.message,
    required this.conversationId,
    this.currentUserId,
  });

  @override
  ConsumerState<MessageInfoSheet> createState() => _MessageInfoSheetState();
}

class _MessageInfoSheetState extends ConsumerState<MessageInfoSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, List<String>> _reactions = {};
  bool _reactionsLoading = true;
  String? _reactionsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReactions() async {
    try {
      final service = ref.read(messageActionServiceProvider);
      final result = await service.getReactions(
        conversationId: widget.conversationId,
        messageId: widget.message.id,
      );
      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _reactionsError = failure.message;
              _reactionsLoading = false;
            });
          }
        },
        (reactions) {
          if (mounted) {
            setState(() {
              _reactions = reactions;
              _reactionsLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _reactionsError = e.toString();
          _reactionsLoading = false;
        });
      }
    }
  }

  List<String> get _readerIds {
    return widget.message.readBy
        .where((id) => id != widget.message.senderId)
        .toList();
  }

  List<String> get _deliveredIds {
    return widget.message.deliveredTo
        .where((id) => id != widget.message.senderId)
        .toList();
  }

  int get _totalReactions {
    return _reactions.values.fold<int>(0, (sum, list) => sum + list.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragHandle(),
              _MessagePreviewCard(message: widget.message),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelColor: context.adaptivePrimaryColor,
                unselectedLabelColor: context.textSecondaryColor,
                indicatorColor: context.adaptivePrimaryColor,
                tabs: [
                  Tab(text: l10n.tabReadBy(_readerIds.length)),
                  Tab(text: l10n.tabDeliveredTo(_deliveredIds.length)),
                  Tab(
                    text: l10n.tabReactions(
                      _reactionsLoading ? 0 : _totalReactions,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ReadByTab(
                      message: widget.message,
                      userIds: _readerIds,
                      emptyTitle: l10n.notReadYet,
                      emptyIcon: Icons.done_all,
                    ),
                    _DeliveredTab(
                      message: widget.message,
                      userIds: _deliveredIds,
                      emptyTitle: l10n.notDeliveredYet,
                      emptyIcon: Icons.done_all,
                    ),
                    _ReactionsTab(
                      reactions: _reactions,
                      isLoading: _reactionsLoading,
                      error: _reactionsError,
                      onRetry: _loadReactions,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========================= WIDGETS RÉUTILISABLES =========================

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: SheetHandle(),
    );
  }
}

class _MessagePreviewCard extends StatelessWidget {
  final MessageEntity message;

  const _MessagePreviewCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final icon = _messageTypeIcon(message.type);
    final previewText = _previewText(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            _EncryptionIcon(message: message),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: context.textSecondaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.textPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.messageSentAt(_formatFullDateTime(message.createdAt)),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (message.isText || message.isSticker) return message.content;
    if (message.isImage) return l10n.photoLabel;
    if (message.isVideo) return l10n.videoLabel;
    if (message.isAudio || message.isVoiceNote) return l10n.audioLabel;
    if (message.isFile) return message.fileName ?? l10n.fileLabel;
    if (message.isLocation) return l10n.location;
    if (message.isCall) return l10n.callTitle;
    return l10n.message;
  }

  IconData _messageTypeIcon(MessageType type) {
    return switch (type) {
      MessageType.text => Icons.chat_bubble_outline,
      MessageType.image => Icons.image_outlined,
      MessageType.file => Icons.insert_drive_file_outlined,
      MessageType.audio => Icons.audiotrack_outlined,
      MessageType.voiceNote => Icons.mic_none,
      MessageType.video => Icons.videocam_outlined,
      MessageType.location => Icons.location_on_outlined,
      MessageType.call => Icons.call_outlined,
      MessageType.sticker => Icons.emoji_emotions_outlined,
      MessageType.system => Icons.info_outline,
    };
  }
}

class _EncryptionIcon extends StatelessWidget {
  final MessageEntity message;

  const _EncryptionIcon({required this.message});

  @override
  Widget build(BuildContext context) {
    final isE2ee = message.encryptionLevel == MessageEncryptionLevel.e2ee;
    return Tooltip(
      message: isE2ee ? 'End-to-end encrypted' : 'Encrypted',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (isE2ee ? Colors.green : Colors.blue).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isE2ee ? Icons.lock_outline : Icons.vpn_key_outlined,
          size: 18,
          color: isE2ee ? Colors.green : Colors.blue,
        ),
      ),
    );
  }
}

class _ReadByTab extends StatelessWidget {
  final MessageEntity message;
  final List<String> userIds;
  final String emptyTitle;
  final IconData emptyIcon;

  const _ReadByTab({
    required this.message,
    required this.userIds,
    required this.emptyTitle,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return _EmptyStateView(icon: emptyIcon, title: emptyTitle);
    }

    final sorted = _sortByTimestamp(userIds, message.readAt);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final userId = sorted[index];
        final timestamp = message.readAt[userId];
        return _UserStatusTile(
          userId: userId,
          timestamp: timestamp,
          trailing: null,
        );
      },
    );
  }
}

class _DeliveredTab extends StatelessWidget {
  final MessageEntity message;
  final List<String> userIds;
  final String emptyTitle;
  final IconData emptyIcon;

  const _DeliveredTab({
    required this.message,
    required this.userIds,
    required this.emptyTitle,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return _EmptyStateView(icon: emptyIcon, title: emptyTitle);
    }

    final sorted = _sortByTimestamp(userIds, message.deliveredAt);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final userId = sorted[index];
        final timestamp = message.deliveredAt[userId];
        return _UserStatusTile(
          userId: userId,
          timestamp: timestamp,
          trailing: null,
        );
      },
    );
  }
}

class _ReactionsTab extends StatefulWidget {
  final Map<String, List<String>> reactions;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _ReactionsTab({
    required this.reactions,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  State<_ReactionsTab> createState() => _ReactionsTabState();
}

class _ReactionsTabState extends State<_ReactionsTab> {
  String? _selectedEmoji;

  List<_ReactionItem> get _items {
    final items = <_ReactionItem>[];
    widget.reactions.forEach((emoji, userIds) {
      for (final userId in userIds) {
        items.add(_ReactionItem(emoji: emoji, userId: userId));
      }
    });
    return items;
  }

  List<_ReactionItem> get _filteredItems {
    if (_selectedEmoji == null) return _items;
    return _items.where((item) => item.emoji == _selectedEmoji).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return _ErrorView(message: widget.error!, onRetry: widget.onRetry);
    }

    if (_items.isEmpty) {
      return _EmptyStateView(
        icon: Icons.sentiment_satisfied_outlined,
        title: l10n.noReactionsYet,
      );
    }

    return Column(
      children: [
        _EmojiFilterBar(
          reactions: widget.reactions,
          selectedEmoji: _selectedEmoji,
          onSelected: (emoji) {
            setState(() {
              _selectedEmoji = emoji;
            });
          },
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];
              return _UserStatusTile(
                userId: item.userId,
                timestamp: null,
                trailing: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmojiFilterBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? selectedEmoji;
  final ValueChanged<String?> onSelected;

  const _EmojiFilterBar({
    required this.reactions,
    required this.selectedEmoji,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sortedEmojis =
        reactions.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _EmojiChip(
            label: l10n.allReactions,
            count: reactions.values.fold(0, (sum, list) => sum + list.length),
            isSelected: selectedEmoji == null,
            onTap: () => onSelected(null),
          ),
          ...sortedEmojis.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _EmojiChip(
                emoji: entry.key,
                count: entry.value.length,
                isSelected: selectedEmoji == entry.key,
                onTap: () => onSelected(entry.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String? emoji;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmojiChip({
    this.emoji,
    this.label = '',
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.surfaceVariantColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.outlineColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
              ] else ...[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isSelected
                            ? context.onPrimaryColor
                            : context.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected
                          ? context.onPrimaryColor
                          : context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserStatusTile extends ConsumerWidget {
  final String userId;
  final DateTime? timestamp;
  final Widget? trailing;

  const _UserStatusTile({required this.userId, this.timestamp, this.trailing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider(userId));

    return profileAsync.when(
      data: (profile) => _buildTile(context, profile),
      loading: () => _buildShimmer(context),
      error: (_, __) => _buildTile(context, null),
    );
  }

  Widget _buildTile(BuildContext context, ProfileEntity? profile) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = profile?.displayName ?? l10n.user;
    final photoUrl = profile?.photoUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: _Avatar(photoUrl: photoUrl),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ),
          if (profile?.isVerified == true) ...[
            const SizedBox(width: 4),
            const VerificationBadge(size: VerificationBadgeSize.small),
          ],
        ],
      ),
      subtitle:
          timestamp != null
              ? Text(
                _formatRelativeDateTime(context, timestamp!),
                style: TextStyle(
                  fontSize: 13,
                  color: context.textTertiaryColor,
                ),
              )
              : null,
      trailing: trailing,
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.borderColor.withValues(alpha: 0.3),
      highlightColor: context.surfaceVariantColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;

  const _Avatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
      ),
      child: ClipOval(
        child:
            photoUrl != null && photoUrl!.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  width: 44,
                  height: 44,
                  placeholder: (_, __) => _placeholder(context),
                  errorWidget: (_, __, ___) => _placeholder(context),
                )
                : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: AppIcon(AppIcon.person, size: 24, color: context.adaptivePrimaryColor),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;

  const _EmptyStateView({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: context.textTertiaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcon.error, size: 40, color: context.errorColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: AppIcon(AppIcon.refresh, color: Theme.of(context).iconTheme.color!),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= HELPERS =========================

class _ReactionItem {
  final String emoji;
  final String userId;

  const _ReactionItem({required this.emoji, required this.userId});
}

List<String> _sortByTimestamp(
  List<String> userIds,
  Map<String, DateTime> timestamps,
) {
  return [...userIds]..sort((a, b) {
    final ta = timestamps[a];
    final tb = timestamps[b];
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });
}

String _formatFullDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateFormat.yMMMd().add_Hm().format(local);
}

String _formatRelativeDateTime(BuildContext context, DateTime dateTime) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final local = dateTime.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final dateDay = DateTime(local.year, local.month, local.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final timeStr = DateFormat.Hm().format(local);

  if (dateDay == today) {
    return l10n.today(timeStr);
  }
  if (dateDay == yesterday) {
    return l10n.yesterday(timeStr);
  }
  return DateFormat.yMMMd().add_Hm().format(local);
}
