import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';

class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

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
              colors: [_primaryColor, Color(0xFF8B5CF6)],
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Actualiser',
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
                    hintText: 'Rechercher par admin ou action...',
                    prefixIcon: const Icon(Icons.search, color: _textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Toutes les actions')),
            DropdownMenuItem(value: 'user', child: Text('Utilisateurs')),
            DropdownMenuItem(value: 'business', child: Text('Commerces')),
            DropdownMenuItem(value: 'content', child: Text('Contenu')),
            DropdownMenuItem(value: 'report', child: Text('Signalements')),
            DropdownMenuItem(value: 'transaction', child: Text('Transactions')),
            DropdownMenuItem(value: 'settings', child: Text('Configuration')),
            DropdownMenuItem(value: 'notification', child: Text('Notifications')),
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
            child: Icon(actionInfo.icon, color: actionInfo.color, size: 24),
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
                    const Icon(Icons.person_outline, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.adminName ?? 'Admin inconnu',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.timestamp != null
                          ? dateFormatter.format(log.timestamp!)
                          : 'Date inconnue',
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
                      color: const Color(0xFFF8FAFC),
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
          Icon(typeInfo.icon, size: 14, color: typeInfo.color),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails:',
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
        return _ActionInfo('Utilisateur banni', Icons.block, Colors.red);
      case 'unban_user':
        return _ActionInfo('Utilisateur débanni', Icons.check_circle, Colors.green);
      case 'promote_admin':
        return _ActionInfo('Promu administrateur', Icons.admin_panel_settings, const Color(0xFF8B5CF6));
      case 'demote_admin':
        return _ActionInfo('Rétrogradé', Icons.remove_moderator, Colors.orange);
      case 'verify_profile':
        return _ActionInfo('Profil vérifié', Icons.verified, Colors.blue);
      case 'verify_business':
        return _ActionInfo('Commerce vérifié', Icons.verified_user, Colors.green);
      case 'unverify_business':
        return _ActionInfo('Vérification retirée', Icons.cancel, Colors.orange);
      case 'delete_business':
        return _ActionInfo('Commerce supprimé', Icons.delete, Colors.red);
      case 'toggle_boost':
        return _ActionInfo('Boost modifié', Icons.trending_up, const Color(0xFFF59E0B));
      case 'delete_event':
        return _ActionInfo('Événement supprimé', Icons.event_busy, Colors.red);
      case 'cancel_event':
        return _ActionInfo('Événement annulé', Icons.event_busy, Colors.orange);
      case 'delete_group':
        return _ActionInfo('Groupe supprimé', Icons.group_off, Colors.red);
      case 'toggle_privacy':
        return _ActionInfo('Confidentialité modifiée', Icons.lock, const Color(0xFF6366F1));
      case 'resolve_report':
        return _ActionInfo('Signalement résolu', Icons.check_circle, Colors.green);
      case 'dismiss_report':
        return _ActionInfo('Signalement rejeté', Icons.cancel, Colors.orange);
      case 'delete_content':
        return _ActionInfo('Contenu supprimé', Icons.delete_forever, Colors.red);
      case 'refund_transaction':
        return _ActionInfo('Transaction remboursée', Icons.money_off, const Color(0xFF10B981));
      case 'complete_transaction':
        return _ActionInfo('Transaction complétée', Icons.check_circle, Colors.green);
      case 'fail_transaction':
        return _ActionInfo('Transaction échouée', Icons.error, Colors.red);
      case 'delete_product':
        return _ActionInfo('Produit supprimé', Icons.shopping_bag, Colors.red);
      case 'toggle_product':
        return _ActionInfo('Disponibilité modifiée', Icons.inventory, const Color(0xFF6366F1));
      case 'resolve_dispute':
        return _ActionInfo('Litige résolu', Icons.gavel, Colors.green);
      case 'update_settings':
        return _ActionInfo('Configuration mise à jour', Icons.settings, const Color(0xFF6366F1));
      case 'toggle_feature':
        return _ActionInfo('Feature modifiée', Icons.toggle_on, const Color(0xFF8B5CF6));
      case 'send_notification':
        return _ActionInfo('Notification envoyée', Icons.notifications, const Color(0xFFF59E0B));
      case 'force_logout':
        return _ActionInfo('Déconnexion forcée', Icons.logout, Colors.orange);
      default:
        return _ActionInfo(action, Icons.info, _textSecondary);
    }
  }

  _TargetTypeInfo _getTargetTypeInfo(String targetType) {
    switch (targetType) {
      case 'user':
        return _TargetTypeInfo('Utilisateur', Icons.person, const Color(0xFF3B82F6));
      case 'business':
        return _TargetTypeInfo('Commerce', Icons.store, const Color(0xFF10B981));
      case 'event':
        return _TargetTypeInfo('Événement', Icons.event, const Color(0xFFF59E0B));
      case 'group':
        return _TargetTypeInfo('Groupe', Icons.group, const Color(0xFF8B5CF6));
      case 'report':
        return _TargetTypeInfo('Signalement', Icons.report, Colors.red);
      case 'product':
        return _TargetTypeInfo('Produit', Icons.shopping_bag, const Color(0xFF6366F1));
      case 'transaction':
        return _TargetTypeInfo('Transaction', Icons.payments, const Color(0xFF14B8A6));
      case 'settings':
        return _TargetTypeInfo('Configuration', Icons.settings, const Color(0xFF64748B));
      case 'notification':
        return _TargetTypeInfo('Notification', Icons.notifications, const Color(0xFFF59E0B));
      case 'order':
        return _TargetTypeInfo('Commande', Icons.shopping_cart, const Color(0xFF6366F1));
      default:
        return _TargetTypeInfo(targetType, Icons.help, _textSecondary);
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
                color: Colors.red.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
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
              style: const TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(adminAuditNotifierProvider.notifier).fetchAuditLogs();
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
                color: const Color(0xFFF8FAFC),
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
            const Text(
              'Les actions des administrateurs apparaîtront ici',
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
  final IconData icon;
  final Color color;

  _ActionInfo(this.label, this.icon, this.color);
}

class _TargetTypeInfo {
  final String label;
  final IconData icon;
  final Color color;

  _TargetTypeInfo(this.label, this.icon, this.color);
}
