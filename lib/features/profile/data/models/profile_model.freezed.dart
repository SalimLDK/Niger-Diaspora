// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) {
  return _ProfileModel.fromJson(json);
}

/// @nodoc
mixin _$ProfileModel {
  String get id => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get handle => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String? get profession => throw _privateConstructorUsedError;
  String? get currentCity => throw _privateConstructorUsedError;
  String? get currentCountry => throw _privateConstructorUsedError;
  String? get currentRegion => throw _privateConstructorUsedError;
  String? get countryCode => throw _privateConstructorUsedError;
  String? get originRegion => throw _privateConstructorUsedError;
  String? get originCity => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  bool get isVisible => throw _privateConstructorUsedError;
  bool get notificationsEnabled => throw _privateConstructorUsedError;
  bool get shareLocation => throw _privateConstructorUsedError;
  String get phoneVisibility => throw _privateConstructorUsedError;
  bool get isPhoneVerified => throw _privateConstructorUsedError;
  List<String> get interests => throw _privateConstructorUsedError;
  List<String> get skills => throw _privateConstructorUsedError;
  List<String> get languages => throw _privateConstructorUsedError;
  int get connectionsCount => throw _privateConstructorUsedError;
  int get groupsCount => throw _privateConstructorUsedError;
  int get eventsCount => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get lastLoginAt => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get lastSeen => throw _privateConstructorUsedError;
  bool get showOnlineStatus => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get locationUpdatedAt => throw _privateConstructorUsedError;
  List<String> get blockedByUserIds => throw _privateConstructorUsedError;

  /// Serializes this ProfileModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileModelCopyWith<ProfileModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileModelCopyWith<$Res> {
  factory $ProfileModelCopyWith(
    ProfileModel value,
    $Res Function(ProfileModel) then,
  ) = _$ProfileModelCopyWithImpl<$Res, ProfileModel>;
  @useResult
  $Res call({
    String id,
    String? email,
    String? displayName,
    String? handle,
    String? photoUrl,
    String? phoneNumber,
    String? bio,
    String? profession,
    String? currentCity,
    String? currentCountry,
    String? currentRegion,
    String? countryCode,
    String? originRegion,
    String? originCity,
    double? latitude,
    double? longitude,
    bool isVisible,
    bool notificationsEnabled,
    bool shareLocation,
    String phoneVisibility,
    bool isPhoneVerified,
    List<String> interests,
    List<String> skills,
    List<String> languages,
    int connectionsCount,
    int groupsCount,
    int eventsCount,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
    @LocalDateTimeNullableConverter() DateTime? lastLoginAt,
    bool isOnline,
    @LocalDateTimeNullableConverter() DateTime? lastSeen,
    bool showOnlineStatus,
    @LocalDateTimeNullableConverter() DateTime? locationUpdatedAt,
    List<String> blockedByUserIds,
  });
}

