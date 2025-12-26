// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BusinessModel _$BusinessModelFromJson(Map<String, dynamic> json) {
  return _BusinessModel.fromJson(json);
}

/// @nodoc
mixin _$BusinessModel {
  String get id => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  String? get ownerName => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  List<String> get photoUrls => throw _privateConstructorUsedError;
  String? get logoUrl => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get website => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  Map<String, dynamic> get openingHours => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;
  bool get isBoosted => throw _privateConstructorUsedError;
  DateTime? get boostExpiresAt => throw _privateConstructorUsedError;
  double get averageRating => throw _privateConstructorUsedError;
  int get reviewCount => throw _privateConstructorUsedError;
  int get viewCount => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  List<String> get services => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this BusinessModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BusinessModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BusinessModelCopyWith<BusinessModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusinessModelCopyWith<$Res> {
  factory $BusinessModelCopyWith(
    BusinessModel value,
    $Res Function(BusinessModel) then,
  ) = _$BusinessModelCopyWithImpl<$Res, BusinessModel>;
  @useResult
  $Res call({
    String id,
    String ownerId,
    String? ownerName,
    String name,
    String description,
    String category,
    List<String> photoUrls,
    String? logoUrl,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    Map<String, dynamic> openingHours,
    bool isVerified,
    bool isBoosted,
    DateTime? boostExpiresAt,
    double averageRating,
    int reviewCount,
    int viewCount,
    List<String> tags,
    List<String> services,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$BusinessModelCopyWithImpl<$Res, $Val extends BusinessModel>
    implements $BusinessModelCopyWith<$Res> {
  _$BusinessModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BusinessModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? ownerName = freezed,
    Object? name = null,
    Object? description = null,
    Object? category = null,
    Object? photoUrls = null,
    Object? logoUrl = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? website = freezed,
    Object? address = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? openingHours = null,
    Object? isVerified = null,
    Object? isBoosted = null,
    Object? boostExpiresAt = freezed,
    Object? averageRating = null,
    Object? reviewCount = null,
    Object? viewCount = null,
    Object? tags = null,
    Object? services = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            ownerId:
                null == ownerId
                    ? _value.ownerId
                    : ownerId // ignore: cast_nullable_to_non_nullable
                        as String,
            ownerName:
                freezed == ownerName
                    ? _value.ownerName
                    : ownerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            category:
                null == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String,
            photoUrls:
                null == photoUrls
                    ? _value.photoUrls
                    : photoUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            logoUrl:
                freezed == logoUrl
                    ? _value.logoUrl
                    : logoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
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
            address:
                freezed == address
                    ? _value.address
                    : address // ignore: cast_nullable_to_non_nullable
                        as String?,
            city:
                freezed == city
                    ? _value.city
                    : city // ignore: cast_nullable_to_non_nullable
                        as String?,
            country:
                freezed == country
                    ? _value.country
                    : country // ignore: cast_nullable_to_non_nullable
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
            openingHours:
                null == openingHours
                    ? _value.openingHours
                    : openingHours // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            isVerified:
                null == isVerified
                    ? _value.isVerified
                    : isVerified // ignore: cast_nullable_to_non_nullable
                        as bool,
            isBoosted:
                null == isBoosted
                    ? _value.isBoosted
                    : isBoosted // ignore: cast_nullable_to_non_nullable
                        as bool,
            boostExpiresAt:
                freezed == boostExpiresAt
                    ? _value.boostExpiresAt
                    : boostExpiresAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            averageRating:
                null == averageRating
                    ? _value.averageRating
                    : averageRating // ignore: cast_nullable_to_non_nullable
                        as double,
            reviewCount:
                null == reviewCount
                    ? _value.reviewCount
                    : reviewCount // ignore: cast_nullable_to_non_nullable
                        as int,
            viewCount:
                null == viewCount
                    ? _value.viewCount
                    : viewCount // ignore: cast_nullable_to_non_nullable
                        as int,
            tags:
                null == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            services:
                null == services
                    ? _value.services
                    : services // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BusinessModelImplCopyWith<$Res>
    implements $BusinessModelCopyWith<$Res> {
  factory _$$BusinessModelImplCopyWith(
    _$BusinessModelImpl value,
    $Res Function(_$BusinessModelImpl) then,
  ) = __$$BusinessModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ownerId,
    String? ownerName,
    String name,
    String description,
    String category,
    List<String> photoUrls,
    String? logoUrl,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    Map<String, dynamic> openingHours,
    bool isVerified,
    bool isBoosted,
    DateTime? boostExpiresAt,
    double averageRating,
    int reviewCount,
    int viewCount,
    List<String> tags,
    List<String> services,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$BusinessModelImplCopyWithImpl<$Res>
    extends _$BusinessModelCopyWithImpl<$Res, _$BusinessModelImpl>
    implements _$$BusinessModelImplCopyWith<$Res> {
  __$$BusinessModelImplCopyWithImpl(
    _$BusinessModelImpl _value,
    $Res Function(_$BusinessModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BusinessModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? ownerName = freezed,
    Object? name = null,
    Object? description = null,
    Object? category = null,
    Object? photoUrls = null,
    Object? logoUrl = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? website = freezed,
    Object? address = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? openingHours = null,
    Object? isVerified = null,
    Object? isBoosted = null,
    Object? boostExpiresAt = freezed,
    Object? averageRating = null,
    Object? reviewCount = null,
    Object? viewCount = null,
    Object? tags = null,
    Object? services = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$BusinessModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        ownerId:
            null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                    as String,
        ownerName:
            freezed == ownerName
                ? _value.ownerName
                : ownerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        category:
            null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String,
        photoUrls:
            null == photoUrls
                ? _value._photoUrls
                : photoUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        logoUrl:
            freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
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
        address:
            freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                    as String?,
        city:
            freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                    as String?,
        country:
            freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
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
        openingHours:
            null == openingHours
                ? _value._openingHours
                : openingHours // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        isVerified:
            null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                    as bool,
        isBoosted:
            null == isBoosted
                ? _value.isBoosted
                : isBoosted // ignore: cast_nullable_to_non_nullable
                    as bool,
        boostExpiresAt:
            freezed == boostExpiresAt
                ? _value.boostExpiresAt
                : boostExpiresAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        averageRating:
            null == averageRating
                ? _value.averageRating
                : averageRating // ignore: cast_nullable_to_non_nullable
                    as double,
        reviewCount:
            null == reviewCount
                ? _value.reviewCount
                : reviewCount // ignore: cast_nullable_to_non_nullable
                    as int,
        viewCount:
            null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                    as int,
        tags:
            null == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        services:
            null == services
                ? _value._services
                : services // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BusinessModelImpl extends _BusinessModel {
  const _$BusinessModelImpl({
    required this.id,
    required this.ownerId,
    this.ownerName,
    required this.name,
    required this.description,
    this.category = 'other',
    final List<String> photoUrls = const [],
    this.logoUrl,
    this.phone,
    this.email,
    this.website,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    final Map<String, dynamic> openingHours = const {},
    this.isVerified = false,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.viewCount = 0,
    final List<String> tags = const [],
    final List<String> services = const [],
    this.createdAt,
    this.updatedAt,
  }) : _photoUrls = photoUrls,
       _openingHours = openingHours,
       _tags = tags,
       _services = services,
       super._();

  factory _$BusinessModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BusinessModelImplFromJson(json);

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final String? ownerName;
  @override
  final String name;
  @override
  final String description;
  @override
  @JsonKey()
  final String category;
  final List<String> _photoUrls;
  @override
  @JsonKey()
  List<String> get photoUrls {
    if (_photoUrls is EqualUnmodifiableListView) return _photoUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photoUrls);
  }

  @override
  final String? logoUrl;
  @override
  final String? phone;
  @override
  final String? email;
  @override
  final String? website;
  @override
  final String? address;
  @override
  final String? city;
  @override
  final String? country;
  @override
  final double? latitude;
  @override
  final double? longitude;
  final Map<String, dynamic> _openingHours;
  @override
  @JsonKey()
  Map<String, dynamic> get openingHours {
    if (_openingHours is EqualUnmodifiableMapView) return _openingHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_openingHours);
  }

  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final bool isBoosted;
  @override
  final DateTime? boostExpiresAt;
  @override
  @JsonKey()
  final double averageRating;
  @override
  @JsonKey()
  final int reviewCount;
  @override
  @JsonKey()
  final int viewCount;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<String> _services;
  @override
  @JsonKey()
  List<String> get services {
    if (_services is EqualUnmodifiableListView) return _services;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_services);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'BusinessModel(id: $id, ownerId: $ownerId, ownerName: $ownerName, name: $name, description: $description, category: $category, photoUrls: $photoUrls, logoUrl: $logoUrl, phone: $phone, email: $email, website: $website, address: $address, city: $city, country: $country, latitude: $latitude, longitude: $longitude, openingHours: $openingHours, isVerified: $isVerified, isBoosted: $isBoosted, boostExpiresAt: $boostExpiresAt, averageRating: $averageRating, reviewCount: $reviewCount, viewCount: $viewCount, tags: $tags, services: $services, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.ownerName, ownerName) ||
                other.ownerName == ownerName) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._photoUrls,
              _photoUrls,
            ) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            const DeepCollectionEquality().equals(
              other._openingHours,
              _openingHours,
            ) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isBoosted, isBoosted) ||
                other.isBoosted == isBoosted) &&
            (identical(other.boostExpiresAt, boostExpiresAt) ||
                other.boostExpiresAt == boostExpiresAt) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.reviewCount, reviewCount) ||
                other.reviewCount == reviewCount) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(other._services, _services) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    ownerId,
    ownerName,
    name,
    description,
    category,
    const DeepCollectionEquality().hash(_photoUrls),
    logoUrl,
    phone,
    email,
    website,
    address,
    city,
    country,
    latitude,
    longitude,
    const DeepCollectionEquality().hash(_openingHours),
    isVerified,
    isBoosted,
    boostExpiresAt,
    averageRating,
    reviewCount,
    viewCount,
    const DeepCollectionEquality().hash(_tags),
    const DeepCollectionEquality().hash(_services),
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of BusinessModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessModelImplCopyWith<_$BusinessModelImpl> get copyWith =>
      __$$BusinessModelImplCopyWithImpl<_$BusinessModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BusinessModelImplToJson(this);
  }
}

