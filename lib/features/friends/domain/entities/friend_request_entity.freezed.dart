// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_request_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FriendRequestEntity {
  String get id => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  String? get senderPhotoUrl => throw _privateConstructorUsedError;
  String get receiverId => throw _privateConstructorUsedError;
  String get receiverName => throw _privateConstructorUsedError;
  String? get receiverPhotoUrl => throw _privateConstructorUsedError;
  FriendRequestStatus get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of FriendRequestEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendRequestEntityCopyWith<FriendRequestEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendRequestEntityCopyWith<$Res> {
  factory $FriendRequestEntityCopyWith(
    FriendRequestEntity value,
    $Res Function(FriendRequestEntity) then,
  ) = _$FriendRequestEntityCopyWithImpl<$Res, FriendRequestEntity>;
  @useResult
  $Res call({
    String id,
    String senderId,
    String senderName,
    String? senderPhotoUrl,
    String receiverId,
    String receiverName,
    String? receiverPhotoUrl,
    FriendRequestStatus status,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$FriendRequestEntityCopyWithImpl<$Res, $Val extends FriendRequestEntity>
    implements $FriendRequestEntityCopyWith<$Res> {
  _$FriendRequestEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendRequestEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderPhotoUrl = freezed,
    Object? receiverId = null,
    Object? receiverName = null,
    Object? receiverPhotoUrl = freezed,
    Object? status = null,
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
            senderId:
                null == senderId
                    ? _value.senderId
                    : senderId // ignore: cast_nullable_to_non_nullable
                        as String,
            senderName:
                null == senderName
                    ? _value.senderName
                    : senderName // ignore: cast_nullable_to_non_nullable
                        as String,
            senderPhotoUrl:
                freezed == senderPhotoUrl
                    ? _value.senderPhotoUrl
                    : senderPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            receiverId:
                null == receiverId
                    ? _value.receiverId
                    : receiverId // ignore: cast_nullable_to_non_nullable
                        as String,
            receiverName:
                null == receiverName
                    ? _value.receiverName
                    : receiverName // ignore: cast_nullable_to_non_nullable
                        as String,
            receiverPhotoUrl:
                freezed == receiverPhotoUrl
                    ? _value.receiverPhotoUrl
                    : receiverPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as FriendRequestStatus,
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
abstract class _$$FriendRequestEntityImplCopyWith<$Res>
    implements $FriendRequestEntityCopyWith<$Res> {
  factory _$$FriendRequestEntityImplCopyWith(
    _$FriendRequestEntityImpl value,
    $Res Function(_$FriendRequestEntityImpl) then,
  ) = __$$FriendRequestEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String senderId,
    String senderName,
    String? senderPhotoUrl,
    String receiverId,
    String receiverName,
    String? receiverPhotoUrl,
    FriendRequestStatus status,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$FriendRequestEntityImplCopyWithImpl<$Res>
    extends _$FriendRequestEntityCopyWithImpl<$Res, _$FriendRequestEntityImpl>
    implements _$$FriendRequestEntityImplCopyWith<$Res> {
  __$$FriendRequestEntityImplCopyWithImpl(
    _$FriendRequestEntityImpl _value,
    $Res Function(_$FriendRequestEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendRequestEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderPhotoUrl = freezed,
    Object? receiverId = null,
    Object? receiverName = null,
    Object? receiverPhotoUrl = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$FriendRequestEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        senderId:
            null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                    as String,
        senderName:
            null == senderName
                ? _value.senderName
                : senderName // ignore: cast_nullable_to_non_nullable
                    as String,
        senderPhotoUrl:
            freezed == senderPhotoUrl
                ? _value.senderPhotoUrl
                : senderPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        receiverId:
            null == receiverId
                ? _value.receiverId
                : receiverId // ignore: cast_nullable_to_non_nullable
                    as String,
        receiverName:
            null == receiverName
                ? _value.receiverName
                : receiverName // ignore: cast_nullable_to_non_nullable
                    as String,
        receiverPhotoUrl:
            freezed == receiverPhotoUrl
                ? _value.receiverPhotoUrl
                : receiverPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as FriendRequestStatus,
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

class _$FriendRequestEntityImpl implements _FriendRequestEntity {
  const _$FriendRequestEntityImpl({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl,
    this.status = FriendRequestStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  @override
  final String id;
  @override
  final String senderId;
  @override
  final String senderName;
  @override
  final String? senderPhotoUrl;
  @override
  final String receiverId;
  @override
  final String receiverName;
  @override
  final String? receiverPhotoUrl;
  @override
  @JsonKey()
  final FriendRequestStatus status;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'FriendRequestEntity(id: $id, senderId: $senderId, senderName: $senderName, senderPhotoUrl: $senderPhotoUrl, receiverId: $receiverId, receiverName: $receiverName, receiverPhotoUrl: $receiverPhotoUrl, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendRequestEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderPhotoUrl, senderPhotoUrl) ||
                other.senderPhotoUrl == senderPhotoUrl) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.receiverName, receiverName) ||
                other.receiverName == receiverName) &&
            (identical(other.receiverPhotoUrl, receiverPhotoUrl) ||
                other.receiverPhotoUrl == receiverPhotoUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    senderId,
    senderName,
    senderPhotoUrl,
    receiverId,
    receiverName,
    receiverPhotoUrl,
    status,
    createdAt,
    updatedAt,
  );

  /// Create a copy of FriendRequestEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendRequestEntityImplCopyWith<_$FriendRequestEntityImpl> get copyWith =>
      __$$FriendRequestEntityImplCopyWithImpl<_$FriendRequestEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _FriendRequestEntity implements FriendRequestEntity {
  const factory _FriendRequestEntity({
    required final String id,
    required final String senderId,
    required final String senderName,
    final String? senderPhotoUrl,
    required final String receiverId,
    required final String receiverName,
    final String? receiverPhotoUrl,
    final FriendRequestStatus status,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$FriendRequestEntityImpl;

  @override
  String get id;
  @override
  String get senderId;
  @override
  String get senderName;
  @override
  String? get senderPhotoUrl;
  @override
  String get receiverId;
  @override
  String get receiverName;
  @override
  String? get receiverPhotoUrl;
  @override
  FriendRequestStatus get status;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of FriendRequestEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendRequestEntityImplCopyWith<_$FriendRequestEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
