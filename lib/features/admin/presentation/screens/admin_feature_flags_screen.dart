import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../providers/app_settings_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class AdminFeatureFlagsScreen extends ConsumerStatefulWidget {
  const AdminFeatureFlagsScreen({super.key});

  @override
  ConsumerState<AdminFeatureFlagsScreen> createState() =>
      _AdminFeatureFlagsScreenState();
}

class _AdminFeatureFlagsScreenState
    extends ConsumerState<AdminFeatureFlagsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;
  static const _backgroundColor = AdminColors.bg;

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
      _showError(l10n.adminMustBeConnected);
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
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(l10n.adminFeatureFlagsUpdated),
              ],
            ),
            backgroundColor: AdminColors.statusGreen,
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
        backgroundColor: AdminColors.statusRed,
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
          l10n.adminFeatureFlags,
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
                          colors: [_primaryColor, AdminColors.actionBlueLight],
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
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  l10n.e2eeBackupNudgeAction,
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
          color: AdminColors.statusRedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.alertBorderRed),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.statusRedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.error_outline, color: AdminColors.statusRedStrong, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.adminLoadingError,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.statusRedStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(color: AdminColors.statusRed),
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
        color: isMaintenanceOn ? AdminColors.statusRedBg : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isMaintenanceOn ? Border.all(color: AdminColors.alertBorderRed, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isMaintenanceOn
                ? AdminColors.statusRed.withValues(alpha: 0.1)
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
                        ? [AdminColors.statusRed, AdminColors.statusRedStrong]
                        : [AdminColors.statusGray, AdminColors.statusGray],
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
                      l10n.adminMaintenanceMode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMaintenanceOn ? l10n.adminMaintenanceActive : l10n.adminMaintenanceInactive,
                      style: TextStyle(
                        fontSize: 13,
                        color: isMaintenanceOn ? AdminColors.statusRed : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: _flags.maintenanceMode,
                  activeThumbColor: AdminColors.statusRed,
                  activeTrackColor: AdminColors.alertBorderRed,
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
                hintText: l10n.adminMaintenanceHint,
                hintStyle: TextStyle(color: AdminColors.text3),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AdminColors.alertBorderRed),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AdminColors.alertBorderRed),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AdminColors.statusRed, width: 2),
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
                color: AdminColors.statusRedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AdminColors.statusRedStrong, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'L\'application sera inaccessible pour tous les utilisateurs non-admin!',
                      style: TextStyle(
                        color: AdminColors.statusRedStrong,
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
                  colors: [_primaryColor, AdminColors.actionBlueLight],
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
                  l10n.adminFeaturesSubtitle,
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
          color: AdminColors.statusGreen,
          value: _flags.moneyTransfer,
          onChanged: (v) => _updateFlag(_flags.copyWith(moneyTransfer: v)),
        ),
        _buildFeatureToggle(
          title: l10n.adminMarketplace,
          subtitle: l10n.featureMarketplaceDesc,
          icon: Icons.storefront_rounded,
          color: AdminColors.statusAmber,
          value: _flags.marketplace,
          onChanged: (v) => _updateFlag(_flags.copyWith(marketplace: v)),
        ),
        // Annuaire et ambassades : toujours actifs dans l'app depuis le
        // 2026-08-19 (feature_flag_service.dart ignore ces flags). Interrupteur
        // désactivé plutôt que retiré : un interrupteur qui n'agit plus sur
        // rien mais reste manœuvrable est un mensonge d'interface.
        _buildFeatureToggle(
          title: l10n.featureBusinessDirectory,
          subtitle: 'Toujours actif — ce flag n\'est plus consulté par l\'app',
          icon: Icons.business_rounded,
          color: AdminColors.actionBlueLight,
          value: true,
          onChanged: null,
        ),
        _buildFeatureToggle(
          title: l10n.adminEventsLabel,
          subtitle: l10n.featureEventsDesc,
          icon: Icons.event_rounded,
          color: AdminColors.statusPurple,
          value: _flags.events,
          onChanged: (v) => _updateFlag(_flags.copyWith(events: v)),
        ),
        _buildFeatureToggle(
          title: l10n.adminGroupsLabel,
          subtitle: l10n.featureGroupsDesc,
          icon: Icons.groups_rounded,
          color: AdminColors.statusPurple,
          value: _flags.groups,
          onChanged: (v) => _updateFlag(_flags.copyWith(groups: v)),
        ),
        _buildFeatureToggle(
          title: l10n.adminEmbassies,
          subtitle: 'Toujours actif — ce flag n\'est plus consulté par l\'app',
          icon: Icons.account_balance_rounded,
          color: AdminColors.statusGreen,
          value: true,
          onChanged: null,
        ),
        // Sans ces deux interrupteurs, audioRooms et podcasts restaient bloques
        // sur leur valeur par defaut (false) : /audio-rooms et /podcasts
        // etaient renvoyes sur /home sans aucun moyen de les activer.
        _buildFeatureToggle(
          title: 'Salons audio',
          subtitle: 'Salons audio en direct et replays',
          icon: Icons.podcasts_rounded,
          color: AdminColors.statusPurple,
          value: _flags.audioRooms,
          onChanged: (v) => _updateFlag(_flags.copyWith(audioRooms: v)),
        ),
        _buildFeatureToggle(
          title: l10n.podcasts,
          subtitle: 'Emissions, episodes et enregistrement',
          icon: Icons.mic_rounded,
          color: AdminColors.actionBlueLight,
          value: _flags.podcasts,
          onChanged: (v) => _updateFlag(_flags.copyWith(podcasts: v)),
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
    // null = fonctionnalité toujours active : l'interrupteur s'affiche
    // grisé/verrouillé (comportement natif de Switch.onChanged null).
    required ValueChanged<bool>? onChanged,
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
              color: value ? color.withValues(alpha: 0.1) : AdminColors.statusGrayBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? color : AdminColors.statusGray,
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
