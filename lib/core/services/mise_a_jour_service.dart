import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

/// Clé publique servie par l'Edge Function `app-config` : la version
/// disponible sur les stores, écrite exactement comme la ligne `version:` de
/// `pubspec.yaml` — `1.3.0+20`.
///
/// Elle vit côté serveur, jamais dans l'APK, pour une raison mécanique : un
/// APK ne peut pas savoir qu'il en existe un plus récent que lui. La publier
/// se fait clé par clé :
///
/// ```bash
/// supabase secrets set DERNIERE_VERSION_APP=1.3.0+20
/// ```
///
/// Jamais `secrets set --env-file`, qui remplacerait l'ensemble des secrets du
/// projet par le contenu du fichier.
///
/// Tant que la clé est absente, [CoordinateurMiseAJour] se tait : c'est l'état
/// par défaut, et c'est celui d'aujourd'hui.
const String cleDerniereVersion = 'DERNIERE_VERSION_APP';

/// Une version d'application au format `pubspec.yaml` : un nom (`1.3.0`) et,
/// facultativement, un numéro de build (`+20`).
@immutable
class VersionApp {
  const VersionApp._(this.nom, this.segments, this.build);

  /// Nom affichable, ex. `1.3.0` — ce que la fiche du store montre.
  final String nom;

  /// `1.3.0` → `[1, 3, 0]`.
  final List<int> segments;

  /// Numéro de build (`+20`), ou null s'il n'y en avait pas.
  final int? build;

  static final RegExp _prefixeNumerique = RegExp(r'^\d+(?:\.\d+)*');

  /// Renvoie null sur tout ce qui n'est pas exploitable : chaîne vide, valeur
  /// tronquée, texte libre.
  ///
  /// Un appelant ne doit **jamais** afficher de notice sur une version qu'il
  /// n'a pas su lire — mieux vaut se taire que réclamer une mise à jour qui
  /// n'existe pas.
  static VersionApp? parse(String? brut) {
    final texte = brut?.trim() ?? '';
    if (texte.isEmpty) return null;

    final plus = texte.indexOf('+');
    final nom = (plus == -1 ? texte : texte.substring(0, plus)).trim();
    final build =
        plus == -1 ? null : int.tryParse(texte.substring(plus + 1).trim());

    // `1.3.0-beta.2` → `1.3.0`. Les pré-versions ne s'ordonnent pas
    // numériquement et ce projet n'en publie pas ; on garde le préfixe chiffré,
    // qui lui s'ordonne.
    final numerique = _prefixeNumerique.stringMatch(nom) ?? '';
    if (numerique.isEmpty) return null;

    return VersionApp._(
      nom,
      numerique.split('.').map(int.parse).toList(growable: false),
      build,
    );
  }

  /// Ordre : le **nom** d'abord, le build seulement pour départager deux noms
  /// identiques (`1.2.1+19` → `1.2.1+20`, un correctif sans changement de nom).
  ///
  /// L'inverse — le build d'abord — paraît plus sûr, puisque Play exige un
  /// `versionCode` strictement croissant. Mais il se retourne au premier
  /// compteur remis à zéro : `1.2.1+19` installée contre `1.3.0+5` publiée
  /// conclurait « pas de mise à jour ». Le nom, lui, est ce que l'on
  /// incrémente à la main dans `pubspec.yaml` et ce que le store affiche.
  int compareTo(VersionApp autre) {
    final longueur = math.max(segments.length, autre.segments.length);
    for (var i = 0; i < longueur; i++) {
      final ici = i < segments.length ? segments[i] : 0;
      final la = i < autre.segments.length ? autre.segments[i] : 0;
      if (ici != la) return ici.compareTo(la);
    }
    final a = build;
    final b = autre.build;
    // Un build absent d'un côté ne prouve rien : on conclut à l'égalité, donc
    // à l'absence de notice.
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  @override
  String toString() => build == null ? nom : '$nom+$build';
}

/// Vrai seulement si les deux versions sont lisibles **et** que [publiee] est
/// strictement postérieure à [installee].
///
/// Tout le reste se tait : valeur absente, illisible, égale, ou antérieure —
/// ce dernier cas étant le quotidien d'un build de développement, en avance
/// sur ce qui est publié.
bool miseAJourDisponible({
  required String? installee,
  required String? publiee,
}) {
  final ici = VersionApp.parse(installee);
  final la = VersionApp.parse(publiee);
  if (ici == null || la == null) return false;
  return la.compareTo(ici) > 0;
}

/// Ce que le bandeau de `MainShell` doit dire. `null` = rien à proposer.
@immutable
class NoticeMiseAJour {
  const NoticeMiseAJour({required this.versionPubliee, required this.brut});

