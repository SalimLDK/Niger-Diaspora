// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ReviewEntity {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get userDisplayName => throw _privateConstructorUsedError;
  String? get userPhotoUrl => throw _privateConstructorUsedError;
  int get rating => throw _privateConstructorUsedError; // 1-5
  String? get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  int get helpfulCount => throw _privateConstructorUsedError;
  List<String> get helpfulByUserIds => throw _privateConstructorUsedError;
  ReviewStatus get status =>
      throw _privateConstructorUsedError; // Réponse du gérant de l'entreprise à cet avis (§18c).
  String? get ownerReply => throw _privateConstructorUsedError;
  DateTime? get ownerReplyAt => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of ReviewEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewEntityCopyWith<ReviewEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewEntityCopyWith<$Res> {
  factory $ReviewEntityCopyWith(
    ReviewEntity value,
    $Res Function(ReviewEntity) then,
  ) = _$ReviewEntityCopyWithImpl<$Res, ReviewEntity>;
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
    ReviewStatus status,
    String? ownerReply,
    DateTime? ownerReplyAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$ReviewEntityCopyWithImpl<$Res, $Val extends ReviewEntity>
    implements $ReviewEntityCopyWith<$Res> {
  _$ReviewEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewEntity
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
                        as ReviewStatus,
            ownerReply:
                freezed == ownerReply
                    ? _value.ownerReply
                    : ownerReply // ignore: cast_nullable_to_non_nullable
                        as String?,
            ownerReplyAt:
                freezed == ownerReplyAt
                    ? _value.ownerReplyAt
                    : ownerReplyAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
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
abstract class _$$ReviewEntityImplCopyWith<$Res>
    implements $ReviewEntityCopyWith<$Res> {
  factory _$$ReviewEntityImplCopyWith(
    _$ReviewEntityImpl value,
    $Res Function(_$ReviewEntityImpl) then,
  ) = __$$ReviewEntityImplCopyWithImpl<$Res>;
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
    ReviewStatus status,
    String? ownerReply,
    DateTime? ownerReplyAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ReviewEntityImplCopyWithImpl<$Res>
    extends _$ReviewEntityCopyWithImpl<$Res, _$ReviewEntityImpl>
    implements _$$ReviewEntityImplCopyWith<$Res> {
  __$$ReviewEntityImplCopyWithImpl(
    _$ReviewEntityImpl _value,
    $Res Function(_$ReviewEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewEntity
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
      _$ReviewEntityImpl(
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
                    as ReviewStatus,
        ownerReply:
            freezed == ownerReply
                ? _value.ownerReply
                : ownerReply // ignore: cast_nullable_to_non_nullable
                    as String?,
        ownerReplyAt:
            freezed == ownerReplyAt
                ? _value.ownerReplyAt
                : ownerReplyAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
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

class _$ReviewEntityImpl implements _ReviewEntity {
  const _$ReviewEntityImpl({
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
    this.status = ReviewStatus.published,
    this.ownerReply,
    this.ownerReplyAt,
    this.createdAt,
    this.updatedAt,
  }) : _imageUrls = imageUrls,
       _helpfulByUserIds = helpfulByUserIds;

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
  // 1-5
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
  final ReviewStatus status;
  // Réponse du gérant de l'entreprise à cet avis (§18c).
  @override
  final String? ownerReply;
  @override
  final DateTime? ownerReplyAt;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ReviewEntity(id: $id, businessId: $businessId, userId: $userId, userDisplayName: $userDisplayName, userPhotoUrl: $userPhotoUrl, rating: $rating, title: $title, content: $content, imageUrls: $imageUrls, helpfulCount: $helpfulCount, helpfulByUserIds: $helpfulByUserIds, status: $status, ownerReply: $ownerReply, ownerReplyAt: $ownerReplyAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewEntityImpl &&
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

  /// Create a copy of ReviewEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewEntityImplCopyWith<_$ReviewEntityImpl> get copyWith =>
      __$$ReviewEntityImplCopyWithImpl<_$ReviewEntityImpl>(this, _$identity);
}

abstract class _ReviewEntity implements ReviewEntity {
  const factory _ReviewEntity({
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
    final ReviewStatus status,
    final String? ownerReply,
    final DateTime? ownerReplyAt,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ReviewEntityImpl;

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
  int get rating; // 1-5
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
  ReviewStatus get status; // Réponse du gérant de l'entreprise à cet avis (§18c).
  @override
  String? get ownerReply;
  @override
  DateTime? get ownerReplyAt;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of ReviewEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewEntityImplCopyWith<_$ReviewEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
