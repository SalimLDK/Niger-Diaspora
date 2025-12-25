import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/notification_preferences_entity.dart';

abstract class NotificationPreferencesRepository {
  Future<Either<Failure, NotificationPreferencesEntity>> getPreferences(String userId);
  Future<Either<Failure, void>> updatePreferences(
    String userId,
    NotificationPreferencesEntity preferences,
  );
}
