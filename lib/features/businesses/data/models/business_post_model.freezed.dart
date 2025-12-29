// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BusinessPostModel _$BusinessPostModelFromJson(Map<String, dynamic> json) {
  return _BusinessPostModel.fromJson(json);
}

/// @nodoc
mixin _$BusinessPostModel {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  double? get originalPrice => throw _privateConstructorUsedError;
  double? get discountedPrice => throw _privateConstructorUsedError;
  int? get discountPercent => throw _privateConstructorUsedError;
  String? get offerStartDate => throw _privateConstructorUsedError;
  String? get offerEndDate => throw _privateConstructorUsedError;
  String? get promoCode => throw _privateConstructorUsedError;
  int get viewCount => throw _privateConstructorUsedError;
  int get likeCount => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get createdAt => throw _privateConstructorUsedError;
  String? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this BusinessPostModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BusinessPostModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BusinessPostModelCopyWith<BusinessPostModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusinessPostModelCopyWith<$Res> {
  factory $BusinessPostModelCopyWith(
    BusinessPostModel value,
    $Res Function(BusinessPostModel) then,
  ) = _$BusinessPostModelCopyWithImpl<$Res, BusinessPostModel>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String title,
    String content,
    String type,
    List<String> imageUrls,
    double? originalPrice,
    double? discountedPrice,
    int? discountPercent,
    String? offerStartDate,
    String? offerEndDate,
    String? promoCode,
    int viewCount,
    int likeCount,
    bool isActive,
    String? createdAt,
    String? updatedAt,
  });
}

/// @nodoc
class _$BusinessPostModelCopyWithImpl<$Res, $Val extends BusinessPostModel>
    implements $BusinessPostModelCopyWith<$Res> {
  _$BusinessPostModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BusinessPostModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? title = null,
    Object? content = null,
    Object? type = null,
    Object? imageUrls = null,
    Object? originalPrice = freezed,
    Object? discountedPrice = freezed,
    Object? discountPercent = freezed,
    Object? offerStartDate = freezed,
    Object? offerEndDate = freezed,
    Object? promoCode = freezed,
    Object? viewCount = null,
    Object? likeCount = null,
    Object? isActive = null,
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
            businessId:
                null == businessId
                    ? _value.businessId
                    : businessId // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrls:
                null == imageUrls
                    ? _value.imageUrls
                    : imageUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            originalPrice:
                freezed == originalPrice
                    ? _value.originalPrice
                    : originalPrice // ignore: cast_nullable_to_non_nullable
                        as double?,
            discountedPrice:
                freezed == discountedPrice
                    ? _value.discountedPrice
                    : discountedPrice // ignore: cast_nullable_to_non_nullable
                        as double?,
            discountPercent:
                freezed == discountPercent
                    ? _value.discountPercent
                    : discountPercent // ignore: cast_nullable_to_non_nullable
                        as int?,
            offerStartDate:
                freezed == offerStartDate
                    ? _value.offerStartDate
                    : offerStartDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            offerEndDate:
                freezed == offerEndDate
                    ? _value.offerEndDate
                    : offerEndDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            promoCode:
                freezed == promoCode
                    ? _value.promoCode
                    : promoCode // ignore: cast_nullable_to_non_nullable
                        as String?,
            viewCount:
                null == viewCount
                    ? _value.viewCount
                    : viewCount // ignore: cast_nullable_to_non_nullable
                        as int,
            likeCount:
                null == likeCount
                    ? _value.likeCount
                    : likeCount // ignore: cast_nullable_to_non_nullable
                        as int,
            isActive:
                null == isActive
                    ? _value.isActive
                    : isActive // ignore: cast_nullable_to_non_nullable
                        as bool,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BusinessPostModelImplCopyWith<$Res>
    implements $BusinessPostModelCopyWith<$Res> {
  factory _$$BusinessPostModelImplCopyWith(
    _$BusinessPostModelImpl value,
    $Res Function(_$BusinessPostModelImpl) then,
  ) = __$$BusinessPostModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String title,
    String content,
    String type,
    List<String> imageUrls,
    double? originalPrice,
    double? discountedPrice,
    int? discountPercent,
    String? offerStartDate,
    String? offerEndDate,
    String? promoCode,
    int viewCount,
    int likeCount,
    bool isActive,
    String? createdAt,
    String? updatedAt,
  });
}

