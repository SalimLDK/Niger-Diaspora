// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FriendRequestModel _$FriendRequestModelFromJson(Map<String, dynamic> json) {
  return _FriendRequestModel.fromJson(json);
}

/// @nodoc
mixin _$FriendRequestModel {
  String get id => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  String? get senderPhotoUrl => throw _privateConstructorUsedError;
  String get receiverId => throw _privateConstructorUsedError;
  String get receiverName => throw _privateConstructorUsedError;
  String? get receiverPhotoUrl => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this FriendRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendRequestModelCopyWith<FriendRequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendRequestModelCopyWith<$Res> {
  factory $FriendRequestModelCopyWith(
    FriendRequestModel value,
    $Res Function(FriendRequestModel) then,
  ) = _$FriendRequestModelCopyWithImpl<$Res, FriendRequestModel>;
  @useResult
  $Res call({
    String id,
    String senderId,
    String senderName,
    String? senderPhotoUrl,
    String receiverId,
    String receiverName,
    String? receiverPhotoUrl,
    String status,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$FriendRequestModelCopyWithImpl<$Res, $Val extends FriendRequestModel>
    implements $FriendRequestModelCopyWith<$Res> {
  _$FriendRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendRequestModel
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
                        as String,
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
abstract class _$$FriendRequestModelImplCopyWith<$Res>
    implements $FriendRequestModelCopyWith<$Res> {
  factory _$$FriendRequestModelImplCopyWith(
    _$FriendRequestModelImpl value,
    $Res Function(_$FriendRequestModelImpl) then,
  ) = __$$FriendRequestModelImplCopyWithImpl<$Res>;
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
    String status,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$FriendRequestModelImplCopyWithImpl<$Res>
    extends _$FriendRequestModelCopyWithImpl<$Res, _$FriendRequestModelImpl>
    implements _$$FriendRequestModelImplCopyWith<$Res> {
  __$$FriendRequestModelImplCopyWithImpl(
    _$FriendRequestModelImpl _value,
    $Res Function(_$FriendRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendRequestModel
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
      _$FriendRequestModelImpl(
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
                    as String,
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
class _$FriendRequestModelImpl extends _FriendRequestModel {
  const _$FriendRequestModelImpl({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
  }) : super._();

  factory _$FriendRequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendRequestModelImplFromJson(json);

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
  final String status;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'FriendRequestModel(id: $id, senderId: $senderId, senderName: $senderName, senderPhotoUrl: $senderPhotoUrl, receiverId: $receiverId, receiverName: $receiverName, receiverPhotoUrl: $receiverPhotoUrl, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendRequestModelImpl &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of FriendRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendRequestModelImplCopyWith<_$FriendRequestModelImpl> get copyWith =>
      __$$FriendRequestModelImplCopyWithImpl<_$FriendRequestModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendRequestModelImplToJson(this);
  }
}

abstract class _FriendRequestModel extends FriendRequestModel {
  const factory _FriendRequestModel({
    required final String id,
    required final String senderId,
    required final String senderName,
    final String? senderPhotoUrl,
    required final String receiverId,
    required final String receiverName,
    final String? receiverPhotoUrl,
    final String status,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$FriendRequestModelImpl;
  const _FriendRequestModel._() : super._();

  factory _FriendRequestModel.fromJson(Map<String, dynamic> json) =
      _$FriendRequestModelImpl.fromJson;

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
  String get status;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of FriendRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendRequestModelImplCopyWith<_$FriendRequestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
