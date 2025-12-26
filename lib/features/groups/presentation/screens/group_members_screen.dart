import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/messages/presentation/providers/conversation_actions_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';

class GroupMembersScreen extends ConsumerWidget {
  final String groupId;
  final GroupEntity? group;
  final String? conversationId;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    this.group,
    this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailNotifierProvider);
    final groupEntity = group ?? groupAsync.valueOrNull;
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          groupEntity?.name ?? 'Membres',
          style: TextStyle(color: context.textPrimaryColor),
        ),
        backgroundColor: context.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body:
          groupEntity == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupEntity.memberIds.length,
                itemBuilder: (context, index) {
                  final memberId = groupEntity.memberIds[index];
                  final isCurrentUserAdmin =
                      currentUser != null &&
                      groupEntity.adminIds.contains(currentUser.id);
                  return _MemberListItem(
                    memberId: memberId,
                    isAdmin: groupEntity.adminIds.contains(memberId),
                    isCreator: groupEntity.creatorId == memberId,
                    conversationId: conversationId,
                    currentUserId: currentUser?.id,
                    canModerate: isCurrentUserAdmin,
                    onTap: () => context.push('/profile/$memberId'),
                  );
                },
              ),
    );
  }
}

class _MemberListItem extends ConsumerWidget {
  final String memberId;
  final bool isAdmin;
  final bool isCreator;
  final String? conversationId;
  final String? currentUserId;
  final bool canModerate;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.memberId,
    required this.isAdmin,
    required this.isCreator,
    required this.conversationId,
    required this.currentUserId,
    required this.canModerate,
    required this.onTap,
  });

  void _showMemberOptions(BuildContext context, WidgetRef ref) {
    if (!canModerate || conversationId == null || currentUserId == memberId) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAdmin && !isCreator)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Promouvoir Admin'),
                    onTap: () async {
                      Navigator.pop(context);
                      final success = await ref
                          .read(conversationActionsNotifierProvider.notifier)
                          .promoteToAdmin(
                            conversationId: conversationId!,
                            userId: memberId,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Membre promu admin'
                                  : 'Erreur lors de la promotion',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (isAdmin && !isCreator)
                  ListTile(
                    leading: const Icon(Icons.remove_moderator),
                    title: const Text('Retirer Admin'),
                    onTap: () async {
                      Navigator.pop(context);
                      final success = await ref
                          .read(conversationActionsNotifierProvider.notifier)
                          .demoteFromAdmin(
                            conversationId: conversationId!,
                            userId: memberId,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Admin rétrogradé'
                                  : 'Erreur lors de la rétrogradation',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (!isCreator)
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: const Text(
                      'Retirer du groupe',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Confirmer'),
                              content: const Text(
                                'Voulez-vous vraiment retirer ce membre du groupe ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Retirer',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true && context.mounted) {
                        final success = await ref
                            .read(conversationActionsNotifierProvider.notifier)
                            .removeUserFromGroup(
                              conversationId: conversationId!,
                              userId: memberId,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Membre retiré du groupe'
                                    : 'Erreur lors de la suppression',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userStreamProvider(memberId));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          color: context.surfaceColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.borderColor.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            onTap: onTap,
            onLongPress:
                canModerate && conversationId != null
                    ? () => _showMemberOptions(context, ref)
                    : null,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  profile.photoUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: profile.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Icon(
                                Icons.person,
                                color: context.adaptivePrimaryColor,
                              ),
                          errorWidget:
                              (_, __, ___) => Icon(
                                Icons.person,
                                color: context.adaptivePrimaryColor,
                              ),
                        ),
                      )
                      : Icon(Icons.person, color: context.adaptivePrimaryColor),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    profile.displayName ?? 'Membre',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCreator) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Créateur',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptiveSecondaryColor.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.adaptiveSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle:
                profile.profession != null
                    ? Text(
                      profile.profession!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                    : null,
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.textTertiaryColor,
            ),
          ),
        );
      },
      loading:
          () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
