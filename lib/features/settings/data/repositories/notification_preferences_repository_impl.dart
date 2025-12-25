import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_preferences_entity.dart';
import '../../domain/repositories/notification_preferences_repository.dart';
import '../datasources/notification_preferences_datasource.dart';
import '../models/notification_preferences_model.dart';

class NotificationPreferencesRepositoryImpl implements NotificationPreferencesRepository {
  final NotificationPreferencesDataSource dataSource;

  NotificationPreferencesRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> getPreferences(String userId) async {
    try {
      final model = await dataSource.getPreferences(userId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePreferences(
    String userId,
    NotificationPreferencesEntity preferences,
  ) async {
    try {
      final model = NotificationPreferencesModel.fromEntity(preferences);
      await dataSource.updatePreferences(userId, model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
