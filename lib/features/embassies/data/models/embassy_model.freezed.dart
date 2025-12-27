// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'embassy_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmbassyModel _$EmbassyModelFromJson(Map<String, dynamic> json) {
  return _EmbassyModel.fromJson(json);
}

/// @nodoc
mixin _$EmbassyModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get country => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get website => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  List<String> get services => throw _privateConstructorUsedError;
  Map<String, String> get openingHours => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;
  bool get isSuspended => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get verifiedAt => throw _privateConstructorUsedError;
  String? get rejectionReason => throw _privateConstructorUsedError;
  List<String> get jurisdictionCountries => throw _privateConstructorUsedError;
  List<EmbassyActivityModel> get activities =>
      throw _privateConstructorUsedError;
  List<EmbassyNewsModel> get news =>
      throw _privateConstructorUsedError; // Availability fields
  bool get isTemporarilyClosed => throw _privateConstructorUsedError;
  String? get closureMessage => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get reopenDate => throw _privateConstructorUsedError;
  List<String> get upcomingServices => throw _privateConstructorUsedError;

  /// Serializes this EmbassyModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmbassyModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmbassyModelCopyWith<EmbassyModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmbassyModelCopyWith<$Res> {
  factory $EmbassyModelCopyWith(
    EmbassyModel value,
    $Res Function(EmbassyModel) then,
  ) = _$EmbassyModelCopyWithImpl<$Res, EmbassyModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String country,
    String city,
    String address,
    String? phone,
    String? email,
    String? website,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String type,
    List<String> services,
    Map<String, String> openingHours,
    bool isVerified,
    bool isSuspended,
    @TimestampConverter() DateTime? verifiedAt,
    String? rejectionReason,
    List<String> jurisdictionCountries,
    List<EmbassyActivityModel> activities,
    List<EmbassyNewsModel> news,
    bool isTemporarilyClosed,
    String? closureMessage,
    @TimestampConverter() DateTime? reopenDate,
    List<String> upcomingServices,
  });
}

/// @nodoc
class _$EmbassyModelCopyWithImpl<$Res, $Val extends EmbassyModel>
    implements $EmbassyModelCopyWith<$Res> {
  _$EmbassyModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmbassyModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? country = null,
    Object? city = null,
    Object? address = null,
    Object? phone = freezed,
    Object? email = freezed,
    Object? website = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? imageUrl = freezed,
    Object? type = null,
    Object? services = null,
    Object? openingHours = null,
    Object? isVerified = null,
    Object? isSuspended = null,
    Object? verifiedAt = freezed,
    Object? rejectionReason = freezed,
    Object? jurisdictionCountries = null,
    Object? activities = null,
    Object? news = null,
    Object? isTemporarilyClosed = null,
    Object? closureMessage = freezed,
    Object? reopenDate = freezed,
    Object? upcomingServices = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            country:
                null == country
                    ? _value.country
                    : country // ignore: cast_nullable_to_non_nullable
                        as String,
            city:
                null == city
                    ? _value.city
                    : city // ignore: cast_nullable_to_non_nullable
                        as String,
            address:
                null == address
                    ? _value.address
                    : address // ignore: cast_nullable_to_non_nullable
                        as String,
            phone:
                freezed == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            website:
                freezed == website
                    ? _value.website
                    : website // ignore: cast_nullable_to_non_nullable
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
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            services:
                null == services
                    ? _value.services
                    : services // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            openingHours:
                null == openingHours
                    ? _value.openingHours
                    : openingHours // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>,
            isVerified:
                null == isVerified
                    ? _value.isVerified
                    : isVerified // ignore: cast_nullable_to_non_nullable
                        as bool,
            isSuspended:
                null == isSuspended
                    ? _value.isSuspended
                    : isSuspended // ignore: cast_nullable_to_non_nullable
                        as bool,
            verifiedAt:
                freezed == verifiedAt
                    ? _value.verifiedAt
                    : verifiedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            rejectionReason:
                freezed == rejectionReason
                    ? _value.rejectionReason
                    : rejectionReason // ignore: cast_nullable_to_non_nullable
                        as String?,
            jurisdictionCountries:
                null == jurisdictionCountries
                    ? _value.jurisdictionCountries
                    : jurisdictionCountries // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            activities:
                null == activities
                    ? _value.activities
                    : activities // ignore: cast_nullable_to_non_nullable
                        as List<EmbassyActivityModel>,
            news:
                null == news
                    ? _value.news
                    : news // ignore: cast_nullable_to_non_nullable
                        as List<EmbassyNewsModel>,
            isTemporarilyClosed:
                null == isTemporarilyClosed
                    ? _value.isTemporarilyClosed
                    : isTemporarilyClosed // ignore: cast_nullable_to_non_nullable
                        as bool,
            closureMessage:
                freezed == closureMessage
                    ? _value.closureMessage
                    : closureMessage // ignore: cast_nullable_to_non_nullable
                        as String?,
            reopenDate:
                freezed == reopenDate
                    ? _value.reopenDate
                    : reopenDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            upcomingServices:
                null == upcomingServices
                    ? _value.upcomingServices
                    : upcomingServices // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmbassyModelImplCopyWith<$Res>
    implements $EmbassyModelCopyWith<$Res> {
  factory _$$EmbassyModelImplCopyWith(
    _$EmbassyModelImpl value,
    $Res Function(_$EmbassyModelImpl) then,
  ) = __$$EmbassyModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String country,
    String city,
    String address,
    String? phone,
    String? email,
    String? website,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String type,
    List<String> services,
    Map<String, String> openingHours,
    bool isVerified,
    bool isSuspended,
    @TimestampConverter() DateTime? verifiedAt,
    String? rejectionReason,
    List<String> jurisdictionCountries,
    List<EmbassyActivityModel> activities,
    List<EmbassyNewsModel> news,
    bool isTemporarilyClosed,
    String? closureMessage,
    @TimestampConverter() DateTime? reopenDate,
    List<String> upcomingServices,
  });
}

