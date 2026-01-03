// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_gate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$securityGateHash() => r'18aec8282964e6e759c55f15d9c3b1d843ecf376';

/// Provider pour le service SecurityGate
///
/// Copied from [securityGate].
@ProviderFor(securityGate)
final securityGateProvider = AutoDisposeProvider<SecurityGateService>.internal(
  securityGate,
  name: r'securityGateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$securityGateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SecurityGateRef = AutoDisposeProviderRef<SecurityGateService>;
String _$canMakePaymentHash() => r'ae87be984829d55d0cb502b6b235c3d0a0158a4b';

/// Provider pour vérifier si les paiements sont autorisés
///
/// Copied from [canMakePayment].
@ProviderFor(canMakePayment)
final canMakePaymentProvider =
    AutoDisposeFutureProvider<SecurityCheckResult>.internal(
      canMakePayment,
      name: r'canMakePaymentProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$canMakePaymentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CanMakePaymentRef = AutoDisposeFutureProviderRef<SecurityCheckResult>;
String _$canMakeTransferHash() => r'0bbb5cd090afb76705b627c9dab5e18de025a4d7';

/// Provider pour vérifier si les transferts sont autorisés
///
/// Copied from [canMakeTransfer].
@ProviderFor(canMakeTransfer)
final canMakeTransferProvider =
    AutoDisposeFutureProvider<SecurityCheckResult>.internal(
      canMakeTransfer,
      name: r'canMakeTransferProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$canMakeTransferHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CanMakeTransferRef = AutoDisposeFutureProviderRef<SecurityCheckResult>;
String _$canUseMarketplaceHash() => r'ed2045cc6e2f9e68ddb9f5fa5fe48fa5e838441f';

/// Provider pour vérifier l'accès au marketplace
///
/// Copied from [canUseMarketplace].
@ProviderFor(canUseMarketplace)
final canUseMarketplaceProvider =
    AutoDisposeFutureProvider<SecurityCheckResult>.internal(
      canUseMarketplace,
      name: r'canUseMarketplaceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$canUseMarketplaceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CanUseMarketplaceRef =
    AutoDisposeFutureProviderRef<SecurityCheckResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
