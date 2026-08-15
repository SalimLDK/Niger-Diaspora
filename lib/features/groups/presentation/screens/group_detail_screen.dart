import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/presentation/providers/conversation_actions_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../messages/presentation/providers/media_gallery_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_content_modal.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_request_entity.dart';
import 'package:intl/intl.dart';
import '../providers/group_provider.dart';
// Fonctionnalité épingle mise en pause (2026-08-14) : la ligne « Épinglés »
// de cette fiche est commentée plus bas (`_GroupInfoCard.build` et
// `_pinnedSummary`), ces deux imports n'ont donc plus d'usage vivant ici.
// import '../providers/group_pinned_providers.dart';
// import '../../domain/entities/group_pinned_item_entity.dart';
import '../../../events/presentation/providers/group_next_event_provider.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../widgets/share_group_modal.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/widgets/app_icon.dart';

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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
    // Un superAdmin plateforme gère tout groupe officiel sans détenir de ligne
    // group_members owner/admin (cf. migration 20260813234500 côté RLS) — sans
    // ce repli, l'UI cache le menu même quand l'écriture serait acceptée.
    final isAdmin =
        group.adminIds.contains(currentUser?.id) ||
        (group.isOfficial && (currentUser?.isAdmin ?? false));

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
              // Fiche 9d : l'en-tete ne porte que le partage et un menu ⋮.
              // Elle alignait jusqu'a quatre pastilles muettes (demandes,
              // modifier, partage, signaler) ; tout ce qui n'est pas le
              // partage passe dans le menu, ou chaque entree est nommee.
              actions: [
                IconButton(
                  icon: AppIcon(
                    AppIcon.share,
                    color: context.textPrimaryColor,
                  ),
                  tooltip: l10n.share,
                  onPressed: () => _shareGroup(group),
                ),
                _GroupOverflowMenu(
                  group: group,
                  isCreator: isCreator,
                  isAdmin: isAdmin,
                  onLeave: () => _leaveGroup(group.id),
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
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            // Vert de groupe de la fiche 9d/9e (#06871D) :
                            // c'est la couleur qui identifie « groupe » dans
                            // toute la messagerie, pas l'accent du compte.
                            color: context.successColor,
                            borderRadius: BorderRadius.circular(22),
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
                              // Nom nu : la fiche 9d ecrit « Diaspora
                              // Montreal » sans le point d'accent de
                              // `DesignTitle`. Ce point signe les titres
                              // d'ecran, pas un nom saisi par l'utilisateur.
                              Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    group.isPrivate
                                        ? Icons.lock_outline_rounded
                                        : Icons.public,
                                    size: 13,
                                    color: context.textTertiaryColor,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      // Fiche 9d : « Privé · Montréal ·
                                      // depuis 2023 ». La catégorie sort de
                                      // cette ligne — elle dit moins que le
                                      // lieu et l'ancienneté du groupe.
                                      [
                                        group.isPrivate
                                            ? l10n.private
                                            : l10n.public,
                                        if ((group.location ?? '').isNotEmpty)
                                          group.location!,
                                        if (group.createdAt != null)
                                          'depuis ${group.createdAt!.toLocal().year}',
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

                    const SizedBox(height: 14),

                    // Description en clair (fiche 9d) : ni intertitre « À
                    // propos » ni carte — le texte se lit directement sous
                    // l'identité. Le bloc de stats a disparu : la ligne de
                    // méta dit déjà l'accès, et la section Membres le compte.
                    if (group.description.trim().isNotEmpty)
                      Text(
                        group.description,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: context.textPrimaryColor,
                        ),
                      ),

                    if (isMember) ...[
                      const SizedBox(height: 14),
                      _GroupActionRow(
                        group: group,
                        onOpenDiscussion: () => _startGroupConversation(group),
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
                    // Carte info groupee de la fiche 9d : Epingles, Medias et
                    // fichiers, Prochaine rencontre sous une seule bordure.
                    _GroupInfoCard(group: group, isMember: isMember),

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
                  // Fiche 9d : aucune barre de bas de page pour un membre.
                  // « Ouvrir la discussion » vit dans le contenu et la sortie
                  // du groupe est passee dans le menu ⋮, ou elle est nommee.
                  ? const SizedBox.shrink()
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

  // `_requestToJoin`, `_joinGroup` et `_leaveGroup` attendent la PREMIÈRE
  // ÉMISSION de `currentUserAsyncProvider` (`await …future`). Cet écran ne
  // regarde que `currentUserProvider` — un provider DIFFÉRENT — donc un
  // `read(currentUserAsyncProvider).valueOrNull` démarrait l'abonnement au
  // moment du tap et rendait `null` : les trois méthodes sortaient sur un
  // `return` nu, boutons morts sans message ni trace. C'est le même défaut qui
  // rendait « Ouvrir la discussion » inopérant (cf. `createGroup` de
  // `message_provider.dart`), vérifié sur appareil le 2026-08-05.
  Future<void> _requestToJoin(GroupEntity group) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.requestToJoinGroup(
        groupId: group.id,
        groupName: group.name,
        groupImageUrl: group.imageUrl,
        requesterId: currentUser.id,
        requesterName: currentUser.displayName ?? l10n.user,
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
    final currentUser = await ref.read(currentUserAsyncProvider.future);
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
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;
    // L'attente ci-dessus est un saut asynchrone : l'écran peut avoir été
    // démonté entre-temps, et `context` ne serait plus utilisable.
    if (!mounted) return;

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
      // Le dépôt remonte bien la cause de l'échec ; le notifier la range dans
      // son état et l'écran ne montrait qu'un message générique. On dit ce qui
      // s'est réellement passé, sinon l'utilisateur n'a rien à rapporter et
      // nous rien à chercher.
      final error = ref.read(createConversationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? l10n.errorOpeningDiscussion
                : '${l10n.errorOpeningDiscussion} — $error',
          ),
          duration: const Duration(seconds: 8),
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
            Expanded(
              child: Text(
                '${l10n.membersLabel} · ${group.memberIds.length}',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  () => context.push(
                    '/groups/${group.id}/members',
                    extra: group,
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Tout voir',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),
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
                // Sur un groupe officiel, `creator_id` pointe vers un compte
                // perso (contrainte de la base) : sans ce repli, la ligne
                // affichait son profil — nom et profession — au lieu de
                // l'identité déjà montrée juste en dessous (« Créé par
                // Diaspo Niger »).
                officialCreatorName:
                    group.isOfficial ? group.creatorName : null,
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

}

class _MemberListItem extends ConsumerWidget {
  final String memberId;
  final bool isAdmin;
  final bool isModerator;
  final bool isCreator;
  final VoidCallback onTap;
  // Non nul seulement pour la ligne du créateur d'un groupe OFFICIEL :
  // `creator_id` y pointe vers un compte perso (contrainte de la base), donc
  // sans ce repli la ligne affichait ce profil perso au lieu de l'identité
  // affichée partout ailleurs sur la fiche.
  final String? officialCreatorName;

  const _MemberListItem({
    required this.memberId,
    required this.isAdmin,
    this.isModerator = false,
    required this.isCreator,
    this.officialCreatorName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userStreamProvider(memberId));

    return profileAsync.when(
      data: (profile) {
        // Afficher un placeholder si le profil n'est pas trouvé
        final displayName =
            officialCreatorName ?? profile?.displayName ?? l10n.member;
        final photoUrl = officialCreatorName != null ? null : profile?.photoUrl;
        final profession = officialCreatorName != null ? null : profile?.profession;

        // Le nom affiché est celui de la plateforme, mais `memberId` reste le
        // compte perso réel derrière `creator_id` : un tap menait à SA fiche
        // profil (nom, profession, photo réels), donnant accès à ce que la
        // ligne prétend justement ne pas montrer. La ligne créateur
        // officielle n'est donc pas cliquable.
        final isOfficialCreator = officialCreatorName != null;

        return ListTile(
          onTap: isOfficialCreator ? null : onTap,
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
          trailing:
              isOfficialCreator
                  ? null
                  : Icon(
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

/// Barre d'action de la fiche 9d : « Ouvrir la discussion » pleine largeur au
/// vert de groupe, et la coupure des notifications à côté.
///
/// Le bouton mute n'apparaît que si la conversation du groupe existe déjà :
/// l'état muet vit sur la conversation (`mutedBy`), pas sur le groupe, et la
/// créer juste pour afficher une cloche serait un effet de bord invisible.
class _GroupActionRow extends ConsumerWidget {
  final GroupEntity group;
  final VoidCallback onOpenDiscussion;

  const _GroupActionRow({required this.group, required this.onOpenDiscussion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final me = ref.watch(currentUserProvider).valueOrNull?.id;
    final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
    final conversation =
        conversations.where((c) => c.groupId == group.id).firstOrNull;
    final isMuted =
        me != null &&
        conversation != null &&
        conversation.mutedBy.containsKey(me);

    return Row(
      children: [
        Expanded(
          // Hauteur **minimale** et non figée : à 44 px fixes, le libellé se
          // faisait rogner par le bas dès que l'appareil dépasse font_scale 1
          // (constaté à 1.1 sur le SM A515F). Le bouton grandit désormais avec
          // le texte.
          child: ElevatedButton(
            onPressed: onOpenDiscussion,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.successColor,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'Ouvrir la discussion',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (conversation != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message:
                isMuted
                    ? l10n.unmute
                    : 'Couper les notifications',
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () async {
                await ref
                    .read(conversationActionsNotifierProvider.notifier)
                    .muteConversation(conversation.id, !isMuted);
                ref.invalidate(conversationsProvider);
              },
              child: Container(
                width: 46,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: context.borderColor),
                ),
                child: Icon(
                  isMuted
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_outlined,
                  size: 20,
                  color:
                      isMuted
                          ? context.adaptivePrimaryColor
                          : context.textSecondaryColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


/// Menu ⋮ de la fiche 9d. Rassemble ce que l'en-tête alignait en pastilles
/// muettes — demandes d'adhésion, édition, signalement — plus la sortie du
/// groupe, que la fiche ne met pas en barre de bas de page.
///
/// Chaque entrée est nommée : une icône seule ne dit pas si elle édite,
/// signale ou fait sortir.
class _GroupOverflowMenu extends ConsumerWidget {
  final GroupEntity group;
  final bool isCreator;
  final bool isAdmin;
  final VoidCallback onLeave;

  const _GroupOverflowMenu({
    required this.group,
    required this.isCreator,
    required this.isAdmin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pendingCount = isAdmin
        ? (ref.watch(groupPendingRequestsProvider(group.id)).valueOrNull?.length ??
            0)
        : 0;

    // Le créateur ne peut partir que s'il reste un autre administrateur :
    // sinon le groupe se retrouverait sans personne pour l'administrer.
    final me = ref.watch(currentUserProvider).valueOrNull?.id;
    final otherAdmins = group.adminIds.where((id) => id != me).toList();
    final canLeave = !isCreator || otherAdmins.isNotEmpty;

    return PopupMenuButton<String>(
      icon: Badge(
        label: Text('$pendingCount'),
        isLabelVisible: pendingCount > 0,
        child: Icon(Icons.more_vert, color: context.textPrimaryColor),
      ),
      onSelected: (value) {
        switch (value) {
          case 'requests':
            context.push('/groups/${group.id}/requests');
          case 'edit':
            context.push('/groups/${group.id}/edit', extra: group);
          case 'report':
            ReportContentModal.show(
              context,
              targetType: ReportTargetType.group,
              targetId: group.id,
              targetName: group.name,
            );
          case 'leave':
            onLeave();
        }
      },
      itemBuilder: (_) => [
        if (isAdmin)
          PopupMenuItem(
            value: 'requests',
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_outlined, size: 18),
                const SizedBox(width: 10),
                Text(
                  pendingCount > 0
                      ? "Demandes d'adhésion · $pendingCount"
                      : "Demandes d'adhésion",
                ),
              ],
            ),
          ),
        if (isCreator || isAdmin)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 10),
                Text(l10n.edit),
              ],
            ),
          ),
        if (!isCreator && !isAdmin)
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                const AppIcon(AppIcon.flag, size: 18),
                const SizedBox(width: 10),
                Text(l10n.report),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'leave',
          enabled: canLeave,
          child: Row(
            children: [
              Icon(
                Icons.exit_to_app,
                size: 18,
                color: canLeave ? Colors.red : context.textTertiaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // Désactivée, l'entrée dit ce qui manque pour partir —
                  // pas le rôle qu'on occupe.
                  canLeave
                      ? l10n.leaveGroup
                      : 'Nommez un autre administrateur pour partir',
                  style: TextStyle(
                    color: canLeave ? Colors.red : context.textTertiaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte info groupée de la fiche 9d : Épinglés, Médias et fichiers,
/// Prochaine rencontre sous une seule bordure.
///
/// Chaque ligne s'efface si elle n'a rien à dire, et la carte entière
/// disparaît si les trois sont vides — un groupe neuf n'a ni épinglé, ni
/// média, ni rencontre, et trois lignes à zéro ne valent pas mieux que rien.
class _GroupInfoCard extends ConsumerWidget {
  final GroupEntity group;
  final bool isMember;

  const _GroupInfoCard({required this.group, required this.isMember});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final event = ref.watch(groupNextEventProvider(group.id)).valueOrNull;

    // Les médias et les épingles vivent sur la conversation du groupe, qui
    // n'existe qu'à partir du premier message.
    final conversationId =
        isMember
            ? ref.watch(groupConversationIdProvider(group.id)).valueOrNull
            : null;
    final media =
        conversationId == null
            ? null
            : ref.watch(conversationMediaProvider(conversationId));
    // Fonctionnalité épingle mise en pause (2026-08-14) : la ligne « Épinglés »
    // ne s'affiche plus dans cette carte. Les épingles restent en base ; voir
    // aussi `canPin` dans conversation_screen.dart et
    // group_pinned_banner.dart pour le reste de la pause.
    //
    // Les épingles sont toujours indexées par `conversation_id`, groupe
    // compris (voir `_pinMessage` dans `conversation_screen.dart`) : lire ici
    // par `group_id` (ex-`groupPinnedItemsProvider`) rendait cette ligne
    // définitivement vide, même quand des messages étaient bien épinglés
    // dans le fil du groupe.
    // final pinned =
    //     conversationId == null
    //         ? const <GroupPinnedItemEntity>[]
    //         : ref
    //                 .watch(conversationPinnedItemsProvider(conversationId))
    //                 .valueOrNull ??
    //             const <GroupPinnedItemEntity>[];

    final rows = <Widget>[
      // if (pinned.isNotEmpty)
      //   _InfoRow(
      //     icon: AppIcon(
      //       AppIcon.pinnedMessage,
      //       size: 18,
      //       color: context.adaptivePrimaryColor,
      //     ),
      //     title: 'Épinglés',
      //     subtitle: _pinnedSummary(pinned),
      //     trailing: Text(
      //       '${pinned.length}',
      //       style: TextStyle(
      //         fontFamily: 'monospace',
      //         fontSize: 12.5,
      //         fontWeight: FontWeight.w600,
      //         color: context.textSecondaryColor,
      //       ),
      //     ),
      //     onTap: null,
      //   ),
      if (media != null && !media.isEmpty)
        _InfoRow(
          icon: Icon(
            Icons.image_outlined,
            size: 18,
            color: context.textSecondaryColor,
          ),
          title: l10n.groupMediaAndFiles,
          subtitle: _mediaSummary(media),
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: context.textTertiaryColor,
          ),
          onTap:
              () => context.push(
                '/messages/$conversationId/media',
                extra: {'name': group.name},
              ),
        ),
      if (event != null)
        _InfoRow(
          icon: Icon(
            Icons.event_outlined,
            size: 18,
            color: context.successColor,
          ),
          title: 'Prochaine rencontre',
          subtitle: _eventSummary(event),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "J'y vais",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          onTap: () => context.push('/events/${event.id}', extra: event),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.borderColor),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  // Fonctionnalité épingle mise en pause (2026-08-14) : plus aucun appelant
  // (voir `rows` ci-dessus). Gardé en commentaire pour réactivation.
  // /// « 1 sondage · 2 messages » — décrit les épinglés par type. Leur libellé
  // /// réel demanderait une requête par élément (l'entité ne porte qu'un id).
  // static String _pinnedSummary(List<GroupPinnedItemEntity> items) {
  //   final counts = <GroupPinnedItemType, int>{};
  //   for (final item in items) {
  //     counts[item.itemType] = (counts[item.itemType] ?? 0) + 1;
  //   }
  //   const labels = {
  //     GroupPinnedItemType.event: ['événement', 'événements'],
  //     GroupPinnedItemType.poll: ['sondage', 'sondages'],
  //     GroupPinnedItemType.message: ['message', 'messages'],
  //   };
  //   final parts = <String>[];
  //   for (final type in GroupPinnedItemType.values) {
  //     final n = counts[type];
  //     if (n == null || n == 0) continue;
  //     parts.add('$n ${labels[type]![n > 1 ? 1 : 0]}');
  //   }
  //   return parts.join(' · ');
  // }

  static String _mediaSummary(MediaGalleryState media) {
    final parts = <String>[];
    if (media.images.isNotEmpty) {
      parts.add(
        '${media.images.length} photo${media.images.length > 1 ? 's' : ''}',
      );
    }
    if (media.videos.isNotEmpty) {
      parts.add(
        '${media.videos.length} vidéo${media.videos.length > 1 ? 's' : ''}',
      );
    }
    if (media.files.isNotEmpty) {
      parts.add(
        '${media.files.length} document${media.files.length > 1 ? 's' : ''}',
      );
    }
    return parts.join(' · ');
  }

  static String _eventSummary(EventEntity event) {
    final start = event.startDate.toLocal();
    final day = DateFormat('EEEE d MMMM', 'fr_FR').format(start);
    final time = DateFormat('HH', 'fr_FR').format(start);
    final place = event.location.trim();
    final when = '${day[0].toUpperCase()}${day.substring(1)} · $time h';
    return place.isNotEmpty ? '$when · $place' : when;
  }
}

/// Ligne de la carte info (fiche 9d) : icône 18, titre 13.5/600, sous-ligne
/// 12/400, et un élément de droite qui varie (compteur, chevron, bouton).
class _InfoRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
