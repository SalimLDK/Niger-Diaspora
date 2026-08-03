import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../../../core/theme/design_kit.dart';
import '../widgets/onboarding_page.dart';

/// Onboarding en cinq écrans (maquettes 14a → 14e).
///
/// Une promesse par écran, formulée du point de vue du membre, et les deux
/// autorisations regroupées sur le dernier écran avec leurs interrupteurs :
/// on ne déclenche plus les demandes système en aveugle, seules celles que
/// la personne laisse activées sont demandées.
class OnboardingIntroScreen extends ConsumerStatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  ConsumerState<OnboardingIntroScreen> createState() =>
      _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends ConsumerState<OnboardingIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Choix affichés sur le dernier écran, avant la demande système.
  bool _wantNotifications = true;
  bool _wantLocation = true;

  bool _requestingPermissions = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(name: 'onboarding_begin');
  }

  /// Nombre d'ecrans, constant : le contenu depend de la langue, pas le
  /// nombre de pages.
  static const int _pageCount = 5;

  List<OnboardingPageData> _buildPages(AppLocalizations l10n) => [
    OnboardingPageData(
      eyebrow: l10n.onbCitiesEyebrow,
      title: l10n.onbWelcomeTitle,
      description: l10n.onbWelcomeBody,
      illustrationCaption: l10n.onbWelcomeIllustration,
      brandMark: true,
    ),
    OnboardingPageData(
      title: l10n.onbMembersTitle,
      description: l10n.onbMembersBody,
      illustrationCaption: l10n.onbMembersIllustration,
      icon: Icons.people_outline,
      bullets: [l10n.onbMembersBullet1, l10n.onbMembersBullet2],
    ),
    OnboardingPageData(
      title: l10n.onbGroupsTitle,
      description: l10n.onbGroupsBody,
      illustrationCaption: l10n.onbGroupsIllustration,
      icon: Icons.groups_outlined,
      bullets: [l10n.onbGroupsBullet1, l10n.onbGroupsBullet2],
    ),
    OnboardingPageData(
      title: l10n.onbEventsTitle,
      description: l10n.onbEventsBody,
      illustrationCaption: l10n.onbEventsIllustration,
      icon: Icons.event_outlined,
      bullets: [l10n.onbEventsBullet1, l10n.onbEventsBullet2],
    ),
    OnboardingPageData(
      title: l10n.onbConnectedTitle,
      description: l10n.onbConnectedBody,
      illustrationCaption: l10n.onbConnectedIllustration,
      icon: Icons.chat_bubble_outline,
    ),
  ];

  bool get _isLastPage => _currentPage == _pageCount - 1;

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    ref.read(onboardingNotifierProvider.notifier).setCurrentPage(page);
  }

  void _nextPage() {
    if (!_isLastPage) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeWithPermissions();
    }
  }

  /// Dernier écran : ne demande que les autorisations laissées activées. Un
  /// refus système ne bloque jamais l'entrée dans l'application.
  Future<void> _completeWithPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    if (_wantNotifications) {
      try {
        await LocationService.instance.requestNotificationPermission();
      } catch (_) {}
    }
    if (_wantLocation) {
      try {
        await LocationService.instance.requestLocationPermission();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _requestingPermissions = false);
    _completeIntro();
  }

  void _completeIntro() {
    ref.read(onboardingNotifierProvider.notifier).completeIntro();
    AnalyticsService.instance.logEvent(name: 'onboarding_complete');
    context.go('/home');
  }

  void _skip() {
    ref.read(onboardingNotifierProvider.notifier).skipAll();
    AnalyticsService.instance.logEvent(name: 'onboarding_skip');
    context.go('/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Carte des deux autorisations + mention chiffrement (écran 5/5).
  Widget _buildPermissionsCard(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignTileGroup(
          children: [
            DesignToggleTile(
              icon: Icons.notifications_none_rounded,
              title: l10n.notifications,
              subtitle: l10n.onbNotificationsSubtitle,
              value: _wantNotifications,
              onChanged:
                  _requestingPermissions
                      ? null
                      : (v) => setState(() => _wantNotifications = v),
            ),
            DesignToggleTile(
              icon: Icons.location_on_outlined,
              title: l10n.locationTitle,
              subtitle: l10n.onbLocationSubtitle,
              value: _wantLocation,
              onChanged:
                  _requestingPermissions
                      ? null
                      : (v) => setState(() => _wantLocation = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DesignInfoLine(
          icon: Icons.lock_outline,
          text: l10n.e2eeFooterNote,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _buildPages(l10n);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // « Passer » discret, aligné à droite.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
                child: TextButton(
                  onPressed: _requestingPermissions ? null : _skip,
                  child: Text(
                    l10n.skip,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final isLast = index == pages.length - 1;
                  return OnboardingPage(
                    data: pages[index],
                    footer: isLast ? _buildPermissionsCard(l10n) : null,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child:
                  _isLastPage
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DesignPageDots(
                            count: pages.length,
                            index: _currentPage,
                          ),
                          const SizedBox(height: 18),
                          DesignPillButton(
                            label: l10n.start,
                            expand: true,
                            isLoading: _requestingPermissions,
                            onPressed: _nextPage,
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton(
                              onPressed:
                                  _requestingPermissions
                                      ? null
                                      : _completeIntro,
                              child: Text(
                                l10n.onbLaterWithoutPermissions,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textTertiaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : Row(
                        children: [
                          DesignPageDots(
                            count: pages.length,
                            index: _currentPage,
                          ),
                          const Spacer(),
                          DesignPillButton(
                            label: l10n.next,
                            onPressed: _nextPage,
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
