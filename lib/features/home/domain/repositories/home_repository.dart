import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/home_content.dart';

/// Interface du repository Home
abstract class HomeRepository {
  /// Récupère le contenu de la page d'accueil
  Future<Either<Failure, HomeContent>> getHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
    int nearbyMembersLimit = 10,
    int upcomingEventsLimit = 5,
  });

  /// Récupère les statistiques uniquement
  Future<Either<Failure, HomeStats>> getHomeStats({
    required String userId,
  });

  /// Récupère les membres proches
  Future<Either<Failure, List<NearbyMember>>> getNearbyMembers({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  });

  /// Récupère les événements à venir
  Future<Either<Failure, List<UpcomingEvent>>> getUpcomingEvents({
    required String userId,
    int limit = 10,
  });

  /// Rafraîchit le contenu depuis le serveur
  Future<Either<Failure, HomeContent>> refreshHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
  });
}
