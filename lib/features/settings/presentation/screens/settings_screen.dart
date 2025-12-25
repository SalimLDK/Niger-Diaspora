import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../widgets/blocked_users_modal.dart';
import '../widgets/bug_report_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _profileVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser != null) {
      await ref
          .read(profileNotifierProvider.notifier)
          .loadProfile(currentUser.id);
      _loadSettings();
    }
  }

  void _loadSettings() {
    final profile = ref.read(profileNotifierProvider).valueOrNull;
    if (profile != null) {
      setState(() {
        _notificationsEnabled = profile.notificationsEnabled;
        _locationEnabled = profile.shareLocation;
        _profileVisible = profile.isVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

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
                icon: Icons.person,
                title: l10n.editProfile,
                subtitle: currentUser?.displayName ?? l10n.myProfile,
                onTap: () => context.push('/profile/edit'),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.email,
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
                icon: Icons.notifications_active,
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
                icon: Icons.block,
                title: l10n.blockedUsers,
                onTap: () => _showBlockedUsers(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App Section
          _buildSectionHeader(l10n.application),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.dark_mode,
                title: l10n.theme,
                subtitle: _getThemeLabel(
                  ref.watch(themeModeNotifierProvider),
                  l10n,
                ),
                onTap: () => _showThemeSelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.language,
                title: l10n.language,
                subtitle:
                    ref
                        .watch(localeNotifierProvider.notifier)
                        .currentLocaleName,
                onTap: () => _showLanguageSelector(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.help_outline,
                title: l10n.helpAndSupport,
                onTap: () => _showHelpSupport(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.info_outline,
                title: l10n.about,
                subtitle: '${l10n.version} 1.0.0',
                onTap: () => _showAbout(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.description,
                title: l10n.termsOfService,
                onTap: () => _showTerms(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.privacy_tip,
                title: l10n.privacyPolicy,
                onTap: () => _showPrivacyPolicy(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionHeader(l10n.dangerZone),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.logout,
                title: l10n.logout,
                iconColor: Colors.orange,
                titleColor: Colors.orange,
                onTap: () => _confirmLogout(),
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.delete_forever,
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
    final profile = ref.read(profileNotifierProvider).valueOrNull;
    if (profile == null) return;

    final updatedProfile = profile.copyWith(
      notificationsEnabled: _notificationsEnabled,
      shareLocation: _locationEnabled,
      isVisible: _profileVisible,
    );

    await ref
        .read(profileNotifierProvider.notifier)
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
    final supportService = SupportService();

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
                    'support@diasponiger.com',
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
    showAboutDialog(
      context: context,
      applicationName: l10n.appTitle,
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: context.adaptivePrimaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.people, color: AppColors.white, size: 32),
      ),
      children: [Text(l10n.appDescription)],
    );
  }

  void _showTerms() {
    context.push('/settings/terms');
  }

  void _showPrivacyPolicy() {
    context.push('/settings/privacy');
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
                  final currentUser = ref.read(currentUserProvider).valueOrNull;
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
      final currentUser = ref.read(currentUserProvider).valueOrNull;
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
  final IconData icon;
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
              child: Icon(icon, color: effectiveIconColor, size: 20),
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
            activeColor: context.adaptivePrimaryColor,
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
    final prefsAsync = ref.watch(notificationPreferencesNotifierProvider);

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
            AppLocalizations.of(context)!.notificationPreferences,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          prefsAsync.when(
            data: (prefs) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  _buildNotificationOption(
                    context,
                    l10n.messages,
                    prefs.messages,
                    (value) => ref
                        .read(notificationPreferencesNotifierProvider.notifier)
                        .updateMessages(value),
                  ),
                  _buildNotificationOption(
                    context,
                    l10n.newEvents,
                    prefs.newEvents,
                    (value) => ref
                        .read(notificationPreferencesNotifierProvider.notifier)
                        .updateNewEvents(value),
                  ),
                  _buildNotificationOption(
                    context,
                    l10n.groupActivity,
                    prefs.groupActivity,
                    (value) => ref
                        .read(notificationPreferencesNotifierProvider.notifier)
                        .updateGroupActivity(value),
                  ),
                  _buildNotificationOption(
                    context,
                    l10n.eventReminders,
                    prefs.eventReminders,
                    (value) => ref
                        .read(notificationPreferencesNotifierProvider.notifier)
                        .updateEventReminders(value),
                  ),
                ],
              );
            },
            loading:
                () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                ),
            error:
                (error, _) => Center(
                  child: Text(
                    '${AppLocalizations.of(context)!.error}: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
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
            activeColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }
}
