// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legal_content_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LegalContentModel _$LegalContentModelFromJson(Map<String, dynamic> json) {
  return _LegalContentModel.fromJson(json);
}

/// @nodoc
mixin _$LegalContentModel {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError; // 'terms' ou 'privacy'
  String get title => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  List<LegalSectionModel> get sections => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;

  /// Serializes this LegalContentModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LegalContentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalContentModelCopyWith<LegalContentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalContentModelCopyWith<$Res> {
  factory $LegalContentModelCopyWith(
    LegalContentModel value,
    $Res Function(LegalContentModel) then,
  ) = _$LegalContentModelCopyWithImpl<$Res, LegalContentModel>;
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String version,
    List<LegalSectionModel> sections,
    DateTime updatedAt,
    String? summary,
  });
}

/// @nodoc
class _$LegalContentModelCopyWithImpl<$Res, $Val extends LegalContentModel>
    implements $LegalContentModelCopyWith<$Res> {
  _$LegalContentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalContentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? version = null,
    Object? sections = null,
    Object? updatedAt = null,
    Object? summary = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            version:
                null == version
                    ? _value.version
                    : version // ignore: cast_nullable_to_non_nullable
                        as String,
            sections:
                null == sections
                    ? _value.sections
                    : sections // ignore: cast_nullable_to_non_nullable
                        as List<LegalSectionModel>,
            updatedAt:
                null == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            summary:
                freezed == summary
                    ? _value.summary
                    : summary // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LegalContentModelImplCopyWith<$Res>
    implements $LegalContentModelCopyWith<$Res> {
  factory _$$LegalContentModelImplCopyWith(
    _$LegalContentModelImpl value,
    $Res Function(_$LegalContentModelImpl) then,
  ) = __$$LegalContentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String version,
    List<LegalSectionModel> sections,
    DateTime updatedAt,
    String? summary,
  });
}

