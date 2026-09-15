// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mls.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$EntrantDto {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Uint8List clair) application,
    required TResult Function(InstantaneDto instantane) commit,
    required TResult Function() proposition,
    required TResult Function() ignore,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Uint8List clair)? application,
    TResult? Function(InstantaneDto instantane)? commit,
    TResult? Function()? proposition,
    TResult? Function()? ignore,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Uint8List clair)? application,
    TResult Function(InstantaneDto instantane)? commit,
    TResult Function()? proposition,
    TResult Function()? ignore,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EntrantDto_Application value) application,
    required TResult Function(EntrantDto_Commit value) commit,
    required TResult Function(EntrantDto_Proposition value) proposition,
    required TResult Function(EntrantDto_Ignore value) ignore,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EntrantDto_Application value)? application,
    TResult? Function(EntrantDto_Commit value)? commit,
    TResult? Function(EntrantDto_Proposition value)? proposition,
    TResult? Function(EntrantDto_Ignore value)? ignore,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EntrantDto_Application value)? application,
    TResult Function(EntrantDto_Commit value)? commit,
    TResult Function(EntrantDto_Proposition value)? proposition,
    TResult Function(EntrantDto_Ignore value)? ignore,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntrantDtoCopyWith<$Res> {
  factory $EntrantDtoCopyWith(
    EntrantDto value,
    $Res Function(EntrantDto) then,
  ) = _$EntrantDtoCopyWithImpl<$Res, EntrantDto>;
}

/// @nodoc
class _$EntrantDtoCopyWithImpl<$Res, $Val extends EntrantDto>
    implements $EntrantDtoCopyWith<$Res> {
  _$EntrantDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$EntrantDto_ApplicationImplCopyWith<$Res> {
  factory _$$EntrantDto_ApplicationImplCopyWith(
    _$EntrantDto_ApplicationImpl value,
    $Res Function(_$EntrantDto_ApplicationImpl) then,
  ) = __$$EntrantDto_ApplicationImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Uint8List clair});
}

/// @nodoc
class __$$EntrantDto_ApplicationImplCopyWithImpl<$Res>
    extends _$EntrantDtoCopyWithImpl<$Res, _$EntrantDto_ApplicationImpl>
    implements _$$EntrantDto_ApplicationImplCopyWith<$Res> {
  __$$EntrantDto_ApplicationImplCopyWithImpl(
    _$EntrantDto_ApplicationImpl _value,
    $Res Function(_$EntrantDto_ApplicationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? clair = null}) {
    return _then(
      _$EntrantDto_ApplicationImpl(
        clair:
            null == clair
                ? _value.clair
                : clair // ignore: cast_nullable_to_non_nullable
                    as Uint8List,
      ),
    );
  }
}

/// @nodoc

class _$EntrantDto_ApplicationImpl extends EntrantDto_Application {
  const _$EntrantDto_ApplicationImpl({required this.clair}) : super._();

  @override
  final Uint8List clair;

  @override
  String toString() {
    return 'EntrantDto.application(clair: $clair)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntrantDto_ApplicationImpl &&
            const DeepCollectionEquality().equals(other.clair, clair));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(clair));

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntrantDto_ApplicationImplCopyWith<_$EntrantDto_ApplicationImpl>
  get copyWith =>
      __$$EntrantDto_ApplicationImplCopyWithImpl<_$EntrantDto_ApplicationImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Uint8List clair) application,
    required TResult Function(InstantaneDto instantane) commit,
    required TResult Function() proposition,
    required TResult Function() ignore,
  }) {
    return application(clair);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Uint8List clair)? application,
    TResult? Function(InstantaneDto instantane)? commit,
    TResult? Function()? proposition,
    TResult? Function()? ignore,
  }) {
    return application?.call(clair);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Uint8List clair)? application,
    TResult Function(InstantaneDto instantane)? commit,
    TResult Function()? proposition,
    TResult Function()? ignore,
    required TResult orElse(),
  }) {
    if (application != null) {
      return application(clair);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EntrantDto_Application value) application,
    required TResult Function(EntrantDto_Commit value) commit,
    required TResult Function(EntrantDto_Proposition value) proposition,
    required TResult Function(EntrantDto_Ignore value) ignore,
  }) {
    return application(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EntrantDto_Application value)? application,
    TResult? Function(EntrantDto_Commit value)? commit,
    TResult? Function(EntrantDto_Proposition value)? proposition,
    TResult? Function(EntrantDto_Ignore value)? ignore,
  }) {
    return application?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EntrantDto_Application value)? application,
    TResult Function(EntrantDto_Commit value)? commit,
    TResult Function(EntrantDto_Proposition value)? proposition,
    TResult Function(EntrantDto_Ignore value)? ignore,
    required TResult orElse(),
  }) {
    if (application != null) {
      return application(this);
    }
    return orElse();
  }
}

