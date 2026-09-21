import 'package:supabase_flutter/supabase_flutter.dart';

/// Rouvre le websocket et redemande chaque abonnement avec le jeton courant.
///
/// À appeler **après** avoir obtenu un jeton neuf, quand l'ancien était périmé.
///
/// Au retour au premier plan, `supabase_flutter` reconnecte le websocket et
/// re-rejoint les canaux aussitôt — avec le jeton qu'il a sous la main, donc
/// le jeton périmé, pendant que le pont en est encore à en demander un neuf.
/// Le serveur accepte le `join`, puis refuse en différé la réplication
/// `postgres_changes` (message `system` en erreur). Le canal reste marqué
/// « joined » et ne reçoit plus rien, jamais : le jeton neuf, poussé ensuite
/// par `setAuth`, ne remonte pas un abonnement déjà refusé. Seule une relance
/// de l'app réparait.
///
/// Vu le 2026-09-21 sur Pixel 10 Pro XL (app restée des heures derrière une
/// autre) : discussion ouverte au premier plan, les messages de l'autre
/// n'arrivaient plus, la liste restait figée ; rouvrir la discussion ne
/// changeait rien, une relance à froid si.
///
/// Même geste que `supabase_flutter` au retour (reconnexion puis
/// `forceRejoin`), rejoué une fois le bon jeton en place. Chaque canal repasse
/// par `subscribed`, ce qui déclenche aussi `rattrapageAuRejoint` : ce qui est
/// arrivé pendant l'absence est relu.
Future<void> reabonnerLeTempsReel(RealtimeClient realtime) async {
  if (realtime.channels.isEmpty) return;

  await realtime.disconnect();
  // ignore: invalid_use_of_internal_member
  await realtime.connect();
  // Échec de connexion : le client le signale déjà aux canaux, qui se
  // rejoindront d'eux-mêmes au retour du réseau.
  if (!realtime.isConnected) return;

  for (final canal in [...realtime.channels]) {
    // ignore: invalid_use_of_internal_member
    if (canal.isJoined || canal.isJoining || canal.isErrored) {
      // ignore: invalid_use_of_internal_member
      canal.forceRejoin();
    }
  }
}
