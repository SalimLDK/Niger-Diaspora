import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../../kit/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/businesses/domain/entities/business_entity.dart';
import '../../../../features/businesses/presentation/providers/business_provider.dart';

class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  ConsumerState<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
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
  final List<String> _services = [];
  final _serviceController = TextEditingController();
  bool _isLoading = false;
  Country? _selectedCountry;
  String _phoneCode = '+227'; // Default Niger

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
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

      // Create business entity
      final phoneNumber = _phoneController.text.trim().isNotEmpty
          ? '$_phoneCode ${_phoneController.text.trim()}'
          : null;

      final business = BusinessEntity(
        id: '',
        ownerId: currentUser.id,
        ownerName: currentUser.displayName,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        photoUrls: imageUrls,
        phone: phoneNumber,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        website: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        country: _selectedCountry?.name,
        services: _services,
      );

      final success = await ref.read(myBusinessNotifierProvider.notifier).createBusiness(business);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entreprise creee avec succes!')),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la creation')),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const DesignTitle('Nouvelle entreprise', size: 22),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images
            Text('Photos', style: theme.textTheme.titleMedium),
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
            Text('Categorie', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _selectedCategory,
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
                      Text(category.label),
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
                  return 'Le nom est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La description est requise';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Contact
            Text('Contact', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Telephone',
                border: const OutlineInputBorder(),
                prefixIcon: const AppIcon(AppIcon.call),
                prefixText: '$_phoneCode ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Site web',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Location
            Text('Localisation', style: theme.textTheme.titleMedium),
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
                      labelText: 'Rechercher un pays',
                      hintText: 'Tapez le nom du pays',
                      prefixIcon: const AppIcon(AppIcon.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country;
                      _phoneCode = '+${country.phoneCode}';
                    });
                  },
                );
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Pays',
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
                  _selectedCountry?.name ?? 'Selectionner un pays',
                  style: _selectedCountry != null
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
              decoration: const InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
                prefixIcon: AppIcon(AppIcon.location),
              ),
            ),
            const SizedBox(height: 24),

            // Services
            Text('Services proposes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serviceController,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un service',
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
                    : const Text('Creer l\'entreprise'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
