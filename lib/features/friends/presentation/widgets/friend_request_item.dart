import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../providers/friend_provider.dart';

class FriendRequestItem extends ConsumerWidget {
  final FriendRequestEntity request;
  final bool isReceived;

  const FriendRequestItem({
    super.key,
    required this.request,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(friendRequestNotifierProvider.notifier);
    final isLoading = ref.watch(friendRequestNotifierProvider).isLoading;

    final displayName = isReceived ? request.senderName : request.receiverName;
    final photoUrl =
        isReceived ? request.senderPhotoUrl : request.receiverPhotoUrl;
    final userId = isReceived ? request.senderId : request.receiverId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        side: BorderSide(color: context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        child: Column(
          children: [
            InkWell(
              onTap: () => context.push('/profile/$userId'),
              child: Row(
                children: [
                  _buildAvatar(context, photoUrl, displayName),
                  const SizedBox(width: AppSpacing.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (request.createdAt != null)
                          Text(
                            _formatDate(request.createdAt!),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.textSecondaryColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spacing16),
            if (isReceived)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                final success = await notifier.declineRequest(
                                  request.id,
                                  senderId: request.senderId,
                                );
                                if (context.mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Demande refusée'),
                                    ),
                                  );
                                }
                              },
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacing8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                final success = await notifier.acceptRequest(
                                  request.id,
                                  senderId: request.senderId,
                                );
                                if (context.mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Demande acceptée'),
                                    ),
                                  );
                                }
                              },
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final success = await notifier.cancelRequest(
                              request.id,
                              receiverId: request.receiverId,
                            );
                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Demande annulée'),
                                ),
                              );
                            }
                          },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Annuler la demande'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    String? photoUrl,
    String displayName,
  ) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => _buildPlaceholderAvatar(context, displayName),
          errorWidget:
              (context, url, error) =>
                  _buildPlaceholderAvatar(context, displayName),
        ),
      );
    }
    return _buildPlaceholderAvatar(context, displayName);
  }

  Widget _buildPlaceholderAvatar(BuildContext context, String displayName) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.1),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.adaptivePrimaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}
