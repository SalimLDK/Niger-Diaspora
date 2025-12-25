// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preferences_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NotificationPreferencesEntity {
  bool get messages => throw _privateConstructorUsedError;
  bool get newEvents => throw _privateConstructorUsedError;
  bool get groupActivity => throw _privateConstructorUsedError;
  bool get eventReminders => throw _privateConstructorUsedError;

  /// Create a copy of NotificationPreferencesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationPreferencesEntityCopyWith<NotificationPreferencesEntity>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationPreferencesEntityCopyWith<$Res> {
  factory $NotificationPreferencesEntityCopyWith(
    NotificationPreferencesEntity value,
    $Res Function(NotificationPreferencesEntity) then,
  ) =
      _$NotificationPreferencesEntityCopyWithImpl<
        $Res,
        NotificationPreferencesEntity
      >;
  @useResult
  $Res call({
    bool messages,
    bool newEvents,
    bool groupActivity,
    bool eventReminders,
  });
}

/// @nodoc
class _$NotificationPreferencesEntityCopyWithImpl<
  $Res,
  $Val extends NotificationPreferencesEntity
>
    implements $NotificationPreferencesEntityCopyWith<$Res> {
  _$NotificationPreferencesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationPreferencesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? newEvents = null,
    Object? groupActivity = null,
    Object? eventReminders = null,
  }) {
    return _then(
      _value.copyWith(
            messages:
                null == messages
                    ? _value.messages
                    : messages // ignore: cast_nullable_to_non_nullable
                        as bool,
            newEvents:
                null == newEvents
                    ? _value.newEvents
                    : newEvents // ignore: cast_nullable_to_non_nullable
                        as bool,
            groupActivity:
                null == groupActivity
                    ? _value.groupActivity
                    : groupActivity // ignore: cast_nullable_to_non_nullable
                        as bool,
            eventReminders:
                null == eventReminders
                    ? _value.eventReminders
                    : eventReminders // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationPreferencesEntityImplCopyWith<$Res>
    implements $NotificationPreferencesEntityCopyWith<$Res> {
  factory _$$NotificationPreferencesEntityImplCopyWith(
    _$NotificationPreferencesEntityImpl value,
    $Res Function(_$NotificationPreferencesEntityImpl) then,
  ) = __$$NotificationPreferencesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool messages,
    bool newEvents,
    bool groupActivity,
    bool eventReminders,
  });
}

/// @nodoc
class __$$NotificationPreferencesEntityImplCopyWithImpl<$Res>
    extends
        _$NotificationPreferencesEntityCopyWithImpl<
          $Res,
          _$NotificationPreferencesEntityImpl
        >
    implements _$$NotificationPreferencesEntityImplCopyWith<$Res> {
  __$$NotificationPreferencesEntityImplCopyWithImpl(
    _$NotificationPreferencesEntityImpl _value,
    $Res Function(_$NotificationPreferencesEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationPreferencesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? newEvents = null,
    Object? groupActivity = null,
    Object? eventReminders = null,
  }) {
    return _then(
      _$NotificationPreferencesEntityImpl(
        messages:
            null == messages
                ? _value.messages
                : messages // ignore: cast_nullable_to_non_nullable
                    as bool,
        newEvents:
            null == newEvents
                ? _value.newEvents
                : newEvents // ignore: cast_nullable_to_non_nullable
                    as bool,
        groupActivity:
            null == groupActivity
                ? _value.groupActivity
                : groupActivity // ignore: cast_nullable_to_non_nullable
                    as bool,
        eventReminders:
            null == eventReminders
                ? _value.eventReminders
                : eventReminders // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$NotificationPreferencesEntityImpl
    implements _NotificationPreferencesEntity {
  const _$NotificationPreferencesEntityImpl({
    this.messages = true,
    this.newEvents = true,
    this.groupActivity = true,
    this.eventReminders = true,
  });

  @override
  @JsonKey()
  final bool messages;
  @override
  @JsonKey()
  final bool newEvents;
  @override
  @JsonKey()
  final bool groupActivity;
  @override
  @JsonKey()
  final bool eventReminders;

  @override
  String toString() {
    return 'NotificationPreferencesEntity(messages: $messages, newEvents: $newEvents, groupActivity: $groupActivity, eventReminders: $eventReminders)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationPreferencesEntityImpl &&
            (identical(other.messages, messages) ||
                other.messages == messages) &&
            (identical(other.newEvents, newEvents) ||
                other.newEvents == newEvents) &&
            (identical(other.groupActivity, groupActivity) ||
                other.groupActivity == groupActivity) &&
            (identical(other.eventReminders, eventReminders) ||
                other.eventReminders == eventReminders));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    messages,
    newEvents,
    groupActivity,
    eventReminders,
  );

  /// Create a copy of NotificationPreferencesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationPreferencesEntityImplCopyWith<
    _$NotificationPreferencesEntityImpl
  >
  get copyWith => __$$NotificationPreferencesEntityImplCopyWithImpl<
    _$NotificationPreferencesEntityImpl
  >(this, _$identity);
}

abstract class _NotificationPreferencesEntity
    implements NotificationPreferencesEntity {
  const factory _NotificationPreferencesEntity({
    final bool messages,
    final bool newEvents,
    final bool groupActivity,
    final bool eventReminders,
  }) = _$NotificationPreferencesEntityImpl;

  @override
  bool get messages;
  @override
  bool get newEvents;
  @override
  bool get groupActivity;
  @override
  bool get eventReminders;

  /// Create a copy of NotificationPreferencesEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationPreferencesEntityImplCopyWith<
    _$NotificationPreferencesEntityImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
