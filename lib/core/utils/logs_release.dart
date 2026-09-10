/// Fait taire toute sortie console en build release.
///
/// `print` **et** `debugPrint` écrivent en release — la doc du SDK le dit pour
/// le second (`foundation/print.dart` : « logs to console even in release
/// mode »), et le premier n'a jamais prétendu le contraire. Sur un APK de
/// production, les deux atterrissent dans logcat sous le tag `flutter`,
/// lisibles par quiconque branche l'appareil.
///
/// Deux verrous, volontairement redondants :
///
/// 1. **`debugPrint` réassigné.** C'est une *variable* du SDK
///    (`DebugPrintCallback debugPrint = debugPrintThrottled;`), pas une
///    fonction : lui donner un corps vide neutralise d'un coup les ~920 appels
///    de `lib/`, sans en toucher un seul, et leur épargne le découpage et le
///    throttling de `debugPrintThrottled`.
/// 2. **La zone avale `print`.** C'est le filet qui rattrape ce que le verrou 1
///    ne peut pas voir : un `print()` brut ajouté par mégarde, et surtout les
///    **paquets tiers**, dont le code ne nous appartient pas.
///
/// `debugPrint` passant par `print`, le verrou 2 couvrirait déjà le verrou 1.
/// Les deux sont conservés : le premier évite le travail, le second garantit
/// le résultat.
///
/// ⚠️ Ce que ça ne fait pas : les chaînes de format restent dans le binaire et
/// leurs arguments sont toujours évalués — seule la **sortie** disparaît. Un
/// log qui ne doit pas exister du tout (valeur de jeton, coordonnées GPS) se
/// supprime à la source, jamais ici.
///
/// Le mode **profile** n'est pas couvert (`kReleaseMode` y est faux),
/// volontairement : un APK de profilage ne se distribue pas, et ses logs
/// servent au diagnostic.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Zone qui jette toute sortie `print` — donc aussi `debugPrint`, qui y passe.
///
/// Exposée pour que le test puisse vérifier le mécanisme sans dépendre de
/// `kReleaseMode`, qui est toujours faux sous `flutter test`.
ZoneSpecification zoneSansSortieConsole() => ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        // Rien : c'est tout l'intérêt.
      },
    );

/// Lance [demarrage] en avalant toute sortie console si le build est release.
///
/// Hors release, [demarrage] est appelé tel quel, dans la zone courante : les
/// logs de développement sont intacts.
///
/// `WidgetsFlutterBinding.ensureInitialized()` et `runApp` doivent vivre dans
/// la **même** zone, sinon Flutter refuse de démarrer. C'est le cas ici : les
/// deux sont à l'intérieur de [demarrage], donc de la même zone dans les deux
/// branches.
Future<void> demarrerSansLogsEnRelease(Future<void> Function() demarrage) {
  if (!kReleaseMode) return demarrage();

  debugPrint = (String? message, {int? wrapWidth}) {};
  return runZoned(demarrage, zoneSpecification: zoneSansSortieConsole());
}
