import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/messages/presentation/providers/message_provider.dart';
import '../../../../features/messages/presentation/providers/media_gallery_provider.dart';
import '../../../../features/messages/presentation/widgets/media_gallery_grid.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/reports/domain/entities/report_entity.dart';
import '../../../../features/reports/presentation/widgets/report_content_modal.dart';
import '../../../../features/groups/domain/entities/group_entity.dart';
import '../../../../features/groups/domain/entities/group_request_entity.dart';
import 'package:intl/intl.dart';
import '../../../../features/groups/presentation/providers/group_provider.dart';
import '../../../../features/events/presentation/providers/group_next_event_provider.dart';
import '../../../../features/groups/presentation/widgets/share_group_modal.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../kit/design_kit.dart';

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

    // Use stream for real-time updates
    final groupStream = ref.watch(groupStreamProvider(widget.groupId));
    final detailState = ref.watch(groupDetailNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    final group = groupStream.when(
      data: (streamGroup) => widget.initialGroup ?? streamGroup ?? detailState.valueOrNull,
      loading: () => widget.initialGroup ?? detailState.valueOrNull,
      error: (_, __) => widget.initialGroup ?? detailState.valueOrNull,
    );

    if (group == null) {
      // Le stream realtime ne remonte jamais d'erreur explicite (RLS refusé =
      // simplement 0 ligne pour toujours) : on se fie donc à l'appel one-shot
      // getGroupById du notifier pour détecter un échec réel (groupe supprimé,
      // accès refusé, réseau) plutôt que de spinner indéfiniment sans jamais
      // le signaler à l'utilisateur.
      if (detailState.hasError) {
        return Scaffold(
          backgroundColor: context.backgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const AppIcon(AppIcon.arrowBack),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcon.error,
                    size: 48,
                    color: context.textSecondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingError,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textPrimaryColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(groupDetailNotifierProvider.notifier)
                        .loadGroup(widget.groupId),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const AppIcon(AppIcon.arrowBack),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
      );
    }

    final isMember = group.memberIds.contains(currentUser?.id);
    final isCreator = group.creatorId == currentUser?.id;
    final isAdmin = group.adminIds.contains(currentUser?.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Check if we can pop
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          // Deep linked - navigate to home instead
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: CustomScrollView(
          slivers: [
            // App Bar avec image
            SliverAppBar(
              pinned: true,
              backgroundColor: context.backgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: AppIcon(
                  AppIcon.arrowBack,
                  color: context.textPrimaryColor,
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                if (isAdmin) ...[
                  Consumer(
                    builder: (context, ref, child) {
                      final requestsAsync = ref.watch(
                        groupPendingRequestsProvider(group.id),
                      );
                      final count = requestsAsync.valueOrNull?.length ?? 0;

                      if (count == 0 && !isCreator) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        icon: Badge(
                          label: Text('$count'),
                          isLabelVisible: count > 0,
                          child: Icon(
                            Icons.notifications_active,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        onPressed: () {
                          context.push('/groups/${group.id}/requests');
                        },
                      );
                    },
                  ),
                ],
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
                    child: AppIcon(AppIcon.share, color: context.textPrimaryColor),
                  ),
                  onPressed: () => _shareGroup(group),
                ),
                // Report button (only for non-admin/non-creator members)
                if (!isCreator && !isAdmin)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        AppIcon.flag,
                        color: Colors.orange,
                      ),
                    ),
                    onPressed: () => ReportContentModal.show(
                      context,
                      targetType: ReportTargetType.group,
                      targetId: group.id,
                      targetName: group.name,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),

            // Contenu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identité du groupe (§9d) : pastille verte, titre serif,
                    // puis une seule ligne qui dit l'essentiel — accès et
                    // catégorie.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: context.adaptiveSecondaryColor,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              group.imageUrl != null
                                  ? Image.network(
                                    group.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const Center(
                                          child: AppIcon(
                                            AppIcon.groups,
                                            size: 26,
                                            color: Colors.white,
                                          ),
                                        ),
                                  )
                                  : const Center(
                                    child: AppIcon(
                                      AppIcon.groups,
                                      size: 26,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DesignTitle(group.name, size: 23),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    group.isPrivate
                                        ? Icons.lock_outline_rounded
                                        : Icons.public,
                                    size: 13,
                                    color: context.textTertiaryColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      [
                                        group.isPrivate
                                            ? l10n.private
                                            : l10n.public,
                                        group.category.label,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.textTertiaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                        borderRadius: BorderRadius.circular(kDesignRadius),
                        border: Border.all(color: context.borderColor),
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
                          AppIcon(
                            AppIcon.location,
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

                    // Prochaine rencontre (§9d)
                    _buildNextEventSection(context, group),

                    // Médias partagés (avant les membres)
                    if (isMember) _buildMediaSection(group),

                    if (isMember) const SizedBox(height: 24),

                    // Membres du groupe
                    _buildMembersSection(context, group, l10n),

                    const SizedBox(height: 24),

                    // Créateur
                    if (group.creatorName != null)
                      Row(
                        children: [
                          AppIcon(
                            AppIcon.person,
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
            boxShadow:
                context.isDarkMode
                    ? null
                    : [
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
                        child: Builder(
                          builder: (context) {
                            // Le créateur peut quitter s'il y a d'autres admins
                            final otherAdmins = group.adminIds
                                .where((id) => id != currentUser?.id)
                                .toList();
                            final canCreatorLeave = isCreator && otherAdmins.isNotEmpty;
                            final canLeave = !isCreator || canCreatorLeave;

                            return OutlinedButton.icon(
                              onPressed: canLeave ? () => _leaveGroup(group.id) : null,
                              icon: canLeave
                                  ? Icon(
                                      Icons.exit_to_app,
                                      color: Colors.red,
                                    )
                                  : AppIcon(
                                      AppIcon.star,
                                      color: context.adaptivePrimaryColor,
                                    ),
                              label: Text(
                                canLeave ? l10n.leaveGroup : l10n.creator,
                                style: TextStyle(
                                  color: canLeave ? Colors.red : context.adaptivePrimaryColor,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: canLeave ? Colors.red : context.adaptivePrimaryColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startGroupConversation(group),
                          icon: const AppIcon(AppIcon.chatBubble),
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
                  : Consumer(
                    builder: (context, ref, child) {
                      if (!group.isPrivate) {
                        return SizedBox(
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
                        );
                      }

                      // For private groups, check pending requests
                      final currentUser =
                          ref.watch(currentUserProvider).valueOrNull;
                      if (currentUser == null) return const SizedBox.shrink();

                      final myRequestsAsync = ref.watch(
                        myGroupRequestsProvider(currentUser.id),
                      );

                      final myRequests = myRequestsAsync.valueOrNull ?? [];
                      final hasPendingRequest = myRequests.any(
                        (r) =>
                            r.groupId == group.id &&
                            r.status == GroupRequestStatus.pending,
                      );

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              hasPendingRequest
                                  ? null // Disable if pending
                                  : () => _requestToJoin(group),
                          icon: Icon(
                            hasPendingRequest
                                ? Icons.hourglass_empty
                                : Icons.person_add,
                          ),
                          label: Text(
                            hasPendingRequest
                                ? l10n.requestPending
                                : l10n.requestToJoin,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.adaptivePrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      );
                    },
                  ),
        ), // Close bottomNavigationBar (Container)
      ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }

  Future<void> _requestToJoin(GroupEntity group) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.requestToJoinGroup(
        groupId: group.id,
        groupName: group.name,
        groupImageUrl: group.imageUrl,
        requesterId: currentUser.id,
        requesterName: currentUser.displayName ?? 'Utilisateur',
        requesterPhotoUrl: currentUser.photoUrl,
      );

      if (mounted) {
        result.fold(
          (failure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.requestSent)),
            );
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(groupDetailNotifierProvider.notifier)
        .joinGroup(groupId, currentUser.id);

    if (success) {
      AnalyticsService.instance.logEvent(
        name: 'join_group',
        parameters: {'group_id': groupId},
      );
    }

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
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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

    if (success) {
      AnalyticsService.instance.logEvent(
        name: 'leave_group',
        parameters: {'group_id': groupId},
      );
    }

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
          groupId: group.id, // Pass the group ID
        );

    setState(() => _isLoading = false);

    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': group.name,
          'imageUrl': group.imageUrl,
          'isGroup': true,
          'groupId': group.id, // Pass the actual group ID
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
    AnalyticsService.instance.logEvent(
      name: 'share_group',
      parameters: {'group_id': group.id},
    );
    ShareGroupDialog.show(
      context,
      groupName: group.name,
      groupImageUrl: group.imageUrl,
      groupId: group.id,
      category: group.category,
    );
  }

  /// Prochaine rencontre (§9d) : carte du prochain événement lié au groupe.
  /// Masquée s'il n'y en a pas (pas de bloc vide).
  Widget _buildNextEventSection(BuildContext context, GroupEntity group) {
    return Consumer(
      builder: (context, ref, _) {
        final eventAsync = ref.watch(groupNextEventProvider(group.id));
        final event = eventAsync.valueOrNull;
        if (event == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: InkWell(
            onTap: () =>
                context.push('/events/${event.id}', extra: event),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.adaptivePrimaryColor.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  // Pastille de date
                  Container(
                    width: 48,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(event.startDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM', 'fr_FR')
                              .format(event.startDate)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prochaine rencontre',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.isOnline ? 'En ligne' : event.location} · ${DateFormat('HH:mm').format(event.startDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.textTertiaryColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    GroupEntity group,
    AppLocalizations l10n,
  ) {
    // Filtrer pour obtenir les membres autres que le créateur
    final otherMemberIds =
        group.memberIds.where((id) => id != group.creatorId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.membersLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${group.memberIds.length}',
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Toujours afficher le créateur en premier
              _MemberListItem(
                memberId: group.creatorId,
                isAdmin: group.adminIds.contains(group.creatorId),
                isModerator: group.isModerator(group.creatorId),
                isCreator: true,
                onTap: () => context.push('/profile/${group.creatorId}'),
              ),
              // Afficher les autres membres ou un message s'il n'y en a pas
              if (otherMemberIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_add,
                        size: 20,
                        color: context.textTertiaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.noOtherMembers,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...otherMemberIds.take(4).map((memberId) {
                  return _MemberListItem(
                    memberId: memberId,
                    isAdmin: group.adminIds.contains(memberId),
                    isModerator: group.isModerator(memberId),
                    isCreator: false,
                    onTap: () => context.push('/profile/$memberId'),
                  );
                }),
            ],
          ),
        ),
        if (group.memberIds.length > 5) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                context.push('/groups/${group.id}/members', extra: group);
              },
              child: Text(
                l10n.groupSeeAllMembers(group.memberIds.length),
                style: TextStyle(color: context.adaptivePrimaryColor),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaSection(GroupEntity group) {
    return Consumer(
      builder: (context, ref, child) {
        final conversationIdAsync = ref.watch(
          groupConversationIdProvider(group.id),
        );

        return conversationIdAsync.when(
          data: (conversationId) {
            if (conversationId == null) {
              return const SizedBox.shrink();
            }

            return MediaGalleryCompact(
              conversationId: conversationId,
              onViewAll: () {
                context.push('/messages/$conversationId/media');
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _MemberListItem extends ConsumerWidget {
  final String memberId;
  final bool isAdmin;
  final bool isModerator;
  final bool isCreator;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.memberId,
    required this.isAdmin,
    this.isModerator = false,
    required this.isCreator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userStreamProvider(memberId));

    return profileAsync.when(
      data: (profile) {
        // Afficher un placeholder si le profil n'est pas trouvé
        final displayName = profile?.displayName ?? 'Membre';
        final photoUrl = profile?.photoUrl;
        final profession = profile?.profession;

        return ListTile(
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                photoUrl != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
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
                  displayName,
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
                    'Admin',
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
              profession != null
                  ? Text(
                    profession,
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
        );
      },
      loading:
          () => ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            title: Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      error: (_, __) => const SizedBox.shrink(),
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
