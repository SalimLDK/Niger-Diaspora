import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../providers/profile_provider.dart';
import '../../../../shared/widgets/app_icon.dart';

class ProfileConfigScreen extends ConsumerStatefulWidget {
  const ProfileConfigScreen({super.key});

  @override
  ConsumerState<ProfileConfigScreen> createState() =>
      _ProfileConfigScreenState();
}

class _ProfileConfigScreenState extends ConsumerState<ProfileConfigScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Basic info
  final _displayNameController = TextEditingController();
  bool _hasManuallyEdited = false;
  String? _selectedProfession;

  // Location preferences
  CountryOption? _selectedCountry;
  final _selectedCityController = TextEditingController();
  bool _shareLocation = true;

  // Niger origin
  String? _selectedOriginRegion;
  String? _selectedOriginCity;
  final _customOriginCityController = TextEditingController();

  // Photo
  String? _photoUrl;

  // Interests
  final Set<String> _selectedInterests = {};
  final List<String> _availableInterests = [
    'Culture',
    'Sport',
    'Business',
    'Education',
    'Technologie',
    'Arts',
    'Santé',
    'Politique',
  ];

  // Notifications
  bool _enableNotifications = true;
  bool _enableEventNotifications = true;
  bool _enableMessageNotifications = true;

  // Theme
  AppThemeMode _selectedThemeMode = AppThemeMode.system;
  AppThemeColor _selectedThemeColor = AppThemeColor.green;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    // Load display name on next frame after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    // debugPrint('🔵 DEBUG: _loadInitialData called');
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;

    if (currentUser != null && mounted) {
      // debugPrint('🟢 DEBUG: User found: ${currentUser.id}');
      setState(() {
        // 1. Try pre-fill displayName from Firebase Auth user
        if (!_hasManuallyEdited &&
            currentUser.displayName != null &&
            currentUser.displayName!.isNotEmpty) {
          _displayNameController.text = currentUser.displayName!;
          // debugPrint(
          //   '✅ DEBUG: DisplayName set from Auth: ${currentUser.displayName}',
          // );
        }

        // 2. Try to load additional data from profile
        final profile =
            ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;
        if (profile != null) {
          // debugPrint('🟢 DEBUG: Profile found: ${profile.toString()}');

          // Fallback: If Auth name was empty but profile has name, use it
          if (!_hasManuallyEdited &&
              _displayNameController.text.isEmpty &&
              profile.displayName != null &&
              profile.displayName!.isNotEmpty) {
            _displayNameController.text = profile.displayName!;
            // debugPrint(
            //   '✅ DEBUG: DisplayName set from Profile: ${profile.displayName}',
            // );
          }

          // Pre-fill profession
          if (profile.profession != null && profile.profession!.isNotEmpty) {
            _selectedProfession = profile.profession;
            // debugPrint('✅ DEBUG: Profession set: ${profile.profession}');
          }
        } else {
          // debugPrint('🟠 DEBUG: Profile is null');
        }
      });
    } else {
      // debugPrint('🔴 DEBUG: currentUser is null in _loadInitialData');
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _selectedCityController.dispose();
    _customOriginCityController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete(currentUser) async {
    setState(() => _isLoading = true);

    try {
      final profile =
          ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;

      if (profile == null) {
        throw Exception(
          'Profil introuvable. Veuillez redémarrer l\'application.',
        );
      }

      // Get final origin city
      String? finalOriginCity;
      if (_selectedOriginCity == 'Autre') {
        finalOriginCity = _customOriginCityController.text.trim();
      } else {
        finalOriginCity = _selectedOriginCity;
      }

      // Update profile with configuration
      final updatedProfile = profile.copyWith(
        displayName: _displayNameController.text.trim(),
        profession: _selectedProfession,
        currentCountry: _selectedCountry?.name,
        countryCode: _selectedCountry?.code,
        currentCity: _selectedCityController.text.trim(),
        originRegion:
            _selectedOriginRegion == 'Autre' ? null : _selectedOriginRegion,
        originCity: finalOriginCity,
        shareLocation: _shareLocation,
        notificationsEnabled: _enableNotifications,
        interests: _selectedInterests.toList(),
        photoUrl: _photoUrl,
      );

      await ref
          .read(profileNotifierProvider(currentUser.id).notifier)
          .updateProfile(updatedProfile);

      // Theme settings are already applied when user selects them
      // No need to apply again here

      // Mark profile configuration as complete via onboarding provider
      await ref
          .read(onboardingNotifierProvider.notifier)
          .markProfileConfigComplete();
    } catch (
      e //, stackTrace
    ) {
      // Log error for debugging only in debug mode
      // debugPrint('Error in _handleComplete: $e');
      // debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('SSL') ||
                      e.toString().contains('Connection')
                  ? 'Erreur de connexion. Vérifiez votre connexion internet.'
                  : e.toString().contains('Utilisateur non connecté')
                  ? 'Utilisateur non connecté. Veuillez vous reconnecter.'
                  : e.toString().contains('Profil introuvable')
                  ? 'Profil introuvable. Veuillez redémarrer l\'application.'
                  : 'Erreur: $e',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action:
                currentUser != null
                    ? SnackBarAction(
                      label: 'Réessayer',
                      textColor: Colors.white,
                      onPressed: () => _handleComplete(currentUser),
                    )
                    : null,
          ),
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
    // Watch currentUser to ensure it's available
    final currentUserAsync = ref.watch(currentUserAsyncProvider);
    final currentUser = currentUserAsync.valueOrNull;

    // Listen to currentUser changes to populate name
    ref.listen(currentUserAsyncProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null &&
          !_hasManuallyEdited &&
          _displayNameController.text.isEmpty) {
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          setState(() => _displayNameController.text = user.displayName!);
        }
      }
    });

    // Listen to profile changes to populate name/profession
    if (currentUser != null) {
      ref.listen(profileNotifierProvider(currentUser.id), (_, next) {
        final profile = next.valueOrNull;
        if (profile != null) {
          if (!_hasManuallyEdited &&
              _displayNameController.text.isEmpty &&
              profile.displayName != null &&
              profile.displayName!.isNotEmpty) {
            setState(() => _displayNameController.text = profile.displayName!);
          }
          if (_selectedProfession == null &&
              profile.profession != null &&
              profile.profession!.isNotEmpty) {
            setState(() => _selectedProfession = profile.profession);
          }
        }
      });
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Configuration du profil'),
        backgroundColor: context.surfaceColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: context.outlineColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              context.adaptivePrimaryColor,
            ),
          ),

          Expanded(child: _buildCurrentStep()),

          // Navigation buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Précédent'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading || currentUser == null
                              ? null
                              : () {
                                if (_currentStep < 3) {
                                  setState(() => _currentStep++);
                                } else {
                                  _handleComplete(currentUser);
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.adaptivePrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(_currentStep < 3 ? 'Suivant' : 'Terminer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildLocationStep();
      case 1:
        return _buildInterestsStep();
      case 2:
        return _buildNotificationsStep();
      case 3:
        return _buildThemeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLocationStep() {
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    final displayName = currentUser?.displayName ?? 'Utilisateur';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo upload section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: context.adaptivePrimaryColor.withValues(
                        alpha: 0.2,
                      ),
                      backgroundImage:
                          _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child:
                          _photoUrl == null
                              ? Text(
                                _getInitials(displayName),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: context.adaptivePrimaryColor,
                                ),
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.adaptivePrimaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.backgroundColor,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Photo de profil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optionnel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Name field
          TextField(
            controller: _displayNameController,
            onChanged: (_) => _hasManuallyEdited = true,
            decoration: InputDecoration(
              labelText: 'Nom complet',
              hintText: 'Ex: Jean Dupont',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const AppIcon(AppIcon.person),
            ),
          ),
          const SizedBox(height: 16),

          // Profession dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedProfession,
            decoration: InputDecoration(
              labelText: 'Profession',
              prefixIcon: const Icon(Icons.work),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            hint: const Text('Sélectionnez votre profession'),
            isExpanded: true,
            items:
                ProfileOptions.professions.map((profession) {
                  return DropdownMenuItem(
                    value: profession,
                    child: Text(profession),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => _selectedProfession = value);
            },
          ),
          const SizedBox(height: 24),

          AppIcon(
            AppIcon.location,
            size: 64,
            color: context.adaptivePrimaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Votre localisation',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cela nous aide à vous connecter avec des membres proches de chez vous.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 24),

          // Country dropdown
          _buildCountryDropdown(),
          const SizedBox(height: 16),

          // City text field
          TextField(
            controller: _selectedCityController,
            decoration: InputDecoration(
              labelText: 'Ville actuelle',
              hintText: 'Ex: Paris, Niamey, New York...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 24),

          // Origin section
          Text(
            'Origine au Niger',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Optionnel - Votre région et ville d\'origine',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          // Origin region dropdown
          _buildOriginRegionDropdown(),
          const SizedBox(height: 16),

          // Origin city dropdown
          if (_selectedOriginRegion != null && _selectedOriginRegion != 'Autre')
            _buildOriginCityDropdown(),
          if (_selectedOriginRegion == 'Autre' ||
              _selectedOriginCity == 'Autre') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customOriginCityController,
              decoration: InputDecoration(
                labelText: 'Précisez votre ville d\'origine',
                hintText: 'Votre ville...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
          ],
          const SizedBox(height: 24),

          SwitchListTile(
            title: const Text('Partager ma localisation'),
            subtitle: const Text(
              'Apparaître sur la carte pour les autres membres',
            ),
            value: _shareLocation,
            onChanged: (value) => setState(() => _shareLocation = value),
            activeThumbColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Widget _buildInterestsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.interests, size: 64, color: context.adaptivePrimaryColor),
          const SizedBox(height: 16),
          Text(
            'Vos centres d\'intérêt',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez vos domaines d\'intérêt pour personnaliser votre expérience.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 32),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                _availableInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                    selectedColor: context.adaptivePrimaryColor.withValues(
                      alpha: 0.3,
                    ),
                    checkmarkColor: context.adaptivePrimaryColor,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active,
            size: 64,
            color: context.adaptivePrimaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Notifications',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Restez informé des activités importantes de la communauté.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 32),

          SwitchListTile(
            title: const Text('Activer les notifications'),
            subtitle: const Text('Recevoir toutes les notifications'),
            value: _enableNotifications,
            onChanged: (value) => setState(() => _enableNotifications = value),
            activeThumbColor: context.adaptivePrimaryColor,
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Événements'),
            subtitle: const Text('Nouveaux événements dans votre ville'),
            value: _enableEventNotifications,
            onChanged:
                _enableNotifications
                    ? (value) =>
                        setState(() => _enableEventNotifications = value)
                    : null,
            activeThumbColor: context.adaptivePrimaryColor,
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Messages'),
            subtitle: const Text('Nouveaux messages et conversations'),
            value: _enableMessageNotifications,
            onChanged:
                _enableNotifications
                    ? (value) =>
                        setState(() => _enableMessageNotifications = value)
                    : null,
            activeThumbColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }

  // Image picker methods
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.photo_camera,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Changer la photo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ImagePickerOption(
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: context.adaptivePrimaryColor,
                  ),
                  title: 'Prendre une photo',
                  subtitle: 'Utiliser l\'appareil photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _ImagePickerOption(
                  icon: Icon(
                    Icons.photo_library_outlined,
                    color: context.adaptivePrimaryColor,
                  ),
                  title: 'Choisir dans la galerie',
                  subtitle: 'Sélectionner une image existante',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_photoUrl != null)
                  _ImagePickerOption(
                    icon: const AppIcon(AppIcon.delete, color: AppColors.error),
                    title: 'Supprimer la photo',
                    subtitle: 'Utiliser les initiales par défaut',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _photoUrl = null);
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
    );

    if (image != null) {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser != null) {
        setState(() => _isLoading = true);
        final url = await ref
            .read(profileNotifierProvider(currentUser.id).notifier)
            .uploadPhoto(image.path);
        if (url != null) {
          setState(() {
            _photoUrl = url;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Dropdown builders
  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<CountryOption>(
      initialValue: _selectedCountry,
      decoration: InputDecoration(
        labelText: 'Pays actuel',
        prefixIcon: const AppIcon(AppIcon.public),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('Sélectionnez votre pays'),
      isExpanded: true,
      items:
          ProfileOptions.countries.map((country) {
            return DropdownMenuItem(
              value: country,
              child: Text(country.displayName),
            );
          }).toList(),
      onChanged: (value) {
        setState(() => _selectedCountry = value);
      },
    );
  }

  Widget _buildOriginRegionDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedOriginRegion,
      decoration: InputDecoration(
        labelText: 'Région d\'origine',
        prefixIcon: const Icon(Icons.map_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('Sélectionnez votre région'),
      isExpanded: true,
      items:
          ProfileOptions.regions.map((region) {
            return DropdownMenuItem(value: region, child: Text(region));
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedOriginRegion = value;
          _selectedOriginCity = null;
          _customOriginCityController.clear();
        });
      },
    );
  }

  Widget _buildOriginCityDropdown() {
    final cities =
        _selectedOriginRegion != null
            ? ProfileOptions.getCitiesForRegion(_selectedOriginRegion!)
            : <String>[];

    return DropdownButtonFormField<String>(
      initialValue: _selectedOriginCity,
      decoration: InputDecoration(
        labelText: 'Ville d\'origine',
        prefixIcon: const Icon(Icons.home_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('Sélectionnez votre ville'),
      isExpanded: true,
      items:
          cities.map((city) {
            return DropdownMenuItem(value: city, child: Text(city));
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedOriginCity = value;
          if (value != 'Autre') {
            _customOriginCityController.clear();
          }
        });
      },
    );
  }

  // Theme step
  Widget _buildThemeStep() {
    // Use current theme values directly
    final currentThemeMode = ref.watch(themeModeNotifierProvider);
    final currentThemeColor = ref.watch(themeColorNotifierProvider);

    // Initialize local state with current values if not already set
    if (!_themeInitialized) {
      _selectedThemeMode = currentThemeMode;
      _selectedThemeColor = currentThemeColor;
      _themeInitialized = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.palette, size: 64, color: context.adaptivePrimaryColor),
          const SizedBox(height: 16),
          Text(
            'Thème de l\'application',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Personnalisez l\'apparence de l\'application selon vos préférences.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 32),

          // Theme mode selection
          Text(
            'Mode d\'affichage',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _ThemeModeOption(
            icon: Icons.light_mode,
            title: 'Clair',
            subtitle: 'Thème lumineux',
            isSelected: _selectedThemeMode == AppThemeMode.light,
            onTap: () {
              setState(() => _selectedThemeMode = AppThemeMode.light);
              ref
                  .read(themeModeNotifierProvider.notifier)
                  .setThemeMode(AppThemeMode.light);
            },
          ),
          const SizedBox(height: 12),
          _ThemeModeOption(
            icon: Icons.dark_mode,
            title: 'Sombre',
            subtitle: 'Thème sombre',
            isSelected: _selectedThemeMode == AppThemeMode.dark,
            onTap: () {
              setState(() => _selectedThemeMode = AppThemeMode.dark);
              ref
                  .read(themeModeNotifierProvider.notifier)
                  .setThemeMode(AppThemeMode.dark);
            },
          ),
          const SizedBox(height: 12),
          _ThemeModeOption(
            icon: Icons.brightness_auto,
            title: 'Automatique',
            subtitle: 'Suit les paramètres du système',
            isSelected: _selectedThemeMode == AppThemeMode.system,
            onTap: () {
              setState(() => _selectedThemeMode = AppThemeMode.system);
              ref
                  .read(themeModeNotifierProvider.notifier)
                  .setThemeMode(AppThemeMode.system);
            },
          ),
          const SizedBox(height: 32),

          // Theme color selection
          Text(
            'Couleur du thème',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ThemeColorOption(
                  color: const Color(0xFF4CAF50),
                  title: 'Vert',
                  isSelected: _selectedThemeColor == AppThemeColor.green,
                  onTap: () {
                    setState(() => _selectedThemeColor = AppThemeColor.green);
                    ref
                        .read(themeColorNotifierProvider.notifier)
                        .setThemeColor(AppThemeColor.green);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ThemeColorOption(
                  color: const Color(0xFFFF9800),
                  title: 'Orange',
                  isSelected: _selectedThemeColor == AppThemeColor.orange,
                  onTap: () {
                    setState(() => _selectedThemeColor = AppThemeColor.orange);
                    ref
                        .read(themeColorNotifierProvider.notifier)
                        .setThemeColor(AppThemeColor.orange);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper widgets
class _ImagePickerOption extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ImagePickerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: context.borderColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDestructive
                        ? AppColors.error.withValues(alpha: 0.1)
                        : context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
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

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? context.adaptivePrimaryColor : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.textSecondaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? context.adaptivePrimaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              AppIcon(AppIcon.checkCircle, color: context.adaptivePrimaryColor),
          ],
        ),
      ),
    );
  }
}

class _ThemeColorOption extends StatelessWidget {
  final Color color;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeColorOption({
    required this.color,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child:
                  isSelected
                      ? const AppIcon(AppIcon.check, color: Colors.white, size: 32)
                      : null,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
