// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationPreferencesModelImpl _$$NotificationPreferencesModelImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationPreferencesModelImpl(
  messages: json['messages'] as bool? ?? true,
  newEvents: json['newEvents'] as bool? ?? true,
  groupActivity: json['groupActivity'] as bool? ?? true,
  eventReminders: json['eventReminders'] as bool? ?? true,
  localEvents: json['localEvents'] as bool? ?? true,
  systemMessages: json['systemMessages'] as bool? ?? false,
);

Map<String, dynamic> _$$NotificationPreferencesModelImplToJson(
  _$NotificationPreferencesModelImpl instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'newEvents': instance.newEvents,
  'groupActivity': instance.groupActivity,
  'eventReminders': instance.eventReminders,
  'localEvents': instance.localEvents,
  'systemMessages': instance.systemMessages,
};
