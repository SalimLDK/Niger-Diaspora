import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _conductAccepted = false;
  bool _isLoading = false;

  bool get _canProceed =>
      _termsAccepted && _privacyAccepted && _conductAccepted;

  Future<void> _handleContinue() async {
    if (!_canProceed) return;

    setState(() => _isLoading = true);

    try {
      // Mark consent as given via onboarding provider
      await ref.read(onboardingNotifierProvider.notifier).markConsentGiven();

      // Router will automatically redirect to profile-config
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Icon and title
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                l10n.consentWelcome,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                l10n.consentAcceptConditions,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Terms checkbox
                      _buildConsentCard(
                        title: 'Conditions d\'utilisation',
                        description:
                            'J\'accepte les conditions générales d\'utilisation de l\'application Diaspo Niger.',
                        isChecked: _termsAccepted,
                        onChanged:
                            (value) =>
                                setState(() => _termsAccepted = value ?? false),
                        onViewDetails: () => context.push('/settings/terms'),
                      ),
                      const SizedBox(height: 16),

                      // Privacy checkbox
                      _buildConsentCard(
                        title: l10n.privacyPolicy,
                        description:
                            'J\'accepte la politique de confidentialité et le traitement de mes données personnelles.',
                        isChecked: _privacyAccepted,
                        onChanged:
                            (value) => setState(
                              () => _privacyAccepted = value ?? false,
                            ),
                        onViewDetails: () => context.push('/settings/privacy'),
                      ),
                      const SizedBox(height: 16),

                      // Code of conduct checkbox
                      _buildConsentCard(
                        title: l10n.codeOfConduct,
                        description:
                            'Je m\'engage à respecter le code de conduite et les règles de la communauté.',
                        isChecked: _conductAccepted,
                        onChanged:
                            (value) => setState(
                              () => _conductAccepted = value ?? false,
                            ),
                        onViewDetails:
                            () => context.push('/settings/code-of-conduct'),
                      ),
                      const SizedBox(height: 24),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.adaptivePrimaryColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: context.adaptivePrimaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.consentDataProtection,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _canProceed && !_isLoading ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.adaptivePrimaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.outlineColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            l10n.continueAction,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  Widget _buildConsentCard({
    required String title,
    required String description,
    required bool isChecked,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDetails,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isChecked
                  ? context.adaptivePrimaryColor
                  : context.outlineColor.withValues(alpha: 0.3),
          width: isChecked ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isChecked,
                onChanged: onChanged,
                activeColor: context.adaptivePrimaryColor,
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onViewDetails,
                  child: Text(
                    'Lire les détails →',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
