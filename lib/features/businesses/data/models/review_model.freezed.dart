// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReviewModel _$ReviewModelFromJson(Map<String, dynamic> json) {
  return _ReviewModel.fromJson(json);
}

/// @nodoc
mixin _$ReviewModel {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get userDisplayName => throw _privateConstructorUsedError;
  String? get userPhotoUrl => throw _privateConstructorUsedError;
  int get rating => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  int get helpfulCount => throw _privateConstructorUsedError;
  List<String> get helpfulByUserIds => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get ownerReply => throw _privateConstructorUsedError;
  String? get ownerReplyAt => throw _privateConstructorUsedError;
  String? get createdAt => throw _privateConstructorUsedError;
  String? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ReviewModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewModelCopyWith<ReviewModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewModelCopyWith<$Res> {
  factory $ReviewModelCopyWith(
    ReviewModel value,
    $Res Function(ReviewModel) then,
  ) = _$ReviewModelCopyWithImpl<$Res, ReviewModel>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    String userDisplayName,
    String? userPhotoUrl,
    int rating,
    String? title,
    String content,
    List<String> imageUrls,
    int helpfulCount,
    List<String> helpfulByUserIds,
    String status,
    String? ownerReply,
    String? ownerReplyAt,
    String? createdAt,
    String? updatedAt,
  });
}

/// @nodoc
class _$ReviewModelCopyWithImpl<$Res, $Val extends ReviewModel>
    implements $ReviewModelCopyWith<$Res> {
  _$ReviewModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? userId = null,
    Object? userDisplayName = null,
    Object? userPhotoUrl = freezed,
    Object? rating = null,
    Object? title = freezed,
    Object? content = null,
    Object? imageUrls = null,
    Object? helpfulCount = null,
    Object? helpfulByUserIds = null,
    Object? status = null,
    Object? ownerReply = freezed,
    Object? ownerReplyAt = freezed,
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
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            userDisplayName:
                null == userDisplayName
                    ? _value.userDisplayName
                    : userDisplayName // ignore: cast_nullable_to_non_nullable
                        as String,
            userPhotoUrl:
                freezed == userPhotoUrl
                    ? _value.userPhotoUrl
                    : userPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            rating:
                null == rating
                    ? _value.rating
                    : rating // ignore: cast_nullable_to_non_nullable
                        as int,
            title:
                freezed == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String?,
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrls:
                null == imageUrls
                    ? _value.imageUrls
                    : imageUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            helpfulCount:
                null == helpfulCount
                    ? _value.helpfulCount
                    : helpfulCount // ignore: cast_nullable_to_non_nullable
                        as int,
            helpfulByUserIds:
                null == helpfulByUserIds
                    ? _value.helpfulByUserIds
                    : helpfulByUserIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            ownerReply:
                freezed == ownerReply
                    ? _value.ownerReply
                    : ownerReply // ignore: cast_nullable_to_non_nullable
                        as String?,
            ownerReplyAt:
                freezed == ownerReplyAt
                    ? _value.ownerReplyAt
                    : ownerReplyAt // ignore: cast_nullable_to_non_nullable
                        as String?,
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
abstract class _$$ReviewModelImplCopyWith<$Res>
    implements $ReviewModelCopyWith<$Res> {
  factory _$$ReviewModelImplCopyWith(
    _$ReviewModelImpl value,
    $Res Function(_$ReviewModelImpl) then,
  ) = __$$ReviewModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    String userDisplayName,
    String? userPhotoUrl,
    int rating,
    String? title,
    String content,
    List<String> imageUrls,
    int helpfulCount,
    List<String> helpfulByUserIds,
    String status,
    String? ownerReply,
    String? ownerReplyAt,
    String? createdAt,
    String? updatedAt,
  });
}

