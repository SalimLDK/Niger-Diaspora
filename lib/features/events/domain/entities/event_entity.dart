import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_entity.freezed.dart';

@freezed
class EventEntity with _$EventEntity {
  const factory EventEntity({
    required String id,
    required String title,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required String location,
    String? address,
    String? country,
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
    @Default(EventCategory.other) EventCategory category,
    @Default(EventStatus.upcoming) EventStatus status,
    DateTime? createdAt,
    @Default([]) List<String> recapPhotoUrls,
    String? recapDescription,
    DateTime? recapCreatedAt,
  }) = _EventEntity;
}

enum EventCategory {
  networking,
  cultural,
  business,
  educational,
  sports,
  charity,
  social,
  other,
}

enum EventStatus { upcoming, ongoing, completed, cancelled }

extension EventCategoryExtension on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.networking:
        return 'Networking';
      case EventCategory.cultural:
        return 'Culturel';
      case EventCategory.business:
        return 'Business';
      case EventCategory.educational:
        return 'Educatif';
      case EventCategory.sports:
        return 'Sport';
      case EventCategory.charity:
        return 'Caritatif';
      case EventCategory.social:
        return 'Social';
      case EventCategory.other:
        return 'Autre';
    }
  }
}

extension EventStatusExtension on EventStatus {
  String get label {
    switch (this) {
      case EventStatus.upcoming:
        return 'A venir';
      case EventStatus.ongoing:
        return 'En cours';
      case EventStatus.completed:
        return 'Termine';
      case EventStatus.cancelled:
        return 'Annule';
    }
  }
}
