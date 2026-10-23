import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/second_facteur.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/refus_non_admin.dart';
import 'admin_defi_second_facteur_screen.dart';
import 'admin_enrolement_totp_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Compte authentifié mais sans droits d'administration : on referme sa
  /// session, puis on l'écrit à l'écran — voir [refuserNonAdmin], partagé
  /// avec l'écran de défi du second facteur, pour le pourquoi.
  Future<void> _refuseNonAdmin(AuthRepository authRepo) async {
    final message = await refuserNonAdmin(authRepo);
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  void _afficherEchec(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  /// Ce qui suit une connexion, e-mail ou Google (`docs/deploiement/MFA_ADMIN.md`).
  ///
  /// Trois sorties, dans l'ordre où Firebase les produit :
  ///
  /// - [SecondFacteurRequisFailure] : premier facteur accepté, le compte porte
  ///   un facteur enrôlé, **aucune session n'est ouverte** — l'écran de défi
  ///   la terminera, ou non ;
  /// - un autre `Left` : le message ;
  /// - un `Right` : la session est ouverte. Sans droits d'administration, on
  ///   la referme ; sinon, enrôlement ou tableau de bord selon que le compte
  ///   a déjà un facteur.
  Future<void> _traiterConnexion(
    Either<Failure, UserEntity> result,
    AuthRepository authRepo,
  ) async {
    await result.fold<Future<void>>(
      (failure) async {
        if (failure is SecondFacteurRequisFailure) {
          if (!mounted) return;
          unawaited(
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AdminDefiSecondFacteurScreen(defi: failure.defi),
              ),
            ),
          );
          return;
        }
        _afficherEchec(failure.message);
      },
      (user) async {
        if (!user.isAdmin) {
          await _refuseNonAdmin(authRepo);
          return;
        }
        await _entrerOuEnroler(authRepo);
      },
    );
  }

  /// Un admin n'entre au tableau de bord qu'avec un second facteur enrôlé.
  ///
  /// La connexion a abouti d'un coup, donc Firebase n'a levé aucun défi, donc
  /// le compte n'a (presque sûrement) pas de facteur. On le relit quand même
  /// plutôt que de le déduire : la lecture est locale, et le jour où le
  /// multi-facteur serait désactivé côté projet, un compte enrôlé
  /// arriverait ici avec un facteur et l'enrôlement lui répondrait « déjà
  /// enrôlé ». La garde de `/dashboard` refait le même contrôle.
  Future<void> _entrerOuEnroler(AuthRepository authRepo) async {
    final facteurs = await authRepo.facteursEnroles();
    if (!mounted) return;
    facteurs.fold((failure) => _afficherEchec(failure.message), (liste) {
      if (liste.isEmpty) {
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const AdminEnrolementTotpScreen(),
            ),
          ),
        );
      } else {
        unawaited(Navigator.of(context).pushReplacementNamed('/dashboard'));
      }
    });
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.signInWithGoogle();
      await _traiterConnexion(result, authRepo);
    } catch (e) {
      _afficherEchec(e.toString());
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _traiterConnexion(result, authRepo);
    } catch (e) {
      _afficherEchec(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AdminColors.actionBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              DesignTitle(
                l10n.adminPanelTitle,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                accent: AdminColors.titleDot,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.adminDiaspoNigerMonitoring,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AdminColors.text3),
              ),
              const SizedBox(height: 32),
              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Text(
                    'G',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AdminColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.adminOrText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AdminColors.text3),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.adminEmailField,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: AdminColors.statusRed.withValues(alpha: 0.1),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AdminColors.statusRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.adminPasswordField,
                  border: OutlineInputBorder(),
                  prefixIcon: AppIcon(AppIcon.lock),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.actionBlue,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(l10n.adminLoginButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
