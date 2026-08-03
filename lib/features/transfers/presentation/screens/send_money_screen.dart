import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/security_gate_provider.dart';
import '../../../../core/services/security_gate_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/recipient_entity.dart';
import '../providers/transfer_provider.dart';

class SendMoneyScreen extends ConsumerStatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transferState = ref.watch(transferStateNotifierProvider);
    final selectedCurrency = ref.watch(selectedCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const DesignTitle('Envoyer de l\'argent', size: 22),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                ref.read(transferStateNotifierProvider.notifier).reset();
                setState(() => _currentStep = 0);
              },
              child: const Text('Reinitialiser'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stepper sur une seule ligne (remplace le Stepper natif — 12a).
            _buildStepIndicator(theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _stepContent(theme, transferState, selectedCurrency),
              ),
            ),
            _buildBottomBar(theme, transferState, selectedCurrency),
          ],
        ),
      ),
    );
  }

  // Couleurs du transfert (refonte §6/12a).
  //
  // Plus rien n'est figé ici. L'accent suit `colorScheme.primary` — donc le
  // thème choisi par le compte, et sa version éclaircie en nocturne — et
  // l'étape à venir `colorScheme.outline`. Les deux recopiaient un jeton
  // (`#B85E24`, `#E8DFD4`) et gardaient donc leur valeur de thème clair en
  // mode nuit. Le texte posé sur l'accent passe par `colorScheme.onPrimary` :
  // le guide impose de l'encre foncée sur l'accent nocturne, jamais du blanc.

  Widget _stepContent(
    ThemeData theme,
    TransferState transferState,
    String selectedCurrency,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildRecipientStep(theme, transferState);
      case 1:
        return _buildAmountStep(theme, selectedCurrency);
      default:
        return _buildConfirmationStep(theme, transferState);
    }
  }

  /// Indicateur d'étapes sur une ligne : rond 22 px + libellé, barre 2 px
  /// entre les étapes (accent = faite/en cours, bordure du thème = à venir).
  Widget _buildStepIndicator(ThemeData theme) {
    const labels = ['Bénéficiaire', 'Montant', 'Confirmer'];

    Widget node(int idx) {
      final done = _currentStep > idx;
      final active = _currentStep >= idx;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              shape: BoxShape.circle,
            ),
            child: done
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  )
                : Text(
                    '${idx + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[idx],
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  _currentStep == idx ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    Widget bar(int afterIdx) {
      final done = _currentStep > afterIdx;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            height: 2,
            color: done
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [node(0), bar(0), node(1), bar(1), node(2)],
      ),
    );
  }

  Widget _buildBottomBar(
    ThemeData theme,
    TransferState transferState,
    String selectedCurrency,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              onPressed: _isLoading ? null : _onStepCancel,
              child: const Text('Retour'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _onStepContinue,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        _continueLabel(transferState, selectedCurrency),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Libellé du bouton principal portant le total débité (« Continuer · 51,50 €
  /// » / « Confirmer · … ») — refonte 12a : les frais/total se lisent avant et
  /// sur le bouton, jamais découverts dans une boîte de dialogue finale.
  String _continueLabel(TransferState state, String currency) {
    final total = state.totalCharged;
    final suffix =
        total > 0 ? ' · ${total.toStringAsFixed(2)} $currency' : '';
    return _currentStep == 2 ? 'Confirmer$suffix' : 'Continuer$suffix';
  }

  Widget _buildRecipientStep(ThemeData theme, TransferState transferState) {
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    final recipientsAsync = ref.watch(
      watchUserRecipientsProvider(currentUser.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add new recipient button
        OutlinedButton.icon(
          onPressed: () => context.push('/transfers/recipient/add'),
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter un beneficiaire'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Ou selectionnez un beneficiaire existant',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),

        // Recipients list
        recipientsAsync.when(
          data: (recipients) {
            if (recipients.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun beneficiaire enregistre',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Separate favorites and recent recipients
            final favorites = recipients.where((r) => r.isFavorite).toList();
            final recentlyUsed =
                recipients
                    .where((r) => !r.isFavorite && r.lastUsedAt != null)
                    .toList()
                  ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
            final others =
                recipients
                    .where((r) => !r.isFavorite && r.lastUsedAt == null)
                    .toList();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Favorites section
                  if (favorites.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Favoris',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...favorites.map(
                      (recipient) =>
                          _buildRecipientCard(recipient, theme, transferState),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Recent recipients section
                  if (recentlyUsed.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'R\u00e9cemment utilis\u00e9s',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...recentlyUsed
                        .take(3)
                        .map(
                          (recipient) => _buildRecipientCard(
                            recipient,
                            theme,
                            transferState,
                          ),
                        ),
                    const SizedBox(height: 8),
                  ],

                  // Other recipients
                  if (others.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        'Autres b\u00e9n\u00e9ficiaires',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...others.map(
                      (recipient) =>
                          _buildRecipientCard(recipient, theme, transferState),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }

  Widget _buildRecipientCard(
    RecipientEntity recipient,
    ThemeData theme,
    TransferState transferState,
  ) {
    final isSelected = transferState.selectedRecipient?.id == recipient.id;

    return Card(
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _getRecipientIcon(recipient.type),
            color:
                isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          recipient.fullName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(recipient.phone),
        trailing:
            isSelected
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : recipient.isFavorite
                ? const Icon(Icons.star, color: Colors.amber, size: 20)
                : null,
        onTap: () {
          ref
              .read(transferStateNotifierProvider.notifier)
              .selectRecipient(recipient);
        },
      ),
    );
  }

  Widget _buildAmountStep(ThemeData theme, String selectedCurrency) {
    const quickAmounts = [25, 50, 100, 200];
    final currentAmount = double.tryParse(_amountController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Montant héros + sélecteur de devise en pastille.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: _amountController,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Entrez un montant';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'Montant invalide';
                  if (amount < 5) return 'Minimum 5 $selectedCurrency';
                  return null;
                },
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  // Rebuild pour rafraîchir la surbrillance des montants rapides.
                  setState(() {});
                  ref
                      .read(transferStateNotifierProvider.notifier)
                      .setAmount(amount);
                  _updateFeeAndRateDebounced();
                },
              ),
            ),
            const SizedBox(width: 10),
            _currencyPastille(theme, selectedCurrency),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Minimum 5 $selectedCurrency',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // Montants rapides.
        Row(
          children: [
            for (final amt in quickAmounts) ...[
              Expanded(
                child: _quickAmountChip(
                  theme,
                  amt,
                  currentAmount == amt.toDouble(),
                ),
              ),
              if (amt != quickAmounts.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Notes (optional)
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Message (optionnel)',
            hintText: 'Ex: Pour les courses',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (value) {
            ref.read(transferStateNotifierProvider.notifier).setNotes(value);
          },
        ),
        const SizedBox(height: 24),

        // Fee breakdown preview
        _buildFeePreview(theme, selectedCurrency),
      ],
    );
  }

  /// Sélecteur de devise en pastille (à droite du montant héros).
  Widget _currencyPastille(ThemeData theme, String selectedCurrency) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        ref.read(selectedCurrencyProvider.notifier).select(value);
        ref.read(transferStateNotifierProvider.notifier).setCurrency(value);
        _updateFeeAndRateDebounced();
      },
      itemBuilder: (ctx) => _transferCurrencies
          .map(
            (c) => PopupMenuItem<String>(
              value: c.code,
              child: Text('${c.flag}  ${c.code} · ${c.name}'),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCurrency,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountChip(ThemeData theme, int amount, bool active) {
    return GestureDetector(
      onTap: () => _setQuickAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$amount',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: active
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _setQuickAmount(int amount) {
    _amountController.text = '$amount';
    setState(() {});
    ref.read(transferStateNotifierProvider.notifier).setAmount(amount.toDouble());
    _updateFeeAndRateDebounced();
  }

  Widget _buildFeePreview(ThemeData theme, String selectedCurrency) {
    final transferState = ref.watch(transferStateNotifierProvider);
    final feePercent = ref.watch(transferFeePercentProvider);

    if (transferState.amount <= 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recapitulatif',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeeRow(
              'Montant envoye',
              '${transferState.amount.toStringAsFixed(2)} $selectedCurrency',
            ),
            if (transferState.fee != null)
              _buildFeeRow(
                'Frais (${(feePercent * 100).toStringAsFixed(1)}%)',
                '${transferState.fee!.toStringAsFixed(2)} $selectedCurrency',
              ),
            const Divider(),
            _buildFeeRow(
              'Total debite',
              '${transferState.totalCharged.toStringAsFixed(2)} $selectedCurrency',
              isBold: true,
            ),
            const SizedBox(height: 8),
            if (transferState.exchangeRate != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Taux: 1 $selectedCurrency = ${transferState.exchangeRate!.toStringAsFixed(2)} XOF',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  // Carte verte « recevra » (§12a).
                  final isDark = theme.brightness == Brightness.dark;
                  final bg =
                      isDark ? const Color(0xFF16241A) : const Color(0xFFF0F4EA);
                  final border =
                      isDark
                          ? const Color(0xFF2D7D46).withValues(alpha: 0.4)
                          : const Color(0xFFDCE6CE);
                  final amountColor =
                      isDark ? const Color(0xFF5BA674) : const Color(0xFF1B5E32);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Le bénéficiaire recevra',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${transferState.amountInXof.toStringAsFixed(0)} XOF',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep(ThemeData theme, TransferState transferState) {
    final selectedCurrency = ref.watch(selectedCurrencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recipient card
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                _getRecipientIcon(
                  transferState.selectedRecipient?.type ??
                      RecipientType.mobileWallet,
                ),
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              transferState.selectedRecipient?.fullName ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(transferState.selectedRecipient?.phone ?? ''),
          ),
        ),
        const SizedBox(height: 16),

        // Amount summary
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Montant a recevoir',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${transferState.amountInXof.toStringAsFixed(0)} ${Currency.xof.code}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total debite: ${transferState.totalCharged.toStringAsFixed(2)} $selectedCurrency',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        if (transferState.notes?.isNotEmpty ?? false)
          Card(
            child: ListTile(
              leading: const Icon(Icons.note),
              title: const Text('Message'),
              subtitle: Text(transferState.notes!),
            ),
          ),

        const SizedBox(height: 16),

        // Terms
        Text(
          'En confirmant, vous acceptez les conditions generales de transfert. '
          'Les fonds seront disponibles sous 24h.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _onStepContinue() async {
    final transferState = ref.read(transferStateNotifierProvider);

    switch (_currentStep) {
      case 0:
        if (transferState.selectedRecipient == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selectionnez un beneficiaire')),
          );
          return;
        }
        setState(() => _currentStep = 1);
        break;

      case 1:
        if (!_formKey.currentState!.validate()) return;
        await _updateFeeAndRate();
        if (!mounted) return;
        if (ref.read(transferStateNotifierProvider).exchangeRate == null ||
            ref.read(transferStateNotifierProvider).fee == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors du calcul des frais')),
          );
          return;
        }
        setState(() => _currentStep = 2);
        break;

      case 2:
        // Show confirmation dialog before submission
        final confirmed = await _showConfirmationDialog();
        if (confirmed == true) {
          await _submitTransfer();
        }
        break;
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<bool?> _showConfirmationDialog() async {
    final transferState = ref.read(transferStateNotifierProvider);
    final selectedCurrency = ref.read(selectedCurrencyProvider);
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Flexible(child: Text('Confirmer le transfert')),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous êtes sur le point d\'envoyer:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Montant:'),
                              Text(
                                '${transferState.amount.toStringAsFixed(2)} $selectedCurrency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Frais:'),
                              Text(
                                '${transferState.fee!.toStringAsFixed(2)} $selectedCurrency',
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:'),
                              Text(
                                '${transferState.totalCharged.toStringAsFixed(2)} $selectedCurrency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'À: ${transferState.selectedRecipient?.fullName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cette action est irréversible. Voulez-vous continuer?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
    );
  }

  void _updateFeeAndRateDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _doUpdateFeeAndRate();
    });
  }

  Future<void> _updateFeeAndRate() async {
    _debounceTimer?.cancel();
    await _doUpdateFeeAndRate();
  }

  Future<void> _doUpdateFeeAndRate() async {
    final selectedCurrency = ref.read(selectedCurrencyProvider);
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) return;

    try {
      final rateResult = await ref.read(
        exchangeRateProvider(selectedCurrency, 'XOF').future,
      );
      final feeResult = await ref.read(
        transferFeeProvider(amount, selectedCurrency).future,
      );

      if (!mounted) return;

      ref
          .read(transferStateNotifierProvider.notifier)
          .setExchangeRate(rateResult);
      ref.read(transferStateNotifierProvider.notifier).setFee(feeResult);
    } catch (e) {
      // debugPrint('Error updating fee/rate: $e');
    }
  }

  Future<void> _submitTransfer() async {
    setState(() => _isLoading = true);

    try {
      // Vérification de sécurité Play Integrity
      final securityGate = ref.read(securityGateProvider);
      final canProceed = await securityGate.checkAndShowDialog(
        context,
        level: SecurityLevel.playStoreRequired,
        customTitle: 'Transfert sécurisé',
        customMessage:
            'Les transferts d\'argent nécessitent l\'installation '
            'de l\'application depuis Google Play Store pour garantir '
            'la sécurité de vos transactions.',
      );

      if (!canProceed) {
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser == null) throw Exception('Utilisateur non connecte');

      final transferState = ref.read(transferStateNotifierProvider);
      final selectedCurrency = ref.read(selectedCurrencyProvider);

      final transaction = await ref
          .read(transactionNotifierProvider.notifier)
          .createTransaction(
            senderId: currentUser.id,
            recipientId: transferState.selectedRecipient!.id,
            recipientName: transferState.selectedRecipient!.fullName,
            recipientPhone: transferState.selectedRecipient!.phone,
            amount: transferState.amount,
            currency: selectedCurrency,
            exchangeRate: transferState.exchangeRate!,
            fee: transferState.fee!,
            notes: transferState.notes,
          );

      if (transaction != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfert initie avec succes'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset state
        ref.read(transferStateNotifierProvider.notifier).reset();

        // Navigate to transfers list (replaces current route)
        // This way, back button from transaction details goes to /transfers
        context.go('/transfers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getRecipientIcon(RecipientType type) {
    switch (type) {
      case RecipientType.mobileWallet:
        return Icons.phone_android;
      case RecipientType.bankAccount:
        return Icons.account_balance;
      case RecipientType.cashPickup:
        return Icons.storefront;
    }
  }

  // Currencies commonly used for money transfers
  static const _transferCurrencies = [
    // Major diaspora currencies
    Currency.eur,
    Currency.usd,
    Currency.gbp,
    Currency.cad,
    Currency.chf,
    // Other common transfer currencies
    Currency.aud,
    Currency.nzd,
    Currency.sek,
    Currency.nok,
    Currency.dkk,
    // Middle East
    Currency.aed,
    Currency.sar,
    Currency.qar,
    Currency.kwd,
  ];

}
