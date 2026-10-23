import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'reglages_briques.dart';

class AdminTaxesTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const AdminTaxesTab({super.key, required this.settings});

  @override
  ConsumerState<AdminTaxesTab> createState() => _AdminTaxesTabState();
}

class _AdminTaxesTabState extends ConsumerState<AdminTaxesTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;

  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'alimentation', 'label': 'Alimentation', 'icon': Icons.restaurant_rounded, 'color': AdminColors.statusGreen},
    {'key': 'artisanat', 'label': 'Artisanat', 'icon': Icons.handyman_rounded, 'color': AdminColors.statusAmber},
    {'key': 'electronique', 'label': 'Electronique', 'icon': Icons.devices_rounded, 'color': AdminColors.actionBlueLight},
    {'key': 'vetements', 'label': 'Vetements', 'icon': Icons.checkroom_rounded, 'color': AdminColors.statusPurple},
    {'key': 'services', 'label': 'Services', 'icon': Icons.miscellaneous_services_rounded, 'color': AdminColors.statusPurple},
    {'key': 'immobilier', 'label': 'Immobilier', 'icon': Icons.home_rounded, 'color': AdminColors.statusGreen},
    {'key': 'standard', 'label': 'Standard (autres)', 'icon': Icons.category_rounded, 'color': AdminColors.statusGray},
  ];

  @override
  void initState() {
    super.initState();
    final rates = widget.settings.taxRates;
    _controllers = {
      'alimentation': TextEditingController(text: (rates.alimentation * 100).toString()),
      'artisanat': TextEditingController(text: (rates.artisanat * 100).toString()),
      'electronique': TextEditingController(text: (rates.electronique * 100).toString()),
      'vetements': TextEditingController(text: (rates.vetements * 100).toString()),
      'services': TextEditingController(text: (rates.services * 100).toString()),
      'immobilier': TextEditingController(text: (rates.immobilier * 100).toString()),
      'standard': TextEditingController(text: (rates.standard * 100).toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final newRates = TaxRatesEntity(
      alimentation: double.parse(_controllers['alimentation']!.text) / 100,
      artisanat: double.parse(_controllers['artisanat']!.text) / 100,
      electronique: double.parse(_controllers['electronique']!.text) / 100,
      vetements: double.parse(_controllers['vetements']!.text) / 100,
      services: double.parse(_controllers['services']!.text) / 100,
      immobilier: double.parse(_controllers['immobilier']!.text) / 100,
      standard: double.parse(_controllers['standard']!.text) / 100,
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateTaxRates(newRates, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminVatRateUpdated),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminColors.statusAmber, AdminColors.statusRed],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminTaxRatesTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      l10n.adminTaxRatesDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
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
                children: _categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTaxRateRow(
                    icon: cat['icon'] as IconData,
                    label: cat['label'] as String,
                    color: cat['color'] as Color,
                    controller: _controllers[cat['key']]!,
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 32),
            ReglagesBoutonEnregistrer(label: l10n.save, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRateRow({
    required IconData icon,
    required String label,
    required Color color,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              suffixText: '%',
              filled: true,
              fillColor: AdminColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.adminFieldRequired;
              final num = double.tryParse(v);
              if (num == null || num < 0 || num > 100) return l10n.quantityInvalidError;
              return null;
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MEDIA LIMITS TAB
// ============================================================================
