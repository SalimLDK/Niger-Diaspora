import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version de l'application, lue sur le paquet installé.
///
/// Elle était écrite « 1.2.0 » en dur à trois endroits (Réglages ×2, Profil).
/// Juste au moment où elle a été saisie, fausse à la publication suivante :
/// personne ne pense à mettre à jour trois chaînes littérales en même temps
/// que `pubspec.yaml`. Le numéro vient maintenant du build lui-même.
class AppVersionService {
  AppVersionService._();

  static String? _cached;

  /// Version affichable, ex. `1.2.0 (10)`.
  ///
  /// Le premier appel lit le paquet ; les suivants servent le cache. Renvoie
  /// une chaîne vide si l'information n'est pas disponible — l'appelant doit
  /// alors masquer la ligne plutôt qu'afficher un numéro inventé.
  static Future<String> displayVersion() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber;
      final value = build.isEmpty ? info.version : '${info.version} ($build)';
      _cached = value;
      return value;
    } catch (e) {
      debugPrint('AppVersionService: lecture de la version impossible: $e');
      return '';
    }
  }
}

/// Version affichable de l'app. Vide tant qu'elle n'est pas lue, ou si la
/// lecture échoue : les écrans masquent alors la ligne.
final appVersionProvider = FutureProvider<String>(
  (ref) => AppVersionService.displayVersion(),
);

/// Libellé « Version 1.2.3 », ou « Version » seul tant que la lecture n'a pas
/// abouti — on n'affiche jamais un numéro inventé. Fonction pure : Profil et
/// Réglages en tenaient chacun une copie couplée à `ref`.
String appVersionLabel(AppLocalizations l10n, String version) =>
    version.isEmpty ? l10n.version : '${l10n.version} $version';
