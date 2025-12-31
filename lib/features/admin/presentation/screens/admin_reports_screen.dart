import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTypeFilter;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

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
      ref.read(adminReportsNotifierProvider.notifier).fetchAllReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ReportEntity> _filterReports(List<ReportEntity> reports) {
    return reports.where((report) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = (report.targetName?.toLowerCase().contains(query) ?? false) ||
            (report.reporterName?.toLowerCase().contains(query) ?? false) ||
            report.reason.toLowerCase().contains(query) ||
            report.targetId.toLowerCase().contains(query) ||
            (report.description?.toLowerCase().contains(query) ?? false);
        if (!matchesSearch) return false;
      }

      // Apply type filter
      if (_selectedTypeFilter != null && report.targetType != _selectedTypeFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, int> _calculateStatistics(List<ReportEntity> reports) {
    final stats = <String, int>{
      'total': reports.length,
      'pending': 0,
      'resolved': 0,
      'dismissed': 0,
    };

    // Count by target type
    for (final type in _targetTypes) {
      stats[type] = 0;
    }

    for (final report in reports) {
      // Count by status
      if (report.status == 'pending') {
        stats['pending'] = (stats['pending'] ?? 0) + 1;
      } else if (report.status == 'resolved') {
        stats['resolved'] = (stats['resolved'] ?? 0) + 1;
      } else if (report.status == 'dismissed') {
        stats['dismissed'] = (stats['dismissed'] ?? 0) + 1;
      }

      // Count by type
      stats[report.targetType] = (stats[report.targetType] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsNotifierProvider);
    final stats = _calculateStatistics(state.reports);

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
              Tab(text: 'En attente (${_filterReports(state.pendingReports).length})'),
              Tab(
                text: 'Traités (${_filterReports(state.reports.where((r) => r.status != 'pending').toList()).length})',
              ),
              Tab(text: 'Tous (${_filterReports(state.reports).length})'),
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
                        _buildReportsList(_filterReports(state.pendingReports)),
                        _buildReportsList(
                          _filterReports(state.reports.where((r) => r.status != 'pending').toList()),
                        ),
                        _buildReportsList(_filterReports(state.reports)),
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
          _buildStatCard(
            'En attente',
            stats['pending'] ?? 0,
            Icons.hourglass_empty_rounded,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Résolus',
            stats['resolved'] ?? 0,
            Icons.check_circle_outline_rounded,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Rejetés',
            stats['dismissed'] ?? 0,
            Icons.cancel_outlined,
            const Color(0xFF6B7280),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total',
            stats['total'] ?? 0,
            Icons.flag_outlined,
            _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, raison, ID...',
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.search, color: _textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: _textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 12),
          // Type filters
          Row(
            children: [
              const Text(
                'Type:',
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
                      _buildFilterChip(null, 'Tous'),
                      const SizedBox(width: 8),
                      ..._targetTypes.map((type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(type, _getTypeLabel(type)),
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
    final isSelected = _selectedTypeFilter == type;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : _textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedTypeFilter = type);
      },
      selectedColor: _primaryColor,
      backgroundColor: const Color(0xFFF1F5F9),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _primaryColor : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
              'Type: ${_getTypeLabel(report.targetType)}${report.targetName != null ? ' • ${report.targetName}' : ''}',
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
          _buildContentSnapshotPreview(report.contentSnapshot!),
          const SizedBox(height: 16),
        ],

        // View content button
        _buildViewContentButton(report),
        const SizedBox(height: 16),
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
        if (report.reportedUserId != null)
          _buildDetailRow('Utilisateur signalé', report.reportedUserId!),
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

  Widget _buildContentSnapshotPreview(ContentSnapshotData snapshot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSnapshotIcon(snapshot.contentType),
                size: 16,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              const Text(
                'Contenu capturé (préservé)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                ),
              ),
              const Spacer(),
              if (snapshot.capturedAt != null)
                Text(
                  _formatDate(snapshot.capturedAt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFFB45309).withAlpha(180),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Image preview
          if (snapshot.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                snapshot.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),

          // Video placeholder
          if (snapshot.videoUrl != null && snapshot.imageUrl == null)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline, size: 40, color: _textSecondary),
              ),
            ),

          // Text content
          if (snapshot.text != null && snapshot.text!.isNotEmpty) ...[
            if (snapshot.imageUrl != null || snapshot.videoUrl != null)
              const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                snapshot.text!,
                style: const TextStyle(fontSize: 13, color: _textPrimary),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // File name
          if (snapshot.fileName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 14, color: _textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    snapshot.fileName!,
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getSnapshotIcon(String? contentType) {
    switch (contentType) {
      case 'text':
        return Icons.chat_bubble_outline;
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'file':
        return Icons.attach_file;
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'user':
        return Icons.person_outline;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _buildViewContentButton(ReportEntity report) {
    final route = _getContentRoute(report);

    if (route == null) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: () => context.push(route),
      icon: const Icon(Icons.visibility_outlined, size: 16),
      label: Text('Voir le ${_getTypeLabel(report.targetType).toLowerCase()}'),
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

  String? _getContentRoute(ReportEntity report) {
    switch (report.targetType) {
      case 'user':
        return '/profile/${report.targetId}';
      case 'group':
        return '/groups/${report.targetId}';
      case 'event':
        return '/events/${report.targetId}';
      case 'business':
        return '/businesses/${report.targetId}';
      case 'product':
        return '/marketplace/${report.targetId}';
      case 'message':
      case 'conversation':
        if (report.conversationId != null) {
          return '/messages/${report.conversationId}';
        }
        return null;
      default:
        return null;
    }
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
          label: 'Rejeter',
          icon: Icons.close_rounded,
          color: const Color(0xFF6B7280),
          isOutlined: true,
          onPressed: () => _dismissReport(report),
        ),
        _buildActionButton(
          label: 'Traiter',
          icon: Icons.check_rounded,
          color: const Color(0xFF10B981),
          onPressed: () => _resolveReport(report),
        ),
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
      case 'conversation':
        return Icons.chat_bubble_rounded;
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
      case 'conversation':
        return 'Conversation';
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(adminReportsNotifierProvider.notifier).fetchAllReports();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
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
    final hasFilters = _searchQuery.isNotEmpty || _selectedTypeFilter != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.report_off_rounded,
            size: 64,
            color: _textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'Aucun résultat pour cette recherche' : 'Aucun signalement',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedTypeFilter = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Effacer les filtres'),
            ),
          ],
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
      _showSnackBar('Erreur: Admin non connecté', isError: true);
      return;
    }

    final reason = await _showTextDialog(
      'Rejeter le signalement',
      'Raison du rejet:',
      hintText: 'Ex: Signalement non fondé, contenu conforme aux règles...',
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
      _showSnackBar('Erreur: Admin non connecté', isError: true);
      return;
    }

    final note = await _showTextDialog(
      'Traiter le signalement',
      'Note de résolution:',
      hintText: 'Ex: Avertissement envoyé, contenu modifié...',
    );
    if (note != null) {
      await ref.read(adminReportsNotifierProvider.notifier).resolveReport(
        report.id,
        note,
        'resolved',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
        reportedUserId: report.reportedUserId,
      );
      _showSnackBar('Signalement traité${report.reportedUserId != null ? ' (utilisateur notifié)' : ''}');
    }
  }

  Future<void> _deleteContent(ReportEntity report) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté', isError: true);
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
                color: const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer le contenu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous sûr de vouloir supprimer ce contenu ?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible et supprimera définitivement le ${_getTypeLabel(report.targetType).toLowerCase()}.',
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTypeIcon(report.targetType),
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
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
        reportId: report.id,
        reportedUserId: report.reportedUserId,
      );
      await ref.read(adminReportsNotifierProvider.notifier).resolveReport(
        report.id,
        'Contenu supprimé',
        'content_deleted',
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
        reportedUserId: null, // Déjà notifié par deleteReportedContent
        notifyUser: false,
      );
      _showSnackBar('Contenu supprimé${report.reportedUserId != null ? ' (utilisateur notifié)' : ''}');
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
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
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
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
