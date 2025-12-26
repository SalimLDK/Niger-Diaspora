// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AdminDashboardState {
  int get totalUsers => throw _privateConstructorUsedError;
  int get activeSessions => throw _privateConstructorUsedError;
  int get totalEvents => throw _privateConstructorUsedError;
  int get totalGroups => throw _privateConstructorUsedError;
  List<UserEntity> get recentUsers => throw _privateConstructorUsedError;
  List<dynamic> get recentContent =>
      throw _privateConstructorUsedError; // Events and Groups
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminDashboardState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminDashboardStateCopyWith<AdminDashboardState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminDashboardStateCopyWith<$Res> {
  factory $AdminDashboardStateCopyWith(
    AdminDashboardState value,
    $Res Function(AdminDashboardState) then,
  ) = _$AdminDashboardStateCopyWithImpl<$Res, AdminDashboardState>;
  @useResult
  $Res call({
    int totalUsers,
    int activeSessions,
    int totalEvents,
    int totalGroups,
    List<UserEntity> recentUsers,
    List<dynamic> recentContent,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminDashboardStateCopyWithImpl<$Res, $Val extends AdminDashboardState>
    implements $AdminDashboardStateCopyWith<$Res> {
  _$AdminDashboardStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminDashboardState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalUsers = null,
    Object? activeSessions = null,
    Object? totalEvents = null,
    Object? totalGroups = null,
    Object? recentUsers = null,
    Object? recentContent = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            totalUsers:
                null == totalUsers
                    ? _value.totalUsers
                    : totalUsers // ignore: cast_nullable_to_non_nullable
                        as int,
            activeSessions:
                null == activeSessions
                    ? _value.activeSessions
                    : activeSessions // ignore: cast_nullable_to_non_nullable
                        as int,
            totalEvents:
                null == totalEvents
                    ? _value.totalEvents
                    : totalEvents // ignore: cast_nullable_to_non_nullable
                        as int,
            totalGroups:
                null == totalGroups
                    ? _value.totalGroups
                    : totalGroups // ignore: cast_nullable_to_non_nullable
                        as int,
            recentUsers:
                null == recentUsers
                    ? _value.recentUsers
                    : recentUsers // ignore: cast_nullable_to_non_nullable
                        as List<UserEntity>,
            recentContent:
                null == recentContent
                    ? _value.recentContent
                    : recentContent // ignore: cast_nullable_to_non_nullable
                        as List<dynamic>,
            isLoading:
                null == isLoading
                    ? _value.isLoading
                    : isLoading // ignore: cast_nullable_to_non_nullable
                        as bool,
            error:
                freezed == error
                    ? _value.error
                    : error // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminDashboardStateImplCopyWith<$Res>
    implements $AdminDashboardStateCopyWith<$Res> {
  factory _$$AdminDashboardStateImplCopyWith(
    _$AdminDashboardStateImpl value,
    $Res Function(_$AdminDashboardStateImpl) then,
  ) = __$$AdminDashboardStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalUsers,
    int activeSessions,
    int totalEvents,
    int totalGroups,
    List<UserEntity> recentUsers,
    List<dynamic> recentContent,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminDashboardStateImplCopyWithImpl<$Res>
    extends _$AdminDashboardStateCopyWithImpl<$Res, _$AdminDashboardStateImpl>
    implements _$$AdminDashboardStateImplCopyWith<$Res> {
  __$$AdminDashboardStateImplCopyWithImpl(
    _$AdminDashboardStateImpl _value,
    $Res Function(_$AdminDashboardStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminDashboardState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalUsers = null,
    Object? activeSessions = null,
    Object? totalEvents = null,
    Object? totalGroups = null,
    Object? recentUsers = null,
    Object? recentContent = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminDashboardStateImpl(
        totalUsers:
            null == totalUsers
                ? _value.totalUsers
                : totalUsers // ignore: cast_nullable_to_non_nullable
                    as int,
        activeSessions:
            null == activeSessions
                ? _value.activeSessions
                : activeSessions // ignore: cast_nullable_to_non_nullable
                    as int,
        totalEvents:
            null == totalEvents
                ? _value.totalEvents
                : totalEvents // ignore: cast_nullable_to_non_nullable
                    as int,
        totalGroups:
            null == totalGroups
                ? _value.totalGroups
                : totalGroups // ignore: cast_nullable_to_non_nullable
                    as int,
        recentUsers:
            null == recentUsers
                ? _value._recentUsers
                : recentUsers // ignore: cast_nullable_to_non_nullable
                    as List<UserEntity>,
        recentContent:
            null == recentContent
                ? _value._recentContent
                : recentContent // ignore: cast_nullable_to_non_nullable
                    as List<dynamic>,
        isLoading:
            null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                    as bool,
        error:
            freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$AdminDashboardStateImpl implements _AdminDashboardState {
  const _$AdminDashboardStateImpl({
    this.totalUsers = 0,
    this.activeSessions = 0,
    this.totalEvents = 0,
    this.totalGroups = 0,
    final List<UserEntity> recentUsers = const [],
    final List<dynamic> recentContent = const [],
    this.isLoading = false,
    this.error,
  }) : _recentUsers = recentUsers,
       _recentContent = recentContent;

  @override
  @JsonKey()
  final int totalUsers;
  @override
  @JsonKey()
  final int activeSessions;
  @override
  @JsonKey()
  final int totalEvents;
  @override
  @JsonKey()
  final int totalGroups;
  final List<UserEntity> _recentUsers;
  @override
  @JsonKey()
  List<UserEntity> get recentUsers {
    if (_recentUsers is EqualUnmodifiableListView) return _recentUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentUsers);
  }

  final List<dynamic> _recentContent;
  @override
  @JsonKey()
  List<dynamic> get recentContent {
    if (_recentContent is EqualUnmodifiableListView) return _recentContent;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentContent);
  }

  // Events and Groups
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'AdminDashboardState(totalUsers: $totalUsers, activeSessions: $activeSessions, totalEvents: $totalEvents, totalGroups: $totalGroups, recentUsers: $recentUsers, recentContent: $recentContent, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminDashboardStateImpl &&
            (identical(other.totalUsers, totalUsers) ||
                other.totalUsers == totalUsers) &&
            (identical(other.activeSessions, activeSessions) ||
                other.activeSessions == activeSessions) &&
            (identical(other.totalEvents, totalEvents) ||
                other.totalEvents == totalEvents) &&
            (identical(other.totalGroups, totalGroups) ||
                other.totalGroups == totalGroups) &&
            const DeepCollectionEquality().equals(
              other._recentUsers,
              _recentUsers,
            ) &&
            const DeepCollectionEquality().equals(
              other._recentContent,
              _recentContent,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalUsers,
    activeSessions,
    totalEvents,
    totalGroups,
    const DeepCollectionEquality().hash(_recentUsers),
    const DeepCollectionEquality().hash(_recentContent),
    isLoading,
    error,
  );

  /// Create a copy of AdminDashboardState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminDashboardStateImplCopyWith<_$AdminDashboardStateImpl> get copyWith =>
      __$$AdminDashboardStateImplCopyWithImpl<_$AdminDashboardStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminDashboardState implements AdminDashboardState {
  const factory _AdminDashboardState({
    final int totalUsers,
    final int activeSessions,
    final int totalEvents,
    final int totalGroups,
    final List<UserEntity> recentUsers,
    final List<dynamic> recentContent,
    final bool isLoading,
    final String? error,
  }) = _$AdminDashboardStateImpl;

  @override
  int get totalUsers;
  @override
  int get activeSessions;
  @override
  int get totalEvents;
  @override
  int get totalGroups;
  @override
  List<UserEntity> get recentUsers;
  @override
  List<dynamic> get recentContent; // Events and Groups
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminDashboardState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminDashboardStateImplCopyWith<_$AdminDashboardStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
