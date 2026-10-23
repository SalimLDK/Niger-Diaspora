import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../auth/domain/entities/second_facteur.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/second_facteur_provider.dart';
import '../widgets/carte_acces_admin.dart';

/// Nom sous lequel le facteur est enrôlé chez Firebase (`displayName`,
/// obligatoire pour TOTP). Il revient dans `FacteurEnrole.libelle`.
const String libelleFacteurTotp = "Application d'authentification";

/// Enrôlement du second facteur (TOTP) d'un compte admin.
///
/// Un compte admin sans facteur n'entre pas au tableau de bord
/// (`docs/deploiement/MFA_ADMIN.md`) : il arrive ici juste après sa
/// connexion, ou depuis la garde de `/dashboard` s'il a tapé l'adresse avec
/// une session sans facteur. Le secret est généré à l'ouverture, montré en
/// QR et en clé ; le premier code de l'application le confirme et enrôle le
/// facteur, puis le tableau de bord s'ouvre.
///
/// La génération exige une connexion récente (`requires-recent-login`) et
/// TOTP activé sur le projet : les deux refus s'affichent tels que le dépôt
/// les nomme, avec « Réessayer » et « Se déconnecter ».
class AdminEnrolementTotpScreen extends ConsumerStatefulWidget {
  const AdminEnrolementTotpScreen({super.key});

  @override
  ConsumerState<AdminEnrolementTotpScreen> createState() =>
      _AdminEnrolementTotpScreenState();
}

class _AdminEnrolementTotpScreenState
    extends ConsumerState<AdminEnrolementTotpScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _codeController = TextEditingController();

  /// Nul tant que la génération n'a pas abouti ; [_erreurSecret] dit alors
  /// pourquoi, une fois [_generationEnCours] retombé.
  SecretTotp? _secret;
  String? _erreurSecret;
  bool _generationEnCours = true;

  String? _erreurCode;
  bool _verificationEnCours = false;

  @override
  void initState() {
    super.initState();
    unawaited(_genererSecret());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _genererSecret() async {
    setState(() {
      _generationEnCours = true;
      _erreurSecret = null;
      _secret = null;
    });
    final resultat =
        await ref.read(authRepositoryProvider).commencerEnrolementTotp();
    if (!mounted) return;
    setState(() {
      _generationEnCours = false;
      resultat.fold(
        (echec) => _erreurSecret = echec.message,
        (secret) => _secret = secret,
      );
    });
  }

  Future<void> _activer() async {
    final secret = _secret;
    if (secret == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _erreurCode = l10n.adminMfaCodeMissing);
      return;
    }
    setState(() {
      _verificationEnCours = true;
      _erreurCode = null;
    });
    final resultat = await ref
        .read(authRepositoryProvider)
        .terminerEnrolementTotp(
          secret: secret,
          code: code,
          libelle: libelleFacteurTotp,
        );
    if (!mounted) return;
    resultat.fold(
      (echec) => setState(() {
        _erreurCode = echec.message;
        _verificationEnCours = false;
      }),
      (_) {
        // La garde de `/dashboard` relit les facteurs : sans ça, elle
        // servirait la liste vide lue avant l'enrôlement et renverrait ici.
        ref.invalidate(facteursEnrolesProvider);
        if (mounted) {
          unawaited(Navigator.of(context).pushReplacementNamed('/dashboard'));
        }
      },
    );
  }

  Future<void> _seDeconnecter() async {
    final resultat = await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    resultat.fold(
      (echec) => setState(
        () => _erreurCode =
            "La session n'a pas pu être fermée : ${echec.message}",
      ),
      (_) {
        if (mounted) {
          unawaited(Navigator.of(context).pushReplacementNamed('/login'));
        }
      },
    );
  }

  /// `ABCDEFGHIJKLMNOP` → `ABCD EFGH IJKL MNOP` : la clé se recopie par
  /// blocs, comme l'application la présente.
  static String cleGroupee(String cle) {
    final blocs = <String>[];
    for (var i = 0; i < cle.length; i += 4) {
      blocs.add(cle.substring(i, i + 4 > cle.length ? cle.length : i + 4));
    }
    return blocs.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final secret = _secret;
    final discret = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AdminColors.text3,
    );
    return CarteAccesAdmin(
      titre: l10n.adminMfaEnrolTitle,
      children: [
        Text(
          l10n.adminMfaEnrolIntro,
          style: discret,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_generationEnCours)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (secret == null) ...[
          BoiteErreurAdmin(_erreurSecret ?? ''),
          OutlinedButton(
            onPressed: _genererSecret,
            child: Text(l10n.adminMfaRetry),
          ),
        ] else ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AdminColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: secret.urlQr,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.adminMfaManualKey,
            style: discret,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          SelectableText(
            cleGroupee(secret.cle),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              letterSpacing: 1.2,
              color: AdminColors.text,
            ),
          ),
          if (secret.expireLe != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.adminMfaConfirmBefore(
                TimeOfDay.fromDateTime(
                  secret.expireLe!.toLocal(),
                ).format(context),
              ),
              style: discret,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
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
            onSubmitted: (_) => _activer(),
          ),
          const SizedBox(height: 16),
          if (_erreurCode != null) BoiteErreurAdmin(_erreurCode!),
          BoutonPrincipalAdmin(
            libelle: l10n.adminMfaActivateButton,
            enCours: _verificationEnCours,
            onPressed: _activer,
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _seDeconnecter,
          child: Text(l10n.adminMfaSignOut),
        ),
      ],
    );
  }
}
