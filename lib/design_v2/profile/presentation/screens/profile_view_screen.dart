import 'package:flutter/material.dart';
import '../../../kit/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/friends/domain/repositories/friend_repository.dart';
import '../../../../features/friends/presentation/providers/friend_provider.dart';
import '../../../../features/messages/presentation/providers/message_provider.dart';
import '../../../../features/messages/presentation/providers/media_gallery_provider.dart';
import '../../../../features/messages/presentation/widgets/media_gallery_grid.dart';
import '../../../../features/profile/domain/entities/profile_entity.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/profile/presentation/providers/online_status_provider.dart';
import '../../../../features/groups/presentation/providers/common_groups_provider.dart';
import '../../../../features/profile/presentation/widgets/online_status_indicator.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/background_location_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../features/profile/presentation/widgets/share_profile_modal.dart';
import 'package:flutter/services.dart';
import '../../../../features/messages/presentation/widgets/full_screen_image_viewer.dart';
import '../../../../features/settings/presentation/providers/blocked_users_provider.dart';
import '../../../../features/reports/domain/entities/report_entity.dart';
import '../../../../features/reports/presentation/widgets/report_content_modal.dart';
import '../../../../shared/widgets/app_icon.dart';

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

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isBackgroundLocationEnabled = false;
  bool _isCurrentUser = false;
  bool _isSendingRequest = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    _loadBackgroundLocationStatus();
    // Profile is auto-loaded by the provider
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
      // Step 1: Check basic location permission
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
          await Geolocator.openAppSettings();
        }
        return;
      }

      // Step 2: Request notification permission (Android 13+)
      await LocationService.instance.requestNotificationPermission();
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

  Future<void> _startConversation() async {
    final l10n = AppLocalizations.of(context)!;
    // Use the same provider as the screen display (userStreamProvider)
    // instead of profileNotifierProvider to avoid desync issues
    final profileAsync = ref.read(userStreamProvider(widget.userId));
    final profile = profileAsync.valueOrNull;

    if (profile == null || profile.displayName == l10n.deletedUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileCannotChatDeleted),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Create or get existing conversation with this user
    final conversation = await ref
        .read(createConversationProvider.notifier)
        .createIndividual(profile.id);

    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': profile.displayName,
          'imageUrl': profile.photoUrl,
          'otherUserId': profile.id,
          'isGroup': false,
        },
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isSendingRequest) return;
    final l10n = AppLocalizations.of(context)!;

    // Use the same provider as the screen display (userStreamProvider)
    final profileAsync = ref.read(userStreamProvider(widget.userId));
    final profile = profileAsync.valueOrNull;
    if (profile == null || profile.displayName == l10n.deletedUser) {
      return;
    }

    setState(() {
      _isSendingRequest = true;
    });

    final success = await ref
        .read(friendRequestNotifierProvider.notifier)
        .sendRequest(
          receiverId: profile.id,
          receiverName: profile.displayName ?? l10n.member,
          receiverPhotoUrl: profile.photoUrl,
        );

    if (mounted) {
      setState(() {
        _isSendingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.profileFriendRequestSent : l10n.profileFriendRequestFailed,
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _blockUser(ProfileEntity profile) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquer l\'utilisateur'),
        content: Text(
          l10n.profileBlockConfirm(profile.displayName ?? l10n.user),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(blockUserNotifierProvider.notifier)
        .blockUser(
          targetUserId: profile.id,
          targetDisplayName: profile.displayName ?? 'Utilisateur',
          targetPhotoUrl: profile.photoUrl,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.userBlocked : l10n.blockError,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        // Retourner à l'écran précédent après le blocage
        if (context.canPop()) {
          context.pop();
        }
      }
    }
  }





  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildProfileInitials(BuildContext context, String? name) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: context.adaptivePrimaryColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, WidgetRef ref) {
    final conversationIdAsync = ref.watch(
      userConversationIdProvider(widget.userId),
    );

    return conversationIdAsync.when(
      data: (conversationId) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MediaGalleryCompact(
            conversationId: conversationId,
            onViewAll:
                conversationId != null
                    ? () {
                      context.push('/messages/$conversationId/media');
                    }
                    : null,
          ),
        );
      },
      loading: () {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: MediaGalleryCompact(
            conversationId: null, // Will show loading skeleton
            showEmptyState: true,
          ),
        );
      },
      error: (e, s) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: MediaGalleryCompact(
            conversationId: null,
            showEmptyState: true,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for KeepAlive
    final l10n = AppLocalizations.of(context)!;

    // Watch the specific profile for this user (Stream pour mises à jour temps réel)
    final profileAsync = ref.watch(userStreamProvider(widget.userId));

    return profileAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: context.backgroundColor,
            appBar: AppBar(
              leading: IconButton(
                icon: const AppIcon(AppIcon.arrowBack),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            body: Center(
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
      error:
          (err, stack) => Scaffold(
            backgroundColor: context.backgroundColor,
            appBar: AppBar(
              leading: IconButton(
                icon: const AppIcon(AppIcon.arrowBack),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            body: Center(child: Text('Erreur: $err')),
          ),
      data: (profile) {
        if (profile == null) {
          return _buildDeletedProfile(context, l10n);
        }
        return _buildProfileContent(context, profile, l10n);
      },
    );
  }

  Widget _buildDeletedProfile(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(AppIcon.arrowBack),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
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

  /// Compteur « groupes en commun » (§10c). Masqué s'il n'y en a pas.
  Widget _buildCommonGroups(BuildContext context, String userId) {
    final common = ref.watch(commonGroupsProvider(userId)).valueOrNull ?? [];
    if (common.isEmpty) return const SizedBox.shrink();
    final label = AppLocalizations.of(
      context,
    )!.profileCommonGroups(common.length);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.adaptiveSecondaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcon.groups,
                size: 16,
                color: context.adaptiveSecondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    ProfileEntity profile,
    AppLocalizations l10n,
  ) {
    // Check if user is blocked (both ways)
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isBlockedByMe = blockedUserIds.contains(profile.id);
    final isBlockedByThem = currentUserId != null && profile.blockedByUserIds.contains(currentUserId);
    final isBlocked = isBlockedByMe || isBlockedByThem;

    // Hide location if blocked

    // Puce « origine → ville actuelle » (§10c), à partir des villes brutes.
    final originCity = profile.originCity?.trim();
    final currentCity = isBlocked ? null : profile.currentCity?.trim();
    final journeyTag = (originCity != null && originCity.isNotEmpty)
        ? ((currentCity != null && currentCity.isNotEmpty)
            ? '$originCity → $currentCity'
            : originCity)
        : ((currentCity != null && currentCity.isNotEmpty)
            ? currentCity
            : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Check if we can pop
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          // Deep linked - navigate to home instead
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.backgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: AppIcon(
                    AppIcon.arrowBack,
                    color: context.textPrimaryColor,
                  ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              actions: [
                if (profile.displayName != l10n.deletedUser)
                  IconButton(
                    icon: AppIcon(
                        AppIcon.share,
                        color: context.textPrimaryColor,
                      ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ShareProfileDialog.show(
                        context,
                        userName: profile.displayName,
                        userPhotoUrl: profile.photoUrl,
                        userId: profile.id,
                      );
                    },
                  ),
                if (!_isCurrentUser && profile.displayName != l10n.deletedUser)
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'block') {
                        _blockUser(profile);
                      } else if (value == 'report') {
                        ReportContentModal.show(
                          context,
                          targetType: ReportTargetType.user,
                          targetId: profile.id,
                          targetName: profile.displayName,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.flag, color: Colors.orange),
                            const SizedBox(width: 12),
                            Text(
                              'Signaler',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            const SizedBox(width: 12),
                            Text(
                              'Bloquer l\'utilisateur',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identité alignée à gauche (§10c) : l'avatar quitte
                    // la bannière-héros et vient se poser à côté du nom, du
                    // statut et des puces — même gabarit que « Mon profil ».
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (profile.photoUrl != null) {
                              HapticFeedback.mediumImpact();
                              FullScreenImageViewer.show(
                                context,
                                imageUrl: profile.photoUrl!,
                                heroTag: 'profile_view_avatar_${profile.id}',
                                senderName: profile.displayName,
                                showActions: false,
                              );
                            }
                          },
                          child: Hero(
                            tag: 'profile_view_avatar_${profile.id}',
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: context.surfaceVariantColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: context.borderColor,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  profile.photoUrl != null
                                      ? Image.network(
                                        profile.photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                _buildProfileInitials(
                                                  context,
                                                  profile.displayName,
                                                ),
                                      )
                                      : _buildProfileInitials(
                                        context,
                                        profile.displayName,
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DesignTitle(
                                profile.displayName?.isNotEmpty == true
                                    ? profile.displayName!
                                    : 'Nouvel utilisateur',
                                size: 22,
                              ),

                              // Poignée publique @handle (§10c)
                              if (profile.handle != null &&
                                  profile.handle!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '@${profile.handle}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.adaptivePrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],

                              // Statut en ligne (masqué si bloqué)
                              if (!isBlocked) ...[
                                const SizedBox(height: 6),
                                OnlineStatusIndicator(
                                  userId: profile.id,
                                  showText: true,
                                  dotSize: 9,
                                ),
                              ],

                              // Puces du §10c : trajet migratoire et métier
                              // remplacent les lignes à pictogramme centrées.
                              if (journeyTag != null ||
                                  (profile.profession?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (journeyTag != null)
                                      DesignTag(journeyTag),
                                    if (profile.profession?.isNotEmpty ?? false)
                                      DesignTag(profile.profession!),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Groupes en commun (§10c)
                    if (!isBlocked) _buildCommonGroups(context, profile.id),

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
                        profile.bio?.isNotEmpty == true
                            ? profile.bio!
                            : l10n.profileNoBio,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              profile.bio?.isNotEmpty == true
                                  ? context.textSecondaryColor
                                  : context.textTertiaryColor,
                          height: 1.5,
                          fontStyle:
                              profile.bio?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Médias partagés (si conversation existante)
                    _buildMediaSection(context, ref),

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
                    profile.skills.isNotEmpty
                        ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              profile.skills
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
                          l10n.profileNoSkillsAdded,
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
                    profile.interests.isNotEmpty
                        ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              profile.interests
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
                          l10n.profileNoInterestsAdded,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    const SizedBox(height: 16),

                    // Langues
                    if (profile.languages.isNotEmpty) ...[
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
                            profile.languages
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
                              activeThumbColor: context.adaptivePrimaryColor,
                              onChanged: _toggleBackgroundLocation,
                            ),
                            Divider(
                              height: 1,
                              color: context.outlineColor.withValues(
                                alpha: 0.1,
                              ),
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
                                      activeThumbColor: context.adaptivePrimaryColor,
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
                                                  l10n.profileUpdateError(e.toString()),
                                                ),
                                                backgroundColor:
                                                    AppColors.error,
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
        bottomNavigationBar: _isCurrentUser
            ? null
            : Consumer(
          builder: (context, ref, child) {
            final status = ref.watch(friendshipStatusProvider(widget.userId));

            // Determine button configuration based on friendship status
            String buttonText = '';
            Widget buttonIcon = const Icon(Icons.help_outline);
            VoidCallback? onPressed;
            Color backgroundColor = context.adaptivePrimaryColor;

            switch (status) {
              case FriendshipStatus.friends:
                buttonText = l10n.sendMessage;
                buttonIcon = const AppIcon(AppIcon.chatBubble);
                onPressed = _startConversation;
                backgroundColor = context.adaptivePrimaryColor;
                break;

              case FriendshipStatus.pendingSent:
                // Return a button to cancel the sent request
                return Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow:
                        context.isDarkMode
                            ? null
                            : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // Find the sent request and cancel it
                        final requests = await ref.read(
                          sentFriendRequestsProvider.future,
                        );

                        final request = requests.firstWhere(
                          (r) => r.receiverId == widget.userId,
                        );

                        // Cancel the request
                        final success = await ref
                            .read(friendRequestNotifierProvider.notifier)
                            .cancelRequest(
                              request.id,
                              receiverId: widget.userId,
                            );

                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.profileRequestCancelled),
                            ),
                          );
                        }
                      } on StateError {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.profileRequestNotExist),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: const AppIcon(AppIcon.close),
                    label: Text(l10n.cancelRequest),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                );

              case FriendshipStatus.pendingReceived:
                // Return two buttons side-by-side for pendingReceived
                return Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow:
                        context.isDarkMode
                            ? null
                            : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              // Find the request and decline it
                              final requests = await ref.read(
                                receivedFriendRequestsProvider.future,
                              );

                              final request = requests.firstWhere(
                                (r) => r.senderId == widget.userId,
                              );

                              // Decline the request
                              final success = await ref
                                  .read(friendRequestNotifierProvider.notifier)
                                  .declineRequest(
                                    request.id,
                                    senderId: widget.userId,
                                  );

                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.profileRequestDeclined),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } on StateError {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.profileRequestNotExist,
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const AppIcon(AppIcon.close),
                          label: const Text('Refuser'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              // Find the request and accept it
                              final requests = await ref.read(
                                receivedFriendRequestsProvider.future,
                              );

                              final request = requests.firstWhere(
                                (r) => r.senderId == widget.userId,
                              );

                              // Accept the request
                              final success = await ref
                                  .read(friendRequestNotifierProvider.notifier)
                                  .acceptRequest(
                                    request.id,
                                    senderId: widget.userId,
                                  );

                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.profileRequestAccepted),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } on StateError {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.profileRequestGoneDetail,
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.profileAcceptError(e.toString()),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const AppIcon(AppIcon.check),
                          label: const Text('Accepter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.successColor,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

              case FriendshipStatus.none:
                buttonText = l10n.profileSendFriendRequest;
                buttonIcon = const AppIcon(AppIcon.personAdd);
                onPressed = _isSendingRequest ? null : _sendFriendRequest;
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
                boxShadow:
                    context.isDarkMode
                        ? null
                        : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
              ),
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: _isSendingRequest
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : buttonIcon,
                label: Text(_isSendingRequest ? l10n.adminSending : buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            );
          },
        ),
      ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }
}
