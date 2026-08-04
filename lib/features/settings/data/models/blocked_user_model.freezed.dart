// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blocked_user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BlockedUserModel _$BlockedUserModelFromJson(Map<String, dynamic> json) {
  return _BlockedUserModel.fromJson(json);
}

/// @nodoc
mixin _$BlockedUserModel {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  @LocalDateTimeConverter()
  DateTime get blockedAt => throw _privateConstructorUsedError;

  /// Serializes this BlockedUserModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BlockedUserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlockedUserModelCopyWith<BlockedUserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockedUserModelCopyWith<$Res> {
  factory $BlockedUserModelCopyWith(
    BlockedUserModel value,
    $Res Function(BlockedUserModel) then,
  ) = _$BlockedUserModelCopyWithImpl<$Res, BlockedUserModel>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    @LocalDateTimeConverter() DateTime blockedAt,
  });
}

/// @nodoc
class _$BlockedUserModelCopyWithImpl<$Res, $Val extends BlockedUserModel>
    implements $BlockedUserModelCopyWith<$Res> {
  _$BlockedUserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlockedUserModel
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
abstract class _$$BlockedUserModelImplCopyWith<$Res>
    implements $BlockedUserModelCopyWith<$Res> {
  factory _$$BlockedUserModelImplCopyWith(
    _$BlockedUserModelImpl value,
    $Res Function(_$BlockedUserModelImpl) then,
  ) = __$$BlockedUserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    @LocalDateTimeConverter() DateTime blockedAt,
  });
}

/// @nodoc
class __$$BlockedUserModelImplCopyWithImpl<$Res>
    extends _$BlockedUserModelCopyWithImpl<$Res, _$BlockedUserModelImpl>
    implements _$$BlockedUserModelImplCopyWith<$Res> {
  __$$BlockedUserModelImplCopyWithImpl(
    _$BlockedUserModelImpl _value,
    $Res Function(_$BlockedUserModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlockedUserModel
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
      _$BlockedUserModelImpl(
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
@JsonSerializable()
class _$BlockedUserModelImpl extends _BlockedUserModel {
  const _$BlockedUserModelImpl({
    required this.id,
    required this.displayName,
    this.photoUrl,
    @LocalDateTimeConverter() required this.blockedAt,
  }) : super._();

  factory _$BlockedUserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BlockedUserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  @override
  @LocalDateTimeConverter()
  final DateTime blockedAt;

  @override
  String toString() {
    return 'BlockedUserModel(id: $id, displayName: $displayName, photoUrl: $photoUrl, blockedAt: $blockedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockedUserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.blockedAt, blockedAt) ||
                other.blockedAt == blockedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, displayName, photoUrl, blockedAt);

  /// Create a copy of BlockedUserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockedUserModelImplCopyWith<_$BlockedUserModelImpl> get copyWith =>
      __$$BlockedUserModelImplCopyWithImpl<_$BlockedUserModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BlockedUserModelImplToJson(this);
  }
}

abstract class _BlockedUserModel extends BlockedUserModel {
  const factory _BlockedUserModel({
    required final String id,
    required final String displayName,
    final String? photoUrl,
    @LocalDateTimeConverter() required final DateTime blockedAt,
  }) = _$BlockedUserModelImpl;
  const _BlockedUserModel._() : super._();

  factory _BlockedUserModel.fromJson(Map<String, dynamic> json) =
      _$BlockedUserModelImpl.fromJson;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String? get photoUrl;
  @override
  @LocalDateTimeConverter()
  DateTime get blockedAt;

  /// Create a copy of BlockedUserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockedUserModelImplCopyWith<_$BlockedUserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
