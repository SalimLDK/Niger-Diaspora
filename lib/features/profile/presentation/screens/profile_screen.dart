import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter/services.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
                          // `/profile/share` n'a jamais été déclarée : c'est
                          // `/profile/:userId` qui l'attrapait, avec « share »
                          // pour identifiant — le bouton menait donc à
                          // « Profil supprimé · Ce compte n'existe plus ».
                          // Il ouvre désormais la même feuille que la ligne
                          // « Partager mon profil », qui, elle, fonctionne.
                          onPressed: () => _showShareProfileModal(),
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
              DesignSectionLabel(l10n.account),
              DesignSettingsCard(
                children: [
                  DesignSettingsTile(
                    icon: const Icon(Icons.edit_outlined),
                    title: l10n.editProfile,
                    subtitle: l10n.modifyYourInfo,
                    onTap: () => context.push('/profile/edit'),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.article_outlined),
                    title: l10n.myPostsTitle,
                    subtitle:
                        '${ref.watch(userPostsCountProvider).valueOrNull ?? 0} ${l10n.posts}',
                    onTap: () => context.push('/profile/my-posts'),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.bookmark_outline),
                    title: l10n.savedPostsTitle,
                    subtitle: l10n.savedPostsCount(
                      ref.watch(bookmarkedPostsCountProvider).valueOrNull ?? 0,
                    ),
                    onTap: () => context.push('/profile/saved-posts'),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.people_outline),
                    title: l10n.myFriends,
                    subtitle: l10n.manageConnections,
                    onTap: () => context.push('/friends'),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.people_alt_outlined),
                    title: l10n.myFollowsTitle,
                    subtitle: l10n.myFollowsSubtitle,
                    onTap: () => context.push('/profile/follows'),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.share_outlined),
                    title: l10n.shareMyProfile,
                    subtitle: l10n.qrCodeAndShareLink,
                    onTap: () => _showShareProfileModal(),
                  ),
                  // Appels 1-à-1 mis en pause (fiabilité en cours de
                  // vérification sur appareil réel — 2026-08-14) : entrée
                  // masquée avec les boutons d'appel, code conservé pour
                  // réactivation. Voir TESTS_APPAREIL_A_FAIRE.md.
                  // TODO(appels): réactiver après vérification à deux vrais
                  // téléphones.
                  // DesignSettingsTile(
                  //   icon: const Icon(Icons.call_outlined),
                  //   title: l10n.callHistoryTitle,
                  //   subtitle: l10n.callHistorySubtitle,
                  //   onTap: () => context.push('/calls/history'),
                  // ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.notifications_outlined),
                    // Cette ligne mène à la LISTE des notifications reçues,
                    // pas aux réglages. Elle s'appelait « Notifications »
                    // avec « Gérer les notifications » en sous-titre — soit
                    // exactement le libellé et la promesse de la ligne
                    // Notifications de l'écran Réglages, qui va ailleurs.
                    // Qui voulait couper ses alertes tombait sur son
                    // historique.
                    title: l10n.myNotifications,
                    subtitle: l10n.myNotificationsSubtitle,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Actions du compte (§10a) : elles vivaient au bas de l'écran
        // Réglages, alors qu'elles ne règlent rien — elles disposent du
        // compte. Elles prennent la place des trois raccourcis « Réglages »
        // qui n'étaient que des ancres vers un écran déjà atteignable par le
        // bouton d'engrenage de l'en-tête.
        _buildAnimatedSection(
          delay: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignSectionLabel(l10n.dangerZone, color: context.errorColor),
              DesignSettingsCard(
                isDanger: true,
                children: [
                  // Jetons adaptatifs et non `AppColors.warning`/`.error`
                  // bruts : ces deux-là sont les valeurs du thème clair, donc
                  // peu lisibles sur le fond du nocturne.
                  DesignSettingsTile(
                    icon: const Icon(Icons.logout_outlined),
                    title: l10n.logout,
                    iconColor: context.warningColor,
                    titleColor: context.warningColor,
                    onTap: () => _confirmLogout(l10n),
                  ),
                  DesignSettingsTile(
                    icon: const Icon(Icons.delete_outline),
                    title: l10n.deleteAccount,
                    iconColor: context.errorColor,
                    titleColor: context.errorColor,
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

    // Puces du §10a : le trajet « origine → ville actuelle » et le métier.
    final origin = profile?.originCity?.trim();
    final currentCity = profile?.currentCity?.trim();
    final originChip =
        (origin != null && origin.isNotEmpty)
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
                  // §11f : sans photo, l'emplacement se montre **vide**
                  // (contour pointillé, glyphe « ajouter une photo ») au lieu
                  // d'afficher des initiales qui ressemblent à un avatar
                  // déjà rempli. Rien n'invite à agir dans une case pleine.
                  child: DottedBorder(
                    active: photoUrl == null,
                    color: context.borderColor,
                    radius: 24,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: context.surfaceVariantColor,
                        border:
                            photoUrl != null
                                ? Border.all(
                                  color: context.borderColor,
                                  width: 2,
                                )
                                : null,
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
                              ? Icon(
                                Icons.add_a_photo_outlined,
                                size: 30,
                                color: context.textTertiaryColor,
                              )
                              : null,
                    ),
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
                      // Le bleu était figé sur le jeton clair (#1976D2), donc
                      // presque noyé en nocturne. `infoColor` donne le
                      // #60A5FA de la fiche 11d en sombre — et le glyphe
                      // `verified` laisse voir le fond au travers du chevron,
                      // ce qui produit le « check foncé » décrit.
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: context.infoColor,
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
                ] else ...[
                  // Sans pseudo, la ligne @ disparaît purement et simplement :
                  // rien n'indique qu'elle existe, ni comment s'en donner un.
                  // Neuf comptes sur onze n'en avaient aucun.
                  // L'appel prend la place exacte du @handle manquant et ouvre
                  // le formulaire **sur le champ** (`?focus=handle`).
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: () => context.push('/profile/edit?focus=handle'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alternate_email_rounded,
                            size: 14,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.handleChooseCta,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.adaptivePrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      // Fiche 11d : le trajet prend l'accent, le métier prend
                      // le vert. Les deux étaient gris, donc indistincts.
                      if (originChip != null)
                        _ProfileTag(
                          label: originChip,
                          tone: DesignTagTone.accent,
                        ),
                      if (professionChip != null)
                        _ProfileTag(
                          label: professionChip,
                          tone: DesignTagTone.success,
                        ),
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

  /// Bandeau « profil incomplet » (§11f) : progression n/5, les champs qui
  /// manquent avec un bouton « Ajouter » chacun, puis ceux déjà faits,
  /// atténués — la fiche les garde à l'écran plutôt que de les effacer, pour
  /// que la barre de progression ait un sens.
  Widget _buildCompletionBanner(dynamic user, AppLocalizations l10n) {
    if (user == null || _completionDismissed) return const SizedBox.shrink();
    final profile = ref.watch(profileNotifierProvider(user.id)).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    // 5 champs de complétude : libellé, bénéfice, glyphe teinté par nature,
    // et l'ancre qui ouvre 20a au bon endroit.
    final fields = <_CompletionField>[
      _CompletionField(
        filled: (profile.photoUrl ?? '').trim().isNotEmpty,
        label: l10n.profilePhotoTitle,
        benefit: l10n.profileCompletionPhotoBenefit,
        icon: Icons.photo_camera_outlined,
        tint: context.adaptivePrimaryColor,
        ancre: l10n.homeFieldPhoto,
      ),
      _CompletionField(
        filled: (profile.currentCity ?? '').trim().isNotEmpty,
        label: l10n.profileYourCurrentCity,
        benefit: l10n.profileCompletionCityBenefit,
        icon: Icons.location_on_outlined,
        tint: context.adaptivePrimaryColor,
        ancre: 'city',
      ),
      _CompletionField(
        filled: (profile.profession ?? '').trim().isNotEmpty,
        label: l10n.profileYourProfession,
        benefit: l10n.profileCompletionJobBenefit,
        icon: Icons.work_outline,
        tint: context.successColor,
        ancre: 'job',
      ),
      _CompletionField(
        filled: profile.languages.isNotEmpty,
        label: l10n.spokenLanguages,
        benefit: "Utile pour l'entraide et les démarches",
        icon: Icons.translate_outlined,
        tint: context.textSecondaryColor,
        ancre: 'languages',
      ),
      _CompletionField(
        filled: (profile.bio ?? '').trim().isNotEmpty,
        label: l10n.bio,
        benefit: l10n.profileCompletionBioBenefit,
        icon: Icons.notes_outlined,
        tint: context.textSecondaryColor,
        ancre: l10n.homeFieldBio,
      ),
    ];

    final faits = fields.where((f) => f.filled).toList();
    final total = fields.length;
    if (faits.length >= total) return const SizedBox.shrink();

    // Trois champs suffisent à faire basculer le profil : au-delà, la liste
    // devient un formulaire et non une invitation.
    final manquants = fields.where((f) => !f.filled).take(3).toList();
    final accent = context.adaptivePrimaryColor;
    final pourcent = (faits.length * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: context.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.profileCompletionPercent(pourcent),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${faits.length}/$total',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: faits.length / total,
                minHeight: 8,
                backgroundColor: context.surfaceVariantColor,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.profileCompletionPitch,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 14),
            for (final f in manquants)
              _CompletionRow(
                champ: f,
                actionLabel: l10n.profileCompletionAdd,
                onAdd: () => context.push('/profile/edit?focus=${f.ancre}'),
              ),
            if (faits.isNotEmpty) ...[
              const SizedBox(height: 2),
              for (final f in faits) _CompletionRow(champ: f),
            ],
            const SizedBox(height: 10),
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
                  // Le fond de la pastille est déjà adaptatif juste au-dessus :
                  // le glyphe restait sur le jeton clair, donc sombre sur
                  // sombre en nocturne.
                  child: Icon(Icons.logout, color: context.warningColor),
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
                  child: Icon(Icons.delete_forever, color: context.errorColor),
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
                        border: const OutlineInputBorder(),
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
                      disabledBackgroundColor: Colors.grey,
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

      final authState = ref.read(authNotifierProvider);
      final errorMessage = authState.maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

      if (errorMessage != null && errorMessage.startsWith('REAUTH_REQUIRED:')) {
        final actualMessage = errorMessage.substring('REAUTH_REQUIRED:'.length);
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
    Navigator.pop(context);

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

    Navigator.pop(context);

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
}

// Widgets réutilisables améliorés

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
  final DesignTagTone tone;

  const _ProfileTag({required this.label, this.tone = DesignTagTone.neutral});

  @override
  Widget build(BuildContext context) => DesignTag(label, tone: tone);
}

/// Un champ de la complétude du profil (§11f).
@immutable
class _CompletionField {
  final bool filled;
  final String label;
  final String benefit;
  final IconData icon;
  final Color tint;

  /// Ancre passée à 20a (`/profile/edit?focus=…`) pour ouvrir le formulaire
  /// sur le champ concerné plutôt qu'en haut de page.
  final String ancre;

  const _CompletionField({
    required this.filled,
    required this.label,
    required this.benefit,
    required this.icon,
    required this.tint,
    required this.ancre,
  });
}

/// Ligne du bandeau de complétude.
///
/// Sans [onAdd], la ligne est un champ **déjà rempli** : coche verte et
/// opacité réduite. La fiche 11f les garde à l'écran, reléguées sous les
/// lignes actionnables — les effacer laisserait une barre de progression qui
/// avance sans qu'on voie pourquoi.
class _CompletionRow extends StatelessWidget {
  final _CompletionField champ;
  final String? actionLabel;
  final VoidCallback? onAdd;

  const _CompletionRow({required this.champ, this.actionLabel, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fait = onAdd == null;

    return Opacity(
      opacity: fait ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              fait ? Icons.check_circle_rounded : champ.icon,
              size: 18,
              color: fait ? context.successColor : champ.tint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    champ.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  // Le bénéfice ne concerne que ce qu'il reste à faire :
                  // sur une ligne acquise, ce serait de la publicité tardive.
                  if (!fait)
                    Text(
                      champ.benefit,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            if (!fait) ...[
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    actionLabel ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.onPrimaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contour pointillé posé autour de [child] quand [active] est vrai.
///
/// Signale un emplacement **à remplir** (fiche 11f) : un contour plein dirait
/// « voici votre photo », un pointillé dit « il en manque une ».
class DottedBorder extends StatelessWidget {
  final bool active;
  final Color color;
  final double radius;
  final Widget child;

  const DottedBorder({
    super.key,
    required this.active,
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return CustomPaint(
      painter: _DottedPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DottedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final trace =
        Path()..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        );
    final crayon =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    // 5 px de trait, 4 px de vide, le long du contour arrondi.
    for (final segment in trace.computeMetrics()) {
      var depart = 0.0;
      while (depart < segment.length) {
        final fin = (depart + 5).clamp(0.0, segment.length);
        canvas.drawPath(segment.extractPath(depart, fin), crayon);
        depart = fin + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPainter old) =>
      old.color != color || old.radius != radius;
}
