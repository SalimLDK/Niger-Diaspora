// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blocked_user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BlockedUserEntity {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  DateTime get blockedAt => throw _privateConstructorUsedError;

  /// Create a copy of BlockedUserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlockedUserEntityCopyWith<BlockedUserEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockedUserEntityCopyWith<$Res> {
  factory $BlockedUserEntityCopyWith(
    BlockedUserEntity value,
    $Res Function(BlockedUserEntity) then,
  ) = _$BlockedUserEntityCopyWithImpl<$Res, BlockedUserEntity>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    DateTime blockedAt,
  });
}

/// @nodoc
class _$BlockedUserEntityCopyWithImpl<$Res, $Val extends BlockedUserEntity>
    implements $BlockedUserEntityCopyWith<$Res> {
  _$BlockedUserEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlockedUserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
    Object? blockedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            displayName:
                null == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            blockedAt:
                null == blockedAt
                    ? _value.blockedAt
                    : blockedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BlockedUserEntityImplCopyWith<$Res>
    implements $BlockedUserEntityCopyWith<$Res> {
  factory _$$BlockedUserEntityImplCopyWith(
    _$BlockedUserEntityImpl value,
    $Res Function(_$BlockedUserEntityImpl) then,
  ) = __$$BlockedUserEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    DateTime blockedAt,
  });
}

/// @nodoc
class __$$BlockedUserEntityImplCopyWithImpl<$Res>
    extends _$BlockedUserEntityCopyWithImpl<$Res, _$BlockedUserEntityImpl>
    implements _$$BlockedUserEntityImplCopyWith<$Res> {
  __$$BlockedUserEntityImplCopyWithImpl(
    _$BlockedUserEntityImpl _value,
    $Res Function(_$BlockedUserEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlockedUserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
    Object? blockedAt = null,
  }) {
    return _then(
      _$BlockedUserEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        displayName:
            null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        blockedAt:
            null == blockedAt
                ? _value.blockedAt
                : blockedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$BlockedUserEntityImpl implements _BlockedUserEntity {
  const _$BlockedUserEntityImpl({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.blockedAt,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  @override
  final DateTime blockedAt;

  @override
  String toString() {
    return 'BlockedUserEntity(id: $id, displayName: $displayName, photoUrl: $photoUrl, blockedAt: $blockedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockedUserEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.blockedAt, blockedAt) ||
                other.blockedAt == blockedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, displayName, photoUrl, blockedAt);

  /// Create a copy of BlockedUserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockedUserEntityImplCopyWith<_$BlockedUserEntityImpl> get copyWith =>
      __$$BlockedUserEntityImplCopyWithImpl<_$BlockedUserEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _BlockedUserEntity implements BlockedUserEntity {
  const factory _BlockedUserEntity({
    required final String id,
    required final String displayName,
    final String? photoUrl,
    required final DateTime blockedAt,
  }) = _$BlockedUserEntityImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String? get photoUrl;
  @override
  DateTime get blockedAt;

  /// Create a copy of BlockedUserEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockedUserEntityImplCopyWith<_$BlockedUserEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