abstract class EntrantDto_Application extends EntrantDto {
  const factory EntrantDto_Application({required final Uint8List clair}) =
      _$EntrantDto_ApplicationImpl;
  const EntrantDto_Application._() : super._();

  Uint8List get clair;

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntrantDto_ApplicationImplCopyWith<_$EntrantDto_ApplicationImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EntrantDto_CommitImplCopyWith<$Res> {
  factory _$$EntrantDto_CommitImplCopyWith(
    _$EntrantDto_CommitImpl value,
    $Res Function(_$EntrantDto_CommitImpl) then,
  ) = __$$EntrantDto_CommitImplCopyWithImpl<$Res>;
  @useResult
  $Res call({InstantaneDto instantane});
}

/// @nodoc
class __$$EntrantDto_CommitImplCopyWithImpl<$Res>
    extends _$EntrantDtoCopyWithImpl<$Res, _$EntrantDto_CommitImpl>
    implements _$$EntrantDto_CommitImplCopyWith<$Res> {
  __$$EntrantDto_CommitImplCopyWithImpl(
    _$EntrantDto_CommitImpl _value,
    $Res Function(_$EntrantDto_CommitImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? instantane = null}) {
    return _then(
      _$EntrantDto_CommitImpl(
        instantane:
            null == instantane
                ? _value.instantane
                : instantane // ignore: cast_nullable_to_non_nullable
                    as InstantaneDto,
      ),
    );
  }
}

/// @nodoc

class _$EntrantDto_CommitImpl extends EntrantDto_Commit {
  const _$EntrantDto_CommitImpl({required this.instantane}) : super._();

  @override
  final InstantaneDto instantane;

  @override
  String toString() {
    return 'EntrantDto.commit(instantane: $instantane)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntrantDto_CommitImpl &&
            (identical(other.instantane, instantane) ||
                other.instantane == instantane));
  }

  @override
  int get hashCode => Object.hash(runtimeType, instantane);

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntrantDto_CommitImplCopyWith<_$EntrantDto_CommitImpl> get copyWith =>
      __$$EntrantDto_CommitImplCopyWithImpl<_$EntrantDto_CommitImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Uint8List clair) application,
    required TResult Function(InstantaneDto instantane) commit,
    required TResult Function() proposition,
    required TResult Function() ignore,
  }) {
    return commit(instantane);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Uint8List clair)? application,
    TResult? Function(InstantaneDto instantane)? commit,
    TResult? Function()? proposition,
    TResult? Function()? ignore,
  }) {
    return commit?.call(instantane);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Uint8List clair)? application,
    TResult Function(InstantaneDto instantane)? commit,
    TResult Function()? proposition,
    TResult Function()? ignore,
    required TResult orElse(),
  }) {
    if (commit != null) {
      return commit(instantane);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EntrantDto_Application value) application,
    required TResult Function(EntrantDto_Commit value) commit,
    required TResult Function(EntrantDto_Proposition value) proposition,
    required TResult Function(EntrantDto_Ignore value) ignore,
  }) {
    return commit(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EntrantDto_Application value)? application,
    TResult? Function(EntrantDto_Commit value)? commit,
    TResult? Function(EntrantDto_Proposition value)? proposition,
    TResult? Function(EntrantDto_Ignore value)? ignore,
  }) {
    return commit?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EntrantDto_Application value)? application,
    TResult Function(EntrantDto_Commit value)? commit,
    TResult Function(EntrantDto_Proposition value)? proposition,
    TResult Function(EntrantDto_Ignore value)? ignore,
    required TResult orElse(),
  }) {
    if (commit != null) {
      return commit(this);
    }
    return orElse();
  }
}

abstract class EntrantDto_Commit extends EntrantDto {
  const factory EntrantDto_Commit({required final InstantaneDto instantane}) =
      _$EntrantDto_CommitImpl;
  const EntrantDto_Commit._() : super._();

