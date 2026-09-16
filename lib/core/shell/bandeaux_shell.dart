import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/mise_a_jour_service.dart';

/// Le bandeau que `MainShell` peut poser en tête d'application.
///
/// Il vit ici, hors de l'écran, pour une raison précise : un `MaterialBanner`
/// construit dans une méthode privée d'un `State` n'est **rendable par aucun
/// banc** — il faudrait monter tout le shell, son routeur et ses providers. Or
/// c'est justement le rendu qui casse : un message qui passe à deux lignes, une
/// échelle de police augmentée. Une fonction libre se rend en trois lignes de
/// test (`test/core/shell/bandeaux_shell_test.dart`).
///
/// Elle ne décide rien : `MainShell` reste seul à détenir le notifier. Ici, que
/// des callbacks.
///
/// **Un second bandeau vivait ici** — le rappel E2EE, « Sauvegardez / Restaurez
/// vos clés de chiffrement » —, avec tout un arbitrage pour qu'il prime sur la
/// mise à jour. Retiré le 2026-09-16 : sa promesse était fausse des deux côtés.
/// La sauvegarde ne porte que du matériel Signal (`SecureKeyStorage
/// .exportAllKeys`), et aucun message de production n'a jamais été chiffré par
/// Signal — 121 sur 121 en repli AES, dont les clés sont redérivées par l'Edge
/// Function `crypto-keys` à chaque installation. Restaurer ne rendait donc
/// aucun message lisible, et ne pas restaurer n'en perdait aucun. Le seul état
/// dont la perte coûte vraiment quelque chose est celui du moteur MLS, que
/// cette sauvegarde ne touche pas — il est même volontairement exclu des
/// sauvegardes système (`mls_engine_provider.dart`). L'écran Réglages ›
/// Sécurité reste atteignable à la main pour qui veut sauvegarder ou restaurer.

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
