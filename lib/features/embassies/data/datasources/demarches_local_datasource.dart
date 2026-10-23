import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/demarche_model.dart';

const String cachedDemarchesCatalogue = 'CACHED_DEMARCHES_CATALOGUE';
const String cachedDemarchesCatalogueLe = 'CACHED_DEMARCHES_CATALOGUE_LE';

/// Les deux sources locales du catalogue des démarches.
///
/// [getCachedCatalogue] rend le dernier chargement Supabase réussi ;
/// [getBundledCatalogue] rend la copie embarquée dans l'APK. Cette dernière
/// n'est pas un simple filet : c'est elle qui fait qu'un usager hors ligne
/// à sa toute première ouverture voit quand même les pièces à réunir — le
/// cas le plus courant pour une diaspora en connexion instable.
class DemarchesLocalDataSource {
  /// Copie embarquée, déclarée dans `pubspec.yaml` sous `assets/data/`.
  static const String assetPath = 'assets/data/demarches_consulaires.json';

  Future<void> cacheCatalogue(DemarchesCatalogue catalogue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedDemarchesCatalogue,
      jsonEncode(catalogue.toJson()),
    );
    await prefs.setString(
      cachedDemarchesCatalogueLe,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Quand le cache a été écrit ; nul pour un cache d'une version qui ne le
  /// datait pas. Une démarche dépubliée reste lisible hors ligne jusqu'à la
  /// prochaine synchronisation : l'usager doit voir de quand date sa liste.
  Future<DateTime?> getCacheDate() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(cachedDemarchesCatalogueLe);
    return brut == null ? null : DateTime.tryParse(brut)?.toLocal();
  }

  /// Dernier catalogue chargé depuis Supabase.
  ///
  /// Lève [CacheException] si rien n'a encore été mis en cache, ou si le
  /// contenu stocké n'est plus lisible — une version antérieure de l'app a
  /// pu y écrire une forme différente, et un cache illisible ne doit jamais
  /// empêcher le repli sur l'asset embarqué.
  Future<DemarchesCatalogue> getCachedCatalogue() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(cachedDemarchesCatalogue);
    if (brut == null) {
      throw CacheException('Aucun catalogue des démarches en cache');
    }
    try {
      return DemarchesCatalogue.fromJson(
        jsonDecode(brut) as Map<String, dynamic>,
      );
    } catch (e) {
      throw CacheException('Catalogue des démarches en cache illisible : $e');
    }
  }

  /// Copie embarquée dans l'APK. Toujours disponible, jamais périmée au
  /// point d'être fausse : elle est régénérée à chaque livraison.
  Future<DemarchesCatalogue> getBundledCatalogue() async {
    final brut = await rootBundle.loadString(assetPath);
    return DemarchesCatalogue.fromJson(
      jsonDecode(brut) as Map<String, dynamic>,
    );
  }
}
