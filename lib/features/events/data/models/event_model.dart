import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/event_entity.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

@freezed
class EventModel with _$EventModel {
  const EventModel._();

  const factory EventModel({
    required String id,
    required String title,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required String location,
    String? address,
    double? latitude,
    double? longitude,
    required String organizerId,
    String? organizerName,
    String? organizerPhotoUrl,
    @Default([]) List<String> posterUrls,
    @Default([]) List<String> attendeeIds,
    @Default(0) int maxAttendees,
    @Default(false) bool isOnline,
    String? onlineLink,
    @Default('other') String category,
    @Default('upcoming') String status,
    DateTime? createdAt,
    @Default([]) List<String> recapPhotoUrls,
    String? recapDescription,
    DateTime? recapCreatedAt,
  }) = _EventModel;

  factory EventModel.fromJson(Map<String, dynamic> json) =>
      _$EventModelFromJson(json);

  EventEntity toEntity() => EventEntity(
    id: id,
    title: title,
    description: description,
    startDate: startDate,
    endDate: endDate,
    location: location,
    address: address,
    latitude: latitude,
    longitude: longitude,
    organizerId: organizerId,
    organizerName: organizerName,
    organizerPhotoUrl: organizerPhotoUrl,
    posterUrls: posterUrls,
    attendeeIds: attendeeIds,
    maxAttendees: maxAttendees,
    isOnline: isOnline,
    onlineLink: onlineLink,
    category: _parseCategory(category),
    status: _parseStatus(status),
    createdAt: createdAt,
    recapPhotoUrls: recapPhotoUrls,
    recapDescription: recapDescription,
    recapCreatedAt: recapCreatedAt,
  );

  static EventCategory _parseCategory(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventCategory.other,
    );
  }

  static EventStatus _parseStatus(String value) {
    return EventStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventStatus.upcoming,
    );
  }

  factory EventModel.fromEntity(EventEntity entity) => EventModel(
    id: entity.id,
    title: entity.title,
    description: entity.description,
    startDate: entity.startDate,
    endDate: entity.endDate,
    location: entity.location,
    address: entity.address,
    latitude: entity.latitude,
    longitude: entity.longitude,
    organizerId: entity.organizerId,
    organizerName: entity.organizerName,
    organizerPhotoUrl: entity.organizerPhotoUrl,
    posterUrls: entity.posterUrls,
    attendeeIds: entity.attendeeIds,
    maxAttendees: entity.maxAttendees,
    isOnline: entity.isOnline,
    onlineLink: entity.onlineLink,
    category: entity.category.name,
    status: entity.status.name,
    createdAt: entity.createdAt,
    recapPhotoUrls: entity.recapPhotoUrls,
    recapDescription: entity.recapDescription,
    recapCreatedAt: entity.recapCreatedAt,
  );
}
