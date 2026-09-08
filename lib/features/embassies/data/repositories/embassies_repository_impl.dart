import '../../domain/entities/embassy_entity.dart';
import '../../domain/repositories/embassies_repository.dart';
import '../datasources/embassies_local_datasource.dart';
import '../datasources/embassies_supabase_datasource.dart';
import '../models/embassy_model.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/errors/exceptions.dart';

/// L'annuaire : Supabase quand le réseau répond, copie locale sinon.
///
/// La copie locale est réécrite à **chaque** lecture distante réussie, et
/// relue sans condition d'âge : quelqu'un qui cherche le numéro de son
/// consulat est souvent précisément celui qui n'a pas de réseau. Une fiche de
/// la semaine dernière vaut mieux qu'un écran vide.
class EmbassiesRepositoryImpl implements EmbassiesRepository {
  final EmbassiesDataSource remoteDataSource;
  final EmbassiesLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  EmbassiesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<List<EmbassyEntity>> getEmbassies() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteEmbassies = await remoteDataSource.getEmbassies();
        await localDataSource.cacheEmbassies(remoteEmbassies);
        return remoteEmbassies.map((e) => e.toEntity()).toList();
      } on ServerException {
        return _fromCache();
      }
    }
    return _fromCache();
  }

  Future<List<EmbassyEntity>> _fromCache() async {
    try {
      final localEmbassies = await localDataSource.getLastEmbassies();
      return localEmbassies.map((e) => e.toEntity()).toList();
    } on CacheException {
      return [];
    }
  }

  @override
  Future<DateTime?> cachedAt() => localDataSource.cachedAt();

  @override
  Future<EmbassyEntity?> getEmbassyById(String id) async {
    // La fiche vient de la liste déjà chargée : c'est la seule voie qui marche
    // hors ligne, et l'annuaire tient en une trentaine de lignes.
    final embassies = await getEmbassies();
    for (final embassy in embassies) {
      if (embassy.id == id) return embassy;
    }

    // Absente du cache : tenter le distant, au cas où la fiche serait plus
    // récente que la dernière copie locale.
    if (await networkInfo.isConnected) {
      try {
        final model = await remoteDataSource.getEmbassyById(id);
        return model?.toEntity();
      } on ServerException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<List<EmbassyEntity>> searchEmbassies(String query) async {
    // Filtrage local plutôt qu'un aller-retour réseau : la liste est courte,
    // le résultat est instantané, et la recherche continue de fonctionner
    // hors ligne.
    final embassies = await getEmbassies();
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return embassies;

    return embassies.where((e) {
      return e.name.toLowerCase().contains(lowerQuery) ||
          e.country.toLowerCase().contains(lowerQuery) ||
          e.city.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) async {
    await remoteDataSource.updateEmbassyStatus(
      id,
      isVerified: isVerified,
      isSuspended: isSuspended,
      rejectionReason: rejectionReason,
    );
    // Le cache porte encore l'ancien statut : le vider force la prochaine
    // lecture à repasser par Supabase.
    await localDataSource.clear();
  }

  @override
  Future<String> createEmbassy(EmbassyEntity embassy) async {
    final id = await remoteDataSource.createEmbassy(
      EmbassyModel.fromEntity(embassy),
    );
    await localDataSource.clear();
    return id;
  }
}
