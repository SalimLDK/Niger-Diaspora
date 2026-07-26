import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/services/currency_provider.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../widgets/blocked_users_modal.dart';
import '../widgets/bug_report_dialog.dart';
import '../../../messages/presentation/widgets/chat_background_picker_modal.dart';
import '../../domain/entities/chat_background_entity.dart';
import 'dart:convert';
import '../../data/models/chat_background_model.dart';
import '../../../../core/services/preferences_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _profileVisible = true;
  ChatBackgroundEntity? _globalBackground;

  @override
  void initState() {
    super.initState();
    // Profile loading and syncing is handled by ref.listen in build
    _loadGlobalBackground();
  }

  Future<void> _loadGlobalBackground() async {
    try {
      final prefs = PreferencesService.instance;
      final bgJson = prefs.defaultChatBackground;

      if (bgJson != null && bgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(bgJson));
        if (mounted) {
          setState(() {
            _globalBackground = model.toEntity();
          });
        }
      }
    } catch (e) {
      // debugPrint('Error loading global background: $e');
    }
  }

  Future<void> _showGlobalBackgroundPicker() async {
    final result = await ChatBackgroundPickerModal.show(
      context,
      currentBackground: _globalBackground,
    );

    if (result != null) {
      setState(() {
        _globalBackground = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    if (currentUser != null) {
      ref.listen(profileNotifierProvider(currentUser.id), (previous, next) {
        next.whenData((profile) {
          if (profile != null) {
            setState(() {
              _notificationsEnabled = profile.notificationsEnabled;
              _locationEnabled = profile.shareLocation;
              _profileVisible = profile.isVisible;
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
          // Profile Section
          _buildSectionHeader(l10n.account),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: const AppIcon(AppIcon.person),
                title: l10n.editProfile,
                subtitle: currentUser?.displayName ?? l10n.myProfile,
                onTap: () => context.push('/profile/edit'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.email),
                title: l10n.email,
                subtitle: currentUser?.email ?? l10n.notDefined,
                showArrow: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(l10n.notifications),
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                icon: Icons.notifications,
                title: l10n.pushNotifications,
                subtitle: l10n.receiveNotifications,
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _updateNotificationSettings(value);
                },
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.notifications_active),
                title: l10n.notificationPreferences,
                onTap: () => _showNotificationPreferences(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader(l10n.privacy),
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                icon: Icons.visibility,
                title: l10n.visibleProfile,
                subtitle: l10n.appearInSearches,
                value: _profileVisible,
                onChanged: (value) {
                  setState(() => _profileVisible = value);
                  _updatePrivacySettings('isVisible', value);
                },
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: Icons.location_on,
                title: l10n.shareLocation,
                subtitle: l10n.appearOnMap,
                value: _locationEnabled,
                onChanged: (value) {
                  setState(() => _locationEnabled = value);
                  _updatePrivacySettings('shareLocation', value);
                },
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.block),
                title: l10n.blockedUsers,
                onTap: () => _showBlockedUsers(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const AppIcon(AppIcon.flag),
                title: 'Mes signalements',
                subtitle: 'Voir l\'historique de vos signalements',
                onTap: () => context.push('/settings/my-reports'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App Section
          _buildSectionHeader(l10n.application),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: const Icon(Icons.dark_mode),
                title: l10n.theme,
                subtitle: _getThemeLabel(
                  ref.watch(themeModeNotifierProvider),
                  l10n,
                ),
                onTap: () => _showThemeSelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.palette),
                title: 'Couleur du thème',
                subtitle: _getThemeColorLabel(
                  ref.watch(themeColorNotifierProvider),
                ),
                onTap: () => _showThemeColorSelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.language),
                title: l10n.language,
                subtitle:
                    ref
                        .watch(localeNotifierProvider.notifier)
                        .currentLocaleName,
                onTap: () => _showLanguageSelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.attach_money),
                title: 'Devise',
                subtitle: _getCurrencyLabel(
                  ref.watch(selectedDisplayCurrencyProvider),
                ),
                onTap: () => _showCurrencySelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.wallpaper),
                title: 'Fond d\'écran des conversations',
                subtitle:
                    _globalBackground?.isDefault ?? true
                        ? 'Thème par défaut'
                        : _globalBackground?.isColor ?? false
                        ? 'Couleur personnalisée'
                        : 'Image personnalisée',
                onTap: () => _showGlobalBackgroundPicker(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.help_outline),
                title: l10n.helpAndSupport,
                onTap: () => _showHelpSupport(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const AppIcon(AppIcon.info),
                title: l10n.about,
                subtitle: '${l10n.version} 1.2.0+10',
                onTap: () => _showAbout(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.description),
                title: l10n.termsOfService,
                onTap: () => _showTerms(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.privacy_tip),
                title: l10n.privacyPolicy,
                onTap: () => _showPrivacyPolicy(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const Icon(Icons.gavel),
                title: l10n.codeOfConduct,
                onTap: () => context.push('/settings/code-of-conduct'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionHeader(l10n.dangerZone),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: const Icon(Icons.logout),
                title: l10n.logout,
                iconColor: Colors.orange,
                titleColor: Colors.orange,
                onTap: () => _confirmLogout(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: const AppIcon(AppIcon.delete),
                title: l10n.deleteAccount,
                iconColor: Colors.red,
                titleColor: Colors.red,
                onTap: () => _confirmDeleteAccount(),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.textTertiaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _updateNotificationSettings(bool enabled) async {
    if (enabled) {
      await NotificationService().subscribeToTopic('general');
    } else {
      await NotificationService().unsubscribeFromTopic('general');
    }
    _saveSettingsToProfile();
  }

  void _updatePrivacySettings(String key, bool value) {
    _saveSettingsToProfile();
  }

  Future<void> _saveSettingsToProfile() async {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user == null) return;

    final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
    if (profile == null) return;

    final updatedProfile = profile.copyWith(
      notificationsEnabled: _notificationsEnabled,
      shareLocation: _locationEnabled,
      isVisible: _profileVisible,
    );

    await ref
        .read(profileNotifierProvider(user.id).notifier)
        .updateProfile(updatedProfile);
  }

  void _showNotificationPreferences() {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => const _NotificationPreferencesModal(),
    );
  }

  void _showBlockedUsers() {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      builder: (context) => const BlockedUsersModal(),
    );
  }

  void _showLanguageSelector() {
    final currentLocale = ref.read(localeNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(ctx)!.chooseLanguage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLanguageOption(
                  ctx,
                  AppLocalizations.of(ctx)!.french,
                  const Locale('fr'),
                  currentLocale.languageCode == 'fr',
                ),
                _buildLanguageOption(
                  ctx,
                  AppLocalizations.of(ctx)!.english,
                  const Locale('en'),
                  currentLocale.languageCode == 'en',
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx,
    String language,
    Locale locale,
    bool isSelected,
  ) {
    return ListTile(
      tileColor: ctx.surfaceColor,
      title: Text(
        language,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? ctx.adaptivePrimaryColor : ctx.textPrimaryColor,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check, color: ctx.adaptivePrimaryColor)
              : null,
      onTap: () {
        ref.read(localeNotifierProvider.notifier).setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  String _getCurrencyLabel(Currency currency) {
    return '${currency.symbol} ${currency.code} - ${currency.name}';
  }

  void _showCurrencySelector() {
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

  void _showThemeSelector() {
    final currentMode = ref.read(themeModeNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(ctx)!.chooseTheme,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildThemeOption(
                  ctx,
                  AppLocalizations.of(ctx)!.light,
                  Icons.light_mode,
                  AppThemeMode.light,
                  currentMode == AppThemeMode.light,
                ),
                _buildThemeOption(
                  ctx,
                  AppLocalizations.of(ctx)!.dark,
                  Icons.dark_mode,
                  AppThemeMode.dark,
                  currentMode == AppThemeMode.dark,
                ),
                _buildThemeOption(
                  ctx,
                  AppLocalizations.of(ctx)!.system,
                  Icons.settings_suggest,
                  AppThemeMode.system,
                  currentMode == AppThemeMode.system,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext ctx,
    String title,
    IconData icon,
    AppThemeMode mode,
    bool isSelected,
  ) {
    return ListTile(
      tileColor: ctx.surfaceColor,
      leading: Icon(
        icon,
        color: isSelected ? ctx.adaptivePrimaryColor : ctx.textSecondaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? ctx.adaptivePrimaryColor : ctx.textPrimaryColor,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check, color: ctx.adaptivePrimaryColor)
              : null,
      onTap: () {
        ref.read(themeModeNotifierProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showHelpSupport() {
    final supportService = ref.read(supportServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(ctx)!.helpAndSupport,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  tileColor: ctx.surfaceColor,
                  leading: Icon(Icons.email, color: ctx.adaptivePrimaryColor),
                  title: Text(
                    AppLocalizations.of(ctx)!.contactUs,
                    style: TextStyle(color: ctx.textPrimaryColor),
                  ),
                  subtitle: Text(
                    supportService.supportEmail,
                    style: TextStyle(color: ctx.textSecondaryColor),
                  ),
                  onTap: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final errorText = AppLocalizations.of(context)!.error;
                    Navigator.pop(context);
                    final success = await supportService.sendContactEmail();
                    if (!success) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(errorText),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  tileColor: ctx.surfaceColor,
                  leading: Icon(
                    Icons.bug_report,
                    color: ctx.adaptivePrimaryColor,
                  ),
                  title: Text(
                    AppLocalizations.of(ctx)!.reportBug,
                    style: TextStyle(color: ctx.textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const BugReportDialog(),
                    );
                  },
                ),
                ListTile(
                  tileColor: ctx.surfaceColor,
                  leading: Icon(
                    Icons.feedback,
                    color: ctx.adaptivePrimaryColor,
                  ),
                  title: Text(
                    AppLocalizations.of(ctx)!.giveFeedback,
                    style: TextStyle(color: ctx.textPrimaryColor),
                  ),
                  onTap: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final errorText = AppLocalizations.of(context)!.error;
                    Navigator.pop(context);
                    final success = await supportService.openStoreForReview();
                    if (!success) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(errorText),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _showAbout() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: context.adaptivePrimaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: const TextStyle(fontSize: 18)),
                    const Text(
                      '1.2.0+10',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            content: Text(l10n.appDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showTerms() async {
    final url = Uri.parse('https://diasponiger.com/terms-of-service.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showPrivacyPolicy() async {
    final url = Uri.parse('https://diasponiger.com/privacy-policy.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmLogout() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.logout),
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
                  backgroundColor: AppColors.primary,
                ),
                child: Text(l10n.logout),
              ),
            ],
          ),
    );
  }

  void _confirmDeleteAccount() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.confirmDeleteAccount),
            content: Text(l10n.deleteAccountWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFinalDeleteConfirmation();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
    );
  }

  void _showFinalDeleteConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
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
                              await _deleteAccount();
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: context.adaptivePrimaryColor),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.deletingAccount)),
              ],
            ),
          ),
    );

    try {
      // Remove FCM token first
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser != null) {
        await NotificationService().removeTokenForUser(currentUser.id);
      }

      // Delete account
      final success =
          await ref.read(authNotifierProvider.notifier).deleteAccount();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Navigate to login
        GoRouter.of(context).go('/auth/login');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountDeleted),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getThemeColorLabel(AppThemeColor color) {
    switch (color) {
      case AppThemeColor.green:
        return 'Vert (Défaut)';
      case AppThemeColor.orange:
        return 'Orange (Classique)';
    }
  }

  void _showThemeColorSelector() {
    final currentColor = ref.read(themeColorNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choisir la couleur',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildThemeColorOption(
                  ctx,
                  'Vert (Défaut)',
                  AppThemeColor.green,
                  currentColor == AppThemeColor.green,
                ),
                _buildThemeColorOption(
                  ctx,
                  'Orange (Classique)',
                  AppThemeColor.orange,
                  currentColor == AppThemeColor.orange,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildThemeColorOption(
    BuildContext ctx,
    String title,
    AppThemeColor color,
    bool isSelected,
  ) {
    // Determine the color to show in the circle
    final Color previewColor =
        color == AppThemeColor.green
            ? AppColors
                .secondary // Green
            : AppColors.primary; // Orange

    return ListTile(
      tileColor: ctx.surfaceColor,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: previewColor,
          shape: BoxShape.circle,
          border: Border.all(color: ctx.borderColor),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? ctx.adaptivePrimaryColor : ctx.textPrimaryColor,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check, color: ctx.adaptivePrimaryColor)
              : null,
      onTap: () {
        ref.read(themeColorNotifierProvider.notifier).setThemeColor(color);
        Navigator.pop(context);
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            context.isDarkMode
                ? Border.all(color: context.borderColor, width: 1)
                : null,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
  final bool showArrow;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showArrow = true,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.adaptivePrimaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: effectiveIconColor),
                  child: icon,
                ),
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
                      fontWeight: FontWeight.w500,
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
            if (showArrow && onTap != null)
              Icon(Icons.chevron_right, color: context.textTertiaryColor),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: context.adaptivePrimaryColor, size: 20),
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
                    fontWeight: FontWeight.w500,
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

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: context.borderColor.withValues(alpha: 0.5),
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
            l10n.friends, // Using "Amis" instead of "Demandes d'amis"
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
            'Son et Vibration', // Using hardcoded French text as placeholder
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationOption(
            context,
            'Son', // Using hardcoded French text as placeholder
            prefs.soundEnabled,
            (value) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setSoundEnabled(value),
          ),
          _buildNotificationOption(
            context,
            'Vibration', // Using hardcoded French text as placeholder
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
// Currency Selector Modal with categories and search
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

  // Currency categories
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
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choisir la devise',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Les prix seront affiches dans cette devise',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher une devise...',
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
              // Currency list
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
              'Aucune devise trouvee',
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
