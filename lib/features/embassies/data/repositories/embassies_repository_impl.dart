import '../../domain/entities/embassy_entity.dart';
import '../../domain/repositories/embassies_repository.dart';
import '../datasources/embassies_local_datasource.dart';
import '../datasources/embassy_remote_datasource.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/errors/exceptions.dart';

class EmbassiesRepositoryImpl implements EmbassiesRepository {
  final EmbassyRemoteDataSource remoteDataSource;
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
        // If remote fails, try cache
        try {
          final localEmbassies = await localDataSource.getLastEmbassies();
          return localEmbassies.map((e) => e.toEntity()).toList();
        } on CacheException {
          return [];
        }
      }
    } else {
      try {
        final localEmbassies = await localDataSource.getLastEmbassies();
        return localEmbassies.map((e) => e.toEntity()).toList();
      } on CacheException {
        return [];
      }
    }
  }

  @override
  Future<EmbassyEntity?> getEmbassyById(String id) async {
    final embassies = await getEmbassies();
    try {
      return embassies.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EmbassyEntity>> searchEmbassies(String query) async {
    final embassies = await getEmbassies();
    final lowerQuery = query.toLowerCase();
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
    // This would call remote data source in production
    // For now, just update local cache
    try {
      await remoteDataSource.updateEmbassyStatus(
        id,
        isVerified: isVerified,
        isSuspended: isSuspended,
        rejectionReason: rejectionReason,
      );
    } catch (_) {
      // If remote fails, we can't update
      rethrow;
    }
  }
}