/// @nodoc
class __$$ReviewModelImplCopyWithImpl<$Res>
    extends _$ReviewModelCopyWithImpl<$Res, _$ReviewModelImpl>
    implements _$$ReviewModelImplCopyWith<$Res> {
  __$$ReviewModelImplCopyWithImpl(
    _$ReviewModelImpl _value,
    $Res Function(_$ReviewModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? userId = null,
    Object? userDisplayName = null,
    Object? userPhotoUrl = freezed,
    Object? rating = null,
    Object? title = freezed,
    Object? content = null,
    Object? imageUrls = null,
    Object? helpfulCount = null,
    Object? helpfulByUserIds = null,
    Object? status = null,
    Object? ownerReply = freezed,
    Object? ownerReplyAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ReviewModelImpl(
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
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        userDisplayName:
            null == userDisplayName
                ? _value.userDisplayName
                : userDisplayName // ignore: cast_nullable_to_non_nullable
                    as String,
        userPhotoUrl:
            freezed == userPhotoUrl
                ? _value.userPhotoUrl
                : userPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        rating:
            null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                    as int,
        title:
            freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String?,
        content:
            null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrls:
            null == imageUrls
                ? _value._imageUrls
                : imageUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        helpfulCount:
            null == helpfulCount
                ? _value.helpfulCount
                : helpfulCount // ignore: cast_nullable_to_non_nullable
                    as int,
        helpfulByUserIds:
            null == helpfulByUserIds
                ? _value._helpfulByUserIds
                : helpfulByUserIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        ownerReply:
            freezed == ownerReply
                ? _value.ownerReply
                : ownerReply // ignore: cast_nullable_to_non_nullable
                    as String?,
        ownerReplyAt:
            freezed == ownerReplyAt
                ? _value.ownerReplyAt
                : ownerReplyAt // ignore: cast_nullable_to_non_nullable
                    as String?,
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
class _$ReviewModelImpl extends _ReviewModel {
  const _$ReviewModelImpl({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoUrl,
    required this.rating,
    this.title,
    required this.content,
    final List<String> imageUrls = const [],
    this.helpfulCount = 0,
    final List<String> helpfulByUserIds = const [],
    this.status = 'published',
    this.ownerReply,
    this.ownerReplyAt,
    this.createdAt,
    this.updatedAt,
  }) : _imageUrls = imageUrls,
       _helpfulByUserIds = helpfulByUserIds,
       super._();

  factory _$ReviewModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewModelImplFromJson(json);

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String userId;
  @override
  final String userDisplayName;
  @override
  final String? userPhotoUrl;
  @override
  final int rating;
  @override
  final String? title;
  @override
  final String content;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  @JsonKey()
  final int helpfulCount;
  final List<String> _helpfulByUserIds;
  @override
  @JsonKey()
  List<String> get helpfulByUserIds {
    if (_helpfulByUserIds is EqualUnmodifiableListView)
      return _helpfulByUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_helpfulByUserIds);
  }

  @override
  @JsonKey()
  final String status;
  @override
  final String? ownerReply;
  @override
  final String? ownerReplyAt;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  @override
  String toString() {
    return 'ReviewModel(id: $id, businessId: $businessId, userId: $userId, userDisplayName: $userDisplayName, userPhotoUrl: $userPhotoUrl, rating: $rating, title: $title, content: $content, imageUrls: $imageUrls, helpfulCount: $helpfulCount, helpfulByUserIds: $helpfulByUserIds, status: $status, ownerReply: $ownerReply, ownerReplyAt: $ownerReplyAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userDisplayName, userDisplayName) ||
                other.userDisplayName == userDisplayName) &&
            (identical(other.userPhotoUrl, userPhotoUrl) ||
                other.userPhotoUrl == userPhotoUrl) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.helpfulCount, helpfulCount) ||
                other.helpfulCount == helpfulCount) &&
            const DeepCollectionEquality().equals(
              other._helpfulByUserIds,
              _helpfulByUserIds,
            ) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.ownerReply, ownerReply) ||
                other.ownerReply == ownerReply) &&
            (identical(other.ownerReplyAt, ownerReplyAt) ||
                other.ownerReplyAt == ownerReplyAt) &&
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
    userId,
    userDisplayName,
    userPhotoUrl,
    rating,
    title,
    content,
    const DeepCollectionEquality().hash(_imageUrls),
    helpfulCount,
    const DeepCollectionEquality().hash(_helpfulByUserIds),
    status,
    ownerReply,
    ownerReplyAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of ReviewModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewModelImplCopyWith<_$ReviewModelImpl> get copyWith =>
      __$$ReviewModelImplCopyWithImpl<_$ReviewModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewModelImplToJson(this);
  }
}

abstract class _ReviewModel extends ReviewModel {
  const factory _ReviewModel({
    required final String id,
    required final String businessId,
    required final String userId,
    required final String userDisplayName,
    final String? userPhotoUrl,
    required final int rating,
    final String? title,
    required final String content,
    final List<String> imageUrls,
    final int helpfulCount,
    final List<String> helpfulByUserIds,
    final String status,
    final String? ownerReply,
    final String? ownerReplyAt,
    final String? createdAt,
    final String? updatedAt,
  }) = _$ReviewModelImpl;
  const _ReviewModel._() : super._();

  factory _ReviewModel.fromJson(Map<String, dynamic> json) =
      _$ReviewModelImpl.fromJson;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get userId;
  @override
  String get userDisplayName;
  @override
  String? get userPhotoUrl;
  @override
  int get rating;
  @override
  String? get title;
  @override
  String get content;
  @override
  List<String> get imageUrls;
  @override
  int get helpfulCount;
  @override
  List<String> get helpfulByUserIds;
  @override
  String get status;
  @override
  String? get ownerReply;
  @override
  String? get ownerReplyAt;
  @override
  String? get createdAt;
  @override
  String? get updatedAt;

  /// Create a copy of ReviewModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewModelImplCopyWith<_$ReviewModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
