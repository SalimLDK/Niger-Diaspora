import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_scaffold.dart';
import '../../../../core/theme/adaptive_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authNotifierProvider.notifier)
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      AnalyticsService.instance.logLogin(method: 'email');
    }
  }

  void _handleGoogleSignIn() {
    ref.read(authNotifierProvider.notifier).signInWithGoogle();
    AnalyticsService.instance.logLogin(method: 'google');
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

    return AuthScaffold(
      footer: const AuthEncryptionNote(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandMark(),
            const SizedBox(height: 26),

            AuthTitle(l10n.welcomeBackTitle),
            const SizedBox(height: 10),
            Text(
              l10n.loginSubtitle,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: context.textSecondaryColor,
              ),
            ),

            const SizedBox(height: 26),

            AuthButton(
              onPressed: _handleGoogleSignIn,
              iconAsset: AuthButton.googleAsset,
              label: l10n.continueWithGoogle,
              isLoading: isLoading,
            ),

            const SizedBox(height: 22),
            AuthDivider(label: l10n.or),
            const SizedBox(height: 22),

            AuthFieldLabel(l10n.emailAddressLabel),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _emailController,
              hintText: l10n.emailAddressLabel,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.enterEmail;
                }
                // Erreurs en langage clair (§15a).
                final v = value.trim();
                if (!v.contains('@')) return l10n.emailMissingAt;
                final parts = v.split('@');
                if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
                  return l10n.invalidEmail;
                }
                if (!parts[1].contains('.')) return l10n.emailMissingDomain;
                return null;
              },
            ),

            const SizedBox(height: 18),

            // Libellé + « Oublié ? » sur la même ligne (§15a).
            AuthFieldLabel(
              l10n.password,
              trailing: GestureDetector(
                onTap: () => context.push('/auth/forgot-password'),
                child: Text(
                  l10n.forgotShort,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.adaptivePrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _passwordController,
              hintText: l10n.password,
              obscureText: _obscurePassword,
              enabled: !isLoading,
              helperText: l10n.passwordMinHelper,
              suffix: AuthObscureToggle(
                obscured: _obscurePassword,
                onChanged: (v) => setState(() => _obscurePassword = v),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.enterPassword;
                }
                if (value.length < 6) {
                  return l10n.passwordTooShort;
                }
                return null;
              },
            ),

            const SizedBox(height: 22),

            AuthPrimaryButton(
              onPressed: _handleLogin,
              label: l10n.signIn,
              isLoading: isLoading,
            ),

            const SizedBox(height: 16),

            AuthFooterLink(
              question: l10n.noAccount,
              action: l10n.signUp,
              onTap: () => context.push('/auth/register'),
            ),
          ],
        ),
      ),
    );
  }
}
