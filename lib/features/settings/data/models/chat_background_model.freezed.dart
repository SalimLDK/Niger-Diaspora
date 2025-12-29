// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_background_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChatBackgroundModel _$ChatBackgroundModelFromJson(Map<String, dynamic> json) {
  return _ChatBackgroundModel.fromJson(json);
}

/// @nodoc
mixin _$ChatBackgroundModel {
  String get type =>
      throw _privateConstructorUsedError; // 'default', 'color', 'image'
  String? get colorValue =>
      throw _privateConstructorUsedError; // Hex color string (e.g., '#FF5733')
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this ChatBackgroundModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatBackgroundModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatBackgroundModelCopyWith<ChatBackgroundModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatBackgroundModelCopyWith<$Res> {
  factory $ChatBackgroundModelCopyWith(
    ChatBackgroundModel value,
    $Res Function(ChatBackgroundModel) then,
  ) = _$ChatBackgroundModelCopyWithImpl<$Res, ChatBackgroundModel>;
  @useResult
  $Res call({String type, String? colorValue, String? imageUrl});
}

/// @nodoc
class _$ChatBackgroundModelCopyWithImpl<$Res, $Val extends ChatBackgroundModel>
    implements $ChatBackgroundModelCopyWith<$Res> {
  _$ChatBackgroundModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatBackgroundModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? colorValue = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            colorValue:
                freezed == colorValue
                    ? _value.colorValue
                    : colorValue // ignore: cast_nullable_to_non_nullable
                        as String?,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChatBackgroundModelImplCopyWith<$Res>
    implements $ChatBackgroundModelCopyWith<$Res> {
  factory _$$ChatBackgroundModelImplCopyWith(
    _$ChatBackgroundModelImpl value,
    $Res Function(_$ChatBackgroundModelImpl) then,
  ) = __$$ChatBackgroundModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String? colorValue, String? imageUrl});
}

/// @nodoc
class __$$ChatBackgroundModelImplCopyWithImpl<$Res>
    extends _$ChatBackgroundModelCopyWithImpl<$Res, _$ChatBackgroundModelImpl>
    implements _$$ChatBackgroundModelImplCopyWith<$Res> {
  __$$ChatBackgroundModelImplCopyWithImpl(
    _$ChatBackgroundModelImpl _value,
    $Res Function(_$ChatBackgroundModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatBackgroundModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? colorValue = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _$ChatBackgroundModelImpl(
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        colorValue:
            freezed == colorValue
                ? _value.colorValue
                : colorValue // ignore: cast_nullable_to_non_nullable
                    as String?,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatBackgroundModelImpl implements _ChatBackgroundModel {
  const _$ChatBackgroundModelImpl({
    required this.type,
    this.colorValue,
    this.imageUrl,
  });

  factory _$ChatBackgroundModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatBackgroundModelImplFromJson(json);

  @override
  final String type;
  // 'default', 'color', 'image'
  @override
  final String? colorValue;
  // Hex color string (e.g., '#FF5733')
  @override
  final String? imageUrl;

  @override
  String toString() {
    return 'ChatBackgroundModel(type: $type, colorValue: $colorValue, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatBackgroundModelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.colorValue, colorValue) ||
                other.colorValue == colorValue) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, colorValue, imageUrl);

  /// Create a copy of ChatBackgroundModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatBackgroundModelImplCopyWith<_$ChatBackgroundModelImpl> get copyWith =>
      __$$ChatBackgroundModelImplCopyWithImpl<_$ChatBackgroundModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatBackgroundModelImplToJson(this);
  }
}

abstract class _ChatBackgroundModel implements ChatBackgroundModel {
  const factory _ChatBackgroundModel({
    required final String type,
    final String? colorValue,
    final String? imageUrl,
  }) = _$ChatBackgroundModelImpl;

  factory _ChatBackgroundModel.fromJson(Map<String, dynamic> json) =
      _$ChatBackgroundModelImpl.fromJson;

  @override
  String get type; // 'default', 'color', 'image'
  @override
  String? get colorValue; // Hex color string (e.g., '#FF5733')
  @override
  String? get imageUrl;

  /// Create a copy of ChatBackgroundModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatBackgroundModelImplCopyWith<_$ChatBackgroundModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
