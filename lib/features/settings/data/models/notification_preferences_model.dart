import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/notification_preferences_entity.dart';

part 'notification_preferences_model.freezed.dart';
part 'notification_preferences_model.g.dart';

@freezed
class NotificationPreferencesModel with _$NotificationPreferencesModel {
  const NotificationPreferencesModel._();

  const factory NotificationPreferencesModel({
    @Default(true) bool messages,
    @Default(true) bool newEvents,
    @Default(true) bool groupActivity,
    @Default(true) bool eventReminders,
  }) = _NotificationPreferencesModel;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesModelFromJson(json);

  NotificationPreferencesEntity toEntity() => NotificationPreferencesEntity(
        messages: messages,
        newEvents: newEvents,
        groupActivity: groupActivity,
        eventReminders: eventReminders,
      );

  static NotificationPreferencesModel fromEntity(NotificationPreferencesEntity entity) =>
      NotificationPreferencesModel(
        messages: entity.messages,
        newEvents: entity.newEvents,
        groupActivity: entity.groupActivity,
        eventReminders: entity.eventReminders,
      );
}
