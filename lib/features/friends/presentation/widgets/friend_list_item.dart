import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/friend_provider.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class FriendListItem extends ConsumerWidget {
  final FriendEntity friend;

  const FriendListItem({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () => context.push('/profile/${friend.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: AppSpacing.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'message') {
                    // Create or get existing conversation with friend
                    final conversation = await ref
                        .read(createConversationProvider.notifier)
                        .createIndividual(friend.id);

                    if (conversation != null && context.mounted) {
                      context.push(
                        '/messages/${conversation.id}',
                        extra: {
                          'name': friend.displayName,
                          'imageUrl': friend.photoUrl,
                          'isGroup': false,
                          'otherUserId': friend.id,
                        },
                      );
                    }
                  } else if (value == 'remove') {
                    _showRemoveFriendDialog(context, ref);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'message',
                        child: Row(
                          children: [
                            Icon(Icons.chat_outlined),
                            SizedBox(width: AppSpacing.spacing8),
                            Text(l10n.friendSendMessage),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_remove_outlined,
                              color: Colors.red,
                            ),
                            SizedBox(width: AppSpacing.spacing8),
                            Text(
                              l10n.friendRemoveTitle,
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatarContent;
    if (friend.photoUrl != null && friend.photoUrl!.isNotEmpty) {
      avatarContent = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: friend.photoUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholderAvatar(),
          errorWidget: (context, url, error) => _buildPlaceholderAvatar(),
        ),
      );
    } else {
      avatarContent = _buildPlaceholderAvatar();
    }

    return Stack(
      children: [
        avatarContent,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Or dynamic helper
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: OnlineStatusIndicator(
              userId: friend.id,
              showText: false,
              dotSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: Text(
        friend.displayName.isNotEmpty
            ? friend.displayName[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  void _showRemoveFriendDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.friendRemoveTitle),
            content: Text(
              'Voulez-vous vraiment retirer ${friend.displayName} de vos amis ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.undo),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await ref
                      .read(friendRequestNotifierProvider.notifier)
                      .removeFriend(friend.id);
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.friendRemoved)));
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.friendRemoveAction),
              ),
            ],
          ),
    );
  }
}