/// @nodoc
class __$$EmbassyModelImplCopyWithImpl<$Res>
    extends _$EmbassyModelCopyWithImpl<$Res, _$EmbassyModelImpl>
    implements _$$EmbassyModelImplCopyWith<$Res> {
  __$$EmbassyModelImplCopyWithImpl(
    _$EmbassyModelImpl _value,
    $Res Function(_$EmbassyModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmbassyModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? country = null,
    Object? city = null,
    Object? address = null,
    Object? phone = freezed,
    Object? email = freezed,
    Object? website = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? imageUrl = freezed,
    Object? type = null,
    Object? services = null,
    Object? openingHours = null,
    Object? isVerified = null,
    Object? isSuspended = null,
    Object? verifiedAt = freezed,
    Object? rejectionReason = freezed,
    Object? jurisdictionCountries = null,
    Object? activities = null,
    Object? news = null,
    Object? isTemporarilyClosed = null,
    Object? closureMessage = freezed,
    Object? reopenDate = freezed,
    Object? upcomingServices = null,
  }) {
    return _then(
      _$EmbassyModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        country:
            null == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                    as String,
        city:
            null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                    as String,
        address:
            null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                    as String,
        phone:
            freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        website:
            freezed == website
                ? _value.website
                : website // ignore: cast_nullable_to_non_nullable
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
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        services:
            null == services
                ? _value._services
                : services // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        openingHours:
            null == openingHours
                ? _value._openingHours
                : openingHours // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>,
        isVerified:
            null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                    as bool,
        isSuspended:
            null == isSuspended
                ? _value.isSuspended
                : isSuspended // ignore: cast_nullable_to_non_nullable
                    as bool,
        verifiedAt:
            freezed == verifiedAt
                ? _value.verifiedAt
                : verifiedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        rejectionReason:
            freezed == rejectionReason
                ? _value.rejectionReason
                : rejectionReason // ignore: cast_nullable_to_non_nullable
                    as String?,
        jurisdictionCountries:
            null == jurisdictionCountries
                ? _value._jurisdictionCountries
                : jurisdictionCountries // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        activities:
            null == activities
                ? _value._activities
                : activities // ignore: cast_nullable_to_non_nullable
                    as List<EmbassyActivityModel>,
        news:
            null == news
                ? _value._news
                : news // ignore: cast_nullable_to_non_nullable
                    as List<EmbassyNewsModel>,
        isTemporarilyClosed:
            null == isTemporarilyClosed
                ? _value.isTemporarilyClosed
                : isTemporarilyClosed // ignore: cast_nullable_to_non_nullable
                    as bool,
        closureMessage:
            freezed == closureMessage
                ? _value.closureMessage
                : closureMessage // ignore: cast_nullable_to_non_nullable
                    as String?,
        reopenDate:
            freezed == reopenDate
                ? _value.reopenDate
                : reopenDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        upcomingServices:
            null == upcomingServices
                ? _value._upcomingServices
                : upcomingServices // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EmbassyModelImpl extends _EmbassyModel {
  const _$EmbassyModelImpl({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.address,
    this.phone,
    this.email,
    this.website,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.type = 'embassy',
    final List<String> services = const [],
    final Map<String, String> openingHours = const {},
    this.isVerified = false,
    this.isSuspended = false,
    @TimestampConverter() this.verifiedAt,
    this.rejectionReason,
    final List<String> jurisdictionCountries = const [],
    final List<EmbassyActivityModel> activities = const [],
    final List<EmbassyNewsModel> news = const [],
    this.isTemporarilyClosed = false,
    this.closureMessage,
    @TimestampConverter() this.reopenDate,
    final List<String> upcomingServices = const [],
  }) : _services = services,
       _openingHours = openingHours,
       _jurisdictionCountries = jurisdictionCountries,
       _activities = activities,
       _news = news,
       _upcomingServices = upcomingServices,
       super._();

  factory _$EmbassyModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmbassyModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String country;
  @override
  final String city;
  @override
  final String address;
  @override
  final String? phone;
  @override
  final String? email;
  @override
  final String? website;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final String? imageUrl;
  @override
  @JsonKey()
  final String type;
  final List<String> _services;
  @override
  @JsonKey()
  List<String> get services {
    if (_services is EqualUnmodifiableListView) return _services;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_services);
  }

  final Map<String, String> _openingHours;
  @override
  @JsonKey()
  Map<String, String> get openingHours {
    if (_openingHours is EqualUnmodifiableMapView) return _openingHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_openingHours);
  }

  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final bool isSuspended;
  @override
  @TimestampConverter()
  final DateTime? verifiedAt;
  @override
  final String? rejectionReason;
  final List<String> _jurisdictionCountries;
  @override
  @JsonKey()
  List<String> get jurisdictionCountries {
    if (_jurisdictionCountries is EqualUnmodifiableListView)
      return _jurisdictionCountries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_jurisdictionCountries);
  }

  final List<EmbassyActivityModel> _activities;
  @override
  @JsonKey()
  List<EmbassyActivityModel> get activities {
    if (_activities is EqualUnmodifiableListView) return _activities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activities);
  }

  final List<EmbassyNewsModel> _news;
  @override
  @JsonKey()
  List<EmbassyNewsModel> get news {
    if (_news is EqualUnmodifiableListView) return _news;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_news);
  }

  // Availability fields
  @override
  @JsonKey()
  final bool isTemporarilyClosed;
  @override
  final String? closureMessage;
  @override
  @TimestampConverter()
  final DateTime? reopenDate;
  final List<String> _upcomingServices;
  @override
  @JsonKey()
  List<String> get upcomingServices {
    if (_upcomingServices is EqualUnmodifiableListView)
      return _upcomingServices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_upcomingServices);
  }

  @override
  String toString() {
    return 'EmbassyModel(id: $id, name: $name, country: $country, city: $city, address: $address, phone: $phone, email: $email, website: $website, latitude: $latitude, longitude: $longitude, imageUrl: $imageUrl, type: $type, services: $services, openingHours: $openingHours, isVerified: $isVerified, isSuspended: $isSuspended, verifiedAt: $verifiedAt, rejectionReason: $rejectionReason, jurisdictionCountries: $jurisdictionCountries, activities: $activities, news: $news, isTemporarilyClosed: $isTemporarilyClosed, closureMessage: $closureMessage, reopenDate: $reopenDate, upcomingServices: $upcomingServices)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmbassyModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._services, _services) &&
            const DeepCollectionEquality().equals(
              other._openingHours,
              _openingHours,
            ) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isSuspended, isSuspended) ||
                other.isSuspended == isSuspended) &&
            (identical(other.verifiedAt, verifiedAt) ||
                other.verifiedAt == verifiedAt) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            const DeepCollectionEquality().equals(
              other._jurisdictionCountries,
              _jurisdictionCountries,
            ) &&
            const DeepCollectionEquality().equals(
              other._activities,
              _activities,
            ) &&
            const DeepCollectionEquality().equals(other._news, _news) &&
            (identical(other.isTemporarilyClosed, isTemporarilyClosed) ||
                other.isTemporarilyClosed == isTemporarilyClosed) &&
            (identical(other.closureMessage, closureMessage) ||
                other.closureMessage == closureMessage) &&
            (identical(other.reopenDate, reopenDate) ||
                other.reopenDate == reopenDate) &&
            const DeepCollectionEquality().equals(
              other._upcomingServices,
              _upcomingServices,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    country,
    city,
    address,
    phone,
    email,
    website,
    latitude,
    longitude,
    imageUrl,
    type,
    const DeepCollectionEquality().hash(_services),
    const DeepCollectionEquality().hash(_openingHours),
    isVerified,
    isSuspended,
    verifiedAt,
    rejectionReason,
    const DeepCollectionEquality().hash(_jurisdictionCountries),
    const DeepCollectionEquality().hash(_activities),
    const DeepCollectionEquality().hash(_news),
    isTemporarilyClosed,
    closureMessage,
    reopenDate,
    const DeepCollectionEquality().hash(_upcomingServices),
  ]);

  /// Create a copy of EmbassyModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmbassyModelImplCopyWith<_$EmbassyModelImpl> get copyWith =>
      __$$EmbassyModelImplCopyWithImpl<_$EmbassyModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmbassyModelImplToJson(this);
  }
}

