import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminAuditNotifierProvider.notifier).fetchAuditLogs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditState = ref.watch(adminAuditNotifierProvider);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFiltersAndSearch(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ];
      },
      body: auditState.isLoading
          ? _buildLoadingState()
          : auditState.error != null
              ? _buildErrorState(auditState.error!)
              : _buildAuditLogsList(auditState.logs),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique d\'Audit',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Suivez toutes les actions des administrateurs',
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
          ref.read(adminAuditNotifierProvider.notifier).fetchAuditLogs();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryColor, AdminColors.actionBlueLight],
            ),
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
              AppIcon(AppIcon.refresh, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                l10n.adminRefresh,
                style: TextStyle(
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

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: l10n.adminSearchByAdminOrAction,
                    prefixIcon: const AppIcon(AppIcon.search, color: _textSecondary),
                    filled: true,
                    fillColor: AdminColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildFilterDropdown(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
          items: [
            DropdownMenuItem(value: 'all', child: Text(l10n.adminAllActions)),
            DropdownMenuItem(value: 'user', child: Text(l10n.adminUsers)),
            DropdownMenuItem(value: 'business', child: Text(l10n.adminBusinesses)),
            DropdownMenuItem(value: 'content', child: Text(l10n.adminContent)),
            DropdownMenuItem(value: 'report', child: Text(l10n.adminReports)),
            DropdownMenuItem(value: 'transaction', child: Text(l10n.adminTransactions)),
            DropdownMenuItem(value: 'settings', child: Text(l10n.adminConfiguration)),
            DropdownMenuItem(value: 'notification', child: Text(l10n.adminNotifications)),
          ],
          onChanged: (value) {
            setState(() => _selectedFilter = value ?? 'all');
          },
        ),
      ),
    );
  }

  Widget _buildAuditLogsList(List<AuditLogEntry> logs) {
    final filteredLogs = _filterLogs(logs);

    if (filteredLogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildAuditLogCard(log);
      },
    );
  }

  List<AuditLogEntry> _filterLogs(List<AuditLogEntry> logs) {
    return logs.where((log) {
      // Filter by type
      if (_selectedFilter != 'all' && log.targetType != _selectedFilter) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesAdmin = log.adminName?.toLowerCase().contains(query) ?? false;
        final matchesAction = log.action.toLowerCase().contains(query);
        final matchesTarget = log.targetId?.toLowerCase().contains(query) ?? false;
        return matchesAdmin || matchesAction || matchesTarget;
      }

      return true;
    }).toList();
  }

  Widget _buildAuditLogCard(AuditLogEntry log) {
    final actionInfo = _getActionInfo(log.action);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: actionInfo.color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: actionInfo.icon,
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        actionInfo.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    _buildTargetTypeBadge(log.targetType),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const AppIcon(AppIcon.person, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.adminName ?? l10n.adminUnknownAdmin,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const AppIcon(AppIcon.clock, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.timestamp != null
                          ? dateFormatter.format(log.timestamp!)
                          : l10n.adminUnknownDate,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (log.targetId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${log.targetId}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailsSection(log.details!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeBadge(String targetType) {
    final typeInfo = _getTargetTypeInfo(targetType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: typeInfo.color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          typeInfo.icon,
          const SizedBox(width: 4),
          Text(
            typeInfo.label,
            style: TextStyle(
              color: typeInfo.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDetailsLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...details.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  _ActionInfo _getActionInfo(String action) {
    switch (action) {
      case 'ban_user':
        return _ActionInfo(l10n.adminUserBanned, const Icon(Icons.block, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'unban_user':
        return _ActionInfo(l10n.adminUserUnbanned, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'promote_admin':
        return _ActionInfo('Promu administrateur', const Icon(Icons.admin_panel_settings, color: AdminColors.statusPurple, size: 24), AdminColors.statusPurple);
      case 'demote_admin':
        return _ActionInfo(l10n.adminDemoted, const Icon(Icons.remove_moderator, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'verify_profile':
        return _ActionInfo('Profil vérifié', const Icon(Icons.verified, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'verify_business':
        return _ActionInfo(l10n.adminBusinessVerified, const Icon(Icons.verified_user, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'unverify_business':
        return _ActionInfo(l10n.adminVerificationRemoved, const AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_business':
        return _ActionInfo(l10n.adminBusinessDeleted, const AppIcon(AppIcon.delete, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_boost':
        return _ActionInfo('Boost modifié', const Icon(Icons.trending_up, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_event':
        return _ActionInfo(l10n.adminEventDeleted, const Icon(Icons.event_busy, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'cancel_event':
        return _ActionInfo(l10n.adminEventCancelled, const Icon(Icons.event_busy, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_group':
        return _ActionInfo(l10n.adminGroupDeleted, const Icon(Icons.group_off, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_privacy':
        return _ActionInfo(l10n.adminPrivacyChanged, const AppIcon(AppIcon.lock, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'resolve_report':
        return _ActionInfo(l10n.adminReportResolved, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'dismiss_report':
        return _ActionInfo(l10n.adminReportDismissed, const AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_content':
        return _ActionInfo(l10n.adminContentDeleted, const Icon(Icons.delete_forever, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'refund_transaction':
        return _ActionInfo(l10n.adminTransactionRefunded, const Icon(Icons.money_off, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'complete_transaction':
        return _ActionInfo(l10n.adminTransactionCompleted, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'fail_transaction':
        return _ActionInfo('Transaction échouée', const AppIcon(AppIcon.error, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'delete_product':
        return _ActionInfo(l10n.adminProductDeleted, const Icon(Icons.shopping_bag, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_product':
        return _ActionInfo(l10n.adminAvailabilityChanged, const Icon(Icons.inventory, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'resolve_dispute':
        return _ActionInfo(l10n.adminDisputeResolved, const Icon(Icons.gavel, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'update_settings':
        return _ActionInfo(l10n.adminConfigUpdated, const Icon(Icons.settings, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'toggle_feature':
        return _ActionInfo(l10n.adminFeatureChanged, const Icon(Icons.toggle_on, color: AdminColors.statusPurple, size: 24), AdminColors.statusPurple);
      case 'send_notification':
        return _ActionInfo(l10n.adminNotificationSent, const Icon(Icons.notifications, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'force_logout':
        return _ActionInfo(l10n.adminForceLogoutAction, const Icon(Icons.logout, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      default:
        return _ActionInfo(action, AppIcon(AppIcon.info, color: _textSecondary, size: 24), _textSecondary);
    }
  }

  _TargetTypeInfo _getTargetTypeInfo(String targetType) {
    switch (targetType) {
      case 'user':
        return _TargetTypeInfo(l10n.user, const AppIcon(AppIcon.person, size: 14, color: AdminColors.actionBlueLight), AdminColors.actionBlueLight);
      case 'business':
        return _TargetTypeInfo(l10n.reportTypeBusiness, const AppIcon(AppIcon.store, size: 14, color: AdminColors.statusGreen), AdminColors.statusGreen);
      case 'event':
        return _TargetTypeInfo(l10n.eventLabel, const AppIcon(AppIcon.event, size: 14, color: AdminColors.statusAmber), AdminColors.statusAmber);
      case 'group':
        return _TargetTypeInfo(l10n.group, const AppIcon(AppIcon.groups, size: 14, color: AdminColors.statusPurple), AdminColors.statusPurple);
      case 'report':
        return _TargetTypeInfo('Signalement', const Icon(Icons.report, size: 14, color: AdminColors.statusRed), AdminColors.statusRed);
      case 'product':
        return _TargetTypeInfo(l10n.reportTypeProduct, const Icon(Icons.shopping_bag, size: 14, color: AdminColors.actionBlue), AdminColors.actionBlue);
      case 'transaction':
        return _TargetTypeInfo(l10n.ticketCategoryTransaction, const Icon(Icons.payments, size: 14, color: AdminColors.statusGreen), AdminColors.statusGreen);
      case 'settings':
        return _TargetTypeInfo(l10n.adminConfiguration, const Icon(Icons.settings, size: 14, color: AdminColors.statusGray), AdminColors.statusGray);
      case 'notification':
        return _TargetTypeInfo('Notification', const Icon(Icons.notifications, size: 14, color: AdminColors.statusAmber), AdminColors.statusAmber);
      case 'order':
        return _TargetTypeInfo('Commande', const Icon(Icons.shopping_cart, size: 14, color: AdminColors.actionBlue), AdminColors.actionBlue);
      default:
        return _TargetTypeInfo(targetType, Icon(Icons.help, size: 14, color: _textSecondary), _textSecondary);
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(_primaryColor),
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
              l10n.adminLoadingError,
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
              style: const TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(adminAuditNotifierProvider.notifier).fetchAuditLogs();
              },
              icon: const AppIcon(AppIcon.refresh),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                color: AdminColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 48,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun log d\'audit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminAuditEmptyState,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionInfo {
  final String label;
  final Widget icon;
  final Color color;

  _ActionInfo(this.label, this.icon, this.color);
}

class _TargetTypeInfo {
  final String label;
  final Widget icon;
  final Color color;

  _TargetTypeInfo(this.label, this.icon, this.color);
}
