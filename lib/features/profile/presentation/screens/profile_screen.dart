import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../feed/presentation/screens/my_posts_screen.dart'
    show userPostsCountProvider;
import '../../../feed/presentation/screens/saved_posts_screen.dart'
    show bookmarkedPostsCountProvider;
import '../../../settings/data/models/chat_background_model.dart';
import '../../../settings/domain/entities/chat_background_entity.dart';
import '../../../settings/presentation/widgets/blocked_users_modal.dart';
import '../../../settings/presentation/widgets/bug_report_dialog.dart';
import '../providers/profile_provider.dart';
import '../widgets/share_profile_modal.dart';
import '../../../messages/presentation/widgets/chat_background_picker_modal.dart';
import '../../../messages/presentation/widgets/full_screen_image_viewer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _profileVisible = true;
  bool _noiseSuppressionEnabled = true;
  ChatBackgroundEntity? _globalBackground;
  bool _headerCollapsed = false;
  bool _completionDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _noiseSuppressionEnabled =
        PreferencesService.instance.noiseSuppressionEnabled;
    _loadGlobalBackground();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _animationController.forward();
    });
  }

  Future<void> _loadGlobalBackground() async {
    try {
      final bgJson = PreferencesService.instance.defaultChatBackground;
      if (bgJson != null && bgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(bgJson));
        if (mounted) {
          setState(() => _globalBackground = model.toEntity());
        }
      }
    } catch (_) {
      // Ignore : fond par défaut conservé.
    }
  }

  Future<void> _showGlobalBackgroundPicker() async {
    HapticFeedback.lightImpact();
    final result = await ChatBackgroundPickerModal.show(
      context,
      currentBackground: _globalBackground,
    );
    if (result != null && mounted) {
      setState(() => _globalBackground = result);
    }
  }

  String _backgroundSubtitle(AppLocalizations l10n) {
    final bg = _globalBackground;
    if (bg == null || bg.isDefault) return l10n.defaultTheme;
    if (bg.isColor) return 'Couleur personnalisée';
    return 'Image personnalisée';
  }

  void _toggleNoiseSuppression(bool value) {
    HapticFeedback.lightImpact();
    setState(() => _noiseSuppressionEnabled = value);
    PreferencesService.instance.setNoiseSuppressionEnabled(value);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser != null) {
      // Auto-load handled by provider
      _loadSettings();
    }
  }

  void _loadSettings() {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user != null) {
      final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
      if (profile != null) {
        setState(() {
          _notificationsEnabled = profile.notificationsEnabled;
          _locationEnabled = profile.shareLocation;
          _profileVisible = profile.isVisible;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            final expanded = context.responsive(mobile: 180.0, tablet: 220.0);
            final collapsed = n.metrics.pixels > (expanded - kToolbarHeight);
            if (collapsed != _headerCollapsed) {
              setState(() => _headerCollapsed = collapsed);
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header avec design moderne
              SliverAppBar(
                expandedHeight: context.responsive(
                  mobile: 180.0,
                  tablet: 220.0,
                ),
                pinned: true,
                stretch: true,
                backgroundColor: context.adaptivePrimaryColor,
                automaticallyImplyLeading: false,
                title:
                    _headerCollapsed ? _buildCollapsedHeaderTitle(user) : null,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: _buildHeader(user, l10n),
                ),
              ),

              // Statistiques
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              context.isTablet
                                  ? AppSpacing.tabletMaxContentWidth + 100
                                  : double.infinity,
                        ),
                        child: _buildStatsCard(l10n),
                      ),
                    ),
                  ),
                ),
              ),

              // Bandeau « profil incomplet » (§11f)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          context.isTablet
                              ? AppSpacing.tabletMaxContentWidth
                              : double.infinity,
                    ),
                    child: _buildCompletionBanner(user, l10n),
                  ),
                ),
              ),

              // Contenu avec animations - centré sur tablette
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.responsive(mobile: 20.0, tablet: 32.0),
                  0,
                  context.responsive(mobile: 20.0, tablet: 32.0),
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            context.isTablet
                                ? AppSpacing.tabletMaxContentWidth
                                : double.infinity,
                      ),
                      child: _buildProfileContent(l10n),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Titre compact affiché dans la SliverAppBar une fois l'en-tête replié :
  /// petit avatar + nom, façon barre pinned (comme l'onglet Groupes).
  Widget _buildCollapsedHeaderTitle(dynamic user) {
    final profile =
        user != null
            ? ref.watch(profileNotifierProvider(user.id)).valueOrNull
            : null;
    final displayName = profile?.displayName ?? user?.displayName;
    final photoUrl = profile?.photoUrl ?? user?.photoUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.2),
            border: Border.all(color: AppColors.white, width: 1.5),
            image:
                photoUrl != null
                    ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                    : null,
          ),
          child:
              photoUrl == null
                  ? Center(
                    child: Text(
                      _getInitials(displayName ?? 'U'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  )
                  : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            displayName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent(AppLocalizations l10n) {
    return Column(
      children: [
        // Section Compte
        _buildAnimatedSection(
          delay: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                l10n.account,
                const Icon(Icons.person_outline),
              ),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: const Icon(Icons.edit_outlined),
                    title: l10n.editProfile,
                    subtitle: l10n.modifyYourInfo,
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.article_outlined),
                    title: l10n.myPostsTitle,
                    subtitle:
                        '${ref.watch(userPostsCountProvider).valueOrNull ?? 0} ${l10n.posts}',
                    onTap: () => context.push('/profile/my-posts'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.bookmark_outline),
                    title: l10n.savedPostsTitle,
                    subtitle:
                        '${ref.watch(bookmarkedPostsCountProvider).valueOrNull ?? 0} ${l10n.savedPostsCountLabel}',
                    onTap: () => context.push('/profile/saved-posts'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.people_outline),
                    title: l10n.myFriends,
                    subtitle: l10n.manageConnections,
                    onTap: () => context.push('/friends'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.people_alt_outlined),
                    title: l10n.myFollowsTitle,
                    subtitle: l10n.myFollowsSubtitle,
                    onTap: () => context.push('/profile/follows'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.share_outlined),
                    title: l10n.shareMyProfile,
                    subtitle: l10n.qrCodeAndShareLink,
                    onTap: () => _showShareProfileModal(),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.notifications_outlined),
                    title: l10n.notifications,
                    subtitle: l10n.manageAlerts,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Réglages condensés en 3 entrées repliables avec leur état en
        // sous-titre (refonte 10a : 7 sections → 3).
        _buildAnimatedSection(
          delay: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Confidentialité et sécurité
              _buildSettingsGroup(
                icon: Icons.shield_outlined,
                title: l10n.settingsPrivacySecurity,
                subtitle: () {
                  final on = <String>[
                    if (_profileVisible) l10n.visibleProfile,
                    if (_locationEnabled) l10n.myLocation,
                  ];
                  return on.isEmpty ? l10n.privacy : on.join(' · ');
                }(),
                children: [
                  _SettingsSwitchTile(
                    icon: const Icon(Icons.visibility_outlined),
                    title: l10n.visibleProfile,
                    subtitle: l10n.appearInSearchesDesc,
                    value: _profileVisible,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      setState(() => _profileVisible = value);
                      _saveSettingsToProfile();
                    },
                  ),
                  const _SettingsDivider(),
                  _SettingsSwitchTile(
                    icon: const Icon(Icons.location_on_outlined),
                    title: l10n.myLocation,
                    subtitle: l10n.appearOnMapDesc,
                    value: _locationEnabled,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      setState(() => _locationEnabled = value);
                      _saveSettingsToProfile();
                    },
                  ),
                  const _SettingsDivider(),
                  _SettingsSwitchTile(
                    icon: const Icon(Icons.notifications_active_outlined),
                    title: l10n.pushNotifications,
                    subtitle: l10n.receiveNotificationsDesc,
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      setState(() => _notificationsEnabled = value);
                      _updateNotificationSettings(value);
                    },
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.lock_outline),
                    title: l10n.keyBackup,
                    subtitle: l10n.keyBackupSubtitle,
                    onTap: () => context.push('/settings/security/backup'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.devices_outlined),
                    title: l10n.connectedDevices,
                    subtitle: l10n.connectedDevicesSubtitle,
                    onTap: () => context.push('/settings/security/devices'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.block_outlined),
                    title: l10n.blockedUsers,
                    onTap: () => _showBlockedUsers(),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.flag_outlined),
                    title: l10n.myReports,
                    subtitle: l10n.myReportsSubtitle,
                    onTap: () => context.push('/settings/my-reports'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 2. Apparence et langue
              _buildSettingsGroup(
                icon: Icons.tune_outlined,
                title: l10n.settingsAppearanceLanguage,
                subtitle:
                    '${_getThemeLabel(ref.watch(themeModeNotifierProvider), l10n)} · ${ref.watch(localeNotifierProvider.notifier).currentLocaleName}',
                children: [
                  _SettingsTile(
                    icon: const Icon(Icons.palette_outlined),
                    title: l10n.theme,
                    subtitle: _getThemeLabel(
                      ref.watch(themeModeNotifierProvider),
                      l10n,
                    ),
                    onTap: () => _showThemeSelector(l10n),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.translate_outlined),
                    title: l10n.language,
                    subtitle:
                        ref
                            .watch(localeNotifierProvider.notifier)
                            .currentLocaleName,
                    onTap: () => _showLanguageSelector(l10n),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.wallpaper_outlined),
                    title: l10n.chatBackground,
                    subtitle: _backgroundSubtitle(l10n),
                    onTap: () => _showGlobalBackgroundPicker(),
                  ),
                  const _SettingsDivider(),
                  _SettingsSwitchTile(
                    icon: const Icon(Icons.graphic_eq),
                    title: l10n.noiseSuppression,
                    subtitle: l10n.noiseSuppressionSubtitle,
                    value: _noiseSuppressionEnabled,
                    onChanged: _toggleNoiseSuppression,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 3. Aide et à propos
              _buildSettingsGroup(
                icon: Icons.help_outline,
                title: l10n.settingsHelpAbout,
                subtitle: '${l10n.version} 1.2.0',
                children: [
                  _SettingsTile(
                    icon: const Icon(Icons.support_agent_outlined),
                    title: l10n.helpFaq,
                    onTap: () => _showHelpSupport(l10n),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.article_outlined),
                    title: l10n.termsOfService,
                    onTap: () => context.push('/settings/terms'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.privacy_tip_outlined),
                    title: l10n.privacyPolicy,
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.gavel_outlined),
                    title: l10n.codeOfConduct,
                    onTap: () => context.push('/settings/code-of-conduct'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.info_outline),
                    title: l10n.about,
                    subtitle: '${l10n.version} 1.2.0',
                    onTap: () => _showAbout(l10n),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Zone de danger
        _buildAnimatedSection(
          delay: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                l10n.dangerZone,
                const Icon(Icons.warning_amber_rounded),
                isWarning: true,
              ),
              _SettingsCard(
                isDanger: true,
                children: [
                  _SettingsTile(
                    icon: const Icon(Icons.logout_outlined),
                    title: l10n.logout,
                    iconColor: AppColors.warning,
                    titleColor: AppColors.warning,
                    onTap: () => _confirmLogout(l10n),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.delete_outline),
                    title: l10n.deleteAccount,
                    iconColor: AppColors.error,
                    titleColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(l10n),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(dynamic user, AppLocalizations l10n) {
    // Utiliser les données du profil si disponibles (car elles sont mises à jour)
    // Need user id to watch profile
    final profileAsync =
        user != null
            ? ref.watch(profileNotifierProvider(user.id))
            : const AsyncValue.data(null);
    final profile = profileAsync.valueOrNull;

    // Priorité aux données du profil, sinon fallback sur les données auth
    final displayName = profile?.displayName ?? user?.displayName;
    final photoUrl = profile?.photoUrl ?? user?.photoUrl;
    // Ligne « Ville, Pays » (l'e-mail disparaît de l'en-tête — refonte 10a).
    final locationParts = <String>[
      if (profile?.currentCity?.trim().isNotEmpty ?? false)
        profile!.currentCity!.trim(),
      if (profile?.currentCountry?.trim().isNotEmpty ?? false)
        profile!.currentCountry!.trim(),
    ];
    final locationLine = locationParts.join(', ');

    return Container(
      color: context.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar 84 rayon 28 + pastille appareil photo.
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (photoUrl != null) {
                    FullScreenImageViewer.show(
                      context,
                      imageUrl: photoUrl,
                      heroTag: 'profile_avatar',
                      senderName: displayName,
                    );
                  } else {
                    context.push('/profile/edit');
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  context.push('/profile/edit');
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: context.surfaceVariantColor,
                          border: Border.all(
                            color: context.borderColor,
                            width: 2,
                          ),
                          image: photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(photoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoUrl == null
                            ? Center(
                                child: Text(
                                  _getInitials(displayName ?? 'U'),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: context.adaptivePrimaryColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.backgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 14,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName ?? l10n.user,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile?.isVerified ?? false) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF1976D2),
                    ),
                  ],
                ],
              ),
              // Poignée publique @handle (§10c)
              if (profile?.handle != null &&
                  profile!.handle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '@${profile.handle}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.adaptivePrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (locationLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationLine,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bandeau « profil incomplet » (§11f) : progression n/5 + jusqu'à trois
  /// champs manquants nommés avec leur bénéfice, CTA « Compléter » + « Plus tard ».
  Widget _buildCompletionBanner(dynamic user, AppLocalizations l10n) {
    if (user == null || _completionDismissed) return const SizedBox.shrink();
    final profile = ref.watch(profileNotifierProvider(user.id)).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    // 5 champs de complétude, chacun avec son bénéfice.
    final fields = <({bool filled, String label, String benefit})>[
      (
        filled: (profile.photoUrl ?? '').trim().isNotEmpty,
        label: 'Photo de profil',
        benefit: 'Vous serez plus facilement reconnu',
      ),
      (
        filled: (profile.currentCity ?? '').trim().isNotEmpty,
        label: 'Ville actuelle',
        benefit: 'Vous apparaîtrez auprès des membres proches',
      ),
      (
        filled: (profile.profession ?? '').trim().isNotEmpty,
        label: 'Métier',
        benefit: 'Utile pour les mises en relation',
      ),
      (
        filled: profile.languages.isNotEmpty,
        label: 'Langues parlées',
        benefit: "Utile pour l'entraide et les démarches",
      ),
      (
        filled: (profile.bio ?? '').trim().isNotEmpty,
        label: 'Bio',
        benefit: 'Présentez-vous à la communauté',
      ),
    ];

    final filledCount = fields.where((f) => f.filled).length;
    final total = fields.length;
    if (filledCount >= total) return const SizedBox.shrink();

    final missing = fields.where((f) => !f.filled).take(3).toList();
    final accent = context.adaptivePrimaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: context.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Complétez votre profil',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
                Text(
                  '$filledCount/$total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: filledCount / total,
                minHeight: 6,
                backgroundColor: context.surfaceVariantColor,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 18,
                      color: context.textTertiaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          Text(
                            f.benefit,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/profile/edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: context.onPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Compléter mon profil'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _completionDismissed = true),
                  child: Text(
                    'Plus tard',
                    style: TextStyle(color: context.textSecondaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(AppLocalizations l10n) {
    // Get real-time counts from providers instead of static values
    final friendsAsync = ref.watch(friendsProvider);
    final userGroupsAsync = ref.watch(myGroupsNotifierProvider);
    final userEventsAsync = ref.watch(myEventsNotifierProvider);

    // Keep previous value during loading to avoid flickering to 0
    final connectionsCount = friendsAsync.when(
      data: (friends) => friends.length,
      loading: () => friendsAsync.valueOrNull?.length ?? 0,
      error: (_, __) => 0,
    );

    final groupsCount = userGroupsAsync.when(
      data: (groups) => groups.length,
      loading: () => userGroupsAsync.valueOrNull?.length ?? 0,
      error: (_, __) => 0,
    );

    final eventsCount = userEventsAsync.when(
      data: (events) => events.length,
      loading: () => userEventsAsync.valueOrNull?.length ?? 0,
      error: (_, __) => 0,
    );

    final postsAsync = ref.watch(userPostsCountProvider);
    final postsCount = postsAsync.when(
      data: (count) => count,
      loading: () => postsAsync.valueOrNull ?? 0,
      error: (_, __) => 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/friends');
            },
            child: _AnimatedProfileStat(
              value: connectionsCount.toString(),
              label: l10n.connections,
              icon: Icons.people_outline,
              color: context.adaptivePrimaryColor,
            ),
          ),
          _buildStatDivider(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/groups');
            },
            child: _AnimatedProfileStat(
              value: groupsCount.toString(),
              label: l10n.groupsTitle,
              icon: Icons.group_work_outlined,
              color: context.adaptiveSecondaryColor,
            ),
          ),
          _buildStatDivider(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/events');
            },
            child: _AnimatedProfileStat(
              value: eventsCount.toString(),
              label: l10n.eventsTitle,
              icon: Icons.event_outlined,
              color: AppColors.info,
            ),
          ),
          _buildStatDivider(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/profile/my-posts');
            },
            child: _AnimatedProfileStat(
              value: postsCount.toString(),
              label: l10n.posts,
              icon: Icons.article_outlined,
              color: context.adaptiveSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 45,
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }

  Widget _buildAnimatedSection({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (delay * 100)),
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

  /// Entrée de réglages repliable (refonte 10a) : une carte + ExpansionTile,
  /// titre + état en sous-titre, révélant les réglages détaillés au tap.
  Widget _buildSettingsGroup({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return _SettingsCard(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, color: context.adaptivePrimaryColor),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: context.textSecondaryColor,
              ),
            ),
            childrenPadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    Widget icon, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isWarning
                      ? context.warningColor
                      : context.adaptivePrimaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 16,
              height: 16,
              child: FittedBox(
                fit: BoxFit.contain,
                child: IconTheme.merge(
                  data: IconThemeData(
                    color:
                        isWarning
                            ? context.warningColor
                            : context.adaptivePrimaryColor,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  isWarning ? context.warningColor : context.textTertiaryColor,
              letterSpacing: 1.2,
            ),
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

  void _updateNotificationSettings(bool enabled) async {
    if (enabled) {
      await NotificationService().subscribeToTopic('general');
    } else {
      await NotificationService().unsubscribeFromTopic('general');
    }
    _saveSettingsToProfile();
  }

  Future<void> _saveSettingsToProfile() async {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user == null) return;

    final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
    if (profile == null) return;

    final updatedProfile = profile.copyWith(
      notificationsEnabled: _notificationsEnabled,
      shareLocation: _locationEnabled,
      isVisible: _profileVisible,
    );

    await ref
        .read(profileNotifierProvider(user.id).notifier)
        .updateProfile(updatedProfile);
  }

  void _showBlockedUsers() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const BlockedUsersModal(),
    );
  }

  void _showShareProfileModal() {
    HapticFeedback.lightImpact();
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final profile =
        currentUser != null
            ? ref.read(profileNotifierProvider(currentUser.id)).valueOrNull
            : null;

    ShareProfileModal.show(
      context,
      userName: profile?.displayName ?? currentUser?.displayName,
      userPhotoUrl: profile?.photoUrl ?? currentUser?.photoUrl,
      userId: profile?.id ?? currentUser?.id,
    );
  }

  String _getThemeLabel(AppThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case AppThemeMode.light:
        return l10n.light;
      case AppThemeMode.dark:
        return l10n.dark;
      case AppThemeMode.system:
        return l10n.system;
    }
  }

  void _showThemeSelector(AppLocalizations l10n) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Consumer(
            builder: (context, ref, _) {
              final currentMode = ref.watch(themeModeNotifierProvider);
              final currentColor = ref.watch(themeColorNotifierProvider);

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.theme,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mode Section
                    Text(
                      'Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      context,
                      l10n.light,
                      AppThemeMode.light,
                      currentMode,
                      Icons.wb_sunny_outlined,
                    ),
                    _buildThemeOption(
                      context,
                      l10n.dark,
                      AppThemeMode.dark,
                      currentMode,
                      Icons.nightlight_round_outlined,
                    ),
                    _buildThemeOption(
                      context,
                      l10n.system,
                      AppThemeMode.system,
                      currentMode,
                      Icons.brightness_auto_outlined,
                    ),

                    // Color Section (Only visible if not strictly Dark mode)
                    if (currentMode != AppThemeMode.dark) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Apparence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textTertiaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeColorOption(
                        'Vert (Défaut)',
                        AppThemeColor.green,
                        currentColor == AppThemeColor.green,
                      ),
                      _buildThemeColorOption(
                        'Orange (Classique)',
                        AppThemeColor.orange,
                        currentColor == AppThemeColor.orange,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    AppThemeMode value,
    AppThemeMode groupValue,
    IconData icon,
  ) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSelected ? context.adaptivePrimaryColor : context.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              isSelected
                  ? context.adaptivePrimaryColor
                  : context.textSecondaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.textPrimaryColor,
          ),
        ),
        trailing:
            isSelected
                ? Icon(Icons.check_circle, color: context.adaptivePrimaryColor)
                : null,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeNotifierProvider.notifier).setThemeMode(value);
        },
      ),
    );
  }

  Widget _buildThemeColorOption(
    String title,
    AppThemeColor color,
    bool isSelected,
  ) {
    // Determine the color to show in the circle
    final Color previewColor =
        color == AppThemeColor.green
            ? AppColors
                .secondary // Green
            : AppColors.primary; // Orange

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor:
          isSelected
              ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
              : null,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: previewColor,
          shape: BoxShape.circle,
          border: Border.all(color: context.borderColor),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color:
              isSelected
                  ? context.adaptivePrimaryColor
                  : context.textPrimaryColor,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: context.adaptivePrimaryColor)
              : null,
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(themeColorNotifierProvider.notifier).setThemeColor(color);
      },
    );
  }

  void _showLanguageSelector(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    final currentLocale = ref.read(localeNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
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
                        color: ctx.adaptivePrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.translate,
                        color: ctx.adaptivePrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.chooseLanguage,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ctx.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLanguageOption(
                  ctx,
                  l10n.french,
                  'FR',
                  const Locale('fr'),
                  currentLocale.languageCode == 'fr',
                ),
                _buildLanguageOption(
                  ctx,
                  l10n.english,
                  'EN',
                  const Locale('en'),
                  currentLocale.languageCode == 'en',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx,
    String language,
    String code,
    Locale locale,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? ctx.adaptivePrimaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? ctx.adaptivePrimaryColor : ctx.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isSelected ? ctx.adaptivePrimaryColor : ctx.surfaceVariantColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.white : ctx.textSecondaryColor,
              ),
            ),
          ),
        ),
        title: Text(
          language,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? ctx.adaptivePrimaryColor : ctx.textPrimaryColor,
          ),
        ),
        trailing:
            isSelected
                ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ctx.adaptivePrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.white,
                    size: 16,
                  ),
                )
                : null,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(localeNotifierProvider.notifier).setLocale(locale);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showHelpSupport(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    final supportService = SupportService();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ctx.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
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
                          color: ctx.adaptiveSecondaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.support_agent,
                          color: ctx.adaptiveSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.helpAndSupport,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ctx.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // FAQ en accordéon, première réponse dépliée (§21d).
                  Theme(
                    data: Theme.of(ctx).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        _FaqItem(
                          question: l10n.faqEncryptionQ,
                          answer: l10n.faqEncryptionA,
                          initiallyExpanded: true,
                        ),
                        _FaqItem(
                          question: l10n.faqLocationQ,
                          answer: l10n.faqLocationA,
                        ),
                        _FaqItem(
                          question: l10n.faqReportQ,
                          answer: l10n.faqReportA,
                        ),
                        _FaqItem(
                          question: l10n.faqTransferQ,
                          answer: l10n.faqTransferA,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.email_outlined,
                    title: l10n.contactUs,
                    subtitle: l10n.supportEmail,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await supportService.sendContactEmail();
                    },
                  ),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.bug_report_outlined,
                    title: l10n.reportBug,
                    subtitle: l10n.helpUsImprove,
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        builder: (context) => const BugReportDialog(),
                      );
                    },
                  ),
                  _HelpOption(
                    ctx: ctx,
                    icon: Icons.star_outline,
                    title: l10n.giveFeedback,
                    subtitle: l10n.rateUsOnStore,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await supportService.openStoreForReview();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }

  void _showAbout(AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: context.adaptivePrimaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people,
                    color: AppColors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${l10n.version} 1.2.0',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.mobileAppDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.allRightsReserved,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _confirmLogout(AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Text(l10n.logout),
              ],
            ),
            content: Text(l10n.confirmLogout),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final router = GoRouter.of(context);
                  navigator.pop();
                  final currentUser =
                      ref.read(currentUserAsyncProvider).valueOrNull;
                  if (currentUser != null) {
                    await NotificationService().removeTokenForUser(
                      currentUser.id,
                    );
                  }
                  await ref.read(authNotifierProvider.notifier).signOut();
                  router.go('/auth/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.logout),
              ),
            ],
          ),
    );
  }

  void _confirmDeleteAccount(AppLocalizations l10n) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.deleteAccountTitle),
              ],
            ),
            content: Text(l10n.deleteAccountWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFinalDeleteConfirmation(l10n);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
    );
  }

  void _showFinalDeleteConfirmation(AppLocalizations l10n) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(l10n.finalConfirmation),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.typeDeleteToConfirm),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmController,
                      decoration: InputDecoration(
                        hintText: l10n.deleteKeyword,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      confirmController.dispose();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        confirmController.text == l10n.deleteKeyword
                            ? () async {
                              Navigator.pop(context);
                              await _deleteAccount(l10n);
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.deletePermanently),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _deleteAccount(AppLocalizations l10n) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.deletingAccount)),
              ],
            ),
          ),
    );

    try {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser != null) {
        await NotificationService().removeTokenForUser(currentUser.id);
      }

      final success =
          await ref.read(authNotifierProvider.notifier).deleteAccount();

      if (!mounted) return;
      Navigator.pop(context);

      // Check if reauthentication is required
      final authState = ref.read(authNotifierProvider);
      final errorMessage = authState.maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

      if (errorMessage != null && errorMessage.startsWith('REAUTH_REQUIRED:')) {
        // Extract the actual error message
        final actualMessage = errorMessage.substring('REAUTH_REQUIRED:'.length);

        // Show password prompt
        await _showPasswordPromptForDeletion(l10n, actualMessage);
        return;
      }

      if (success) {
        GoRouter.of(context).go('/auth/login');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white),
                const SizedBox(width: 12),
                Text(l10n.accountDeletedSuccess),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: AppColors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(errorMessage ?? l10n.errorDeletingAccount),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showPasswordPromptForDeletion(
    AppLocalizations l10n,
    String message,
  ) async {
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: context.warningColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.confirmPassword,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        hintText: l10n.confirmPasswordRequired,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.adaptivePrimaryColor,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (passwordController.text.isNotEmpty) {
                          _handlePasswordSubmit(passwordController.text, l10n);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      passwordController.dispose();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        passwordController.text.isEmpty
                            ? null
                            : () {
                              _handlePasswordSubmit(
                                passwordController.text,
                                l10n,
                              );
                              passwordController.dispose();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _handlePasswordSubmit(
    String password,
    AppLocalizations l10n,
  ) async {
    Navigator.pop(context); // Close password dialog first

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.deletingAccount)),
              ],
            ),
          ),
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .reauthenticateAndDelete(password);

    if (!mounted) return;

    Navigator.pop(context); // Close loading dialog

    if (success) {
      GoRouter.of(context).go('/auth/login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.white),
              const SizedBox(width: 12),
              Text(l10n.accountDeletedSuccess),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      final authState = ref.read(authNotifierProvider);
      final errorMessage = authState.maybeWhen(
        error: (msg) => msg,
        orElse: () => l10n.errorDeletingAccount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: AppColors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// Widgets réutilisables améliorés

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDanger;

  const _SettingsCard({required this.children, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            isDanger
                ? Border.all(color: AppColors.error.withValues(alpha: 0.2))
                : null,
        boxShadow: [
          BoxShadow(
            color: (isDanger ? AppColors.error : Colors.black).withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (iconColor ?? context.adaptivePrimaryColor).withValues(
                        alpha: 0.15,
                      ),
                      (iconColor ?? context.adaptivePrimaryColor).withValues(
                        alpha: 0.05,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: 18,
                      color: iconColor ?? context.adaptivePrimaryColor,
                    ),
                    child: icon,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? context.textPrimaryColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: context.textTertiaryColor,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor)
                      .withValues(alpha: 0.15),
                  (value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor)
                      .withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 18,
                  color:
                      value
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor,
                ),
                child: icon,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.adaptivePrimaryColor,
            activeTrackColor: context.adaptivePrimaryColor.withValues(
              alpha: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        color: context.borderColor.withValues(alpha: 0.5),
      ),
    );
  }
}

class _AnimatedProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _AnimatedProfileStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Entrée de FAQ en accordéon (§21d).
class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;
  final bool initiallyExpanded;

  const _FaqItem({
    required this.question,
    required this.answer,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: context.textPrimaryColor,
        ),
      ),
      iconColor: context.adaptivePrimaryColor,
      collapsedIconColor: context.textTertiaryColor,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpOption extends StatelessWidget {
  final BuildContext ctx;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpOption({
    required this.ctx,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ctx.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ctx.adaptiveSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ctx.adaptiveSecondaryColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ctx.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: ctx.textSecondaryColor),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: ctx.textTertiaryColor,
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}
