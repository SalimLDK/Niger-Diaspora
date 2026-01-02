import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/home_content.dart';
import '../repositories/home_repository.dart';

/// Use case pour récupérer le contenu de la page d'accueil
class GetHomeContent {
  final HomeRepository repository;

  GetHomeContent(this.repository);

  Future<Either<Failure, HomeContent>> call({
    required String userId,
    double? latitude,
    double? longitude,
    int nearbyMembersLimit = 10,
    int upcomingEventsLimit = 5,
  }) {
    return repository.getHomeContent(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      nearbyMembersLimit: nearbyMembersLimit,
      upcomingEventsLimit: upcomingEventsLimit,
    );
  }
}

/// Use case pour récupérer les membres proches
class GetNearbyMembers {
  final HomeRepository repository;

  GetNearbyMembers(this.repository);

  Future<Either<Failure, List<NearbyMember>>> call({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  }) {
    return repository.getNearbyMembers(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
    );
  }
}

/// Use case pour récupérer les événements à venir
class GetUpcomingEvents {
  final HomeRepository repository;

  GetUpcomingEvents(this.repository);

  Future<Either<Failure, List<UpcomingEvent>>> call({
    required String userId,
    int limit = 10,
  }) {
    return repository.getUpcomingEvents(
      userId: userId,
      limit: limit,
    );
  }
}

/// Use case pour rafraîchir le contenu
class RefreshHomeContent {
  final HomeRepository repository;

  RefreshHomeContent(this.repository);

  Future<Either<Failure, HomeContent>> call({
    required String userId,
    double? latitude,
    double? longitude,
  }) {
    return repository.refreshHomeContent(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