/// @nodoc
class __$$BusinessPostModelImplCopyWithImpl<$Res>
    extends _$BusinessPostModelCopyWithImpl<$Res, _$BusinessPostModelImpl>
    implements _$$BusinessPostModelImplCopyWith<$Res> {
  __$$BusinessPostModelImplCopyWithImpl(
    _$BusinessPostModelImpl _value,
    $Res Function(_$BusinessPostModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BusinessPostModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? title = null,
    Object? content = null,
    Object? type = null,
    Object? imageUrls = null,
    Object? originalPrice = freezed,
    Object? discountedPrice = freezed,
    Object? discountPercent = freezed,
    Object? offerStartDate = freezed,
    Object? offerEndDate = freezed,
    Object? promoCode = freezed,
    Object? viewCount = null,
    Object? likeCount = null,
    Object? isActive = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$BusinessPostModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        businessId:
            null == businessId
                ? _value.businessId
                : businessId // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        content:
            null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrls:
            null == imageUrls
                ? _value._imageUrls
                : imageUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        originalPrice:
            freezed == originalPrice
                ? _value.originalPrice
                : originalPrice // ignore: cast_nullable_to_non_nullable
                    as double?,
        discountedPrice:
            freezed == discountedPrice
                ? _value.discountedPrice
                : discountedPrice // ignore: cast_nullable_to_non_nullable
                    as double?,
        discountPercent:
            freezed == discountPercent
                ? _value.discountPercent
                : discountPercent // ignore: cast_nullable_to_non_nullable
                    as int?,
        offerStartDate:
            freezed == offerStartDate
                ? _value.offerStartDate
                : offerStartDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        offerEndDate:
            freezed == offerEndDate
                ? _value.offerEndDate
                : offerEndDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        promoCode:
            freezed == promoCode
                ? _value.promoCode
                : promoCode // ignore: cast_nullable_to_non_nullable
                    as String?,
        viewCount:
            null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                    as int,
        likeCount:
            null == likeCount
                ? _value.likeCount
                : likeCount // ignore: cast_nullable_to_non_nullable
                    as int,
        isActive:
            null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                    as bool,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BusinessPostModelImpl extends _BusinessPostModel {
  const _$BusinessPostModelImpl({
    required this.id,
    required this.businessId,
    required this.title,
    required this.content,
    this.type = 'announcement',
    final List<String> imageUrls = const [],
    this.originalPrice,
    this.discountedPrice,
    this.discountPercent,
    this.offerStartDate,
    this.offerEndDate,
    this.promoCode,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : _imageUrls = imageUrls,
       super._();

  factory _$BusinessPostModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BusinessPostModelImplFromJson(json);

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String title;
  @override
  final String content;
  @override
  @JsonKey()
  final String type;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  final double? originalPrice;
  @override
  final double? discountedPrice;
  @override
  final int? discountPercent;
  @override
  final String? offerStartDate;
  @override
  final String? offerEndDate;
  @override
  final String? promoCode;
  @override
  @JsonKey()
  final int viewCount;
  @override
  @JsonKey()
  final int likeCount;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  @override
  String toString() {
    return 'BusinessPostModel(id: $id, businessId: $businessId, title: $title, content: $content, type: $type, imageUrls: $imageUrls, originalPrice: $originalPrice, discountedPrice: $discountedPrice, discountPercent: $discountPercent, offerStartDate: $offerStartDate, offerEndDate: $offerEndDate, promoCode: $promoCode, viewCount: $viewCount, likeCount: $likeCount, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessPostModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.originalPrice, originalPrice) ||
                other.originalPrice == originalPrice) &&
            (identical(other.discountedPrice, discountedPrice) ||
                other.discountedPrice == discountedPrice) &&
            (identical(other.discountPercent, discountPercent) ||
                other.discountPercent == discountPercent) &&
            (identical(other.offerStartDate, offerStartDate) ||
                other.offerStartDate == offerStartDate) &&
            (identical(other.offerEndDate, offerEndDate) ||
                other.offerEndDate == offerEndDate) &&
            (identical(other.promoCode, promoCode) ||
                other.promoCode == promoCode) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    title,
    content,
    type,
    const DeepCollectionEquality().hash(_imageUrls),
    originalPrice,
    discountedPrice,
    discountPercent,
    offerStartDate,
    offerEndDate,
    promoCode,
    viewCount,
    likeCount,
    isActive,
    createdAt,
    updatedAt,
  );

  /// Create a copy of BusinessPostModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessPostModelImplCopyWith<_$BusinessPostModelImpl> get copyWith =>
      __$$BusinessPostModelImplCopyWithImpl<_$BusinessPostModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BusinessPostModelImplToJson(this);
  }
}

abstract class _BusinessPostModel extends BusinessPostModel {
  const factory _BusinessPostModel({
    required final String id,
    required final String businessId,
    required final String title,
    required final String content,
    final String type,
    final List<String> imageUrls,
    final double? originalPrice,
    final double? discountedPrice,
    final int? discountPercent,
    final String? offerStartDate,
    final String? offerEndDate,
    final String? promoCode,
    final int viewCount,
    final int likeCount,
    final bool isActive,
    final String? createdAt,
    final String? updatedAt,
  }) = _$BusinessPostModelImpl;
  const _BusinessPostModel._() : super._();

  factory _BusinessPostModel.fromJson(Map<String, dynamic> json) =
      _$BusinessPostModelImpl.fromJson;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get title;
  @override
  String get content;
  @override
  String get type;
  @override
  List<String> get imageUrls;
  @override
  double? get originalPrice;
  @override
  double? get discountedPrice;
  @override
  int? get discountPercent;
  @override
  String? get offerStartDate;
  @override
  String? get offerEndDate;
  @override
  String? get promoCode;
  @override
  int get viewCount;
  @override
  int get likeCount;
  @override
  bool get isActive;
  @override
  String? get createdAt;
  @override
  String? get updatedAt;

  /// Create a copy of BusinessPostModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessPostModelImplCopyWith<_$BusinessPostModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
