// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_share_link_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProfileShareLinkModel _$ProfileShareLinkModelFromJson(
  Map<String, dynamic> json,
) {
  return _ProfileShareLinkModel.fromJson(json);
}

/// @nodoc
mixin _$ProfileShareLinkModel {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get shortCode => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  int get clickCount => throw _privateConstructorUsedError;

  /// Serializes this ProfileShareLinkModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProfileShareLinkModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileShareLinkModelCopyWith<ProfileShareLinkModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileShareLinkModelCopyWith<$Res> {
  factory $ProfileShareLinkModelCopyWith(
    ProfileShareLinkModel value,
    $Res Function(ProfileShareLinkModel) then,
  ) = _$ProfileShareLinkModelCopyWithImpl<$Res, ProfileShareLinkModel>;
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
class _$ProfileShareLinkModelCopyWithImpl<
  $Res,
  $Val extends ProfileShareLinkModel
>
    implements $ProfileShareLinkModelCopyWith<$Res> {
  _$ProfileShareLinkModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileShareLinkModel
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
abstract class _$$ProfileShareLinkModelImplCopyWith<$Res>
    implements $ProfileShareLinkModelCopyWith<$Res> {
  factory _$$ProfileShareLinkModelImplCopyWith(
    _$ProfileShareLinkModelImpl value,
    $Res Function(_$ProfileShareLinkModelImpl) then,
  ) = __$$ProfileShareLinkModelImplCopyWithImpl<$Res>;
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
class __$$ProfileShareLinkModelImplCopyWithImpl<$Res>
    extends
        _$ProfileShareLinkModelCopyWithImpl<$Res, _$ProfileShareLinkModelImpl>
    implements _$$ProfileShareLinkModelImplCopyWith<$Res> {
  __$$ProfileShareLinkModelImplCopyWithImpl(
    _$ProfileShareLinkModelImpl _value,
    $Res Function(_$ProfileShareLinkModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileShareLinkModel
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
      _$ProfileShareLinkModelImpl(
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
@JsonSerializable()
class _$ProfileShareLinkModelImpl extends _ProfileShareLinkModel {
  const _$ProfileShareLinkModelImpl({
    required this.id,
    required this.userId,
    required this.shortCode,
    required this.createdAt,
    this.expiresAt,
    this.clickCount = 0,
  }) : super._();

  factory _$ProfileShareLinkModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileShareLinkModelImplFromJson(json);

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
    return 'ProfileShareLinkModel(id: $id, userId: $userId, shortCode: $shortCode, createdAt: $createdAt, expiresAt: $expiresAt, clickCount: $clickCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileShareLinkModelImpl &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of ProfileShareLinkModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileShareLinkModelImplCopyWith<_$ProfileShareLinkModelImpl>
  get copyWith =>
      __$$ProfileShareLinkModelImplCopyWithImpl<_$ProfileShareLinkModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileShareLinkModelImplToJson(this);
  }
}

abstract class _ProfileShareLinkModel extends ProfileShareLinkModel {
  const factory _ProfileShareLinkModel({
    required final String id,
    required final String userId,
    required final String shortCode,
    required final DateTime createdAt,
    final DateTime? expiresAt,
    final int clickCount,
  }) = _$ProfileShareLinkModelImpl;
  const _ProfileShareLinkModel._() : super._();

  factory _ProfileShareLinkModel.fromJson(Map<String, dynamic> json) =
      _$ProfileShareLinkModelImpl.fromJson;

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

  /// Create a copy of ProfileShareLinkModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileShareLinkModelImplCopyWith<_$ProfileShareLinkModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
