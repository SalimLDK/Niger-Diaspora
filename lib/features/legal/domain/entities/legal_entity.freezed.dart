// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legal_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LegalContent {
  String get id => throw _privateConstructorUsedError;
  LegalContentType get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  List<LegalSection> get sections => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;

  /// Create a copy of LegalContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalContentCopyWith<LegalContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalContentCopyWith<$Res> {
  factory $LegalContentCopyWith(
    LegalContent value,
    $Res Function(LegalContent) then,
  ) = _$LegalContentCopyWithImpl<$Res, LegalContent>;
  @useResult
  $Res call({
    String id,
    LegalContentType type,
    String title,
    String version,
    List<LegalSection> sections,
    DateTime updatedAt,
    String? summary,
  });
}

/// @nodoc
class _$LegalContentCopyWithImpl<$Res, $Val extends LegalContent>
    implements $LegalContentCopyWith<$Res> {
  _$LegalContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalContent
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
                        as LegalContentType,
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
                        as List<LegalSection>,
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
abstract class _$$LegalContentImplCopyWith<$Res>
    implements $LegalContentCopyWith<$Res> {
  factory _$$LegalContentImplCopyWith(
    _$LegalContentImpl value,
    $Res Function(_$LegalContentImpl) then,
  ) = __$$LegalContentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    LegalContentType type,
    String title,
    String version,
    List<LegalSection> sections,
    DateTime updatedAt,
    String? summary,
  });
}

/// @nodoc
class __$$LegalContentImplCopyWithImpl<$Res>
    extends _$LegalContentCopyWithImpl<$Res, _$LegalContentImpl>
    implements _$$LegalContentImplCopyWith<$Res> {
  __$$LegalContentImplCopyWithImpl(
    _$LegalContentImpl _value,
    $Res Function(_$LegalContentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LegalContent
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
      _$LegalContentImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as LegalContentType,
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
                    as List<LegalSection>,
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

class _$LegalContentImpl extends _LegalContent {
  const _$LegalContentImpl({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required final List<LegalSection> sections,
    required this.updatedAt,
    this.summary,
  }) : _sections = sections,
       super._();

  @override
  final String id;
  @override
  final LegalContentType type;
  @override
  final String title;
  @override
  final String version;
  final List<LegalSection> _sections;
  @override
  List<LegalSection> get sections {
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
    return 'LegalContent(id: $id, type: $type, title: $title, version: $version, sections: $sections, updatedAt: $updatedAt, summary: $summary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalContentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.version, version) || other.version == version) &&
            const DeepCollectionEquality().equals(other._sections, _sections) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.summary, summary) || other.summary == summary));
  }

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

  /// Create a copy of LegalContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalContentImplCopyWith<_$LegalContentImpl> get copyWith =>
      __$$LegalContentImplCopyWithImpl<_$LegalContentImpl>(this, _$identity);
}

abstract class _LegalContent extends LegalContent {
  const factory _LegalContent({
    required final String id,
    required final LegalContentType type,
    required final String title,
    required final String version,
    required final List<LegalSection> sections,
    required final DateTime updatedAt,
    final String? summary,
  }) = _$LegalContentImpl;
  const _LegalContent._() : super._();

  @override
  String get id;
  @override
  LegalContentType get type;
  @override
  String get title;
  @override
  String get version;
  @override
  List<LegalSection> get sections;
  @override
  DateTime get updatedAt;
  @override
  String? get summary;

  /// Create a copy of LegalContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalContentImplCopyWith<_$LegalContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LegalSection {
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;

  /// Create a copy of LegalSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalSectionCopyWith<LegalSection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalSectionCopyWith<$Res> {
  factory $LegalSectionCopyWith(
    LegalSection value,
    $Res Function(LegalSection) then,
  ) = _$LegalSectionCopyWithImpl<$Res, LegalSection>;
  @useResult
  $Res call({String title, String content, int order});
}

/// @nodoc
class _$LegalSectionCopyWithImpl<$Res, $Val extends LegalSection>
    implements $LegalSectionCopyWith<$Res> {
  _$LegalSectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? content = null,
    Object? order = null,
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
                null == order
                    ? _value.order
                    : order // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LegalSectionImplCopyWith<$Res>
    implements $LegalSectionCopyWith<$Res> {
  factory _$$LegalSectionImplCopyWith(
    _$LegalSectionImpl value,
    $Res Function(_$LegalSectionImpl) then,
  ) = __$$LegalSectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String content, int order});
}

