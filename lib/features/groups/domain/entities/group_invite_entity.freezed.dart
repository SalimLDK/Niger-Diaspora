// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_invite_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GroupInviteEntity {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get groupName => throw _privateConstructorUsedError;
  String? get groupImageUrl => throw _privateConstructorUsedError;
  String get inviterId => throw _privateConstructorUsedError;
  String get inviterName => throw _privateConstructorUsedError;
  String get inviteeId => throw _privateConstructorUsedError;
  String get inviteeName => throw _privateConstructorUsedError;
  String? get inviteePhotoUrl => throw _privateConstructorUsedError;
  GroupInviteStatus get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get respondedAt => throw _privateConstructorUsedError;

  /// Create a copy of GroupInviteEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupInviteEntityCopyWith<GroupInviteEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupInviteEntityCopyWith<$Res> {
  factory $GroupInviteEntityCopyWith(
    GroupInviteEntity value,
    $Res Function(GroupInviteEntity) then,
  ) = _$GroupInviteEntityCopyWithImpl<$Res, GroupInviteEntity>;
  @useResult
  $Res call({
    String id,
    String groupId,
    String groupName,
    String? groupImageUrl,
    String inviterId,
    String inviterName,
    String inviteeId,
    String inviteeName,
    String? inviteePhotoUrl,
    GroupInviteStatus status,
    DateTime? createdAt,
    DateTime? respondedAt,
  });
}

/// @nodoc
class _$GroupInviteEntityCopyWithImpl<$Res, $Val extends GroupInviteEntity>
    implements $GroupInviteEntityCopyWith<$Res> {
  _$GroupInviteEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupInviteEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? groupName = null,
    Object? groupImageUrl = freezed,
    Object? inviterId = null,
    Object? inviterName = null,
    Object? inviteeId = null,
    Object? inviteeName = null,
    Object? inviteePhotoUrl = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? respondedAt = freezed,
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
            inviterId:
                null == inviterId
                    ? _value.inviterId
                    : inviterId // ignore: cast_nullable_to_non_nullable
                        as String,
            inviterName:
                null == inviterName
                    ? _value.inviterName
                    : inviterName // ignore: cast_nullable_to_non_nullable
                        as String,
            inviteeId:
                null == inviteeId
                    ? _value.inviteeId
                    : inviteeId // ignore: cast_nullable_to_non_nullable
                        as String,
            inviteeName:
                null == inviteeName
                    ? _value.inviteeName
                    : inviteeName // ignore: cast_nullable_to_non_nullable
                        as String,
            inviteePhotoUrl:
                freezed == inviteePhotoUrl
                    ? _value.inviteePhotoUrl
                    : inviteePhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as GroupInviteStatus,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            respondedAt:
                freezed == respondedAt
                    ? _value.respondedAt
                    : respondedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupInviteEntityImplCopyWith<$Res>
    implements $GroupInviteEntityCopyWith<$Res> {
  factory _$$GroupInviteEntityImplCopyWith(
    _$GroupInviteEntityImpl value,
    $Res Function(_$GroupInviteEntityImpl) then,
  ) = __$$GroupInviteEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String groupId,
    String groupName,
    String? groupImageUrl,
    String inviterId,
    String inviterName,
    String inviteeId,
    String inviteeName,
    String? inviteePhotoUrl,
    GroupInviteStatus status,
    DateTime? createdAt,
    DateTime? respondedAt,
  });
}

