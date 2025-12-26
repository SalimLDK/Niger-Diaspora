// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'embassy_activity_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmbassyActivityModel _$EmbassyActivityModelFromJson(Map<String, dynamic> json) {
  return _EmbassyActivityModel.fromJson(json);
}

/// @nodoc
mixin _$EmbassyActivityModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this EmbassyActivityModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmbassyActivityModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmbassyActivityModelCopyWith<EmbassyActivityModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmbassyActivityModelCopyWith<$Res> {
  factory $EmbassyActivityModelCopyWith(
    EmbassyActivityModel value,
    $Res Function(EmbassyActivityModel) then,
  ) = _$EmbassyActivityModelCopyWithImpl<$Res, EmbassyActivityModel>;
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    DateTime date,
    String location,
    String? imageUrl,
  });
}

/// @nodoc
class _$EmbassyActivityModelCopyWithImpl<
  $Res,
  $Val extends EmbassyActivityModel
>
    implements $EmbassyActivityModelCopyWith<$Res> {
  _$EmbassyActivityModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmbassyActivityModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? date = null,
    Object? location = null,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            location:
                null == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String,
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
abstract class _$$EmbassyActivityModelImplCopyWith<$Res>
    implements $EmbassyActivityModelCopyWith<$Res> {
  factory _$$EmbassyActivityModelImplCopyWith(
    _$EmbassyActivityModelImpl value,
    $Res Function(_$EmbassyActivityModelImpl) then,
  ) = __$$EmbassyActivityModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    DateTime date,
    String location,
    String? imageUrl,
  });
}

/// @nodoc
class __$$EmbassyActivityModelImplCopyWithImpl<$Res>
    extends _$EmbassyActivityModelCopyWithImpl<$Res, _$EmbassyActivityModelImpl>
    implements _$$EmbassyActivityModelImplCopyWith<$Res> {
  __$$EmbassyActivityModelImplCopyWithImpl(
    _$EmbassyActivityModelImpl _value,
    $Res Function(_$EmbassyActivityModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmbassyActivityModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? date = null,
    Object? location = null,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _$EmbassyActivityModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        location:
            null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String,
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
class _$EmbassyActivityModelImpl implements _EmbassyActivityModel {
  const _$EmbassyActivityModelImpl({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageUrl,
  });

  factory _$EmbassyActivityModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmbassyActivityModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final DateTime date;
  @override
  final String location;
  @override
  final String? imageUrl;

  @override
  String toString() {
    return 'EmbassyActivityModel(id: $id, title: $title, description: $description, date: $date, location: $location, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmbassyActivityModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    date,
    location,
    imageUrl,
  );

  /// Create a copy of EmbassyActivityModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmbassyActivityModelImplCopyWith<_$EmbassyActivityModelImpl>
  get copyWith =>
      __$$EmbassyActivityModelImplCopyWithImpl<_$EmbassyActivityModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmbassyActivityModelImplToJson(this);
  }
}

abstract class _EmbassyActivityModel implements EmbassyActivityModel {
  const factory _EmbassyActivityModel({
    required final String id,
    required final String title,
    required final String description,
    required final DateTime date,
    required final String location,
    final String? imageUrl,
  }) = _$EmbassyActivityModelImpl;

  factory _EmbassyActivityModel.fromJson(Map<String, dynamic> json) =
      _$EmbassyActivityModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  DateTime get date;
  @override
  String get location;
  @override
  String? get imageUrl;

  /// Create a copy of EmbassyActivityModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmbassyActivityModelImplCopyWith<_$EmbassyActivityModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
