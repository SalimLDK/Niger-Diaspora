import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/admin_provider.dart';

class AdminUsersManagementScreen extends ConsumerStatefulWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  ConsumerState<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState
    extends ConsumerState<AdminUsersManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUsersNotifierProvider.notifier).fetchAllUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 24),
        // Search bar
        _buildSearchBar(),
        const SizedBox(height: 16),
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
              Tab(text: 'Tous (${state.users.length})'),
              Tab(text: 'Admins (${state.admins.length})'),
              Tab(text: 'Bannis (${state.bannedUsers.length})'),
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
                        _buildUsersList(_filterUsers(state.users)),
                        _buildUsersList(_filterUsers(state.admins)),
                        _buildUsersList(_filterUsers(state.bannedUsers)),
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
              'Gestion des Utilisateurs',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gérez les comptes, permissions et bannissements',
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
          ref.read(adminUsersNotifierProvider.notifier).fetchAllUsers();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
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

  Widget _buildSearchBar() {
    return Container(
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
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher un utilisateur...',
          prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: _textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  List<UserEntity> _filterUsers(List<UserEntity> users) {
    if (_searchQuery.isEmpty) return users;
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      return (user.displayName?.toLowerCase().contains(query) ?? false) ||
          (user.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _buildUsersList(List<UserEntity> users) {
    if (users.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserEntity user) {
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
            // Avatar
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: user.photoUrl == null
                        ? const LinearGradient(colors: [_primaryColor, Color(0xFF8B5CF6)])
                        : null,
                    image: user.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(user.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.photoUrl == null
                      ? Center(
                          child: Text(
                            (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : null,
                ),
                if (user.isBanned)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName ?? 'Sans nom',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      if (user.isAdmin) _buildBadge('ADMIN', const Color(0xFF8B5CF6)),
                      if (user.isBanned) _buildBadge('BANNI', const Color(0xFFEF4444)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? 'Pas d\'email',
                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  if (user.lastLoginAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dernière connexion: ${_formatDate(user.lastLoginAt!)}',
                      style: TextStyle(color: _textSecondary.withAlpha(150), fontSize: 12),
                    ),
                  ],
                  if (user.banReason != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Raison: ${user.banReason}',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleUserAction(value, user),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert_rounded, color: _textSecondary, size: 20),
              ),
              itemBuilder: (context) => [
                if (!user.isBanned)
                  _buildPopupMenuItem('ban', 'Bannir', Icons.block_rounded, const Color(0xFFEF4444))
                else
                  _buildPopupMenuItem('unban', 'Débannir', Icons.check_circle_rounded, const Color(0xFF10B981)),
                if (!user.isAdmin)
                  _buildPopupMenuItem('promote', 'Promouvoir admin', Icons.arrow_upward_rounded, const Color(0xFF8B5CF6))
                else
                  _buildPopupMenuItem('demote', 'Retirer admin', Icons.arrow_downward_rounded, const Color(0xFFF59E0B)),
                _buildPopupMenuItem('verify_profile', 'Vérifier profil', Icons.verified_rounded, const Color(0xFF3B82F6)),
                _buildPopupMenuItem('force_logout', 'Forcer déconnexion', Icons.logout_rounded, _textSecondary),
                _buildPopupMenuItem('activity', 'Voir activité', Icons.history_rounded, _primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Chargement...', style: TextStyle(color: _textSecondary, fontSize: 14)),
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
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: _textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          const Text('Aucun utilisateur trouvé', style: TextStyle(color: _textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _handleUserAction(String action, UserEntity user) async {
    final notifier = ref.read(adminUsersNotifierProvider.notifier);
    final dashboardNotifier = ref.read(adminDashboardNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    switch (action) {
      case 'ban':
        final reason = await _showTextDialog('Bannir l\'utilisateur', 'Raison du bannissement:');
        if (reason != null && reason.isNotEmpty) {
          await notifier.banUser(user.id, reason, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Utilisateur banni');
        }
        break;
      case 'unban':
        final confirm = await _showConfirmation('Débannir l\'utilisateur', 'Êtes-vous sûr de vouloir débannir cet utilisateur ?');
        if (confirm == true) {
          await notifier.unbanUser(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Utilisateur débanni');
        }
        break;
      case 'promote':
        final confirm = await _showConfirmation('Promouvoir en admin', 'Êtes-vous sûr de vouloir promouvoir cet utilisateur en administrateur ?');
        if (confirm == true) {
          await notifier.promoteToAdmin(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Utilisateur promu admin');
        }
        break;
      case 'demote':
        final confirm = await _showConfirmation('Retirer les droits admin', 'Êtes-vous sûr de vouloir retirer les droits administrateur ?');
        if (confirm == true) {
          await notifier.demoteFromAdmin(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Droits admin retirés');
        }
        break;
      case 'verify_profile':
        await notifier.verifyProfile(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _showSnackBar('Profil vérifié');
        break;
      case 'force_logout':
        final confirm = await _showConfirmation('Forcer la déconnexion', 'Cela déconnectera l\'utilisateur de tous ses appareils.');
        if (confirm == true) {
          await dashboardNotifier.forceLogoutUser(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Utilisateur déconnecté');
        }
        break;
      case 'activity':
        await _showUserActivity(user);
        break;
    }
  }

  Future<void> _showUserActivity(UserEntity user) async {
    final activity = await ref.read(adminUsersNotifierProvider.notifier).getUserActivity(user.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Activité de ${user.displayName ?? user.email}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: activity.isEmpty
              ? const Center(child: Text('Aucune activité enregistrée'))
              : ListView.builder(
                  itemCount: activity.length,
                  itemBuilder: (context, index) {
                    final item = activity[index];
                    return ListTile(
                      leading: const Icon(Icons.history_rounded, color: _primaryColor),
                      title: Text(item['action'] ?? 'Action'),
                      subtitle: Text(item['timestamp']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmation(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextDialog(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
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