  InstantaneDto get instantane;

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntrantDto_CommitImplCopyWith<_$EntrantDto_CommitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EntrantDto_PropositionImplCopyWith<$Res> {
  factory _$$EntrantDto_PropositionImplCopyWith(
    _$EntrantDto_PropositionImpl value,
    $Res Function(_$EntrantDto_PropositionImpl) then,
  ) = __$$EntrantDto_PropositionImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EntrantDto_PropositionImplCopyWithImpl<$Res>
    extends _$EntrantDtoCopyWithImpl<$Res, _$EntrantDto_PropositionImpl>
    implements _$$EntrantDto_PropositionImplCopyWith<$Res> {
  __$$EntrantDto_PropositionImplCopyWithImpl(
    _$EntrantDto_PropositionImpl _value,
    $Res Function(_$EntrantDto_PropositionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$EntrantDto_PropositionImpl extends EntrantDto_Proposition {
  const _$EntrantDto_PropositionImpl() : super._();

  @override
  String toString() {
    return 'EntrantDto.proposition()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntrantDto_PropositionImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Uint8List clair) application,
    required TResult Function(InstantaneDto instantane) commit,
    required TResult Function() proposition,
    required TResult Function() ignore,
  }) {
    return proposition();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Uint8List clair)? application,
    TResult? Function(InstantaneDto instantane)? commit,
    TResult? Function()? proposition,
    TResult? Function()? ignore,
  }) {
    return proposition?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Uint8List clair)? application,
    TResult Function(InstantaneDto instantane)? commit,
    TResult Function()? proposition,
    TResult Function()? ignore,
    required TResult orElse(),
  }) {
    if (proposition != null) {
      return proposition();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EntrantDto_Application value) application,
    required TResult Function(EntrantDto_Commit value) commit,
    required TResult Function(EntrantDto_Proposition value) proposition,
    required TResult Function(EntrantDto_Ignore value) ignore,
  }) {
    return proposition(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EntrantDto_Application value)? application,
    TResult? Function(EntrantDto_Commit value)? commit,
    TResult? Function(EntrantDto_Proposition value)? proposition,
    TResult? Function(EntrantDto_Ignore value)? ignore,
  }) {
    return proposition?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EntrantDto_Application value)? application,
    TResult Function(EntrantDto_Commit value)? commit,
    TResult Function(EntrantDto_Proposition value)? proposition,
    TResult Function(EntrantDto_Ignore value)? ignore,
    required TResult orElse(),
  }) {
    if (proposition != null) {
      return proposition(this);
    }
    return orElse();
  }
}

abstract class EntrantDto_Proposition extends EntrantDto {
  const factory EntrantDto_Proposition() = _$EntrantDto_PropositionImpl;
  const EntrantDto_Proposition._() : super._();
}

/// @nodoc
abstract class _$$EntrantDto_IgnoreImplCopyWith<$Res> {
  factory _$$EntrantDto_IgnoreImplCopyWith(
    _$EntrantDto_IgnoreImpl value,
    $Res Function(_$EntrantDto_IgnoreImpl) then,
  ) = __$$EntrantDto_IgnoreImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EntrantDto_IgnoreImplCopyWithImpl<$Res>
    extends _$EntrantDtoCopyWithImpl<$Res, _$EntrantDto_IgnoreImpl>
    implements _$$EntrantDto_IgnoreImplCopyWith<$Res> {
  __$$EntrantDto_IgnoreImplCopyWithImpl(
    _$EntrantDto_IgnoreImpl _value,
    $Res Function(_$EntrantDto_IgnoreImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EntrantDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$EntrantDto_IgnoreImpl extends EntrantDto_Ignore {
  const _$EntrantDto_IgnoreImpl() : super._();

  @override
  String toString() {
    return 'EntrantDto.ignore()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$EntrantDto_IgnoreImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Uint8List clair) application,
    required TResult Function(InstantaneDto instantane) commit,
    required TResult Function() proposition,
    required TResult Function() ignore,
  }) {
    return ignore();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Uint8List clair)? application,
    TResult? Function(InstantaneDto instantane)? commit,
    TResult? Function()? proposition,
    TResult? Function()? ignore,
  }) {
    return ignore?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Uint8List clair)? application,
    TResult Function(InstantaneDto instantane)? commit,
    TResult Function()? proposition,
    TResult Function()? ignore,
    required TResult orElse(),
  }) {
    if (ignore != null) {
      return ignore();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EntrantDto_Application value) application,
    required TResult Function(EntrantDto_Commit value) commit,
    required TResult Function(EntrantDto_Proposition value) proposition,
    required TResult Function(EntrantDto_Ignore value) ignore,
  }) {
    return ignore(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EntrantDto_Application value)? application,
    TResult? Function(EntrantDto_Commit value)? commit,
    TResult? Function(EntrantDto_Proposition value)? proposition,
    TResult? Function(EntrantDto_Ignore value)? ignore,
  }) {
    return ignore?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EntrantDto_Application value)? application,
    TResult Function(EntrantDto_Commit value)? commit,
    TResult Function(EntrantDto_Proposition value)? proposition,
    TResult Function(EntrantDto_Ignore value)? ignore,
    required TResult orElse(),
  }) {
    if (ignore != null) {
      return ignore(this);
    }
    return orElse();
  }
}

abstract class EntrantDto_Ignore extends EntrantDto {
  const factory EntrantDto_Ignore() = _$EntrantDto_IgnoreImpl;
  const EntrantDto_Ignore._() : super._();
}
