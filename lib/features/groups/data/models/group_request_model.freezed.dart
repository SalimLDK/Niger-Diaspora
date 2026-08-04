// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GroupRequestModel _$GroupRequestModelFromJson(Map<String, dynamic> json) {
  return _GroupRequestModel.fromJson(json);
}

/// @nodoc
mixin _$GroupRequestModel {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get groupName => throw _privateConstructorUsedError;
  String? get groupImageUrl => throw _privateConstructorUsedError;
  String get requesterId => throw _privateConstructorUsedError;
  String get requesterName => throw _privateConstructorUsedError;
  String? get requesterPhotoUrl => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @LocalDateTimeNullableConverter()
  DateTime? get processedAt => throw _privateConstructorUsedError;
  String? get processedBy => throw _privateConstructorUsedError;

  /// Serializes this GroupRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupRequestModelCopyWith<GroupRequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupRequestModelCopyWith<$Res> {
  factory $GroupRequestModelCopyWith(
    GroupRequestModel value,
    $Res Function(GroupRequestModel) then,
  ) = _$GroupRequestModelCopyWithImpl<$Res, GroupRequestModel>;
  @useResult
  $Res call({
    String id,
    String groupId,
    String groupName,
    String? groupImageUrl,
    String requesterId,
    String requesterName,
    String? requesterPhotoUrl,
    String status,
    String? message,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
    @LocalDateTimeNullableConverter() DateTime? processedAt,
    String? processedBy,
  });
}

/// @nodoc
class _$GroupRequestModelCopyWithImpl<$Res, $Val extends GroupRequestModel>
    implements $GroupRequestModelCopyWith<$Res> {
  _$GroupRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? groupName = null,
    Object? groupImageUrl = freezed,
    Object? requesterId = null,
    Object? requesterName = null,
    Object? requesterPhotoUrl = freezed,
    Object? status = null,
    Object? message = freezed,
    Object? createdAt = freezed,
    Object? processedAt = freezed,
    Object? processedBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            groupId:
                null == groupId
                    ? _value.groupId
                    : groupId // ignore: cast_nullable_to_non_nullable
                        as String,
            groupName:
                null == groupName
                    ? _value.groupName
                    : groupName // ignore: cast_nullable_to_non_nullable
                        as String,
            groupImageUrl:
                freezed == groupImageUrl
                    ? _value.groupImageUrl
                    : groupImageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            requesterId:
                null == requesterId
                    ? _value.requesterId
                    : requesterId // ignore: cast_nullable_to_non_nullable
                        as String,
            requesterName:
                null == requesterName
                    ? _value.requesterName
                    : requesterName // ignore: cast_nullable_to_non_nullable
                        as String,
            requesterPhotoUrl:
                freezed == requesterPhotoUrl
                    ? _value.requesterPhotoUrl
                    : requesterPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            message:
                freezed == message
                    ? _value.message
                    : message // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            processedAt:
                freezed == processedAt
                    ? _value.processedAt
                    : processedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            processedBy:
                freezed == processedBy
                    ? _value.processedBy
                    : processedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupRequestModelImplCopyWith<$Res>
    implements $GroupRequestModelCopyWith<$Res> {
  factory _$$GroupRequestModelImplCopyWith(
    _$GroupRequestModelImpl value,
    $Res Function(_$GroupRequestModelImpl) then,
  ) = __$$GroupRequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String groupId,
    String groupName,
    String? groupImageUrl,
    String requesterId,
    String requesterName,
    String? requesterPhotoUrl,
    String status,
    String? message,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
    @LocalDateTimeNullableConverter() DateTime? processedAt,
    String? processedBy,
  });
}

