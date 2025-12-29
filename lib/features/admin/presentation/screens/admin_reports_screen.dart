import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      ref.read(adminReportsNotifierProvider.notifier).fetchAllReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(state),
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
              Tab(text: 'En attente (${state.pendingReports.length})'),
              Tab(
                text: 'Traités (${state.reports.where((r) => r.status != 'pending').length})',
              ),
              Tab(text: 'Tous (${state.reports.length})'),
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
                        _buildReportsList(state.pendingReports),
                        _buildReportsList(
                          state.reports.where((r) => r.status != 'pending').toList(),
                        ),
                        _buildReportsList(state.reports),
                      ],
                    ),
        ),
      ],
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
            const Text(
              'Gestion des Signalements',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Traitez les signalements de contenu inapproprié',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (state.pendingReports.isNotEmpty) _buildPendingBadge(state.pendingReports.length),
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
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withAlpha(50),
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
          ref.read(adminReportsNotifierProvider.notifier).fetchAllReports();
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

  Widget _buildReportsList(List<ReportEntity> reports) {
    if (reports.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildReportCard(ReportEntity report) {
    final statusColor = _getStatusColor(report.status);

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
            _getTypeIcon(report.targetType),
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
              'Type: ${_getTypeLabel(report.targetType)}',
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
        if (report.description != null) ...[
          _buildSectionLabel('Description'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
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
        _buildDetailRow('ID cible', report.targetId),
        if (report.targetName != null)
          _buildDetailRow('Nom', report.targetName!),
        _buildDetailRow('Signalé par', report.reporterName ?? report.reporterId),
        if (report.adminNote != null) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('Note admin'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(30)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          label: 'Rejeter',
          icon: Icons.close_rounded,
          color: const Color(0xFF6B7280),
          isOutlined: true,
          onPressed: () => _dismissReport(report),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          label: 'Traiter',
          icon: Icons.check_rounded,
          color: const Color(0xFF10B981),
          onPressed: () => _resolveReport(report),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          label: 'Supprimer contenu',
          icon: Icons.delete_rounded,
          color: const Color(0xFFEF4444),
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
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'dismissed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'resolved':
        return 'Résolu';
      case 'dismissed':
        return 'Rejeté';
      default:
        return status;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'user':
        return Icons.person_rounded;
      case 'message':
        return Icons.message_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'group':
        return Icons.group_rounded;
      case 'business':
        return Icons.store_rounded;
      case 'product':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.report_rounded;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'user':
        return 'Utilisateur';
      case 'message':
        return 'Message';
      case 'event':
        return 'Événement';
      case 'group':
        return 'Groupe';
      case 'business':
        return 'Commerce';
      case 'product':
        return 'Produit';
      default:
        return type;
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
            'Chargement des signalements...',
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
                color: const Color(0xFFEF4444).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_off_rounded,
            size: 64,
            color: _textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun signalement',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _dismissReport(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    final reason = await _showTextDialog(
      'Rejeter le signalement',
      'Raison du rejet:',
    );
    if (reason != null && reason.isNotEmpty) {
      await ref.read(adminReportsNotifierProvider.notifier).dismissReport(
        report.id,
        reason,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _showSnackBar('Signalement rejeté');
    }
  }

  Future<void> _resolveReport(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    final note = await _showTextDialog(
      'Traiter le signalement',
      'Note de résolution:',
    );
    if (note != null) {
      await ref.read(adminReportsNotifierProvider.notifier).resolveReport(
        report.id,
        note,
        'resolved',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _showSnackBar('Signalement traité');
    }
  }

  Future<void> _deleteContent(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le contenu'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce contenu ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminReportsNotifierProvider.notifier).deleteReportedContent(
        report.targetType,
        report.targetId,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      await ref.read(adminReportsNotifierProvider.notifier).resolveReport(
        report.id,
        'Contenu supprimé',
        'content_deleted',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _showSnackBar('Contenu supprimé et signalement résolu');
    }
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
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
