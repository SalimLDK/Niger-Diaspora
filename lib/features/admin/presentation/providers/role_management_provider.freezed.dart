// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'role_management_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AdminUser {
  String get id => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  AdminRole get adminRole => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get lastLoginAt => throw _privateConstructorUsedError;

  /// Create a copy of AdminUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminUserCopyWith<AdminUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminUserCopyWith<$Res> {
  factory $AdminUserCopyWith(AdminUser value, $Res Function(AdminUser) then) =
      _$AdminUserCopyWithImpl<$Res, AdminUser>;
  @useResult
  $Res call({
    String id,
    String? email,
    String? displayName,
    String? photoUrl,
    AdminRole adminRole,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  });
}

/// @nodoc
class _$AdminUserCopyWithImpl<$Res, $Val extends AdminUser>
    implements $AdminUserCopyWith<$Res> {
  _$AdminUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? adminRole = null,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            displayName:
                freezed == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String?,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            adminRole:
                null == adminRole
                    ? _value.adminRole
                    : adminRole // ignore: cast_nullable_to_non_nullable
                        as AdminRole,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            lastLoginAt:
                freezed == lastLoginAt
                    ? _value.lastLoginAt
                    : lastLoginAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminUserImplCopyWith<$Res>
    implements $AdminUserCopyWith<$Res> {
  factory _$$AdminUserImplCopyWith(
    _$AdminUserImpl value,
    $Res Function(_$AdminUserImpl) then,
  ) = __$$AdminUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? email,
    String? displayName,
    String? photoUrl,
    AdminRole adminRole,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  });
}

/// @nodoc
class __$$AdminUserImplCopyWithImpl<$Res>
    extends _$AdminUserCopyWithImpl<$Res, _$AdminUserImpl>
    implements _$$AdminUserImplCopyWith<$Res> {
  __$$AdminUserImplCopyWithImpl(
    _$AdminUserImpl _value,
    $Res Function(_$AdminUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? adminRole = null,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
  }) {
    return _then(
      _$AdminUserImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        displayName:
            freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String?,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        adminRole:
            null == adminRole
                ? _value.adminRole
                : adminRole // ignore: cast_nullable_to_non_nullable
                    as AdminRole,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        lastLoginAt:
            freezed == lastLoginAt
                ? _value.lastLoginAt
                : lastLoginAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$AdminUserImpl with DiagnosticableTreeMixin implements _AdminUser {
  const _$AdminUserImpl({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.adminRole,
    this.createdAt,
    this.lastLoginAt,
  });

  @override
  final String id;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoUrl;
  @override
  final AdminRole adminRole;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? lastLoginAt;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'AdminUser(id: $id, email: $email, displayName: $displayName, photoUrl: $photoUrl, adminRole: $adminRole, createdAt: $createdAt, lastLoginAt: $lastLoginAt)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'AdminUser'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('email', email))
      ..add(DiagnosticsProperty('displayName', displayName))
      ..add(DiagnosticsProperty('photoUrl', photoUrl))
      ..add(DiagnosticsProperty('adminRole', adminRole))
      ..add(DiagnosticsProperty('createdAt', createdAt))
      ..add(DiagnosticsProperty('lastLoginAt', lastLoginAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.adminRole, adminRole) ||
                other.adminRole == adminRole) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastLoginAt, lastLoginAt) ||
                other.lastLoginAt == lastLoginAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    displayName,
    photoUrl,
    adminRole,
    createdAt,
    lastLoginAt,
  );

  /// Create a copy of AdminUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminUserImplCopyWith<_$AdminUserImpl> get copyWith =>
      __$$AdminUserImplCopyWithImpl<_$AdminUserImpl>(this, _$identity);
}

abstract class _AdminUser implements AdminUser {
  const factory _AdminUser({
    required final String id,
    final String? email,
    final String? displayName,
    final String? photoUrl,
    required final AdminRole adminRole,
    final DateTime? createdAt,
    final DateTime? lastLoginAt,
  }) = _$AdminUserImpl;

  @override
  String get id;
  @override
  String? get email;
  @override
  String? get displayName;
  @override
  String? get photoUrl;
  @override
  AdminRole get adminRole;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get lastLoginAt;

  /// Create a copy of AdminUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminUserImplCopyWith<_$AdminUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RoleManagementState {
  List<AdminUser> get admins => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  String? get successMessage => throw _privateConstructorUsedError;

  /// Create a copy of RoleManagementState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoleManagementStateCopyWith<RoleManagementState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoleManagementStateCopyWith<$Res> {
  factory $RoleManagementStateCopyWith(
    RoleManagementState value,
    $Res Function(RoleManagementState) then,
  ) = _$RoleManagementStateCopyWithImpl<$Res, RoleManagementState>;
  @useResult
  $Res call({
    List<AdminUser> admins,
    bool isLoading,
    String? error,
    String? successMessage,
  });
}

/// @nodoc
class _$RoleManagementStateCopyWithImpl<$Res, $Val extends RoleManagementState>
    implements $RoleManagementStateCopyWith<$Res> {
  _$RoleManagementStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoleManagementState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? admins = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? successMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            admins:
                null == admins
                    ? _value.admins
                    : admins // ignore: cast_nullable_to_non_nullable
                        as List<AdminUser>,
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
abstract class _$$RoleManagementStateImplCopyWith<$Res>
    implements $RoleManagementStateCopyWith<$Res> {
  factory _$$RoleManagementStateImplCopyWith(
    _$RoleManagementStateImpl value,
    $Res Function(_$RoleManagementStateImpl) then,
  ) = __$$RoleManagementStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<AdminUser> admins,
    bool isLoading,
    String? error,
    String? successMessage,
  });
}

