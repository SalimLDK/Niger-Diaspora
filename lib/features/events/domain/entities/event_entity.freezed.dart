// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$EventEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  String get organizerId => throw _privateConstructorUsedError;
  String? get organizerName => throw _privateConstructorUsedError;
  String? get organizerPhotoUrl => throw _privateConstructorUsedError;
  List<String> get posterUrls => throw _privateConstructorUsedError;
  List<String> get attendeeIds => throw _privateConstructorUsedError;
  int get maxAttendees => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  String? get onlineLink => throw _privateConstructorUsedError;
  EventCategory get category => throw _privateConstructorUsedError;
  EventStatus get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  List<String> get recapPhotoUrls => throw _privateConstructorUsedError;
  String? get recapDescription => throw _privateConstructorUsedError;
  DateTime? get recapCreatedAt => throw _privateConstructorUsedError;

  /// Create a copy of EventEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventEntityCopyWith<EventEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventEntityCopyWith<$Res> {
  factory $EventEntityCopyWith(
    EventEntity value,
    $Res Function(EventEntity) then,
  ) = _$EventEntityCopyWithImpl<$Res, EventEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    DateTime startDate,
    DateTime? endDate,
    String location,
    String? address,
    double? latitude,
    double? longitude,
    String organizerId,
    String? organizerName,
    String? organizerPhotoUrl,
    List<String> posterUrls,
    List<String> attendeeIds,
    int maxAttendees,
    bool isOnline,
    String? onlineLink,
    EventCategory category,
    EventStatus status,
    DateTime? createdAt,
    List<String> recapPhotoUrls,
    String? recapDescription,
    DateTime? recapCreatedAt,
  });
}

/// @nodoc
class _$EventEntityCopyWithImpl<$Res, $Val extends EventEntity>
    implements $EventEntityCopyWith<$Res> {
  _$EventEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EventEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? location = null,
    Object? address = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? organizerId = null,
    Object? organizerName = freezed,
    Object? organizerPhotoUrl = freezed,
    Object? posterUrls = null,
    Object? attendeeIds = null,
    Object? maxAttendees = null,
    Object? isOnline = null,
    Object? onlineLink = freezed,
    Object? category = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? recapPhotoUrls = null,
    Object? recapDescription = freezed,
    Object? recapCreatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            startDate:
                null == startDate
                    ? _value.startDate
                    : startDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            endDate:
                freezed == endDate
                    ? _value.endDate
                    : endDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            location:
                null == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String,
            address:
                freezed == address
                    ? _value.address
                    : address // ignore: cast_nullable_to_non_nullable
                        as String?,
            latitude:
                freezed == latitude
                    ? _value.latitude
                    : latitude // ignore: cast_nullable_to_non_nullable
                        as double?,
            longitude:
                freezed == longitude
                    ? _value.longitude
                    : longitude // ignore: cast_nullable_to_non_nullable
                        as double?,
            organizerId:
                null == organizerId
                    ? _value.organizerId
                    : organizerId // ignore: cast_nullable_to_non_nullable
                        as String,
            organizerName:
                freezed == organizerName
                    ? _value.organizerName
                    : organizerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            organizerPhotoUrl:
                freezed == organizerPhotoUrl
                    ? _value.organizerPhotoUrl
                    : organizerPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            posterUrls:
                null == posterUrls
                    ? _value.posterUrls
                    : posterUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            attendeeIds:
                null == attendeeIds
                    ? _value.attendeeIds
                    : attendeeIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            maxAttendees:
                null == maxAttendees
                    ? _value.maxAttendees
                    : maxAttendees // ignore: cast_nullable_to_non_nullable
                        as int,
            isOnline:
                null == isOnline
                    ? _value.isOnline
                    : isOnline // ignore: cast_nullable_to_non_nullable
                        as bool,
            onlineLink:
                freezed == onlineLink
                    ? _value.onlineLink
                    : onlineLink // ignore: cast_nullable_to_non_nullable
                        as String?,
            category:
                null == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as EventCategory,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as EventStatus,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            recapPhotoUrls:
                null == recapPhotoUrls
                    ? _value.recapPhotoUrls
                    : recapPhotoUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            recapDescription:
                freezed == recapDescription
                    ? _value.recapDescription
                    : recapDescription // ignore: cast_nullable_to_non_nullable
                        as String?,
            recapCreatedAt:
                freezed == recapCreatedAt
                    ? _value.recapCreatedAt
                    : recapCreatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EventEntityImplCopyWith<$Res>
    implements $EventEntityCopyWith<$Res> {
  factory _$$EventEntityImplCopyWith(
    _$EventEntityImpl value,
    $Res Function(_$EventEntityImpl) then,
  ) = __$$EventEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    DateTime startDate,
    DateTime? endDate,
    String location,
    String? address,
    double? latitude,
    double? longitude,
    String organizerId,
    String? organizerName,
    String? organizerPhotoUrl,
    List<String> posterUrls,
    List<String> attendeeIds,
    int maxAttendees,
    bool isOnline,
    String? onlineLink,
    EventCategory category,
    EventStatus status,
    DateTime? createdAt,
    List<String> recapPhotoUrls,
    String? recapDescription,
    DateTime? recapCreatedAt,
  });
}

