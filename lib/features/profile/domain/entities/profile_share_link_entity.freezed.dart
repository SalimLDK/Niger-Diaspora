// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_share_link_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProfileShareLinkEntity {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get shortCode => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  int get clickCount => throw _privateConstructorUsedError;

  /// Create a copy of ProfileShareLinkEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileShareLinkEntityCopyWith<ProfileShareLinkEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileShareLinkEntityCopyWith<$Res> {
  factory $ProfileShareLinkEntityCopyWith(
    ProfileShareLinkEntity value,
    $Res Function(ProfileShareLinkEntity) then,
  ) = _$ProfileShareLinkEntityCopyWithImpl<$Res, ProfileShareLinkEntity>;
  @useResult
  $Res call({
    String id,
    String userId,
    String shortCode,
    DateTime createdAt,
    DateTime? expiresAt,
    int clickCount,
  });
}

/// @nodoc
class _$ProfileShareLinkEntityCopyWithImpl<
  $Res,
  $Val extends ProfileShareLinkEntity
>
    implements $ProfileShareLinkEntityCopyWith<$Res> {
  _$ProfileShareLinkEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileShareLinkEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? shortCode = null,
    Object? createdAt = null,
    Object? expiresAt = freezed,
    Object? clickCount = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            shortCode:
                null == shortCode
                    ? _value.shortCode
                    : shortCode // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            expiresAt:
                freezed == expiresAt
                    ? _value.expiresAt
                    : expiresAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            clickCount:
                null == clickCount
                    ? _value.clickCount
                    : clickCount // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileShareLinkEntityImplCopyWith<$Res>
    implements $ProfileShareLinkEntityCopyWith<$Res> {
  factory _$$ProfileShareLinkEntityImplCopyWith(
    _$ProfileShareLinkEntityImpl value,
    $Res Function(_$ProfileShareLinkEntityImpl) then,
  ) = __$$ProfileShareLinkEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String shortCode,
    DateTime createdAt,
    DateTime? expiresAt,
    int clickCount,
  });
}

/// @nodoc
class __$$ProfileShareLinkEntityImplCopyWithImpl<$Res>
    extends
        _$ProfileShareLinkEntityCopyWithImpl<$Res, _$ProfileShareLinkEntityImpl>
    implements _$$ProfileShareLinkEntityImplCopyWith<$Res> {
  __$$ProfileShareLinkEntityImplCopyWithImpl(
    _$ProfileShareLinkEntityImpl _value,
    $Res Function(_$ProfileShareLinkEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileShareLinkEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? shortCode = null,
    Object? createdAt = null,
    Object? expiresAt = freezed,
    Object? clickCount = null,
  }) {
    return _then(
      _$ProfileShareLinkEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        shortCode:
            null == shortCode
                ? _value.shortCode
                : shortCode // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        expiresAt:
            freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        clickCount:
            null == clickCount
                ? _value.clickCount
                : clickCount // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$ProfileShareLinkEntityImpl implements _ProfileShareLinkEntity {
  const _$ProfileShareLinkEntityImpl({
    required this.id,
    required this.userId,
    required this.shortCode,
    required this.createdAt,
    this.expiresAt,
    this.clickCount = 0,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String shortCode;
  @override
  final DateTime createdAt;
  @override
  final DateTime? expiresAt;
  @override
  @JsonKey()
  final int clickCount;

  @override
  String toString() {
    return 'ProfileShareLinkEntity(id: $id, userId: $userId, shortCode: $shortCode, createdAt: $createdAt, expiresAt: $expiresAt, clickCount: $clickCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileShareLinkEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.shortCode, shortCode) ||
                other.shortCode == shortCode) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.clickCount, clickCount) ||
                other.clickCount == clickCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    shortCode,
    createdAt,
    expiresAt,
    clickCount,
  );

  /// Create a copy of ProfileShareLinkEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileShareLinkEntityImplCopyWith<_$ProfileShareLinkEntityImpl>
  get copyWith =>
      __$$ProfileShareLinkEntityImplCopyWithImpl<_$ProfileShareLinkEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _ProfileShareLinkEntity implements ProfileShareLinkEntity {
  const factory _ProfileShareLinkEntity({
    required final String id,
    required final String userId,
    required final String shortCode,
    required final DateTime createdAt,
    final DateTime? expiresAt,
    final int clickCount,
  }) = _$ProfileShareLinkEntityImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get shortCode;
  @override
  DateTime get createdAt;
  @override
  DateTime? get expiresAt;
  @override
  int get clickCount;

  /// Create a copy of ProfileShareLinkEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileShareLinkEntityImplCopyWith<_$ProfileShareLinkEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
