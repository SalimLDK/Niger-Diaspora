import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../providers/app_settings_provider.dart';

class AdminFeatureFlagsScreen extends ConsumerStatefulWidget {
  const AdminFeatureFlagsScreen({super.key});

  @override
  ConsumerState<AdminFeatureFlagsScreen> createState() =>
      _AdminFeatureFlagsScreenState();
}

class _AdminFeatureFlagsScreenState
    extends ConsumerState<AdminFeatureFlagsScreen> {
  static const _primaryColor = Color(0xFF6366F1);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF1E293B);
  static const _textSecondary = Color(0xFF64748B);
  static const _backgroundColor = Color(0xFFF8FAFC);

  FeatureFlagsEntity? _localFlags;
  bool _hasChanges = false;
  bool _isSaving = false;
  final _maintenanceMessageController = TextEditingController();

  FeatureFlagsEntity get _flags => _localFlags ?? const FeatureFlagsEntity();

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    super.dispose();
  }

  void _initializeFromSettings(FeatureFlagsEntity flags) {
    if (_localFlags == null) {
      _localFlags = flags;
      _maintenanceMessageController.text = flags.maintenanceMessage ?? '';
    }
  }

  void _updateFlag(FeatureFlagsEntity newFlags) {
    setState(() {
      _localFlags = newFlags;
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Vous devez etre connecte pour sauvegarder');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(appSettingsNotifierProvider.notifier)
          .updateFeatureFlags(_flags, user.uid);

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Feature flags mis a jour'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Erreur lors de la sauvegarde: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsNotifierProvider);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _primaryColor, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Feature Flags',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryColor, Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _save,
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Sauvegarder',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (settings) {
          // Initialize local state from settings only once
          _initializeFromSettings(settings.featureFlags);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMaintenanceSection(),
                const SizedBox(height: 32),
                _buildFeaturesSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    final isMaintenanceOn = _flags.maintenanceMode;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isMaintenanceOn ? Colors.red.shade50 : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isMaintenanceOn ? Border.all(color: Colors.red.shade200, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isMaintenanceOn
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isMaintenanceOn
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [Colors.grey.shade400, Colors.grey.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Maintenance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMaintenanceOn ? 'Application en maintenance' : 'Application active',
                      style: TextStyle(
                        fontSize: 13,
                        color: isMaintenanceOn ? Colors.red.shade600 : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: _flags.maintenanceMode,
                  activeThumbColor: Colors.red,
                  activeTrackColor: Colors.red.shade200,
                  onChanged: (value) {
                    _updateFlag(_flags.copyWith(maintenanceMode: value));
                  },
                ),
              ),
            ],
          ),
          if (isMaintenanceOn) ...[
            const SizedBox(height: 24),
            Text(
              'Message affiche aux utilisateurs',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maintenanceMessageController,
              decoration: InputDecoration(
                hintText: 'Ex: Application en maintenance...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
              maxLines: 2,
              onChanged: (value) {
                _updateFlag(_flags.copyWith(
                  maintenanceMessage: value.isEmpty ? null : value,
                ));
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'L\'application sera inaccessible pour tous les utilisateurs non-admin!',
                      style: TextStyle(
                        color: Colors.red.shade800,
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
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.toggle_on_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonctionnalites',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Activez ou desactivez les modules',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFeatureToggle(
          title: 'Transfert d\'argent',
          subtitle: 'Envoi d\'argent vers le Niger',
          icon: Icons.send_rounded,
          color: const Color(0xFF10B981),
          value: _flags.moneyTransfer,
          onChanged: (v) => _updateFlag(_flags.copyWith(moneyTransfer: v)),
        ),
        _buildFeatureToggle(
          title: 'Marketplace',
          subtitle: 'Achat et vente de produits',
          icon: Icons.storefront_rounded,
          color: const Color(0xFFF59E0B),
          value: _flags.marketplace,
          onChanged: (v) => _updateFlag(_flags.copyWith(marketplace: v)),
        ),
        _buildFeatureToggle(
          title: 'Annuaire Entreprises',
          subtitle: 'Repertoire des entreprises nigeriennes',
          icon: Icons.business_rounded,
          color: const Color(0xFF3B82F6),
          value: _flags.businessDirectory,
          onChanged: (v) => _updateFlag(_flags.copyWith(businessDirectory: v)),
        ),
        _buildFeatureToggle(
          title: 'Evenements',
          subtitle: 'Creation et participation aux evenements',
          icon: Icons.event_rounded,
          color: const Color(0xFF8B5CF6),
          value: _flags.events,
          onChanged: (v) => _updateFlag(_flags.copyWith(events: v)),
        ),
        _buildFeatureToggle(
          title: 'Groupes',
          subtitle: 'Creation et gestion des groupes',
          icon: Icons.groups_rounded,
          color: const Color(0xFFEC4899),
          value: _flags.groups,
          onChanged: (v) => _updateFlag(_flags.copyWith(groups: v)),
        ),
        _buildFeatureToggle(
          title: 'Ambassades',
          subtitle: 'Services consulaires et ambassades',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF06B6D4),
          value: _flags.embassies,
          onChanged: (v) => _updateFlag(_flags.copyWith(embassies: v)),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: value
                ? color.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: value ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? color : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              activeThumbColor: color,
              activeTrackColor: color.withValues(alpha: 0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
