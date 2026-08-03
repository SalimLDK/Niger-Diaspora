import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter/services.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../feed/presentation/screens/my_posts_screen.dart'
    show userPostsCountProvider;
import '../../../feed/presentation/screens/saved_posts_screen.dart'
    show bookmarkedPostsCountProvider;
import '../providers/profile_provider.dart';
import '../widgets/share_profile_modal.dart';
import '../../../messages/presentation/widgets/full_screen_image_viewer.dart';
import '../../../../core/services/app_version_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  /// Version de l'app, lue sur le paquet installé plutôt qu'écrite en dur.
  String _versionLabel(AppLocalizations l10n) {
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    return version.isEmpty ? l10n.version : '${l10n.version} $version';
  }

  bool _locationEnabled = true;
  bool _profileVisible = true;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _animationController.forward();
    });
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
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // En-tête plat (§10a) : le hero repliable disparaît, le titre
              // et les deux actions carrées défilent avec le contenu.
              SliverToBoxAdapter(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DesignScreenHeader(
                        title: l10n.myProfile,
                        actions: [
                          DesignSquareAction(
                            icon: Icons.qr_code_2,
                            tooltip: l10n.shareMyProfile,
                            onPressed: () => context.push('/profile/share'),
                          ),
                          DesignSquareAction(
                            icon: Icons.settings_outlined,
                            tooltip: l10n.settings,
                            onPressed: () => context.push('/settings'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildHeader(user, l10n),
                    ],
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
                  // CallHistoryScreen était injoignable : la route existait,
                  // mais aucun écran n'y renvoyait.
                  _SettingsTile(
                    icon: const Icon(Icons.call_outlined),
                    title: l10n.callHistoryTitle,
                    subtitle: l10n.callHistorySubtitle,
                    onTap: () => context.push('/calls/history'),
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

        // Réglages condensés en 3 entrées avec leur état en sous-titre
        // (refonte 10a : 7 sections → 3), renvoyant vers l'écran dédié §10b.
        _buildAnimatedSection(
          delay: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                l10n.settings,
                const Icon(Icons.settings_outlined),
              ),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: const Icon(Icons.shield_outlined),
                    title: l10n.settingsPrivacySecurity,
                    subtitle: () {
                      final on = <String>[
                        if (_profileVisible) l10n.visibleProfile,
                        if (_locationEnabled) l10n.myLocation,
                      ];
                      return on.isEmpty ? l10n.privacy : on.join(' · ');
                    }(),
                    onTap: () => context.push('/settings'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.tune_outlined),
                    title: l10n.settingsAppearanceLanguage,
                    subtitle:
                        '${_getThemeLabel(ref.watch(themeModeNotifierProvider), l10n)} · ${ref.watch(localeNotifierProvider.notifier).currentLocaleName}',
                    onTap: () => context.push('/settings'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: const Icon(Icons.help_outline),
                    title: l10n.settingsHelpAbout,
                    subtitle: _versionLabel(l10n),
                    onTap: () => context.push('/settings'),
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

    // Puces du §10a : le trajet « origine → ville actuelle » et le métier.
    final origin = profile?.originCity?.trim();
    final currentCity = profile?.currentCity?.trim();
    final originChip = (origin != null && origin.isNotEmpty)
        ? (currentCity != null && currentCity.isNotEmpty
            ? '$origin → $currentCity'
            : origin)
        : null;
    final professionRaw = profile?.profession?.trim();
    final professionChip =
        (professionRaw != null && professionRaw.isNotEmpty)
            ? professionRaw
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar 76 rayon 24 + pastille appareil photo (§10a : l'identité
          // est alignée à gauche, plus centrée sous un bandeau).
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
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: context.surfaceVariantColor,
                      border: Border.all(color: context.borderColor, width: 2),
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
                                fontSize: 26,
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
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.backgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: context.onPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: DesignTitle(displayName ?? l10n.user, size: 22),
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
                if (profile?.handle != null && profile!.handle!.isNotEmpty) ...[
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
                if (locationLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    locationLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
                // Puces « origine → ville » et métier (§10a).
                if (originChip != null || professionChip != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (originChip != null) _ProfileTag(label: originChip),
                      if (professionChip != null)
                        _ProfileTag(label: professionChip),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
        label: l10n.profilePhotoTitle,
        benefit: l10n.profileCompletionPhotoBenefit,
      ),
      (
        filled: (profile.currentCity ?? '').trim().isNotEmpty,
        label: 'Ville actuelle',
        benefit: l10n.profileCompletionCityBenefit,
      ),
      (
        filled: (profile.profession ?? '').trim().isNotEmpty,
        label: l10n.profileFieldOccupation,
        benefit: l10n.profileCompletionJobBenefit,
      ),
      (
        filled: profile.languages.isNotEmpty,
        label: l10n.spokenLanguages,
        benefit: "Utile pour l'entraide et les démarches",
      ),
      (
        filled: (profile.bio ?? '').trim().isNotEmpty,
        label: 'Bio',
        benefit: l10n.profileCompletionBioBenefit,
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
                    l10n.profileCompleteYours,
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
                    child: Text(l10n.profileCompleteMine),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _completionDismissed = true),
                  child: Text(
                    l10n.later,
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
              // AppColors.info est un bleu Material figé, absent de la palette
              // et insensible au thème. La rangée alterne terracotta et vert.
              color: context.adaptivePrimaryColor,
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
              label: l10n.profileStatPosts,
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
      color: context.borderColor.withValues(alpha: 0.5),
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

  /// Libellé de section (§10a) : petites capitales en chasse fixe. L'icône
  /// en pastille a disparu — les appels la passent encore, elle est ignorée.
  Widget _buildSectionHeader(String title, Widget icon) {
    return DesignSectionLabel(title);
  }


  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
}

// Widgets réutilisables améliorés

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return DesignListCard(children: children);
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
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
                      context.adaptivePrimaryColor.withValues(alpha: 0.15),
                      context.adaptivePrimaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: 18,
                      color: context.adaptivePrimaryColor,
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

/// Puce d'identité du profil (§10a) : alias de [DesignTag], pour que les
/// deux profils (le mien et celui d'un membre) partagent la même puce.
class _ProfileTag extends StatelessWidget {
  final String label;

  const _ProfileTag({required this.label});

  @override
  Widget build(BuildContext context) => DesignTag(label);
}