/// @nodoc
class __$$LegalContentModelImplCopyWithImpl<$Res>
    extends _$LegalContentModelCopyWithImpl<$Res, _$LegalContentModelImpl>
    implements _$$LegalContentModelImplCopyWith<$Res> {
  __$$LegalContentModelImplCopyWithImpl(
    _$LegalContentModelImpl _value,
    $Res Function(_$LegalContentModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LegalContentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? version = null,
    Object? sections = null,
    Object? updatedAt = null,
    Object? summary = freezed,
  }) {
    return _then(
      _$LegalContentModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        version:
            null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                    as String,
        sections:
            null == sections
                ? _value._sections
                : sections // ignore: cast_nullable_to_non_nullable
                    as List<LegalSectionModel>,
        updatedAt:
            null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        summary:
            freezed == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LegalContentModelImpl implements _LegalContentModel {
  const _$LegalContentModelImpl({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required final List<LegalSectionModel> sections,
    required this.updatedAt,
    this.summary,
  }) : _sections = sections;

  factory _$LegalContentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$LegalContentModelImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  // 'terms' ou 'privacy'
  @override
  final String title;
  @override
  final String version;
  final List<LegalSectionModel> _sections;
  @override
  List<LegalSectionModel> get sections {
    if (_sections is EqualUnmodifiableListView) return _sections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sections);
  }

  @override
  final DateTime updatedAt;
  @override
  final String? summary;

  @override
  String toString() {
    return 'LegalContentModel(id: $id, type: $type, title: $title, version: $version, sections: $sections, updatedAt: $updatedAt, summary: $summary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalContentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.version, version) || other.version == version) &&
            const DeepCollectionEquality().equals(other._sections, _sections) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    title,
    version,
    const DeepCollectionEquality().hash(_sections),
    updatedAt,
    summary,
  );

  /// Create a copy of LegalContentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalContentModelImplCopyWith<_$LegalContentModelImpl> get copyWith =>
      __$$LegalContentModelImplCopyWithImpl<_$LegalContentModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LegalContentModelImplToJson(this);
  }
}

abstract class _LegalContentModel implements LegalContentModel {
  const factory _LegalContentModel({
    required final String id,
    required final String type,
    required final String title,
    required final String version,
    required final List<LegalSectionModel> sections,
    required final DateTime updatedAt,
    final String? summary,
  }) = _$LegalContentModelImpl;

  factory _LegalContentModel.fromJson(Map<String, dynamic> json) =
      _$LegalContentModelImpl.fromJson;

  @override
  String get id;
  @override
  String get type; // 'terms' ou 'privacy'
  @override
  String get title;
  @override
  String get version;
  @override
  List<LegalSectionModel> get sections;
  @override
  DateTime get updatedAt;
  @override
  String? get summary;

  /// Create a copy of LegalContentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalContentModelImplCopyWith<_$LegalContentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LegalSectionModel _$LegalSectionModelFromJson(Map<String, dynamic> json) {
  return _LegalSectionModel.fromJson(json);
}

/// @nodoc
mixin _$LegalSectionModel {
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  int? get order => throw _privateConstructorUsedError;

  /// Serializes this LegalSectionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LegalSectionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalSectionModelCopyWith<LegalSectionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalSectionModelCopyWith<$Res> {
  factory $LegalSectionModelCopyWith(
    LegalSectionModel value,
    $Res Function(LegalSectionModel) then,
  ) = _$LegalSectionModelCopyWithImpl<$Res, LegalSectionModel>;
  @useResult
  $Res call({String title, String content, int? order});
}

/// @nodoc
class _$LegalSectionModelCopyWithImpl<$Res, $Val extends LegalSectionModel>
    implements $LegalSectionModelCopyWith<$Res> {
  _$LegalSectionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalSectionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? content = null,
    Object? order = freezed,
  }) {
    return _then(
      _value.copyWith(
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
            order:
                freezed == order
                    ? _value.order
                    : order // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LegalSectionModelImplCopyWith<$Res>
    implements $LegalSectionModelCopyWith<$Res> {
  factory _$$LegalSectionModelImplCopyWith(
    _$LegalSectionModelImpl value,
    $Res Function(_$LegalSectionModelImpl) then,
  ) = __$$LegalSectionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String content, int? order});
}

/// @nodoc
class __$$LegalSectionModelImplCopyWithImpl<$Res>
    extends _$LegalSectionModelCopyWithImpl<$Res, _$LegalSectionModelImpl>
    implements _$$LegalSectionModelImplCopyWith<$Res> {
  __$$LegalSectionModelImplCopyWithImpl(
    _$LegalSectionModelImpl _value,
    $Res Function(_$LegalSectionModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LegalSectionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? content = null,
    Object? order = freezed,
  }) {
    return _then(
      _$LegalSectionModelImpl(
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
        order:
            freezed == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LegalSectionModelImpl implements _LegalSectionModel {
  const _$LegalSectionModelImpl({
    required this.title,
    required this.content,
    this.order,
  });

  factory _$LegalSectionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$LegalSectionModelImplFromJson(json);

  @override
  final String title;
  @override
  final String content;
  @override
  final int? order;

  @override
  String toString() {
    return 'LegalSectionModel(title: $title, content: $content, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalSectionModelImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, content, order);

  /// Create a copy of LegalSectionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalSectionModelImplCopyWith<_$LegalSectionModelImpl> get copyWith =>
      __$$LegalSectionModelImplCopyWithImpl<_$LegalSectionModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LegalSectionModelImplToJson(this);
  }
}

abstract class _LegalSectionModel implements LegalSectionModel {
  const factory _LegalSectionModel({
    required final String title,
    required final String content,
    final int? order,
  }) = _$LegalSectionModelImpl;

  factory _LegalSectionModel.fromJson(Map<String, dynamic> json) =
      _$LegalSectionModelImpl.fromJson;

  @override
  String get title;
  @override
  String get content;
  @override
  int? get order;

  /// Create a copy of LegalSectionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalSectionModelImplCopyWith<_$LegalSectionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserLegalAcceptance _$UserLegalAcceptanceFromJson(Map<String, dynamic> json) {
  return _UserLegalAcceptance.fromJson(json);
}

/// @nodoc
mixin _$UserLegalAcceptance {
  String get termsVersion => throw _privateConstructorUsedError;
  String get privacyVersion => throw _privateConstructorUsedError;
  DateTime get acceptedAt => throw _privateConstructorUsedError;

  /// Serializes this UserLegalAcceptance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserLegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserLegalAcceptanceCopyWith<UserLegalAcceptance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserLegalAcceptanceCopyWith<$Res> {
  factory $UserLegalAcceptanceCopyWith(
    UserLegalAcceptance value,
    $Res Function(UserLegalAcceptance) then,
  ) = _$UserLegalAcceptanceCopyWithImpl<$Res, UserLegalAcceptance>;
  @useResult
  $Res call({String termsVersion, String privacyVersion, DateTime acceptedAt});
}

/// @nodoc
class _$UserLegalAcceptanceCopyWithImpl<$Res, $Val extends UserLegalAcceptance>
    implements $UserLegalAcceptanceCopyWith<$Res> {
  _$UserLegalAcceptanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserLegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? termsVersion = null,
    Object? privacyVersion = null,
    Object? acceptedAt = null,
  }) {
    return _then(
      _value.copyWith(
            termsVersion:
                null == termsVersion
                    ? _value.termsVersion
                    : termsVersion // ignore: cast_nullable_to_non_nullable
                        as String,
            privacyVersion:
                null == privacyVersion
                    ? _value.privacyVersion
                    : privacyVersion // ignore: cast_nullable_to_non_nullable
                        as String,
            acceptedAt:
                null == acceptedAt
                    ? _value.acceptedAt
                    : acceptedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserLegalAcceptanceImplCopyWith<$Res>
    implements $UserLegalAcceptanceCopyWith<$Res> {
  factory _$$UserLegalAcceptanceImplCopyWith(
    _$UserLegalAcceptanceImpl value,
    $Res Function(_$UserLegalAcceptanceImpl) then,
  ) = __$$UserLegalAcceptanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String termsVersion, String privacyVersion, DateTime acceptedAt});
}

/// @nodoc
class __$$UserLegalAcceptanceImplCopyWithImpl<$Res>
    extends _$UserLegalAcceptanceCopyWithImpl<$Res, _$UserLegalAcceptanceImpl>
    implements _$$UserLegalAcceptanceImplCopyWith<$Res> {
  __$$UserLegalAcceptanceImplCopyWithImpl(
    _$UserLegalAcceptanceImpl _value,
    $Res Function(_$UserLegalAcceptanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserLegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? termsVersion = null,
    Object? privacyVersion = null,
    Object? acceptedAt = null,
  }) {
    return _then(
      _$UserLegalAcceptanceImpl(
        termsVersion:
            null == termsVersion
                ? _value.termsVersion
                : termsVersion // ignore: cast_nullable_to_non_nullable
                    as String,
        privacyVersion:
            null == privacyVersion
                ? _value.privacyVersion
                : privacyVersion // ignore: cast_nullable_to_non_nullable
                    as String,
        acceptedAt:
            null == acceptedAt
                ? _value.acceptedAt
                : acceptedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserLegalAcceptanceImpl implements _UserLegalAcceptance {
  const _$UserLegalAcceptanceImpl({
    required this.termsVersion,
    required this.privacyVersion,
    required this.acceptedAt,
  });

  factory _$UserLegalAcceptanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserLegalAcceptanceImplFromJson(json);

  @override
  final String termsVersion;
  @override
  final String privacyVersion;
  @override
  final DateTime acceptedAt;

  @override
  String toString() {
    return 'UserLegalAcceptance(termsVersion: $termsVersion, privacyVersion: $privacyVersion, acceptedAt: $acceptedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserLegalAcceptanceImpl &&
            (identical(other.termsVersion, termsVersion) ||
                other.termsVersion == termsVersion) &&
            (identical(other.privacyVersion, privacyVersion) ||
                other.privacyVersion == privacyVersion) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, termsVersion, privacyVersion, acceptedAt);

  /// Create a copy of UserLegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserLegalAcceptanceImplCopyWith<_$UserLegalAcceptanceImpl> get copyWith =>
      __$$UserLegalAcceptanceImplCopyWithImpl<_$UserLegalAcceptanceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$UserLegalAcceptanceImplToJson(this);
  }
}

abstract class _UserLegalAcceptance implements UserLegalAcceptance {
  const factory _UserLegalAcceptance({
    required final String termsVersion,
    required final String privacyVersion,
    required final DateTime acceptedAt,
  }) = _$UserLegalAcceptanceImpl;

  factory _UserLegalAcceptance.fromJson(Map<String, dynamic> json) =
      _$UserLegalAcceptanceImpl.fromJson;

  @override
  String get termsVersion;
  @override
  String get privacyVersion;
  @override
  DateTime get acceptedAt;

  /// Create a copy of UserLegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserLegalAcceptanceImplCopyWith<_$UserLegalAcceptanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
