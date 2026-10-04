import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rattrapage des événements perdus pendant une coupure du websocket.
///
/// `subscribe()` n'est appelé qu'une fois, mais le client realtime **rejoint
/// le canal à chaque reconnexion** : retour au premier plan, passage Wi-Fi →
/// données mobiles, tunnel, veille prolongée. Postgres ne rejoue rien de ce
/// qui s'est produit entre-temps — le canal reprend au présent.
///
/// Sans relecture à ce moment-là, l'écran reste figé sur son dernier état
/// connu jusqu'au prochain événement… qui peut ne jamais venir : une liste de
/// discussions ne bouge que si quelqu'un écrit. C'est la forme qu'a prise
/// « les messages, les notifications et le fil ne s'actualisent plus tout
/// seuls » — rien n'est en erreur, il ne se passe simplement plus rien.
///
/// Le **premier** `subscribed` est ignoré : l'appelant vient de faire sa
/// lecture initiale, la relancer ne ferait que doubler la requête au
/// démarrage. Seuls les rejoints suivants déclenchent [relire].
///
/// ⚠️ **Sauf si cette lecture initiale a échoué.** Un écran ouvert alors que
/// l'appareil est déjà hors ligne n'a rien pu charger, et le premier `subscribed`
/// — qui n'arrive qu'au retour du réseau — est alors sa première occasion
/// d'afficher quoi que ce soit. Sans [lectureInitialeEnEchec], il restait sur
/// son erreur jusqu'à ce que l'utilisateur tire pour rafraîchir. L'appelant
/// signale l'échec ; on ne relit pas sur « pas encore terminée », sinon la
/// requête serait doublée à chaque démarrage.
///
/// [desLePremier] relit aussi au premier `subscribed`, lecture réussie ou
/// non. Pour un flux d'**insertions** (nouveaux messages), le premier
/// abonnement n'est pas une redite : rejoindre le canal prend de 100 ms à
/// quelques secondes après la lecture initiale, et ce qui s'écrit dans cet
/// intervalle n'est ni dans la page lue, ni livré par le temps réel.
/// L'appelant doit alors dédoublonner ce que les deux chemins rapportent.
///
/// À passer directement à `subscribe()` :
///
/// ```dart
/// canal.onPostgresChanges(...).subscribe(
///   rattrapageAuRejoint(fetch, lectureInitialeEnEchec: () => echecInitial),
/// );
/// ```
void Function(RealtimeSubscribeStatus, Object?) rattrapageAuRejoint(
  void Function() relire, {
  bool Function()? lectureInitialeEnEchec,
  bool desLePremier = false,
  String? etiquette,
}) {
  var dejaRejoint = false;
  return (status, error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        if (dejaRejoint ||
            desLePremier ||
            (lectureInitialeEnEchec?.call() ?? false)) {
          if (etiquette != null) {
            debugPrint('realtime: rejoint « $etiquette » → rattrapage');
          }
          relire();
        }
        dejaRejoint = true;
      case RealtimeSubscribeStatus.closed:
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.channelError:
        // Le prochain `subscribed` sera une reprise, pas une première.
        // On ne remet pas [dejaRejoint] à faux : c'est précisément ce passage
        // par l'échec qui rend le rattrapage nécessaire.
        if (etiquette != null) {
          debugPrint('realtime: « $etiquette » $status ${error ?? ''}');
        }
    }
  };
}