/// @nodoc
class __$$GroupRequestModelImplCopyWithImpl<$Res>
    extends _$GroupRequestModelCopyWithImpl<$Res, _$GroupRequestModelImpl>
    implements _$$GroupRequestModelImplCopyWith<$Res> {
  __$$GroupRequestModelImplCopyWithImpl(
    _$GroupRequestModelImpl _value,
    $Res Function(_$GroupRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? groupName = null,
    Object? groupImageUrl = freezed,
    Object? requesterId = null,
    Object? requesterName = null,
    Object? requesterPhotoUrl = freezed,
    Object? status = null,
    Object? message = freezed,
    Object? createdAt = freezed,
    Object? processedAt = freezed,
    Object? processedBy = freezed,
  }) {
    return _then(
      _$GroupRequestModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        groupId:
            null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                    as String,
        groupName:
            null == groupName
                ? _value.groupName
                : groupName // ignore: cast_nullable_to_non_nullable
                    as String,
        groupImageUrl:
            freezed == groupImageUrl
                ? _value.groupImageUrl
                : groupImageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        requesterId:
            null == requesterId
                ? _value.requesterId
                : requesterId // ignore: cast_nullable_to_non_nullable
                    as String,
        requesterName:
            null == requesterName
                ? _value.requesterName
                : requesterName // ignore: cast_nullable_to_non_nullable
                    as String,
        requesterPhotoUrl:
            freezed == requesterPhotoUrl
                ? _value.requesterPhotoUrl
                : requesterPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        message:
            freezed == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        processedAt:
            freezed == processedAt
                ? _value.processedAt
                : processedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        processedBy:
            freezed == processedBy
                ? _value.processedBy
                : processedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupRequestModelImpl extends _GroupRequestModel {
  const _$GroupRequestModelImpl({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhotoUrl,
    this.status = 'pending',
    this.message,
    @LocalDateTimeNullableConverter() this.createdAt,
    @LocalDateTimeNullableConverter() this.processedAt,
    this.processedBy,
  }) : super._();

  factory _$GroupRequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupRequestModelImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String groupName;
  @override
  final String? groupImageUrl;
  @override
  final String requesterId;
  @override
  final String requesterName;
  @override
  final String? requesterPhotoUrl;
  @override
  @JsonKey()
  final String status;
  @override
  final String? message;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? createdAt;
  @override
  @LocalDateTimeNullableConverter()
  final DateTime? processedAt;
  @override
  final String? processedBy;

  @override
  String toString() {
    return 'GroupRequestModel(id: $id, groupId: $groupId, groupName: $groupName, groupImageUrl: $groupImageUrl, requesterId: $requesterId, requesterName: $requesterName, requesterPhotoUrl: $requesterPhotoUrl, status: $status, message: $message, createdAt: $createdAt, processedAt: $processedAt, processedBy: $processedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupRequestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.groupImageUrl, groupImageUrl) ||
                other.groupImageUrl == groupImageUrl) &&
            (identical(other.requesterId, requesterId) ||
                other.requesterId == requesterId) &&
            (identical(other.requesterName, requesterName) ||
                other.requesterName == requesterName) &&
            (identical(other.requesterPhotoUrl, requesterPhotoUrl) ||
                other.requesterPhotoUrl == requesterPhotoUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.processedAt, processedAt) ||
                other.processedAt == processedAt) &&
            (identical(other.processedBy, processedBy) ||
                other.processedBy == processedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    groupId,
    groupName,
    groupImageUrl,
    requesterId,
    requesterName,
    requesterPhotoUrl,
    status,
    message,
    createdAt,
    processedAt,
    processedBy,
  );

  /// Create a copy of GroupRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupRequestModelImplCopyWith<_$GroupRequestModelImpl> get copyWith =>
      __$$GroupRequestModelImplCopyWithImpl<_$GroupRequestModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupRequestModelImplToJson(this);
  }
}

abstract class _GroupRequestModel extends GroupRequestModel {
  const factory _GroupRequestModel({
    required final String id,
    required final String groupId,
    required final String groupName,
    final String? groupImageUrl,
    required final String requesterId,
    required final String requesterName,
    final String? requesterPhotoUrl,
    final String status,
    final String? message,
    @LocalDateTimeNullableConverter() final DateTime? createdAt,
    @LocalDateTimeNullableConverter() final DateTime? processedAt,
    final String? processedBy,
  }) = _$GroupRequestModelImpl;
  const _GroupRequestModel._() : super._();

  factory _GroupRequestModel.fromJson(Map<String, dynamic> json) =
      _$GroupRequestModelImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get groupName;
  @override
  String? get groupImageUrl;
  @override
  String get requesterId;
  @override
  String get requesterName;
  @override
  String? get requesterPhotoUrl;
  @override
  String get status;
  @override
  String? get message;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get createdAt;
  @override
  @LocalDateTimeNullableConverter()
  DateTime? get processedAt;
  @override
  String? get processedBy;

  /// Create a copy of GroupRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupRequestModelImplCopyWith<_$GroupRequestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
