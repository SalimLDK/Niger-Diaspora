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
import 'package:diaspo_niger/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final groupAsync = ref.watch(groupDetailNotifierProvider);
    final groupEntity = group ?? groupAsync.valueOrNull;
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          groupEntity?.name ?? l10n.membersLabel,
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
                    group: groupEntity,
                    memberId: memberId,
                    isAdmin: groupEntity.adminIds.contains(memberId),
                    isModerator: groupEntity.moderatorIds.contains(memberId),
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
  final GroupEntity group;
  final String memberId;
  final bool isAdmin;
  final bool isModerator;
  final bool isCreator;
  final String? conversationId;
  final String? currentUserId;
  final bool canModerate;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.group,
    required this.memberId,
    required this.isAdmin,
    required this.isModerator,
    required this.isCreator,
    required this.conversationId,
    required this.currentUserId,
    required this.canModerate,
    required this.onTap,
  });

  /// Bascule le rôle modérateur (§9d) via updateGroup (persiste
  /// groups.moderator_ids). Invalide la fiche pour rafraîchir le badge.
  Future<void> _toggleModerator(BuildContext context, WidgetRef ref) async {
    final updated = List<String>.from(group.moderatorIds);
    if (isModerator) {
      updated.remove(memberId);
    } else {
      updated.add(memberId);
    }
    final success = await ref
        .read(myGroupsNotifierProvider.notifier)
        .updateGroup(group.copyWith(moderatorIds: updated));
    if (success) ref.invalidate(groupDetailNotifierProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isModerator ? 'Modérateur retiré' : 'Membre promu modérateur')
                : 'Erreur lors de la mise à jour du rôle',
          ),
        ),
      );
    }
  }

  void _showMemberOptions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (!canModerate || currentUserId == memberId) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rôle modérateur (§9d) — indépendant de la conversation.
                if (!isCreator && !isAdmin)
                  ListTile(
                    leading: Icon(
                      isModerator
                          ? Icons.remove_moderator_outlined
                          : Icons.shield_outlined,
                    ),
                    title: Text(
                      isModerator
                          ? 'Retirer modérateur'
                          : 'Promouvoir modérateur',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleModerator(context, ref);
                    },
                  ),
                if (conversationId != null && !isAdmin && !isCreator)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: Text(l10n.groupPromoteAdmin),
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
                                  ? l10n.memberPromotedAdmin
                                  : l10n.promoteError,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (conversationId != null && isAdmin && !isCreator)
                  ListTile(
                    leading: const Icon(Icons.remove_moderator),
                    title: Text(l10n.groupDemoteAdmin),
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
                                  ? l10n.memberDemotedAdmin
                                  : l10n.demoteError,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (conversationId != null && !isCreator)
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: Text(
                      l10n.removeFromGroup,
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text(l10n.groupConfirmTitle),
                              content: Text(
                                l10n.confirmRemoveMember,
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: Text(l10n.undo),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    l10n.remove,
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
                                    ? l10n.memberRemovedFromGroup
                                    : l10n.removalError,
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
    final l10n = AppLocalizations.of(context)!;
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
                canModerate ? () => _showMemberOptions(context, ref) : null,
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
                    profile.displayName ?? l10n.member,
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
                    child: Text(
                      l10n.creator,
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
                      l10n.adminRoleLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.adaptiveSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isModerator) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A8A5E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.groupRoleModerator,
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5A6B45),
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
