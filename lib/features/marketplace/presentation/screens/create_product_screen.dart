import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/image_upload_provider.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/tax_provider.dart';
import '../../../../core/services/tax_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/marketplace_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class CreateProductScreen extends ConsumerStatefulWidget {
  final ProductEntity? product; // For editing

  /// Catégorie pré-cochée à l'ouverture (puces de l'état vide « rien mis en
  /// vente »). Ignorée en édition, où la catégorie vient du produit.
  final ProductCategory? initialCategory;

  const CreateProductScreen({super.key, this.product, this.initialCategory});

  @override
  ConsumerState<CreateProductScreen> createState() =>
      _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();

  ProductCategory _selectedCategory = ProductCategory.other;
  ProductCondition _selectedCondition = ProductCondition.newProduct;
  List<String> _existingImageUrls = [];
  final List<File> _newImages = [];
  bool _isLoading = false;

  // Tax settings
  String _selectedTaxOptionId = 'default';
  double? _customTaxRate;
  bool _taxIncludedInPrice = false;

  // Currency
  Currency _selectedCurrency = Currency.xof;

  // Country - will be initialized from user's profile
  Country? _selectedCountry;

  String _formatPrice(double amount) {
    return CurrencyService.instance.format(amount, _selectedCurrency);
  }

  // Common currencies shown first
  static const _commonCurrencies = [
    Currency.xof,
    Currency.eur,
    Currency.usd,
    Currency.xaf,
    Currency.ngn,
    Currency.ghs,
    Currency.gbp,
    Currency.cad,
  ];

  List<DropdownMenuItem<Currency>> _buildCurrencyItems() {
    final items = <DropdownMenuItem<Currency>>[];

    // Add common currencies first
    for (final currency in _commonCurrencies) {
      items.add(_buildCurrencyMenuItem(currency));
    }

    // Add divider
    items.add(
      DropdownMenuItem<Currency>(
        enabled: false,
        child: Divider(color: Colors.grey.shade300),
      ),
    );

    // Add remaining currencies
    for (final currency in Currency.values) {
      if (!_commonCurrencies.contains(currency)) {
        items.add(_buildCurrencyMenuItem(currency));
      }
    }

    return items;
  }

  DropdownMenuItem<Currency> _buildCurrencyMenuItem(Currency currency) {
    return DropdownMenuItem(
      value: currency,
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
  }

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.product == null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.product != null) {
      _titleController.text = widget.product!.title;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toStringAsFixed(0);
      _quantityController.text = widget.product!.quantity.toString();
      _locationController.text = widget.product!.location ?? '';
      _selectedCategory = widget.product!.category;
      _selectedCondition = widget.product!.condition;
      _existingImageUrls = List.from(widget.product!.imageUrls);
      // Currency
      _selectedCurrency = CurrencyExtension.fromCode(widget.product!.currency);
      // Country
      _selectedCountry = widget.product!.country;
      // Tax settings
      _taxIncludedInPrice = widget.product!.taxIncludedInPrice;
      if (widget.product!.customTaxRate != null) {
        if (widget.product!.customTaxRate == 0) {
          _selectedTaxOptionId = 'exempt';
        } else if (widget.product!.customTaxRate == 0.19) {
          _selectedTaxOptionId = 'standard';
        } else if (widget.product!.customTaxRate == 0.10) {
          _selectedTaxOptionId = 'reduced';
        } else {
          _selectedTaxOptionId = 'custom';
          _customTaxRate = widget.product!.customTaxRate;
        }
      }
    } else {
      _quantityController.text = '1';
      // Load user's country from profile
      _initUserCountry();
    }
  }

  void _initUserCountry() {
    try {
      final user = ref.read(currentUserAsyncProvider).valueOrNull;
      if (user != null) {
        final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
        if (profile?.currentCountry != null) {
          final countryName = profile!.currentCountry!;
          final country = Country.values.firstWhere(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
            orElse: () => Country.niger,
          );
          setState(() => _selectedCountry = country);
        } else {
          setState(() => _selectedCountry = Country.niger);
        }
      } else {
        setState(() => _selectedCountry = Country.niger);
      }
    } catch (_) {
      setState(() => _selectedCountry = Country.niger);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.marketplaceAddImageMin)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current Firebase user directly (avoids StreamProvider race conditions)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('Utilisateur non connecte');
      }

      // Try to get extended user data, or use Firebase user data as fallback
      final currentUserAsync = ref.read(currentUserAsyncProvider);
      final extendedUser = currentUserAsync.valueOrNull;

      final userId = extendedUser?.id ?? firebaseUser.uid;
      final displayName =
          extendedUser?.displayName ?? firebaseUser.displayName ?? l10n.seller;
      final photoUrl = extendedUser?.photoUrl ?? firebaseUser.photoURL;

      // Upload new images
      final imageUploadService = ref.read(imageUploadServiceProvider);
      final productId = widget.product?.id ?? const Uuid().v4();
      final uploadedUrls = <String>[];

      for (int i = 0; i < _newImages.length; i++) {
        final url = await imageUploadService.uploadImage(
          file: _newImages[i],
          type: ImageUploadType.product,
          id: '${productId}_$i',
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];

      // Determine effective custom tax rate
      double? effectiveCustomTaxRate;
      bool isTaxable = true;
      if (_selectedTaxOptionId == 'exempt') {
        effectiveCustomTaxRate = 0;
        isTaxable = false;
      } else if (_selectedTaxOptionId == 'standard') {
        effectiveCustomTaxRate = 0.19;
      } else if (_selectedTaxOptionId == 'reduced') {
        effectiveCustomTaxRate = 0.10;
      } else if (_selectedTaxOptionId == 'custom') {
        effectiveCustomTaxRate = _customTaxRate;
      }
      // 'default' leaves effectiveCustomTaxRate as null

      final product = ProductEntity(
        id: productId,
        sellerId: userId,
        sellerName: displayName,
        sellerPhotoUrl: photoUrl,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        currency: _selectedCurrency.code,
        imageUrls: allImageUrls,
        category: _selectedCategory,
        condition: _selectedCondition,
        location:
            _locationController.text.trim().isNotEmpty
                ? _locationController.text.trim()
                : null,
        country: _selectedCountry,
        quantity: int.parse(_quantityController.text),
        isTaxable: isTaxable,
        customTaxRate: effectiveCustomTaxRate,
        taxIncludedInPrice: _taxIncludedInPrice,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );

      final notifier = ref.read(productNotifierProvider.notifier);

      if (_isEditing) {
        await notifier.updateProduct(product);
      } else {
        await notifier.createProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Produit modifie' : 'Produit publie'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTaxSection(ThemeData theme) {
    final taxOptions = ref.watch(availableTaxOptionsProvider);
    final taxService = TaxService.instance;
    final categoryTaxRate = taxService.getTaxRate(_selectedCategory.name);
    final isCategoryExempt =
        !taxService.isCategoryTaxable(_selectedCategory.name);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                // Expanded : en-tête de carte, donc déjà plus étroit que la
                // page — le titre déborde sans lui aux grandes échelles.
                Expanded(
                  child: Text(
                    'Parametres de taxe',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCategoryExempt
                  ? 'Cette categorie est exoneree de taxe par defaut'
                  : 'Taxe par defaut pour cette categorie: ${(categoryTaxRate * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),

            // Tax option selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  taxOptions.map((option) {
                    final isSelected = _selectedTaxOptionId == option.id;
                    return ChoiceChip(
                      label: Text(option.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTaxOptionId = option.id;
                            if (option.rate != null) {
                              _customTaxRate = option.rate;
                            } else if (!option.isCustom) {
                              _customTaxRate = null;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
            ),

            // Custom tax rate input
            if (_selectedTaxOptionId == 'custom') ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue:
                    _customTaxRate != null
                        ? (_customTaxRate! * 100).toStringAsFixed(0)
                        : '',
                decoration: InputDecoration(
                  labelText: 'Taux personnalise (%)',
                  hintText: l10n.marketplaceCustomTaxHint,
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final rate = double.tryParse(value);
                  if (rate != null) {
                    setState(() {
                      _customTaxRate = rate / 100;
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 16),

            // Tax included in price switch
            SwitchListTile(
              title: Text(l10n.marketplacePriceTTC),
              subtitle: Text(
                _taxIncludedInPrice
                    ? 'Le prix affiche inclut deja la taxe'
                    : 'La taxe sera ajoutee au prix affiche',
                style: theme.textTheme.bodySmall,
              ),
              value: _taxIncludedInPrice,
              onChanged: (value) {
                setState(() {
                  _taxIncludedInPrice = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Tax preview
            if (_priceController.text.isNotEmpty) ...[
              const Divider(),
              _buildTaxPreview(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaxPreview(ThemeData theme) {
    final price = double.tryParse(_priceController.text) ?? 0;
    final quantity = int.tryParse(_quantityController.text) ?? 1;

    double effectiveRate;
    if (_selectedTaxOptionId == 'default') {
      effectiveRate = TaxService.instance.getTaxRate(_selectedCategory.name);
    } else if (_selectedTaxOptionId == 'exempt') {
      effectiveRate = 0;
    } else if (_selectedTaxOptionId == 'standard') {
      effectiveRate = 0.19;
    } else if (_selectedTaxOptionId == 'reduced') {
      effectiveRate = 0.10;
    } else {
      effectiveRate = _customTaxRate ?? 0;
    }

    final subtotal = price * quantity;
    double taxAmount;
    double total;

    if (_taxIncludedInPrice) {
      // Price already includes tax
      taxAmount = subtotal - (subtotal / (1 + effectiveRate));
      total = subtotal;
    } else {
      taxAmount = subtotal * effectiveRate;
      total = subtotal + taxAmount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Apercu',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(l10n.marketplaceSubtotal), Text(_formatPrice(subtotal))],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Taxe (${(effectiveRate * 100).toStringAsFixed(0)}%)'),
            Text(_formatPrice(taxAmount)),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.total,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatPrice(total),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editProductScreenTitle : l10n.sellProductScreenTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images
            Text(
              l10n.marketplacePhotos,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add image button
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.marketplaceAddPhoto,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Existing images
                  ..._existingImageUrls.asMap().entries.map((entry) {
                    return _ImageTile(
                      imageUrl: entry.value,
                      onRemove: () => _removeExistingImage(entry.key),
                    );
                  }),
                  // New images
                  ..._newImages.asMap().entries.map((entry) {
                    return _ImageTile(
                      file: entry.value,
                      onRemove: () => _removeNewImage(entry.key),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.marketplaceTitleLabel,
                hintText: l10n.marketplaceTitleHint,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.marketplaceTitleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.marketplaceDescriptionLabel,
                hintText: 'Decrivez votre produit...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.marketplaceDescriptionRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price, quantity and currency
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: l10n.marketplacePriceLabel,
                      hintText: '50000',
                      border: const OutlineInputBorder(),
                      suffixText: _selectedCurrency.code,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.priceRequiredError;
                      }
                      if (double.tryParse(value) == null) {
                        return l10n.priceInvalidError;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantite',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.adminFieldRequired;
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty < 1) {
                        return l10n.quantityInvalidError;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Currency selector
            DropdownButtonFormField<Currency>(
              initialValue: _selectedCurrency,
              decoration: InputDecoration(
                labelText: l10n.marketplaceCurrencyLabel,
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _buildCurrencyItems(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCurrency = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<ProductCategory>(
              initialValue: _selectedCategory,
              // L'item est une Row icône + libellé : `isExpanded` borne la
              // pile interne, et l'Expanded empêche cette Row-là de déborder
              // à son tour une fois bornée.
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categorie',
                border: OutlineInputBorder(),
              ),
              items:
                  ProductCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Condition
            DropdownButtonFormField<ProductCondition>(
              initialValue: _selectedCondition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Etat',
                border: OutlineInputBorder(),
              ),
              items:
                  ProductCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(
                        condition.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCondition = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Country
            DropdownButtonFormField<Country>(
              initialValue: _selectedCountry,
              decoration: InputDecoration(
                labelText: l10n.marketplaceCountryLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
              isExpanded: true,
              items: [
                // Priority countries first
                ...priorityCountries.map(
                  (country) => DropdownMenuItem(
                    value: country,
                    child: Row(
                      children: [
                        Text(
                          country.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        // `isExpanded` est déjà là, donc cette Row reçoit une
                        // largeur contrainte : sans Expanded, un nom de pays
                        // long la ferait déborder à son tour.
                        Expanded(
                          child: Text(
                            country.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                const DropdownMenuItem<Country>(
                  enabled: false,
                  child: Divider(),
                ),
                // Other countries
                ...Country.values
                    .where((c) => !priorityCountries.contains(c))
                    .map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Row(
                          children: [
                            Text(
                              country.flag,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            // Même Row que les pays prioritaires ci-dessus, et
                            // c'est la liste la plus longue : même borne.
                            Expanded(
                              child: Text(
                                country.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              onChanged: (value) {
                setState(() => _selectedCountry = value);
              },
              validator: (value) {
                if (value == null) {
                  return 'Selectionnez un pays';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.marketplaceCityLabel,
                hintText: l10n.marketplaceCityHint,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Tax settings section
            _buildTaxSection(theme),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          _isEditing ? l10n.save : l10n.publish,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _ImageTile({this.imageUrl, this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image:
                  imageUrl != null
                      ? NetworkImage(imageUrl!) as ImageProvider
                      : FileImage(file!),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: IconButton.filled(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
