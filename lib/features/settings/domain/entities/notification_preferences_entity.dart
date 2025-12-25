import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_preferences_entity.freezed.dart';

@freezed
class NotificationPreferencesEntity with _$NotificationPreferencesEntity {
  const factory NotificationPreferencesEntity({
    @Default(true) bool messages,
    @Default(true) bool newEvents,
    @Default(true) bool groupActivity,
    @Default(true) bool eventReminders,
  }) = _NotificationPreferencesEntity;
}
