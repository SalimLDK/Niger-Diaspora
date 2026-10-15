import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_bandeau_erreur.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';

class AdminUsersManagementScreen extends ConsumerStatefulWidget {
  const AdminUsersManagementScreen({super.key, this.onGererRoles});

  /// Mène à l'écran Rôles, seul chemin de promotion. Les entrées « Promouvoir
  /// admin » / « Retirer admin » de ce menu n'écrivaient que `is_admin`, sans
  /// `admin_role` ni Firestore : des admins fantômes, tous les pouvoirs RLS
  /// et invisibles comme admins dans l'app — un tel compte existe en
  /// production (audit du 2026-10-14, § 2). Nul quand l'écran est monté hors
  /// du tableau de bord.
  final VoidCallback? onGererRoles;

  @override
  ConsumerState<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState
    extends ConsumerState<AdminUsersManagementScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceRecherche;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(adminUsersNotifierProvider.notifier).fetchAllUsers());
    });
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
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
              Tab(text: l10n.adminTabWithCount(l10n.all, '${state.users.length}${state.encorePlus.contains(FiltreUtilisateurs.tous) ? '+' : ''}')),
              Tab(text: l10n.adminTabWithCount(l10n.admins, '${state.admins.length}${state.encorePlus.contains(FiltreUtilisateurs.admins) ? '+' : ''}')),
              Tab(text: l10n.adminTabWithCount(l10n.adminBannedName, '${state.bannedUsers.length}${state.encorePlus.contains(FiltreUtilisateurs.bannis) ? '+' : ''}')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.isLoading
              ? _buildLoadingState()
              : state.error != null && state.users.isEmpty
                  ? _buildErrorState(state.error!)
                  : Column(
                      children: [
                        // Une erreur posée après une action (zéro ligne,
                        // journal refusé) ne doit pas effacer la liste.
                        if (state.error != null)
                          AdminBandeauErreur(
                            message: state.error!,
                            onFermer: ref
                                .read(adminUsersNotifierProvider.notifier)
                                .effacerErreur,
                          ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildUsersList(state, FiltreUtilisateurs.tous),
                              _buildUsersList(state, FiltreUtilisateurs.admins),
                              _buildUsersList(state, FiltreUtilisateurs.bannis),
                            ],
                          ),
                        ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTitle(
              l10n.adminUsersTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
            ),
            SizedBox(height: 4),
            Text(
              l10n.adminUsersManagementSubtitle,
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

  Widget _buildRefreshButton() => Tooltip(
    message: l10n.adminRefresh,
    child: _boutonActualiser(),
  );

  Widget _boutonActualiser() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(ref.read(adminUsersNotifierProvider.notifier).fetchAllUsers());
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

  Widget _buildSearchBar() {
    return DesignSearchField(
      controller: _searchController,
      hintText: l10n.adminSearchUser,
      onChanged: _surRecherche,
      onClear: () {
        _searchController.clear();
        _surRecherche('');
      },
      active: _searchQuery.isNotEmpty,
    );
  }

  /// La recherche part au serveur, un court instant après la dernière frappe.
  void _surRecherche(String value) {
    setState(() => _searchQuery = value);
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      unawaited(ref.read(adminUsersNotifierProvider.notifier).rechercher(value));
    });
  }

  Widget _buildUsersList(AdminUsersState state, FiltreUtilisateurs filtre) {
    final users = state.liste(filtre);
    if (users.isEmpty) {
      return _buildEmptyState();
    }
    final encorePlus = state.encorePlus.contains(filtre);

    return ListView.builder(
      itemCount: users.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == users.length) {
          return AdminChargerPlus(
            enCours: state.chargementPlus == filtre,
            onPressed: () => unawaited(
              ref.read(adminUsersNotifierProvider.notifier).chargerPlus(filtre),
            ),
          );
        }
        return _buildUserCard(users[index]);
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
                        ? const LinearGradient(colors: [_primaryColor, AdminColors.actionBlueLight])
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
                        color: AdminColors.statusRed,
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
                          user.displayName ?? l10n.adminNoName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      if (user.isAdmin) _badge(DesignTag(l10n.adminAdminBadge, tone: DesignTagTone.accent)),
                      if (user.isBanned) _badge(DesignBadge(l10n.adminBannedBadge, tone: DesignBadgeTone.failed)),
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
                        color: AdminColors.statusRed.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Raison: ${user.banReason}',
                        style: const TextStyle(color: AdminColors.statusRed, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              tooltip: l10n.moreActions,
              onSelected: (value) => _handleUserAction(value, user),
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
                if (!user.isBanned)
                  _buildPopupMenuItem('ban', 'Bannir', Icons.block_rounded, AdminColors.statusRed)
                else
                  _buildPopupMenuItem('unban', 'Débannir', Icons.check_circle_rounded, AdminColors.statusGreen),
                _buildPopupMenuItem('roles', 'Rôle admin : écran Rôles', Icons.admin_panel_settings_outlined, AdminColors.statusPurple),
                _buildPopupMenuItem('verify_profile', 'Vérifier profil', Icons.verified_rounded, AdminColors.actionBlueLight),
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

  /// Les pastilles du kit, décalées de la ligne de nom.
  Widget _badge(Widget pastille) =>
      Padding(padding: const EdgeInsets.only(left: 8), child: pastille);

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
          Text(l10n.adminLoading, style: TextStyle(color: _textSecondary, fontSize: 14)),
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
                color: AdminColors.statusRed.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: AdminColors.statusRed),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adminLoadingError,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignEmptyState(
          icon: Icons.people_outline_rounded,
          title: l10n.adminNoUserFound,
          body: _searchQuery.isEmpty
              ? l10n.adminUsersEmptyBody
              : l10n.adminUsersNoMatchBody,
        ),
      ),
    );
  }

  Future<void> _handleUserAction(String action, UserEntity user) async {
    final notifier = ref.read(adminUsersNotifierProvider.notifier);
    final dashboardNotifier = ref.read(adminDashboardNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected);
      return;
    }

    switch (action) {
      case 'ban':
        final reason = await _showTextDialog('Bannir l\'utilisateur', l10n.adminBanReasonLabel);
        if (reason != null && reason.isNotEmpty) {
          final ok = await notifier.banUser(user.id, reason);
          _montrerBilan(ok, l10n.adminUserBanned);
        }
        break;
      case 'unban':
        final confirm = await _showConfirmation('Débannir l\'utilisateur', l10n.adminUnbanConfirm);
        if (confirm == true) {
          final ok = await notifier.unbanUser(user.id);
          _montrerBilan(ok, l10n.adminUserUnbanned);
        }
        break;
      case 'roles':
        // Un seul chemin de promotion : l'écran Rôles écrit les trois
        // registres (Postgres, Firestore, RTDB), ce menu n'en écrivait qu'un.
        final ouvrirRoles = widget.onGererRoles;
        if (ouvrirRoles != null) {
          ouvrirRoles();
        } else {
          _showSnackBar("Les rôles admin se gèrent depuis l'écran Rôles.");
        }
        break;
      case 'verify_profile':
        final ok = await notifier.verifyProfile(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _montrerBilan(ok, 'Profil vérifié');
        break;
      case 'force_logout':
        final confirm = await _showConfirmation('Forcer la déconnexion', 'Cela déconnectera l\'utilisateur de tous ses appareils.');
        if (confirm == true) {
          final ok = await dashboardNotifier.forceLogoutUser(user.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          // L'erreur vit dans le notifier du tableau de bord, pas dans celui
          // des utilisateurs.
          _montrerBilan(
            ok,
            l10n.adminUserDisconnected,
            erreur: ref.read(adminDashboardNotifierProvider).error,
          );
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

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.adminUserActivityTitle(user.displayName ?? user.email ?? '')),
        content: SizedBox(
          width: 400,
          height: 300,
          child: activity.isEmpty
              ? Center(child: Text(l10n.adminNoActivity))
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.adminCancelAction)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.adminConfirmAction),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancelAction)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.adminConfirmAction),
          ),
        ],
      ),
    );
  }

  /// Le libellé de succès ne s'affiche que si le notifier a rendu vrai ;
  /// sinon son `state.error` (zéro ligne sous RLS, journal d'audit refusé…).
  /// Avant, le succès s'affichait quoi qu'il arrive (audit du 2026-10-14,
  /// § 5).
  void _montrerBilan(bool ok, String succes, {String? erreur}) {
    if (!mounted) return;
    if (ok) {
      _showSnackBar(succes);
      return;
    }
    _showSnackBar(
      erreur ?? ref.read(adminUsersNotifierProvider).error ?? l10n.loadingError,
      isError: true,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.statusRed : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
