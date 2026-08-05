import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/recipient_entity.dart';
import '../providers/transfer_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class AddRecipientScreen extends ConsumerStatefulWidget {
  final RecipientEntity? existingRecipient;

  const AddRecipientScreen({super.key, this.existingRecipient});

  @override
  ConsumerState<AddRecipientScreen> createState() => _AddRecipientScreenState();
}

class _AddRecipientScreenState extends ConsumerState<AddRecipientScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();

  RecipientType _selectedType = RecipientType.mobileWallet;
  String? _selectedMobileProvider;
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _isSubmitting = false; // Guard against double submission

  bool get _isEditing => widget.existingRecipient != null;

  static const List<String> _mobileProviders = [
    'Orange Money',
    'Airtel Money',
    'Moov Money',
    'Zamani',
  ];

  static const List<String> _nigerBanks = [
    'BOA Niger',
    'Ecobank Niger',
    'BIA Niger',
    'SONIBANK',
    'Banque Atlantique',
    'Coris Bank',
    'BSIC Niger',
    'Autre',
  ];

  static const List<String> _nigerCities = [
    'Niamey',
    'Zinder',
    'Maradi',
    'Tahoua',
    'Agadez',
    'Dosso',
    'Diffa',
    'Tillaberi',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final recipient = widget.existingRecipient!;
    _fullNameController.text = recipient.fullName;
    _phoneController.text = recipient.phone;
    _emailController.text = recipient.email ?? '';
    _cityController.text = recipient.city ?? '';
    _addressController.text = recipient.address ?? '';
    _bankNameController.text = recipient.bankName ?? '';
    _bankAccountController.text = recipient.bankAccountNumber ?? '';
    _selectedType = recipient.type;
    _selectedMobileProvider = recipient.mobileProvider;
    _isFavorite = recipient.isFavorite;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.recipientEditTitle : l10n.recipientNewTitle,
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),
            _buildRecipientTypeSection(),
            const SizedBox(height: 24),
            _buildPaymentDetailsSection(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildFavoriteToggle(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.personalInfo,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: l10n.transferFullNameLabel,
            hintText: l10n.transferFullNameHint,
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.nameRequired;
            }
            if (value.trim().length < 3) {
              return l10n.nameMinLength;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: l10n.transferPhoneLabel,
            hintText: '+227 XX XX XX XX',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le numéro de téléphone est requis';
            }
            final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
            if (cleaned.length < 8) {
              return l10n.phoneVerifInvalidNumber;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: l10n.transferEmailOptional,
            hintText: l10n.transferEmailHint,
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.contains('@') || !value.contains('.')) {
                return l10n.invalidEmail;
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRecipientTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recipientTypeTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...RecipientType.values.map((type) => _buildTypeOption(type)),
      ],
    );
  }

  Widget _buildTypeOption(RecipientType type) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedMobileProvider = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            children: [
              Icon(
                _getTypeIcon(type),
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      type.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(RecipientType type) {
    switch (type) {
      case RecipientType.mobileWallet:
        return Icons.phone_android;
      case RecipientType.bankAccount:
        return Icons.account_balance;
      case RecipientType.cashPickup:
        return Icons.storefront;
    }
  }

  Widget _buildPaymentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paymentDetailsTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_selectedType == RecipientType.mobileWallet)
          _buildMobileWalletFields()
        else if (_selectedType == RecipientType.bankAccount)
          _buildBankAccountFields()
        else
          _buildCashPickupInfo(),
      ],
    );
  }

  Widget _buildMobileWalletFields() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedMobileProvider,
      // `prefixIcon` retire ~48 px à la largeur disponible : sans `isExpanded`
      // la pile interne du menu, dimensionnée sur son plus long libellé,
      // déborde d'autant plus tôt.
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Opérateur mobile *',
        prefixIcon: Icon(Icons.sim_card_outlined),
      ),
      items:
          _mobileProviders.map((provider) {
            return DropdownMenuItem(
              value: provider,
              child: Text(
                provider,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedMobileProvider = value;
        });
      },
      validator: (value) {
        if (_selectedType == RecipientType.mobileWallet && value == null) {
          return 'Sélectionnez un opérateur';
        }
        return null;
      },
    );
  }

  Widget _buildBankAccountFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              _bankNameController.text.isEmpty
                  ? null
                  : _bankNameController.text,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.transferBankName,
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          items:
              _nigerBanks.map((bank) {
                return DropdownMenuItem(
                  value: bank,
                  child: Text(
                    bank,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _bankNameController.text = value ?? '';
            });
          },
          validator: (value) {
            if (_selectedType == RecipientType.bankAccount &&
                (value == null || value.isEmpty)) {
              return l10n.recipientSelectBank;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bankAccountController,
          decoration: InputDecoration(
            labelText: l10n.recipientAccountNumber,
            hintText: l10n.transferAccountHint,
            prefixIcon: Icon(Icons.credit_card_outlined),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_selectedType == RecipientType.bankAccount) {
              if (value == null || value.trim().isEmpty) {
                return l10n.transferAccountNumberRequired;
              }
              if (value.replaceAll(' ', '').length < 10) {
                return l10n.recipientAccountNumberInvalid;
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCashPickupInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Le bénéficiaire pourra retirer l\'argent dans un point de service NITA avec une pièce d\'identité.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.locationTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _cityController.text.isEmpty ? null : _cityController.text,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.transferCityLabel,
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items:
              _nigerCities.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _cityController.text = value ?? '';
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: l10n.transferAddressOptional,
            hintText: l10n.transferAddressHint,
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildFavoriteToggle() {
    return SwitchListTile(
      title: Text(l10n.transferAddToFavorites),
      subtitle: Text(l10n.transferFavoritesSubtitle),
      value: _isFavorite,
      onChanged: (value) {
        setState(() {
          _isFavorite = value;
        });
      },
      secondary: Icon(
        _isFavorite ? Icons.star : Icons.star_border,
        color: _isFavorite ? Colors.amber : Colors.grey,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child:
          _isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Text(
                _isEditing
                    ? l10n.saveChanges
                    : l10n.addRecipientButton,
              ),
    );
  }

  Future<void> _submit() async {
    // Guard against double submission (sync check before async setState)
    if (_isSubmitting || _isLoading) {
      // debugPrint(
      //   '🚫 Submit blocked: _isSubmitting=$_isSubmitting, _isLoading=$_isLoading',
      // );
      return;
    }
    _isSubmitting = true;
    // debugPrint('✅ Submit started');

    if (!_formKey.currentState!.validate()) {
      // debugPrint('❌ Form validation failed');
      _isSubmitting = false;
      return;
    }

    setState(() => _isLoading = true);

    bool navigatedSuccessfully = false;

    try {
      final user = ref.read(currentUserAsyncProvider).value;
      if (user == null) {
        throw Exception(l10n.transferUserNotConnected);
      }

      // debugPrint('👤 User: ${user.id}');

      final recipient = RecipientEntity(
        id: widget.existingRecipient?.id ?? '',
        userId: user.id,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        type: _selectedType,
        mobileProvider:
            _selectedType == RecipientType.mobileWallet
                ? _selectedMobileProvider
                : null,
        bankName:
            _selectedType == RecipientType.bankAccount
                ? _bankNameController.text.trim()
                : null,
        bankAccountNumber:
            _selectedType == RecipientType.bankAccount
                ? _bankAccountController.text.trim()
                : null,
        city: _cityController.text.isEmpty ? null : _cityController.text,
        address:
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        isFavorite: _isFavorite,
        createdAt: widget.existingRecipient?.createdAt,
        lastUsedAt: widget.existingRecipient?.lastUsedAt,
      );

      // debugPrint('💾 Saving recipient: ${recipient.fullName}');

      final notifier = ref.read(recipientNotifierProvider.notifier);

      if (_isEditing) {
        await notifier.updateRecipient(recipient);
        // debugPrint('✏️ Recipient updated');
      } else {
        await notifier.createRecipient(recipient);
        // debugPrint('➕ Recipient created');
      }

      // debugPrint('📱 mounted=$mounted');

      if (mounted) {
        navigatedSuccessfully = true;
        // debugPrint('🎉 Showing success snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? l10n.recipientModified
                  : l10n.recipientAdded,
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // debugPrint('🔙 canPop=${context.canPop()}');
        if (context.canPop()) {
          // debugPrint('🚀 Calling context.pop()');
          context.pop(recipient);
          // debugPrint('✅ context.pop() called');
        } else {
          // debugPrint('⚠️ Cannot pop - no route to pop');
        }
      }
    } catch (e) {
      // debugPrint('❌ Error in submit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isSubmitting = false;
      // debugPrint(
      //   '🔄 Finally block: navigatedSuccessfully=$navigatedSuccessfully, mounted=$mounted',
      // );
      // Only update loading state if we didn't navigate away successfully
      if (!navigatedSuccessfully && mounted) {
        // debugPrint('⏸️ Setting _isLoading=false');
        setState(() => _isLoading = false);
      } else {
        // debugPrint('✋ Skipping setState (navigated or not mounted)');
      }
    }
    // debugPrint('🏁 Submit method completed');
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.transferDeleteRecipient),
            content: Text(
              'Voulez-vous vraiment supprimer ${widget.existingRecipient?.fullName} de vos bénéficiaires ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.undo),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(currentUserAsyncProvider).value;
        if (user == null) throw Exception(l10n.transferUserNotConnected);

        await ref
            .read(recipientNotifierProvider.notifier)
            .deleteRecipient(widget.existingRecipient!.id, user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.transferRecipientDeleted),
              backgroundColor: AppColors.success,
            ),
          );
          if (context.canPop()) {
            context.pop();
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
