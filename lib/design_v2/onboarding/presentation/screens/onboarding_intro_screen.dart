import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../../kit/design_kit.dart';
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

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      eyebrow: 'Niamey · Paris · Montréal · Abidjan',
      title: 'Bienvenue sur\nDiaspo Niger',
      description:
          'La communauté nigérienne, où qu\'elle soit : retrouvez vos '
          'proches, entraidez-vous, restez au pays même de loin.',
      illustrationCaption: 'illustration — la diaspora',
      brandMark: true,
    ),
    OnboardingPageData(
      title: 'Découvrez\nles membres',
      description:
          'Voyez qui vit près de chez vous : métier, ville d\'origine, '
          'langues parlées — de quoi trouver la bonne personne au bon moment.',
      illustrationCaption: 'illustration — carte des membres',
      icon: Icons.people_outline,
      bullets: [
        'Position approximative, jamais l\'adresse exacte',
        'Vous voyez ceux qui partagent, et réciproquement',
      ],
    ),
    OnboardingPageData(
      title: 'Rejoignez\ndes groupes',
      description:
          'Entraide de quartier, associations, promos d\'étudiants : '
          'trouvez les vôtres près de chez vous ou au pays.',
      illustrationCaption: 'illustration — rejoindre un groupe',
      icon: Icons.groups_outlined,
      bullets: [
        'Groupes publics ou privés, à vous de choisir',
        'Discussions chiffrées de bout en bout',
      ],
    ),
    OnboardingPageData(
      title: 'Participez aux\névénements',
      description:
          'Fêtes, permanences administratives, rencontres sportives : '
          'inscrivez-vous en un geste et ajoutez la date à votre agenda.',
      illustrationCaption: 'illustration — fête de la République',
      icon: Icons.event_outlined,
      bullets: ['En présentiel ou en ligne', 'Rappel avant le jour J'],
    ),
    OnboardingPageData(
      title: 'Restez\nconnectés',
      description:
          'Deux autorisations et vous êtes prêt. Vous pourrez les changer '
          'à tout moment dans Réglages.',
      illustrationCaption: 'illustration — rester connectés',
      icon: Icons.chat_bubble_outline,
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

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
  Widget _buildPermissionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignTileGroup(
          children: [
            DesignToggleTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Messages, invitations, rappels d\'événement',
              value: _wantNotifications,
              onChanged:
                  _requestingPermissions
                      ? null
                      : (v) => setState(() => _wantNotifications = v),
            ),
            DesignToggleTile(
              icon: Icons.location_on_outlined,
              title: 'Localisation',
              subtitle: 'Réciproque : vous voyez ceux qui partagent',
              value: _wantLocation,
              onChanged:
                  _requestingPermissions
                      ? null
                      : (v) => setState(() => _wantLocation = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const DesignInfoLine(
          icon: Icons.lock_outline,
          text: 'Vos messages sont chiffrés de bout en bout.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'Passer',
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
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final isLast = index == _pages.length - 1;
                  return OnboardingPage(
                    data: _pages[index],
                    footer: isLast ? _buildPermissionsCard() : null,
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
                            count: _pages.length,
                            index: _currentPage,
                          ),
                          const SizedBox(height: 18),
                          DesignPillButton(
                            label: 'Commencer',
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
                                'Plus tard, sans autorisations',
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
                            count: _pages.length,
                            index: _currentPage,
                          ),
                          const Spacer(),
                          DesignPillButton(
                            label: 'Suivant',
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
