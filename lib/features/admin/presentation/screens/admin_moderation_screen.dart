import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../providers/admin_provider.dart';

class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() =>
      _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminContentNotifierProvider.notifier).fetchAllContent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminContentNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 24),
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _textSecondary,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Événements (${state.events.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Groupes (${state.groups.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.isLoading
              ? _buildLoadingState()
              : state.error != null
                  ? _buildErrorState(state.error!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEventsList(state.events),
                        _buildGroupsList(state.groups),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modération de Contenu',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gérez les événements et groupes de la communauté',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(adminContentNotifierProvider.notifier).fetchAllContent();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.statusGrayBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            color: _textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList(List<EventEntity> events) {
    if (events.isEmpty) {
      return _buildEmptyState(Icons.event_rounded, 'Aucun événement trouvé');
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(EventEntity event) {
    final statusColor = _getStatusColor(event.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Event info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organisateur: ${event.organizerId}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusBadge(event.status.name.toUpperCase(), statusColor),
                      const SizedBox(width: 8),
                      _buildCategoryBadge(event.category.name),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleEventAction(value, event),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.statusGrayBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert_rounded, color: _textSecondary, size: 20),
              ),
              itemBuilder: (context) => [
                if (event.status != EventStatus.cancelled)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AdminColors.statusAmber.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.cancel_rounded, color: AdminColors.statusAmber, size: 16),
                        ),
                        const SizedBox(width: 12),
                        const Text('Annuler'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AdminColors.statusRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_rounded, color: AdminColors.statusRed, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(List<GroupEntity> groups) {
    if (groups.isEmpty) {
      return _buildEmptyState(Icons.group_rounded, 'Aucun groupe trouvé');
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildGroupCard(GroupEntity group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Group image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: group.imageUrl == null
                    ? const LinearGradient(colors: [_primaryColor, AdminColors.actionBlueLight])
                    : null,
                image: group.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(group.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: group.imageUrl == null
                  ? const Icon(Icons.group_rounded, color: Colors.white, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        group.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                        size: 18,
                        color: group.isPrivate ? AdminColors.statusAmber : AdminColors.statusGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberIds.length} membres',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catégorie: ${group.category.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleGroupAction(value, group),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.statusGrayBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert_rounded, color: _textSecondary, size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: group.isPrivate ? 'make_public' : 'make_private',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AdminColors.actionBlueLight.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          group.isPrivate ? Icons.public_rounded : Icons.lock_rounded,
                          color: AdminColors.actionBlueLight,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(group.isPrivate ? 'Rendre public' : 'Rendre privé'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AdminColors.statusRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_rounded, color: AdminColors.statusRed, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _textSecondary.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
        ),
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return AdminColors.actionBlueLight;
      case EventStatus.ongoing:
        return AdminColors.statusGreen;
      case EventStatus.completed:
        return AdminColors.statusGray;
      case EventStatus.cancelled:
        return AdminColors.statusRed;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chargement du contenu...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.statusRed.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AdminColors.statusRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: _textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEventAction(String action, EventEntity event) async {
    final notifier = ref.read(adminContentNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    switch (action) {
      case 'cancel':
        final confirm = await _showConfirmation(
          'Annuler l\'événement',
          'Êtes-vous sûr de vouloir annuler cet événement ?',
        );
        if (confirm == true) {
          await notifier.cancelEvent(event.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Événement annulé');
        }
        break;
      case 'delete':
        final confirm = await _showConfirmation(
          'Supprimer l\'événement',
          'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.',
        );
        if (confirm == true) {
          await notifier.deleteEvent(event.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Événement supprimé');
        }
        break;
    }
  }

  Future<void> _handleGroupAction(String action, GroupEntity group) async {
    final notifier = ref.read(adminContentNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    switch (action) {
      case 'make_public':
        await notifier.toggleGroupPrivacy(group.id, false, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _showSnackBar('Groupe rendu public');
        break;
      case 'make_private':
        await notifier.toggleGroupPrivacy(group.id, true, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _showSnackBar('Groupe rendu privé');
        break;
      case 'delete':
        final confirm = await _showConfirmation(
          'Supprimer le groupe',
          'Êtes-vous sûr de vouloir supprimer ce groupe ? Cette action est irréversible.',
        );
        if (confirm == true) {
          await notifier.deleteGroup(group.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Groupe supprimé');
        }
        break;
    }
  }

  Future<bool?> _showConfirmation(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.statusRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
