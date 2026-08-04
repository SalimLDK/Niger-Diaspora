import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../providers/profile_provider.dart';
import '../widgets/handle_field.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Longueur maximale de la bio (§20a : « 118/160 »). Le compteur et la
/// limite de saisie lisent la même constante — deux valeurs séparées
/// finiraient par diverger.
const int _kBioMaxLength = 160;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentCityController = TextEditingController();
  final _customProfessionController = TextEditingController();
  final _customCountryController = TextEditingController();
  final _customOriginCityController = TextEditingController();
  final _scrollController = ScrollController();

  // Poignée publique @handle (§16f) — gérée par le widget partagé HandleField.
  String? _handle;
  String? _initialHandle;
  bool _handleValid = true;

  bool _isLoading = false;
  bool _isVisible = true;
  String _phoneVisibility = ProfileOptions.phoneVisibilityEveryone;
  bool _isPhoneVerified = false;
  String? _photoUrl;
  bool _pendingPhotoDelete =
      false; // Flag pour indiquer que l'utilisateur veut supprimer sa photo
  String _completePhoneNumber = '';
  String _verifiedPhoneNumber = '';

  // Profession
  String? _selectedProfession;

  // Pays et ville actuelle
  CountryOption? _selectedCountry;

  // Origine au Niger
  String? _selectedOriginRegion;
  String? _selectedOriginCity;

  List<String> _selectedInterests = [];
  List<String> _selectedLanguages = [];

  late AnimationController _animationController;

  final Map<String, IconData> _interestsWithIcons = {
    'Affaires': Icons.business_center_outlined,
    'Technologie': Icons.computer_outlined,
    'Culture': Icons.theater_comedy_outlined,
    'Sport': Icons.sports_soccer_outlined,
    'Musique': Icons.music_note_outlined,
    'Art': Icons.palette_outlined,
    'Cuisine': Icons.restaurant_outlined,
    'Voyage': Icons.flight_outlined,
    'Education': Icons.school_outlined,
    'Sante': Icons.health_and_safety_outlined,
  };

  final Map<String, String> _languagesWithFlags = {
    'Francais': 'FR',
    'Anglais': 'EN',
    'Haoussa': 'HA',
    'Zarma': 'ZA',
    'Arabe': 'AR',
    'Fulfulde': 'FF',
    'Tamashek': 'TM',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadCurrentProfile();
    _animationController.forward();
  }

  void _loadCurrentProfile() {
    final authState = ref.read(authNotifierProvider);
    authState.maybeWhen(
      authenticated: (user) {
        // D'abord vérifier si le profil est déjà chargé (priorité aux données profil)
        final existingProfile =
            ref.read(profileNotifierProvider(user.id)).valueOrNull;
        if (existingProfile != null && existingProfile.id == user.id) {
          // Utiliser les données du profil existant (pas besoin de recharger)
          _displayNameController.text =
              existingProfile.displayName ?? user.displayName ?? '';
          _initialHandle = existingProfile.handle;
          _handle = existingProfile.handle;
          _bioController.text = existingProfile.bio ?? '';
          _completePhoneNumber = existingProfile.phoneNumber ?? '';
          _currentCityController.text = existingProfile.currentCity ?? '';
          _isVisible = existingProfile.isVisible;
          _phoneVisibility = existingProfile.phoneVisibility;
          _isPhoneVerified = existingProfile.isPhoneVerified;
          // Si le numéro est vérifié, stocker le numéro vérifié
          if (existingProfile.isPhoneVerified &&
              existingProfile.phoneNumber != null) {
            _verifiedPhoneNumber = existingProfile.phoneNumber!;
          }
          _selectedInterests = List.from(existingProfile.interests);
          _selectedLanguages = List.from(existingProfile.languages);
          // Ne pas écraser _photoUrl si l'utilisateur veut supprimer sa photo
          if (!_pendingPhotoDelete) {
            _photoUrl = existingProfile.photoUrl ?? user.photoUrl;
          }

          // Charger les sélections
          _loadProfessionFromProfile(existingProfile.profession);
          _loadCountryFromProfile(
            existingProfile.currentCountry,
            existingProfile.countryCode,
          );
          _loadOriginFromProfile(
            existingProfile.originRegion,
            existingProfile.originCity,
          );
        } else {
          // Fallback sur les données auth si pas de profil
          _displayNameController.text = user.displayName ?? '';
          // Ne pas écraser _photoUrl si l'utilisateur veut supprimer sa photo
          if (!_pendingPhotoDelete) {
            _photoUrl = user.photoUrl;
          }

          // Provider auto-loads, no explicit call needed here if watched/listened elsewhere
        }
      },
      orElse: () {},
    );
  }

  void _loadProfessionFromProfile(String? profession) {
    if (profession == null || profession.isEmpty) {
      _selectedProfession = null;
      return;
    }
    if (ProfileOptions.professions.contains(profession)) {
      _selectedProfession = profession;
    } else {
      _selectedProfession = 'Autre';
      _customProfessionController.text = profession;
    }
  }

  void _loadCountryFromProfile(String? country, String? code) {
    if (country == null || country.isEmpty) {
      _selectedCountry = null;
      return;
    }
    // D'abord chercher par code si disponible
    if (code != null && code.isNotEmpty) {
      final foundByCode = ProfileOptions.getCountryByCode(code);
      if (foundByCode != null) {
        _selectedCountry = foundByCode;
        return;
      }
    }
    // Sinon chercher par nom
    final foundByName = ProfileOptions.getCountryByName(country);
    if (foundByName != null) {
      _selectedCountry = foundByName;
    } else {
      _selectedCountry = null;
      _customCountryController.text = country;
    }
  }

  void _loadOriginFromProfile(String? region, String? city) {
    if (region != null && region.isNotEmpty) {
      if (ProfileOptions.regions.contains(region)) {
        _selectedOriginRegion = region;
      } else {
        _selectedOriginRegion = 'Autre';
      }
    }
    if (city != null && city.isNotEmpty) {
      final cities = ProfileOptions.getCitiesForRegion(
        _selectedOriginRegion ?? '',
      );
      if (cities.contains(city)) {
        _selectedOriginCity = city;
      } else {
        _selectedOriginCity = 'Autre';
        _customOriginCityController.text = city;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _currentCityController.dispose();
    _customProfessionController.dispose();
    _customCountryController.dispose();
    _customOriginCityController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerOptions() async {
    HapticFeedback.mediumImpact();
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
                const SheetHandle(),
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
                    Text(
                      AppLocalizations.of(context)!.changePhoto,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ImagePickerOption(
                  icon: Icons.camera_alt_outlined,
                  title: AppLocalizations.of(context)!.takePhotoTitle,
                  subtitle: AppLocalizations.of(context)!.takePhotoSubtitle,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _ImagePickerOption(
                  icon: Icons.photo_library_outlined,
                  title: AppLocalizations.of(context)!.galleryTitle,
                  subtitle: AppLocalizations.of(context)!.gallerySubtitle,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_photoUrl != null)
                  _ImagePickerOption(
                    icon: Icons.delete_outline,
                    title: AppLocalizations.of(context)!.deletePhotoTitle,
                    subtitle: AppLocalizations.of(context)!.deletePhotoSubtitle,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _photoUrl = null;
                        _pendingPhotoDelete = true;
                      });
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
      final authState = ref.read(authNotifierProvider);
      authState.maybeWhen(
        authenticated: (user) async {
          setState(() => _isLoading = true);
          final url = await ref
              .read(profileNotifierProvider(user.id).notifier)
              .uploadPhoto(image.path);
          if (url != null) {
            setState(() {
              _photoUrl = url;
              _pendingPhotoDelete =
                  false; // Réinitialiser le flag car nouvelle photo
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        },
        orElse: () {},
      );
    }
  }

  String _getFinalProfession() {
    if (_selectedProfession == 'Autre') {
      return _customProfessionController.text.trim();
    }
    return _selectedProfession ?? '';
  }

  String _getFinalCountry() {
    if (_selectedCountry == null && _customCountryController.text.isNotEmpty) {
      return _customCountryController.text.trim();
    }
    return _selectedCountry?.name ?? '';
  }

  String? _getFinalCountryCode() {
    return _selectedCountry?.code;
  }

  String _getFinalOriginCity() {
    if (_selectedOriginCity == 'Autre') {
      return _customOriginCityController.text.trim();
    }
    return _selectedOriginCity ?? '';
  }

  void _onPhoneNumberChanged(String completeNumber) {
    setState(() {
      _completePhoneNumber = completeNumber;
      // Réinitialiser la vérification si le numéro change
      if (_verifiedPhoneNumber.isNotEmpty &&
          completeNumber != _verifiedPhoneNumber) {
        _isPhoneVerified = false;
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    // Bloque la sauvegarde si la poignée saisie est invalide ou déjà prise.
    if (!_handleValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez une poignée valide et disponible'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final authState = ref.read(authNotifierProvider);
    await authState.maybeWhen(
      authenticated: (user) async {
        final profile = ProfileEntity(
          id: user.id,
          email: user.email,
          displayName: _displayNameController.text.trim(),
          handle: _handle,
          photoUrl: _photoUrl,
          phoneNumber: _completePhoneNumber.trim(),
          bio: _bioController.text.trim(),
          profession: _getFinalProfession(),
          currentCity: _currentCityController.text.trim(),
          currentCountry: _getFinalCountry(),
          countryCode: _getFinalCountryCode(),
          originRegion:
              _selectedOriginRegion == 'Autre' ? null : _selectedOriginRegion,
          originCity: _getFinalOriginCity(),
          isVisible: _isVisible,
          phoneVisibility: _phoneVisibility,
          isPhoneVerified: _isPhoneVerified,
          interests: _selectedInterests,
          languages: _selectedLanguages,
        );

        await ref
            .read(profileNotifierProvider(user.id).notifier)
            .updateProfile(profile);

        // Vérifier que l'écriture a réussi (sinon on affichait un faux succès
        // alors que rien n'était sauvegardé).
        final saved = ref.read(profileNotifierProvider(user.id));
        if (saved.hasError) {
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.profileUpdateError(saved.error?.toString() ?? ''),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Réinitialiser le flag après sauvegarde réussie
        _pendingPhotoDelete = false;

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const AppIcon(AppIcon.checkCircle, color: AppColors.white),
                  const SizedBox(width: 12),
                  Text(l10n.profileUpdatedSuccess),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.pop();
        }
      },
      orElse: () {},
    );

    setState(() => _isLoading = false);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    // Obtenir le user auth pour fallback du displayName
    final authUser = ref
        .read(authNotifierProvider)
        .maybeWhen(authenticated: (user) => user, orElse: () => null);

    if (authUser != null) {
      ref.listen(profileNotifierProvider(authUser.id), (previous, next) {
        next.whenData((profile) {
          if (profile != null) {
            // Priorité au displayName du profil, sinon utiliser celui de l'auth
            _displayNameController.text =
                profile.displayName ?? authUser.displayName ?? '';
            _bioController.text = profile.bio ?? '';
            _completePhoneNumber = profile.phoneNumber ?? '';
            _currentCityController.text = profile.currentCity ?? '';

            // Charger les sélections
            _loadProfessionFromProfile(profile.profession);
            _loadCountryFromProfile(
              profile.currentCountry,
              profile.countryCode,
            );
            _loadOriginFromProfile(profile.originRegion, profile.originCity);

            setState(() {
              _isVisible = profile.isVisible;
              _phoneVisibility = profile.phoneVisibility;
              _isPhoneVerified = profile.isPhoneVerified;
              // Si le numéro est vérifié, stocker le numéro vérifié
              if (profile.isPhoneVerified && profile.phoneNumber != null) {
                _verifiedPhoneNumber = profile.phoneNumber!;
              }
              _selectedInterests = List.from(profile.interests);
              _selectedLanguages = List.from(profile.languages);
              // Ne pas écraser _photoUrl si l'utilisateur veut supprimer sa photo
              if (!_pendingPhotoDelete) {
                _photoUrl = profile.photoUrl ?? authUser.photoUrl;
              }
            });
          }
        });
      });
    }

    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header avec photo de profil
              SliverAppBar(
                // §20a : la barre n'a plus de hero. L'avatar est descendu
                // dans le contenu, en ligne — l'écran commence donc sur un
                // champ et non sur un tiers de page décoratif.
                pinned: true,
                title: Text(
                  AppLocalizations.of(context)!.editProfileTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                // Repliée, cette barre virait au terracotta plein sur toute
                // la largeur — le seul écran de l'app à faire ça, et le
                // jeton était figé sur la palette claire. Elle suit
                // désormais le fond de la page, comme partout ailleurs.
                backgroundColor: context.backgroundColor,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppIcon(AppIcon.close, color: Colors.white),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.visibility_outlined,
                      color: context.textPrimaryColor,
                    ),
                    tooltip: AppLocalizations.of(context)!.previewTooltip,
                    onPressed: () {
                      final authState = ref.read(authNotifierProvider);
                      authState.maybeWhen(
                        authenticated: (user) =>
                            context.push('/profile/${user.id}'),
                        orElse: () {},
                      );
                    },
                  ),
                  // §20a : « Enregistrer » est un lien texte, pas une pilule
                  // pleine. La pilule mangeait la largeur et tronquait le
                  // titre en « Modifier le p… ».
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    context.adaptivePrimaryColor,
                                  ),
                                ),
                              )
                              : Text(
                                l10n.save,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: context.adaptivePrimaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildHeader()),

              // Contenu du formulaire
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Section Informations de base
                    _buildAnimatedSection(
                      delay: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: l10n.basicInfo,
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _FormCard(
                            children: [
                              CustomTextField(
                                controller: _displayNameController,
                                label: l10n.fullName,
                                prefixIcon: Icons.badge_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.enterYourName;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Poignée publique @handle (§16f)
                              HandleField(
                                initialHandle: _initialHandle,
                                userId: ref
                                    .read(authNotifierProvider)
                                    .maybeWhen(
                                      authenticated: (user) => user.id,
                                      orElse: () => null,
                                    ),
                                onChanged: (normalized, isValid) {
                                  _handle = normalized;
                                  _handleValid = isValid;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Dropdown Profession
                              _buildDropdownField(
                                label: l10n.profession,
                                icon: Icons.work_outline,
                                value: _selectedProfession,
                                items: ProfileOptions.professions,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedProfession = value;
                                    if (value != 'Autre') {
                                      _customProfessionController.clear();
                                    }
                                  });
                                },
                              ),
                              if (_selectedProfession == 'Autre') ...[
                                const SizedBox(height: 12),
                                CustomTextField(
                                  controller: _customProfessionController,
                                  label: l10n.specifyYourProfession,
                                  prefixIcon: Icons.edit_outlined,
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Numéro de téléphone avec vérification
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: IntlPhoneField(
                                      decoration: InputDecoration(
                                        labelText: l10n.phone,
                                        labelStyle: TextStyle(
                                          color: context.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: context.surfaceVariantColor,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: context.borderColor,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: context.adaptivePrimaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                      // Si un numéro E.164 est déjà stocké
                                      // (+1…, +33…, etc.), on laisse le package
                                      // détecter le pays depuis le préfixe au
                                      // lieu de forcer 'NE' (sinon un numéro
                                      // hors Niger devient invalide et bloque
                                      // l'enregistrement).
                                      initialCountryCode:
                                          _completePhoneNumber.trim().startsWith(
                                            '+',
                                          )
                                          ? null
                                          : 'NE',
                                      initialValue: _completePhoneNumber,
                                      onChanged: (phone) {
                                        _onPhoneNumberChanged(
                                          phone.completeNumber,
                                        );
                                      },
                                      invalidNumberMessage:
                                          l10n.adminInvalidNumberError,
                                      // Téléphone optionnel : un champ vide ne
                                      // doit jamais empêcher l'enregistrement.
                                      disableLengthCheck: true,
                                      validator: (phone) {
                                        final n = phone?.number.trim() ?? '';
                                        if (n.isEmpty) return null;
                                        if (n.length < 4) {
                                          return l10n.adminInvalidNumberError;
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Bouton de vérification OTP
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _buildVerifyButton(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Sélecteur de visibilité du numéro
                              _buildPhoneVisibilitySelector(),
                              const SizedBox(height: 16),
                              // Compteur de bio (§20a). Il est posé au-dessus
                              // du champ plutôt que dans sa décoration : le
                              // compteur natif de Flutter s'affiche sous le
                              // champ, où il se confond avec un texte d'aide.
                              // `counterText: ''` le neutralise.
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _bioController,
                                builder: (context, value, _) {
                                  final n = value.text.characters.length;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '$n/$_kBioMaxLength',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: n >= _kBioMaxLength
                                              ? context.errorColor
                                              : context.textTertiaryColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              CustomTextField(
                                controller: _bioController,
                                label: l10n.bio,
                                prefixIcon: Icons.notes_outlined,
                                maxLines: 3,
                                maxLength: _kBioMaxLength,
                                counterText: '',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Localisation
                    _buildAnimatedSection(
                      delay: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: l10n.location,
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 16),
                          _FormCard(
                            children: [
                              // Dropdown Pays avec drapeaux
                              _buildCountryDropdown(
                                label: l10n.country,
                                icon: Icons.public_outlined,
                                value: _selectedCountry,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCountry = value;
                                    _customCountryController.clear();
                                  });
                                },
                              ),
                              // Option pour saisir un pays non listé
                              if (_selectedCountry == null) ...[
                                const SizedBox(height: 12),
                                CustomTextField(
                                  controller: _customCountryController,
                                  label: l10n.profileSpecifyCountry,
                                  prefixIcon: Icons.edit_outlined,
                                ),
                              ],
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _currentCityController,
                                label: l10n.currentCity,
                                prefixIcon: Icons.location_city_outlined,
                              ),
                              const SizedBox(height: 20),
                              // Origine au Niger
                              Text(
                                l10n.originAtNiger,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Dropdown Region
                              _buildDropdownField(
                                label: l10n.profileRegion,
                                icon: Icons.map_outlined,
                                value: _selectedOriginRegion,
                                items: ProfileOptions.regions,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedOriginRegion = value;
                                    _selectedOriginCity = null;
                                    _customOriginCityController.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              // Dropdown Ville d'origine
                              if (_selectedOriginRegion != null &&
                                  _selectedOriginRegion != 'Autre')
                                _buildDropdownField(
                                  label: l10n.profileOriginCity,
                                  icon: Icons.home_outlined,
                                  value: _selectedOriginCity,
                                  items: ProfileOptions.getCitiesForRegion(
                                    _selectedOriginRegion!,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedOriginCity = value;
                                      if (value != 'Autre') {
                                        _customOriginCityController.clear();
                                      }
                                    });
                                  },
                                ),
                              if (_selectedOriginRegion == 'Autre' ||
                                  _selectedOriginCity == 'Autre') ...[
                                const SizedBox(height: 12),
                                CustomTextField(
                                  controller: _customOriginCityController,
                                  label: l10n.profileSpecifyOriginCity,
                                  prefixIcon: Icons.edit_outlined,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Centres d'intérêt
                    _buildAnimatedSection(
                      delay: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: l10n.interests,
                            icon: Icons.interests_outlined,
                            subtitle:
                                AppLocalizations.of(context)!.selectedCount(_selectedInterests.length),
                          ),
                          const SizedBox(height: 16),
                          _FormCard(
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _interestsWithIcons.entries.map((entry) {
                                      final isSelected = _selectedInterests
                                          .contains(entry.key);
                                      return _SelectableChip(
                                        label: entry.key,
                                        icon: entry.value,
                                        isSelected: isSelected,
                                        color: AppColors.primary,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            if (isSelected) {
                                              _selectedInterests.remove(
                                                entry.key,
                                              );
                                            } else {
                                              _selectedInterests.add(entry.key);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Langues
                    _buildAnimatedSection(
                      delay: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: l10n.spokenLanguages,
                            icon: Icons.translate_outlined,
                            subtitle:
                                AppLocalizations.of(context)!.selectedCount(_selectedLanguages.length),
                          ),
                          const SizedBox(height: 16),
                          _FormCard(
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _languagesWithFlags.entries.map((entry) {
                                      final isSelected = _selectedLanguages
                                          .contains(entry.key);
                                      return _LanguageChip(
                                        language: entry.key,
                                        code: entry.value,
                                        isSelected: isSelected,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            if (isSelected) {
                                              _selectedLanguages.remove(
                                                entry.key,
                                              );
                                            } else {
                                              _selectedLanguages.add(entry.key);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Confidentialité
                    _buildAnimatedSection(
                      delay: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: l10n.privacy,
                            icon: Icons.shield_outlined,
                          ),
                          const SizedBox(height: 16),
                          _FormCard(
                            children: [
                              _PrivacyToggle(
                                icon:
                                    _isVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                title: l10n.visibleProfile,
                                subtitle: l10n.otherMembersCanSee,
                                value: _isVisible,
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isVisible = value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bouton de sauvegarde
                    _buildAnimatedSection(
                      delay: 5,
                      child: CustomButton(
                        onPressed: _saveProfile,
                        label: l10n.saveChanges,
                        isLoading: _isLoading,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Identité en ligne (§20a) : avatar à gauche, invitation à changer la
  /// photo à côté. La maquette a supprimé le hero de 240 px, ses cercles
  /// décoratifs et le bandeau terracotta — l'écran est désormais plat, et
  /// l'avatar ne prend plus le tiers de la page avant le premier champ.
  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showImagePickerOptions,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor,
                    borderRadius: BorderRadius.circular(20),
                    image: _photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _photoUrl == null
                      ? Text(
                          _getInitials(_displayNameController.text),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: context.onPrimaryColor,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.backgroundColor,
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: context.onPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _showImagePickerOptions,
              child: Text(
                l10n.changePhotoAction,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (delay * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.textTertiaryColor),
          prefixIcon: Icon(icon, color: context.textTertiaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        dropdownColor: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: context.textTertiaryColor,
        ),
        isExpanded: true,
        items:
            items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color:
                        item == 'Autre'
                            ? context.adaptivePrimaryColor
                            : context.textPrimaryColor,
                    fontWeight:
                        item == 'Autre' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVerifyButton() {
    final bool hasPhone = _completePhoneNumber.trim().isNotEmpty;
    // Vérifier que le numéro actuel correspond au numéro vérifié
    final bool isCurrentNumberVerified =
        _isPhoneVerified &&
        _verifiedPhoneNumber.isNotEmpty &&
        _completePhoneNumber == _verifiedPhoneNumber;

    if (isCurrentNumberVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.successColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, color: context.successColor, size: 20),
            const SizedBox(width: 6),
            Text(
              'Verifie',
              style: TextStyle(
                color: context.successColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: hasPhone ? _showOtpVerificationDialog : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color:
              hasPhone
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                  : context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                hasPhone
                    ? context.adaptivePrimaryColor.withValues(alpha: 0.3)
                    : context.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: hasPhone ? AppColors.primary : context.textTertiaryColor,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.verify,
              style: TextStyle(
                color:
                    hasPhone
                        ? context.adaptivePrimaryColor
                        : context.textTertiaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtpVerificationDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder:
          (context) => _OtpVerificationDialog(
            phoneNumber: _completePhoneNumber,
            onVerified: () {
              setState(() {
                _isPhoneVerified = true;
                _verifiedPhoneNumber = _completePhoneNumber;
              });
              Navigator.pop(context);
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const AppIcon(AppIcon.checkCircle, color: AppColors.white),
                      const SizedBox(width: 12),
                      Text(l10n.profilePhoneVerified),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildPhoneVisibilitySelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.whoCanSeeMyNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children:
                ProfileOptions.phoneVisibilityOptions.entries.map((entry) {
                  final isSelected = _phoneVisibility == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _phoneVisibility = entry.key);
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          right:
                              entry.key != ProfileOptions.phoneVisibilityNone
                                  ? 8
                                  : 0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? context.adaptivePrimaryColor.withValues(
                                    alpha: 0.15,
                                  )
                                  : context.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isSelected
                                    ? context.adaptivePrimaryColor
                                    : context.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIcon(
                              entry.key ==
                                      ProfileOptions.phoneVisibilityEveryone
                                  ? AppIcon.public
                                  : entry.key ==
                                      ProfileOptions.phoneVisibilityFriends
                                  ? AppIcon.people
                                  : AppIcon.lock,
                              size: 20,
                              color:
                                  isSelected
                                      ? context.adaptivePrimaryColor
                                      : context.textTertiaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                color:
                                    isSelected
                                        ? context.adaptivePrimaryColor
                                        : context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown({
    required String label,
    required IconData icon,
    required CountryOption? value,
    required ValueChanged<CountryOption?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonFormField<CountryOption>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.textTertiaryColor),
          prefixIcon:
              value != null
                  ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Text(
                      value.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                  )
                  : Icon(icon, color: context.textTertiaryColor, size: 22),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        dropdownColor: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: context.textTertiaryColor,
        ),
        isExpanded: true,
        menuMaxHeight: 300,
        // Affiche uniquement le nom du pays (sans drapeau) quand selectionne
        // car le prefixIcon affiche deja le drapeau
        selectedItemBuilder: (BuildContext context) {
          return ProfileOptions.countries.map((country) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                country.name,
                style: TextStyle(color: this.context.textPrimaryColor),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
        items:
            ProfileOptions.countries.map((country) {
              return DropdownMenuItem<CountryOption>(
                value: country,
                child: Row(
                  children: [
                    Text(country.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        country.name,
                        style: TextStyle(color: context.textPrimaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// Widgets réutilisables

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: context.adaptivePrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withValues(alpha: 0.15)
                  : context.surfaceVariantColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : context.textTertiaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : context.textSecondaryColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              AppIcon(AppIcon.checkCircle, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String language;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.language,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = context.adaptiveSecondaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? secondaryColor.withValues(alpha: 0.15)
                  : context.surfaceVariantColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? secondaryColor : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? secondaryColor : context.textTertiaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              language,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? secondaryColor : context.textSecondaryColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              AppIcon(AppIcon.checkCircle, size: 16, color: secondaryColor),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.adaptivePrimaryColor;
    final tertiaryColor = context.textTertiaryColor;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (value ? primaryColor : tertiaryColor).withValues(alpha: 0.15),
                (value ? primaryColor : tertiaryColor).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: value ? primaryColor : tertiaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: primaryColor,
          activeTrackColor: primaryColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
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
    final color =
        isDestructive ? AppColors.error : context.adaptivePrimaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? AppColors.error : context.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: color.withValues(alpha: 0.5),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        ),
      ),
    );
  }
}

class _OtpVerificationDialog extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onVerified;

  const _OtpVerificationDialog({
    required this.phoneNumber,
    required this.onVerified,
  });

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<_OtpVerificationDialog> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _codeSent = false;
  int _resendTimer = 0;
  String? _verificationId;
  String? _errorMessage;
  int? _resendToken;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-vérification (Android uniquement)
          if (mounted) {
            widget.onVerified();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = _getErrorMessage(e.code);
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _codeSent = true;
              _isLoading = false;
              _resendTimer = 60;
            });
            _startResendTimer();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.codeSentTo(widget.phoneNumber)),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.phoneVerifSendError;
        });
      }
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.phoneVerifEnterComplete;
      });
      return;
    }

    if (_verificationId == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.phoneVerifResendRequired;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.phoneVerifUserNotLoggedIn;
        });
        return;
      }

      try {
        await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // Ces codes signifient que l'OTP était valide → vérifié quand même
        if (e.code != 'credential-already-in-use' &&
            e.code != 'account-exists-with-different-credential' &&
            e.code != 'provider-already-linked') {
          rethrow;
        }
      }

      if (mounted) {
        widget.onVerified();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final l10n = AppLocalizations.of(context)!;
          _errorMessage =
              e.code == 'invalid-verification-code'
                  ? l10n.phoneVerifInvalidCode
                  : l10n.phoneVerifError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.phoneVerifError;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'invalid-phone-number':
        return l10n.phoneVerifInvalidNumber;
      case 'too-many-requests':
        return l10n.phoneVerifTooManyAttempts;
      case 'quota-exceeded':
        return l10n.phoneVerifQuotaExceeded;
      case 'network-request-failed':
        return l10n.phoneVerifNetworkError;
      default:
        return l10n.phoneVerifSendError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.adaptivePrimaryColor;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_android, size: 32, color: primaryColor),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.phoneVerifTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? l10n.phoneVerifEnterCodeHint(widget.phoneNumber)
                    : l10n.phoneVerifSendCodeHint(widget.phoneNumber),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Afficher les erreurs
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(AppIcon.error,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!_codeSent) ...[
                // Bouton envoyer le code
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.white,
                                ),
                              ),
                            )
                            : Text(
                              l10n.sendCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ] else ...[
                // Champs OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: context.surfaceVariantColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (index == 5 && value.isNotEmpty) {
                            _verifyOtp();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Bouton verifier
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.white,
                                ),
                              ),
                            )
                            : Text(
                              l10n.verify,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 12),

                // Renvoyer le code
                TextButton(
                  onPressed: _resendTimer > 0 ? null : _sendOtp,
                  child: Text(
                    _resendTimer > 0
                        ? l10n.resendCodeIn(_resendTimer)
                        : l10n.resendCode,
                    style: TextStyle(
                      color:
                          _resendTimer > 0
                              ? context.textTertiaryColor
                              : primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(color: context.textSecondaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
