import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/e2ee/e2ee_backup_coordinator.dart';
import '../services/mise_a_jour_service.dart';

/// Les deux bandeaux que `MainShell` peut poser en tête d'application.
///
/// Ils vivent ici, hors de l'écran, pour une raison précise : un
/// `MaterialBanner` construit dans une méthode privée d'un `State` n'est
/// **rendable par aucun banc** — il faudrait monter tout le shell, son
/// routeur et ses providers. Or c'est justement le rendu qui casse : trois
/// actions, un message qui passe à deux lignes, une échelle de police
/// augmentée. Des fonctions libres se rendent en trois lignes de test
/// (`test/core/shell/bandeaux_shell_test.dart`).
///
/// Elles ne décident rien : `MainShell` reste seul à arbitrer lequel des deux
/// s'affiche, et seul à détenir les notifiers. Ici, que des callbacks.

/// Bandeau invitant à sauvegarder ou restaurer les clés E2EE.
MaterialBanner bandeauE2EE({
  required AppLocalizations l10n,
  required E2EEBackupPrompt prompt,
  required VoidCallback surNePlusRappeler,
  required VoidCallback surPasMaintenant,
  required VoidCallback surAgir,
}) {
  final isRestore = prompt == E2EEBackupPrompt.needsRestore;

  return MaterialBanner(
    content: Text(
      isRestore ? l10n.e2eeRestoreNudgeMessage : l10n.e2eeBackupNudgeMessage,
    ),
    leading: const Icon(Icons.lock_outline),
    actions: [
      // Sortie définitive : « Pas maintenant » ne met en veille que 7 jours,
      // et `needsRestore` reste vrai tant que la restauration n'a pas eu
      // lieu — le bandeau revenait donc indéfiniment.
      TextButton(
        onPressed: surNePlusRappeler,
        child: Text(l10n.e2eeNudgeMuteAction),
      ),
      TextButton(
        onPressed: surPasMaintenant,
        child: Text(l10n.notNow),
      ),
      TextButton(
        onPressed: surAgir,
        child: Text(
          isRestore ? l10n.e2eeRestoreNudgeAction : l10n.e2eeBackupNudgeAction,
        ),
      ),
    ],
  );
}

/// Bandeau « une nouvelle version est disponible ».
///
/// Deux actions, aucune définitive : « Pas maintenant » ne tait que cette
/// version-là, la suivante reparlera.
///
/// Le message tient en **une phrase**, et c'est délibéré. La première version
/// ajoutait « Mettez à jour pour profiter des derniers correctifs » : une
/// consigne que le bouton « Mettre à jour » donne déjà, qui poussait le
/// message à deux lignes et le bandeau à un sixième de l'écran du SM-A515F —
/// par-dessus l'Accueil comme par-dessus une discussion, puisqu'il vit dans le
/// shell.
MaterialBanner bandeauMiseAJour({
  required AppLocalizations l10n,
  required NoticeMiseAJour notice,
  required VoidCallback surPasMaintenant,
  required VoidCallback surMettreAJour,
}) {
  return MaterialBanner(
    content: Text(l10n.updateAvailableMessage(notice.versionPubliee)),
    leading: const Icon(Icons.system_update_outlined),
    actions: [
      TextButton(
        onPressed: surPasMaintenant,
        child: Text(l10n.notNow),
      ),
      TextButton(
        onPressed: surMettreAJour,
        child: Text(l10n.updateAvailableAction),
      ),
    ],
  );
}