/// @nodoc
class __$$LegalSectionImplCopyWithImpl<$Res>
    extends _$LegalSectionCopyWithImpl<$Res, _$LegalSectionImpl>
    implements _$$LegalSectionImplCopyWith<$Res> {
  __$$LegalSectionImplCopyWithImpl(
    _$LegalSectionImpl _value,
    $Res Function(_$LegalSectionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LegalSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? content = null,
    Object? order = null,
  }) {
    return _then(
      _$LegalSectionImpl(
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
            null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$LegalSectionImpl implements _LegalSection {
  const _$LegalSectionImpl({
    required this.title,
    required this.content,
    this.order = 0,
  });

  @override
  final String title;
  @override
  final String content;
  @override
  @JsonKey()
  final int order;

  @override
  String toString() {
    return 'LegalSection(title: $title, content: $content, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalSectionImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.order, order) || other.order == order));
  }

  @override
  int get hashCode => Object.hash(runtimeType, title, content, order);

  /// Create a copy of LegalSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalSectionImplCopyWith<_$LegalSectionImpl> get copyWith =>
      __$$LegalSectionImplCopyWithImpl<_$LegalSectionImpl>(this, _$identity);
}

abstract class _LegalSection implements LegalSection {
  const factory _LegalSection({
    required final String title,
    required final String content,
    final int order,
  }) = _$LegalSectionImpl;

  @override
  String get title;
  @override
  String get content;
  @override
  int get order;

  /// Create a copy of LegalSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalSectionImplCopyWith<_$LegalSectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LegalAcceptance {
  String get termsVersion => throw _privateConstructorUsedError;
  String get privacyVersion => throw _privateConstructorUsedError;
  DateTime get acceptedAt => throw _privateConstructorUsedError;
  String? get conductVersion => throw _privateConstructorUsedError;

  /// Create a copy of LegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalAcceptanceCopyWith<LegalAcceptance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalAcceptanceCopyWith<$Res> {
  factory $LegalAcceptanceCopyWith(
    LegalAcceptance value,
    $Res Function(LegalAcceptance) then,
  ) = _$LegalAcceptanceCopyWithImpl<$Res, LegalAcceptance>;
  @useResult
  $Res call({
    String termsVersion,
    String privacyVersion,
    DateTime acceptedAt,
    String? conductVersion,
  });
}

/// @nodoc
class _$LegalAcceptanceCopyWithImpl<$Res, $Val extends LegalAcceptance>
    implements $LegalAcceptanceCopyWith<$Res> {
  _$LegalAcceptanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? termsVersion = null,
    Object? privacyVersion = null,
    Object? acceptedAt = null,
    Object? conductVersion = freezed,
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
            conductVersion:
                freezed == conductVersion
                    ? _value.conductVersion
                    : conductVersion // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LegalAcceptanceImplCopyWith<$Res>
    implements $LegalAcceptanceCopyWith<$Res> {
  factory _$$LegalAcceptanceImplCopyWith(
    _$LegalAcceptanceImpl value,
    $Res Function(_$LegalAcceptanceImpl) then,
  ) = __$$LegalAcceptanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String termsVersion,
    String privacyVersion,
    DateTime acceptedAt,
    String? conductVersion,
  });
}

/// @nodoc
class __$$LegalAcceptanceImplCopyWithImpl<$Res>
    extends _$LegalAcceptanceCopyWithImpl<$Res, _$LegalAcceptanceImpl>
    implements _$$LegalAcceptanceImplCopyWith<$Res> {
  __$$LegalAcceptanceImplCopyWithImpl(
    _$LegalAcceptanceImpl _value,
    $Res Function(_$LegalAcceptanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? termsVersion = null,
    Object? privacyVersion = null,
    Object? acceptedAt = null,
    Object? conductVersion = freezed,
  }) {
    return _then(
      _$LegalAcceptanceImpl(
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
        conductVersion:
            freezed == conductVersion
                ? _value.conductVersion
                : conductVersion // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$LegalAcceptanceImpl extends _LegalAcceptance {
  const _$LegalAcceptanceImpl({
    required this.termsVersion,
    required this.privacyVersion,
    required this.acceptedAt,
    this.conductVersion,
  }) : super._();

  @override
  final String termsVersion;
  @override
  final String privacyVersion;
  @override
  final DateTime acceptedAt;
  @override
  final String? conductVersion;

  @override
  String toString() {
    return 'LegalAcceptance(termsVersion: $termsVersion, privacyVersion: $privacyVersion, acceptedAt: $acceptedAt, conductVersion: $conductVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalAcceptanceImpl &&
            (identical(other.termsVersion, termsVersion) ||
                other.termsVersion == termsVersion) &&
            (identical(other.privacyVersion, privacyVersion) ||
                other.privacyVersion == privacyVersion) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.conductVersion, conductVersion) ||
                other.conductVersion == conductVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    termsVersion,
    privacyVersion,
    acceptedAt,
    conductVersion,
  );

  /// Create a copy of LegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalAcceptanceImplCopyWith<_$LegalAcceptanceImpl> get copyWith =>
      __$$LegalAcceptanceImplCopyWithImpl<_$LegalAcceptanceImpl>(
        this,
        _$identity,
      );
}

abstract class _LegalAcceptance extends LegalAcceptance {
  const factory _LegalAcceptance({
    required final String termsVersion,
    required final String privacyVersion,
    required final DateTime acceptedAt,
    final String? conductVersion,
  }) = _$LegalAcceptanceImpl;
  const _LegalAcceptance._() : super._();

  @override
  String get termsVersion;
  @override
  String get privacyVersion;
  @override
  DateTime get acceptedAt;
  @override
  String? get conductVersion;

  /// Create a copy of LegalAcceptance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalAcceptanceImplCopyWith<_$LegalAcceptanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
