import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../providers/permission_provider.dart';
import '../../domain/enums/admin_enums.dart';
import '../../domain/constants/role_permissions.dart';
import 'admin_embassy_verification_screen.dart';
import 'admin_create_embassy_screen.dart';
import 'admin_businesses_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_marketplace_screen.dart';
import 'admin_users_management_screen.dart';
import 'admin_transactions_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_feature_flags_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_role_management_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Définition d'une destination de navigation avec sa permission requise
class _NavDestination {
  final String id;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final AdminPermission? requiredPermission;
  final bool superAdminOnly;
  final Widget Function(BuildContext, WidgetRef) contentBuilder;
  final int Function(AdminDashboardState)? badgeCount;

  const _NavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.contentBuilder,
    this.requiredPermission,
    this.superAdminOnly = false,
    this.badgeCount,
  });
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  int _selectedIndex = 0;

  // Palette back-office (design system — cf. AdminColors).
  // L'accent orange grand public est exclu de l'admin : l'action principale
  // et l'état actif utilisent le bleu d'action.
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _secondaryColor = AdminColors.actionBlueLight;
  static const Color _backgroundColor = AdminColors.bg;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  /// Toutes les destinations de navigation avec leurs permissions
  late final List<_NavDestination> _allDestinations;

  @override
  void initState() {
    super.initState();
    _initDestinations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardNotifierProvider.notifier).loadDashboardStats();
    });
  }

  void _initDestinations() {
    _allDestinations = [
      _NavDestination(
        id: 'overview',
        label: l10n.adminOverview,
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        requiredPermission: AdminPermission.viewDashboard,
        contentBuilder: (_, __) => _buildOverviewWidget(),
      ),
      _NavDestination(
        id: 'users',
        label: l10n.adminUsers,
        icon: const AppIcon(AppIcon.people),
        selectedIcon: const AppIcon(AppIcon.people),
        requiredPermission: AdminPermission.viewUsers,
        contentBuilder: (_, __) => const AdminUsersManagementScreen(),
        badgeCount: (state) => state.pendingReports,
      ),
      _NavDestination(
        id: 'businesses',
        label: l10n.adminBusinesses,
        icon: const AppIcon(AppIcon.store),
        selectedIcon: const AppIcon(AppIcon.store),
        requiredPermission: AdminPermission.viewBusinesses,
        contentBuilder: (_, __) => const AdminBusinessesScreen(),
      ),
      _NavDestination(
        id: 'content',
        label: l10n.adminContent,
        icon: const Icon(Icons.event_outlined),
        selectedIcon: const AppIcon(AppIcon.event),
        requiredPermission: AdminPermission.viewContent,
        contentBuilder: (_, __) => const AdminModerationScreen(),
      ),
      _NavDestination(
        id: 'reports',
        label: l10n.adminReports,
        icon: const Icon(Icons.report_outlined),
        selectedIcon: const Icon(Icons.report),
        requiredPermission: AdminPermission.viewReports,
        contentBuilder: (_, __) => const AdminReportsScreen(),
      ),
      _NavDestination(
        id: 'marketplace',
        label: l10n.adminMarketplace,
        icon: const Icon(Icons.shopping_bag_outlined),
        selectedIcon: const Icon(Icons.shopping_bag),
        requiredPermission: AdminPermission.viewMarketplace,
        contentBuilder: (_, __) => const AdminMarketplaceScreen(),
      ),
      _NavDestination(
        id: 'transactions',
        label: l10n.adminTransfers,
        icon: const Icon(Icons.payments_outlined),
        selectedIcon: const Icon(Icons.payments),
        requiredPermission: AdminPermission.viewTransactions,
        contentBuilder: (_, __) => const AdminTransactionsScreen(),
      ),
      _NavDestination(
        id: 'embassies',
        label: l10n.adminEmbassies,
        icon: const AppIcon(AppIcon.bank),
        selectedIcon: const AppIcon(AppIcon.bank),
        superAdminOnly: true,
        contentBuilder: (context, ref) => _buildEmbassiesPanel(),
      ),
      _NavDestination(
        id: 'analytics',
        label: l10n.adminAnalytics,
        icon: const Icon(Icons.analytics_outlined),
        selectedIcon: const Icon(Icons.analytics),
        requiredPermission: AdminPermission.viewAnalytics,
        contentBuilder: (_, __) => const AdminAnalyticsScreen(),
      ),
      _NavDestination(
        id: 'notifications',
        label: l10n.adminNotifications,
        icon: const Icon(Icons.notifications_outlined),
        selectedIcon: const Icon(Icons.notifications),
        requiredPermission: AdminPermission.sendNotifications,
        contentBuilder: (_, __) => const AdminNotificationsScreen(),
      ),
      _NavDestination(
        id: 'settings',
        label: l10n.adminConfiguration,
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        requiredPermission: AdminPermission.viewSettings,
        contentBuilder: (_, __) => const AdminSettingsScreen(),
      ),
      _NavDestination(
        id: 'features',
        label: l10n.adminFeatures,
        icon: const Icon(Icons.toggle_on_outlined),
        selectedIcon: const Icon(Icons.toggle_on),
        requiredPermission: AdminPermission.viewFeatureFlags,
        contentBuilder: (_, __) => const AdminFeatureFlagsScreen(),
      ),
      _NavDestination(
        id: 'audit',
        label: l10n.adminAudit,
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history),
        requiredPermission: AdminPermission.viewAuditLogs,
        contentBuilder: (_, __) => const AdminAuditScreen(),
      ),
      _NavDestination(
        id: 'roles',
        label: l10n.adminRoles,
        icon: const Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: const Icon(Icons.admin_panel_settings),
        superAdminOnly: true,
        contentBuilder: (_, __) => const AdminRoleManagementScreen(),
      ),
    ];
  }

  /// Filtre les destinations selon les permissions de l'utilisateur
  List<_NavDestination> _getFilteredDestinations(AdminRole role) {
    return _allDestinations.where((dest) {
      // SuperAdmin only destinations
      if (dest.superAdminOnly) {
        return role == AdminRole.superAdmin;
      }
      // Check specific permission
      if (dest.requiredPermission != null) {
        return role.hasPermission(dest.requiredPermission!);
      }
      // No permission required
      return true;
    }).toList();
  }

  Widget _buildOverviewWidget() {
    final state = ref.watch(adminDashboardNotifierProvider);
    return _buildOverview(state);
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardNotifierProvider);
    final adminRole = ref.watch(adminRoleProvider);
    final isWideScreen = MediaQuery.of(context).size.width > 1200;

    // Filtrer les destinations selon les permissions
    final filteredDestinations = _getFilteredDestinations(adminRole);

    // S'assurer que l'index sélectionné est valide
    if (_selectedIndex >= filteredDestinations.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(adminRole),
      body: Row(
        children: [
          _buildNavigationRail(adminState, isWideScreen, filteredDestinations),
          const VerticalDivider(thickness: 1, width: 1, color: AdminColors.border),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: _buildContent(filteredDestinations),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AdminRole role) {
    return AppBar(
      elevation: 0,
      backgroundColor: _cardColor,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DiaspoNiger',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Row(
                children: [
                  Text(
                    l10n.embassyDepartmentAdministration,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: role.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role.shortName,
                      style: TextStyle(
                        color: role.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildAppBarButton(
          icon: const AppIcon(AppIcon.refresh, color: _textSecondary, size: 20),
          tooltip: l10n.adminRefresh,
          onPressed: () {
            ref.read(adminDashboardNotifierProvider.notifier).loadDashboardStats();
          },
        ),
        const SizedBox(width: 8),
        _buildAppBarButton(
          icon: const Icon(Icons.logout_rounded, color: AdminColors.statusRed, size: 20),
          tooltip: l10n.adminLogout,
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/login');
          },
          isDestructive: true,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildAppBarButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDestructive
                  ? AdminColors.statusRed.withAlpha(20)
                  : AdminColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail(
    AdminDashboardState adminState,
    bool isWideScreen,
    List<_NavDestination> destinations,
  ) {
    return Container(
      color: _cardColor,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
          ),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              labelType: isWideScreen ? NavigationRailLabelType.all : NavigationRailLabelType.selected,
              extended: isWideScreen,
              minExtendedWidth: 220,
              backgroundColor: _cardColor,
              indicatorColor: _primaryColor.withAlpha(30),
              selectedIconTheme: const IconThemeData(color: _primaryColor),
              selectedLabelTextStyle: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
              unselectedIconTheme: const IconThemeData(color: _textSecondary),
              unselectedLabelTextStyle: const TextStyle(color: _textSecondary),
              leading: isWideScreen
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primaryColor, _secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.dashboard, color: Colors.white, size: 24),
                      ),
                    ),
              destinations: destinations.map((dest) {
                final badgeCount = dest.badgeCount?.call(adminState) ?? 0;
                Widget iconWidget = dest.icon;

                if (badgeCount > 0) {
                  iconWidget = Badge(
                    backgroundColor: AdminColors.statusRed,
                    label: Text('$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                    child: iconWidget,
                  );
                }

                return NavigationRailDestination(
                  icon: iconWidget,
                  selectedIcon: dest.selectedIcon,
                  label: Text(dest.label),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<_NavDestination> destinations) {
    if (_selectedIndex >= destinations.length) {
      return const SizedBox();
    }
    return destinations[_selectedIndex].contentBuilder(context, ref);
  }

  Widget _buildEmbassiesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(
          title: l10n.adminEmbassyManagement,
          subtitle: l10n.adminManageEmbassiesDesc,
          action: _buildGradientButton(
            label: l10n.adminCreateEmbassy,
            icon: const AppIcon(AppIcon.add, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminCreateEmbassyScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Expanded(child: AdminEmbassyVerificationScreen()),
      ],
    );
  }

  Widget _buildOverview(AdminDashboardState state) {
    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.error != null) {
      return _buildErrorState(state.error!);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: l10n.adminDashboardTitle,
            subtitle: 'Bienvenue dans le panneau d\'administration DiaspoNiger',
          ),
          const SizedBox(height: 32),

          // Main Stats
          _buildSectionTitle(l10n.adminGeneralStats),
          const SizedBox(height: 16),
          _buildStatsGrid([
            _StatItem(
              title: l10n.adminUsers,
              value: state.totalUsers.toString(),
              icon: const AppIcon(AppIcon.people, color: Colors.white, size: 24),
              gradient: const [AdminColors.actionBlue, AdminColors.actionBlueLight],
            ),
            _StatItem(
              title: l10n.adminActiveSessions,
              value: state.activeSessions.toString(),
              icon: const Icon(Icons.wifi_rounded, color: Colors.white, size: 24),
              gradient: const [AdminColors.statusGreen, AdminColors.statusGreenStrong],
            ),
            _StatItem(
              title: l10n.adminEventsLabel,
              value: state.totalEvents.toString(),
              icon: const AppIcon(AppIcon.event, color: Colors.white, size: 24),
              gradient: const [AdminColors.statusAmber, AdminColors.statusAmberStrong],
            ),
            _StatItem(
              title: l10n.adminGroupsLabel,
              value: state.totalGroups.toString(),
              icon: const AppIcon(AppIcon.groups, color: Colors.white, size: 24),
              gradient: const [AdminColors.statusPurple, AdminColors.statusPurple],
            ),
          ]),
          const SizedBox(height: 32),

          // Business & Marketplace
          _buildSectionTitle(l10n.adminCommerceTitle),
          const SizedBox(height: 16),
          _buildStatsGrid([
            _StatItem(
              title: l10n.adminBusinesses,
              value: state.totalBusinesses.toString(),
              icon: const AppIcon(AppIcon.store, color: Colors.white, size: 24),
              gradient: const [AdminColors.statusGreen, AdminColors.statusGreenStrong],
            ),
            _StatItem(
              title: l10n.adminProducts,
              value: state.totalProducts.toString(),
              icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 24),
              gradient: const [AdminColors.actionBlue, AdminColors.actionBlueLight],
            ),
            _StatItem(
              title: l10n.adminTransactions,
              value: state.totalTransactions.toString(),
              icon: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
              gradient: const [AdminColors.statusAmber, AdminColors.statusAmberStrong],
            ),
            _StatItem(
              title: l10n.adminReports,
              value: state.pendingReports.toString(),
              icon: Icon(Icons.report_rounded, color: Colors.white, size: 24),
              gradient: state.pendingReports > 0
                  ? const [AdminColors.statusRed, AdminColors.statusRedStrong]
                  : const [AdminColors.statusGray, AdminColors.statusGray],
            ),
          ]),
          const SizedBox(height: 32),

          // Quick Actions
          _buildSectionTitle(l10n.adminQuickActions),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction(
                label: l10n.adminViewReports,
                icon: const Icon(Icons.report_rounded, color: AdminColors.statusRed, size: 20),
                color: AdminColors.statusRed,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
              _buildQuickAction(
                label: l10n.adminManageUsers,
                icon: const AppIcon(AppIcon.people, color: AdminColors.actionBlue, size: 20),
                color: AdminColors.actionBlue,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildQuickAction(
                label: l10n.adminSendNotification,
                icon: const Icon(Icons.notifications_rounded, color: AdminColors.statusAmber, size: 20),
                color: AdminColors.statusAmber,
                onTap: () => setState(() => _selectedIndex = 9),
              ),
              _buildQuickAction(
                label: l10n.adminViewAnalytics,
                icon: const Icon(Icons.analytics_rounded, color: AdminColors.statusGreen, size: 20),
                color: AdminColors.statusGreen,
                onTap: () => setState(() => _selectedIndex = 8),
              ),
              _buildQuickAction(
                label: l10n.adminConfiguration,
                icon: const Icon(Icons.settings_rounded, color: AdminColors.statusGray, size: 20),
                color: AdminColors.statusGray,
                onTap: () => setState(() => _selectedIndex = 10),
              ),
              _buildQuickAction(
                label: l10n.adminFeatureFlags,
                icon: const Icon(Icons.toggle_on_rounded, color: AdminColors.statusPurple, size: 20),
                color: AdminColors.statusPurple,
                onTap: () => setState(() => _selectedIndex = 11),
              ),
              _buildQuickAction(
                label: l10n.adminAuditHistory,
                icon: const Icon(Icons.history_rounded, color: AdminColors.statusGray, size: 20),
                color: AdminColors.statusGray,
                onTap: () => setState(() => _selectedIndex = 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items.map((item) => SizedBox(
            width: (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount,
            child: _buildStatCard(item),
          )).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: item.gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.icon,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: item.gradient.first.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 14, color: item.gradient.first),
                    const SizedBox(width: 4),
                    Text(
                      l10n.adminActive,
                      style: TextStyle(
                        color: item.gradient.first,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            item.title,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required String label,
    required Widget icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primaryColor, _secondaryColor]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
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
          Text(
            l10n.adminLoadingData,
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
              child: const AppIcon(
                AppIcon.error,
                size: 48,
                color: AdminColors.statusRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adminErrorOccurred,
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
            const SizedBox(height: 24),
            _buildGradientButton(
              label: l10n.retry,
              icon: const AppIcon(AppIcon.refresh, color: Colors.white, size: 20),
              onPressed: () {
                ref.read(adminDashboardNotifierProvider.notifier).loadDashboardStats();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final Widget icon;
  final List<Color> gradient;

  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}
