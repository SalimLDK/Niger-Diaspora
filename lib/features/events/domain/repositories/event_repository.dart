import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/event_entity.dart';

abstract class EventRepository {
  Future<Either<Failure, List<EventEntity>>> getEvents();
  Future<Either<Failure, List<EventEntity>>> getUpcomingEvents();
  Future<Either<Failure, List<EventEntity>>> getPastEvents();
  Future<Either<Failure, List<EventEntity>>> getEventsByCategory(
    EventCategory category,
  );
  Future<Either<Failure, EventEntity>> getEventById(String eventId);
  Future<Either<Failure, EventEntity>> createEvent(EventEntity event);
  Future<Either<Failure, EventEntity>> updateEvent(EventEntity event);
  Future<Either<Failure, void>> deleteEvent(String eventId);
  Future<Either<Failure, void>> attendEvent(String eventId, String userId);
  Future<Either<Failure, void>> cancelAttendance(String eventId, String userId);
  Future<Either<Failure, List<EventEntity>>> getMyEvents(String userId);
  Future<Either<Failure, List<EventEntity>>> getAttendingEvents(String userId);

  // Photo management
  Future<Either<Failure, String>> uploadEventPoster(
    String eventId,
    String imagePath,
  );
  Future<Either<Failure, void>> deleteEventPoster(
    String eventId,
    String imageUrl,
  );
  Future<Either<Failure, String>> uploadRecapPhoto(
    String eventId,
    String imagePath,
  );
  Future<Either<Failure, void>> updateEventRecap(
    String eventId,
    List<String> photoUrls,
    String description,
  );
}
