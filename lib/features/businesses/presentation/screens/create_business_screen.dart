import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/presentation/widgets/location_picker_modal.dart';
import '../../domain/entities/business_entity.dart';
import '../providers/business_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Création d'une entreprise, et édition de la même fiche quand
/// [editBusinessId] est fourni (route `/businesses/:id/edit`).
class CreateBusinessScreen extends ConsumerStatefulWidget {
  /// Id de l'entreprise à éditer ; null en création.
  final String? editBusinessId;

  /// Entité déjà chargée quand la navigation vient de la fiche ; par lien
  /// profond `state.extra` est null et l'écran recharge via [editBusinessId].
  final BusinessEntity? initial;

  const CreateBusinessScreen({super.key, this.editBusinessId, this.initial});

  @override
  ConsumerState<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  BusinessCategory _selectedCategory = BusinessCategory.other;
  final List<File> _selectedImages = [];
  final List<String> _existingPhotoUrls = [];
  final List<String> _services = [];
  final _serviceController = TextEditingController();
  bool _isLoading = false;
  Country? _selectedCountry;
  String? _countryName;
  String _phoneCode = '+227'; // Default Niger

  // Position exacte (pins de la carte) : choisie sur la carte, ou géocodée
  // depuis l'adresse à la soumission si l'utilisateur n'a rien choisi.
  double? _latitude;
  double? _longitude;
  String? _positionAddress;

  // Édition : entité d'origine (fournie par la route, ou rechargée par id).
  BusinessEntity? _editing;
  bool _loadingInitial = false;
  String? _initialLoadError;