/// @nodoc
class _$ProfileModelCopyWithImpl<$Res, $Val extends ProfileModel>
    implements $ProfileModelCopyWith<$Res> {
  _$ProfileModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? displayName = freezed,
    Object? handle = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? bio = freezed,
    Object? profession = freezed,
    Object? currentCity = freezed,
    Object? currentCountry = freezed,
    Object? currentRegion = freezed,
    Object? countryCode = freezed,
    Object? originRegion = freezed,
    Object? originCity = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? isVisible = null,
    Object? notificationsEnabled = null,
    Object? shareLocation = null,
    Object? phoneVisibility = null,
    Object? isPhoneVerified = null,
    Object? interests = null,
    Object? skills = null,
    Object? languages = null,
    Object? connectionsCount = null,
    Object? groupsCount = null,
    Object? eventsCount = null,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? showOnlineStatus = null,
    Object? locationUpdatedAt = freezed,
    Object? blockedByUserIds = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            displayName:
                freezed == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String?,
            handle:
                freezed == handle
                    ? _value.handle
                    : handle // ignore: cast_nullable_to_non_nullable
                        as String?,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            phoneNumber:
                freezed == phoneNumber
                    ? _value.phoneNumber
                    : phoneNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            bio:
                freezed == bio
                    ? _value.bio
                    : bio // ignore: cast_nullable_to_non_nullable
                        as String?,
            profession:
                freezed == profession
                    ? _value.profession
                    : profession // ignore: cast_nullable_to_non_nullable
                        as String?,
            currentCity:
                freezed == currentCity
                    ? _value.currentCity
                    : currentCity // ignore: cast_nullable_to_non_nullable
                        as String?,
            currentCountry:
                freezed == currentCountry
                    ? _value.currentCountry
                    : currentCountry // ignore: cast_nullable_to_non_nullable
                        as String?,
            currentRegion:
                freezed == currentRegion
                    ? _value.currentRegion
                    : currentRegion // ignore: cast_nullable_to_non_nullable
                        as String?,
            countryCode:
                freezed == countryCode
                    ? _value.countryCode
                    : countryCode // ignore: cast_nullable_to_non_nullable
                        as String?,
            originRegion:
                freezed == originRegion
                    ? _value.originRegion
                    : originRegion // ignore: cast_nullable_to_non_nullable
                        as String?,
            originCity:
                freezed == originCity
                    ? _value.originCity
                    : originCity // ignore: cast_nullable_to_non_nullable
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
            isVisible:
                null == isVisible
                    ? _value.isVisible
                    : isVisible // ignore: cast_nullable_to_non_nullable
                        as bool,
            notificationsEnabled:
                null == notificationsEnabled
                    ? _value.notificationsEnabled
                    : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            shareLocation:
                null == shareLocation
                    ? _value.shareLocation
                    : shareLocation // ignore: cast_nullable_to_non_nullable
                        as bool,
            phoneVisibility:
                null == phoneVisibility
                    ? _value.phoneVisibility
                    : phoneVisibility // ignore: cast_nullable_to_non_nullable
                        as String,
            isPhoneVerified:
                null == isPhoneVerified
                    ? _value.isPhoneVerified
                    : isPhoneVerified // ignore: cast_nullable_to_non_nullable
                        as bool,
            interests:
                null == interests
                    ? _value.interests
                    : interests // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            skills:
                null == skills
                    ? _value.skills
                    : skills // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            languages:
                null == languages
                    ? _value.languages
                    : languages // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            connectionsCount:
                null == connectionsCount
                    ? _value.connectionsCount
                    : connectionsCount // ignore: cast_nullable_to_non_nullable
                        as int,
            groupsCount:
                null == groupsCount
                    ? _value.groupsCount
                    : groupsCount // ignore: cast_nullable_to_non_nullable
                        as int,
            eventsCount:
                null == eventsCount
                    ? _value.eventsCount
                    : eventsCount // ignore: cast_nullable_to_non_nullable
                        as int,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            lastLoginAt:
                freezed == lastLoginAt
                    ? _value.lastLoginAt
                    : lastLoginAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            isOnline:
                null == isOnline
                    ? _value.isOnline
                    : isOnline // ignore: cast_nullable_to_non_nullable
                        as bool,
            lastSeen:
                freezed == lastSeen
                    ? _value.lastSeen
                    : lastSeen // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            showOnlineStatus:
                null == showOnlineStatus
                    ? _value.showOnlineStatus
                    : showOnlineStatus // ignore: cast_nullable_to_non_nullable
                        as bool,
            locationUpdatedAt:
                freezed == locationUpdatedAt
                    ? _value.locationUpdatedAt
                    : locationUpdatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            blockedByUserIds:
                null == blockedByUserIds
                    ? _value.blockedByUserIds
                    : blockedByUserIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileModelImplCopyWith<$Res>
    implements $ProfileModelCopyWith<$Res> {
  factory _$$ProfileModelImplCopyWith(
    _$ProfileModelImpl value,
    $Res Function(_$ProfileModelImpl) then,
  ) = __$$ProfileModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? email,
    String? displayName,
    String? handle,
    String? photoUrl,
    String? phoneNumber,
    String? bio,
    String? profession,
    String? currentCity,
    String? currentCountry,
    String? currentRegion,
    String? countryCode,
    String? originRegion,
    String? originCity,
    double? latitude,
    double? longitude,
    bool isVisible,
    bool notificationsEnabled,
    bool shareLocation,
    String phoneVisibility,
    bool isPhoneVerified,
    List<String> interests,
    List<String> skills,
    List<String> languages,
    int connectionsCount,
    int groupsCount,
    int eventsCount,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
    @LocalDateTimeNullableConverter() DateTime? lastLoginAt,
    bool isOnline,
    @LocalDateTimeNullableConverter() DateTime? lastSeen,
    bool showOnlineStatus,
    @LocalDateTimeNullableConverter() DateTime? locationUpdatedAt,
    List<String> blockedByUserIds,
  });
}

