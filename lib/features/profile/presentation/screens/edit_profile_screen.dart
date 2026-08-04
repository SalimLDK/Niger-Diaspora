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

  /// §20a : les deux listes de puces sont repliées par défaut. Elles
  /// affichaient l'intégralité du catalogue en permanence — une trentaine de
  /// puces qui repoussaient la moitié du formulaire hors de l'écran. Repliées,
  /// on ne voit que ses propres choix, plus une puce « +N » pour ouvrir.
  /// Un numéro vérifié s'affiche masqué (§20a). Ce drapeau rouvre le
  /// champ quand la personne demande explicitement à le changer :
  /// rouvrir tout seul exposerait le numéro à chaque ouverture.
  bool _editingPhone = false;

  /// L'origine au Niger tient en une ligne repliée (§20a) : deux listes
  /// déroulantes empilées pour un champ optionnel, c'était trois fois la
  /// hauteur de ce qu'il vaut. Elle s'ouvre déjà dépliée si elle est
  /// renseignée, pour qu'on voie qu'il y a quelque chose à corriger.
  bool _showOrigin = false;

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
          _phoneVisibility = _normaliserVisibilite(
            existingProfile.phoneVisibility,
          );
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
        _showOrigin = true;
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

  /// Ce qu'on montre d'une liste de puces : tout si elle est dépliée, sinon
  /// les seuls choix déjà faits. Repliée et vide, elle ne laisse que la puce
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
              _phoneVisibility = _normaliserVisibilite(profile.phoneVisibility);
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
                // §20a : simple ✕ dans la couleur du texte. Il restait de
                // l'époque où la barre était un hero terracotta : pastille
                // blanche à 20 % et glyphe blanc, donc **invisible** une fois
                // la barre passée au fond crème de la page.
                leading: IconButton(
                  icon: AppIcon(
                    AppIcon.close,
                    size: 24,
                    color: context.textPrimaryColor,
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
                    // §20a : formulaire à plat, dans l'ordre de la fiche.
                    // Plus d'en-tête de section ni d'icône de préfixe : un
                    // libellé, un champ. Les champs que la fiche ne montre
                    // pas (pays, ville actuelle, visibilité du profil) sont
                    // conservés à la suite — les retirer supprimerait des
                    // données, pas de la décoration.
                    _buildAnimatedSection(
                      delay: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            controller: _displayNameController,
                            label: l10n.fullName,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.enterYourName;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Poignée publique @handle (§16f). Absente de la
                          // maquette, mais c'est elle qui alimente la ligne
                          // d'identité de « Mon espace » (5a).
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
                          // Compteur de bio sur la ligne du libellé : posé
                          // au-dessus du champ il flottait sans attache, et
                          // le compteur natif de Flutter s'affiche sous le
                          // champ où il se confond avec un texte d'aide
                          // (`counterText: ''` l'éteint).
                          CustomTextField(
                            controller: _bioController,
                            label: l10n.bio,
                            maxLines: 3,
                            maxLength: _kBioMaxLength,
                            counterText: '',
                            labelTrailing:
                                ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _bioController,
                              builder: (context, value, _) {
                                final n = value.text.characters.length;
                                return Text(
                                  '$n/$_kBioMaxLength',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: n >= _kBioMaxLength
                                        ? context.errorColor
                                        : context.textTertiaryColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: l10n.profession,
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
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _customProfessionController,
                              label: l10n.specifyYourProfession,
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Langues parlées
                          _FieldLabel(l10n.spokenLanguages),
                          _ChipsField(
                            options: _languagesWithFlags,
                            selection: _selectedLanguages,
                            restantLabel: l10n.plusMoreLanguages,
                            videLabel: l10n.spokenLanguagesEmptyAction,
                            onOuvrir: _choisirLangues,
                            onRetirer: (cle) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedLanguages.remove(cle));
                            },
                          ),
                          const SizedBox(height: 24),

                          // Centres d'intérêt
                          _FieldLabel(l10n.interests),
                          _ChipsField(
                            options: {
                              for (final cle in _interestsWithIcons.keys)
                                cle: null,
                            },
                            selection: _selectedInterests,
                            restantLabel: l10n.plusMoreCount,
                            videLabel: l10n.interestsEmptyAction,
                            onOuvrir: _choisirInterets,
                            onRetirer: (cle) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedInterests.remove(cle));
                            },
                          ),
                          const SizedBox(height: 24),

                          // Localisation — hors maquette, conservée.
                          _buildCountryDropdown(
                            label: l10n.country,
                            value: _selectedCountry,
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                                _customCountryController.clear();
                              });
                            },
                          ),
                          if (_selectedCountry == null) ...[
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _customCountryController,
                              label: l10n.profileSpecifyCountry,
                            ),
                          ],
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _currentCityController,
                            label: l10n.currentCity,
                          ),
                          const SizedBox(height: 16),

                          // Origine au Niger : ligne de résumé repliable.
                          _buildOriginRow(l10n),
                          if (_showOrigin) ...[
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              label: l10n.profileRegion,
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
                            if (_selectedOriginRegion != null &&
                                _selectedOriginRegion != 'Autre') ...[
                              const SizedBox(height: 12),
                              _buildDropdownField(
                                label: l10n.profileOriginCity,
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
                            ],
                            if (_selectedOriginRegion == 'Autre' ||
                                _selectedOriginCity == 'Autre') ...[
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _customOriginCityController,
                                label: l10n.profileSpecifyOriginCity,
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),

                          // Bloc téléphone : numéro (vérifié ou non) puis
                          // visibilité, dans une seule carte comme la fiche.
                          _buildPhoneBlock(l10n),
                          const SizedBox(height: 24),

                          _PrivacyToggle(
                            icon: _isVisible
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
                          const SizedBox(height: 32),
                          CustomButton(
                            onPressed: _saveProfile,
                            label: l10n.saveChanges,
                            isLoading: _isLoading,
                          ),
                        ],
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
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor,
                    borderRadius: BorderRadius.circular(22),
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
                // §20a : pastille neutre cerclée du fond de page, pas un
                // second aplat d'accent collé à l'avatar — la maquette veut
                // que l'accent reste sur « Modifier la photo ».
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.backgroundColor,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 15,
                      color: context.textSecondaryColor,
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

  /// §20a : le libellé est porté au-dessus du champ, comme pour les champs
  /// texte, et non en étiquette flottante dans le contour — la maquette
  /// aligne tous les libellés du formulaire sur la même colonne.
  Widget _buildDropdownField({
    required String label,
    IconData? icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        _buildDropdownBox(icon: icon, value: value, items: items, onChanged: onChanged),
      ],
    );
  }

  Widget _buildDropdownBox({
    required IconData? icon,
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
          prefixIcon:
              icon == null
                  ? null
                  : Icon(icon, color: context.textTertiaryColor, size: 22),
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

  /// « Origine au Niger » en une ligne : ce qui est choisi, ou un texte gris
  /// s'il n'y a rien. L'appui déplie les deux listes en place — pas de
  /// feuille modale pour un champ optionnel.
  Widget _buildOriginRow(AppLocalizations l10n) {
    final parties = <String>[
      if ((_selectedOriginRegion ?? '').isNotEmpty &&
          _selectedOriginRegion != 'Autre')
        _selectedOriginRegion!,
      if ((_selectedOriginCity ?? '').isNotEmpty &&
          _selectedOriginCity != 'Autre')
        _selectedOriginCity!,
    ];
    final rempli = parties.isNotEmpty;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _showOrigin = !_showOrigin),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.surfaceVariantColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.home_outlined,
                size: 18,
                color: context.textSecondaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.originAtNiger,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  rempli
                      ? parties.join(' \u00b7 ')
                      : l10n.originSummaryPlaceholder,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: rempli
                        ? context.textSecondaryColor
                        : context.textTertiaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showOrigin ? Icons.expand_less : Icons.chevron_right,
                size: 20,
                color: context.textTertiaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Masque un numéro : indicatif et premiers chiffres visibles, milieu
  /// caché, deux derniers visibles — « +33 6 12 •• •• 47 ». Assez pour
  /// reconnaître son propre numéro, pas pour qu'un regard le retienne.
  String _masquerNumero(String brut) {
    final t = brut.trim();
    if (t.length < 8) return t;
    final debut = t.substring(0, 6);
    final fin = t.substring(t.length - 2);
    final restant = t.length - debut.length - fin.length;
    final groupes = (restant / 2).round().clamp(1, 4);
    return '$debut ${List.filled(groupes, '\u2022\u2022').join(' ')} $fin';
  }

  /// Carte du numéro vérifié : numéro masqué, état, et « Modifier ».
  /// Bloc téléphone de la fiche 20a : le numéro (carte en lecture seule s'il
  /// est vérifié, champ de saisie + bouton de vérification sinon), puis la
  /// ligne « Qui peut voir mon numéro ? ».
  Widget _buildPhoneBlock(AppLocalizations l10n) {
    OutlineInputBorder bordure(Color couleur, double epaisseur) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: couleur, width: epaisseur),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isPhoneVerified && !_editingPhone)
          _buildVerifiedPhoneCard()
        else ...[
          _FieldLabel(l10n.phone),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IntlPhoneField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.surfaceVariantColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: bordure(context.borderColor, 1),
                    focusedBorder: bordure(context.adaptivePrimaryColor, 2),
                    errorBorder: bordure(AppColors.error, 1),
                    focusedErrorBorder: bordure(AppColors.error, 2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  // Si un numéro E.164 est déjà stocké (+1…, +33…), on laisse
                  // le package détecter le pays depuis le préfixe au lieu de
                  // forcer 'NE' (sinon un numéro hors Niger devient invalide
                  // et bloque l'enregistrement).
                  initialCountryCode:
                      _completePhoneNumber.trim().startsWith('+') ? null : 'NE',
                  initialValue: _completePhoneNumber,
                  onChanged: (phone) =>
                      _onPhoneNumberChanged(phone.completeNumber),
                  invalidNumberMessage: l10n.adminInvalidNumberError,
                  // Téléphone optionnel : un champ vide ne doit jamais
                  // empêcher l'enregistrement.
                  disableLengthCheck: true,
                  validator: (phone) {
                    final n = phone?.number.trim() ?? '';
                    if (n.isEmpty) return null;
                    if (n.length < 4) return l10n.adminInvalidNumberError;
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildVerifyButton(),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildPhoneVisibilitySelector(),
      ],
    );
  }

  Widget _buildVerifiedPhoneCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_outlined,
            size: 18,
            color: context.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _masquerNumero(_completePhoneNumber),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 13,
                      color: context.successColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.phoneVerifiedBySms,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.successColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _editingPhone = true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.edit,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Visibilité du numéro (§20a) : une ligne avec la valeur courante et un
  /// chevron, au lieu de trois gros boutons occupant toute la largeur. Le
  /// réglage est rarement touché — il n'a pas à peser autant qu'un champ.
  /// Ramène une valeur stockée inconnue sur la valeur par défaut. Sans ça,
  /// la ligne « Qui peut voir mon numéro ? » n'affichait **aucune** valeur :
  /// le profil de test portait une chaîne absente de
  /// [ProfileOptions.phoneVisibilityOptions], et le `?? ''` la remplaçait par
  /// du vide, en silence.
  String _normaliserVisibilite(String valeur) =>
      ProfileOptions.phoneVisibilityOptions.containsKey(valeur)
          ? valeur
          : ProfileOptions.phoneVisibilityEveryone;

  Widget _buildPhoneVisibilitySelector() {
    final l10n = AppLocalizations.of(context)!;
    final libelle =
        ProfileOptions.phoneVisibilityOptions[_phoneVisibility] ??
        ProfileOptions.phoneVisibilityOptions[
            ProfileOptions.phoneVisibilityEveryone]!;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _choisirVisibiliteNumero,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.surfaceVariantColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: context.adaptivePrimaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.phoneVisibilityQuestion,
                  // Le libellé se tronque, la valeur jamais : c'est elle
                  // l'information. Avec deux enfants souples, le libellé
                  // prenait tout et la valeur disparaissait.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.textTertiaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Feuille de choix de la visibilité du numéro.
  /// Sélecteur multi-choix des langues parlées (§20a).
  ///
  /// La puce « +N langues » dépliait la liste sur place : la carte doublait
  /// de hauteur et poussait tout le formulaire vers le bas. Elle ouvre
  /// désormais une feuille — on choisit, on valide, et la carte ne montre
  /// que les langues retenues.
  ///
  /// La sélection se fait sur une copie : fermer la feuille sans valider
  /// laisse le profil intact.
  Future<void> _choisirLangues() => _choisirDansListe(
    titre: AppLocalizations.of(context)!.spokenLanguages,
    options: _languagesWithFlags,
    selection: _selectedLanguages,
  );

  /// Sélecteur multi-choix des centres d'intérêt (§20a).
  ///
  /// La puce « +N » dépliait la liste **sur place** : la page doublait de
  /// hauteur et tout ce qui suivait partait sous le pli. Elle ouvre désormais
  /// la même feuille que les langues — deux blocs jumeaux, deux mécaniques
  /// identiques.
  Future<void> _choisirInterets() => _choisirDansListe(
    titre: AppLocalizations.of(context)!.interests,
    options: {for (final cle in _interestsWithIcons.keys) cle: null},
    selection: _selectedInterests,
  );

  /// Feuille commune aux langues et aux centres d'intérêt.
  ///
  /// [options] associe chaque libellé à un code court facultatif (« FR »,
  /// « HA »…), affiché en tête de ligne. La sélection se fait sur une copie :
  /// fermer la feuille sans valider laisse le profil intact.
  Future<void> _choisirDansListe({
    required String titre,
    required Map<String, String?> options,
    required List<String> selection,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final brouillon = List<String>.from(selection);

    final valide = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, majFeuille) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titre,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ctx.textPrimaryColor,
                        ),
                      ),
                    ),
                    Text(
                      l10n.selectedCount(brouillon.length),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ctx.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.entries.map((e) {
                    final choisie = brouillon.contains(e.key);
                    return CheckboxListTile(
                      value: choisie,
                      onChanged: (_) {
                        HapticFeedback.selectionClick();
                        majFeuille(() {
                          if (choisie) {
                            brouillon.remove(e.key);
                          } else {
                            brouillon.add(e.key);
                          }
                        });
                      },
                      activeColor: ctx.adaptivePrimaryColor,
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text(
                        e.key,
                        style: TextStyle(color: ctx.textPrimaryColor),
                      ),
                      secondary:
                          e.value == null
                              ? null
                              : Text(
                                e.value!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: ctx.textTertiaryColor,
                                ),
                              ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ctx.adaptivePrimaryColor,
                      foregroundColor: ctx.onPrimaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.finish,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (valide == true && mounted) {
      setState(() {
        selection
          ..clear()
          ..addAll(brouillon);
      });
    }
  }

  Future<void> _choisirVisibiliteNumero() async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 12),
            ...ProfileOptions.phoneVisibilityOptions.entries.map(
              (e) => ListTile(
                title: Text(e.value),
                trailing: e.key == _phoneVisibility
                    ? Icon(Icons.check, color: ctx.adaptivePrimaryColor)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix != null && mounted) {
      setState(() => _phoneVisibility = choix);
    }
  }

  Widget _buildCountryDropdown({
    required String label,
    required CountryOption? value,
    required ValueChanged<CountryOption?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        _buildCountryBox(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildCountryBox({
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
          prefixIcon:
              value != null
                  ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Text(
                      value.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                  )
                  // Pas d'icône générique quand aucun pays n'est choisi :
                  // la fiche ne met rien dans les champs.
                  : null,
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

/// Libellé de champ de la fiche 20a : 12.5/600, posé au-dessus du contrôle.
/// Sert aux groupes qui n'ont pas de `CustomTextField` pour porter le leur
/// (sélecteurs, rangées de puces).
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}


/// Rangée de puces d'un champ multi-choix (langues, centres d'intérêt).
///
/// Ne montre que ce qui est **retenu**, plus une puce d'ouverture. Rien de
/// sélectionné n'affichait auparavant qu'un « +10 » nu, qui ne dit ni ce
/// qu'on choisit ni qu'on peut le faire : la puce porte alors une invitation
/// en toutes lettres.
class _ChipsField extends StatelessWidget {
  /// Libellé → code court facultatif, dans l'ordre d'affichage.
  final Map<String, String?> options;
  final List<String> selection;

  /// Libellé de la puce d'ouverture quand il reste des choix à faire.
  final String Function(int) restantLabel;

  /// Libellé de la puce d'ouverture quand rien n'est encore choisi.
  final String videLabel;
  final VoidCallback onOuvrir;
  final ValueChanged<String> onRetirer;

  const _ChipsField({
    required this.options,
    required this.selection,
    required this.restantLabel,
    required this.videLabel,
    required this.onOuvrir,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final retenues = options.keys.where(selection.contains).toList();
    final restant = options.length - retenues.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cle in retenues)
          _ProfileChip(
            label: cle,
            code: options[cle],
            isSelected: true,
            onTap: () => onRetirer(cle),
          ),
        // Masquée quand tout est déjà retenu : une puce « +0 » n'aurait rien
        // à ouvrir.
        if (restant > 0)
          _ProfileChip(
            label: retenues.isEmpty ? videLabel : restantLabel(restant),
            isSelected: false,
            onTap: onOuvrir,
          ),
      ],
    );
  }
}

/// Puce de sélection du profil (§20a) : pilule au rayon 999, remplie à
/// l'encre quand elle est retenue, en simple contour sinon.
///
/// Une seule puce pour les langues et les centres d'intérêt : la fiche leur
/// donne le même traitement, seul le code court de deux lettres change.
/// L'ancienne paire (`_SelectableChip` / `_LanguageChip`) divergeait sur le
/// rayon, la couleur d'accent et jusqu'à la coche de sélection.
class _ProfileChip extends StatelessWidget {
  final String label;

  /// Code court affiché avant le libellé (« FR », « HA »). Absent pour les
  /// centres d'intérêt.
  final String? code;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    final fond = isSelected ? context.textPrimaryColor : Colors.transparent;
    final texte =
        isSelected ? context.backgroundColor : context.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fond,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? context.textPrimaryColor
                  : context.borderStrongColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (code != null) ...[
                Text(
                  code!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    // Le code reste lisible sans voler la vedette au nom :
                    // même encre, atténuée.
                    color: texte.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: texte,
                ),
              ),
            ],
          ),
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