abstract class _EmbassyModel extends EmbassyModel {
  const factory _EmbassyModel({
    required final String id,
    required final String name,
    required final String country,
    required final String city,
    required final String address,
    final String? phone,
    final String? email,
    final String? website,
    final double? latitude,
    final double? longitude,
    final String? imageUrl,
    final String type,
    final List<String> services,
    final Map<String, String> openingHours,
    final bool isVerified,
    final bool isSuspended,
    @TimestampConverter() final DateTime? verifiedAt,
    final String? rejectionReason,
    final List<String> jurisdictionCountries,
    final List<EmbassyActivityModel> activities,
    final List<EmbassyNewsModel> news,
    final bool isTemporarilyClosed,
    final String? closureMessage,
    @TimestampConverter() final DateTime? reopenDate,
    final List<String> upcomingServices,
  }) = _$EmbassyModelImpl;
  const _EmbassyModel._() : super._();

  factory _EmbassyModel.fromJson(Map<String, dynamic> json) =
      _$EmbassyModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get country;
  @override
  String get city;
  @override
  String get address;
  @override
  String? get phone;
  @override
  String? get email;
  @override
  String? get website;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  String? get imageUrl;
  @override
  String get type;
  @override
  List<String> get services;
  @override
  Map<String, String> get openingHours;
  @override
  bool get isVerified;
  @override
  bool get isSuspended;
  @override
  @TimestampConverter()
  DateTime? get verifiedAt;
  @override
  String? get rejectionReason;
  @override
  List<String> get jurisdictionCountries;
  @override
  List<EmbassyActivityModel> get activities;
  @override
  List<EmbassyNewsModel> get news; // Availability fields
  @override
  bool get isTemporarilyClosed;
  @override
  String? get closureMessage;
  @override
  @TimestampConverter()
  DateTime? get reopenDate;
  @override
  List<String> get upcomingServices;

  /// Create a copy of EmbassyModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmbassyModelImplCopyWith<_$EmbassyModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
