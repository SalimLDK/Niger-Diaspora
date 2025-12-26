import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../friends/domain/repositories/friend_repository.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../providers/profile_provider.dart';
import '../providers/online_status_provider.dart';
import '../widgets/online_status_indicator.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/background_location_service.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;
  final ProfileEntity? initialProfile;

  const ProfileViewScreen({
    super.key,
    required this.userId,
    this.initialProfile,
  });

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  ProfileEntity? _profile;
  bool _isLoading = true;
  bool _isBackgroundLocationEnabled = false;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    _loadBackgroundLocationStatus();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _isLoading = false;
    } else {
      // Use addPostFrameCallback to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProfile();
      });
    }
  }

  void _checkIfCurrentUser() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == widget.userId) {
      setState(() {
        _isCurrentUser = true;
      });
    }
  }

  Future<void> _loadBackgroundLocationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackgroundLocationService.prefKeyEnabled) ?? false;
    if (mounted) {
      setState(() {
        _isBackgroundLocationEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBackgroundLocation(bool value) async {
    if (value) {
      // 1. Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Permission de localisation refusée"),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Permission de localisation refusée définitivement. Veuillez l'activer dans les paramètres.",
              ),
            ),
          );
        }
        return;
      }
    }

    await BackgroundLocationService.setEnabled(value);
    setState(() {
      _isBackgroundLocationEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "Mode Voyage activé (Localisation en arrière-plan)"
                : "Mode Voyage désactivé",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    debugPrint(
      '🔍 ProfileViewScreen: Loading profile for userId: ${widget.userId}',
    );
    try {
      await ref
          .read(profileNotifierProvider.notifier)
          .loadProfile(widget.userId);
      final profile = ref.read(profileNotifierProvider).valueOrNull;
      debugPrint('✅ ProfileViewScreen: Profile loaded successfully');
      debugPrint('   - displayName: ${profile?.displayName}');
      debugPrint('   - email: ${profile?.email}');
      debugPrint('   - profession: ${profile?.profession}');
      debugPrint('   - bio: ${profile?.bio}');
      debugPrint('   - currentCity: ${profile?.currentCity}');
      debugPrint('   - skills: ${profile?.skills}');
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ProfileViewScreen: Error loading profile: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du profil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startConversation() async {
    if (_profile == null) return;

    // Create or get existing conversation with this user
    final conversation = await ref
        .read(createConversationProvider.notifier)
        .createIndividual(_profile!.id);

    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': _profile!.displayName,
          'imageUrl': _profile!.photoUrl,
          'otherUserId': _profile!.id,
          'isGroup': false,
        },
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_profile == null) return;

    final l10n = AppLocalizations.of(context)!;
    final success = await ref
        .read(friendRequestNotifierProvider.notifier)
        .sendRequest(
          receiverId: _profile!.id,
          receiverName: _profile!.displayName ?? l10n.member,
          receiverPhotoUrl: _profile!.photoUrl,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Demande d\'ami envoyée' : 'Échec de l\'envoi',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  String _buildLocationString(AppLocalizations l10n) {
    final city = _profile?.currentCity;
    final region = _profile?.currentRegion;
    final country = _profile?.currentCountry;

    final parts = <String>[];

    if (city != null && city.isNotEmpty) {
      parts.add(city);
    }

    if (region != null && region.isNotEmpty) {
      parts.add(region);
    }

    if (country != null && country.isNotEmpty) {
      parts.add(country);
    }

    return parts.join(', ');
  }

  String _buildOriginString(AppLocalizations l10n) {
    final region = _profile?.originRegion;
    final city = _profile?.originCity;

    if (region != null &&
        region.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      return '${l10n.fromCity(city)} ($region)';
    } else if (region != null && region.isNotEmpty) {
      return l10n.fromRegion(region);
    } else if (city != null && city.isNotEmpty) {
      return l10n.fromCity(city);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.profileTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppColors.error.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.deletedProfile,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.accountNoLongerExists,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final locationString = _buildLocationString(l10n);
    final originString = _buildOriginString(l10n);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: context.textPrimaryColor),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child:
                            _profile!.photoUrl != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.network(
                                    _profile!.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Icon(
                                          Icons.person,
                                          size: 50,
                                          color: context.adaptivePrimaryColor,
                                        ),
                                  ),
                                )
                                : Icon(
                                  Icons.person,
                                  size: 50,
                                  color: context.adaptivePrimaryColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Center(
                    child: Text(
                      _profile!.displayName?.isNotEmpty == true
                          ? _profile!.displayName!
                          : 'Nouvel utilisateur',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),

                  // Online Status Indicator
                  const SizedBox(height: 8),
                  Center(
                    child: OnlineStatusIndicator(
                      userId: _profile!.id,
                      showText: true,
                      dotSize: 10,
                    ),
                  ),

                  if (_profile!.profession != null &&
                      _profile!.profession!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _profile!.profession!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Current location (city, country)
                  if (locationString.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationString,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Origin (region, city in Niger)
                  if (originString.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 18,
                            color: context.adaptiveSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            originString,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bio
                  Text(
                    l10n.about,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _profile!.bio?.isNotEmpty == true
                          ? _profile!.bio!
                          : 'Aucune biographie',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            _profile!.bio?.isNotEmpty == true
                                ? context.textSecondaryColor
                                : context.textTertiaryColor,
                        height: 1.5,
                        fontStyle:
                            _profile!.bio?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Compétences
                  Text(
                    l10n.skills,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _profile!.skills.isNotEmpty
                      ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _profile!.skills
                                .map(
                                  (skill) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.adaptivePrimaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      skill,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.adaptivePrimaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      )
                      : Text(
                        'Aucune compétence ajoutée',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textTertiaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  const SizedBox(height: 16),

                  // Intérêts
                  Text(
                    l10n.interests,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _profile!.interests.isNotEmpty
                      ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _profile!.interests
                                .map(
                                  (interest) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.surfaceVariantColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      )
                      : Text(
                        'Aucun intérêt ajouté',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textTertiaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  const SizedBox(height: 16),

                  // Langues
                  if (_profile!.languages.isNotEmpty) ...[
                    Text(
                      l10n.languagesSpoken,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _profile!.languages
                              .map(
                                (language) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariantColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    language,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],

                  if (_isCurrentUser) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Paramètres",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.outlineColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text("Mode Voyage"),
                            subtitle: const Text(
                              "Permettre la localisation même quand l'application est fermée (Mise à jour toutes les 5 min)",
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isBackgroundLocationEnabled,
                            activeColor: context.adaptivePrimaryColor,
                            onChanged: _toggleBackgroundLocation,
                          ),
                          Divider(
                            height: 1,
                            color: context.outlineColor.withValues(alpha: 0.1),
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final visibilityAsync = ref.watch(
                                currentUserOnlineStatusVisibilityProvider,
                              );

                              return visibilityAsync.when(
                                data: (showStatus) {
                                  return SwitchListTile(
                                    title: const Text(
                                      "Afficher mon statut en ligne",
                                    ),
                                    subtitle: const Text(
                                      "Permet de voir et d'être vu en ligne. Si désactivé, vous ne verrez pas le statut des autres.",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: showStatus,
                                    activeColor: context.adaptivePrimaryColor,
                                    onChanged: (value) async {
                                      try {
                                        await ref
                                            .read(
                                              currentUserOnlineStatusVisibilityProvider
                                                  .notifier,
                                            )
                                            .setValue(value);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Erreur lors de la mise à jour: $e',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  );
                                },
                                loading:
                                    () => SwitchListTile(
                                      title: const Text(
                                        "Afficher mon statut en ligne",
                                      ),
                                      subtitle: const Text(
                                        "Chargement...",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: true,
                                      onChanged: null,
                                    ),
                                error:
                                    (_, __) => SwitchListTile(
                                      title: const Text(
                                        "Afficher mon statut en ligne",
                                      ),
                                      subtitle: const Text(
                                        "Erreur de chargement",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: true,
                                      onChanged: null,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final friendshipStatus = ref.watch(
            friendshipStatusProvider(widget.userId),
          );

          return friendshipStatus.when(
            data: (status) {
              // Determine button configuration based on friendship status
              String buttonText = '';
              IconData buttonIcon = Icons.help_outline;
              VoidCallback? onPressed;
              Color backgroundColor = context.adaptivePrimaryColor;

              switch (status) {
                case FriendshipStatus.friends:
                  buttonText = 'Envoyer un message';
                  buttonIcon = Icons.chat;
                  onPressed = _startConversation;
                  backgroundColor = context.adaptivePrimaryColor;
                  break;

                case FriendshipStatus.pendingSent:
                  buttonText = 'Demande envoyée';
                  buttonIcon = Icons.schedule;
                  onPressed = null; // Disabled
                  backgroundColor = context.textSecondaryColor;
                  break;

                case FriendshipStatus.pendingReceived:
                  buttonText = 'Accepter la demande';
                  buttonIcon = Icons.person_add;
                  onPressed = () async {
                    // Find the request and accept it
                    final requests = await ref.read(
                      receivedFriendRequestsProvider.future,
                    );
                    final request = requests.firstWhere(
                      (r) => r.senderId == widget.userId,
                      orElse: () => throw Exception('Request not found'),
                    );
                    await ref
                        .read(friendRequestNotifierProvider.notifier)
                        .acceptRequest(request.id);
                  };
                  backgroundColor = context.successColor;
                  break;

                case FriendshipStatus.none:
                  buttonText = 'Envoyer une demande d\'ami';
                  buttonIcon = Icons.person_add;
                  onPressed = _sendFriendRequest;
                  backgroundColor = context.adaptivePrimaryColor;
                  break;
              }

              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(buttonIcon),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              );
            },
            loading:
                () => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                ),
            error:
                (_, __) => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _sendFriendRequest,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Envoyer une demande d\'ami'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
          );
        },
      ),
    );
  }
}
