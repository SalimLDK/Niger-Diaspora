// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentAdminRoleHash() => r'c3c6a7b43e35d5716777fef654b73a9413f95388';

/// Provider qui récupère le rôle admin de l'utilisateur courant depuis Firestore
///
/// Copied from [currentAdminRole].
@ProviderFor(currentAdminRole)
final currentAdminRoleProvider = AutoDisposeStreamProvider<AdminRole>.internal(
  currentAdminRole,
  name: r'currentAdminRoleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentAdminRoleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentAdminRoleRef = AutoDisposeStreamProviderRef<AdminRole>;
String _$adminRoleHash() => r'5da5081f440b7e651b524de6eb0dba20d68d2502';

/// Provider synchrone pour obtenir le rôle admin actuel (avec valeur par défaut)
///
/// Copied from [adminRole].
@ProviderFor(adminRole)
final adminRoleProvider = AutoDisposeProvider<AdminRole>.internal(
  adminRole,
  name: r'adminRoleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminRoleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminRoleRef = AutoDisposeProviderRef<AdminRole>;
String _$hasPermissionHash() => r'616783b0a3442bd4dbd199ac672df82d71c28b74';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Vérifie si l'utilisateur a une permission spécifique
///
/// Copied from [hasPermission].
@ProviderFor(hasPermission)
const hasPermissionProvider = HasPermissionFamily();

/// Vérifie si l'utilisateur a une permission spécifique
///
/// Copied from [hasPermission].
class HasPermissionFamily extends Family<bool> {
  /// Vérifie si l'utilisateur a une permission spécifique
  ///
  /// Copied from [hasPermission].
  const HasPermissionFamily();

  /// Vérifie si l'utilisateur a une permission spécifique
  ///
  /// Copied from [hasPermission].
  HasPermissionProvider call(AdminPermission permission) {
    return HasPermissionProvider(permission);
  }

  @override
  HasPermissionProvider getProviderOverride(
    covariant HasPermissionProvider provider,
  ) {
    return call(provider.permission);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'hasPermissionProvider';
}

/// Vérifie si l'utilisateur a une permission spécifique
///
/// Copied from [hasPermission].
class HasPermissionProvider extends AutoDisposeProvider<bool> {
  /// Vérifie si l'utilisateur a une permission spécifique
  ///
  /// Copied from [hasPermission].
  HasPermissionProvider(AdminPermission permission)
    : this._internal(
        (ref) => hasPermission(ref as HasPermissionRef, permission),
        from: hasPermissionProvider,
        name: r'hasPermissionProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$hasPermissionHash,
        dependencies: HasPermissionFamily._dependencies,
        allTransitiveDependencies:
            HasPermissionFamily._allTransitiveDependencies,
        permission: permission,
      );

  HasPermissionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.permission,
  }) : super.internal();

  final AdminPermission permission;

  @override
  Override overrideWith(bool Function(HasPermissionRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: HasPermissionProvider._internal(
        (ref) => create(ref as HasPermissionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        permission: permission,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _HasPermissionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasPermissionProvider && other.permission == permission;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, permission.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HasPermissionRef on AutoDisposeProviderRef<bool> {
  /// The parameter `permission` of this provider.
  AdminPermission get permission;
}

class _HasPermissionProviderElement extends AutoDisposeProviderElement<bool>
    with HasPermissionRef {
  _HasPermissionProviderElement(super.provider);

  @override
  AdminPermission get permission =>
      (origin as HasPermissionProvider).permission;
}

String _$hasAnyPermissionHash() => r'0288e39dec2f2bce11a4ac104c371663530414df';

/// Vérifie si l'utilisateur a au moins une des permissions données
///
/// Copied from [hasAnyPermission].
@ProviderFor(hasAnyPermission)
const hasAnyPermissionProvider = HasAnyPermissionFamily();

/// Vérifie si l'utilisateur a au moins une des permissions données
///
/// Copied from [hasAnyPermission].
class HasAnyPermissionFamily extends Family<bool> {
  /// Vérifie si l'utilisateur a au moins une des permissions données
  ///
  /// Copied from [hasAnyPermission].
  const HasAnyPermissionFamily();

  /// Vérifie si l'utilisateur a au moins une des permissions données
  ///
  /// Copied from [hasAnyPermission].
  HasAnyPermissionProvider call(Set<AdminPermission> permissions) {
    return HasAnyPermissionProvider(permissions);
  }

  @override
  HasAnyPermissionProvider getProviderOverride(
    covariant HasAnyPermissionProvider provider,
  ) {
    return call(provider.permissions);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'hasAnyPermissionProvider';
}

/// Vérifie si l'utilisateur a au moins une des permissions données
///
/// Copied from [hasAnyPermission].
class HasAnyPermissionProvider extends AutoDisposeProvider<bool> {
  /// Vérifie si l'utilisateur a au moins une des permissions données
  ///
  /// Copied from [hasAnyPermission].
  HasAnyPermissionProvider(Set<AdminPermission> permissions)
    : this._internal(
        (ref) => hasAnyPermission(ref as HasAnyPermissionRef, permissions),
        from: hasAnyPermissionProvider,
        name: r'hasAnyPermissionProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$hasAnyPermissionHash,
        dependencies: HasAnyPermissionFamily._dependencies,
        allTransitiveDependencies:
            HasAnyPermissionFamily._allTransitiveDependencies,
        permissions: permissions,
      );

  HasAnyPermissionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.permissions,
  }) : super.internal();

  final Set<AdminPermission> permissions;

  @override
  Override overrideWith(bool Function(HasAnyPermissionRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: HasAnyPermissionProvider._internal(
        (ref) => create(ref as HasAnyPermissionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        permissions: permissions,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _HasAnyPermissionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasAnyPermissionProvider &&
        other.permissions == permissions;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, permissions.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HasAnyPermissionRef on AutoDisposeProviderRef<bool> {
  /// The parameter `permissions` of this provider.
  Set<AdminPermission> get permissions;
}

class _HasAnyPermissionProviderElement extends AutoDisposeProviderElement<bool>
    with HasAnyPermissionRef {
  _HasAnyPermissionProviderElement(super.provider);

  @override
  Set<AdminPermission> get permissions =>
      (origin as HasAnyPermissionProvider).permissions;
}

String _$isSuperAdminHash() => r'02aead512eaa004fbe8195b5e0bc25f04e30ed1b';

/// Vérifie si l'utilisateur est SuperAdmin
///
/// Copied from [isSuperAdmin].
@ProviderFor(isSuperAdmin)
final isSuperAdminProvider = AutoDisposeProvider<bool>.internal(
  isSuperAdmin,
  name: r'isSuperAdminProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isSuperAdminHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsSuperAdminRef = AutoDisposeProviderRef<bool>;
String _$isAnyAdminHash() => r'54d22dc59fadf2630b68a4279337334bc5624d26';

/// Vérifie si l'utilisateur a un rôle admin (n'importe lequel)
///
/// Copied from [isAnyAdmin].
@ProviderFor(isAnyAdmin)
final isAnyAdminProvider = AutoDisposeProvider<bool>.internal(
  isAnyAdmin,
  name: r'isAnyAdminProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isAnyAdminHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsAnyAdminRef = AutoDisposeProviderRef<bool>;
String _$permissionCheckerHash() => r'ce28b05bc9526de551ee7d1796239177e3c494bd';

/// Provider pour obtenir un PermissionChecker
///
/// Copied from [permissionChecker].
@ProviderFor(permissionChecker)
final permissionCheckerProvider =
    AutoDisposeProvider<PermissionChecker>.internal(
      permissionChecker,
      name: r'permissionCheckerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$permissionCheckerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PermissionCheckerRef = AutoDisposeProviderRef<PermissionChecker>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
