import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../widgets/share_group_modal.dart';
import '../../../../core/theme/adaptive_colors.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final GroupEntity? initialGroup;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(groupDetailNotifierProvider.notifier)
            .loadGroup(widget.groupId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final groupAsync = ref.watch(groupDetailNotifierProvider);

    final group = widget.initialGroup ?? groupAsync.valueOrNull;

    if (group == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isMember = group.memberIds.contains(currentUser?.id);
    final isCreator = group.creatorId == currentUser?.id;
    final isAdmin = group.adminIds.contains(currentUser?.id);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar avec image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: context.textPrimaryColor),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isCreator || isAdmin)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.surfaceColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit, color: context.textPrimaryColor),
                  ),
                  onPressed: () {
                    context.push('/groups/${group.id}/edit', extra: group);
                  },
                ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.surfaceColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: context.textPrimaryColor),
                ),
                onPressed: () => _shareGroup(group),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                ),
                child:
                    group.imageUrl != null
                        ? Image.network(
                          group.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.groups,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                        )
                        : const Center(
                          child: Icon(
                            Icons.groups,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom et catégorie
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          group.category.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow:
                          context.isDarkMode
                              ? null
                              : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.people,
                          value: '${group.memberIds.length}',
                          label: l10n.membersLabel,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: context.borderColor,
                        ),
                        _StatItem(
                          icon: Icons.admin_panel_settings,
                          value: '${group.adminIds.length}',
                          label: l10n.admins,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: context.borderColor,
                        ),
                        _StatItem(
                          icon: group.isPrivate ? Icons.lock : Icons.public,
                          value: group.isPrivate ? l10n.private : l10n.public,
                          label: l10n.access,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    l10n.aboutGroup,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      group.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                        height: 1.5,
                      ),
                    ),
                  ),

                  if (group.location != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group.location!,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (group.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          group.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariantColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Créateur
                  if (group.creatorName != null)
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: context.textTertiaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.createdBy(group.creatorName!),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: context.adaptivePrimaryColor,
                  ),
                )
                : isMember
                ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isCreator ? null : () => _leaveGroup(group.id),
                        icon: Icon(
                          isCreator ? Icons.star : Icons.exit_to_app,
                          color:
                              isCreator
                                  ? context.adaptivePrimaryColor
                                  : Colors.red,
                        ),
                        label: Text(
                          isCreator ? l10n.creator : l10n.leaveGroup,
                          style: TextStyle(
                            color:
                                isCreator
                                    ? context.adaptivePrimaryColor
                                    : Colors.red,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color:
                                isCreator
                                    ? context.adaptivePrimaryColor
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _startGroupConversation(group),
                        icon: const Icon(Icons.chat),
                        label: Text(l10n.discussion),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.adaptivePrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                )
                : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _joinGroup(group.id),
                    icon: const Icon(Icons.group_add),
                    label: Text(l10n.joinTheGroup),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
      ),
    );
  }

  Future<void> _joinGroup(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(groupDetailNotifierProvider.notifier)
        .joinGroup(groupId, currentUser.id);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.groupJoined),
          backgroundColor: context.adaptiveSecondaryColor,
        ),
      );
      context.pop();
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.leaveGroupTitle),
            content: Text(l10n.leaveGroupConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.leaveGroup),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(groupDetailNotifierProvider.notifier)
        .leaveGroup(groupId, currentUser.id);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.groupLeft)));
      context.pop();
    }
  }

  Future<void> _startGroupConversation(GroupEntity group) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    // Créer ou récupérer la conversation de groupe
    final conversation = await ref
        .read(createConversationProvider.notifier)
        .createGroup(
          participantIds: group.memberIds,
          groupName: group.name,
          groupImageUrl: group.imageUrl,
        );

    setState(() => _isLoading = false);

    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': group.name,
          'imageUrl': group.imageUrl,
          'isGroup': true,
        },
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorOpeningDiscussion),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareGroup(GroupEntity group) {
    ShareGroupDialog.show(
      context,
      groupName: group.name,
      groupImageUrl: group.imageUrl,
      groupId: group.id,
      category: group.category,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.adaptivePrimaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
        ),
      ],
    );
  }
}
