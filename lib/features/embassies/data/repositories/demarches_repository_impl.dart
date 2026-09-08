import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/network_info.dart';
import '../datasources/demarches_local_datasource.dart';
import '../datasources/demarches_remote_datasource.dart';
import '../models/demarche_model.dart';

/// Origine effective du catalogue rendu, pour que l'écran puisse le dire.
///
/// Un usager qui lit des pièces vieilles de plusieurs mois doit pouvoir le
/// savoir : afficher du cache sans le signaler, c'est présenter une donnée
/// périmée avec la même autorité qu'une donnée fraîche.
enum OrigineCatalogue {
  /// Chargé à l'instant depuis Supabase.
  serveur,

  /// Dernier chargement serveur réussi, relu hors ligne.
  cache,

  /// Copie embarquée dans l'APK — le serveur n'a jamais répondu sur cet
  /// appareil.
  embarque,
}

class CatalogueCharge {
  final DemarchesCatalogue catalogue;
  final OrigineCatalogue origine;

  const CatalogueCharge(this.catalogue, this.origine);
}

/// Chargement du catalogue des démarches, du plus frais au plus sûr :
/// Supabase, puis le cache du dernier chargement réussi, puis la copie
/// embarquée.
///
/// Pas d'interface de domaine ici : une seule implémentation, en lecture
/// seule, dont les deux sources sont déjà les points d'injection utiles pour
/// un test. Une abstraction de plus n'ajouterait qu'une indirection.
class DemarchesRepositoryImpl {
  final DemarchesRemoteDataSource remoteDataSource;
  final DemarchesLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  DemarchesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  Future<CatalogueCharge> getCatalogue() async {
    if (await networkInfo.isConnected) {
      try {
        final distant = await remoteDataSource.getCatalogue();
        await localDataSource.cacheCatalogue(distant);
        return CatalogueCharge(distant, OrigineCatalogue.serveur);
      } on ServerException {
        return _depuisLeLocal();
      }
    }
    return _depuisLeLocal();
  }

  /// Cache d'abord, asset embarqué ensuite — sauf si l'APK est plus récent.
  ///
  /// Le cas se produit quand l'app est mise à jour alors que l'appareil est
  /// hors ligne : le cache porte alors le catalogue de la version précédente
  /// tandis que l'APK embarque déjà le nouveau. Comparer les `version` évite
  /// de servir l'ancien par simple priorité de rang.
  Future<CatalogueCharge> _depuisLeLocal() async {
    DemarchesCatalogue? enCache;
    try {
      enCache = await localDataSource.getCachedCatalogue();
    } on CacheException {
      enCache = null;
    }

    DemarchesCatalogue? embarque;
    try {
      embarque = await localDataSource.getBundledCatalogue();
    } catch (_) {
      // Asset absent ou illisible : ne doit pas masquer un cache valide.
      embarque = null;
    }

    if (enCache != null && embarque != null) {
      return embarque.version > enCache.version
          ? CatalogueCharge(embarque, OrigineCatalogue.embarque)
          : CatalogueCharge(enCache, OrigineCatalogue.cache);
    }
    if (enCache != null) {
      return CatalogueCharge(enCache, OrigineCatalogue.cache);
    }
    if (embarque != null) {
      return CatalogueCharge(embarque, OrigineCatalogue.embarque);
    }
    throw CacheException(
      'Aucune source disponible pour le catalogue des démarches',
    );
  }
}