/// @nodoc
class __$$ProfileModelImplCopyWithImpl<$Res>
    extends _$ProfileModelCopyWithImpl<$Res, _$ProfileModelImpl>
    implements _$$ProfileModelImplCopyWith<$Res> {
  __$$ProfileModelImplCopyWithImpl(
    _$ProfileModelImpl _value,
    $Res Function(_$ProfileModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? displayName = freezed,
    Object? handle = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? bio = freezed,
    Object? profession = freezed,
    Object? currentCity = freezed,
    Object? currentCountry = freezed,
    Object? currentRegion = freezed,
    Object? countryCode = freezed,
    Object? originRegion = freezed,
    Object? originCity = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? isVisible = null,
    Object? notificationsEnabled = null,
    Object? shareLocation = null,
    Object? phoneVisibility = null,
    Object? isPhoneVerified = null,
    Object? interests = null,
    Object? skills = null,
    Object? languages = null,
    Object? connectionsCount = null,
    Object? groupsCount = null,
    Object? eventsCount = null,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? showOnlineStatus = null,
    Object? locationUpdatedAt = freezed,
    Object? blockedByUserIds = null,
  }) {
    return _then(
      _$ProfileModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        displayName:
            freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String?,
        handle:
            freezed == handle
                ? _value.handle
                : handle // ignore: cast_nullable_to_non_nullable
                    as String?,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        phoneNumber:
            freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        bio:
            freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                    as String?,
        profession:
            freezed == profession
                ? _value.profession
                : profession // ignore: cast_nullable_to_non_nullable
                    as String?,
        currentCity:
            freezed == currentCity
                ? _value.currentCity
                : currentCity // ignore: cast_nullable_to_non_nullable
                    as String?,
        currentCountry:
            freezed == currentCountry
                ? _value.currentCountry
                : currentCountry // ignore: cast_nullable_to_non_nullable
                    as String?,
        currentRegion:
            freezed == currentRegion
                ? _value.currentRegion
                : currentRegion // ignore: cast_nullable_to_non_nullable
                    as String?,
        countryCode:
            freezed == countryCode
                ? _value.countryCode
                : countryCode // ignore: cast_nullable_to_non_nullable
                    as String?,
        originRegion:
            freezed == originRegion
                ? _value.originRegion
                : originRegion // ignore: cast_nullable_to_non_nullable
                    as String?,
        originCity:
            freezed == originCity
                ? _value.originCity
                : originCity // ignore: cast_nullable_to_non_nullable
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
        isVisible:
            null == isVisible
                ? _value.isVisible
                : isVisible // ignore: cast_nullable_to_non_nullable
                    as bool,
        notificationsEnabled:
            null == notificationsEnabled
                ? _value.notificationsEnabled
                : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        shareLocation:
            null == shareLocation
                ? _value.shareLocation
                : shareLocation // ignore: cast_nullable_to_non_nullable
                    as bool,
        phoneVisibility:
            null == phoneVisibility
                ? _value.phoneVisibility
                : phoneVisibility // ignore: cast_nullable_to_non_nullable
                    as String,
        isPhoneVerified:
            null == isPhoneVerified
                ? _value.isPhoneVerified
                : isPhoneVerified // ignore: cast_nullable_to_non_nullable
                    as bool,
        interests:
            null == interests
                ? _value._interests
                : interests // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        skills:
            null == skills
                ? _value._skills
                : skills // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        languages:
            null == languages
                ? _value._languages
                : languages // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        connectionsCount:
            null == connectionsCount
                ? _value.connectionsCount
                : connectionsCount // ignore: cast_nullable_to_non_nullable
                    as int,
        groupsCount:
            null == groupsCount
                ? _value.groupsCount
                : groupsCount // ignore: cast_nullable_to_non_nullable
                    as int,
        eventsCount:
            null == eventsCount
                ? _value.eventsCount
                : eventsCount // ignore: cast_nullable_to_non_nullable
                    as int,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        lastLoginAt:
            freezed == lastLoginAt
                ? _value.lastLoginAt
                : lastLoginAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        isOnline:
            null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                    as bool,
        lastSeen:
            freezed == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        showOnlineStatus:
            null == showOnlineStatus
                ? _value.showOnlineStatus
                : showOnlineStatus // ignore: cast_nullable_to_non_nullable
                    as bool,
        locationUpdatedAt:
            freezed == locationUpdatedAt
                ? _value.locationUpdatedAt
                : locationUpdatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        blockedByUserIds:
            null == blockedByUserIds
                ? _value._blockedByUserIds
                : blockedByUserIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileModelImpl extends _ProfileModel {
  const _$ProfileModelImpl({
    required this.id,
    this.email,
    this.displayName,
    this.handle,
    this.photoUrl,
    this.phoneNumber,
    this.bio,
    this.profession,
    this.currentCity,
    this.currentCountry,
    this.currentRegion,
    this.countryCode,
    this.originRegion,
    this.originCity,
    this.latitude,
    this.longitude,
    this.isVisible = true,
    this.notificationsEnabled = true,
    this.shareLocation = true,
    this.phoneVisibility = 'everyone',
    this.isPhoneVerified = false,
    final List<String> interests = const [],
    final List<String> skills = const [],
    final List<String> languages = const [],
    this.connectionsCount = 0,
    this.groupsCount = 0,
    this.eventsCount = 0,
    @LocalDateTimeNullableConverter() this.createdAt,
    @LocalDateTimeNullableConverter() this.lastLoginAt,
    this.isOnline = false,
    @LocalDateTimeNullableConverter() this.lastSeen,
    this.showOnlineStatus = true,
    @LocalDateTimeNullableConverter() this.locationUpdatedAt,
    final List<String> blockedByUserIds = const [],
  }) : _interests = interests,
       _skills = skills,
       _languages = languages,
       _blockedByUserIds = blockedByUserIds,
       super._();

  factory _$ProfileModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileModelImplFromJson(json);

  @override
  final String id;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? handle;
  @override
  final String? photoUrl;
  @override
  final String? phoneNumber;
  @override
  final String? bio;
  @override
  final String? profession;
  @override
  final String? currentCity;
  @override
  final String? currentCountry;
  @override
  final String? currentRegion;
  @override
  final String? countryCode;
  @override
  final String? originRegion;
  @override
  final String? originCity;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  @JsonKey()
  final bool isVisible;
  @override
  @JsonKey()
  final bool notificationsEnabled;
  @override
  @JsonKey()
  final bool shareLocation;
  @override
  @JsonKey()
  final String phoneVisibility;
  @override
  @JsonKey()
  final bool isPhoneVerified;
  final List<String> _interests;
  @override
  @JsonKey()
  List<String> get interests {
    if (_interests is EqualUnmodifiableListView) return _interests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_interests);
  }

  final List<String> _skills;
  @override
  @JsonKey()
  List<String> get skills {
    if (_skills is EqualUnmodifiableListView) return _skills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_skills);
  }

  final List<String> _languages;
  @override
  @JsonKey()
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  @override
  @JsonKey()
  final int connectionsCount;
  @override
  @JsonKey()
  final int groupsCount;
  @override
  @JsonKey()
  final int eventsCount;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? createdAt;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? lastLoginAt;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? lastSeen;
  @override
  @JsonKey()
  final bool showOnlineStatus;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? locationUpdatedAt;
  final List<String> _blockedByUserIds;
  @override
  @JsonKey()
  List<String> get blockedByUserIds {
    if (_blockedByUserIds is EqualUnmodifiableListView)
      return _blockedByUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedByUserIds);
  }

  @override
  String toString() {
    return 'ProfileModel(id: $id, email: $email, displayName: $displayName, handle: $handle, photoUrl: $photoUrl, phoneNumber: $phoneNumber, bio: $bio, profession: $profession, currentCity: $currentCity, currentCountry: $currentCountry, currentRegion: $currentRegion, countryCode: $countryCode, originRegion: $originRegion, originCity: $originCity, latitude: $latitude, longitude: $longitude, isVisible: $isVisible, notificationsEnabled: $notificationsEnabled, shareLocation: $shareLocation, phoneVisibility: $phoneVisibility, isPhoneVerified: $isPhoneVerified, interests: $interests, skills: $skills, languages: $languages, connectionsCount: $connectionsCount, groupsCount: $groupsCount, eventsCount: $eventsCount, createdAt: $createdAt, lastLoginAt: $lastLoginAt, isOnline: $isOnline, lastSeen: $lastSeen, showOnlineStatus: $showOnlineStatus, locationUpdatedAt: $locationUpdatedAt, blockedByUserIds: $blockedByUserIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.handle, handle) || other.handle == handle) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.profession, profession) ||
                other.profession == profession) &&
            (identical(other.currentCity, currentCity) ||
                other.currentCity == currentCity) &&
            (identical(other.currentCountry, currentCountry) ||
                other.currentCountry == currentCountry) &&
            (identical(other.currentRegion, currentRegion) ||
                other.currentRegion == currentRegion) &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.originRegion, originRegion) ||
                other.originRegion == originRegion) &&
            (identical(other.originCity, originCity) ||
                other.originCity == originCity) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible) &&
            (identical(other.notificationsEnabled, notificationsEnabled) ||
                other.notificationsEnabled == notificationsEnabled) &&
            (identical(other.shareLocation, shareLocation) ||
                other.shareLocation == shareLocation) &&
            (identical(other.phoneVisibility, phoneVisibility) ||
                other.phoneVisibility == phoneVisibility) &&
            (identical(other.isPhoneVerified, isPhoneVerified) ||
                other.isPhoneVerified == isPhoneVerified) &&
            const DeepCollectionEquality().equals(
              other._interests,
              _interests,
            ) &&
            const DeepCollectionEquality().equals(other._skills, _skills) &&
            const DeepCollectionEquality().equals(
              other._languages,
              _languages,
            ) &&
            (identical(other.connectionsCount, connectionsCount) ||
                other.connectionsCount == connectionsCount) &&
            (identical(other.groupsCount, groupsCount) ||
                other.groupsCount == groupsCount) &&
            (identical(other.eventsCount, eventsCount) ||
                other.eventsCount == eventsCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastLoginAt, lastLoginAt) ||
                other.lastLoginAt == lastLoginAt) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.showOnlineStatus, showOnlineStatus) ||
                other.showOnlineStatus == showOnlineStatus) &&
            (identical(other.locationUpdatedAt, locationUpdatedAt) ||
                other.locationUpdatedAt == locationUpdatedAt) &&
            const DeepCollectionEquality().equals(
              other._blockedByUserIds,
              _blockedByUserIds,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    email,
    displayName,
    handle,
    photoUrl,
    phoneNumber,
    bio,
    profession,
    currentCity,
    currentCountry,
    currentRegion,
    countryCode,
    originRegion,
    originCity,
    latitude,
    longitude,
    isVisible,
    notificationsEnabled,
    shareLocation,
    phoneVisibility,
    isPhoneVerified,
    const DeepCollectionEquality().hash(_interests),
    const DeepCollectionEquality().hash(_skills),
    const DeepCollectionEquality().hash(_languages),
    connectionsCount,
    groupsCount,
    eventsCount,
    createdAt,
    lastLoginAt,
    isOnline,
    lastSeen,
    showOnlineStatus,
    locationUpdatedAt,
    const DeepCollectionEquality().hash(_blockedByUserIds),
  ]);

  /// Create a copy of ProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileModelImplCopyWith<_$ProfileModelImpl> get copyWith =>
      __$$ProfileModelImplCopyWithImpl<_$ProfileModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileModelImplToJson(this);
  }
}

