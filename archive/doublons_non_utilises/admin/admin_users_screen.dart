import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardNotifierProvider.notifier).fetchRecentUsers();
    });
  }

  Future<void> _handleForceLogout(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la déconnexion'),
        content: Text(
          'Voulez-vous vraiment déconnecter $userName de tous ses appareils ?',
        ),
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
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentAdmin = ref.read(currentAdminProvider);
      if (currentAdmin == null) {
        if (mounted) {
          _showSnackBar('Erreur: Admin non connecté');
        }
        return;
      }

      final success = await ref
          .read(adminDashboardNotifierProvider.notifier)
          .forceLogoutUser(userId, adminId: currentAdmin.id, adminName: currentAdmin.name);

      if (success && mounted) {
        _showSnackBar('$userName a été déconnecté.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: adminState.isLoading && adminState.recentUsers.isEmpty
              ? _buildLoadingState()
              : adminState.recentUsers.isEmpty
                  ? _buildEmptyState()
                  : _buildUsersList(adminState),
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
              'Gérez les comptes utilisateurs et les sessions',
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
          ref.read(adminDashboardNotifierProvider.notifier).fetchRecentUsers();
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

  Widget _buildUsersList(AdminDashboardState adminState) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          itemCount: adminState.recentUsers.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: AdminColors.border.withAlpha(30),
          ),
          itemBuilder: (context, index) {
            final user = adminState.recentUsers[index];
            final lastLogin = user.lastLoginAt != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(user.lastLoginAt!)
                : 'Jamais';

            return _buildUserTile(user, lastLogin);
          },
        ),
      ),
    );
  }

  Widget _buildUserTile(dynamic user, String lastLogin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: user.photoUrl == null
                  ? const LinearGradient(
                      colors: [_primaryColor, AdminColors.actionBlueLight],
                    )
                  : null,
              image: user.photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(user.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photoUrl == null
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
                : null,
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
                    if (user.isAdmin) _buildAdminBadge(),
                    if (user.isBanned) _buildBannedBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? 'Pas d\'email',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: _textSecondary.withAlpha(150),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Dernière connexion: $lastLogin',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action button
          _buildLogoutButton(user),
        ],
      ),
    );
  }

  Widget _buildAdminBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminColors.statusAmber.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.statusAmber.withAlpha(50)),
      ),
      child: const Text(
        'Admin',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AdminColors.statusAmber,
        ),
      ),
    );
  }

  Widget _buildBannedBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminColors.statusRed.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.statusRed.withAlpha(50)),
      ),
      child: const Text(
        'Banni',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AdminColors.statusRed,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(dynamic user) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleForceLogout(
          user.id,
          user.displayName ?? 'Utilisateur',
        ),
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: 'Déconnecter de force',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.statusRed.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AdminColors.statusRed,
              size: 20,
            ),
          ),
        ),
      ),
    );
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
            'Chargement des utilisateurs...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: _textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
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
