import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'reglages_briques.dart';

class AdminBoostsTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const AdminBoostsTab({super.key, required this.settings});

  @override
  ConsumerState<AdminBoostsTab> createState() => _AdminBoostsTabState();
}

class _AdminBoostsTabState extends ConsumerState<AdminBoostsTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _standardBaseController;
  late TextEditingController _featuredBaseController;
  late TextEditingController _premiumBaseController;
  late TextEditingController _multiplier7Controller;
  late TextEditingController _multiplier30Controller;
  late TextEditingController _multiplier90Controller;

  @override
  void initState() {
    super.initState();
    final pricing = widget.settings.boostPricing;
    _standardBaseController =
        TextEditingController(text: pricing.standardBase.toInt().toString());
    _featuredBaseController =
        TextEditingController(text: pricing.featuredBase.toInt().toString());
    _premiumBaseController =
        TextEditingController(text: pricing.premiumBase.toInt().toString());
    _multiplier7Controller =
        TextEditingController(text: pricing.multiplier7Days.toString());
    _multiplier30Controller =
        TextEditingController(text: pricing.multiplier30Days.toString());
    _multiplier90Controller =
        TextEditingController(text: pricing.multiplier90Days.toString());
  }

  @override
  void dispose() {
    _standardBaseController.dispose();
    _featuredBaseController.dispose();
    _premiumBaseController.dispose();
    _multiplier7Controller.dispose();
    _multiplier30Controller.dispose();
    _multiplier90Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final newPricing = BoostPricingEntity(
      standardBase: double.parse(_standardBaseController.text),
      featuredBase: double.parse(_featuredBaseController.text),
      premiumBase: double.parse(_premiumBaseController.text),
      multiplier7Days: double.parse(_multiplier7Controller.text),
      multiplier30Days: double.parse(_multiplier30Controller.text),
      multiplier90Days: double.parse(_multiplier90Controller.text),
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateBoostPricing(newPricing, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminBoostRatesUpdated),
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
            _buildSectionHeader(l10n.adminBasePricesTitle, Icons.rocket_launch_rounded, AdminColors.statusPurple),
            const SizedBox(height: 20),
            _buildPriceCard(
              title: l10n.adminStandardTier,
              description: l10n.adminStandardTierDesc,
              controller: _standardBaseController,
              color: AdminColors.actionBlueLight,
            ),
            const SizedBox(height: 12),
            _buildPriceCard(
              title: l10n.adminFeaturedTier,
              description: l10n.adminFeaturedTierDesc,
              controller: _featuredBaseController,
              color: AdminColors.statusAmber,
            ),
            const SizedBox(height: 12),
            _buildPriceCard(
              title: l10n.adminPremiumTier,
              description: l10n.adminPremiumTierDesc,
              controller: _premiumBaseController,
              color: AdminColors.statusPurple,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(l10n.adminDurationMultipliersTitle, Icons.schedule_rounded, AdminColors.statusGreen),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMultiplierField(
                      controller: _multiplier7Controller,
                      label: l10n.adminDays7Label,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMultiplierField(
                      controller: _multiplier30Controller,
                      label: l10n.adminDays30Label,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMultiplierField(
                      controller: _multiplier90Controller,
                      label: l10n.adminDays90Label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildPricePreview(),
            const SizedBox(height: 32),
            ReglagesBoutonEnregistrer(label: l10n.save, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard({
    required String title,
    required String description,
    required TextEditingController controller,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.5)],
              ),
              borderRadius: BorderRadius.circular(2),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                suffixText: 'XOF',
                filled: true,
                fillColor: AdminColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v == null || v.isEmpty ? l10n.adminFieldRequired : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'x',
        filled: true,
        fillColor: AdminColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.adminFieldRequired;
        final num = double.tryParse(v);
        if (num == null || num <= 0) return l10n.quantityInvalidError;
        return null;
      },
    );
  }

  Widget _buildPricePreview() {
    final standardBase = double.tryParse(_standardBaseController.text) ?? 5000;
    final mult30 = double.tryParse(_multiplier30Controller.text) ?? 3.0;
    final mult90 = double.tryParse(_multiplier90Controller.text) ?? 7.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withValues(alpha: 0.1),
            AdminColors.actionBlueLight.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.adminPricePreviewTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPreviewItem(l10n.adminDays7Label, '${standardBase.toInt()} XOF'),
              ),
              Expanded(
                child: _buildPreviewItem(l10n.adminDays30Label, '${(standardBase * mult30).toInt()} XOF'),
              ),
              Expanded(
                child: _buildPreviewItem(l10n.adminDays90Label, '${(standardBase * mult90).toInt()} XOF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textPrimary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAX RATES TAB
// ============================================================================
