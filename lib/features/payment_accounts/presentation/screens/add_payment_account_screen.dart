import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/payment_account_entity.dart';
import '../providers/payment_account_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class AddPaymentAccountScreen extends ConsumerStatefulWidget {
  const AddPaymentAccountScreen({super.key});

  @override
  ConsumerState<AddPaymentAccountScreen> createState() =>
      _AddPaymentAccountScreenState();
}

class _AddPaymentAccountScreenState
    extends ConsumerState<AddPaymentAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _ibanController = TextEditingController();
  final _bicController = TextEditingController();

  PaymentAccountType? _selectedType;
  MobileProvider _mobileProvider = MobileProvider.orangeMoney;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _labelController.dispose();
    _mobileNumberController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      String? maskedNumber;
      if (_selectedType == PaymentAccountType.mobileMoney &&
          _mobileNumberController.text.isNotEmpty) {
        maskedNumber = PaymentAccountEntity.maskNumber(
          _mobileNumberController.text,
        );
      } else if (_selectedType == PaymentAccountType.bankAccount &&
          _ibanController.text.isNotEmpty) {
        maskedNumber = PaymentAccountEntity.maskNumber(_ibanController.text);
      }

      final account = PaymentAccountEntity(
        id: '',
        userId: currentUser.id,
        type: _selectedType!,
        label: _labelController.text,
        isDefault: _isDefault,
        mobileProvider:
            _selectedType == PaymentAccountType.mobileMoney
                ? _mobileProvider
                : null,
        mobileNumber:
            _selectedType == PaymentAccountType.mobileMoney
                ? _mobileNumberController.text
                : null,
        bankName:
            _selectedType == PaymentAccountType.bankAccount
                ? _bankNameController.text
                : null,
        accountHolderName:
            _selectedType == PaymentAccountType.bankAccount
                ? _accountHolderController.text
                : null,
        iban:
            _selectedType == PaymentAccountType.bankAccount
                ? _ibanController.text
                : null,
        bic:
            _selectedType == PaymentAccountType.bankAccount &&
                    _bicController.text.isNotEmpty
                ? _bicController.text
                : null,
        maskedNumber: maskedNumber,
      );

      await ref
          .read(paymentAccountNotifierProvider.notifier)
          .addAccount(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountAdded),
            backgroundColor: context.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: context.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addPaymentAccount)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Step 1: Type selection
            Text(
              l10n.paymentAccountType,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTypeSelector(theme, l10n),
            const SizedBox(height: 24),

            // Step 2: Form fields based on type
            if (_selectedType != null) ...[
              // Label
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: l10n.paymentAccountLabel,
                  hintText: _getLabelHint(l10n),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.paymentAccountLabelRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Type-specific fields
              if (_selectedType == PaymentAccountType.mobileMoney)
                _buildMobileMoneyFields(theme, l10n),
              if (_selectedType == PaymentAccountType.bankAccount)
                _buildBankAccountFields(theme, l10n),
              if (_selectedType == PaymentAccountType.stripeConnect)
                _buildStripeConnectInfo(theme, l10n),

              const SizedBox(height: 16),

              // Default toggle
              SwitchListTile(
                title: Text(l10n.setAsDefault),
                subtitle: Text(l10n.setAsDefaultDesc),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
                secondary: const AppIcon(AppIcon.starBorder),
                activeThumbColor: theme.colorScheme.primary,
              ),

              const SizedBox(height: 32),

              // Save button
              if (_selectedType != PaymentAccountType.stripeConnect)
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    icon:
                        _isLoading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                            : const Icon(Icons.save),
                    label: Text(_isLoading ? l10n.saving : l10n.saveAccount),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme, AppLocalizations l10n) {
    final types = [
      (
        PaymentAccountType.mobileMoney,
        l10n.mobileMoney,
        Icons.phone_android_rounded,
        const Color(0xFFFF6600),
      ),
      (
        PaymentAccountType.bankAccount,
        l10n.bankAccount,
        Icons.account_balance_rounded,
        theme.colorScheme.primary,
      ),
      (
        PaymentAccountType.stripeConnect,
        l10n.stripeConnect,
        Icons.credit_card_rounded,
        const Color(0xFF635BFF),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          types.map((t) {
            final isSelected = _selectedType == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: MediaQuery.of(context).size.width / 2 - 28,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? t.$4.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? t.$4 : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(t.$3, size: 32, color: isSelected ? t.$4 : null),
                    const SizedBox(height: 8),
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? t.$4 : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMobileMoneyFields(ThemeData theme, AppLocalizations l10n) {
    final providers = [
      (MobileProvider.orangeMoney, 'Orange Money', const Color(0xFFFF6600)),
      (MobileProvider.moovMoney, 'Moov Money', const Color(0xFF0066CC)),
      (MobileProvider.airtelMoney, 'Airtel Money', const Color(0xFFE40000)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mobileProvider,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              providers.map((p) {
                final isSelected = _mobileProvider == p.$1;
                return ChoiceChip(
                  label: Text(p.$2),
                  selected: isSelected,
                  selectedColor: p.$3.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) setState(() => _mobileProvider = p.$1);
                  },
                );
              }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mobileNumberController,
          decoration: InputDecoration(
            labelText: l10n.mobileNumber,
            hintText: '+227 XX XX XX XX',
            prefixIcon: const Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.mobileNumberRequired;
            }
            if (value.length < 8) {
              return l10n.mobileNumberInvalid;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBankAccountFields(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        TextFormField(
          controller: _bankNameController,
          decoration: InputDecoration(
            labelText: l10n.bankName,
            hintText: l10n.bankNameHint,
            prefixIcon: AppIcon(AppIcon.bank, color: Theme.of(context).iconTheme.color!),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.bankNameRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _accountHolderController,
          decoration: InputDecoration(
            labelText: l10n.accountHolder,
            prefixIcon: AppIcon(AppIcon.person, color: Theme.of(context).iconTheme.color!),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.accountHolderRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ibanController,
          decoration: InputDecoration(
            labelText: l10n.ibanLabel,
            hintText: l10n.ibanHint,
            prefixIcon: const Icon(Icons.numbers),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.ibanRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bicController,
          decoration: InputDecoration(
            labelText: '${l10n.bicLabel} (${l10n.optional})',
            prefixIcon: const Icon(Icons.code),
          ),
        ),
      ],
    );
  }

  Widget _buildStripeConnectInfo(ThemeData theme, AppLocalizations l10n) {
    return Card(
      color: const Color(0xFF635BFF).withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.credit_card_rounded,
              size: 48,
              color: Color(0xFF635BFF),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.stripeConnectDesc,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // '/audio-rooms/monetization' n'existe pas : GoRouter la
                // matchait sur '/audio-rooms/:roomId' et ouvrait un salon
                // nommé « monetization ». L'onboarding Stripe Connect vit
                // dans l'écran des revenus créateur.
                context.push('/creator/earnings');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF635BFF),
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.stripeConnectSetup),
            ),
          ],
        ),
      ),
    );
  }

  String _getLabelHint(AppLocalizations l10n) {
    return switch (_selectedType) {
      PaymentAccountType.mobileMoney => 'Ex: Mon Orange Money',
      PaymentAccountType.bankAccount => 'Ex: Compte Ecobank',
      PaymentAccountType.stripeConnect => 'Stripe Connect',
      null => '',
    };
  }
}
