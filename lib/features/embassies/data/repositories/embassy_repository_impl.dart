import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/errors/exceptions.dart';
import '../datasources/embassy_remote_datasource.dart';
import '../datasources/embassies_local_datasource.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../domain/repositories/embassy_repository.dart';

class EmbassyRepositoryImpl implements EmbassyRepository {
  final EmbassyRemoteDataSource remoteDataSource;
  final EmbassiesLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  EmbassyRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<EmbassyEntity>>> getEmbassies() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteEmbassies = await remoteDataSource.getEmbassies();
        await localDataSource.cacheEmbassies(remoteEmbassies);
        return Right(remoteEmbassies.map((e) => e.toEntity()).toList());
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      try {
        final localEmbassies = await localDataSource.getLastEmbassies();
        return Right(localEmbassies.map((e) => e.toEntity()).toList());
      } on CacheException {
        return const Left(CacheFailure('Pas de données en cache'));
      }
    }
  }
}
