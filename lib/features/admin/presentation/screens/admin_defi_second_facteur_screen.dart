import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/second_facteur.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/carte_acces_admin.dart';
import '../widgets/refus_non_admin.dart';

/// Défi du second facteur : Firebase a accepté l'e-mail et le mot de passe
/// (ou Google), le compte porte un facteur enrôlé, il reste à le prouver —
/// et **aucune session n'existe** tant que ce n'est pas fait.
///
/// Le code de l'application d'authentification clôt le défi par
/// `resoudreSecondFacteur`, qui termine la connexion comme `signInWithEmail`
/// (pont Supabase, profil). Puis le même tri qu'à la connexion : admin →
/// tableau de bord ; sinon refus et déconnexion.
class AdminDefiSecondFacteurScreen extends ConsumerStatefulWidget {
  const AdminDefiSecondFacteurScreen({super.key, required this.defi});

  final DefiSecondFacteur defi;

  @override
  ConsumerState<AdminDefiSecondFacteurScreen> createState() =>
      _AdminDefiSecondFacteurScreenState();
}

class _AdminDefiSecondFacteurScreenState
    extends ConsumerState<AdminDefiSecondFacteurScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _codeController = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  /// Le panneau ne sait prouver qu'un TOTP ; un compte qui n'a qu'un facteur
  /// SMS (enrôlé ailleurs) ne peut pas entrer d'ici, et l'écran le dit au
  /// lieu de laisser taper un code qui ne mènera nulle part.
  bool get _aUnTotp => widget.defi.facteurs.any((f) => f.estTotp);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifier() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _erreur = l10n.adminMfaCodeMissing);
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final authRepo = ref.read(authRepositoryProvider);
    final resultat = await authRepo.resoudreSecondFacteur(
      defi: widget.defi,
      code: code,
    );
    if (!mounted) return;
    await resultat.fold<Future<void>>(
      (echec) async => setState(() {
        _erreur = echec.message;
        _enCours = false;
      }),
      (user) async {
        if (user.isAdmin) {
          if (mounted) {
            unawaited(
              Navigator.of(context).pushReplacementNamed('/dashboard'),
            );
          }
          return;
        }
        // La session vient de s'ouvrir pour un compte sans droits : on la
        // referme, comme à la connexion.
        final message = await refuserNonAdmin(authRepo);
        if (!mounted) return;
        setState(() {
          _erreur = message;
          _enCours = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final discret = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AdminColors.text3,
    );
    return CarteAccesAdmin(
      titre: l10n.adminMfaChallengeTitle,
      children: [
        Text(
          l10n.adminMfaChallengeIntro,
          style: discret,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!_aUnTotp) BoiteErreurAdmin(l10n.adminMfaNoTotp),
        TextField(
          controller: _codeController,
          enabled: _aUnTotp,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: l10n.adminMfaCodeField,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.password),
          ),
          onSubmitted: (_) => _verifier(),
        ),
        const SizedBox(height: 16),
        if (_erreur != null) BoiteErreurAdmin(_erreur!),
        BoutonPrincipalAdmin(
          libelle: l10n.adminMfaVerifyButton,
          enCours: _enCours,
          onPressed: _aUnTotp ? _verifier : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/login'),
          child: Text(l10n.adminMfaBackToLogin),
        ),
      ],
    );
  }
}
