import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/mls/mls_providers.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Bandeau « le chiffrement de cette discussion est bloqué », avec
/// « Réparer ».
///
/// Un membre peut publier des octets quelconques à l'epoch suivant du groupe
/// MLS — le serveur ne voit que du chiffré. Tous les autres restaient alors
/// bloqués sans le savoir : plus aucun message lisible, et une seule trace,
/// `commit_illisible` dans `mls_diagnostics`. Le bandeau le dit, et « Réparer »
/// reconstruit le groupe (`MlsGateway.reparer`) ; c'est le serveur qui décide
/// qui en a le droit — un administrateur pour un groupe, un participant hors
/// groupe —, et son refus s'affiche tel quel.
///
/// **Toujours dans l'arbre**, vide quand rien n'est bloqué : un enfant qui
/// apparaît ou disparaît dans la `Column` de l'écran démonterait le
/// composeur placé en dessous (voir `GroupPinnedBanner`).
class BandeauChiffrementBloque extends ConsumerStatefulWidget {
  const BandeauChiffrementBloque({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<BandeauChiffrementBloque> createState() =>
      _BandeauChiffrementBloqueState();
}

class _BandeauChiffrementBloqueState
    extends ConsumerState<BandeauChiffrementBloque> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final bloque =
        ref.watch(groupeMlsBloqueProvider(widget.conversationId)).valueOrNull ??
            false;
    if (!bloque) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.lock_reset,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.chiffrementBloqueTexte,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _enCours ? null : _reparer,
              child: _enCours
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textSecondaryColor,
                      ),
                    )
                  : Text(l10n.chiffrementBloqueReparer),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reparer() async {
    final l10n = AppLocalizations.of(context)!;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chiffrementReparerTitre),
        content: Text(l10n.chiffrementReparerTexte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.chiffrementBloqueReparer),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    final passerelle = ref.read(mlsGatewayProvider);
    if (passerelle == null) return;
    setState(() => _enCours = true);
    String message;
    try {
      await passerelle.reparer(widget.conversationId);
      message = l10n.chiffrementReparerOk;
    } catch (e) {
      message = messageDeRefusReparation(e, l10n);
    }
    if (!mounted) return;
    setState(() => _enCours = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Le refus du serveur (`reconstruire_groupe_mls`), dans la langue de
/// l'utilisateur.
String messageDeRefusReparation(Object e, AppLocalizations l10n) {
  final texte = e.toString();
  if (texte.contains('administrateurs')) {
    return l10n.chiffrementReparerReserveAdmin;
  }
  if (texte.contains('moins de 5 minutes')) {
    return l10n.chiffrementReparerTropRecent;
  }
  return l10n.chiffrementReparerEchec;
}
