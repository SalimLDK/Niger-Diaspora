import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_remote_datasource.dart';
import '../models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;

  EventRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    CacheService? cacheService,
  }) : cacheService = cacheService ?? CacheService.instance;

  @override
  Either<Failure, List<EventEntity>> getCachedEvents() {
    try {
      final cachedData = cacheService.getAllCachedEvents();
      final entities =
          cachedData
              .map((data) => EventModel.fromJson(data).toEntity())
              .toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getEvents() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getEvents();
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getUpcomingEvents() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getUpcomingEvents();
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getEventsByCategory(
    EventCategory category,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getEventsByCategory(category.name);
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getEventsByGroup(
    String groupId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getEventsByGroup(groupId);
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, EventEntity>> getEventById(String eventId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final event = await remoteDataSource.getEventById(eventId);
      return Right(event.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, EventEntity>> createEvent(EventEntity event) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final eventModel = EventModel.fromEntity(event);
      final created = await remoteDataSource.createEvent(eventModel);
      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, EventEntity>> updateEvent(EventEntity event) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final eventModel = EventModel.fromEntity(event);
      final updated = await remoteDataSource.updateEvent(eventModel);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEvent(String eventId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.deleteEvent(eventId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> attendEvent(
    String eventId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      // Get event details to know who to notify
      final event = await remoteDataSource.getEventById(eventId);

      await remoteDataSource.attendEvent(eventId, userId);

      // Only notify if the attendee is not the organizer
      if (event.organizerId != userId) {
        // Le nom du participant, lu dans `public.users`.
        //
        // Il venait de Firestore (`users/<uid>.displayName`) alors que les
        // comptes vivent sur Supabase : le document n'existait pas, `exists`
        // rendait `false`, et la notification annonçait « Un utilisateur
        // participera à … » — signalé par Salim le 2026-09-09, dès que
        // « Participer » a recommencé à fonctionner. Le repli masquait la
        // panne au lieu de la signaler, c'est pour ça qu'elle a duré.
        String userName = 'Un utilisateur';
        try {
          await SupabaseAuthBridge.instance.ensureAuthenticated();
          final row = await Supabase.instance.client
              .from('users')
              .select('display_name')
              .eq('id', userId)
              .maybeSingle();
          final nom = row?['display_name'] as String?;
          if (nom != null && nom.trim().isNotEmpty) userName = nom;
        } catch (_) {
          // Un nom illisible ne doit pas empêcher l'inscription d'aboutir :
          // la notification part avec le libellé générique.
        }

        // Notify the event organizer
        await NotificationService().createNotification(
          userId: event.organizerId,
          title: 'Nouvelle participation',
          body: '$userName participera à "${event.title}"',
          type: 'eventAttendance',
          targetId: eventId,
          data: {
            'eventId': eventId,
            'eventTitle': event.title,
            'attendeeId': userId,
            'attendeeName': userName,
          },
        );
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> cancelAttendance(
    String eventId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.cancelAttendance(eventId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getMyEvents(String userId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getMyEvents(userId);
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getAttendingEvents(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getAttendingEvents(userId);
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventEntity>>> getPastEvents() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final events = await remoteDataSource.getPastEvents();
      return Right(events.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadEventPoster(
    String eventId,
    String imagePath,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final url = await remoteDataSource.uploadEventPoster(eventId, imagePath);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEventPoster(
    String eventId,
    String imageUrl,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.deleteEventPoster(eventId, imageUrl);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadRecapPhoto(
    String eventId,
    String imagePath,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final url = await remoteDataSource.uploadRecapPhoto(eventId, imagePath);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateEventRecap(
    String eventId,
    List<String> photoUrls,
    String description,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.updateEventRecap(eventId, photoUrls, description);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
