import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_preferences_entity.freezed.dart';

@freezed
class NotificationPreferencesEntity with _$NotificationPreferencesEntity {
  const factory NotificationPreferencesEntity({
    @Default(true) bool messages,
    @Default(true) bool newEvents,
    @Default(true) bool groupActivity,
    @Default(true) bool eventReminders,
    @Default(true) bool localEvents, // Notifications for events in my city
    @Default(false) bool systemMessages, // Notifications for system messages
  }) = _NotificationPreferencesEntity;
}
