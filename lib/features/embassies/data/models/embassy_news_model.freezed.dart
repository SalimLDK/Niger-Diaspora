// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'embassy_news_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmbassyNewsModel _$EmbassyNewsModelFromJson(Map<String, dynamic> json) {
  return _EmbassyNewsModel.fromJson(json);
}

/// @nodoc
mixin _$EmbassyNewsModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @LocalDateTimeConverter()
  DateTime get date => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this EmbassyNewsModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmbassyNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmbassyNewsModelCopyWith<EmbassyNewsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmbassyNewsModelCopyWith<$Res> {
  factory $EmbassyNewsModelCopyWith(
    EmbassyNewsModel value,
    $Res Function(EmbassyNewsModel) then,
  ) = _$EmbassyNewsModelCopyWithImpl<$Res, EmbassyNewsModel>;
  @useResult
  $Res call({
    String id,
    String title,
    String content,
    @LocalDateTimeConverter() DateTime date,
    String? imageUrl,
  });
}

/// @nodoc
class _$EmbassyNewsModelCopyWithImpl<$Res, $Val extends EmbassyNewsModel>
    implements $EmbassyNewsModelCopyWith<$Res> {
  _$EmbassyNewsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmbassyNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? date = null,
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
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as String,
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as DateTime,
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
abstract class _$$EmbassyNewsModelImplCopyWith<$Res>
    implements $EmbassyNewsModelCopyWith<$Res> {
  factory _$$EmbassyNewsModelImplCopyWith(
    _$EmbassyNewsModelImpl value,
    $Res Function(_$EmbassyNewsModelImpl) then,
  ) = __$$EmbassyNewsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String content,
    @LocalDateTimeConverter() DateTime date,
    String? imageUrl,
  });
}

/// @nodoc
class __$$EmbassyNewsModelImplCopyWithImpl<$Res>
    extends _$EmbassyNewsModelCopyWithImpl<$Res, _$EmbassyNewsModelImpl>
    implements _$$EmbassyNewsModelImplCopyWith<$Res> {
  __$$EmbassyNewsModelImplCopyWithImpl(
    _$EmbassyNewsModelImpl _value,
    $Res Function(_$EmbassyNewsModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmbassyNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? date = null,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _$EmbassyNewsModelImpl(
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
        content:
            null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                    as String,
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as DateTime,
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
class _$EmbassyNewsModelImpl implements _EmbassyNewsModel {
  const _$EmbassyNewsModelImpl({
    required this.id,
    required this.title,
    required this.content,
    @LocalDateTimeConverter() required this.date,
    this.imageUrl,
  });

  factory _$EmbassyNewsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmbassyNewsModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String content;
  @override
  @LocalDateTimeConverter()
  final DateTime date;
  @override
  final String? imageUrl;

  @override
  String toString() {
    return 'EmbassyNewsModel(id: $id, title: $title, content: $content, date: $date, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmbassyNewsModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, content, date, imageUrl);

  /// Create a copy of EmbassyNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmbassyNewsModelImplCopyWith<_$EmbassyNewsModelImpl> get copyWith =>
      __$$EmbassyNewsModelImplCopyWithImpl<_$EmbassyNewsModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmbassyNewsModelImplToJson(this);
  }
}

abstract class _EmbassyNewsModel implements EmbassyNewsModel {
  const factory _EmbassyNewsModel({
    required final String id,
    required final String title,
    required final String content,
    @LocalDateTimeConverter() required final DateTime date,
    final String? imageUrl,
  }) = _$EmbassyNewsModelImpl;

  factory _EmbassyNewsModel.fromJson(Map<String, dynamic> json) =
      _$EmbassyNewsModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get content;
  @override
  @LocalDateTimeConverter()
  DateTime get date;
  @override
  String? get imageUrl;

  /// Create a copy of EmbassyNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmbassyNewsModelImplCopyWith<_$EmbassyNewsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
