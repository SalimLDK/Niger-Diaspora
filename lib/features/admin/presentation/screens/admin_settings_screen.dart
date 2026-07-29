import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../providers/app_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;
  static const _backgroundColor = AdminColors.bg;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          'Configuration App',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
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
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_money_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Frais'),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Boosts'),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Taxes'),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Medias'),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Systeme'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (settings) => TabBarView(
          controller: _tabController,
          children: [
            _FeesTab(settings: settings),
            _BoostPricingTab(settings: settings),
            _TaxRatesTab(settings: settings),
            _MediaLimitsTab(settings: settings),
            _SystemSettingsTab(settings: settings),
          ],
        ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Erreur de chargement',
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
}

// ============================================================================
// FEES TAB
// ============================================================================

class _FeesTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const _FeesTab({required this.settings});

  @override
  ConsumerState<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends ConsumerState<_FeesTab> {
  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;

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
        TextEditingController(text: fees.transferFeeMin.toString());
    _transferFeeMaxController =
        TextEditingController(text: fees.transferFeeMax.toString());
    _marketplaceFeePercentController = TextEditingController(
        text: (fees.marketplaceFeePercent * 100).toString());
    _marketplaceFeeMinController =
        TextEditingController(text: fees.marketplaceFeeMin.toString());
    _marketplaceFeeMaxController =
        TextEditingController(text: fees.marketplaceFeeMax.toString());
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Frais mis a jour'),
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
              title: 'Frais de Transfert',
              subtitle: 'Configuration des frais sur les envois d\'argent',
              icon: Icons.send_rounded,
              color: AdminColors.statusGreen,
              children: [
                _buildPercentField(
                  controller: _transferFeePercentController,
                  label: 'Pourcentage des frais',
                  hint: 'Ex: 2.5 pour 2.5%',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountField(
                        controller: _transferFeeMinController,
                        label: 'Frais minimum (XOF)',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAmountField(
                        controller: _transferFeeMaxController,
                        label: 'Frais maximum (XOF)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Frais Marketplace',
              subtitle: 'Commission sur les ventes de produits',
              icon: Icons.storefront_rounded,
              color: AdminColors.statusAmber,
              children: [
                _buildPercentField(
                  controller: _marketplaceFeePercentController,
                  label: 'Commission plateforme',
                  hint: 'Ex: 5 pour 5%',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountField(
                        controller: _marketplaceFeeMinController,
                        label: 'Commission min (XOF)',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAmountField(
                        controller: _marketplaceFeeMaxController,
                        label: 'Commission max (XOF)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSaveButton(),
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
        ],
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
        if (value == null || value.isEmpty) return 'Requis';
        final num = double.tryParse(value);
        if (num == null || num < 0 || num > 100) {
          return 'Valeur entre 0 et 100';
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
        if (value == null || value.isEmpty) return 'Requis';
        if (int.tryParse(value) == null) return 'Nombre invalide';
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, AdminColors.actionBlueLight],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _save,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Enregistrer les modifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BOOST PRICING TAB
// ============================================================================

class _BoostPricingTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const _BoostPricingTab({required this.settings});

  @override
  ConsumerState<_BoostPricingTab> createState() => _BoostPricingTabState();
}

class _BoostPricingTabState extends ConsumerState<_BoostPricingTab> {
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

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Tarifs boost mis a jour'),
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
            _buildSectionHeader('Prix de base (7 jours)', Icons.rocket_launch_rounded, AdminColors.statusPurple),
            const SizedBox(height: 20),
            _buildPriceCard(
              title: 'Standard',
              description: 'Visibilite amelioree',
              controller: _standardBaseController,
              color: AdminColors.actionBlueLight,
            ),
            const SizedBox(height: 12),
            _buildPriceCard(
              title: 'Featured',
              description: 'Badge + meilleure position',
              controller: _featuredBaseController,
              color: AdminColors.statusAmber,
            ),
            const SizedBox(height: 12),
            _buildPriceCard(
              title: 'Premium',
              description: 'Top position + section dediee',
              controller: _premiumBaseController,
              color: AdminColors.statusPurple,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Multiplicateurs de duree', Icons.schedule_rounded, AdminColors.statusGreen),
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
                      label: '7 jours',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMultiplierField(
                      controller: _multiplier30Controller,
                      label: '30 jours',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMultiplierField(
                      controller: _multiplier90Controller,
                      label: '90 jours',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildPricePreview(),
            const SizedBox(height: 32),
            _buildSaveButton(),
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
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
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
        if (v == null || v.isEmpty) return 'Requis';
        final num = double.tryParse(v);
        if (num == null || num <= 0) return 'Invalide';
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
                'Apercu des prix (Standard)',
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
                child: _buildPreviewItem('7 jours', '${standardBase.toInt()} XOF'),
              ),
              Expanded(
                child: _buildPreviewItem('30 jours', '${(standardBase * mult30).toInt()} XOF'),
              ),
              Expanded(
                child: _buildPreviewItem('90 jours', '${(standardBase * mult90).toInt()} XOF'),
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

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, AdminColors.actionBlueLight],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _save,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Enregistrer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TAX RATES TAB
// ============================================================================

class _TaxRatesTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const _TaxRatesTab({required this.settings});

  @override
  ConsumerState<_TaxRatesTab> createState() => _TaxRatesTabState();
}

class _TaxRatesTabState extends ConsumerState<_TaxRatesTab> {
  static const _primaryColor = AdminColors.actionBlue;
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

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Taux de TVA mis a jour'),
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
                      'Taux de TVA par categorie',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Definissez les taux applicables a chaque categorie',
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
            _buildSaveButton(),
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
              if (v == null || v.isEmpty) return 'Requis';
              final num = double.tryParse(v);
              if (num == null || num < 0 || num > 100) return 'Invalide';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, AdminColors.actionBlueLight],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _save,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Enregistrer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MEDIA LIMITS TAB
// ============================================================================

class _MediaLimitsTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const _MediaLimitsTab({required this.settings});

  @override
  ConsumerState<_MediaLimitsTab> createState() => _MediaLimitsTabState();
}

class _MediaLimitsTabState extends ConsumerState<_MediaLimitsTab> {
  static const _primaryColor = AdminColors.actionBlue;
  static const _cardColor = AdminColors.surface;
  static const _textPrimary = AdminColors.text;
  static const _textSecondary = AdminColors.text2;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _imageMaxWidthController;
  late TextEditingController _imageQualityController;
  late TextEditingController _maxImagesController;
  late TextEditingController _messageMaxCharsController;
  late TextEditingController _maxImageSizeController;
  late TextEditingController _maxVideoSizeController;

  @override
  void initState() {
    super.initState();
    final limits = widget.settings.mediaLimits;
    _imageMaxWidthController =
        TextEditingController(text: limits.imageMaxWidth.toString());
    _imageQualityController =
        TextEditingController(text: limits.imageQuality.toString());
    _maxImagesController =
        TextEditingController(text: limits.maxImagesPerUpload.toString());
    _messageMaxCharsController =
        TextEditingController(text: limits.messageMaxChars.toString());
    _maxImageSizeController =
        TextEditingController(text: limits.maxImageSizeMb.toString());
    _maxVideoSizeController =
        TextEditingController(text: limits.maxVideoSizeMb.toString());
  }

  @override
  void dispose() {
    _imageMaxWidthController.dispose();
    _imageQualityController.dispose();
    _maxImagesController.dispose();
    _messageMaxCharsController.dispose();
    _maxImageSizeController.dispose();
    _maxVideoSizeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final current = widget.settings.mediaLimits;
    final newLimits = MediaLimitsEntity(
      imageMaxWidth: int.parse(_imageMaxWidthController.text),
      imageMaxHeight: int.parse(_imageMaxWidthController.text),
      imageQuality: int.parse(_imageQualityController.text),
      maxImagesPerUpload: int.parse(_maxImagesController.text),
      minWidthForCompression: current.minWidthForCompression,
      messageMaxChars: int.parse(_messageMaxCharsController.text),
      messageCharCountThreshold: current.messageCharCountThreshold,
      maxImageSizeMb: int.parse(_maxImageSizeController.text),
      maxVideoSizeMb: int.parse(_maxVideoSizeController.text),
      maxDocumentSizeMb: current.maxDocumentSizeMb,
      maxAudioDurationSeconds: current.maxAudioDurationSeconds,
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateMediaLimits(newLimits, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Limites medias mises a jour'),
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
              title: 'Images',
              subtitle: 'Configuration des images uploadees',
              icon: Icons.image_rounded,
              color: AdminColors.actionBlueLight,
              children: [
                _buildIntField(
                  controller: _imageMaxWidthController,
                  label: 'Dimension max (px)',
                  hint: 'Largeur et hauteur max',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildIntField(
                        controller: _imageQualityController,
                        label: 'Qualite compression (%)',
                        hint: '1-100',
                        max: 100,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildIntField(
                        controller: _maxImagesController,
                        label: 'Max images/upload',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildIntField(
                  controller: _maxImageSizeController,
                  label: 'Taille max image (MB)',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Videos',
              subtitle: 'Limites pour les videos',
              icon: Icons.videocam_rounded,
              color: AdminColors.statusRed,
              children: [
                _buildIntField(
                  controller: _maxVideoSizeController,
                  label: 'Taille max video (MB)',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Messages',
              subtitle: 'Configuration des messages',
              icon: Icons.message_rounded,
              color: AdminColors.statusGreen,
              children: [
                _buildIntField(
                  controller: _messageMaxCharsController,
                  label: 'Caracteres max par message',
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSaveButton(),
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
        ],
      ),
    );
  }

  Widget _buildIntField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? max,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
        if (v == null || v.isEmpty) return 'Requis';
        final num = int.tryParse(v);
        if (num == null || num <= 0) return 'Invalide';
        if (max != null && num > max) return 'Max: $max';
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, AdminColors.actionBlueLight],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _save,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Enregistrer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SYSTEM SETTINGS TAB
// ============================================================================

class _SystemSettingsTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const _SystemSettingsTab({required this.settings});

  @override
  ConsumerState<_SystemSettingsTab> createState() => _SystemSettingsTabState();
}

class _SystemSettingsTabState extends ConsumerState<_SystemSettingsTab> {
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
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('URLs mises a jour'),
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

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Intervalles mis a jour'),
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
              title: 'URLs & Contact',
              subtitle: 'Configuration des liens et emails',
              icon: Icons.link_rounded,
              color: AdminColors.actionBlueLight,
              saveAction: _saveUrls,
              children: [
                _buildTextField(
                  controller: _shareBaseUrlController,
                  label: 'URL de base pour partage',
                  icon: Icons.share_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _supportEmailController,
                  label: 'Email support',
                  icon: Icons.support_agent_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _privacyEmailController,
                  label: 'Email confidentialite (RGPD)',
                  icon: Icons.privacy_tip_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bugsEmailController,
                  label: 'Email rapport de bugs',
                  icon: Icons.bug_report_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _feedbackEmailController,
                  label: 'Email feedback',
                  icon: Icons.feedback_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _moderationEmailController,
                  label: 'Email moderation',
                  icon: Icons.admin_panel_settings_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Intervalles systeme',
              subtitle: 'Frequences de mise a jour',
              icon: Icons.timer_rounded,
              color: AdminColors.statusAmber,
              saveAction: _saveIntervals,
              children: [
                _buildIntervalField(
                  controller: _locationIntervalController,
                  label: 'Mise a jour localisation (min)',
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 16),
                _buildIntervalField(
                  controller: _heartbeatIntervalController,
                  label: 'Heartbeat statut en ligne (min)',
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 16),
                _buildIntervalField(
                  controller: _cacheMinutesController,
                  label: 'Duree cache (min)',
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sauvegarder',
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
        if (v == null || v.isEmpty) return 'Requis';
        final num = int.tryParse(v);
        if (num == null || num <= 0) return 'Invalide';
        return null;
      },
    );
  }
}