abstract class _ProfileModel extends ProfileModel {
  const factory _ProfileModel({
    required final String id,
    final String? email,
    final String? displayName,
    final String? handle,
    final String? photoUrl,
    final String? phoneNumber,
    final String? bio,
    final String? profession,
    final String? currentCity,
    final String? currentCountry,
    final String? currentRegion,
    final String? countryCode,
    final String? originRegion,
    final String? originCity,
    final double? latitude,
    final double? longitude,
    final bool isVisible,
    final bool notificationsEnabled,
    final bool shareLocation,
    final String phoneVisibility,
    final bool isPhoneVerified,
    final List<String> interests,
    final List<String> skills,
    final List<String> languages,
    final int connectionsCount,
    final int groupsCount,
    final int eventsCount,
    @LocalDateTimeNullableConverter() final DateTime? createdAt,
    @LocalDateTimeNullableConverter() final DateTime? lastLoginAt,
    final bool isOnline,
    @LocalDateTimeNullableConverter() final DateTime? lastSeen,
    final bool showOnlineStatus,
    @LocalDateTimeNullableConverter() final DateTime? locationUpdatedAt,
    final List<String> blockedByUserIds,
  }) = _$ProfileModelImpl;
  const _ProfileModel._() : super._();

  factory _ProfileModel.fromJson(Map<String, dynamic> json) =
      _$ProfileModelImpl.fromJson;

  @override
  String get id;
  @override
  String? get email;
  @override
  String? get displayName;
  @override
  String? get handle;
  @override
  String? get photoUrl;
  @override
  String? get phoneNumber;
  @override
  String? get bio;
  @override
  String? get profession;
  @override
  String? get currentCity;
  @override
  String? get currentCountry;
  @override
  String? get currentRegion;
  @override
  String? get countryCode;
  @override
  String? get originRegion;
  @override
  String? get originCity;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  bool get isVisible;
  @override
  bool get notificationsEnabled;
  @override
  bool get shareLocation;
  @override
  String get phoneVisibility;
  @override
  bool get isPhoneVerified;
  @override
  List<String> get interests;
  @override
  List<String> get skills;
  @override
  List<String> get languages;
  @override
  int get connectionsCount;
  @override
  int get groupsCount;
  @override
  int get eventsCount;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get createdAt;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get lastLoginAt;
  @override
  bool get isOnline;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get lastSeen;
  @override
  bool get showOnlineStatus;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get locationUpdatedAt;
  @override
  List<String> get blockedByUserIds;

  /// Create a copy of ProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileModelImplCopyWith<_$ProfileModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
