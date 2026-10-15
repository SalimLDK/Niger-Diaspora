import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class AdminSystemeTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const AdminSystemeTab({super.key, required this.settings});

  @override
  ConsumerState<AdminSystemeTab> createState() => _AdminSystemeTabState();
}

class _AdminSystemeTabState extends ConsumerState<AdminSystemeTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shareBaseUrlController;
  late TextEditingController _supportEmailController;
  late TextEditingController _privacyEmailController;
  late TextEditingController _bugsEmailController;
  late TextEditingController _feedbackEmailController;
  late TextEditingController _moderationEmailController;
  late TextEditingController _locationIntervalController;
  late TextEditingController _heartbeatIntervalController;
  late TextEditingController _cacheMinutesController;

  @override
  void initState() {
    super.initState();
    final urls = widget.settings.urls;
    final intervals = widget.settings.intervals;
    _shareBaseUrlController = TextEditingController(text: urls.shareBaseUrl);
    _supportEmailController = TextEditingController(text: urls.supportEmail);
    _privacyEmailController = TextEditingController(text: urls.privacyEmail);
    _bugsEmailController = TextEditingController(text: urls.bugsEmail);
    _feedbackEmailController = TextEditingController(text: urls.feedbackEmail);
    _moderationEmailController = TextEditingController(text: urls.moderationEmail);
    _locationIntervalController =
        TextEditingController(text: intervals.locationUpdateMinutes.toString());
    _heartbeatIntervalController =
        TextEditingController(text: intervals.heartbeatMinutes.toString());
    _cacheMinutesController =
        TextEditingController(text: intervals.cacheMinutes.toString());
  }

  @override
  void dispose() {
    _shareBaseUrlController.dispose();
    _supportEmailController.dispose();
    _privacyEmailController.dispose();
    _bugsEmailController.dispose();
    _feedbackEmailController.dispose();
    _moderationEmailController.dispose();
    _locationIntervalController.dispose();
    _heartbeatIntervalController.dispose();
    _cacheMinutesController.dispose();
    super.dispose();
  }

  Future<void> _saveUrls() async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final current = widget.settings.urls;
    final newUrls = SystemUrlsEntity(
      shareBaseUrl: _shareBaseUrlController.text,
      supportEmail: _supportEmailController.text,
      privacyEmail: _privacyEmailController.text,
      bugsEmail: _bugsEmailController.text,
      feedbackEmail: _feedbackEmailController.text,
      moderationEmail: _moderationEmailController.text,
      stripeMerchantId: current.stripeMerchantId,
      termsUrl: current.termsUrl,
      privacyUrl: current.privacyUrl,
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateUrls(newUrls, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminUrlsUpdated),
            ],
          ),
          backgroundColor: AdminColors.statusGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _saveIntervals() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final current = widget.settings.intervals;
    final newIntervals = SystemIntervalsEntity(
      locationUpdateMinutes: int.parse(_locationIntervalController.text),
      heartbeatMinutes: int.parse(_heartbeatIntervalController.text),
      cacheMinutes: int.parse(_cacheMinutesController.text),
      remoteConfigFetchMinutes: current.remoteConfigFetchMinutes,
      typingIndicatorSeconds: current.typingIndicatorSeconds,
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateIntervals(newIntervals, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminIntervalsUpdated),
            ],
          ),
          backgroundColor: AdminColors.statusGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: l10n.adminUrlsAndContactTitle,
              subtitle: l10n.adminUrlsAndContactDesc,
              icon: Icons.link_rounded,
              color: AdminColors.actionBlueLight,
              saveAction: _saveUrls,
              children: [
                _buildTextField(
                  controller: _shareBaseUrlController,
                  label: l10n.adminBaseShareUrl,
                  icon: Icons.share_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _supportEmailController,
                  label: l10n.adminSupportEmail,
                  icon: Icons.support_agent_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _privacyEmailController,
                  label: l10n.adminPrivacyEmail,
                  icon: Icons.privacy_tip_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bugsEmailController,
                  label: l10n.adminBugReportEmail,
                  icon: Icons.bug_report_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _feedbackEmailController,
                  label: l10n.adminFeedbackEmail,
                  icon: Icons.feedback_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _moderationEmailController,
                  label: l10n.adminModerationEmail,
                  icon: Icons.admin_panel_settings_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: l10n.adminIntervalsTitle,
              subtitle: l10n.adminIntervalsDesc,
              icon: Icons.timer_rounded,
              color: AdminColors.statusAmber,
              saveAction: _saveIntervals,
              children: [
                _buildIntervalField(
                  controller: _locationIntervalController,
                  label: l10n.adminLocationUpdateMin,
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 16),
                _buildIntervalField(
                  controller: _heartbeatIntervalController,
                  label: l10n.adminOnlineHeartbeat,
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 16),
                _buildIntervalField(
                  controller: _cacheMinutesController,
                  label: l10n.adminCacheDuration,
                  icon: Icons.cached_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback saveAction,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
            ],
          ),
          const SizedBox(height: 24),
          ...children,
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: saveAction,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        l10n.e2eeBackupNudgeAction,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        filled: true,
        fillColor: AdminColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildIntervalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        filled: true,
        fillColor: AdminColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.statusRed),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.adminFieldRequired;
        final num = int.tryParse(v);
        if (num == null || num <= 0) return l10n.quantityInvalidError;
        return null;
      },
    );
  }
}