/// @nodoc
class __$$EventEntityImplCopyWithImpl<$Res>
    extends _$EventEntityCopyWithImpl<$Res, _$EventEntityImpl>
    implements _$$EventEntityImplCopyWith<$Res> {
  __$$EventEntityImplCopyWithImpl(
    _$EventEntityImpl _value,
    $Res Function(_$EventEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EventEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? location = null,
    Object? address = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? organizerId = null,
    Object? organizerName = freezed,
    Object? organizerPhotoUrl = freezed,
    Object? posterUrls = null,
    Object? attendeeIds = null,
    Object? maxAttendees = null,
    Object? isOnline = null,
    Object? onlineLink = freezed,
    Object? category = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? recapPhotoUrls = null,
    Object? recapDescription = freezed,
    Object? recapCreatedAt = freezed,
  }) {
    return _then(
      _$EventEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        startDate:
            null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        endDate:
            freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        location:
            null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String,
        address:
            freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                    as String?,
        latitude:
            freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                    as double?,
        longitude:
            freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                    as double?,
        organizerId:
            null == organizerId
                ? _value.organizerId
                : organizerId // ignore: cast_nullable_to_non_nullable
                    as String,
        organizerName:
            freezed == organizerName
                ? _value.organizerName
                : organizerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        organizerPhotoUrl:
            freezed == organizerPhotoUrl
                ? _value.organizerPhotoUrl
                : organizerPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        posterUrls:
            null == posterUrls
                ? _value._posterUrls
                : posterUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        attendeeIds:
            null == attendeeIds
                ? _value._attendeeIds
                : attendeeIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        maxAttendees:
            null == maxAttendees
                ? _value.maxAttendees
                : maxAttendees // ignore: cast_nullable_to_non_nullable
                    as int,
        isOnline:
            null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                    as bool,
        onlineLink:
            freezed == onlineLink
                ? _value.onlineLink
                : onlineLink // ignore: cast_nullable_to_non_nullable
                    as String?,
        category:
            null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as EventCategory,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as EventStatus,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        recapPhotoUrls:
            null == recapPhotoUrls
                ? _value._recapPhotoUrls
                : recapPhotoUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        recapDescription:
            freezed == recapDescription
                ? _value.recapDescription
                : recapDescription // ignore: cast_nullable_to_non_nullable
                    as String?,
        recapCreatedAt:
            freezed == recapCreatedAt
                ? _value.recapCreatedAt
                : recapCreatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$EventEntityImpl implements _EventEntity {
  const _$EventEntityImpl({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.location,
    this.address,
    this.latitude,
    this.longitude,
    required this.organizerId,
    this.organizerName,
    this.organizerPhotoUrl,
    final List<String> posterUrls = const [],
    final List<String> attendeeIds = const [],
    this.maxAttendees = 0,
    this.isOnline = false,
    this.onlineLink,
    this.category = EventCategory.other,
    this.status = EventStatus.upcoming,
    this.createdAt,
    final List<String> recapPhotoUrls = const [],
    this.recapDescription,
    this.recapCreatedAt,
  }) : _posterUrls = posterUrls,
       _attendeeIds = attendeeIds,
       _recapPhotoUrls = recapPhotoUrls;

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final DateTime startDate;
  @override
  final DateTime? endDate;
  @override
  final String location;
  @override
  final String? address;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final String organizerId;
  @override
  final String? organizerName;
  @override
  final String? organizerPhotoUrl;
  final List<String> _posterUrls;
  @override
  @JsonKey()
  List<String> get posterUrls {
    if (_posterUrls is EqualUnmodifiableListView) return _posterUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_posterUrls);
  }

  final List<String> _attendeeIds;
  @override
  @JsonKey()
  List<String> get attendeeIds {
    if (_attendeeIds is EqualUnmodifiableListView) return _attendeeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendeeIds);
  }

  @override
  @JsonKey()
  final int maxAttendees;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final String? onlineLink;
  @override
  @JsonKey()
  final EventCategory category;
  @override
  @JsonKey()
  final EventStatus status;
  @override
  final DateTime? createdAt;
  final List<String> _recapPhotoUrls;
  @override
  @JsonKey()
  List<String> get recapPhotoUrls {
    if (_recapPhotoUrls is EqualUnmodifiableListView) return _recapPhotoUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recapPhotoUrls);
  }

  @override
  final String? recapDescription;
  @override
  final DateTime? recapCreatedAt;

  @override
  String toString() {
    return 'EventEntity(id: $id, title: $title, description: $description, startDate: $startDate, endDate: $endDate, location: $location, address: $address, latitude: $latitude, longitude: $longitude, organizerId: $organizerId, organizerName: $organizerName, organizerPhotoUrl: $organizerPhotoUrl, posterUrls: $posterUrls, attendeeIds: $attendeeIds, maxAttendees: $maxAttendees, isOnline: $isOnline, onlineLink: $onlineLink, category: $category, status: $status, createdAt: $createdAt, recapPhotoUrls: $recapPhotoUrls, recapDescription: $recapDescription, recapCreatedAt: $recapCreatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.organizerId, organizerId) ||
                other.organizerId == organizerId) &&
            (identical(other.organizerName, organizerName) ||
                other.organizerName == organizerName) &&
            (identical(other.organizerPhotoUrl, organizerPhotoUrl) ||
                other.organizerPhotoUrl == organizerPhotoUrl) &&
            const DeepCollectionEquality().equals(
              other._posterUrls,
              _posterUrls,
            ) &&
            const DeepCollectionEquality().equals(
              other._attendeeIds,
              _attendeeIds,
            ) &&
            (identical(other.maxAttendees, maxAttendees) ||
                other.maxAttendees == maxAttendees) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.onlineLink, onlineLink) ||
                other.onlineLink == onlineLink) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(
              other._recapPhotoUrls,
              _recapPhotoUrls,
            ) &&
            (identical(other.recapDescription, recapDescription) ||
                other.recapDescription == recapDescription) &&
            (identical(other.recapCreatedAt, recapCreatedAt) ||
                other.recapCreatedAt == recapCreatedAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    startDate,
    endDate,
    location,
    address,
    latitude,
    longitude,
    organizerId,
    organizerName,
    organizerPhotoUrl,
    const DeepCollectionEquality().hash(_posterUrls),
    const DeepCollectionEquality().hash(_attendeeIds),
    maxAttendees,
    isOnline,
    onlineLink,
    category,
    status,
    createdAt,
    const DeepCollectionEquality().hash(_recapPhotoUrls),
    recapDescription,
    recapCreatedAt,
  ]);

  /// Create a copy of EventEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventEntityImplCopyWith<_$EventEntityImpl> get copyWith =>
      __$$EventEntityImplCopyWithImpl<_$EventEntityImpl>(this, _$identity);
}

