import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/admin_provider.dart';
import '../widgets/avatar_admin.dart';
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
    // Une recherche posée avant l'ouverture (« Voir l'utilisateur » d'un
    // signalement) doit s'afficher dans le champ, pas seulement filtrer.
    final recherche = ref.read(adminUsersNotifierProvider).recherche;
    _searchController.text = recherche;
    _searchQuery = recherche;
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
                AvatarAdmin(
                  nom: user.displayName ?? user.email,
                  photoUrl: user.photoUrl,
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
                _buildPopupMenuItem('roles', l10n.adminMenuRolesScreen, Icons.admin_panel_settings_outlined, AdminColors.statusPurple),
                _buildPopupMenuItem('warn', l10n.mbrAdmWarn, Icons.report_gmailerrorred_rounded, AdminColors.statusAmber),
                if (!user.isBanned)
                  _buildPopupMenuItem('suspend', l10n.mbrAdmSuspend, Icons.pause_circle_outline_rounded, AdminColors.statusAmber)
                else if ((user.banReason ?? '').startsWith('Suspension : '))
                  _buildPopupMenuItem('unsuspend', l10n.mbrAdmUnsuspend, Icons.play_circle_outline_rounded, AdminColors.statusGreen),
                // L'écran ne sait pas si le profil porte déjà le badge : les
                // deux gestes restent offerts, le serveur refuse l'inutile
                // (déjà vérifié / pas vérifié) en le disant.
                _buildPopupMenuItem('verify_profile', l10n.mbrAdmVerify, Icons.verified_rounded, AdminColors.actionBlueLight),
                _buildPopupMenuItem('unverify_profile', l10n.mbrAdmUnverify, Icons.verified_outlined, _textSecondary),
                _buildPopupMenuItem('force_logout', l10n.adminMenuForceLogout, Icons.logout_rounded, _textSecondary),
                _buildPopupMenuItem('moderation_history', l10n.mbrAdmHistory, Icons.history_rounded, _primaryColor),
                _buildPopupMenuItem('activity', l10n.adminMenuViewActivity, Icons.list_alt_rounded, _primaryColor),
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
        final v = await _saisir(
          l10n.mbrAdmVerifyTitle,
          [l10n.mbrAdmVerifySource],
          avertissement: l10n.mbrAdmVerifyWarn,
        );
        if (v == null) return;
        final ok = await notifier.verifyProfile(user.id, source: v[0]);
        _montrerBilan(ok, l10n.adminProfileVerifiedSuccess);
        break;
      case 'unverify_profile':
        final v = await _saisir(l10n.mbrAdmUnverifyTitle, [l10n.mbrAdmReason]);
        if (v == null) return;
        final ok = await notifier.revokeVerification(user.id, motif: v[0]);
        _montrerBilan(ok, l10n.mbrAdmUnverified);
        break;
      case 'warn':
        final v = await _saisir(
          l10n.mbrAdmWarnTitle,
          [l10n.mbrAdmWarnReason, l10n.mbrAdmWarnMessage],
          avertissement: l10n.mbrAdmWarnWarn,
          minimums: const [5, 10],
        );
        if (v == null) return;
        final n = await notifier.warnUser(user.id, motif: v[0], message: v[1]);
        _montrerBilan(n != null, l10n.mbrAdmWarned('${n ?? 0}'));
        break;
      case 'suspend':
        final s = await showDialog<({int jours, String motif})>(
          context: context,
          builder: (_) => const _DialogueSuspension(),
        );
        if (s == null) return;
        final ok = await notifier.suspendUser(user.id, jours: s.jours, motif: s.motif);
        _montrerBilan(ok, l10n.mbrAdmSuspended);
        break;
      case 'unsuspend':
        final v = await _saisir(l10n.mbrAdmUnsuspendTitle, [l10n.mbrAdmReason]);
        if (v == null) return;
        final ok = await notifier.unsuspendUser(user.id, motif: v[0]);
        _montrerBilan(ok, l10n.mbrAdmUnsuspended);
        break;
      case 'force_logout':
        final v = await _saisir(
          l10n.adminForceLogoutTitle,
          [l10n.mbrAdmForceLogoutReason],
          avertissement: l10n.adminForceLogoutBody,
        );
        if (v == null) return;
        final ok = await dashboardNotifier.forceLogoutUser(user.id, motif: v[0]);
        // L'erreur vit dans le notifier du tableau de bord, pas dans celui
        // des utilisateurs.
        _montrerBilan(
          ok,
          l10n.adminUserDisconnected,
          erreur: ref.read(adminDashboardNotifierProvider).error,
        );
        break;
      case 'moderation_history':
        await _showModerationHistory(user);
        break;
      case 'activity':
        await _showUserActivity(user);
        break;
    }
  }

  /// Un ou plusieurs champs obligatoires (5 caractères au moins, ou
  /// [minimums]) ; `null` si annulé.
  Future<List<String>?> _saisir(
    String titre,
    List<String> libelles, {
    String? avertissement,
    List<int>? minimums,
  }) {
    final controllers = [for (final _ in libelles) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(titre),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (avertissement != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(avertissement,
                          style: const TextStyle(
                              fontSize: 12, color: AdminColors.statusAmberStrong)),
                    ),
                  for (var i = 0; i < libelles.length; i++) ...[
                    TextField(
                      controller: controllers[i],
                      onChanged: (_) => setLocal(() {}),
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: libelles[i],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.mbrAdmCancel)),
            ElevatedButton(
              onPressed: [
                for (var i = 0; i < controllers.length; i++)
                  controllers[i].text.trim().length >= (minimums != null ? minimums[i] : 5),
              ].every((b) => b)
                  ? () => Navigator.pop(ctx, [for (final c in controllers) c.text.trim()])
                  : null,
              child: Text(l10n.mbrAdmConfirm),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  Future<void> _showModerationHistory(UserEntity user) async {
    List<Map<String, dynamic>> events = const [];
    String? erreur;
    try {
      events = await ref.read(adminUsersNotifierProvider.notifier).getModerationHistory(user.id);
    } catch (e) {
      erreur = '$e';
    }
    if (!mounted) return;
    String libelle(String k) => switch (k) {
          'verified' => l10n.mbrAdmKindVerified,
          'unverified' => l10n.mbrAdmKindUnverified,
          'warned' => l10n.mbrAdmKindWarned,
          'suspended' => l10n.mbrAdmKindSuspended,
          'unsuspended' => l10n.mbrAdmKindUnsuspended,
          _ => l10n.mbrAdmKindRevoked,
        };
    String jour(Object? v) {
      final d = DateTime.tryParse('$v')?.toLocal();
      return d == null
          ? ''
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.mbrAdmHistoryTitle),
        content: SizedBox(
          width: 460,
          height: 320,
          child: erreur != null
              ? Text(l10n.mbrAdmLoadError(erreur),
                  style: const TextStyle(color: AdminColors.statusRed))
              : events.isEmpty
                  ? Center(child: Text(l10n.mbrAdmHistoryEmpty))
                  : ListView(
                      children: [
                        for (final e in events)
                          ListTile(
                            dense: true,
                            title: Text('${libelle('${e['kind']}')} · ${jour(e['occurred_at'])}'),
                            subtitle: Text(
                              e['actor_id'] == null
                                  ? '${l10n.mbrAdmBySystem} — ${e['reason'] ?? ''}'
                                  : '${e['reason'] ?? ''}',
                            ),
                          ),
                      ],
                    ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.mbrAdmClose)),
        ],
      ),
    );
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

/// Durée (1 à 30 jours) et motif d'une suspension.
class _DialogueSuspension extends StatefulWidget {
  const _DialogueSuspension();

  @override
  State<_DialogueSuspension> createState() => _DialogueSuspensionState();
}

class _DialogueSuspensionState extends State<_DialogueSuspension> {
  final _motif = TextEditingController();
  int _jours = 7;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.mbrAdmSuspendTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.mbrAdmSuspendWarn,
                  style: const TextStyle(fontSize: 12, color: AdminColors.statusAmberStrong)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _jours,
                decoration: InputDecoration(
                  labelText: l10n.mbrAdmSuspendDays,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  for (final j in const [1, 3, 7, 14, 30])
                    DropdownMenuItem(value: j, child: Text(l10n.mbrAdmDays('$j'))),
                ],
                onChanged: (v) => setState(() => _jours = v ?? _jours),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _motif,
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.mbrAdmReason,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.mbrAdmCancel)),
        ElevatedButton(
          onPressed: _motif.text.trim().length >= 5
              ? () => Navigator.pop(context, (jours: _jours, motif: _motif.text.trim()))
              : null,
          child: Text(l10n.mbrAdmConfirm),
        ),
      ],
    );
  }
}