  /// Nom affichable de la version disponible, ex. `1.3.0`.
  final String versionPubliee;

  /// La valeur serveur telle quelle. C'est elle qu'on retient sur « Pas
  /// maintenant », pour que la notice se taise sur *cette* version et reparle
  /// à la suivante.
  final String brut;

  /// L'égalité porte sur [brut] : `MainShell` s'en sert pour ne pas reposer un
  /// bandeau identique à chaque rebuild.
  @override
  bool operator ==(Object other) =>
      other is NoticeMiseAJour && other.brut == brut;

  @override
  int get hashCode => brut.hashCode;
}

/// Décide s'il faut proposer une mise à jour, et retient un refus.
///
/// L'UI (cf. `MainShell`) l'observe pour afficher un bandeau non bloquant —
/// même canal que le rappel de sauvegarde des clés E2EE, et même règle : rien
/// ici ne doit pouvoir empêcher l'application de démarrer.
final coordinateurMiseAJourProvider =
    StateNotifierProvider<CoordinateurMiseAJour, NoticeMiseAJour?>(
  (ref) => CoordinateurMiseAJour(),
);

class CoordinateurMiseAJour extends StateNotifier<NoticeMiseAJour?> {
  /// Les trois dépendances sont injectables pour que la décision se teste sans
  /// canal de plateforme ni réseau.
  CoordinateurMiseAJour({
    String? Function()? versionPubliee,
    Future<String?> Function()? versionInstallee,
    Future<SharedPreferences> Function()? preferences,
  })  : _versionPubliee = versionPubliee ?? _versionPublieeParDefaut,
        _versionInstallee = versionInstallee ?? _versionInstalleeParDefaut,
        _preferences = preferences ?? SharedPreferences.getInstance,
        super(null);

  final String? Function() _versionPubliee;
  final Future<String?> Function() _versionInstallee;
  final Future<SharedPreferences> Function() _preferences;

  /// Clé unique, qui porte la version écartée plutôt qu'un booléen. Une clé
  /// par version s'accumulerait dans les préférences sans que rien ne les
  /// efface jamais.
  static const String cleVersionEcartee = 'maj_version_ecartee';

  bool _dejaVerifie = false;

  static String? _versionPublieeParDefaut() =>
      RemoteConfigService.instance.value(cleDerniereVersion);

  static Future<String?> _versionInstalleeParDefaut() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber;
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  /// À appeler une fois, quand le shell est monté.
  ///
  /// Best-effort de bout en bout : aucune branche ne lève, et toutes les
  /// sorties anticipées laissent l'état à `null`, c'est-à-dire « aucune
  /// notice ».
  Future<void> verifie() async {
    if (_dejaVerifie) return;
    _dejaVerifie = true;
    try {
      final publiee = _versionPubliee()?.trim();
      if (publiee == null || publiee.isEmpty) return;

      final installee = await _versionInstallee();
      if (!miseAJourDisponible(installee: installee, publiee: publiee)) return;

      final prefs = await _preferences();
      if (prefs.getString(cleVersionEcartee) == publiee) return;

      state = NoticeMiseAJour(
        versionPubliee: VersionApp.parse(publiee)!.nom,
        brut: publiee,
      );
    } catch (e) {
      debugPrint('CoordinateurMiseAJour: vérification impossible: $e');
    }
  }

  /// « Pas maintenant » : la notice se tait pour cette version-là et reparlera
  /// à la suivante.
  ///
  /// Pas de minuterie, contrairement au rappel E2EE : la personne a répondu
  /// non, et une version plus récente est une question neuve — alors qu'une
  /// sauvegarde de clés manquante reste le même problème une semaine plus
  /// tard.
  void ecarte() {
    final notice = state;
    state = null;
    if (notice == null) return;
    unawaited(_persisteEcart(notice.brut));
  }

  Future<void> _persisteEcart(String brut) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(cleVersionEcartee, brut);
    } catch (e) {
      // Sans persistance, la notice reviendra au prochain démarrage : gênant,
      // jamais bloquant.
      debugPrint('CoordinateurMiseAJour: écart non persisté: $e');
    }
  }

  /// La personne part vers le store. On n'écarte **pas** : si elle revient
  /// sans avoir installé, la notice doit pouvoir reparaître au prochain
  /// démarrage.
  void ouvre() => state = null;
}