/// @nodoc
class __$$GroupInviteEntityImplCopyWithImpl<$Res>
    extends _$GroupInviteEntityCopyWithImpl<$Res, _$GroupInviteEntityImpl>
    implements _$$GroupInviteEntityImplCopyWith<$Res> {
  __$$GroupInviteEntityImplCopyWithImpl(
    _$GroupInviteEntityImpl _value,
    $Res Function(_$GroupInviteEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupInviteEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? groupName = null,
    Object? groupImageUrl = freezed,
    Object? inviterId = null,
    Object? inviterName = null,
    Object? inviteeId = null,
    Object? inviteeName = null,
    Object? inviteePhotoUrl = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? respondedAt = freezed,
  }) {
    return _then(
      _$GroupInviteEntityImpl(
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
        inviterId:
            null == inviterId
                ? _value.inviterId
                : inviterId // ignore: cast_nullable_to_non_nullable
                    as String,
        inviterName:
            null == inviterName
                ? _value.inviterName
                : inviterName // ignore: cast_nullable_to_non_nullable
                    as String,
        inviteeId:
            null == inviteeId
                ? _value.inviteeId
                : inviteeId // ignore: cast_nullable_to_non_nullable
                    as String,
        inviteeName:
            null == inviteeName
                ? _value.inviteeName
                : inviteeName // ignore: cast_nullable_to_non_nullable
                    as String,
        inviteePhotoUrl:
            freezed == inviteePhotoUrl
                ? _value.inviteePhotoUrl
                : inviteePhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as GroupInviteStatus,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        respondedAt:
            freezed == respondedAt
                ? _value.respondedAt
                : respondedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$GroupInviteEntityImpl implements _GroupInviteEntity {
  const _$GroupInviteEntityImpl({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeId,
    required this.inviteeName,
    this.inviteePhotoUrl,
    this.status = GroupInviteStatus.pending,
    this.createdAt,
    this.respondedAt,
  });

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String groupName;
  @override
  final String? groupImageUrl;
  @override
  final String inviterId;
  @override
  final String inviterName;
  @override
  final String inviteeId;
  @override
  final String inviteeName;
  @override
  final String? inviteePhotoUrl;
  @override
  @JsonKey()
  final GroupInviteStatus status;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? respondedAt;

  @override
  String toString() {
    return 'GroupInviteEntity(id: $id, groupId: $groupId, groupName: $groupName, groupImageUrl: $groupImageUrl, inviterId: $inviterId, inviterName: $inviterName, inviteeId: $inviteeId, inviteeName: $inviteeName, inviteePhotoUrl: $inviteePhotoUrl, status: $status, createdAt: $createdAt, respondedAt: $respondedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupInviteEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.groupImageUrl, groupImageUrl) ||
                other.groupImageUrl == groupImageUrl) &&
            (identical(other.inviterId, inviterId) ||
                other.inviterId == inviterId) &&
            (identical(other.inviterName, inviterName) ||
                other.inviterName == inviterName) &&
            (identical(other.inviteeId, inviteeId) ||
                other.inviteeId == inviteeId) &&
            (identical(other.inviteeName, inviteeName) ||
                other.inviteeName == inviteeName) &&
            (identical(other.inviteePhotoUrl, inviteePhotoUrl) ||
                other.inviteePhotoUrl == inviteePhotoUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.respondedAt, respondedAt) ||
                other.respondedAt == respondedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    groupId,
    groupName,
    groupImageUrl,
    inviterId,
    inviterName,
    inviteeId,
    inviteeName,
    inviteePhotoUrl,
    status,
    createdAt,
    respondedAt,
  );

  /// Create a copy of GroupInviteEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupInviteEntityImplCopyWith<_$GroupInviteEntityImpl> get copyWith =>
      __$$GroupInviteEntityImplCopyWithImpl<_$GroupInviteEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _GroupInviteEntity implements GroupInviteEntity {
  const factory _GroupInviteEntity({
    required final String id,
    required final String groupId,
    required final String groupName,
    final String? groupImageUrl,
    required final String inviterId,
    required final String inviterName,
    required final String inviteeId,
    required final String inviteeName,
    final String? inviteePhotoUrl,
    final GroupInviteStatus status,
    final DateTime? createdAt,
    final DateTime? respondedAt,
  }) = _$GroupInviteEntityImpl;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get groupName;
  @override
  String? get groupImageUrl;
  @override
  String get inviterId;
  @override
  String get inviterName;
  @override
  String get inviteeId;
  @override
  String get inviteeName;
  @override
  String? get inviteePhotoUrl;
  @override
  GroupInviteStatus get status;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get respondedAt;

  /// Create a copy of GroupInviteEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupInviteEntityImplCopyWith<_$GroupInviteEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
