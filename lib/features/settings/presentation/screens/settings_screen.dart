import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/services/currency_provider.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_export_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/presentation/widgets/chat_background_picker_modal.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/models/chat_background_model.dart';
import '../../domain/entities/chat_background_entity.dart';
import '../providers/notification_preferences_provider.dart';
import '../widgets/blocked_users_modal.dart';
import '../widgets/bug_report_dialog.dart';
import '../../../../core/services/app_version_service.dart';

/// Écran de réglages dédié (§10b) : « Qui vous voit », Sécurité, Application,
/// puis une zone sensible isolée pour déconnexion/suppression. ProfileScreen
/// n'affiche plus que 3 entrées condensées qui renvoient ici.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Version de l'app, lue sur le paquet installé plutôt qu'écrite en dur.
  /// Chaîne vide tant qu'elle n'est pas résolue : on n'affiche alors que le
  /// libellé, jamais un numéro inventé.
  String _versionLabel(AppLocalizations l10n) {
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    return version.isEmpty ? l10n.version : '${l10n.version} $version';
  }

  bool _profileVisible = true;
  bool _locationEnabled = true;
  bool _showOnlineStatus = true;
  bool _notificationsEnabled = true;
  bool _noiseSuppressionEnabled = true;
  bool _dataSaverMode = false;
  ChatBackgroundEntity? _globalBackground;
  bool _isExportingData = false;

  @override
  void initState() {
    super.initState();
    _noiseSuppressionEnabled =
        PreferencesService.instance.noiseSuppressionEnabled;
    _dataSaverMode = PreferencesService.instance.dataSaverMode;
    _loadGlobalBackground();
  }

  Future<void> _loadGlobalBackground() async {
    try {
      final bgJson = PreferencesService.instance.defaultChatBackground;
      if (bgJson != null && bgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(bgJson));
        if (mounted) {
          setState(() => _globalBackground = model.toEntity());
        }
      }
    } catch (_) {
      // Ignore : fond par défaut conservé.
    }
  }

  Future<void> _showGlobalBackgroundPicker() async {
    HapticFeedback.lightImpact();
    final result = await ChatBackgroundPickerModal.show(
      context,
      currentBackground: _globalBackground,
    );
    if (result != null && mounted) {
      setState(() => _globalBackground = result);
    }
  }

  String _backgroundSubtitle(AppLocalizations l10n) {
    final bg = _globalBackground;
    if (bg == null || bg.isDefault) return l10n.defaultTheme;
    if (bg.isColor) return 'Couleur personnalisée';
    return 'Image personnalisée';
  }

  void _toggleNoiseSuppression(bool value) {
    HapticFeedback.lightImpact();
    setState(() => _noiseSuppressionEnabled = value);
    PreferencesService.instance.setNoiseSuppressionEnabled(value);
  }

  void _toggleDataSaverMode(bool value) {
    HapticFeedback.lightImpact();
    setState(() => _dataSaverMode = value);
    PreferencesService.instance.setDataSaverMode(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;

    if (currentUser != null) {
      ref.listen(profileNotifierProvider(currentUser.id), (previous, next) {
        next.whenData((profile) {
          if (profile != null && mounted) {
            setState(() {
              _profileVisible = profile.isVisible;
              _locationEnabled = profile.shareLocation;
              _showOnlineStatus = profile.showOnlineStatus;
              _notificationsEnabled = profile.notificationsEnabled;
            });
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Qui vous voit
          _buildSectionHeader(l10n.whoSeesYou, Icons.visibility_outlined),
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                icon: const Icon(Icons.visibility_outlined),
                title: l10n.visibleProfile,
                subtitle: l10n.appearInSearchesDesc,
                value: _profileVisible,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _profileVisible = value);
                  _saveSettingsToProfile();
                },
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: const Icon(Icons.location_on_outlined),
                title: l10n.myLocation,
                subtitle: l10n.appearOnMapDesc,
                value: _locationEnabled,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _locationEnabled = value);
                  _saveSettingsToProfile();
                },
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: const Icon(Icons.circle_outlined),
                title: l10n.profileShowOnlineStatus,
                subtitle: l10n.profileShowOnlineStatusSubtitle,
                value: _showOnlineStatus,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _showOnlineStatus = value);
                  _saveSettingsToProfile();
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Sécurité
          _buildSectionHeader(l10n.security, Icons.shield_outlined),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: const Icon(Icons.lock_outline),
                title: l10n.keyBackup,
                subtitle: l10n.keyBackupSubtitle,
                onTap: () => context.push('/settings/security/backup'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.devices_outlined),
                title: l10n.connectedDevices,
                subtitle: l10n.connectedDevicesSubtitle,
                onTap: () => context.push('/settings/security/devices'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.block_outlined),
                title: l10n.blockedUsers,
                onTap: () => _showBlockedUsers(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.flag_outlined),
                title: l10n.myReports,
                subtitle: l10n.myReportsSubtitle,
                onTap: () => context.push('/settings/my-reports'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Application
          _buildSectionHeader(l10n.application, Icons.tune_outlined),
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                icon: const Icon(Icons.notifications_active_outlined),
                title: l10n.pushNotifications,
                subtitle: l10n.receiveNotificationsDesc,
                value: _notificationsEnabled,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _notificationsEnabled = value);
                  _updateNotificationSettings(value);
                },
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.tune),
                title: l10n.notificationPreferences,
                onTap: () => _showNotificationPreferences(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.palette_outlined),
                title: l10n.theme,
                subtitle: _getThemeLabel(
                  ref.watch(themeModeNotifierProvider),
                  l10n,
                ),
                onTap: () => _showThemeSelector(l10n),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.translate_outlined),
                title: l10n.language,
                subtitle:
                    ref
                        .watch(localeNotifierProvider.notifier)
                        .currentLocaleName,
                onTap: () => _showLanguageSelector(l10n),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.attach_money),
                title: l10n.displayCurrency,
                subtitle: _getCurrencyLabel(
                  ref.watch(selectedDisplayCurrencyProvider),
                ),
                onTap: () => _showCurrencySelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.wallpaper_outlined),
                title: l10n.chatBackground,
                subtitle: _backgroundSubtitle(l10n),
                onTap: () => _showGlobalBackgroundPicker(),
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: const Icon(Icons.graphic_eq),
                title: l10n.noiseSuppression,
                subtitle: l10n.noiseSuppressionSubtitle,
                value: _noiseSuppressionEnabled,
                onChanged: _toggleNoiseSuppression,
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: const Icon(Icons.data_saver_on_outlined),
                title: l10n.dataSaverMode,
                subtitle: l10n.dataSaverModeSubtitle,
                value: _dataSaverMode,
                onChanged: _toggleDataSaverMode,
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.support_agent_outlined),
                title: l10n.helpFaq,
                onTap: () => _showHelpSupport(l10n),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.info_outline),
                title: l10n.about,
                subtitle: _versionLabel(l10n),
                onTap: () => _showAbout(l10n),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.article_outlined),
                title: l10n.termsOfService,
                onTap: () => context.push('/settings/terms'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.privacy_tip_outlined),
                title: l10n.privacyPolicy,
                onTap: () => context.push('/settings/privacy'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.gavel_outlined),
                title: l10n.codeOfConduct,
                onTap: () => context.push('/settings/code-of-conduct'),
              ),
              const _SettingsDivider(),
              // Droit à la portabilité (RGPD art. 20).
              _SettingsTile(
                icon:
                    _isExportingData
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.download_outlined),
                title: l10n.exportMyData,
                subtitle:
                    _isExportingData
                        ? l10n.exportMyDataPreparing
                        : l10n.exportMyDataSubtitle,
                onTap: _isExportingData ? null : () => _exportMyData(l10n),
              ),
            ],
          ),

          // Accès à la galerie de la refonte (design_v2). En debug
          // uniquement : c'est un outil de travail, il n'a rien à faire
          // dans une version publiée. À retirer avec lib/design_v2/.
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Refonte', Icons.palette_outlined),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: const Icon(Icons.palette_outlined),
                  title: 'Galerie design v2',
                  subtitle: 'Les écrans redessinés, copies de travail',
                  onTap: () => context.push('/design-v2'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Zone sensible isolée
          _buildSectionHeader(
            l10n.dangerZone,
            Icons.warning_amber_rounded,
            isWarning: true,
          ),
          _SettingsCard(
            isDanger: true,
            children: [
              _SettingsTile(
                icon: const Icon(Icons.logout_outlined),
                title: l10n.logout,
                iconColor: AppColors.warning,
                titleColor: AppColors.warning,
                onTap: () => _confirmLogout(l10n),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.delete_outline),
                title: l10n.deleteAccount,
                iconColor: AppColors.error,
                titleColor: AppColors.error,
                onTap: () => _confirmDeleteAccount(l10n),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isWarning
                      ? context.warningColor
                      : context.adaptivePrimaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color:
                  isWarning ? context.warningColor : context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  isWarning ? context.warningColor : context.textTertiaryColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettingsToProfile() async {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user == null) return;

    final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
    if (profile == null) return;

    final updatedProfile = profile.copyWith(
      isVisible: _profileVisible,
      shareLocation: _locationEnabled,
      showOnlineStatus: _showOnlineStatus,
      notificationsEnabled: _notificationsEnabled,
    );

    await ref
        .read(profileNotifierProvider(user.id).notifier)
        .updateProfile(updatedProfile);
  }

  void _updateNotificationSettings(bool enabled) async {
    if (enabled) {
      await NotificationService().subscribeToTopic('general');
    } else {
      await NotificationService().unsubscribeFromTopic('general');
    }
    _saveSettingsToProfile();
  }

  void _showNotificationPreferences() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => const _NotificationPreferencesModal(),
    );
  }

  void _showBlockedUsers() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const BlockedUsersModal(),
    );
  }

  String _getThemeLabel(AppThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case AppThemeMode.light:
        return l10n.light;
      case AppThemeMode.dark:
        return l10n.dark;
      case AppThemeMode.system:
        return l10n.system;
    }
  }

  void _showThemeSelector(AppLocalizations l10n) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Consumer(
            builder: (context, ref, _) {
              final currentMode = ref.watch(themeModeNotifierProvider);
              final currentColor = ref.watch(themeColorNotifierProvider);

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.theme,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      context,
                      l10n.light,
                      AppThemeMode.light,
                      currentMode,
                      Icons.wb_sunny_outlined,
                    ),
                    _buildThemeOption(
                      context,
                      l10n.dark,
                      AppThemeMode.dark,
                      currentMode,
                      Icons.nightlight_round_outlined,
                    ),
                    _buildThemeOption(
                      context,
                      l10n.system,
                      AppThemeMode.system,
                      currentMode,
                      Icons.brightness_auto_outlined,
                    ),
                    if (currentMode != AppThemeMode.dark) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Apparence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textTertiaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeColorOption(
                        'Vert (Défaut)',
                        AppThemeColor.green,
                        currentColor == AppThemeColor.green,
                      ),
                      _buildThemeColorOption(
                        'Orange (Classique)',
                        AppThemeColor.orange,
                        currentColor == AppThemeColor.orange,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    AppThemeMode value,
    AppThemeMode groupValue,
    IconData icon,
  ) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSelected ? context.adaptivePrimaryColor : context.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              isSelected
                  ? context.adaptivePrimaryColor
                  : context.textSecondaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.textPrimaryColor,
          ),
        ),
        trailing:
            isSelected
                ? Icon(Icons.check_circle, color: context.adaptivePrimaryColor)
                : null,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeNotifierProvider.notifier).setThemeMode(value);
        },
      ),
    );
  }

  Widget _buildThemeColorOption(
    String title,
    AppThemeColor color,
    bool isSelected,
  ) {
    final Color previewColor =
        color == AppThemeColor.green ? AppColors.secondary : AppColors.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor:
          isSelected
              ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
              : null,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: previewColor,
          shape: BoxShape.circle,
          border: Border.all(color: context.borderColor),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color:
              isSelected
                  ? context.adaptivePrimaryColor
                  : context.textPrimaryColor,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: context.adaptivePrimaryColor)
              : null,
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(themeColorNotifierProvider.notifier).setThemeColor(color);
      },
    );
  }

  void _showLanguageSelector(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    final currentLocale = ref.read(localeNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ctx.adaptivePrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.translate,
                        color: ctx.adaptivePrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.chooseLanguage,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ctx.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLanguageOption(
                  ctx,
                  l10n.french,
                  'FR',
                  const Locale('fr'),
                  currentLocale.languageCode == 'fr',
                ),
                _buildLanguageOption(
                  ctx,
                  l10n.english,
                  'EN',
                  const Locale('en'),
                  currentLocale.languageCode == 'en',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx,
    String language,
    String code,
    Locale locale,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? ctx.adaptivePrimaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? ctx.adaptivePrimaryColor : ctx.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isSelected ? ctx.adaptivePrimaryColor : ctx.surfaceVariantColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.white : ctx.textSecondaryColor,
              ),
            ),
          ),
        ),
        title: Text(
          language,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? ctx.adaptivePrimaryColor : ctx.textPrimaryColor,
          ),
        ),
        trailing:
            isSelected
                ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ctx.adaptivePrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.white,
                    size: 16,
                  ),
                )
                : null,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(localeNotifierProvider.notifier).setLocale(locale);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getCurrencyLabel(Currency currency) {
    return '${currency.symbol} ${currency.code} - ${currency.name}';
  }

  void _showCurrencySelector() {
    HapticFeedback.lightImpact();
    final currentCurrency = ref.read(selectedDisplayCurrencyProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => _CurrencySelectorModal(
            currentCurrency: currentCurrency,
            onSelect: (currency) {
              ref
                  .read(selectedDisplayCurrencyProvider.notifier)
                  .select(currency);
              Navigator.pop(ctx);
            },
          ),
    );
  }

  /// Export RGPD (art. 20) : l'Edge Function `export-my-data` agrège les
  /// données, le service écrit le JSON et ouvre la feuille de partage.
  Future<void> _exportMyData(AppLocalizations l10n) async {
    if (_isExportingData) return;
    setState(() => _isExportingData = true);

    try {
      await DataExportService.instance.exportAndShare();
    } on DataExportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportMyDataFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  void _showHelpSupport(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    final supportService = SupportService();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ctx.adaptiveSecondaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.support_agent,
                          color: ctx.adaptiveSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.helpAndSupport,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ctx.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // FAQ en accordéon, première réponse dépliée (§21d).
                  Theme(
                    data: Theme.of(
                      ctx,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: Column(
                      children: [
                        _FaqItem(
                          question: l10n.faqEncryptionQ,
                          answer: l10n.faqEncryptionA,
                          initiallyExpanded: true,
                        ),
                        _FaqItem(
                          question: l10n.faqLocationQ,
                          answer: l10n.faqLocationA,
                        ),
                        _FaqItem(
                          question: l10n.faqReportQ,
                          answer: l10n.faqReportA,
                        ),
                        _FaqItem(
                          question: l10n.faqTransferQ,
                          answer: l10n.faqTransferA,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.email_outlined,
                    title: l10n.contactUs,
                    subtitle: l10n.supportEmail,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await supportService.sendContactEmail();
                    },
                  ),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.bug_report_outlined,
                    title: l10n.reportBug,
                    subtitle: l10n.helpUsImprove,
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        builder: (context) => const BugReportDialog(),
                      );
                    },
                  ),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.star_outline,
                    title: l10n.giveFeedback,
                    subtitle: l10n.rateUsOnStore,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await supportService.openStoreForReview();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }

  void _showAbout(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: context.adaptivePrimaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people,
                    color: AppColors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _versionLabel(l10n),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.mobileAppDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.allRightsReserved,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _confirmLogout(AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Text(l10n.logout),
              ],
            ),
            content: Text(l10n.confirmLogout),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final router = GoRouter.of(context);
                  navigator.pop();
                  final currentUser =
                      ref.read(currentUserAsyncProvider).valueOrNull;
                  if (currentUser != null) {
                    await NotificationService().removeTokenForUser(
                      currentUser.id,
                    );
                  }
                  await ref.read(authNotifierProvider.notifier).signOut();
                  router.go('/auth/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.logout),
              ),
            ],
          ),
    );
  }

  void _confirmDeleteAccount(AppLocalizations l10n) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.deleteAccountTitle),
              ],
            ),
            content: Text(l10n.deleteAccountWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFinalDeleteConfirmation(l10n);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
    );
  }

  void _showFinalDeleteConfirmation(AppLocalizations l10n) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(l10n.finalConfirmation),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.typeDeleteToConfirm),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmController,
                      decoration: InputDecoration(
                        hintText: l10n.deleteKeyword,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      confirmController.dispose();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        confirmController.text == l10n.deleteKeyword
                            ? () async {
                              Navigator.pop(context);
                              await _deleteAccount(l10n);
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(l10n.deletePermanently),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _deleteAccount(AppLocalizations l10n) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.deletingAccount)),
              ],
            ),
          ),
    );

    try {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser != null) {
        await NotificationService().removeTokenForUser(currentUser.id);
      }

      final success =
          await ref.read(authNotifierProvider.notifier).deleteAccount();

      if (!mounted) return;
      Navigator.pop(context);

      final authState = ref.read(authNotifierProvider);
      final errorMessage = authState.maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

      if (errorMessage != null && errorMessage.startsWith('REAUTH_REQUIRED:')) {
        final actualMessage = errorMessage.substring('REAUTH_REQUIRED:'.length);
        await _showPasswordPromptForDeletion(l10n, actualMessage);
        return;
      }

      if (success) {
        GoRouter.of(context).go('/auth/login');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white),
                const SizedBox(width: 12),
                Text(l10n.accountDeletedSuccess),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: AppColors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(errorMessage ?? l10n.errorDeletingAccount),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showPasswordPromptForDeletion(
    AppLocalizations l10n,
    String message,
  ) async {
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: context.warningColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.confirmPassword,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        hintText: l10n.confirmPasswordRequired,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.adaptivePrimaryColor,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (passwordController.text.isNotEmpty) {
                          _handlePasswordSubmit(passwordController.text, l10n);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      passwordController.dispose();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        passwordController.text.isEmpty
                            ? null
                            : () {
                              _handlePasswordSubmit(
                                passwordController.text,
                                l10n,
                              );
                              passwordController.dispose();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _handlePasswordSubmit(
    String password,
    AppLocalizations l10n,
  ) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.deletingAccount)),
              ],
            ),
          ),
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .reauthenticateAndDelete(password);

    if (!mounted) return;

    Navigator.pop(context);

    if (success) {
      GoRouter.of(context).go('/auth/login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.white),
              const SizedBox(width: 12),
              Text(l10n.accountDeletedSuccess),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      final authState = ref.read(authNotifierProvider);
      final errorMessage = authState.maybeWhen(
        error: (msg) => msg,
        orElse: () => l10n.errorDeletingAccount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: AppColors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDanger;

  const _SettingsCard({required this.children, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            isDanger
                ? Border.all(color: AppColors.error.withValues(alpha: 0.2))
                : null,
        boxShadow: [
          BoxShadow(
            color: (isDanger ? AppColors.error : Colors.black).withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (iconColor ?? context.adaptivePrimaryColor).withValues(
                        alpha: 0.15,
                      ),
                      (iconColor ?? context.adaptivePrimaryColor).withValues(
                        alpha: 0.05,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: 18,
                      color: iconColor ?? context.adaptivePrimaryColor,
                    ),
                    child: icon,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? context.textPrimaryColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: context.textTertiaryColor,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor)
                      .withValues(alpha: 0.15),
                  (value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor)
                      .withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 18,
                  color:
                      value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor,
                ),
                child: icon,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.adaptivePrimaryColor,
            activeTrackColor: context.adaptivePrimaryColor.withValues(
              alpha: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        color: context.borderColor.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Entrée de FAQ en accordéon (§21d).
class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;
  final bool initiallyExpanded;

  const _FaqItem({
    required this.question,
    required this.answer,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: context.textPrimaryColor,
        ),
      ),
      iconColor: context.adaptivePrimaryColor,
      collapsedIconColor: context.textTertiaryColor,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpOption extends StatelessWidget {
  final BuildContext ctx;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpOption({
    required this.ctx,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ctx.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ctx.adaptiveSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ctx.adaptiveSecondaryColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ctx.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: ctx.textSecondaryColor),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: ctx.textTertiaryColor,
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

class _NotificationPreferencesModal extends ConsumerWidget {
  const _NotificationPreferencesModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SheetHandle()),
          const SizedBox(height: 20),
          Text(
            l10n.notificationPreferences,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildNotificationOption(
            context,
            l10n.messages,
            prefs.messagesEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setMessagesEnabled(value),
          ),
          _buildNotificationOption(
            context,
            l10n.newEvents,
            prefs.eventsEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setEventsEnabled(value),
          ),
          _buildNotificationOption(
            context,
            l10n.friends,
            prefs.friendRequestsEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setFriendRequestsEnabled(value),
          ),
          _buildNotificationOption(
            context,
            l10n.groupActivity,
            prefs.groupsEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setGroupsEnabled(value),
          ),
          _buildNotificationOption(
            context,
            l10n.eventReminders,
            prefs.eventRemindersEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setEventRemindersEnabled(value),
          ),
          const SizedBox(height: 16),
          Divider(color: context.borderColor),
          const SizedBox(height: 16),
          Text(
            'Son et Vibration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationOption(
            context,
            'Son',
            prefs.soundEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setSoundEnabled(value),
          ),
          _buildNotificationOption(
            context,
            'Vibration',
            prefs.vibrationEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setVibrationEnabled(value),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNotificationOption(
    BuildContext context,
    String title,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: context.textPrimaryColor),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sélecteur de devise avec catégories et recherche
// ============================================================================

class _CurrencySelectorModal extends StatefulWidget {
  final Currency currentCurrency;
  final void Function(Currency) onSelect;

  const _CurrencySelectorModal({
    required this.currentCurrency,
    required this.onSelect,
  });

  @override
  State<_CurrencySelectorModal> createState() => _CurrencySelectorModalState();
}

class _CurrencySelectorModalState extends State<_CurrencySelectorModal> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const _categories = <String, List<Currency>>{
    'Devises principales': [
      Currency.xof,
      Currency.eur,
      Currency.usd,
      Currency.gbp,
      Currency.cad,
      Currency.chf,
    ],
    'Afrique': [
      Currency.xaf,
      Currency.ngn,
      Currency.ghs,
      Currency.mad,
      Currency.zar,
      Currency.kes,
      Currency.egp,
      Currency.tzs,
      Currency.etb,
    ],
    'Asie': [
      Currency.cny,
      Currency.jpy,
      Currency.inr,
      Currency.krw,
      Currency.sgd,
      Currency.hkd,
      Currency.thb,
      Currency.myr,
      Currency.php,
      Currency.idr,
      Currency.vnd,
      Currency.pkr,
    ],
    'Europe': [
      Currency.sek,
      Currency.nok,
      Currency.dkk,
      Currency.pln,
      Currency.czk,
      Currency.try_,
      Currency.rub,
    ],
    'Ameriques': [
      Currency.mxn,
      Currency.ars,
      Currency.clp,
      Currency.cop,
      Currency.brl,
    ],
    'Oceanie & Moyen-Orient': [
      Currency.aud,
      Currency.nzd,
      Currency.aed,
      Currency.sar,
      Currency.qar,
      Currency.kwd,
    ],
  };

  List<Currency> get _filteredCurrencies {
    if (_searchQuery.isEmpty) {
      return Currency.values;
    }
    final query = _searchQuery.toLowerCase();
    return Currency.values.where((c) {
      return c.code.toLowerCase().contains(query) ||
          c.name.toLowerCase().contains(query) ||
          c.symbol.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSearching = _searchQuery.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SheetHandle(),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chooseCurrency,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.displayCurrencySubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchCurrency,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    isSearching
                        ? _buildSearchResults(scrollController)
                        : _buildCategorizedList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    final currencies = _filteredCurrencies;

    if (currencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: context.textTertiaryColor),
            const SizedBox(height: 16),
            Text(
              'Aucune devise trouvée',
              style: TextStyle(color: context.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: currencies.length,
      itemBuilder: (context, index) {
        final currency = currencies[index];
        return _buildCurrencyTile(currency);
      },
    );
  }

  Widget _buildCategorizedList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final entry in _categories.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textTertiaryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...entry.value.map((currency) => _buildCurrencyTile(currency)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCurrencyTile(Currency currency) {
    final isSelected = currency == widget.currentCurrency;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                  : context.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(currency.flag, style: const TextStyle(fontSize: 22)),
        ),
      ),
      title: Row(
        children: [
          Text(
            currency.code,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            currency.symbol,
            style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
          ),
        ],
      ),
      subtitle: Text(
        currency.name,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: context.adaptivePrimaryColor)
              : null,
      onTap: () => widget.onSelect(currency),
    );
  }
}
