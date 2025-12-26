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

  @override
  void dispose() {
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
          onPressed: () => context.push('/transfers/recipients/add'),
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

            return Column(
              children:
                  recipients.map((recipient) {
                    final isSelected =
                        transferState.selectedRecipient?.id == recipient.id;
                    return Card(
                      color:
                          isSelected
                              ? theme.colorScheme.primaryContainer
                              : null,
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
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(recipient.phone),
                        trailing:
                            isSelected
                                ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                                : recipient.isFavorite
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                        onTap: () {
                          ref
                              .read(transferStateNotifierProvider.notifier)
                              .selectRecipient(recipient);
                        },
                      ),
                    );
                  }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
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
          items: const [
            DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
            DropdownMenuItem(value: 'USD', child: Text('USD - Dollar US')),
            DropdownMenuItem(value: 'GBP', child: Text('GBP - Livre Sterling')),
            DropdownMenuItem(
              value: 'CAD',
              child: Text('CAD - Dollar Canadien'),
            ),
            DropdownMenuItem(value: 'CHF', child: Text('CHF - Franc Suisse')),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedCurrencyProvider.notifier).select(value);
              ref
                  .read(transferStateNotifierProvider.notifier)
                  .setCurrency(value);
            }
          },
        ),
        const SizedBox(height: 16),

        // Amount input
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Montant a envoyer',
            border: const OutlineInputBorder(),
            prefixText: _getCurrencySymbol(selectedCurrency),
            suffixText: selectedCurrency,
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
            ref.read(transferStateNotifierProvider.notifier).setAmount(amount);
            _updateFeeAndRate();
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
                'Frais (2.5%)',
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
              _buildFeeRow(
                'Taux de change',
                '1 $selectedCurrency = ${transferState.exchangeRate!.toStringAsFixed(2)} ${Currency.xof.code}',
              ),
              _buildFeeRow(
                'Le beneficiaire recoit',
                '${transferState.amountInXof.toStringAsFixed(0)} ${Currency.xof.code}',
                isBold: true,
                color: theme.colorScheme.primary,
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
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
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
        await _submitTransfer();
        break;
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _updateFeeAndRate() async {
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

      ref
          .read(transferStateNotifierProvider.notifier)
          .setExchangeRate(rateResult);
      ref.read(transferStateNotifierProvider.notifier).setFee(feeResult);
    } catch (e) {
      debugPrint('Error updating fee/rate: $e');
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
        // Reset state
        ref.read(transferStateNotifierProvider.notifier).reset();

        // Navigate to transaction detail
        context.go('/transfers/${transaction.id}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfert initie avec succes'),
            backgroundColor: Colors.green,
          ),
        );
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

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'CA\$';
      case 'CHF':
        return 'CHF ';
      default:
        return '';
    }
  }
}
