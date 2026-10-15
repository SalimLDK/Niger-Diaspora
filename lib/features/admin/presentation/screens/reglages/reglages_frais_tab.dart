import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'reglages_briques.dart';

class AdminFraisTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const AdminFraisTab({super.key, required this.settings});

  @override
  ConsumerState<AdminFraisTab> createState() => _AdminFraisTabState();
}

class _AdminFraisTabState extends ConsumerState<AdminFraisTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _primaryColor = AdminColors.actionBlue;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _transferFeePercentController;
  late TextEditingController _transferFeeMinController;
  late TextEditingController _transferFeeMaxController;
  late TextEditingController _marketplaceFeePercentController;
  late TextEditingController _marketplaceFeeMinController;
  late TextEditingController _marketplaceFeeMaxController;

  @override
  void initState() {
    super.initState();
    final fees = widget.settings.fees;
    _transferFeePercentController =
        TextEditingController(text: (fees.transferFeePercent * 100).toString());
    _transferFeeMinController =
        TextEditingController(text: _montant(fees.transferFeeMin));
    _transferFeeMaxController =
        TextEditingController(text: _montant(fees.transferFeeMax));
    _marketplaceFeePercentController = TextEditingController(
        text: (fees.marketplaceFeePercent * 100).toString());
    _marketplaceFeeMinController =
        TextEditingController(text: _montant(fees.marketplaceFeeMin));
    _marketplaceFeeMaxController =
        TextEditingController(text: _montant(fees.marketplaceFeeMax));
  }

  @override
  void dispose() {
    _transferFeePercentController.dispose();
    _transferFeeMinController.dispose();
    _transferFeeMaxController.dispose();
    _marketplaceFeePercentController.dispose();
    _marketplaceFeeMinController.dispose();
    _marketplaceFeeMaxController.dispose();
    super.dispose();
  }

  /// Un montant entier s'affiche sans « .0 » : le champ n'accepte que des
  /// chiffres (`digitsOnly`) et son validateur lit un nombre, donc « 750.0 »
  /// rendait l'enregistrement impossible sans retaper les quatre montants.
  static String _montant(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final newFees = FeeSettingsEntity(
      transferFeePercent:
          double.parse(_transferFeePercentController.text) / 100,
      transferFeeMin: double.parse(_transferFeeMinController.text),
      transferFeeMax: double.parse(_transferFeeMaxController.text),
      marketplaceFeePercent:
          double.parse(_marketplaceFeePercentController.text) / 100,
      marketplaceFeeMin: double.parse(_marketplaceFeeMinController.text),
      marketplaceFeeMax: double.parse(_marketplaceFeeMaxController.text),
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateFees(newFees, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminFeesUpdated),
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
            ReglagesCarteSection(
              title: l10n.adminTransferFeesTitle,
              subtitle: 'Configuration des frais sur les envois d\'argent',
              icon: Icons.send_rounded,
              color: AdminColors.statusGreen,
              children: [
                _buildPercentField(
                  controller: _transferFeePercentController,
                  label: l10n.adminFeePercentage,
                  hint: l10n.adminPercentageHint,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountField(
                        controller: _transferFeeMinController,
                        label: l10n.adminMinFee,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAmountField(
                        controller: _transferFeeMaxController,
                        label: l10n.adminMaxFee,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ReglagesCarteSection(
              title: l10n.adminMarketplaceFeesTitle,
              subtitle: l10n.adminMarketplaceFeesDesc,
              icon: Icons.storefront_rounded,
              color: AdminColors.statusAmber,
              children: [
                _buildPercentField(
                  controller: _marketplaceFeePercentController,
                  label: l10n.adminPlatformCommission,
                  hint: 'Ex: 5 pour 5%',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountField(
                        controller: _marketplaceFeeMinController,
                        label: l10n.adminCommissionMin,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAmountField(
                        controller: _marketplaceFeeMaxController,
                        label: l10n.adminCommissionMax,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            ReglagesBoutonEnregistrer(label: l10n.adminSaveChanges, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: '%',
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.adminFieldRequired;
        final num = double.tryParse(value);
        if (num == null || num < 0 || num > 100) {
          return l10n.adminValueBetweenError;
        }
        return null;
      },
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.adminFieldRequired;
        final montant = double.tryParse(value);
        if (montant == null || montant < 0) return l10n.adminInvalidNumberError;
        return null;
      },
    );
  }
}

// ============================================================================
// BOOST PRICING TAB
// ============================================================================
