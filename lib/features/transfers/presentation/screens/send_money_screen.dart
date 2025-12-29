import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/currency_service.dart';
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
  bool _amountValid = false;
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
        title: const Text('Envoyer de l\'argent'),
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
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                _currentStep == 2 ? 'Confirmer' : 'Continuer',
                              ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Retour'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // Step 1: Select Recipient
            Step(
              title: const Text('Beneficiaire'),
              subtitle:
                  transferState.selectedRecipient != null
                      ? Text(transferState.selectedRecipient!.fullName)
                      : null,
              content: _buildRecipientStep(theme, transferState),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            // Step 2: Enter Amount
            Step(
              title: const Text('Montant'),
              subtitle:
                  transferState.amount > 0
                      ? Text(
                        '${transferState.amount.toStringAsFixed(2)} $selectedCurrency',
                      )
                      : null,
              content: _buildAmountStep(theme, selectedCurrency),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            // Step 3: Review & Confirm
            Step(
              title: const Text('Confirmation'),
              content: _buildConfirmationStep(theme, transferState),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
            ),
          ],
        ),
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Currency selector
        DropdownButtonFormField<String>(
          value: selectedCurrency,
          decoration: const InputDecoration(
            labelText: 'Devise',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: _buildTransferCurrencyItems(),
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedCurrencyProvider.notifier).select(value);
              ref
                  .read(transferStateNotifierProvider.notifier)
                  .setCurrency(value);
              // Mettre à jour le taux de change et les frais pour la nouvelle devise
              _updateFeeAndRateDebounced();
            }
          },
        ),
        const SizedBox(height: 16),

        // Amount input with real-time validation
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Montant a envoyer',
            border: const OutlineInputBorder(),
            prefixText: _getCurrencySymbol(selectedCurrency),
            suffixText: selectedCurrency,
            suffixIcon:
                _amountController.text.isNotEmpty
                    ? Icon(
                      _amountValid ? Icons.check_circle : Icons.error,
                      color: _amountValid ? Colors.green : Colors.red,
                    )
                    : null,
            helperText:
                _amountController.text.isEmpty
                    ? 'Minimum 5 $selectedCurrency'
                    : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Entrez un montant';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Montant invalide';
            }
            if (amount < 5) {
              return 'Minimum 5 $selectedCurrency';
            }
            return null;
          },
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            setState(() {
              _amountValid = amount >= 5;
            });
            ref.read(transferStateNotifierProvider.notifier).setAmount(amount);
            _updateFeeAndRateDebounced();
          },
        ),
        const SizedBox(height: 16),

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
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Le bénéficiaire recevra',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transferState.amountInXof.toStringAsFixed(0)} XOF',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
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

  String _getCurrencySymbol(String currencyCode) {
    final currency = CurrencyExtension.fromCode(currencyCode);
    return currency.symbol;
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

  List<DropdownMenuItem<String>> _buildTransferCurrencyItems() {
    return _transferCurrencies.map((currency) {
      return DropdownMenuItem<String>(
        value: currency.code,
        child: Row(
          children: [
            Text(currency.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              currency.code,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currency.name,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
