import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../embassies/domain/entities/embassy_entity.dart';
import '../../../embassies/presentation/providers/embassies_provider.dart';

class AdminEmbassyVerificationScreen extends ConsumerStatefulWidget {
  const AdminEmbassyVerificationScreen({super.key});

  @override
  ConsumerState<AdminEmbassyVerificationScreen> createState() =>
      _AdminEmbassyVerificationScreenState();
}

class _AdminEmbassyVerificationScreenState
    extends ConsumerState<AdminEmbassyVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Modern color palette
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embassiesAsync = ref.watch(embassiesListProvider);

    return embassiesAsync.when(
      data: (embassies) {
        final pending =
            embassies.where((e) => !e.isVerified && !e.isSuspended).toList();
        final active =
            embassies.where((e) => e.isVerified && !e.isSuspended).toList();
        final suspended = embassies.where((e) => e.isSuspended).toList();

        return Column(
          children: [
            // Stats Cards
            _buildStatsRow(pending.length, active.length, suspended.length),
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
                  Tab(text: 'En attente (${pending.length})'),
                  Tab(text: 'Actives (${active.length})'),
                  Tab(text: 'Suspendues (${suspended.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmbassyList(pending, 'pending'),
                  _buildEmbassyList(active, 'active'),
                  _buildEmbassyList(suspended, 'suspended'),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => _buildLoadingState(),
      error: (err, stack) => _buildErrorState(err.toString()),
    );
  }

  Widget _buildStatsRow(int pending, int active, int suspended) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          title: 'En attente',
          value: pending.toString(),
          icon: Icons.hourglass_empty_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        _buildStatCard(
          title: 'Actives',
          value: active.toString(),
          icon: Icons.verified_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        ),
        _buildStatCard(
          title: 'Suspendues',
          value: suspended.toString(),
          icon: Icons.block_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      width: 180,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbassyList(List<EmbassyEntity> embassies, String type) {
    if (embassies.isEmpty) {
      return _buildEmptyState(type);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: embassies.length,
      itemBuilder: (context, index) {
        return _EmbassyAdminCard(embassy: embassies[index]);
      },
    );
  }

  Widget _buildEmptyState(String type) {
    final messages = {
      'pending': 'Aucune ambassade en attente de verification',
      'active': 'Aucune ambassade active',
      'suspended': 'Aucune ambassade suspendue',
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcon.bank,
                size: 48,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              messages[type] ?? 'Aucune ambassade',
              style: const TextStyle(fontSize: 16, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
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
                BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chargement des ambassades...',
            style: TextStyle(color: _textSecondary, fontSize: 14),
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
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10),
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
              child: const AppIcon(
                AppIcon.error,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur de chargement',
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
              style: const TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(embassiesListProvider),
              icon: const AppIcon(AppIcon.refresh),
              label: const Text('Reessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbassyAdminCard extends ConsumerWidget {
  final EmbassyEntity embassy;

  // Modern color palette
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  const _EmbassyAdminCard({required this.embassy});

  Color _getStatusColor() {
    if (embassy.isSuspended) return const Color(0xFFEF4444);
    if (embassy.isVerified) return const Color(0xFF10B981);
    return const Color(0xFFF59E0B);
  }

  IconData _getStatusIcon() {
    if (embassy.isSuspended) return Icons.block_rounded;
    if (embassy.isVerified) return Icons.verified_rounded;
    return Icons.hourglass_empty_rounded;
  }

  String _getStatusLabel() {
    if (embassy.isSuspended) return 'Suspendue';
    if (embassy.isVerified) return 'Verifiee';
    return 'En attente';
  }

  Future<void> _approve(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(embassiesRepositoryProvider)
          .updateEmbassyStatus(
            embassy.id,
            isVerified: true,
            isSuspended: false,
          );
      ref.invalidate(embassiesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const AppIcon(AppIcon.checkCircle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Ambassade ${embassy.name} approuvee'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const AppIcon(AppIcon.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _reject(WidgetRef ref, BuildContext context) async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Rejeter la demande'),
            content: TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Raison du rejet',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(embassiesRepositoryProvider)
                        .updateEmbassyStatus(
                          embassy.id,
                          isVerified: false,
                          rejectionReason: reasonController.text,
                        );
                    ref.invalidate(embassiesListProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ambassade ${embassy.name} rejetee'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Rejeter',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _suspend(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(embassiesRepositoryProvider)
          .updateEmbassyStatus(embassy.id, isSuspended: true);
      ref.invalidate(embassiesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Ambassade ${embassy.name} suspendue'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reactivate(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(embassiesRepositoryProvider)
          .updateEmbassyStatus(embassy.id, isSuspended: false);
      ref.invalidate(embassiesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const AppIcon(AppIcon.checkCircle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Ambassade ${embassy.name} reactivee'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getStatusIcon(), color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                embassy.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withAlpha(50)),
              ),
              child: Text(
                _getStatusLabel(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon(
                    AppIcon.location,
                    size: 14,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${embassy.city}, ${embassy.country}',
                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const AppIcon(
                    AppIcon.public,
                    size: 14,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Juridiction: ${embassy.jurisdictionCountries.join(", ")}',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          // Details
          _buildDetailRow('Type', embassy.type),
          if (embassy.phone != null)
            _buildDetailRow('Telephone', embassy.phone!),
          if (embassy.email != null) _buildDetailRow('Email', embassy.email!),
          _buildDetailRow('Adresse', embassy.address),
          const SizedBox(height: 16),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (embassy.isSuspended) ...[
                _buildActionButton(
                  label: 'Reactiver',
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  color: const Color(0xFF10B981),
                  onPressed: () => _reactivate(ref, context),
                ),
              ] else if (!embassy.isVerified) ...[
                _buildActionButton(
                  label: 'Rejeter',
                  icon: const AppIcon(AppIcon.close, size: 18),
                  color: const Color(0xFFEF4444),
                  isOutlined: true,
                  onPressed: () => _reject(ref, context),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Approuver',
                  icon: const AppIcon(AppIcon.check, size: 18),
                  color: const Color(0xFF10B981),
                  onPressed: () => _approve(ref, context),
                ),
              ] else ...[
                _buildActionButton(
                  label: 'Suspendre',
                  icon: const Icon(Icons.block_rounded, size: 18),
                  color: Colors.orange,
                  isOutlined: true,
                  onPressed: () => _suspend(ref, context),
                ),
              ],
            ],
          ),
        ],
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
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: _textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Widget icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
