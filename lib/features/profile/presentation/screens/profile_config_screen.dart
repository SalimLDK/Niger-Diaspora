import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/handle_field.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../core/theme/design_kit.dart';

/// Sentinelles d'erreur : le message affiché est localisé, mais la
/// reconnaissance du cas repose sur ces marqueurs bruts, qui ne doivent pas
/// dépendre de la langue.
const String _kProfileMissing = 'Profil introuvable';
const String _kNotSignedIn = 'Utilisateur non connecté';

/// Configuration du profil en quatre étapes (maquettes 16f, 15c, 15d, 16g).
///
/// Le découpage suit les maquettes et non plus l'ancien écran : l'identité
/// (photo, nom, poignée, métier) est séparée de la localisation, et les
/// notifications ont rejoint l'étape des centres d'intérêt sous la forme
/// « Ce que vous recevrez ». Chaque champ dit à quoi il sert.
class ProfileConfigScreen extends ConsumerStatefulWidget {
  const ProfileConfigScreen({super.key});

  @override
  ConsumerState<ProfileConfigScreen> createState() =>
      _ProfileConfigScreenState();
}

class _ProfileConfigScreenState extends ConsumerState<ProfileConfigScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const int _stepCount = 4;

  int _currentStep = 0;
  bool _isLoading = false;

  // Basic info
  final _displayNameController = TextEditingController();
  bool _hasManuallyEdited = false;
  String? _selectedProfession;

  // Poignée publique @handle (§16f)
  String? _handle;
  String? _initialHandle;
  bool _handleValid = true;

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

  /// Centres d'intérêt : la valeur stockée reste la chaîne française (c'est
  /// ce que le profil enregistre), seul le libellé affiché est localisé.
  static const List<String> _availableInterests = [
    'Culture',
    'Sport',
    'Business',
    'Education',
    'Technologie',
    'Arts',
    'Santé',
    'Politique',
  ];

  String _interestLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Culture':
        return l10n.interestCulture;
      case 'Sport':
        return l10n.interestSport;
      case 'Business':
        return l10n.interestBusiness;
      case 'Education':
        return l10n.interestEducation;
      case 'Technologie':
        return l10n.interestTechnology;
      case 'Arts':
        return l10n.interestArts;
      case 'Santé':
        return l10n.interestHealth;
      case 'Politique':
        return l10n.interestPolitics;
      default:
        return value;
    }
  }

  // Notifications
  bool _enableNotifications = true;
  bool _enableEventNotifications = true;
  bool _enableMessageNotifications = true;

  // Theme
  AppThemeMode _selectedThemeMode = AppThemeMode.system;
  // Aligné sur le défaut du ThemeColorNotifier. Cette valeur est de toute
  // façon écrasée par _themeInitialized au premier build de l'étape 4/4,
  // mais un défaut divergent finirait par mentir un jour.
  AppThemeColor _selectedThemeColor = AppThemeColor.orange;
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
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;

    if (currentUser != null && mounted) {
      setState(() {
        // 1. Try pre-fill displayName from Firebase Auth user
        if (!_hasManuallyEdited &&
            currentUser.displayName != null &&
            currentUser.displayName!.isNotEmpty) {
          _displayNameController.text = currentUser.displayName!;
        }

        // 2. Try to load additional data from profile
        final profile =
            ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;
        if (profile != null) {
          // Fallback: If Auth name was empty but profile has name, use it
          if (!_hasManuallyEdited &&
              _displayNameController.text.isEmpty &&
              profile.displayName != null &&
              profile.displayName!.isNotEmpty) {
            _displayNameController.text = profile.displayName!;
          }

          // Pre-fill profession
          if (profile.profession != null && profile.profession!.isNotEmpty) {
            _selectedProfession = profile.profession;
          }

          // Pre-fill handle
          _initialHandle = profile.handle;
          _handle = profile.handle;
        }
      });
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
        throw Exception(_kProfileMissing);
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
        handle: _handle,
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

      // `ProfileNotifier.updateProfile` ne relance pas l'échec : il le range
      // dans son état. Sans cette relecture, un refus du serveur laissait
      // l'assistant marquer la configuration comme terminée — et sortir sans
      // le moindre message — alors que rien n'avait été enregistré.
      final saved = ref.read(profileNotifierProvider(currentUser.id));
      if (saved.hasError) {
        throw Exception(saved.error?.toString() ?? '');
      }

      // Theme settings are already applied when user selects them
      // No need to apply again here

      // Mark profile configuration as complete via onboarding provider
      await ref
          .read(onboardingNotifierProvider.notifier)
          .markProfileConfigComplete();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final texte = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              texte.contains('SSL') || texte.contains('Connection')
                  ? l10n.setupErrorConnection
                  : texte.contains(_kNotSignedIn)
                  ? l10n.setupErrorNotSignedIn
                  : texte.contains(_kProfileMissing)
                  ? l10n.setupErrorProfileMissing
                  : l10n.setupErrorGeneric(texte),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action:
                currentUser != null
                    ? SnackBarAction(
                      label: l10n.retry,
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

  void _goNext(currentUser) {
    // Bloque l'avancement si la poignée saisie à l'étape 1/4 est invalide ou
    // déjà prise.
    if (_currentStep == 0 && !_handleValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.setupHandleInvalid),
        ),
      );
      return;
    }
    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep++);
    } else {
      _handleComplete(currentUser);
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

    final isLastStep = _currentStep == _stepCount - 1;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(child: _buildCurrentStep()),

            // Barre de navigation : « Précédent » n'apparaît qu'à partir de
            // la 2e étape, comme sur les maquettes.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      flex: 3,
                      child: DesignSecondaryButton(
                        label: l10n.profilePrevious,
                        onPressed:
                            _isLoading
                                ? null
                                : () => setState(() => _currentStep--),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    // 3/4 et non 1/2 : à font_scale 1.1, « Précédent » était
                    // tronqué en « Précéd » sur le SM A515F. La maquette veut
                    // un bouton principal plus large, pas un secondaire illisible.
                    flex: _currentStep > 0 ? 4 : 1,
                    child: DesignPrimaryButton(
                      label: isLastStep ? l10n.finish : l10n.next,
                      isLoading: _isLoading,
                      onPressed:
                          currentUser == null
                              ? null
                              : () => _goNext(currentUser),
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

  /// En-tête : retour, titre de section, compteur d'étape, puis les quatre
  /// segments de progression.
  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                IconButton(
                  onPressed:
                      _isLoading ? null : () => setState(() => _currentStep--),
                  icon: Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: context.textPrimaryColor,
                  ),
                  splashRadius: 22,
                )
              else
                const SizedBox(width: 12),
              Text(
                l10n.profileConfigTitle,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_currentStep + 1}/$_stepCount',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: DesignStepBar(total: _stepCount, current: _currentStep),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildIdentityStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildInterestsStep();
      case 3:
        return _buildThemeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------- étape 1/4

  /// « Faisons connaissance » (§16f) : photo, nom, poignée, métier.
  Widget _buildIdentityStep() {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    final displayName =
        _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : (currentUser?.displayName ?? l10n.user);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitle(l10n.setupIdentityTitle),
          const SizedBox(height: 10),
          DesignBody(l10n.setupIdentityBody),
          const SizedBox(height: 26),

          Center(child: _buildAvatarPicker(displayName)),
          const SizedBox(height: 26),

          DesignFieldLabel(l10n.fullName),
          TextField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              _hasManuallyEdited = true;
              setState(() {});
            },
            style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
            decoration: designInputDecoration(
              context,
              hintText: l10n.setupFullNameHint,
            ),
          ),
          const SizedBox(height: 18),

          // Poignée publique @handle (§16f)
          HandleField(
            initialHandle: _initialHandle,
            userId: currentUser?.id,
            onChanged: (normalized, isValid) {
              _handle = normalized;
              _handleValid = isValid;
            },
          ),
          const SizedBox(height: 18),

          DesignFieldLabel(l10n.profession),
          DesignDropdown<String>(
            value: _selectedProfession,
            hintText: l10n.setupProfessionHint,
            helperText: l10n.setupProfessionHelper,
            items:
                ProfileOptions.professions.map((profession) {
                  return DropdownMenuItem(
                    value: profession,
                    child: Text(profession),
                  );
                }).toList(),
            onChanged: (value) => setState(() => _selectedProfession = value),
          ),
        ],
      ),
    );
  }

  /// Avatar rond terracotta avec pastille appareil photo, puis l'invitation
  /// « Ajouter une photo · optionnel ».
  Widget _buildAvatarPicker(String displayName) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: context.adaptivePrimaryColor.withValues(
                alpha: 0.18,
              ),
              backgroundImage:
                  _photoUrl != null ? NetworkImage(_photoUrl!) : null,
              child:
                  _photoUrl == null
                      ? Text(
                        _getInitials(displayName),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
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
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: context.onPrimaryColor,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Text(
            _photoUrl == null ? l10n.setupAddPhoto : l10n.changePhoto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.adaptivePrimaryColor,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          l10n.setupPhotoHint,
          style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ---------------------------------------------------------------- étape 2/4

  /// « Votre localisation » (§15c) : ce que la position sert à faire est dit
  /// avant de la demander.
  Widget _buildLocationStep() {
    final l10n = AppLocalizations.of(context)!;
    final needsCustomOriginCity =
        _selectedOriginRegion == 'Autre' || _selectedOriginCity == 'Autre';
    final originCities =
        _selectedOriginRegion != null && _selectedOriginRegion != 'Autre'
            ? ProfileOptions.getCitiesForRegion(_selectedOriginRegion!)
            : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitle(l10n.yourLocation),
          const SizedBox(height: 10),
          DesignBody(l10n.setupLocationBody),
          const SizedBox(height: 26),

          DesignFieldLabel(l10n.currentCountry),
          DesignDropdown<CountryOption>(
            value: _selectedCountry,
            hintText: l10n.profileSelectCountry,
            items:
                ProfileOptions.countries.map((country) {
                  return DropdownMenuItem(
                    value: country,
                    child: Text(country.displayName),
                  );
                }).toList(),
            onChanged: (value) => setState(() => _selectedCountry = value),
          ),
          const SizedBox(height: 18),

          DesignFieldLabel(l10n.currentCity),
          TextField(
            controller: _selectedCityController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
            decoration: designInputDecoration(
              context,
              hintText: l10n.setupCityHint,
            ),
          ),
          const SizedBox(height: 20),

          DesignFieldLabel(
            l10n.originAtNiger,
            trailing: Text(
              l10n.optional,
              style: TextStyle(
                fontSize: 12.5,
                color: context.textTertiaryColor,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DesignDropdown<String>(
                  value: _selectedOriginRegion,
                  hintText: l10n.profileRegion,
                  items:
                      ProfileOptions.regions.map((region) {
                        return DropdownMenuItem(
                          value: region,
                          child: Text(region),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOriginRegion = value;
                      _selectedOriginCity = null;
                      _customOriginCityController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DesignDropdown<String>(
                  value: _selectedOriginCity,
                  hintText: l10n.city,
                  items:
                      originCities.map((city) {
                        return DropdownMenuItem(value: city, child: Text(city));
                      }).toList(),
                  // Désactivée tant qu'aucune région n'est choisie : la liste
                  // des villes en dépend.
                  onChanged:
                      originCities.isEmpty
                          ? null
                          : (value) {
                            setState(() {
                              _selectedOriginCity = value;
                              if (value != 'Autre') {
                                _customOriginCityController.clear();
                              }
                            });
                          },
                ),
              ),
            ],
          ),
          if (needsCustomOriginCity) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customOriginCityController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
              decoration: designInputDecoration(
                context,
                hintText: l10n.setupOriginCityHint,
              ),
            ),
          ],
          const SizedBox(height: 22),

          DesignTileGroup(
            children: [
              DesignToggleTile(
                icon: Icons.location_on_outlined,
                title: l10n.shareLocation,
                subtitle: l10n.setupShareLocationSubtitle,
                value: _shareLocation,
                onChanged: (value) => setState(() => _shareLocation = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DesignInfoLine(
            icon: Icons.info_outline,
            text: l10n.setupLocationPrivacyNote,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- étape 3/4

  /// « Vos centres d'intérêt » (§15d) + « Ce que vous recevrez » : les deux
  /// réglages qui personnalisent le fil vivent sur le même écran.
  Widget _buildInterestsStep() {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedInterests.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitle(l10n.interestsTitle),
          const SizedBox(height: 10),
          DesignBody(l10n.setupInterestsBody),
          const SizedBox(height: 22),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _availableInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return DesignSelectableChip(
                    label: _interestLabel(l10n, interest),
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterests.remove(interest);
                        } else {
                          _selectedInterests.add(interest);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            count == 0
                ? l10n.setupNoneSelected
                : l10n.setupSelectedCount(count),
            style: TextStyle(fontSize: 12.5, color: context.textTertiaryColor),
          ),

          const SizedBox(height: 22),
          Divider(height: 1, color: context.dividerColor),
          const SizedBox(height: 22),

          DesignSectionTitle(l10n.setupWhatYouGet),
          const SizedBox(height: 14),
          DesignTileGroup(
            children: [
              DesignToggleTile(
                icon: Icons.chat_bubble_outline,
                title: l10n.messages,
                subtitle: l10n.profileNewMessagesNotifications,
                value: _enableMessageNotifications,
                onChanged:
                    (value) => setState(() {
                      _enableMessageNotifications = value;
                      _syncNotificationsMaster();
                    }),
              ),
              DesignToggleTile(
                icon: Icons.event_outlined,
                title: l10n.eventsTitle,
                subtitle: l10n.profileNewEventsInCity,
                value: _enableEventNotifications,
                onChanged:
                    (value) => setState(() {
                      _enableEventNotifications = value;
                      _syncNotificationsMaster();
                    }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Le profil n'a qu'un seul drapeau `notificationsEnabled` : il reste vrai
  /// tant qu'au moins une des deux catégories est active.
  void _syncNotificationsMaster() {
    _enableNotifications =
        _enableMessageNotifications || _enableEventNotifications;
  }

  // ---------------------------------------------------------------- étape 4/4

  /// « Thème de l'application » (§16g) : trois aperçus de mode, la couleur
  /// d'accent, puis le récapitulatif de fin de configuration.
  Widget _buildThemeStep() {
    final l10n = AppLocalizations.of(context)!;
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
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitle(l10n.themeAppTitle),
          const SizedBox(height: 10),
          DesignBody(l10n.setupThemeBody),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _ThemeModeCard(
                  mode: AppThemeMode.light,
                  label: l10n.light,
                  isSelected: _selectedThemeMode == AppThemeMode.light,
                  onTap: () => _selectThemeMode(AppThemeMode.light),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeModeCard(
                  mode: AppThemeMode.dark,
                  label: l10n.dark,
                  isSelected: _selectedThemeMode == AppThemeMode.dark,
                  onTap: () => _selectThemeMode(AppThemeMode.dark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeModeCard(
                  mode: AppThemeMode.system,
                  label: l10n.autoLabel,
                  isSelected: _selectedThemeMode == AppThemeMode.system,
                  onTap: () => _selectThemeMode(AppThemeMode.system),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          DesignFieldLabel(l10n.setupAccentColor),
          Row(
            children: [
              _AccentSwatch(
                // La pastille est l'aperçu de l'accent choisi : elle doit
                // porter la valeur que le thème rendra réellement, soit
                // l'orange d'action `#B85E24` du guide de style — pas la
                // teinte claire de la famille.
                color: AppColors.primaryDark,
                label: l10n.orangeColor,
                isSelected: _selectedThemeColor == AppThemeColor.orange,
                onTap: () => _selectThemeColor(AppThemeColor.orange),
              ),
              const SizedBox(width: 18),
              _AccentSwatch(
                color: AppColors.secondary,
                label: l10n.greenColor,
                isSelected: _selectedThemeColor == AppThemeColor.green,
                onTap: () => _selectThemeColor(AppThemeColor.green),
              ),
            ],
          ),
          const SizedBox(height: 26),

          _buildCompletionSummary(),
        ],
      ),
    );
  }

  void _selectThemeMode(AppThemeMode mode) {
    setState(() => _selectedThemeMode = mode);
    ref.read(themeModeNotifierProvider.notifier).setThemeMode(mode);
  }

  void _selectThemeColor(AppThemeColor color) {
    setState(() => _selectedThemeColor = color);
    ref.read(themeColorNotifierProvider.notifier).setThemeColor(color);
  }

  /// Récapitulatif de fin : le pourcentage est calculé sur les champs
  /// réellement remplis, jamais annoncé d'avance.
  Widget _buildCompletionSummary() {
    final l10n = AppLocalizations.of(context)!;
    final filled = <bool>[
      _displayNameController.text.trim().isNotEmpty,
      (_handle ?? '').isNotEmpty,
      _selectedProfession != null,
      _selectedCountry != null,
      _selectedCityController.text.trim().isNotEmpty,
      _selectedInterests.isNotEmpty,
      _photoUrl != null,
    ];
    final percent =
        (filled.where((f) => f).length * 100 / filled.length).round();

    final name = _displayNameController.text.trim();
    final firstName = name.isEmpty ? null : name.split(' ').first;
    final city = _selectedCityController.text.trim();

    return DesignSummaryCard(
      title:
          firstName == null
              ? l10n.setupAllSet
              : l10n.setupAllSetNamed(firstName),
      body:
          city.isEmpty
              ? l10n.setupCompletionSummary(percent)
              : l10n.setupCompletionSummaryCity(percent, city),
    );
  }

  // ------------------------------------------------------------------- photo

  Future<void> _showImagePickerOptions() async {
    final l10n = AppLocalizations.of(context)!;
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
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DesignSectionTitle(l10n.setupYourPhoto),
                ),
                const SizedBox(height: 18),
                _ImagePickerOption(
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: context.adaptivePrimaryColor,
                  ),
                  title: l10n.takePhotoTitle,
                  subtitle: l10n.takePhotoSubtitle,
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
                  title: l10n.galleryTitle,
                  subtitle: l10n.gallerySubtitle,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_photoUrl != null)
                  _ImagePickerOption(
                    icon: const AppIcon(AppIcon.delete, color: AppColors.error),
                    title: l10n.deletePhoto,
                    subtitle: l10n.deletePhotoSubtitle,
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
}

// ---------------------------------------------------------------- composants

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
      borderRadius: BorderRadius.circular(kDesignRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: context.borderColor),
          borderRadius: BorderRadius.circular(kDesignRadius),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDestructive
                        ? AppColors.error.withValues(alpha: 0.1)
                        : context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: icon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color:
                          isDestructive
                              ? AppColors.error
                              : context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.textTertiaryColor,
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

/// Carte d'aperçu d'un mode d'affichage (§16g) : une miniature de page plutôt
/// qu'un pictogramme, pour montrer ce que le mode change.
class _ThemeModeCard extends StatelessWidget {
  final AppThemeMode mode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeCard({
    required this.mode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kDesignRadius),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border.all(
            color: isSelected ? accent : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(kDesignRadius),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.92,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _ThemeModePreview(mode: mode),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? accent : context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature de page. Les couleurs sont volontairement figées : cette vignette
/// représente le thème clair et le thème sombre, elle ne suit donc pas le
/// thème courant.
class _ThemeModePreview extends StatelessWidget {
  final AppThemeMode mode;

  const _ThemeModePreview({required this.mode});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AppThemeMode.light:
        return _panel(dark: false);
      case AppThemeMode.dark:
        return _panel(dark: true);
      case AppThemeMode.system:
        // Moitié claire / moitié sombre, coupées en diagonale.
        return Stack(
          fit: StackFit.expand,
          children: [
            _panel(dark: false),
            ClipPath(clipper: _DiagonalClipper(), child: _panel(dark: true)),
          ],
        );
    }
  }

  Widget _panel({required bool dark}) {
    final background = dark ? AppColors.backgroundDark : AppColors.background;
    final bar = dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
    return Container(
      color: background,
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(bar, widthFactor: 0.85),
          const SizedBox(height: 5),
          _bar(bar, widthFactor: 0.6),
          const SizedBox(height: 12),
          // L'aperçu doit montrer l'accent du thème qu'il représente : l'orange
          // d'action en clair, sa version éclaircie en nocturne. Les deux
          // vignettes affichaient la même valeur.
          _bar(
            dark ? AppColors.primaryLight : AppColors.primaryDark,
            widthFactor: 0.72,
            height: 9,
          ),
        ],
      ),
    );
  }

  Widget _bar(Color color, {required double widthFactor, double height = 5}) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Pastille de couleur d'accent (§16g).
class _AccentSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border:
                  isSelected
                      ? Border.all(color: context.textPrimaryColor, width: 2)
                      : null,
            ),
            alignment: Alignment.center,
            child:
                isSelected
                    ? const Icon(Icons.check, size: 22, color: Colors.white)
                    : null,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color:
                  isSelected
                      ? context.textPrimaryColor
                      : context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
