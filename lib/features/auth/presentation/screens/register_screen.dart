import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../core/services/analytics_service.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authNotifierProvider.notifier)
          .signUp(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim(),
          );
      AnalyticsService.instance.logSignUp(method: 'email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        authenticated: (_) {},
        error:
            (message) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.error,
              ),
            ),
      );
    });

    final isLoading = authState.maybeWhen(
      loading: () => true,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: context.surfaceVariantColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  l10n.createAccount,
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  l10n.joinCommunity,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Name Field
                CustomTextField(
                  controller: _nameController,
                  label: l10n.fullName,
                  keyboardType: TextInputType.name,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.enterName;
                    }
                    if (value.length < 2) {
                      return l10n.nameTooShort;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email Field
                CustomTextField(
                  controller: _emailController,
                  label: l10n.email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.enterEmail;
                    }
                    // Erreurs en langage clair (§15b).
                    final v = value.trim();
                    if (!v.contains('@')) return l10n.emailMissingAt;
                    final parts = v.split('@');
                    if (parts.length != 2 ||
                        parts[0].isEmpty ||
                        parts[1].isEmpty) {
                      return l10n.invalidEmail;
                    }
                    if (!parts[1].contains('.')) return l10n.emailMissingDomain;
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                CustomTextField(
                  controller: _passwordController,
                  label: l10n.password,
                  obscureText: true,
                  enabled: !isLoading,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.enterAPassword;
                    }
                    if (value.length < 6) {
                      return l10n.passwordTooShort;
                    }
                    return null;
                  },
                ),

                // Jauge de robustesse en 3 segments (§15b).
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PasswordStrengthGauge(password: _passwordController.text),
                ],

                const SizedBox(height: 16),

                // Confirm Password Field
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: l10n.confirmPassword,
                  obscureText: true,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.confirmPasswordRequired;
                    }
                    if (value != _passwordController.text) {
                      return l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Register Button
                CustomButton(
                  onPressed: _handleRegister,
                  label: l10n.signUp,
                  isLoading: isLoading,
                ),

                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.alreadyHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textTertiaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        l10n.signIn,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Terms
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fullText = l10n.termsAgreement;
                    final termsText = l10n.termsOfService;
                    final privacyText = l10n.privacyPolicy;

                    final termsIndex = fullText.indexOf(termsText);
                    final privacyIndex = fullText.indexOf(privacyText);

                    if (termsIndex == -1 || privacyIndex == -1) {
                      // Fallback if translations don't match
                      return Text(
                        fullText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textTertiaryColor,
                        ),
                        textAlign: TextAlign.center,
                      );
                    }

                    final part1 = fullText.substring(0, termsIndex);
                    final part2 = fullText.substring(
                      termsIndex + termsText.length,
                      privacyIndex,
                    );
                    final part3 = fullText.substring(
                      privacyIndex + privacyText.length,
                    );

                    return RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textTertiaryColor,
                        ),
                        children: [
                          TextSpan(text: part1),
                          TextSpan(
                            text: termsText,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap =
                                      () => context.push('/settings/terms'),
                          ),
                          TextSpan(text: part2),
                          TextSpan(
                            text: privacyText,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap =
                                      () => context.push('/settings/privacy'),
                          ),
                          TextSpan(text: part3),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Jauge de robustesse du mot de passe en 3 segments (§15b) :
/// faible (rouge) / moyen (orange) / fort (vert).
class _PasswordStrengthGauge extends StatelessWidget {
  final String password;

  const _PasswordStrengthGauge({required this.password});

  /// Score 1..3 (0 = vide).
  int get _score {
    var s = 0;
    if (password.length >= 6) s++;
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasSpecial = password.contains(RegExp(r'[^A-Za-z0-9]'));
    if (password.length >= 10 || (hasLetter && hasDigit)) s++;
    if (hasUpper && hasDigit && (hasSpecial || password.length >= 12)) s++;
    return s.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    const labels = ['Faible', 'Moyen', 'Fort'];
    final colors = [
      const Color(0xFFC23E2D),
      const Color(0xFFD9A441),
      const Color(0xFF2D7D46),
    ];
    final color = score == 0 ? Colors.grey : colors[score - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < score;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? color
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        if (score > 0) ...[
          const SizedBox(height: 4),
          Text(
            labels[score - 1],
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