abstract class _EventEntity implements EventEntity {
  const factory _EventEntity({
    required final String id,
    required final String title,
    required final String description,
    required final DateTime startDate,
    final DateTime? endDate,
    required final String location,
    final String? address,
    final double? latitude,
    final double? longitude,
    required final String organizerId,
    final String? organizerName,
    final String? organizerPhotoUrl,
    final List<String> posterUrls,
    final List<String> attendeeIds,
    final int maxAttendees,
    final bool isOnline,
    final String? onlineLink,
    final EventCategory category,
    final EventStatus status,
    final DateTime? createdAt,
    final List<String> recapPhotoUrls,
    final String? recapDescription,
    final DateTime? recapCreatedAt,
  }) = _$EventEntityImpl;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  DateTime get startDate;
  @override
  DateTime? get endDate;
  @override
  String get location;
  @override
  String? get address;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  String get organizerId;
  @override
  String? get organizerName;
  @override
  String? get organizerPhotoUrl;
  @override
  List<String> get posterUrls;
  @override
  List<String> get attendeeIds;
  @override
  int get maxAttendees;
  @override
  bool get isOnline;
  @override
  String? get onlineLink;
  @override
  EventCategory get category;
  @override
  EventStatus get status;
  @override
  DateTime? get createdAt;
  @override
  List<String> get recapPhotoUrls;
  @override
  String? get recapDescription;
  @override
  DateTime? get recapCreatedAt;

  /// Create a copy of EventEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventEntityImplCopyWith<_$EventEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
