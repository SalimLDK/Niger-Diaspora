import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../../../../core/models/country.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/analytics_service.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  /// Nom pré-rempli, venant du « Créer « X » » de la recherche sans résultat.
  final String? initialName;

  const CreateGroupScreen({super.key, this.initialName});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagsController = TextEditingController();

  GroupCategory _selectedCategory = GroupCategory.other;
  String? _selectedCountry;
  String? _selectedOriginRegion;
  bool _isPrivate = false;
  bool _isLoading = false;
  File? _selectedImage;

  // Liste des pays d'accueil courants pour la diaspora nigérienne
  static const List<String> _hostCountries = [
    'Niger',
    'France',
    'États-Unis',
    'Canada',
    'Belgique',
    'Allemagne',
    'Royaume-Uni',
    'Italie',
    'Espagne',
    'Suisse',
    'Côte d\'Ivoire',
    'Sénégal',
    'Maroc',
    'Autre',
  ];

  // Régions du Niger
  static const List<String> _nigerRegions = [
    'Niamey',
    'Agadez',
    'Diffa',
    'Dosso',
    'Maradi',
    'Tahoua',
    'Tillabéri',
    'Zinder',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _nameController.text = widget.initialName!.trim();
    }
    // Pré-remplir le pays d'accueil depuis le profil utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultCountryFromProfile();
    });
  }

  void _loadDefaultCountryFromProfile() {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final profileAsync = ref.read(profileNotifierProvider(currentUser.id));
    profileAsync.whenData((profile) {
      if (profile?.currentCountry != null &&
          profile!.currentCountry!.isNotEmpty) {
        // Vérifier si le pays du profil est dans notre liste
        final userCountry = profile.currentCountry!;
        if (_hostCountries.contains(userCountry)) {
          setState(() => _selectedCountry = userCountry);
        } else {
          // Si le pays n'est pas dans la liste, utiliser Niger par défaut
          setState(() => _selectedCountry = 'Niger');
        }
      } else {
        // Si pas de pays dans le profil, utiliser Niger par défaut
        setState(() => _selectedCountry = 'Niger');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final imageService = ImageUploadService();
    final image = await imageService.pickImageFromGallery();
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // `currentUserAsyncProvider` est un StreamProvider **autoDispose** que cet
    // écran ne regarde jamais : un `ref.read(...).valueOrNull` démarrait
    // l'abonnement à l'instant du tap et rendait `AsyncLoading`, donc `null`.
    // La méthode sortait alors sur un `return` nu — bouton mort, sans spinner,
    // sans message et sans trace dans logcat. On attend la première émission.
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (!mounted) return;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      ToastUtils.showError(
        context,
        'Session expirée — reconnectez-vous pour créer un groupe.',
      );
      return;
    }

    // Upload image if selected
    String? imageUrl;
    if (_selectedImage != null) {
      final imageService = ImageUploadService();
      // Use a temporary ID for upload, will be replaced with actual group ID
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      imageUrl = await imageService.uploadImage(
        file: _selectedImage!,
        type: ImageUploadType.group,
        id: tempId,
      );
    }

    final tags =
        _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    final group = GroupEntity(
      id: '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      creatorId: currentUser.id,
      creatorName: currentUser.displayName,
      category: _selectedCategory,
      isPrivate: _isPrivate,
      imageUrl: imageUrl,
      location:
          _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
      tags: tags,
      adminIds: [currentUser.id],
      memberIds: [currentUser.id],
      createdAt: DateTime.now(),
      // `_hostCountries` est une liste de LIBELLÉS français ('Niger',
      // 'Canada', …) et cette valeur part telle quelle dans
      // `groups.country_code`, qui attend un code ISO-2. D'où le mélange
      // `CA`/`Canada`, `NE`/`Niger` constaté en base, et un filtre par pays qui
      // ne retenait qu'une partie des groupes. On normalise ici — l'affichage
      // continue de montrer les libellés.
      country:
          CountryExtension.toIsoCode(_selectedCountry) ?? _selectedCountry,
      originRegion: _selectedOriginRegion,
    );

    final success = await ref
        .read(myGroupsNotifierProvider.notifier)
        .createGroup(group);

    if (success) {
      AnalyticsService.instance.logEvent(
        name: 'create_group',
        parameters: {
          'category': _selectedCategory.name,
          'is_private': _isPrivate,
          'has_image': _selectedImage != null,
          'has_country': _selectedCountry != null,
          'has_origin_region': _selectedOriginRegion != null,
        },
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ToastUtils.showSuccess(context, l10n.groupCreated);
      context.pop();
    } else {
      // La raison remonte du dépôt : « Erreur lors de la création » tout court
      // n'apprenait rien, ni à l'utilisateur ni au diagnostic.
      final reason = ref.read(myGroupsNotifierProvider.notifier).lastError;
      ToastUtils.showError(
        context,
        reason == null || reason.isEmpty
            ? l10n.groupCreationError
            : 'Création impossible : $reason',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.groupCreateTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Photo de groupe
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.borderColor, width: 2),
                  ),
                  child:
                      _selectedImage != null
                          ? ClipOval(
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: context.textTertiaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.addPhoto,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nom du groupe
            _buildLabel('Nom du groupe *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(l10n.groupNameExample),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.groupNameIsRequired;
                }
                if (value.trim().length < 3) {
                  return l10n.groupNameMinLength;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Description
            _buildLabel(l10n.businessDescriptionLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(l10n.describeYourGroup),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.descriptionRequired;
                }
                if (value.trim().length < 10) {
                  return l10n.descriptionMinLength;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Catégorie
            _buildLabel(l10n.category),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<GroupCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items:
                      GroupCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Pays d'accueil
            _buildLabel('Pays d\'accueil (optionnel)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountry,
                  isExpanded: true,
                  hint: Text(
                    l10n.selectCountry,
                    style: TextStyle(color: context.textTertiaryColor),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        l10n.none,
                        style: TextStyle(color: context.textTertiaryColor),
                      ),
                    ),
                    ..._hostCountries.map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCountry = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.groupCountryHint,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),

            const SizedBox(height: 20),

            // Région d'origine
            _buildLabel('Région d\'origine au Niger (optionnel)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedOriginRegion,
                  isExpanded: true,
                  hint: Text(
                    l10n.selectRegion,
                    style: TextStyle(color: context.textTertiaryColor),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        l10n.audioRoomCollectionTypeNone,
                        style: TextStyle(color: context.textTertiaryColor),
                      ),
                    ),
                    ..._nigerRegions.map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedOriginRegion = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pour regrouper les membres par région d\'origine',
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),

            const SizedBox(height: 20),

            // Localisation
            _buildLabel(l10n.detailedLocation),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: _inputDecoration(l10n.detailedLocationExample),
            ),

            const SizedBox(height: 20),

            // Tags
            _buildLabel(l10n.audioRoomTagsOptional),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsController,
              decoration: _inputDecoration(l10n.tagsExample),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tagsHint,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),

            const SizedBox(height: 20),

            // Groupe privé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.privateGroup,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.membersNeedApproval,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value),
                    activeThumbColor: context.adaptivePrimaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Bouton créer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.adaptivePrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          l10n.createTheGroup,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.textPrimaryColor,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textTertiaryColor),
      filled: true,
      fillColor: context.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.adaptivePrimaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
