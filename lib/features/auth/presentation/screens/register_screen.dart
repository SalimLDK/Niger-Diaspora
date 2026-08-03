import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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

  /// Les deux mots de passe concordent et sont assez longs — sert la coche
  /// verte de la maquette sur le champ de confirmation.
  bool get _confirmMatches =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text &&
      _passwordController.text.length >= 6;

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
      header: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      footer: AuthFooterLink(
        question: l10n.alreadyHaveAccount,
        action: l10n.signIn,
        onTap: () => context.pop(),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTitle(l10n.createAccount),
            const SizedBox(height: 10),
            Text(
              l10n.joinCommunity,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: context.textSecondaryColor,
              ),
            ),

            const SizedBox(height: 24),

            AuthFieldLabel(l10n.fullName),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _nameController,
              hintText: l10n.fullName,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.enterName;
                if (value.length < 2) return l10n.nameTooShort;
                return null;
              },
            ),

            const SizedBox(height: 18),

            AuthFieldLabel(l10n.emailAddressLabel),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _emailController,
              hintText: l10n.emailAddressLabel,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.enterEmail;
                // Erreurs en langage clair (§15b).
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

            AuthFieldLabel(l10n.password),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _passwordController,
              hintText: l10n.password,
              obscureText: _obscurePassword,
              enabled: !isLoading,
              onChanged: (_) => setState(() {}),
              suffix: AuthObscureToggle(
                obscured: _obscurePassword,
                onChanged: (v) => setState(() => _obscurePassword = v),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.enterAPassword;
                if (value.length < 6) return l10n.passwordTooShort;
                return null;
              },
            ),

            // Jauge de robustesse en 3 segments (§15b).
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PasswordStrengthGauge(password: _passwordController.text),
            ],

            const SizedBox(height: 18),

            AuthFieldLabel(l10n.confirmPassword),
            const SizedBox(height: 7),
            AuthTextField(
              controller: _confirmPasswordController,
              hintText: l10n.confirmPassword,
              obscureText: _obscureConfirm,
              enabled: !isLoading,
              onChanged: (_) => setState(() {}),
              suffix:
                  _confirmMatches
                      ? Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 21,
                          color: context.successColor,
                        ),
                      )
                      : AuthObscureToggle(
                        obscured: _obscureConfirm,
                        onChanged: (v) => setState(() => _obscureConfirm = v),
                      ),
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

            const SizedBox(height: 26),

            AuthPrimaryButton(
              onPressed: _handleRegister,
              label: l10n.createMyAccount,
              isLoading: isLoading,
            ),

            const SizedBox(height: 16),

            _TermsNotice(),
          ],
        ),
      ),
    );
  }
}

/// Mention légale sous le bouton, avec les deux liens cliquables.
class _TermsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fullText = l10n.termsAgreement;
    final termsText = l10n.termsOfService;
    final privacyText = l10n.privacyPolicy;

    final base = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: context.textTertiaryColor,
    );
    final link = base.copyWith(
      color: context.adaptivePrimaryColor,
      fontWeight: FontWeight.w700,
    );

    final termsIndex = fullText.indexOf(termsText);
    final privacyIndex = fullText.indexOf(privacyText);

    if (termsIndex == -1 || privacyIndex == -1 || privacyIndex < termsIndex) {
      // Repli si la traduction ne contient pas les deux libellés tels quels.
      return Text(fullText, style: base, textAlign: TextAlign.center);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: fullText.substring(0, termsIndex)),
          TextSpan(
            text: termsText,
            style: link,
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () => context.push('/settings/terms'),
          ),
          TextSpan(
            text: fullText.substring(
              termsIndex + termsText.length,
              privacyIndex,
            ),
          ),
          TextSpan(
            text: privacyText,
            style: link,
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () => context.push('/settings/privacy'),
          ),
          TextSpan(
            text: fullText.substring(privacyIndex + privacyText.length),
          ),
        ],
      ),
    );
  }
}

/// Jauge de robustesse du mot de passe en 3 segments (§15b) :
/// faible / correct / fort, le libellé à droite des barres.
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
    final l10n = AppLocalizations.of(context)!;
    final score = _score;
    final labels = [
      l10n.passwordStrengthWeak,
      l10n.passwordStrengthOk,
      l10n.passwordStrengthStrong,
    ];
    final colors = [
      context.errorColor,
      context.warningColor,
      context.successColor,
    ];
    final color = score == 0 ? context.borderColor : colors[score - 1];

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? color : context.borderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        SizedBox(
          width: 58,
          child: Text(
            score == 0 ? '' : labels[score - 1],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
