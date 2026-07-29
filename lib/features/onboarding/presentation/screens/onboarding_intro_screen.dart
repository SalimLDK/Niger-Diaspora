import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page.dart';

class OnboardingIntroScreen extends ConsumerStatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  ConsumerState<OnboardingIntroScreen> createState() =>
      _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends ConsumerState<OnboardingIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(name: 'onboarding_begin');
  }

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      title: 'Bienvenue sur\nDiaspo Niger',
      description:
          'Connectez-vous avec la diaspora nigerienne partout dans le monde. Retrouvez vos compatriotes et partagez ensemble.',
      icon: Icons.people_outline,
      color: AppColors.primary,
    ),
    OnboardingPageData(
      title: 'Decouvrez les membres',
      description:
          'Trouvez des Nigeriens pres de chez vous grace a notre carte interactive. Voyez qui habite dans votre region.',
      icon: Icons.map_outlined,
      color: AppColors.secondary,
    ),
    OnboardingPageData(
      title: 'Rejoignez des groupes',
      description:
          'Participez a des communautes thematiques: professionnels, etudiants, entrepreneurs... Echangez et entraidez-vous.',
      icon: Icons.groups_outlined,
      color: AppColors.primaryDark,
    ),
    OnboardingPageData(
      title: 'Participez aux evenements',
      description:
          'Organisez ou participez a des rencontres, conferences et activites culturelles de la diaspora.',
      icon: Icons.event_outlined,
      color: AppColors.primary,
    ),
    OnboardingPageData(
      title: 'Restez connectes',
      description:
          'Discutez en prive avec les membres de la communaute. Creez des liens durables avec la diaspora.',
      icon: Icons.chat_bubble_outline,
      color: AppColors.secondary,
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    ref.read(onboardingNotifierProvider.notifier).setCurrentPage(page);
  }

  bool _requestingPermissions = false;

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeWithPermissions();
    }
  }

  /// Dernier écran (§14) : demande notifications + localisation (réciprocité
  /// expliquée dans le contenu de l'écran), puis termine. Les refus ne bloquent
  /// pas l'entrée dans l'app.
  Future<void> _completeWithPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    try {
      await LocationService.instance.requestNotificationPermission();
    } catch (_) {}
    try {
      await LocationService.instance.requestLocationPermission();
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Passer',
                    style: TextStyle(
                      color: context.textTertiaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            // Indicators and buttons
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 32 : 8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Next/Start button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _requestingPermissions ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _requestingPermissions
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                              : Text(
                                _currentPage == _pages.length - 1
                                    ? 'Commencer'
                                    : 'Suivant',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  // Entrer sans accorder les autorisations (§14).
                  if (_currentPage == _pages.length - 1) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _requestingPermissions ? null : _completeIntro,
                      child: Text(
                        'Plus tard, sans autorisations',
                        style: TextStyle(
                          color: context.textTertiaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
