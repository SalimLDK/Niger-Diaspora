// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_integrity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playIntegrityServiceHash() =>
    r'05cc4306f6e96208a51cb5db80c2afb188dbc8b0';

/// Provider for the Play Integrity service instance
///
/// Copied from [playIntegrityService].
@ProviderFor(playIntegrityService)
final playIntegrityServiceProvider =
    AutoDisposeProvider<PlayIntegrityService>.internal(
      playIntegrityService,
      name: r'playIntegrityServiceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$playIntegrityServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayIntegrityServiceRef = AutoDisposeProviderRef<PlayIntegrityService>;
String _$playIntegrityAvailableHash() =>
    r'68a18d55596ed9427279730ebd6c85b1a78b6ba7';

/// Provider to check if Play Integrity is available
///
/// Copied from [playIntegrityAvailable].
@ProviderFor(playIntegrityAvailable)
final playIntegrityAvailableProvider = AutoDisposeFutureProvider<bool>.internal(
  playIntegrityAvailable,
  name: r'playIntegrityAvailableProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playIntegrityAvailableHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayIntegrityAvailableRef = AutoDisposeFutureProviderRef<bool>;
String _$integrityCheckHash() => r'05a9f8e2ad04c4efccf944a0b52bb346f8492393';

/// Notifier for managing integrity check state
///
/// Copied from [IntegrityCheck].
@ProviderFor(IntegrityCheck)
final integrityCheckProvider =
    AutoDisposeNotifierProvider<IntegrityCheck, IntegrityCheckState>.internal(
      IntegrityCheck.new,
      name: r'integrityCheckProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$integrityCheckHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IntegrityCheck = AutoDisposeNotifier<IntegrityCheckState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
