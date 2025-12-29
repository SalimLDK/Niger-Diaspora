import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_provider.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _targetGroup = 'all';

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotificationNotifierProvider.notifier).fetchSentNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotificationNotifierProvider);

    // Show success or error messages
    ref.listen<AdminNotificationState>(
      adminNotificationNotifierProvider,
      (previous, next) {
        if (next.successMessage != null) {
          _showSnackBar(next.successMessage!, isSuccess: true);
          ref.read(adminNotificationNotifierProvider.notifier).clearMessages();
        }
        if (next.error != null) {
          _showSnackBar(next.error!, isError: true);
          ref.read(adminNotificationNotifierProvider.notifier).clearMessages();
        }
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
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
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Envoyer'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Historique'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSendNotificationForm(state),
              _buildNotificationHistory(state),
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications Globales',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Envoyez des notifications à tous les utilisateurs',
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
          ref.read(adminNotificationNotifierProvider.notifier).fetchSentNotifications();
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

  Widget _buildSendNotificationForm(AdminNotificationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(24),
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
            const Text(
              'Nouvelle Notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _titleController,
              label: 'Titre',
              hint: 'Ex: Mise à jour importante',
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bodyController,
              label: 'Message',
              hint: 'Contenu de la notification...',
              icon: Icons.message_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            const Text(
              'Destinataires',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildTargetChip('all', 'Tous les utilisateurs', Icons.people_rounded),
                _buildTargetChip('admins', 'Administrateurs', Icons.admin_panel_settings_rounded),
                _buildTargetChip('verified', 'Profils vérifiés', Icons.verified_rounded),
                _buildTargetChip('business_owners', 'Propriétaires de commerces', Icons.store_rounded),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Effacer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: state.isSending ? null : _sendNotification,
                    icon: state.isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(state.isSending ? 'Envoi en cours...' : 'Envoyer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _textSecondary),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _buildTargetChip(String value, String label, IconData icon) {
    final isSelected = _targetGroup == value;
    return GestureDetector(
      onTap: () => setState(() => _targetGroup = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationHistory(AdminNotificationState state) {
    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.sentNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: state.sentNotifications.length,
      itemBuilder: (context, index) {
        final notification = state.sentNotifications[index];
        final sentAt = notification['sentAt'] as Timestamp?;
        final status = notification['status'] as String? ?? 'unknown';

        return _buildNotificationCard(notification, sentAt, status);
      },
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    Timestamp? sentAt,
    String status,
  ) {
    final statusColor = _getStatusColor(status);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? 'Sans titre',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification['body'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.group_rounded, size: 14, color: _textSecondary.withAlpha(150)),
                      const SizedBox(width: 4),
                      Text(
                        _getTargetLabel(notification['targetGroup'] as String? ?? 'all'),
                        style: TextStyle(color: _textSecondary.withAlpha(150), fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time_rounded, size: 14, color: _textSecondary.withAlpha(150)),
                      const SizedBox(width: 4),
                      Text(
                        sentAt != null ? _formatDate(sentAt.toDate()) : 'N/A',
                        style: TextStyle(color: _textSecondary.withAlpha(150), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
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
      case 'sent':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'failed':
        return Icons.error_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Envoyé';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échoué';
      default:
        return status;
    }
  }

  String _getTargetLabel(String target) {
    switch (target) {
      case 'all':
        return 'Tous';
      case 'admins':
        return 'Admins';
      case 'verified':
        return 'Vérifiés';
      case 'business_owners':
        return 'Commerces';
      default:
        return target;
    }
  }

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
            'Chargement...',
            style: TextStyle(color: _textSecondary, fontSize: 14),
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
          Icon(Icons.notifications_off_rounded, size: 64, color: _textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification envoyée',
            style: TextStyle(color: _textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    setState(() => _targetGroup = 'all');
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar('Veuillez remplir le titre et le message', isError: true);
      return;
    }

    final confirm = await _showConfirmation();
    if (confirm == true) {
      final currentAdmin = ref.read(currentAdminProvider);
      if (currentAdmin == null) {
        _showSnackBar('Erreur: Admin non connecté', isError: true);
        return;
      }
      await ref.read(adminNotificationNotifierProvider.notifier).sendGlobalNotification(
        title: _titleController.text,
        body: _bodyController.text,
        targetGroup: _targetGroup,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _clearForm();
    }
  }

  Future<bool?> _showConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer l\'envoi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vous êtes sur le point d\'envoyer une notification à:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getTargetLabel(_targetGroup),
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Titre: ${_titleController.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Message: ${_bodyController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? const Color(0xFF10B981)
            : isError
                ? const Color(0xFFEF4444)
                : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