  bool get _isEdit => widget.editBusinessId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _prefill(widget.initial!);
    } else if (widget.editBusinessId != null) {
      _loadInitial(widget.editBusinessId!);
    }
  }

  void _prefill(BusinessEntity business) {
    _editing = business;
    _nameController.text = business.name;
    _descriptionController.text = business.description;
    _selectedCategory = business.category;
    _existingPhotoUrls
      ..clear()
      ..addAll(business.photoUrls);
    _emailController.text = business.email ?? '';
    _websiteController.text = business.website ?? '';
    _addressController.text = business.address ?? '';
    _cityController.text = business.city ?? '';
    _countryName = business.country;
    _services
      ..clear()
      ..addAll(business.services);
    _latitude = business.latitude;
    _longitude = business.longitude;

    // Le téléphone est stocké « +indicatif numéro » : re-séparer les deux.
    final phone = business.phone ?? '';
    if (phone.startsWith('+') && phone.contains(' ')) {
      final splitAt = phone.indexOf(' ');
      _phoneCode = phone.substring(0, splitAt);
      _phoneController.text = phone.substring(splitAt + 1);
    } else {
      _phoneController.text = phone;
    }
  }

  Future<void> _loadInitial(String businessId) async {
    setState(() => _loadingInitial = true);
    final result =
        await ref.read(businessRepositoryProvider).getBusinessById(businessId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingInitial = false;
        _initialLoadError = failure.message;
      }),
      (business) => setState(() {
        _loadingInitial = false;
        _prefill(business);
      }),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await ImageUploadService().pickMultipleImages(maxImages: 5);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _addService() {
    final service = _serviceController.text.trim();
    if (service.isNotEmpty && !_services.contains(service)) {
      setState(() {
        _services.add(service);
        _serviceController.clear();
      });
    }
  }

  Future<void> _pickPosition() async {
    final initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerModal(
        title: l10n.businessPositionOnMap,
        confirmLabel: l10n.useThisPosition,
        initialLocation: initial,
        onLocationSelected: (lat, lng, address) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
            _positionAddress = address;
            // Compléter l'adresse postale si elle est encore vide.
            if (_addressController.text.trim().isEmpty && address.isNotEmpty) {
              _addressController.text = address;
            }
          });
        },
      ),
    );
  }

  /// Repli quand aucune position n'a été choisie sur la carte : géocoder
  /// l'adresse saisie. Meilleur effort — un échec n'empêche pas la
  /// soumission, l'entreprise n'aura simplement pas de pin sur la carte.
  Future<void> _geocodeAddressFallback() async {
    if (_latitude != null && _longitude != null) return;
    final query = [
      _addressController.text.trim(),
      _cityController.text.trim(),
      _countryName ?? '',
    ].where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return;
    try {
      final results = await locationFromAddress(query)
          .timeout(const Duration(seconds: 5));
      if (results.isNotEmpty) {
        _latitude = results.first.latitude;
        _longitude = results.first.longitude;
      }
    } catch (_) {
      // Géocodage indisponible (hors ligne, adresse introuvable) : tant pis.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload images
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await ImageUploadService().uploadMultipleImages(
          files: _selectedImages,
          type: ImageUploadType.business,
          id: currentUser.id,
        );
      }

      await _geocodeAddressFallback();

      // Create business entity
      final phoneNumber = _phoneController.text.trim().isNotEmpty
          ? '$_phoneCode ${_phoneController.text.trim()}'
          : null;
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null;
      final website = _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : null;
      final address = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null;
      final city = _cityController.text.trim().isNotEmpty
          ? _cityController.text.trim()
          : null;

      final bool success;
      final notifier = ref.read(myBusinessNotifierProvider.notifier);
      if (_isEdit) {
        final business = _editing!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          photoUrls: [..._existingPhotoUrls, ...imageUrls],
          phone: phoneNumber,
          email: email,
          website: website,
          address: address,
          city: city,
          country: _countryName,
          latitude: _latitude,
          longitude: _longitude,
          services: List.of(_services),
        );
        success = await notifier.updateBusiness(business);
        if (success) {
          // La fiche détail lit ce provider : la resynchroniser.
          ref
              .read(businessDetailNotifierProvider.notifier)
              .loadBusiness(business.id);
        }
      } else {
        final business = BusinessEntity(
          id: '',
          ownerId: currentUser.id,
          ownerName: currentUser.displayName,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          photoUrls: imageUrls,
          phone: phoneNumber,
          email: email,
          website: website,
          address: address,
          city: city,
          country: _countryName,
          latitude: _latitude,
          longitude: _longitude,
          services: _services,
        );
        success = await notifier.createBusiness(business);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? l10n.businessUpdatedSuccess
                : l10n.businessCreatedSuccess),
          ),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.creationError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingInitial || _initialLoadError != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: DesignTitle(l10n.editBusiness, size: 22),
        ),
        body: Center(
          child: _loadingInitial
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _initialLoadError!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: DesignTitle(_isEdit ? l10n.editBusiness : l10n.newBusiness, size: 22),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images
            Text(l10n.photos, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add button
                  InkWell(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_photo_alternate, size: 40),
                    ),
                  ),
                  // Photos déjà en ligne (mode édition)
                  ..._existingPhotoUrls.map((url) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url,
                                width: 100, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _existingPhotoUrls.remove(url));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(AppIcon.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Selected images
                  ..._selectedImages.map((file) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedImages.remove(file));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(AppIcon.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category
            Text(l10n.category, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _selectedCategory,
              // L'item est une Row icône + libellé : `isExpanded` borne la
              // pile interne, et l'Expanded empêche cette Row-là de déborder
              // à son tour une fois bornée.
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: BusinessCategory.values.map((category) {
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

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'entreprise *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.nameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.businessDescriptionLabel,
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.descriptionRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Contact
            Text(l10n.contact, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: l10n.phone,
                border: const OutlineInputBorder(),
                prefixIcon: const AppIcon(AppIcon.call),
                prefixText: '$_phoneCode ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: l10n.website,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Location
            Text(l10n.locationTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            // Country picker
            InkWell(
              onTap: () {
                showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  countryListTheme: CountryListThemeData(
                    flagSize: 25,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    textStyle: theme.textTheme.bodyMedium,
                    bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    inputDecoration: InputDecoration(
                      labelText: l10n.searchCountry,
                      hintText: l10n.typeCountryName,
                      prefixIcon: const AppIcon(AppIcon.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country;
                      _countryName = country.name;
                      _phoneCode = '+${country.phoneCode}';
                    });
                  },
                );
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.country,
                  border: const OutlineInputBorder(),
                  prefixIcon: _selectedCountry != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _selectedCountry!.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        )
                      : const AppIcon(AppIcon.flag),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _countryName ?? l10n.selectCountry,
                  style: _countryName != null
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: l10n.city,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: l10n.address,
                border: OutlineInputBorder(),
                prefixIcon: AppIcon(AppIcon.location),
              ),
            ),
            const SizedBox(height: 16),

            // Position exacte : sans elle, l'entreprise n'a pas de pin sur
            // la carte (les requêtes filtrent sur latitude/longitude).
            InkWell(
              onTap: _pickPosition,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.businessPositionOnMap,
                  helperText: l10n.businessPositionHelp,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: _latitude != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _latitude = null;
                              _longitude = null;
                              _positionAddress = null;
                            });
                          },
                        )
                      : const Icon(Icons.map_outlined),
                ),
                child: Text(
                  _latitude != null
                      ? (_positionAddress?.isNotEmpty == true
                          ? _positionAddress!
                          : '${_latitude!.toStringAsFixed(5)}, '
                              '${_longitude!.toStringAsFixed(5)}')
                      : l10n.setBusinessPosition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _latitude != null
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Services
            Text(l10n.offeredServices, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serviceController,
                    decoration: InputDecoration(
                      hintText: l10n.addService,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addService(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addService,
                  icon: const AppIcon(AppIcon.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _services.map((service) {
                return Chip(
                  label: Text(service),
                  onDeleted: () {
                    setState(() => _services.remove(service));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? l10n.save : l10n.createTheBusiness),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
