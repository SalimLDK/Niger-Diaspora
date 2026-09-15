import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'mise_a_jour_service.dart';
import 'remote_config_service.dart';

/// Version **en deçà de laquelle** l'application refuse de fonctionner, servie
/// par l'Edge Function `app-config` :
///
/// ```bash
/// supabase secrets set VERSION_MINIMALE_APP=1.3.0+21
/// ```
///
/// Tant que la clé est absente, rien ne bloque — et c'est l'état d'aujourd'hui.
/// Jamais `secrets set --env-file`, qui remplacerait tous les secrets du
/// projet.
const String cleVersionMinimale = 'VERSION_MINIMALE_APP';

/// Faut-il **refuser de démarrer** ?
///
/// À distinguer de [miseAJourDisponible], qui ne fait que proposer : ici, on
/// ferme la porte. La différence de nature impose des gardes que la notice
/// n'a pas besoin d'avoir — parce que la panne, elle, n'est pas symétrique.
/// Une notice qui manque coûte une mise à jour tardive ; un blocage de trop
/// rend l'application inutilisable pour **tout le monde**, sans recours, et
/// sans qu'on puisse le corriger autrement qu'en republiant une configuration
/// que les appareils bloqués iront quand même chercher.
///
/// D'où quatre refus de bloquer, dans l'ordre :
///
/// 1. **Pas de version minimale** — l'état par défaut ;
/// 2. **version minimale illisible** — une faute de frappe ne doit pas
///    fermer l'application ;
/// 3. **version installée illisible** — on ne ferme jamais la porte sur sa
///    propre ignorance ;
/// 4. **la version minimale n'existe pas encore sur les stores**
///    (`publiee < minimale`, ou `publiee` illisible) — c'est le garde qui
///    compte le plus : il rend inoffensive la faute la plus probable, exiger
///    une version que personne ne peut installer. Sans lui, un `1.4.0` posé
///    trop tôt bloquerait tout le monde devant un store qui n'offre que
///    `1.3.0`.
///
/// L'égalité ne bloque pas : `installee == minimale` est la version exigée.
///
/// Format accepté pour [minimale], et lui seul : `1.3.0` ou `1.3.0+21`.
final RegExp _formatStrict = RegExp(r'^\d+(?:\.\d+)*(?:\+\d+)?$');

bool miseAJourObligatoire({
  required String? installee,
  required String? minimale,
  required String? publiee,
}) {
  // **Lecture stricte, contrairement au reste du projet.** `VersionApp.parse`
  // est tolérant par choix : il lit le préfixe numérique et ignore la suite,
  // si bien que `1.2.x` devient `1.2`. Cette indulgence convient à une notice,
  // qui au pire s'affiche de travers. Elle ne convient pas ici : un verrou qui
  // DEVINE ce qu'on a voulu écrire finit par fermer l'application sur une
  // faute de frappe. Trouvé en écrivant le test, pas en relisant le code.
  if (minimale == null || !_formatStrict.hasMatch(minimale.trim())) {
    return false;
  }

  final exigee = VersionApp.parse(minimale);
  if (exigee == null) return false;

  final ici = VersionApp.parse(installee);
  if (ici == null) return false;

  if (ici.compareTo(exigee) >= 0) return false;

  // Y a-t-il seulement une issue ? Si le store ne sert pas encore la version
  // exigée, bloquer enfermerait sans porte de sortie.
  final surLeStore = VersionApp.parse(publiee);
  if (surLeStore == null) return false;
  if (surLeStore.compareTo(exigee) < 0) return false;

  return true;
}

/// Vrai quand cette installation est trop ancienne pour continuer.
///
/// Calculé une fois au démarrage du shell, puis relu : la valeur ne peut que
/// passer de `false` à `true` (une configuration serveur qui change), jamais
/// dans l'autre sens sans redémarrage — et ce n'est pas gênant, personne ne
/// rajeunit son APK en cours de route.
final versionTropAncienneProvider =
    StateNotifierProvider<VerrouVersionMinimale, bool>(
  (ref) => VerrouVersionMinimale(),
);

class VerrouVersionMinimale extends StateNotifier<bool> {
  VerrouVersionMinimale({
    String? Function()? versionMinimale,
    String? Function()? versionPubliee,
    Future<String?> Function()? versionInstallee,
  })  : _versionMinimale = versionMinimale ?? _minimaleParDefaut,
        _versionPubliee = versionPubliee ?? _publieeParDefaut,
        _versionInstallee = versionInstallee ?? _installeeParDefaut,
        super(false);

  final String? Function() _versionMinimale;
  final String? Function() _versionPubliee;
  final Future<String?> Function() _versionInstallee;

  static String? _minimaleParDefaut() =>
      RemoteConfigService.instance.value(cleVersionMinimale);

  static String? _publieeParDefaut() =>
      RemoteConfigService.instance.value(cleDerniereVersion);

  static Future<String?> _installeeParDefaut() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber;
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  /// Best-effort de bout en bout : **toute** exception laisse l'état à
  /// `false`. Une vérification qui échoue ne doit jamais fermer
  /// l'application — c'est la règle du § ci-dessus, appliquée aussi aux
  /// pannes.
  Future<void> verifie() async {
    try {
      state = miseAJourObligatoire(
        installee: await _versionInstallee(),
        minimale: _versionMinimale(),
        publiee: _versionPubliee(),
      );
    } catch (e) {
      debugPrint('VerrouVersionMinimale: vérification impossible: $e');
      state = false;
    }
  }
}
