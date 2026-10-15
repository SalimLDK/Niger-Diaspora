import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admin_bandeau_erreur.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/apercu_contenu_signale.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/carte_stat_signalement.dart';
import 'package:diaspo_niger/features/admin/presentation/signalement_presentation.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceRecherche;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  static const List<String> _targetTypes = [
    'user',
    'message',
    'conversation',
    'group',
    'event',
    'business',
    'product',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(adminReportsNotifierProvider.notifier).fetchAllReports());
    });
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// La recherche part au serveur, un court instant après la dernière frappe.
  void _surRecherche(String value) {
    setState(() => _searchQuery = value);
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      unawaited(ref.read(adminReportsNotifierProvider.notifier).rechercher(value));
    });
  }

  Map<String, int> _statistiques(CompteursSignalements c) => {
        'total': c.total,
        'pending': c.enAttente,
        'resolved': c.traites,
        'dismissed': c.rejetes,
      };

  String _libelleOnglet(String nom, AdminReportsState state, FiltreSignalements f) =>
      '$nom (${state.liste(f).length}${state.encorePlus.contains(f) ? '+' : ''})';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsNotifierProvider);
    final stats = _statistiques(state.compteurs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(state),
        const SizedBox(height: 16),
        // Statistics Row
        _buildStatisticsRow(stats),
        const SizedBox(height: 16),
        // Search and Filters
        _buildSearchAndFilters(),
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
              Tab(text: _libelleOnglet('En attente', state, FiltreSignalements.enAttente)),
              Tab(
                text: _libelleOnglet('Traités', state, FiltreSignalements.traites),
              ),
              Tab(text: _libelleOnglet('Tous', state, FiltreSignalements.tous)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.isLoading
              ? _buildLoadingState()
              : state.error != null && state.reports.isEmpty
                  ? _buildErrorState(state.error!)
                  : Column(
                      children: [
                        // Une erreur posée après une action (zéro ligne,
                        // journal refusé) ne doit pas effacer la liste.
                        if (state.error != null)
                          AdminBandeauErreur(
                            message: state.error!,
                            onFermer: ref
                                .read(adminReportsNotifierProvider.notifier)
                                .effacerErreur,
                          ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildReportsList(state, FiltreSignalements.enAttente),
                              _buildReportsList(state, FiltreSignalements.traites),
                              _buildReportsList(state, FiltreSignalements.tous),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildStatisticsRow(Map<String, int> stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          CarteStatSignalement(
            l10n.adminPending,
            stats['pending'] ?? 0,
            Icons.hourglass_empty_rounded,
            AdminColors.statusAmber,
          ),
          const SizedBox(width: 12),
          CarteStatSignalement(
            'Résolus',
            stats['resolved'] ?? 0,
            Icons.check_circle_outline_rounded,
            AdminColors.statusGreen,
          ),
          const SizedBox(width: 12),
          CarteStatSignalement(
            'Rejetés',
            stats['dismissed'] ?? 0,
            Icons.cancel_outlined,
            AdminColors.statusGray,
          ),
          const SizedBox(width: 12),
          CarteStatSignalement(
            l10n.adminTotalLabel,
            stats['total'] ?? 0,
            Icons.flag_outlined,
            _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          DesignSearchField(
            controller: _searchController,
            hintText: l10n.adminSearchReports,
            onChanged: _surRecherche,
            onClear: () {
              _searchController.clear();
              _surRecherche('');
            },
            active: _searchQuery.isNotEmpty,
          ),
          const SizedBox(height: 12),
          // Type filters
          Row(
            children: [
              Text(
                l10n.adminTypeFilterLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, l10n.adminAll),
                      const SizedBox(width: 8),
                      ..._targetTypes.map((type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(type, libelleTypeSignalement(l10n, type)),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label) {
    return DesignFilterChip(
      label: label,
      selected: ref.watch(adminReportsNotifierProvider).typeFiltre == type,
      compact: true,
      onTap: () => unawaited(
        ref.read(adminReportsNotifierProvider.notifier).filtrerType(type),
      ),
    );
  }

  Widget _buildPageHeader(AdminReportsState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTitle(
              l10n.adminReportsManagement,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminReportsSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (state.compteurs.enAttente > 0) _buildPendingBadge(state.compteurs.enAttente),
            const SizedBox(width: 12),
            _buildRefreshButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.statusRed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AdminColors.statusRed.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$count en attente',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(ref.read(adminReportsNotifierProvider.notifier).fetchAllReports());
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

  Widget _buildReportsList(AdminReportsState state, FiltreSignalements filtre) {
    final reports = state.liste(filtre);
    if (reports.isEmpty) {
      return _buildEmptyState();
    }
    final encorePlus = state.encorePlus.contains(filtre);

    return ListView.builder(
      itemCount: reports.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == reports.length) {
          return AdminChargerPlus(
            enCours: state.chargementPlus == filtre,
            onPressed: () => unawaited(
              ref
                  .read(adminReportsNotifierProvider.notifier)
                  .chargerPlus(filtre),
            ),
          );
        }
        return _buildReportCard(reports[index]);
      },
    );
  }

  Widget _buildReportCard(ReportEntity report) {
    final statusColor = couleurStatutSignalement(report.status);

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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            iconeTypeSignalement(report.targetType),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                report.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: _textPrimary,
                ),
              ),
            ),
            _buildStatusBadge(report.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Type: ${libelleTypeSignalement(l10n, report.targetType)}${report.targetName != null ? ' • ${report.targetName}' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            if (report.createdAt != null)
              Text(
                'Signalé le: ${_formatDate(report.createdAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary.withAlpha(150),
                ),
              ),
          ],
        ),
        children: [
          _buildReportDetails(report),
        ],
      ),
    );
  }

  Widget _buildReportDetails(ReportEntity report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        // Snapshot du contenu signalé
        if (report.contentSnapshot != null && report.contentSnapshot!.hasContent) ...[
          ApercuContenuSignale(
                snapshot: report.contentSnapshot!,
                libelle: l10n.adminCapturedContentLabel,
                date: report.contentSnapshot!.capturedAt == null ? null : _formatDate(report.contentSnapshot!.capturedAt!),
              ),
          const SizedBox(height: 16),
        ],

        // View content button
        _buildViewContentButton(report),
        const SizedBox(height: 16),
        if (report.description != null) ...[
          _buildSectionLabel(l10n.adminDescriptionLabel),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              report.description!,
              style: const TextStyle(
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildDetailRow(l10n.adminTargetIdLabel, report.targetId),
        if (report.targetName != null)
          _buildDetailRow(l10n.adminTargetNameLabel, report.targetName!),
        _buildDetailRow(l10n.adminReportedByLabel, report.reporterName ?? report.reporterId),
        if (report.reportedUserId != null)
          _buildDetailRow(l10n.adminReportedUserLabel, report.reportedUserId!),
        if (report.adminNote != null) ...[
          const SizedBox(height: 16),
          _buildSectionLabel(l10n.adminAdminNoteLabel),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.statusGreen.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminColors.statusGreen.withAlpha(30)),
            ),
            child: Text(
              report.adminNote!,
              style: const TextStyle(
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
          ),
        ],
        if (report.status == 'pending') ...[
          const SizedBox(height: 20),
          _buildActionButtons(report),
        ],
      ],
    );
  }

  Widget _buildViewContentButton(ReportEntity report) {
    final route = routeContenuSignale(report);

    if (route == null) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: () => context.push(route),
      icon: const Icon(Icons.visibility_outlined, size: 16),
      label: Text('Voir le ${libelleTypeSignalement(l10n, report.targetType).toLowerCase()}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: const BorderSide(color: _primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: _textPrimary,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ReportEntity report) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _buildActionButton(
          label: l10n.adminReject,
          icon: Icons.close_rounded,
          color: AdminColors.statusGray,
          isOutlined: true,
          onPressed: () => _dismissReport(report),
        ),
        _buildActionButton(
          label: l10n.adminProcess,
          icon: Icons.check_rounded,
          color: AdminColors.statusGreen,
          onPressed: () => _resolveReport(report),
        ),
        _buildActionButton(
          label: l10n.adminDeleteContent,
          icon: Icons.delete_rounded,
          color: AdminColors.statusRed,
          onPressed: () => _deleteContent(report),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return DesignBadge(
      libelleStatutSignalement(l10n, status),
      tone: switch (status) {
        'pending' => DesignBadgeTone.review,
        'resolved' => DesignBadgeTone.verified,
        _ => DesignBadgeTone.archived,
      },
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
            l10n.adminLoadingReports,
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                unawaited(ref.read(adminReportsNotifierProvider.notifier).fetchAllReports());
              },
              icon: const Icon(Icons.refresh),
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
    final hasFilters = _searchQuery.isNotEmpty ||
        ref.watch(adminReportsNotifierProvider).typeFiltre != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: DesignEmptyState(
          icon: hasFilters ? Icons.search_off_rounded : Icons.report_off_rounded,
          title: hasFilters
              ? l10n.adminNoResultsSearch
              : l10n.adminNoReportsAvailable,
          body: hasFilters
              ? 'Essayez un autre mot, ou retirez les filtres.'
              : 'Rien à traiter ici pour le moment.',
          children: [
            if (hasFilters)
              Center(
                child: DesignSecondaryButton(
                  label: l10n.adminClearFilters,
                  onPressed: () {
                    _debounceRecherche?.cancel();
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    unawaited(
                      ref
                          .read(adminReportsNotifierProvider.notifier)
                          .viderFiltres(),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _dismissReport(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected, isError: true);
      return;
    }

    final reason = await _showTextDialog(
      l10n.adminRejectReport,
      l10n.adminDismissReportPrompt,
      hintText: l10n.adminRejectHint,
    );
    if (reason != null && reason.isNotEmpty) {
      final ok = await ref.read(adminReportsNotifierProvider.notifier).dismissReport(
        report.id,
        reason,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _montrerBilan(ok, l10n.adminReportDismissed);
    }
  }

  Future<void> _resolveReport(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected, isError: true);
      return;
    }

    final note = await _showTextDialog(
      l10n.adminProcessReport,
      l10n.adminProcessReportPrompt,
      hintText: l10n.adminProcessHint,
    );
    if (note != null) {
      final ok = await ref.read(adminReportsNotifierProvider.notifier).resolveReport(
        report.id,
        note,
        'resolved',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
        reportedUserId: report.reportedUserId,
      );
      _montrerBilan(ok, 'Signalement traité${report.reportedUserId != null ? ' (utilisateur notifié)' : ''}');
    }
  }

  Future<void> _deleteContent(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected, isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.statusRed.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AdminColors.statusRed,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.adminDeleteContentTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminDeleteContentMsg,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible et supprimera définitivement le ${libelleTypeSignalement(l10n, report.targetType).toLowerCase()}.',
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            if (report.targetName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      iconeTypeSignalement(report.targetType),
                      size: 18,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.targetName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.adminCancelAction),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: Text(l10n.adminDelete),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.statusRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = ref.read(adminReportsNotifierProvider.notifier);
      final supprime = await notifier.deleteReportedContent(
        report.targetType,
        report.targetId,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
        reportId: report.id,
        reportedUserId: report.reportedUserId,
      );
      if (!supprime) {
        // Rien n'a disparu (type sans table, refus RLS, cible introuvable) :
        // ne pas clore le signalement en « contenu supprimé », ni l'annoncer.
        _showSnackBar(
          ref.read(adminReportsNotifierProvider).error ?? l10n.deleteError,
          isError: true,
        );
        return;
      }
      final clos = await notifier.resolveReport(
        report.id,
        l10n.adminContentDeleted,
        'content_deleted',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
        reportedUserId: null, // Déjà notifié par deleteReportedContent
        notifyUser: false,
      );
      _montrerBilan(clos, 'Contenu supprimé${report.reportedUserId != null ? ' (utilisateur notifié)' : ''}');
    }
  }

  Future<String?> _showTextDialog(String title, String label, {String? hintText}) {
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
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: _textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.adminCancelAction),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
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
  void _montrerBilan(bool ok, String succes) {
    if (!mounted) return;
    if (ok) {
      _showSnackBar(succes);
      return;
    }
    _showSnackBar(
      ref.read(adminReportsNotifierProvider).error ?? l10n.loadingError,
      isError: true,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AdminColors.statusRed : AdminColors.statusGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