/// @nodoc
class __$$RoleManagementStateImplCopyWithImpl<$Res>
    extends _$RoleManagementStateCopyWithImpl<$Res, _$RoleManagementStateImpl>
    implements _$$RoleManagementStateImplCopyWith<$Res> {
  __$$RoleManagementStateImplCopyWithImpl(
    _$RoleManagementStateImpl _value,
    $Res Function(_$RoleManagementStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoleManagementState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? admins = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? successMessage = freezed,
  }) {
    return _then(
      _$RoleManagementStateImpl(
        admins:
            null == admins
                ? _value._admins
                : admins // ignore: cast_nullable_to_non_nullable
                    as List<AdminUser>,
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

class _$RoleManagementStateImpl
    with DiagnosticableTreeMixin
    implements _RoleManagementState {
  const _$RoleManagementStateImpl({
    final List<AdminUser> admins = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  }) : _admins = admins;

  final List<AdminUser> _admins;
  @override
  @JsonKey()
  List<AdminUser> get admins {
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
  final String? successMessage;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'RoleManagementState(admins: $admins, isLoading: $isLoading, error: $error, successMessage: $successMessage)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'RoleManagementState'))
      ..add(DiagnosticsProperty('admins', admins))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('successMessage', successMessage));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoleManagementStateImpl &&
            const DeepCollectionEquality().equals(other._admins, _admins) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.successMessage, successMessage) ||
                other.successMessage == successMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_admins),
    isLoading,
    error,
    successMessage,
  );

  /// Create a copy of RoleManagementState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoleManagementStateImplCopyWith<_$RoleManagementStateImpl> get copyWith =>
      __$$RoleManagementStateImplCopyWithImpl<_$RoleManagementStateImpl>(
        this,
        _$identity,
      );
}

abstract class _RoleManagementState implements RoleManagementState {
  const factory _RoleManagementState({
    final List<AdminUser> admins,
    final bool isLoading,
    final String? error,
    final String? successMessage,
  }) = _$RoleManagementStateImpl;

  @override
  List<AdminUser> get admins;
  @override
  bool get isLoading;
  @override
  String? get error;
  @override
  String? get successMessage;

  /// Create a copy of RoleManagementState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoleManagementStateImplCopyWith<_$RoleManagementStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
