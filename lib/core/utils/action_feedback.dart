import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Attend le résultat d'une écriture et, si elle n'a pas abouti, le dit.
///
/// Les écritures que l'utilisateur déclenche d'un geste — bascule de réglage,
/// suppression, abonnement — rendent `Future<bool>` : `false` veut dire « rien
/// n'a été enregistré », et la méthode a déjà remis l'état visible d'aplomb
/// (l'interrupteur, la liste). Restait à le dire. Sans cela un refus se lit
/// « le tap n'a pas pris », et pire quand l'écran annonce dans la foulée
/// « supprimé » : il affirmait un succès que rien n'avait constaté.
///
/// Une méthode qui **lève** plutôt que de rendre `false` est un piège pour les
/// appelants en `unawaited(...)` : l'exception y devient une erreur asynchrone
/// non gérée, que personne n'affiche.
///
/// Le messager et le libellé sont pris **avant** l'attente : l'écran peut avoir
/// été refermé entre-temps (suppression, retour), alors que le
/// `ScaffoldMessenger` vit au niveau de l'app et affichera quand même.
///
/// Rend le résultat, pour que l'appelant n'affiche « supprimé » qu'en cas de
/// succès.
Future<bool> reportIfFailed(BuildContext context, Future<bool> result) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context)!.errorOccurred;

  final done = await result;
  if (!done) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
  return done;
}