abstract class _BusinessModel extends BusinessModel {
  const factory _BusinessModel({
    required final String id,
    required final String ownerId,
    final String? ownerName,
    required final String name,
    required final String description,
    final String category,
    final List<String> photoUrls,
    final String? logoUrl,
    final String? phone,
    final String? email,
    final String? website,
    final String? address,
    final String? city,
    final String? country,
    final double? latitude,
    final double? longitude,
    final Map<String, dynamic> openingHours,
    final bool isVerified,
    final bool isBoosted,
    final DateTime? boostExpiresAt,
    final double averageRating,
    final int reviewCount,
    final int viewCount,
    final List<String> tags,
    final List<String> services,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$BusinessModelImpl;
  const _BusinessModel._() : super._();

  factory _BusinessModel.fromJson(Map<String, dynamic> json) =
      _$BusinessModelImpl.fromJson;

  @override
  String get id;
  @override
  String get ownerId;
  @override
  String? get ownerName;
  @override
  String get name;
  @override
  String get description;
  @override
  String get category;
  @override
  List<String> get photoUrls;
  @override
  String? get logoUrl;
  @override
  String? get phone;
  @override
  String? get email;
  @override
  String? get website;
  @override
  String? get address;
  @override
  String? get city;
  @override
  String? get country;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  Map<String, dynamic> get openingHours;
  @override
  bool get isVerified;
  @override
  bool get isBoosted;
  @override
  DateTime? get boostExpiresAt;
  @override
  double get averageRating;
  @override
  int get reviewCount;
  @override
  int get viewCount;
  @override
  List<String> get tags;
  @override
  List<String> get services;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of BusinessModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessModelImplCopyWith<_$BusinessModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
