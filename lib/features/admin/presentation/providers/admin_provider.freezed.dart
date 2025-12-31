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
mixin _$CurrentAdmin {
  String get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;

  /// Create a copy of CurrentAdmin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CurrentAdminCopyWith<CurrentAdmin> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurrentAdminCopyWith<$Res> {
  factory $CurrentAdminCopyWith(
    CurrentAdmin value,
    $Res Function(CurrentAdmin) then,
  ) = _$CurrentAdminCopyWithImpl<$Res, CurrentAdmin>;
  @useResult
  $Res call({String id, String? name, String? email});
}

/// @nodoc
class _$CurrentAdminCopyWithImpl<$Res, $Val extends CurrentAdmin>
    implements $CurrentAdminCopyWith<$Res> {
  _$CurrentAdminCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CurrentAdmin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? email = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                freezed == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CurrentAdminImplCopyWith<$Res>
    implements $CurrentAdminCopyWith<$Res> {
  factory _$$CurrentAdminImplCopyWith(
    _$CurrentAdminImpl value,
    $Res Function(_$CurrentAdminImpl) then,
  ) = __$$CurrentAdminImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String? name, String? email});
}

/// @nodoc
class __$$CurrentAdminImplCopyWithImpl<$Res>
    extends _$CurrentAdminCopyWithImpl<$Res, _$CurrentAdminImpl>
    implements _$$CurrentAdminImplCopyWith<$Res> {
  __$$CurrentAdminImplCopyWithImpl(
    _$CurrentAdminImpl _value,
    $Res Function(_$CurrentAdminImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CurrentAdmin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? email = freezed,
  }) {
    return _then(
      _$CurrentAdminImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$CurrentAdminImpl with DiagnosticableTreeMixin implements _CurrentAdmin {
  const _$CurrentAdminImpl({required this.id, this.name, this.email});

  @override
  final String id;
  @override
  final String? name;
  @override
  final String? email;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'CurrentAdmin(id: $id, name: $name, email: $email)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'CurrentAdmin'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('name', name))
      ..add(DiagnosticsProperty('email', email));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurrentAdminImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, email);

  /// Create a copy of CurrentAdmin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CurrentAdminImplCopyWith<_$CurrentAdminImpl> get copyWith =>
      __$$CurrentAdminImplCopyWithImpl<_$CurrentAdminImpl>(this, _$identity);
}

abstract class _CurrentAdmin implements CurrentAdmin {
  const factory _CurrentAdmin({
    required final String id,
    final String? name,
    final String? email,
  }) = _$CurrentAdminImpl;

  @override
  String get id;
  @override
  String? get name;
  @override
  String? get email;

  /// Create a copy of CurrentAdmin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CurrentAdminImplCopyWith<_$CurrentAdminImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminDashboardState {
  int get totalUsers => throw _privateConstructorUsedError;
  int get activeSessions => throw _privateConstructorUsedError;
  int get totalEvents => throw _privateConstructorUsedError;
  int get totalGroups => throw _privateConstructorUsedError;
  int get totalBusinesses => throw _privateConstructorUsedError;
  int get totalProducts => throw _privateConstructorUsedError;
  int get totalTransactions => throw _privateConstructorUsedError;
  int get pendingReports => throw _privateConstructorUsedError;
  List<UserEntity> get recentUsers => throw _privateConstructorUsedError;
  List<dynamic> get recentContent => throw _privateConstructorUsedError;
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
    int totalBusinesses,
    int totalProducts,
    int totalTransactions,
    int pendingReports,
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
    Object? totalBusinesses = null,
    Object? totalProducts = null,
    Object? totalTransactions = null,
    Object? pendingReports = null,
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
            totalBusinesses:
                null == totalBusinesses
                    ? _value.totalBusinesses
                    : totalBusinesses // ignore: cast_nullable_to_non_nullable
                        as int,
            totalProducts:
                null == totalProducts
                    ? _value.totalProducts
                    : totalProducts // ignore: cast_nullable_to_non_nullable
                        as int,
            totalTransactions:
                null == totalTransactions
                    ? _value.totalTransactions
                    : totalTransactions // ignore: cast_nullable_to_non_nullable
                        as int,
            pendingReports:
                null == pendingReports
                    ? _value.pendingReports
                    : pendingReports // ignore: cast_nullable_to_non_nullable
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
    int totalBusinesses,
    int totalProducts,
    int totalTransactions,
    int pendingReports,
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
    Object? totalBusinesses = null,
    Object? totalProducts = null,
    Object? totalTransactions = null,
    Object? pendingReports = null,
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
        totalBusinesses:
            null == totalBusinesses
                ? _value.totalBusinesses
                : totalBusinesses // ignore: cast_nullable_to_non_nullable
                    as int,
        totalProducts:
            null == totalProducts
                ? _value.totalProducts
                : totalProducts // ignore: cast_nullable_to_non_nullable
                    as int,
        totalTransactions:
            null == totalTransactions
                ? _value.totalTransactions
                : totalTransactions // ignore: cast_nullable_to_non_nullable
                    as int,
        pendingReports:
            null == pendingReports
                ? _value.pendingReports
                : pendingReports // ignore: cast_nullable_to_non_nullable
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

class _$AdminDashboardStateImpl
    with DiagnosticableTreeMixin
    implements _AdminDashboardState {
  const _$AdminDashboardStateImpl({
    this.totalUsers = 0,
    this.activeSessions = 0,
    this.totalEvents = 0,
    this.totalGroups = 0,
    this.totalBusinesses = 0,
    this.totalProducts = 0,
    this.totalTransactions = 0,
    this.pendingReports = 0,
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
  @override
  @JsonKey()
  final int totalBusinesses;
  @override
  @JsonKey()
  final int totalProducts;
  @override
  @JsonKey()
  final int totalTransactions;
  @override
  @JsonKey()
  final int pendingReports;
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

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminDashboardState(totalUsers: $totalUsers, activeSessions: $activeSessions, totalEvents: $totalEvents, totalGroups: $totalGroups, totalBusinesses: $totalBusinesses, totalProducts: $totalProducts, totalTransactions: $totalTransactions, pendingReports: $pendingReports, recentUsers: $recentUsers, recentContent: $recentContent, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminDashboardState'))
      ..add(DiagnosticsProperty('totalUsers', totalUsers))
      ..add(DiagnosticsProperty('activeSessions', activeSessions))
      ..add(DiagnosticsProperty('totalEvents', totalEvents))
      ..add(DiagnosticsProperty('totalGroups', totalGroups))
      ..add(DiagnosticsProperty('totalBusinesses', totalBusinesses))
      ..add(DiagnosticsProperty('totalProducts', totalProducts))
      ..add(DiagnosticsProperty('totalTransactions', totalTransactions))
      ..add(DiagnosticsProperty('pendingReports', pendingReports))
      ..add(DiagnosticsProperty('recentUsers', recentUsers))
      ..add(DiagnosticsProperty('recentContent', recentContent))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
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
            (identical(other.totalBusinesses, totalBusinesses) ||
                other.totalBusinesses == totalBusinesses) &&
            (identical(other.totalProducts, totalProducts) ||
                other.totalProducts == totalProducts) &&
            (identical(other.totalTransactions, totalTransactions) ||
                other.totalTransactions == totalTransactions) &&
            (identical(other.pendingReports, pendingReports) ||
                other.pendingReports == pendingReports) &&
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
    totalBusinesses,
    totalProducts,
    totalTransactions,
    pendingReports,
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
    final int totalBusinesses,
    final int totalProducts,
    final int totalTransactions,
    final int pendingReports,
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
  int get totalBusinesses;
  @override
  int get totalProducts;
  @override
  int get totalTransactions;
  @override
  int get pendingReports;
  @override
  List<UserEntity> get recentUsers;
  @override
  List<dynamic> get recentContent;
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

/// @nodoc
mixin _$AdminBusinessState {
  List<BusinessEntity> get businesses => throw _privateConstructorUsedError;
  List<BusinessEntity> get pendingVerification =>
      throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminBusinessState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminBusinessStateCopyWith<AdminBusinessState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminBusinessStateCopyWith<$Res> {
  factory $AdminBusinessStateCopyWith(
    AdminBusinessState value,
    $Res Function(AdminBusinessState) then,
  ) = _$AdminBusinessStateCopyWithImpl<$Res, AdminBusinessState>;
  @useResult
  $Res call({
    List<BusinessEntity> businesses,
    List<BusinessEntity> pendingVerification,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminBusinessStateCopyWithImpl<$Res, $Val extends AdminBusinessState>
    implements $AdminBusinessStateCopyWith<$Res> {
  _$AdminBusinessStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminBusinessState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? businesses = null,
    Object? pendingVerification = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            businesses:
                null == businesses
                    ? _value.businesses
                    : businesses // ignore: cast_nullable_to_non_nullable
                        as List<BusinessEntity>,
            pendingVerification:
                null == pendingVerification
                    ? _value.pendingVerification
                    : pendingVerification // ignore: cast_nullable_to_non_nullable
                        as List<BusinessEntity>,
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
abstract class _$$AdminBusinessStateImplCopyWith<$Res>
    implements $AdminBusinessStateCopyWith<$Res> {
  factory _$$AdminBusinessStateImplCopyWith(
    _$AdminBusinessStateImpl value,
    $Res Function(_$AdminBusinessStateImpl) then,
  ) = __$$AdminBusinessStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<BusinessEntity> businesses,
    List<BusinessEntity> pendingVerification,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminBusinessStateImplCopyWithImpl<$Res>
    extends _$AdminBusinessStateCopyWithImpl<$Res, _$AdminBusinessStateImpl>
    implements _$$AdminBusinessStateImplCopyWith<$Res> {
  __$$AdminBusinessStateImplCopyWithImpl(
    _$AdminBusinessStateImpl _value,
    $Res Function(_$AdminBusinessStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminBusinessState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? businesses = null,
    Object? pendingVerification = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminBusinessStateImpl(
        businesses:
            null == businesses
                ? _value._businesses
                : businesses // ignore: cast_nullable_to_non_nullable
                    as List<BusinessEntity>,
        pendingVerification:
            null == pendingVerification
                ? _value._pendingVerification
                : pendingVerification // ignore: cast_nullable_to_non_nullable
                    as List<BusinessEntity>,
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

class _$AdminBusinessStateImpl
    with DiagnosticableTreeMixin
    implements _AdminBusinessState {
  const _$AdminBusinessStateImpl({
    final List<BusinessEntity> businesses = const [],
    final List<BusinessEntity> pendingVerification = const [],
    this.isLoading = false,
    this.error,
  }) : _businesses = businesses,
       _pendingVerification = pendingVerification;

  final List<BusinessEntity> _businesses;
  @override
  @JsonKey()
  List<BusinessEntity> get businesses {
    if (_businesses is EqualUnmodifiableListView) return _businesses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_businesses);
  }

  final List<BusinessEntity> _pendingVerification;
  @override
  @JsonKey()
  List<BusinessEntity> get pendingVerification {
    if (_pendingVerification is EqualUnmodifiableListView)
      return _pendingVerification;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingVerification);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminBusinessState(businesses: $businesses, pendingVerification: $pendingVerification, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminBusinessState'))
      ..add(DiagnosticsProperty('businesses', businesses))
      ..add(DiagnosticsProperty('pendingVerification', pendingVerification))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminBusinessStateImpl &&
            const DeepCollectionEquality().equals(
              other._businesses,
              _businesses,
            ) &&
            const DeepCollectionEquality().equals(
              other._pendingVerification,
              _pendingVerification,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_businesses),
    const DeepCollectionEquality().hash(_pendingVerification),
    isLoading,
    error,
  );

  /// Create a copy of AdminBusinessState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminBusinessStateImplCopyWith<_$AdminBusinessStateImpl> get copyWith =>
      __$$AdminBusinessStateImplCopyWithImpl<_$AdminBusinessStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminBusinessState implements AdminBusinessState {
  const factory _AdminBusinessState({
    final List<BusinessEntity> businesses,
    final List<BusinessEntity> pendingVerification,
    final bool isLoading,
    final String? error,
  }) = _$AdminBusinessStateImpl;

  @override
  List<BusinessEntity> get businesses;
  @override
  List<BusinessEntity> get pendingVerification;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminBusinessState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminBusinessStateImplCopyWith<_$AdminBusinessStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminContentState {
  List<EventEntity> get events => throw _privateConstructorUsedError;
  List<GroupEntity> get groups => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminContentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminContentStateCopyWith<AdminContentState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminContentStateCopyWith<$Res> {
  factory $AdminContentStateCopyWith(
    AdminContentState value,
    $Res Function(AdminContentState) then,
  ) = _$AdminContentStateCopyWithImpl<$Res, AdminContentState>;
  @useResult
  $Res call({
    List<EventEntity> events,
    List<GroupEntity> groups,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminContentStateCopyWithImpl<$Res, $Val extends AdminContentState>
    implements $AdminContentStateCopyWith<$Res> {
  _$AdminContentStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminContentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? events = null,
    Object? groups = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            events:
                null == events
                    ? _value.events
                    : events // ignore: cast_nullable_to_non_nullable
                        as List<EventEntity>,
            groups:
                null == groups
                    ? _value.groups
                    : groups // ignore: cast_nullable_to_non_nullable
                        as List<GroupEntity>,
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
abstract class _$$AdminContentStateImplCopyWith<$Res>
    implements $AdminContentStateCopyWith<$Res> {
  factory _$$AdminContentStateImplCopyWith(
    _$AdminContentStateImpl value,
    $Res Function(_$AdminContentStateImpl) then,
  ) = __$$AdminContentStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<EventEntity> events,
    List<GroupEntity> groups,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminContentStateImplCopyWithImpl<$Res>
    extends _$AdminContentStateCopyWithImpl<$Res, _$AdminContentStateImpl>
    implements _$$AdminContentStateImplCopyWith<$Res> {
  __$$AdminContentStateImplCopyWithImpl(
    _$AdminContentStateImpl _value,
    $Res Function(_$AdminContentStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminContentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? events = null,
    Object? groups = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminContentStateImpl(
        events:
            null == events
                ? _value._events
                : events // ignore: cast_nullable_to_non_nullable
                    as List<EventEntity>,
        groups:
            null == groups
                ? _value._groups
                : groups // ignore: cast_nullable_to_non_nullable
                    as List<GroupEntity>,
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

class _$AdminContentStateImpl
    with DiagnosticableTreeMixin
    implements _AdminContentState {
  const _$AdminContentStateImpl({
    final List<EventEntity> events = const [],
    final List<GroupEntity> groups = const [],
    this.isLoading = false,
    this.error,
  }) : _events = events,
       _groups = groups;

  final List<EventEntity> _events;
  @override
  @JsonKey()
  List<EventEntity> get events {
    if (_events is EqualUnmodifiableListView) return _events;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_events);
  }

  final List<GroupEntity> _groups;
  @override
  @JsonKey()
  List<GroupEntity> get groups {
    if (_groups is EqualUnmodifiableListView) return _groups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_groups);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminContentState(events: $events, groups: $groups, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminContentState'))
      ..add(DiagnosticsProperty('events', events))
      ..add(DiagnosticsProperty('groups', groups))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminContentStateImpl &&
            const DeepCollectionEquality().equals(other._events, _events) &&
            const DeepCollectionEquality().equals(other._groups, _groups) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_events),
    const DeepCollectionEquality().hash(_groups),
    isLoading,
    error,
  );

  /// Create a copy of AdminContentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminContentStateImplCopyWith<_$AdminContentStateImpl> get copyWith =>
      __$$AdminContentStateImplCopyWithImpl<_$AdminContentStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminContentState implements AdminContentState {
  const factory _AdminContentState({
    final List<EventEntity> events,
    final List<GroupEntity> groups,
    final bool isLoading,
    final String? error,
  }) = _$AdminContentStateImpl;

  @override
  List<EventEntity> get events;
  @override
  List<GroupEntity> get groups;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminContentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminContentStateImplCopyWith<_$AdminContentStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ReportEntity {
  String get id => throw _privateConstructorUsedError;
  String get reporterId => throw _privateConstructorUsedError;
  String? get reporterName => throw _privateConstructorUsedError;
  String get targetType =>
      throw _privateConstructorUsedError; // 'user', 'message', 'event', 'group', 'business', 'product'
  String get targetId => throw _privateConstructorUsedError;
  String? get targetName => throw _privateConstructorUsedError;
  String? get conversationId =>
      throw _privateConstructorUsedError; // For message/conversation reports
  String get reason => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Snapshot du contenu signalé
  ContentSnapshotData? get contentSnapshot =>
      throw _privateConstructorUsedError;

  /// ID de l'utilisateur signalé (pour notification)
  String? get reportedUserId => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 'pending', 'reviewed', 'resolved', 'dismissed'
  String? get adminNote => throw _privateConstructorUsedError;
  String? get reviewedBy => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;

  /// Indique si la personne signalée a été notifiée
  bool get reportedUserNotified => throw _privateConstructorUsedError;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportEntityCopyWith<ReportEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportEntityCopyWith<$Res> {
  factory $ReportEntityCopyWith(
    ReportEntity value,
    $Res Function(ReportEntity) then,
  ) = _$ReportEntityCopyWithImpl<$Res, ReportEntity>;
  @useResult
  $Res call({
    String id,
    String reporterId,
    String? reporterName,
    String targetType,
    String targetId,
    String? targetName,
    String? conversationId,
    String reason,
    String? description,
    ContentSnapshotData? contentSnapshot,
    String? reportedUserId,
    String status,
    String? adminNote,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? reviewedAt,
    bool reportedUserNotified,
  });
}

/// @nodoc
class _$ReportEntityCopyWithImpl<$Res, $Val extends ReportEntity>
    implements $ReportEntityCopyWith<$Res> {
  _$ReportEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reporterName = freezed,
    Object? targetType = null,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? conversationId = freezed,
    Object? reason = null,
    Object? description = freezed,
    Object? contentSnapshot = freezed,
    Object? reportedUserId = freezed,
    Object? status = null,
    Object? adminNote = freezed,
    Object? reviewedBy = freezed,
    Object? createdAt = freezed,
    Object? reviewedAt = freezed,
    Object? reportedUserNotified = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            reporterId:
                null == reporterId
                    ? _value.reporterId
                    : reporterId // ignore: cast_nullable_to_non_nullable
                        as String,
            reporterName:
                freezed == reporterName
                    ? _value.reporterName
                    : reporterName // ignore: cast_nullable_to_non_nullable
                        as String?,
            targetType:
                null == targetType
                    ? _value.targetType
                    : targetType // ignore: cast_nullable_to_non_nullable
                        as String,
            targetId:
                null == targetId
                    ? _value.targetId
                    : targetId // ignore: cast_nullable_to_non_nullable
                        as String,
            targetName:
                freezed == targetName
                    ? _value.targetName
                    : targetName // ignore: cast_nullable_to_non_nullable
                        as String?,
            conversationId:
                freezed == conversationId
                    ? _value.conversationId
                    : conversationId // ignore: cast_nullable_to_non_nullable
                        as String?,
            reason:
                null == reason
                    ? _value.reason
                    : reason // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            contentSnapshot:
                freezed == contentSnapshot
                    ? _value.contentSnapshot
                    : contentSnapshot // ignore: cast_nullable_to_non_nullable
                        as ContentSnapshotData?,
            reportedUserId:
                freezed == reportedUserId
                    ? _value.reportedUserId
                    : reportedUserId // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            adminNote:
                freezed == adminNote
                    ? _value.adminNote
                    : adminNote // ignore: cast_nullable_to_non_nullable
                        as String?,
            reviewedBy:
                freezed == reviewedBy
                    ? _value.reviewedBy
                    : reviewedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            reviewedAt:
                freezed == reviewedAt
                    ? _value.reviewedAt
                    : reviewedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            reportedUserNotified:
                null == reportedUserNotified
                    ? _value.reportedUserNotified
                    : reportedUserNotified // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReportEntityImplCopyWith<$Res>
    implements $ReportEntityCopyWith<$Res> {
  factory _$$ReportEntityImplCopyWith(
    _$ReportEntityImpl value,
    $Res Function(_$ReportEntityImpl) then,
  ) = __$$ReportEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String reporterId,
    String? reporterName,
    String targetType,
    String targetId,
    String? targetName,
    String? conversationId,
    String reason,
    String? description,
    ContentSnapshotData? contentSnapshot,
    String? reportedUserId,
    String status,
    String? adminNote,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? reviewedAt,
    bool reportedUserNotified,
  });
}

/// @nodoc
class __$$ReportEntityImplCopyWithImpl<$Res>
    extends _$ReportEntityCopyWithImpl<$Res, _$ReportEntityImpl>
    implements _$$ReportEntityImplCopyWith<$Res> {
  __$$ReportEntityImplCopyWithImpl(
    _$ReportEntityImpl _value,
    $Res Function(_$ReportEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reporterName = freezed,
    Object? targetType = null,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? conversationId = freezed,
    Object? reason = null,
    Object? description = freezed,
    Object? contentSnapshot = freezed,
    Object? reportedUserId = freezed,
    Object? status = null,
    Object? adminNote = freezed,
    Object? reviewedBy = freezed,
    Object? createdAt = freezed,
    Object? reviewedAt = freezed,
    Object? reportedUserNotified = null,
  }) {
    return _then(
      _$ReportEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        reporterId:
            null == reporterId
                ? _value.reporterId
                : reporterId // ignore: cast_nullable_to_non_nullable
                    as String,
        reporterName:
            freezed == reporterName
                ? _value.reporterName
                : reporterName // ignore: cast_nullable_to_non_nullable
                    as String?,
        targetType:
            null == targetType
                ? _value.targetType
                : targetType // ignore: cast_nullable_to_non_nullable
                    as String,
        targetId:
            null == targetId
                ? _value.targetId
                : targetId // ignore: cast_nullable_to_non_nullable
                    as String,
        targetName:
            freezed == targetName
                ? _value.targetName
                : targetName // ignore: cast_nullable_to_non_nullable
                    as String?,
        conversationId:
            freezed == conversationId
                ? _value.conversationId
                : conversationId // ignore: cast_nullable_to_non_nullable
                    as String?,
        reason:
            null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        contentSnapshot:
            freezed == contentSnapshot
                ? _value.contentSnapshot
                : contentSnapshot // ignore: cast_nullable_to_non_nullable
                    as ContentSnapshotData?,
        reportedUserId:
            freezed == reportedUserId
                ? _value.reportedUserId
                : reportedUserId // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        adminNote:
            freezed == adminNote
                ? _value.adminNote
                : adminNote // ignore: cast_nullable_to_non_nullable
                    as String?,
        reviewedBy:
            freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        reviewedAt:
            freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        reportedUserNotified:
            null == reportedUserNotified
                ? _value.reportedUserNotified
                : reportedUserNotified // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$ReportEntityImpl with DiagnosticableTreeMixin implements _ReportEntity {
  const _$ReportEntityImpl({
    required this.id,
    required this.reporterId,
    this.reporterName,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.conversationId,
    required this.reason,
    this.description,
    this.contentSnapshot,
    this.reportedUserId,
    this.status = 'pending',
    this.adminNote,
    this.reviewedBy,
    this.createdAt,
    this.reviewedAt,
    this.reportedUserNotified = false,
  });

  @override
  final String id;
  @override
  final String reporterId;
  @override
  final String? reporterName;
  @override
  final String targetType;
  // 'user', 'message', 'event', 'group', 'business', 'product'
  @override
  final String targetId;
  @override
  final String? targetName;
  @override
  final String? conversationId;
  // For message/conversation reports
  @override
  final String reason;
  @override
  final String? description;

  /// Snapshot du contenu signalé
  @override
  final ContentSnapshotData? contentSnapshot;

  /// ID de l'utilisateur signalé (pour notification)
  @override
  final String? reportedUserId;
  @override
  @JsonKey()
  final String status;
  // 'pending', 'reviewed', 'resolved', 'dismissed'
  @override
  final String? adminNote;
  @override
  final String? reviewedBy;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? reviewedAt;

  /// Indique si la personne signalée a été notifiée
  @override
  @JsonKey()
  final bool reportedUserNotified;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ReportEntity(id: $id, reporterId: $reporterId, reporterName: $reporterName, targetType: $targetType, targetId: $targetId, targetName: $targetName, conversationId: $conversationId, reason: $reason, description: $description, contentSnapshot: $contentSnapshot, reportedUserId: $reportedUserId, status: $status, adminNote: $adminNote, reviewedBy: $reviewedBy, createdAt: $createdAt, reviewedAt: $reviewedAt, reportedUserNotified: $reportedUserNotified)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ReportEntity'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('reporterId', reporterId))
      ..add(DiagnosticsProperty('reporterName', reporterName))
      ..add(DiagnosticsProperty('targetType', targetType))
      ..add(DiagnosticsProperty('targetId', targetId))
      ..add(DiagnosticsProperty('targetName', targetName))
      ..add(DiagnosticsProperty('conversationId', conversationId))
      ..add(DiagnosticsProperty('reason', reason))
      ..add(DiagnosticsProperty('description', description))
      ..add(DiagnosticsProperty('contentSnapshot', contentSnapshot))
      ..add(DiagnosticsProperty('reportedUserId', reportedUserId))
      ..add(DiagnosticsProperty('status', status))
      ..add(DiagnosticsProperty('adminNote', adminNote))
      ..add(DiagnosticsProperty('reviewedBy', reviewedBy))
      ..add(DiagnosticsProperty('createdAt', createdAt))
      ..add(DiagnosticsProperty('reviewedAt', reviewedAt))
      ..add(DiagnosticsProperty('reportedUserNotified', reportedUserNotified));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.reporterId, reporterId) ||
                other.reporterId == reporterId) &&
            (identical(other.reporterName, reporterName) ||
                other.reporterName == reporterName) &&
            (identical(other.targetType, targetType) ||
                other.targetType == targetType) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            (identical(other.targetName, targetName) ||
                other.targetName == targetName) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.contentSnapshot, contentSnapshot) ||
                other.contentSnapshot == contentSnapshot) &&
            (identical(other.reportedUserId, reportedUserId) ||
                other.reportedUserId == reportedUserId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.adminNote, adminNote) ||
                other.adminNote == adminNote) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reportedUserNotified, reportedUserNotified) ||
                other.reportedUserNotified == reportedUserNotified));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    reporterId,
    reporterName,
    targetType,
    targetId,
    targetName,
    conversationId,
    reason,
    description,
    contentSnapshot,
    reportedUserId,
    status,
    adminNote,
    reviewedBy,
    createdAt,
    reviewedAt,
    reportedUserNotified,
  );

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportEntityImplCopyWith<_$ReportEntityImpl> get copyWith =>
      __$$ReportEntityImplCopyWithImpl<_$ReportEntityImpl>(this, _$identity);
}

abstract class _ReportEntity implements ReportEntity {
  const factory _ReportEntity({
    required final String id,
    required final String reporterId,
    final String? reporterName,
    required final String targetType,
    required final String targetId,
    final String? targetName,
    final String? conversationId,
    required final String reason,
    final String? description,
    final ContentSnapshotData? contentSnapshot,
    final String? reportedUserId,
    final String status,
    final String? adminNote,
    final String? reviewedBy,
    final DateTime? createdAt,
    final DateTime? reviewedAt,
    final bool reportedUserNotified,
  }) = _$ReportEntityImpl;

  @override
  String get id;
  @override
  String get reporterId;
  @override
  String? get reporterName;
  @override
  String get targetType; // 'user', 'message', 'event', 'group', 'business', 'product'
  @override
  String get targetId;
  @override
  String? get targetName;
  @override
  String? get conversationId; // For message/conversation reports
  @override
  String get reason;
  @override
  String? get description;

  /// Snapshot du contenu signalé
  @override
  ContentSnapshotData? get contentSnapshot;

  /// ID de l'utilisateur signalé (pour notification)
  @override
  String? get reportedUserId;
  @override
  String get status; // 'pending', 'reviewed', 'resolved', 'dismissed'
  @override
  String? get adminNote;
  @override
  String? get reviewedBy;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get reviewedAt;

  /// Indique si la personne signalée a été notifiée
  @override
  bool get reportedUserNotified;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportEntityImplCopyWith<_$ReportEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminReportsState {
  List<ReportEntity> get reports => throw _privateConstructorUsedError;
  List<ReportEntity> get pendingReports => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminReportsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminReportsStateCopyWith<AdminReportsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminReportsStateCopyWith<$Res> {
  factory $AdminReportsStateCopyWith(
    AdminReportsState value,
    $Res Function(AdminReportsState) then,
  ) = _$AdminReportsStateCopyWithImpl<$Res, AdminReportsState>;
  @useResult
  $Res call({
    List<ReportEntity> reports,
    List<ReportEntity> pendingReports,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminReportsStateCopyWithImpl<$Res, $Val extends AdminReportsState>
    implements $AdminReportsStateCopyWith<$Res> {
  _$AdminReportsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminReportsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reports = null,
    Object? pendingReports = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            reports:
                null == reports
                    ? _value.reports
                    : reports // ignore: cast_nullable_to_non_nullable
                        as List<ReportEntity>,
            pendingReports:
                null == pendingReports
                    ? _value.pendingReports
                    : pendingReports // ignore: cast_nullable_to_non_nullable
                        as List<ReportEntity>,
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
abstract class _$$AdminReportsStateImplCopyWith<$Res>
    implements $AdminReportsStateCopyWith<$Res> {
  factory _$$AdminReportsStateImplCopyWith(
    _$AdminReportsStateImpl value,
    $Res Function(_$AdminReportsStateImpl) then,
  ) = __$$AdminReportsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<ReportEntity> reports,
    List<ReportEntity> pendingReports,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminReportsStateImplCopyWithImpl<$Res>
    extends _$AdminReportsStateCopyWithImpl<$Res, _$AdminReportsStateImpl>
    implements _$$AdminReportsStateImplCopyWith<$Res> {
  __$$AdminReportsStateImplCopyWithImpl(
    _$AdminReportsStateImpl _value,
    $Res Function(_$AdminReportsStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminReportsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reports = null,
    Object? pendingReports = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminReportsStateImpl(
        reports:
            null == reports
                ? _value._reports
                : reports // ignore: cast_nullable_to_non_nullable
                    as List<ReportEntity>,
        pendingReports:
            null == pendingReports
                ? _value._pendingReports
                : pendingReports // ignore: cast_nullable_to_non_nullable
                    as List<ReportEntity>,
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

class _$AdminReportsStateImpl
    with DiagnosticableTreeMixin
    implements _AdminReportsState {
  const _$AdminReportsStateImpl({
    final List<ReportEntity> reports = const [],
    final List<ReportEntity> pendingReports = const [],
    this.isLoading = false,
    this.error,
  }) : _reports = reports,
       _pendingReports = pendingReports;

  final List<ReportEntity> _reports;
  @override
  @JsonKey()
  List<ReportEntity> get reports {
    if (_reports is EqualUnmodifiableListView) return _reports;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reports);
  }

  final List<ReportEntity> _pendingReports;
  @override
  @JsonKey()
  List<ReportEntity> get pendingReports {
    if (_pendingReports is EqualUnmodifiableListView) return _pendingReports;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingReports);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminReportsState(reports: $reports, pendingReports: $pendingReports, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminReportsState'))
      ..add(DiagnosticsProperty('reports', reports))
      ..add(DiagnosticsProperty('pendingReports', pendingReports))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminReportsStateImpl &&
            const DeepCollectionEquality().equals(other._reports, _reports) &&
            const DeepCollectionEquality().equals(
              other._pendingReports,
              _pendingReports,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_reports),
    const DeepCollectionEquality().hash(_pendingReports),
    isLoading,
    error,
  );

  /// Create a copy of AdminReportsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminReportsStateImplCopyWith<_$AdminReportsStateImpl> get copyWith =>
      __$$AdminReportsStateImplCopyWithImpl<_$AdminReportsStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminReportsState implements AdminReportsState {
  const factory _AdminReportsState({
    final List<ReportEntity> reports,
    final List<ReportEntity> pendingReports,
    final bool isLoading,
    final String? error,
  }) = _$AdminReportsStateImpl;

  @override
  List<ReportEntity> get reports;
  @override
  List<ReportEntity> get pendingReports;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminReportsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminReportsStateImplCopyWith<_$AdminReportsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminMarketplaceState {
  List<ProductEntity> get products => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get orders => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get disputes => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminMarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminMarketplaceStateCopyWith<AdminMarketplaceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminMarketplaceStateCopyWith<$Res> {
  factory $AdminMarketplaceStateCopyWith(
    AdminMarketplaceState value,
    $Res Function(AdminMarketplaceState) then,
  ) = _$AdminMarketplaceStateCopyWithImpl<$Res, AdminMarketplaceState>;
  @useResult
  $Res call({
    List<ProductEntity> products,
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> disputes,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminMarketplaceStateCopyWithImpl<
  $Res,
  $Val extends AdminMarketplaceState
>
    implements $AdminMarketplaceStateCopyWith<$Res> {
  _$AdminMarketplaceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminMarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? orders = null,
    Object? disputes = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            products:
                null == products
                    ? _value.products
                    : products // ignore: cast_nullable_to_non_nullable
                        as List<ProductEntity>,
            orders:
                null == orders
                    ? _value.orders
                    : orders // ignore: cast_nullable_to_non_nullable
                        as List<Map<String, dynamic>>,
            disputes:
                null == disputes
                    ? _value.disputes
                    : disputes // ignore: cast_nullable_to_non_nullable
                        as List<Map<String, dynamic>>,
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
abstract class _$$AdminMarketplaceStateImplCopyWith<$Res>
    implements $AdminMarketplaceStateCopyWith<$Res> {
  factory _$$AdminMarketplaceStateImplCopyWith(
    _$AdminMarketplaceStateImpl value,
    $Res Function(_$AdminMarketplaceStateImpl) then,
  ) = __$$AdminMarketplaceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<ProductEntity> products,
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> disputes,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminMarketplaceStateImplCopyWithImpl<$Res>
    extends
        _$AdminMarketplaceStateCopyWithImpl<$Res, _$AdminMarketplaceStateImpl>
    implements _$$AdminMarketplaceStateImplCopyWith<$Res> {
  __$$AdminMarketplaceStateImplCopyWithImpl(
    _$AdminMarketplaceStateImpl _value,
    $Res Function(_$AdminMarketplaceStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminMarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? orders = null,
    Object? disputes = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminMarketplaceStateImpl(
        products:
            null == products
                ? _value._products
                : products // ignore: cast_nullable_to_non_nullable
                    as List<ProductEntity>,
        orders:
            null == orders
                ? _value._orders
                : orders // ignore: cast_nullable_to_non_nullable
                    as List<Map<String, dynamic>>,
        disputes:
            null == disputes
                ? _value._disputes
                : disputes // ignore: cast_nullable_to_non_nullable
                    as List<Map<String, dynamic>>,
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

class _$AdminMarketplaceStateImpl
    with DiagnosticableTreeMixin
    implements _AdminMarketplaceState {
  const _$AdminMarketplaceStateImpl({
    final List<ProductEntity> products = const [],
    final List<Map<String, dynamic>> orders = const [],
    final List<Map<String, dynamic>> disputes = const [],
    this.isLoading = false,
    this.error,
  }) : _products = products,
       _orders = orders,
       _disputes = disputes;

  final List<ProductEntity> _products;
  @override
  @JsonKey()
  List<ProductEntity> get products {
    if (_products is EqualUnmodifiableListView) return _products;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_products);
  }

  final List<Map<String, dynamic>> _orders;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get orders {
    if (_orders is EqualUnmodifiableListView) return _orders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_orders);
  }

  final List<Map<String, dynamic>> _disputes;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get disputes {
    if (_disputes is EqualUnmodifiableListView) return _disputes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_disputes);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminMarketplaceState(products: $products, orders: $orders, disputes: $disputes, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminMarketplaceState'))
      ..add(DiagnosticsProperty('products', products))
      ..add(DiagnosticsProperty('orders', orders))
      ..add(DiagnosticsProperty('disputes', disputes))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminMarketplaceStateImpl &&
            const DeepCollectionEquality().equals(other._products, _products) &&
            const DeepCollectionEquality().equals(other._orders, _orders) &&
            const DeepCollectionEquality().equals(other._disputes, _disputes) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_products),
    const DeepCollectionEquality().hash(_orders),
    const DeepCollectionEquality().hash(_disputes),
    isLoading,
    error,
  );

  /// Create a copy of AdminMarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminMarketplaceStateImplCopyWith<_$AdminMarketplaceStateImpl>
  get copyWith =>
      __$$AdminMarketplaceStateImplCopyWithImpl<_$AdminMarketplaceStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminMarketplaceState implements AdminMarketplaceState {
  const factory _AdminMarketplaceState({
    final List<ProductEntity> products,
    final List<Map<String, dynamic>> orders,
    final List<Map<String, dynamic>> disputes,
    final bool isLoading,
    final String? error,
  }) = _$AdminMarketplaceStateImpl;

  @override
  List<ProductEntity> get products;
  @override
  List<Map<String, dynamic>> get orders;
  @override
  List<Map<String, dynamic>> get disputes;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminMarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminMarketplaceStateImplCopyWith<_$AdminMarketplaceStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminUsersState {
  List<UserEntity> get users => throw _privateConstructorUsedError;
  List<UserEntity> get bannedUsers => throw _privateConstructorUsedError;
  List<UserEntity> get admins => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminUsersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminUsersStateCopyWith<AdminUsersState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminUsersStateCopyWith<$Res> {
  factory $AdminUsersStateCopyWith(
    AdminUsersState value,
    $Res Function(AdminUsersState) then,
  ) = _$AdminUsersStateCopyWithImpl<$Res, AdminUsersState>;
  @useResult
  $Res call({
    List<UserEntity> users,
    List<UserEntity> bannedUsers,
    List<UserEntity> admins,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminUsersStateCopyWithImpl<$Res, $Val extends AdminUsersState>
    implements $AdminUsersStateCopyWith<$Res> {
  _$AdminUsersStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminUsersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? users = null,
    Object? bannedUsers = null,
    Object? admins = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            users:
                null == users
                    ? _value.users
                    : users // ignore: cast_nullable_to_non_nullable
                        as List<UserEntity>,
            bannedUsers:
                null == bannedUsers
                    ? _value.bannedUsers
                    : bannedUsers // ignore: cast_nullable_to_non_nullable
                        as List<UserEntity>,
            admins:
                null == admins
                    ? _value.admins
                    : admins // ignore: cast_nullable_to_non_nullable
                        as List<UserEntity>,
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
abstract class _$$AdminUsersStateImplCopyWith<$Res>
    implements $AdminUsersStateCopyWith<$Res> {
  factory _$$AdminUsersStateImplCopyWith(
    _$AdminUsersStateImpl value,
    $Res Function(_$AdminUsersStateImpl) then,
  ) = __$$AdminUsersStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<UserEntity> users,
    List<UserEntity> bannedUsers,
    List<UserEntity> admins,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminUsersStateImplCopyWithImpl<$Res>
    extends _$AdminUsersStateCopyWithImpl<$Res, _$AdminUsersStateImpl>
    implements _$$AdminUsersStateImplCopyWith<$Res> {
  __$$AdminUsersStateImplCopyWithImpl(
    _$AdminUsersStateImpl _value,
    $Res Function(_$AdminUsersStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminUsersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? users = null,
    Object? bannedUsers = null,
    Object? admins = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminUsersStateImpl(
        users:
            null == users
                ? _value._users
                : users // ignore: cast_nullable_to_non_nullable
                    as List<UserEntity>,
        bannedUsers:
            null == bannedUsers
                ? _value._bannedUsers
                : bannedUsers // ignore: cast_nullable_to_non_nullable
                    as List<UserEntity>,
        admins:
            null == admins
                ? _value._admins
                : admins // ignore: cast_nullable_to_non_nullable
                    as List<UserEntity>,
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

class _$AdminUsersStateImpl
    with DiagnosticableTreeMixin
    implements _AdminUsersState {
  const _$AdminUsersStateImpl({
    final List<UserEntity> users = const [],
    final List<UserEntity> bannedUsers = const [],
    final List<UserEntity> admins = const [],
    this.isLoading = false,
    this.error,
  }) : _users = users,
       _bannedUsers = bannedUsers,
       _admins = admins;

  final List<UserEntity> _users;
  @override
  @JsonKey()
  List<UserEntity> get users {
    if (_users is EqualUnmodifiableListView) return _users;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_users);
  }

  final List<UserEntity> _bannedUsers;
  @override
  @JsonKey()
  List<UserEntity> get bannedUsers {
    if (_bannedUsers is EqualUnmodifiableListView) return _bannedUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bannedUsers);
  }

  final List<UserEntity> _admins;
  @override
  @JsonKey()
  List<UserEntity> get admins {
    if (_admins is EqualUnmodifiableListView) return _admins;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_admins);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminUsersState(users: $users, bannedUsers: $bannedUsers, admins: $admins, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminUsersState'))
      ..add(DiagnosticsProperty('users', users))
      ..add(DiagnosticsProperty('bannedUsers', bannedUsers))
      ..add(DiagnosticsProperty('admins', admins))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminUsersStateImpl &&
            const DeepCollectionEquality().equals(other._users, _users) &&
            const DeepCollectionEquality().equals(
              other._bannedUsers,
              _bannedUsers,
            ) &&
            const DeepCollectionEquality().equals(other._admins, _admins) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_users),
    const DeepCollectionEquality().hash(_bannedUsers),
    const DeepCollectionEquality().hash(_admins),
    isLoading,
    error,
  );

  /// Create a copy of AdminUsersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminUsersStateImplCopyWith<_$AdminUsersStateImpl> get copyWith =>
      __$$AdminUsersStateImplCopyWithImpl<_$AdminUsersStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminUsersState implements AdminUsersState {
  const factory _AdminUsersState({
    final List<UserEntity> users,
    final List<UserEntity> bannedUsers,
    final List<UserEntity> admins,
    final bool isLoading,
    final String? error,
  }) = _$AdminUsersStateImpl;

  @override
  List<UserEntity> get users;
  @override
  List<UserEntity> get bannedUsers;
  @override
  List<UserEntity> get admins;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminUsersState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminUsersStateImplCopyWith<_$AdminUsersStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminTransactionsState {
  List<TransactionEntity> get transactions =>
      throw _privateConstructorUsedError;
  List<TransactionEntity> get pendingTransactions =>
      throw _privateConstructorUsedError;
  List<TransactionEntity> get failedTransactions =>
      throw _privateConstructorUsedError;
  double get totalVolumeUSD =>
      throw _privateConstructorUsedError; // Total converted to USD
  double get totalFeesUSD =>
      throw _privateConstructorUsedError; // Fees converted to USD
  Map<String, double> get volumeByCurrency =>
      throw _privateConstructorUsedError; // Volume per currency
  Map<String, double> get feesByCurrency =>
      throw _privateConstructorUsedError; // Fees per currency
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminTransactionsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminTransactionsStateCopyWith<AdminTransactionsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminTransactionsStateCopyWith<$Res> {
  factory $AdminTransactionsStateCopyWith(
    AdminTransactionsState value,
    $Res Function(AdminTransactionsState) then,
  ) = _$AdminTransactionsStateCopyWithImpl<$Res, AdminTransactionsState>;
  @useResult
  $Res call({
    List<TransactionEntity> transactions,
    List<TransactionEntity> pendingTransactions,
    List<TransactionEntity> failedTransactions,
    double totalVolumeUSD,
    double totalFeesUSD,
    Map<String, double> volumeByCurrency,
    Map<String, double> feesByCurrency,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class _$AdminTransactionsStateCopyWithImpl<
  $Res,
  $Val extends AdminTransactionsState
>
    implements $AdminTransactionsStateCopyWith<$Res> {
  _$AdminTransactionsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminTransactionsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactions = null,
    Object? pendingTransactions = null,
    Object? failedTransactions = null,
    Object? totalVolumeUSD = null,
    Object? totalFeesUSD = null,
    Object? volumeByCurrency = null,
    Object? feesByCurrency = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            transactions:
                null == transactions
                    ? _value.transactions
                    : transactions // ignore: cast_nullable_to_non_nullable
                        as List<TransactionEntity>,
            pendingTransactions:
                null == pendingTransactions
                    ? _value.pendingTransactions
                    : pendingTransactions // ignore: cast_nullable_to_non_nullable
                        as List<TransactionEntity>,
            failedTransactions:
                null == failedTransactions
                    ? _value.failedTransactions
                    : failedTransactions // ignore: cast_nullable_to_non_nullable
                        as List<TransactionEntity>,
            totalVolumeUSD:
                null == totalVolumeUSD
                    ? _value.totalVolumeUSD
                    : totalVolumeUSD // ignore: cast_nullable_to_non_nullable
                        as double,
            totalFeesUSD:
                null == totalFeesUSD
                    ? _value.totalFeesUSD
                    : totalFeesUSD // ignore: cast_nullable_to_non_nullable
                        as double,
            volumeByCurrency:
                null == volumeByCurrency
                    ? _value.volumeByCurrency
                    : volumeByCurrency // ignore: cast_nullable_to_non_nullable
                        as Map<String, double>,
            feesByCurrency:
                null == feesByCurrency
                    ? _value.feesByCurrency
                    : feesByCurrency // ignore: cast_nullable_to_non_nullable
                        as Map<String, double>,
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
abstract class _$$AdminTransactionsStateImplCopyWith<$Res>
    implements $AdminTransactionsStateCopyWith<$Res> {
  factory _$$AdminTransactionsStateImplCopyWith(
    _$AdminTransactionsStateImpl value,
    $Res Function(_$AdminTransactionsStateImpl) then,
  ) = __$$AdminTransactionsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<TransactionEntity> transactions,
    List<TransactionEntity> pendingTransactions,
    List<TransactionEntity> failedTransactions,
    double totalVolumeUSD,
    double totalFeesUSD,
    Map<String, double> volumeByCurrency,
    Map<String, double> feesByCurrency,
    bool isLoading,
    String? error,
  });
}

/// @nodoc
class __$$AdminTransactionsStateImplCopyWithImpl<$Res>
    extends
        _$AdminTransactionsStateCopyWithImpl<$Res, _$AdminTransactionsStateImpl>
    implements _$$AdminTransactionsStateImplCopyWith<$Res> {
  __$$AdminTransactionsStateImplCopyWithImpl(
    _$AdminTransactionsStateImpl _value,
    $Res Function(_$AdminTransactionsStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminTransactionsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactions = null,
    Object? pendingTransactions = null,
    Object? failedTransactions = null,
    Object? totalVolumeUSD = null,
    Object? totalFeesUSD = null,
    Object? volumeByCurrency = null,
    Object? feesByCurrency = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminTransactionsStateImpl(
        transactions:
            null == transactions
                ? _value._transactions
                : transactions // ignore: cast_nullable_to_non_nullable
                    as List<TransactionEntity>,
        pendingTransactions:
            null == pendingTransactions
                ? _value._pendingTransactions
                : pendingTransactions // ignore: cast_nullable_to_non_nullable
                    as List<TransactionEntity>,
        failedTransactions:
            null == failedTransactions
                ? _value._failedTransactions
                : failedTransactions // ignore: cast_nullable_to_non_nullable
                    as List<TransactionEntity>,
        totalVolumeUSD:
            null == totalVolumeUSD
                ? _value.totalVolumeUSD
                : totalVolumeUSD // ignore: cast_nullable_to_non_nullable
                    as double,
        totalFeesUSD:
            null == totalFeesUSD
                ? _value.totalFeesUSD
                : totalFeesUSD // ignore: cast_nullable_to_non_nullable
                    as double,
        volumeByCurrency:
            null == volumeByCurrency
                ? _value._volumeByCurrency
                : volumeByCurrency // ignore: cast_nullable_to_non_nullable
                    as Map<String, double>,
        feesByCurrency:
            null == feesByCurrency
                ? _value._feesByCurrency
                : feesByCurrency // ignore: cast_nullable_to_non_nullable
                    as Map<String, double>,
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

class _$AdminTransactionsStateImpl
    with DiagnosticableTreeMixin
    implements _AdminTransactionsState {
  const _$AdminTransactionsStateImpl({
    final List<TransactionEntity> transactions = const [],
    final List<TransactionEntity> pendingTransactions = const [],
    final List<TransactionEntity> failedTransactions = const [],
    this.totalVolumeUSD = 0.0,
    this.totalFeesUSD = 0.0,
    final Map<String, double> volumeByCurrency = const <String, double>{},
    final Map<String, double> feesByCurrency = const <String, double>{},
    this.isLoading = false,
    this.error,
  }) : _transactions = transactions,
       _pendingTransactions = pendingTransactions,
       _failedTransactions = failedTransactions,
       _volumeByCurrency = volumeByCurrency,
       _feesByCurrency = feesByCurrency;

  final List<TransactionEntity> _transactions;
  @override
  @JsonKey()
  List<TransactionEntity> get transactions {
    if (_transactions is EqualUnmodifiableListView) return _transactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transactions);
  }

  final List<TransactionEntity> _pendingTransactions;
  @override
  @JsonKey()
  List<TransactionEntity> get pendingTransactions {
    if (_pendingTransactions is EqualUnmodifiableListView)
      return _pendingTransactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingTransactions);
  }

  final List<TransactionEntity> _failedTransactions;
  @override
  @JsonKey()
  List<TransactionEntity> get failedTransactions {
    if (_failedTransactions is EqualUnmodifiableListView)
      return _failedTransactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_failedTransactions);
  }

  @override
  @JsonKey()
  final double totalVolumeUSD;
  // Total converted to USD
  @override
  @JsonKey()
  final double totalFeesUSD;
  // Fees converted to USD
  final Map<String, double> _volumeByCurrency;
  // Fees converted to USD
  @override
  @JsonKey()
  Map<String, double> get volumeByCurrency {
    if (_volumeByCurrency is EqualUnmodifiableMapView) return _volumeByCurrency;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_volumeByCurrency);
  }

  // Volume per currency
  final Map<String, double> _feesByCurrency;
  // Volume per currency
  @override
  @JsonKey()
  Map<String, double> get feesByCurrency {
    if (_feesByCurrency is EqualUnmodifiableMapView) return _feesByCurrency;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_feesByCurrency);
  }

  // Fees per currency
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminTransactionsState(transactions: $transactions, pendingTransactions: $pendingTransactions, failedTransactions: $failedTransactions, totalVolumeUSD: $totalVolumeUSD, totalFeesUSD: $totalFeesUSD, volumeByCurrency: $volumeByCurrency, feesByCurrency: $feesByCurrency, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminTransactionsState'))
      ..add(DiagnosticsProperty('transactions', transactions))
      ..add(DiagnosticsProperty('pendingTransactions', pendingTransactions))
      ..add(DiagnosticsProperty('failedTransactions', failedTransactions))
      ..add(DiagnosticsProperty('totalVolumeUSD', totalVolumeUSD))
      ..add(DiagnosticsProperty('totalFeesUSD', totalFeesUSD))
      ..add(DiagnosticsProperty('volumeByCurrency', volumeByCurrency))
      ..add(DiagnosticsProperty('feesByCurrency', feesByCurrency))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminTransactionsStateImpl &&
            const DeepCollectionEquality().equals(
              other._transactions,
              _transactions,
            ) &&
            const DeepCollectionEquality().equals(
              other._pendingTransactions,
              _pendingTransactions,
            ) &&
            const DeepCollectionEquality().equals(
              other._failedTransactions,
              _failedTransactions,
            ) &&
            (identical(other.totalVolumeUSD, totalVolumeUSD) ||
                other.totalVolumeUSD == totalVolumeUSD) &&
            (identical(other.totalFeesUSD, totalFeesUSD) ||
                other.totalFeesUSD == totalFeesUSD) &&
            const DeepCollectionEquality().equals(
              other._volumeByCurrency,
              _volumeByCurrency,
            ) &&
            const DeepCollectionEquality().equals(
              other._feesByCurrency,
              _feesByCurrency,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_transactions),
    const DeepCollectionEquality().hash(_pendingTransactions),
    const DeepCollectionEquality().hash(_failedTransactions),
    totalVolumeUSD,
    totalFeesUSD,
    const DeepCollectionEquality().hash(_volumeByCurrency),
    const DeepCollectionEquality().hash(_feesByCurrency),
    isLoading,
    error,
  );

  /// Create a copy of AdminTransactionsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminTransactionsStateImplCopyWith<_$AdminTransactionsStateImpl>
  get copyWith =>
      __$$AdminTransactionsStateImplCopyWithImpl<_$AdminTransactionsStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminTransactionsState implements AdminTransactionsState {
  const factory _AdminTransactionsState({
    final List<TransactionEntity> transactions,
    final List<TransactionEntity> pendingTransactions,
    final List<TransactionEntity> failedTransactions,
    final double totalVolumeUSD,
    final double totalFeesUSD,
    final Map<String, double> volumeByCurrency,
    final Map<String, double> feesByCurrency,
    final bool isLoading,
    final String? error,
  }) = _$AdminTransactionsStateImpl;

  @override
  List<TransactionEntity> get transactions;
  @override
  List<TransactionEntity> get pendingTransactions;
  @override
  List<TransactionEntity> get failedTransactions;
  @override
  double get totalVolumeUSD; // Total converted to USD
  @override
  double get totalFeesUSD; // Fees converted to USD
  @override
  Map<String, double> get volumeByCurrency; // Volume per currency
  @override
  Map<String, double> get feesByCurrency; // Fees per currency
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminTransactionsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminTransactionsStateImplCopyWith<_$AdminTransactionsStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AnalyticsData {
  Map<String, int> get userGrowth => throw _privateConstructorUsedError;
  Map<String, int> get eventsByCategory => throw _privateConstructorUsedError;
  Map<String, int> get businessesByCategory =>
      throw _privateConstructorUsedError;
  Map<String, double> get transactionVolume =>
      throw _privateConstructorUsedError;
  Map<String, int> get activeUsersByDay => throw _privateConstructorUsedError;
  int get newUsersToday => throw _privateConstructorUsedError;
  int get newUsersThisWeek => throw _privateConstructorUsedError;
  int get newUsersThisMonth => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsDataCopyWith<AnalyticsData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsDataCopyWith<$Res> {
  factory $AnalyticsDataCopyWith(
    AnalyticsData value,
    $Res Function(AnalyticsData) then,
  ) = _$AnalyticsDataCopyWithImpl<$Res, AnalyticsData>;
  @useResult
  $Res call({
    Map<String, int> userGrowth,
    Map<String, int> eventsByCategory,
    Map<String, int> businessesByCategory,
    Map<String, double> transactionVolume,
    Map<String, int> activeUsersByDay,
    int newUsersToday,
    int newUsersThisWeek,
    int newUsersThisMonth,
  });
}

/// @nodoc
class _$AnalyticsDataCopyWithImpl<$Res, $Val extends AnalyticsData>
    implements $AnalyticsDataCopyWith<$Res> {
  _$AnalyticsDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userGrowth = null,
    Object? eventsByCategory = null,
    Object? businessesByCategory = null,
    Object? transactionVolume = null,
    Object? activeUsersByDay = null,
    Object? newUsersToday = null,
    Object? newUsersThisWeek = null,
    Object? newUsersThisMonth = null,
  }) {
    return _then(
      _value.copyWith(
            userGrowth:
                null == userGrowth
                    ? _value.userGrowth
                    : userGrowth // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>,
            eventsByCategory:
                null == eventsByCategory
                    ? _value.eventsByCategory
                    : eventsByCategory // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>,
            businessesByCategory:
                null == businessesByCategory
                    ? _value.businessesByCategory
                    : businessesByCategory // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>,
            transactionVolume:
                null == transactionVolume
                    ? _value.transactionVolume
                    : transactionVolume // ignore: cast_nullable_to_non_nullable
                        as Map<String, double>,
            activeUsersByDay:
                null == activeUsersByDay
                    ? _value.activeUsersByDay
                    : activeUsersByDay // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>,
            newUsersToday:
                null == newUsersToday
                    ? _value.newUsersToday
                    : newUsersToday // ignore: cast_nullable_to_non_nullable
                        as int,
            newUsersThisWeek:
                null == newUsersThisWeek
                    ? _value.newUsersThisWeek
                    : newUsersThisWeek // ignore: cast_nullable_to_non_nullable
                        as int,
            newUsersThisMonth:
                null == newUsersThisMonth
                    ? _value.newUsersThisMonth
                    : newUsersThisMonth // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnalyticsDataImplCopyWith<$Res>
    implements $AnalyticsDataCopyWith<$Res> {
  factory _$$AnalyticsDataImplCopyWith(
    _$AnalyticsDataImpl value,
    $Res Function(_$AnalyticsDataImpl) then,
  ) = __$$AnalyticsDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Map<String, int> userGrowth,
    Map<String, int> eventsByCategory,
    Map<String, int> businessesByCategory,
    Map<String, double> transactionVolume,
    Map<String, int> activeUsersByDay,
    int newUsersToday,
    int newUsersThisWeek,
    int newUsersThisMonth,
  });
}

/// @nodoc
class __$$AnalyticsDataImplCopyWithImpl<$Res>
    extends _$AnalyticsDataCopyWithImpl<$Res, _$AnalyticsDataImpl>
    implements _$$AnalyticsDataImplCopyWith<$Res> {
  __$$AnalyticsDataImplCopyWithImpl(
    _$AnalyticsDataImpl _value,
    $Res Function(_$AnalyticsDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userGrowth = null,
    Object? eventsByCategory = null,
    Object? businessesByCategory = null,
    Object? transactionVolume = null,
    Object? activeUsersByDay = null,
    Object? newUsersToday = null,
    Object? newUsersThisWeek = null,
    Object? newUsersThisMonth = null,
  }) {
    return _then(
      _$AnalyticsDataImpl(
        userGrowth:
            null == userGrowth
                ? _value._userGrowth
                : userGrowth // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>,
        eventsByCategory:
            null == eventsByCategory
                ? _value._eventsByCategory
                : eventsByCategory // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>,
        businessesByCategory:
            null == businessesByCategory
                ? _value._businessesByCategory
                : businessesByCategory // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>,
        transactionVolume:
            null == transactionVolume
                ? _value._transactionVolume
                : transactionVolume // ignore: cast_nullable_to_non_nullable
                    as Map<String, double>,
        activeUsersByDay:
            null == activeUsersByDay
                ? _value._activeUsersByDay
                : activeUsersByDay // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>,
        newUsersToday:
            null == newUsersToday
                ? _value.newUsersToday
                : newUsersToday // ignore: cast_nullable_to_non_nullable
                    as int,
        newUsersThisWeek:
            null == newUsersThisWeek
                ? _value.newUsersThisWeek
                : newUsersThisWeek // ignore: cast_nullable_to_non_nullable
                    as int,
        newUsersThisMonth:
            null == newUsersThisMonth
                ? _value.newUsersThisMonth
                : newUsersThisMonth // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$AnalyticsDataImpl
    with DiagnosticableTreeMixin
    implements _AnalyticsData {
  const _$AnalyticsDataImpl({
    final Map<String, int> userGrowth = const {},
    final Map<String, int> eventsByCategory = const {},
    final Map<String, int> businessesByCategory = const {},
    final Map<String, double> transactionVolume = const {},
    final Map<String, int> activeUsersByDay = const {},
    this.newUsersToday = 0,
    this.newUsersThisWeek = 0,
    this.newUsersThisMonth = 0,
  }) : _userGrowth = userGrowth,
       _eventsByCategory = eventsByCategory,
       _businessesByCategory = businessesByCategory,
       _transactionVolume = transactionVolume,
       _activeUsersByDay = activeUsersByDay;

  final Map<String, int> _userGrowth;
  @override
  @JsonKey()
  Map<String, int> get userGrowth {
    if (_userGrowth is EqualUnmodifiableMapView) return _userGrowth;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userGrowth);
  }

  final Map<String, int> _eventsByCategory;
  @override
  @JsonKey()
  Map<String, int> get eventsByCategory {
    if (_eventsByCategory is EqualUnmodifiableMapView) return _eventsByCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_eventsByCategory);
  }

  final Map<String, int> _businessesByCategory;
  @override
  @JsonKey()
  Map<String, int> get businessesByCategory {
    if (_businessesByCategory is EqualUnmodifiableMapView)
      return _businessesByCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_businessesByCategory);
  }

  final Map<String, double> _transactionVolume;
  @override
  @JsonKey()
  Map<String, double> get transactionVolume {
    if (_transactionVolume is EqualUnmodifiableMapView)
      return _transactionVolume;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_transactionVolume);
  }

  final Map<String, int> _activeUsersByDay;
  @override
  @JsonKey()
  Map<String, int> get activeUsersByDay {
    if (_activeUsersByDay is EqualUnmodifiableMapView) return _activeUsersByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_activeUsersByDay);
  }

  @override
  @JsonKey()
  final int newUsersToday;
  @override
  @JsonKey()
  final int newUsersThisWeek;
  @override
  @JsonKey()
  final int newUsersThisMonth;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AnalyticsData(userGrowth: $userGrowth, eventsByCategory: $eventsByCategory, businessesByCategory: $businessesByCategory, transactionVolume: $transactionVolume, activeUsersByDay: $activeUsersByDay, newUsersToday: $newUsersToday, newUsersThisWeek: $newUsersThisWeek, newUsersThisMonth: $newUsersThisMonth)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AnalyticsData'))
      ..add(DiagnosticsProperty('userGrowth', userGrowth))
      ..add(DiagnosticsProperty('eventsByCategory', eventsByCategory))
      ..add(DiagnosticsProperty('businessesByCategory', businessesByCategory))
      ..add(DiagnosticsProperty('transactionVolume', transactionVolume))
      ..add(DiagnosticsProperty('activeUsersByDay', activeUsersByDay))
      ..add(DiagnosticsProperty('newUsersToday', newUsersToday))
      ..add(DiagnosticsProperty('newUsersThisWeek', newUsersThisWeek))
      ..add(DiagnosticsProperty('newUsersThisMonth', newUsersThisMonth));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsDataImpl &&
            const DeepCollectionEquality().equals(
              other._userGrowth,
              _userGrowth,
            ) &&
            const DeepCollectionEquality().equals(
              other._eventsByCategory,
              _eventsByCategory,
            ) &&
            const DeepCollectionEquality().equals(
              other._businessesByCategory,
              _businessesByCategory,
            ) &&
            const DeepCollectionEquality().equals(
              other._transactionVolume,
              _transactionVolume,
            ) &&
            const DeepCollectionEquality().equals(
              other._activeUsersByDay,
              _activeUsersByDay,
            ) &&
            (identical(other.newUsersToday, newUsersToday) ||
                other.newUsersToday == newUsersToday) &&
            (identical(other.newUsersThisWeek, newUsersThisWeek) ||
                other.newUsersThisWeek == newUsersThisWeek) &&
            (identical(other.newUsersThisMonth, newUsersThisMonth) ||
                other.newUsersThisMonth == newUsersThisMonth));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_userGrowth),
    const DeepCollectionEquality().hash(_eventsByCategory),
    const DeepCollectionEquality().hash(_businessesByCategory),
    const DeepCollectionEquality().hash(_transactionVolume),
    const DeepCollectionEquality().hash(_activeUsersByDay),
    newUsersToday,
    newUsersThisWeek,
    newUsersThisMonth,
  );

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      __$$AnalyticsDataImplCopyWithImpl<_$AnalyticsDataImpl>(this, _$identity);
}

abstract class _AnalyticsData implements AnalyticsData {
  const factory _AnalyticsData({
    final Map<String, int> userGrowth,
    final Map<String, int> eventsByCategory,
    final Map<String, int> businessesByCategory,
    final Map<String, double> transactionVolume,
    final Map<String, int> activeUsersByDay,
    final int newUsersToday,
    final int newUsersThisWeek,
    final int newUsersThisMonth,
  }) = _$AnalyticsDataImpl;

  @override
  Map<String, int> get userGrowth;
  @override
  Map<String, int> get eventsByCategory;
  @override
  Map<String, int> get businessesByCategory;
  @override
  Map<String, double> get transactionVolume;
  @override
  Map<String, int> get activeUsersByDay;
  @override
  int get newUsersToday;
  @override
  int get newUsersThisWeek;
  @override
  int get newUsersThisMonth;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminAnalyticsState {
  AnalyticsData get data => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminAnalyticsStateCopyWith<AdminAnalyticsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminAnalyticsStateCopyWith<$Res> {
  factory $AdminAnalyticsStateCopyWith(
    AdminAnalyticsState value,
    $Res Function(AdminAnalyticsState) then,
  ) = _$AdminAnalyticsStateCopyWithImpl<$Res, AdminAnalyticsState>;
  @useResult
  $Res call({AnalyticsData data, bool isLoading, String? error});

  $AnalyticsDataCopyWith<$Res> get data;
}

/// @nodoc
class _$AdminAnalyticsStateCopyWithImpl<$Res, $Val extends AdminAnalyticsState>
    implements $AdminAnalyticsStateCopyWith<$Res> {
  _$AdminAnalyticsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            data:
                null == data
                    ? _value.data
                    : data // ignore: cast_nullable_to_non_nullable
                        as AnalyticsData,
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

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnalyticsDataCopyWith<$Res> get data {
    return $AnalyticsDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AdminAnalyticsStateImplCopyWith<$Res>
    implements $AdminAnalyticsStateCopyWith<$Res> {
  factory _$$AdminAnalyticsStateImplCopyWith(
    _$AdminAnalyticsStateImpl value,
    $Res Function(_$AdminAnalyticsStateImpl) then,
  ) = __$$AdminAnalyticsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({AnalyticsData data, bool isLoading, String? error});

  @override
  $AnalyticsDataCopyWith<$Res> get data;
}

/// @nodoc
class __$$AdminAnalyticsStateImplCopyWithImpl<$Res>
    extends _$AdminAnalyticsStateCopyWithImpl<$Res, _$AdminAnalyticsStateImpl>
    implements _$$AdminAnalyticsStateImplCopyWith<$Res> {
  __$$AdminAnalyticsStateImplCopyWithImpl(
    _$AdminAnalyticsStateImpl _value,
    $Res Function(_$AdminAnalyticsStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminAnalyticsStateImpl(
        data:
            null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                    as AnalyticsData,
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

class _$AdminAnalyticsStateImpl
    with DiagnosticableTreeMixin
    implements _AdminAnalyticsState {
  const _$AdminAnalyticsStateImpl({
    this.data = const AnalyticsData(),
    this.isLoading = false,
    this.error,
  });

  @override
  @JsonKey()
  final AnalyticsData data;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminAnalyticsState(data: $data, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminAnalyticsState'))
      ..add(DiagnosticsProperty('data', data))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminAnalyticsStateImpl &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, data, isLoading, error);

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminAnalyticsStateImplCopyWith<_$AdminAnalyticsStateImpl> get copyWith =>
      __$$AdminAnalyticsStateImplCopyWithImpl<_$AdminAnalyticsStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminAnalyticsState implements AdminAnalyticsState {
  const factory _AdminAnalyticsState({
    final AnalyticsData data,
    final bool isLoading,
    final String? error,
  }) = _$AdminAnalyticsStateImpl;

  @override
  AnalyticsData get data;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminAnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminAnalyticsStateImplCopyWith<_$AdminAnalyticsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminNotificationState {
  List<Map<String, dynamic>> get sentNotifications =>
      throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isSending => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  String? get successMessage => throw _privateConstructorUsedError;

  /// Create a copy of AdminNotificationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminNotificationStateCopyWith<AdminNotificationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminNotificationStateCopyWith<$Res> {
  factory $AdminNotificationStateCopyWith(
    AdminNotificationState value,
    $Res Function(AdminNotificationState) then,
  ) = _$AdminNotificationStateCopyWithImpl<$Res, AdminNotificationState>;
  @useResult
  $Res call({
    List<Map<String, dynamic>> sentNotifications,
    bool isLoading,
    bool isSending,
    String? error,
    String? successMessage,
  });
}

/// @nodoc
class _$AdminNotificationStateCopyWithImpl<
  $Res,
  $Val extends AdminNotificationState
>
    implements $AdminNotificationStateCopyWith<$Res> {
  _$AdminNotificationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminNotificationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sentNotifications = null,
    Object? isLoading = null,
    Object? isSending = null,
    Object? error = freezed,
    Object? successMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            sentNotifications:
                null == sentNotifications
                    ? _value.sentNotifications
                    : sentNotifications // ignore: cast_nullable_to_non_nullable
                        as List<Map<String, dynamic>>,
            isLoading:
                null == isLoading
                    ? _value.isLoading
                    : isLoading // ignore: cast_nullable_to_non_nullable
                        as bool,
            isSending:
                null == isSending
                    ? _value.isSending
                    : isSending // ignore: cast_nullable_to_non_nullable
                        as bool,
            error:
                freezed == error
                    ? _value.error
                    : error // ignore: cast_nullable_to_non_nullable
                        as String?,
            successMessage:
                freezed == successMessage
                    ? _value.successMessage
                    : successMessage // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminNotificationStateImplCopyWith<$Res>
    implements $AdminNotificationStateCopyWith<$Res> {
  factory _$$AdminNotificationStateImplCopyWith(
    _$AdminNotificationStateImpl value,
    $Res Function(_$AdminNotificationStateImpl) then,
  ) = __$$AdminNotificationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Map<String, dynamic>> sentNotifications,
    bool isLoading,
    bool isSending,
    String? error,
    String? successMessage,
  });
}

/// @nodoc
class __$$AdminNotificationStateImplCopyWithImpl<$Res>
    extends
        _$AdminNotificationStateCopyWithImpl<$Res, _$AdminNotificationStateImpl>
    implements _$$AdminNotificationStateImplCopyWith<$Res> {
  __$$AdminNotificationStateImplCopyWithImpl(
    _$AdminNotificationStateImpl _value,
    $Res Function(_$AdminNotificationStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminNotificationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sentNotifications = null,
    Object? isLoading = null,
    Object? isSending = null,
    Object? error = freezed,
    Object? successMessage = freezed,
  }) {
    return _then(
      _$AdminNotificationStateImpl(
        sentNotifications:
            null == sentNotifications
                ? _value._sentNotifications
                : sentNotifications // ignore: cast_nullable_to_non_nullable
                    as List<Map<String, dynamic>>,
        isLoading:
            null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                    as bool,
        isSending:
            null == isSending
                ? _value.isSending
                : isSending // ignore: cast_nullable_to_non_nullable
                    as bool,
        error:
            freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                    as String?,
        successMessage:
            freezed == successMessage
                ? _value.successMessage
                : successMessage // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$AdminNotificationStateImpl
    with DiagnosticableTreeMixin
    implements _AdminNotificationState {
  const _$AdminNotificationStateImpl({
    final List<Map<String, dynamic>> sentNotifications = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.successMessage,
  }) : _sentNotifications = sentNotifications;

  final List<Map<String, dynamic>> _sentNotifications;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get sentNotifications {
    if (_sentNotifications is EqualUnmodifiableListView)
      return _sentNotifications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sentNotifications);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isSending;
  @override
  final String? error;
  @override
  final String? successMessage;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminNotificationState(sentNotifications: $sentNotifications, isLoading: $isLoading, isSending: $isSending, error: $error, successMessage: $successMessage)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminNotificationState'))
      ..add(DiagnosticsProperty('sentNotifications', sentNotifications))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('isSending', isSending))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('successMessage', successMessage));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminNotificationStateImpl &&
            const DeepCollectionEquality().equals(
              other._sentNotifications,
              _sentNotifications,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSending, isSending) ||
                other.isSending == isSending) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.successMessage, successMessage) ||
                other.successMessage == successMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_sentNotifications),
    isLoading,
    isSending,
    error,
    successMessage,
  );

  /// Create a copy of AdminNotificationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminNotificationStateImplCopyWith<_$AdminNotificationStateImpl>
  get copyWith =>
      __$$AdminNotificationStateImplCopyWithImpl<_$AdminNotificationStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminNotificationState implements AdminNotificationState {
  const factory _AdminNotificationState({
    final List<Map<String, dynamic>> sentNotifications,
    final bool isLoading,
    final bool isSending,
    final String? error,
    final String? successMessage,
  }) = _$AdminNotificationStateImpl;

  @override
  List<Map<String, dynamic>> get sentNotifications;
  @override
  bool get isLoading;
  @override
  bool get isSending;
  @override
  String? get error;
  @override
  String? get successMessage;

  /// Create a copy of AdminNotificationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminNotificationStateImplCopyWith<_$AdminNotificationStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AuditLogEntry {
  String get id => throw _privateConstructorUsedError;
  String get adminId => throw _privateConstructorUsedError;
  String? get adminName => throw _privateConstructorUsedError;
  String get action => throw _privateConstructorUsedError;
  String get targetType => throw _privateConstructorUsedError;
  String? get targetId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get details => throw _privateConstructorUsedError;
  DateTime? get timestamp => throw _privateConstructorUsedError;

  /// Create a copy of AuditLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuditLogEntryCopyWith<AuditLogEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuditLogEntryCopyWith<$Res> {
  factory $AuditLogEntryCopyWith(
    AuditLogEntry value,
    $Res Function(AuditLogEntry) then,
  ) = _$AuditLogEntryCopyWithImpl<$Res, AuditLogEntry>;
  @useResult
  $Res call({
    String id,
    String adminId,
    String? adminName,
    String action,
    String targetType,
    String? targetId,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  });
}

/// @nodoc
class _$AuditLogEntryCopyWithImpl<$Res, $Val extends AuditLogEntry>
    implements $AuditLogEntryCopyWith<$Res> {
  _$AuditLogEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuditLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? adminId = null,
    Object? adminName = freezed,
    Object? action = null,
    Object? targetType = null,
    Object? targetId = freezed,
    Object? details = freezed,
    Object? timestamp = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            adminId:
                null == adminId
                    ? _value.adminId
                    : adminId // ignore: cast_nullable_to_non_nullable
                        as String,
            adminName:
                freezed == adminName
                    ? _value.adminName
                    : adminName // ignore: cast_nullable_to_non_nullable
                        as String?,
            action:
                null == action
                    ? _value.action
                    : action // ignore: cast_nullable_to_non_nullable
                        as String,
            targetType:
                null == targetType
                    ? _value.targetType
                    : targetType // ignore: cast_nullable_to_non_nullable
                        as String,
            targetId:
                freezed == targetId
                    ? _value.targetId
                    : targetId // ignore: cast_nullable_to_non_nullable
                        as String?,
            details:
                freezed == details
                    ? _value.details
                    : details // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            timestamp:
                freezed == timestamp
                    ? _value.timestamp
                    : timestamp // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AuditLogEntryImplCopyWith<$Res>
    implements $AuditLogEntryCopyWith<$Res> {
  factory _$$AuditLogEntryImplCopyWith(
    _$AuditLogEntryImpl value,
    $Res Function(_$AuditLogEntryImpl) then,
  ) = __$$AuditLogEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String adminId,
    String? adminName,
    String action,
    String targetType,
    String? targetId,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  });
}

/// @nodoc
class __$$AuditLogEntryImplCopyWithImpl<$Res>
    extends _$AuditLogEntryCopyWithImpl<$Res, _$AuditLogEntryImpl>
    implements _$$AuditLogEntryImplCopyWith<$Res> {
  __$$AuditLogEntryImplCopyWithImpl(
    _$AuditLogEntryImpl _value,
    $Res Function(_$AuditLogEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuditLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? adminId = null,
    Object? adminName = freezed,
    Object? action = null,
    Object? targetType = null,
    Object? targetId = freezed,
    Object? details = freezed,
    Object? timestamp = freezed,
  }) {
    return _then(
      _$AuditLogEntryImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        adminId:
            null == adminId
                ? _value.adminId
                : adminId // ignore: cast_nullable_to_non_nullable
                    as String,
        adminName:
            freezed == adminName
                ? _value.adminName
                : adminName // ignore: cast_nullable_to_non_nullable
                    as String?,
        action:
            null == action
                ? _value.action
                : action // ignore: cast_nullable_to_non_nullable
                    as String,
        targetType:
            null == targetType
                ? _value.targetType
                : targetType // ignore: cast_nullable_to_non_nullable
                    as String,
        targetId:
            freezed == targetId
                ? _value.targetId
                : targetId // ignore: cast_nullable_to_non_nullable
                    as String?,
        details:
            freezed == details
                ? _value._details
                : details // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        timestamp:
            freezed == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$AuditLogEntryImpl
    with DiagnosticableTreeMixin
    implements _AuditLogEntry {
  const _$AuditLogEntryImpl({
    required this.id,
    required this.adminId,
    this.adminName,
    required this.action,
    required this.targetType,
    this.targetId,
    final Map<String, dynamic>? details,
    this.timestamp,
  }) : _details = details;

  @override
  final String id;
  @override
  final String adminId;
  @override
  final String? adminName;
  @override
  final String action;
  @override
  final String targetType;
  @override
  final String? targetId;
  final Map<String, dynamic>? _details;
  @override
  Map<String, dynamic>? get details {
    final value = _details;
    if (value == null) return null;
    if (_details is EqualUnmodifiableMapView) return _details;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime? timestamp;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AuditLogEntry(id: $id, adminId: $adminId, adminName: $adminName, action: $action, targetType: $targetType, targetId: $targetId, details: $details, timestamp: $timestamp)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AuditLogEntry'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('adminId', adminId))
      ..add(DiagnosticsProperty('adminName', adminName))
      ..add(DiagnosticsProperty('action', action))
      ..add(DiagnosticsProperty('targetType', targetType))
      ..add(DiagnosticsProperty('targetId', targetId))
      ..add(DiagnosticsProperty('details', details))
      ..add(DiagnosticsProperty('timestamp', timestamp));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuditLogEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.adminId, adminId) || other.adminId == adminId) &&
            (identical(other.adminName, adminName) ||
                other.adminName == adminName) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.targetType, targetType) ||
                other.targetType == targetType) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            const DeepCollectionEquality().equals(other._details, _details) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    adminId,
    adminName,
    action,
    targetType,
    targetId,
    const DeepCollectionEquality().hash(_details),
    timestamp,
  );

  /// Create a copy of AuditLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuditLogEntryImplCopyWith<_$AuditLogEntryImpl> get copyWith =>
      __$$AuditLogEntryImplCopyWithImpl<_$AuditLogEntryImpl>(this, _$identity);
}

abstract class _AuditLogEntry implements AuditLogEntry {
  const factory _AuditLogEntry({
    required final String id,
    required final String adminId,
    final String? adminName,
    required final String action,
    required final String targetType,
    final String? targetId,
    final Map<String, dynamic>? details,
    final DateTime? timestamp,
  }) = _$AuditLogEntryImpl;

  @override
  String get id;
  @override
  String get adminId;
  @override
  String? get adminName;
  @override
  String get action;
  @override
  String get targetType;
  @override
  String? get targetId;
  @override
  Map<String, dynamic>? get details;
  @override
  DateTime? get timestamp;

  /// Create a copy of AuditLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuditLogEntryImplCopyWith<_$AuditLogEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AdminAuditState {
  List<AuditLogEntry> get logs => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AdminAuditState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminAuditStateCopyWith<AdminAuditState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminAuditStateCopyWith<$Res> {
  factory $AdminAuditStateCopyWith(
    AdminAuditState value,
    $Res Function(AdminAuditState) then,
  ) = _$AdminAuditStateCopyWithImpl<$Res, AdminAuditState>;
  @useResult
  $Res call({List<AuditLogEntry> logs, bool isLoading, String? error});
}

/// @nodoc
class _$AdminAuditStateCopyWithImpl<$Res, $Val extends AdminAuditState>
    implements $AdminAuditStateCopyWith<$Res> {
  _$AdminAuditStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminAuditState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? logs = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            logs:
                null == logs
                    ? _value.logs
                    : logs // ignore: cast_nullable_to_non_nullable
                        as List<AuditLogEntry>,
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
abstract class _$$AdminAuditStateImplCopyWith<$Res>
    implements $AdminAuditStateCopyWith<$Res> {
  factory _$$AdminAuditStateImplCopyWith(
    _$AdminAuditStateImpl value,
    $Res Function(_$AdminAuditStateImpl) then,
  ) = __$$AdminAuditStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AuditLogEntry> logs, bool isLoading, String? error});
}

/// @nodoc
class __$$AdminAuditStateImplCopyWithImpl<$Res>
    extends _$AdminAuditStateCopyWithImpl<$Res, _$AdminAuditStateImpl>
    implements _$$AdminAuditStateImplCopyWith<$Res> {
  __$$AdminAuditStateImplCopyWithImpl(
    _$AdminAuditStateImpl _value,
    $Res Function(_$AdminAuditStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminAuditState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? logs = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$AdminAuditStateImpl(
        logs:
            null == logs
                ? _value._logs
                : logs // ignore: cast_nullable_to_non_nullable
                    as List<AuditLogEntry>,
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

class _$AdminAuditStateImpl
    with DiagnosticableTreeMixin
    implements _AdminAuditState {
  const _$AdminAuditStateImpl({
    final List<AuditLogEntry> logs = const [],
    this.isLoading = false,
    this.error,
  }) : _logs = logs;

  final List<AuditLogEntry> _logs;
  @override
  @JsonKey()
  List<AuditLogEntry> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminAuditState(logs: $logs, isLoading: $isLoading, error: $error)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminAuditState'))
      ..add(DiagnosticsProperty('logs', logs))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminAuditStateImpl &&
            const DeepCollectionEquality().equals(other._logs, _logs) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_logs),
    isLoading,
    error,
  );

  /// Create a copy of AdminAuditState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminAuditStateImplCopyWith<_$AdminAuditStateImpl> get copyWith =>
      __$$AdminAuditStateImplCopyWithImpl<_$AdminAuditStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AdminAuditState implements AdminAuditState {
  const factory _AdminAuditState({
    final List<AuditLogEntry> logs,
    final bool isLoading,
    final String? error,
  }) = _$AdminAuditStateImpl;

  @override
  List<AuditLogEntry> get logs;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of AdminAuditState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminAuditStateImplCopyWith<_$AdminAuditStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
