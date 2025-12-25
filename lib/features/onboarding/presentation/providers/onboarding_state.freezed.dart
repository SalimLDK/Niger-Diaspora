// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OnboardingState {
  bool get hasSeenIntro => throw _privateConstructorUsedError;
  bool get hasSeenCoachMarks => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  int get currentPage => throw _privateConstructorUsedError;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OnboardingStateCopyWith<OnboardingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingStateCopyWith<$Res> {
  factory $OnboardingStateCopyWith(
    OnboardingState value,
    $Res Function(OnboardingState) then,
  ) = _$OnboardingStateCopyWithImpl<$Res, OnboardingState>;
  @useResult
  $Res call({
    bool hasSeenIntro,
    bool hasSeenCoachMarks,
    bool isLoading,
    int currentPage,
  });
}

/// @nodoc
class _$OnboardingStateCopyWithImpl<$Res, $Val extends OnboardingState>
    implements $OnboardingStateCopyWith<$Res> {
  _$OnboardingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasSeenIntro = null,
    Object? hasSeenCoachMarks = null,
    Object? isLoading = null,
    Object? currentPage = null,
  }) {
    return _then(
      _value.copyWith(
            hasSeenIntro:
                null == hasSeenIntro
                    ? _value.hasSeenIntro
                    : hasSeenIntro // ignore: cast_nullable_to_non_nullable
                        as bool,
            hasSeenCoachMarks:
                null == hasSeenCoachMarks
                    ? _value.hasSeenCoachMarks
                    : hasSeenCoachMarks // ignore: cast_nullable_to_non_nullable
                        as bool,
            isLoading:
                null == isLoading
                    ? _value.isLoading
                    : isLoading // ignore: cast_nullable_to_non_nullable
                        as bool,
            currentPage:
                null == currentPage
                    ? _value.currentPage
                    : currentPage // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OnboardingStateImplCopyWith<$Res>
    implements $OnboardingStateCopyWith<$Res> {
  factory _$$OnboardingStateImplCopyWith(
    _$OnboardingStateImpl value,
    $Res Function(_$OnboardingStateImpl) then,
  ) = __$$OnboardingStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool hasSeenIntro,
    bool hasSeenCoachMarks,
    bool isLoading,
    int currentPage,
  });
}

/// @nodoc
class __$$OnboardingStateImplCopyWithImpl<$Res>
    extends _$OnboardingStateCopyWithImpl<$Res, _$OnboardingStateImpl>
    implements _$$OnboardingStateImplCopyWith<$Res> {
  __$$OnboardingStateImplCopyWithImpl(
    _$OnboardingStateImpl _value,
    $Res Function(_$OnboardingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasSeenIntro = null,
    Object? hasSeenCoachMarks = null,
    Object? isLoading = null,
    Object? currentPage = null,
  }) {
    return _then(
      _$OnboardingStateImpl(
        hasSeenIntro:
            null == hasSeenIntro
                ? _value.hasSeenIntro
                : hasSeenIntro // ignore: cast_nullable_to_non_nullable
                    as bool,
        hasSeenCoachMarks:
            null == hasSeenCoachMarks
                ? _value.hasSeenCoachMarks
                : hasSeenCoachMarks // ignore: cast_nullable_to_non_nullable
                    as bool,
        isLoading:
            null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                    as bool,
        currentPage:
            null == currentPage
                ? _value.currentPage
                : currentPage // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$OnboardingStateImpl implements _OnboardingState {
  const _$OnboardingStateImpl({
    this.hasSeenIntro = false,
    this.hasSeenCoachMarks = false,
    this.isLoading = true,
    this.currentPage = 0,
  });

  @override
  @JsonKey()
  final bool hasSeenIntro;
  @override
  @JsonKey()
  final bool hasSeenCoachMarks;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final int currentPage;

  @override
  String toString() {
    return 'OnboardingState(hasSeenIntro: $hasSeenIntro, hasSeenCoachMarks: $hasSeenCoachMarks, isLoading: $isLoading, currentPage: $currentPage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingStateImpl &&
            (identical(other.hasSeenIntro, hasSeenIntro) ||
                other.hasSeenIntro == hasSeenIntro) &&
            (identical(other.hasSeenCoachMarks, hasSeenCoachMarks) ||
                other.hasSeenCoachMarks == hasSeenCoachMarks) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.currentPage, currentPage) ||
                other.currentPage == currentPage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    hasSeenIntro,
    hasSeenCoachMarks,
    isLoading,
    currentPage,
  );

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      __$$OnboardingStateImplCopyWithImpl<_$OnboardingStateImpl>(
        this,
        _$identity,
      );
}

abstract class _OnboardingState implements OnboardingState {
  const factory _OnboardingState({
    final bool hasSeenIntro,
    final bool hasSeenCoachMarks,
    final bool isLoading,
    final int currentPage,
  }) = _$OnboardingStateImpl;

  @override
  bool get hasSeenIntro;
  @override
  bool get hasSeenCoachMarks;
  @override
  bool get isLoading;
  @override
  int get currentPage;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
