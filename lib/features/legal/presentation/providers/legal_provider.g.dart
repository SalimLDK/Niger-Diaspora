// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$legalDataSourceHash() => r'8c2c6d4884d160911738fc33580d019a773ce478';

/// See also [legalDataSource].
@ProviderFor(legalDataSource)
final legalDataSourceProvider =
    AutoDisposeProvider<LegalRemoteDataSource>.internal(
      legalDataSource,
      name: r'legalDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$legalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LegalDataSourceRef = AutoDisposeProviderRef<LegalRemoteDataSource>;
String _$termsHash() => r'9393896be5a0deb678504fc6664d9c473d2da91f';

/// See also [terms].
@ProviderFor(terms)
final termsProvider = AutoDisposeFutureProvider<LegalContentModel>.internal(
  terms,
  name: r'termsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$termsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TermsRef = AutoDisposeFutureProviderRef<LegalContentModel>;
String _$privacyPolicyHash() => r'4acc83edcff2566a9d52118711e5414ccc6439c8';

/// See also [privacyPolicy].
@ProviderFor(privacyPolicy)
final privacyPolicyProvider =
    AutoDisposeFutureProvider<LegalContentModel>.internal(
      privacyPolicy,
      name: r'privacyPolicyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$privacyPolicyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PrivacyPolicyRef = AutoDisposeFutureProviderRef<LegalContentModel>;
String _$codeOfConductHash() => r'131d1c70a510bf0ddaec99f988adc5e31de92971';

/// See also [codeOfConduct].
@ProviderFor(codeOfConduct)
final codeOfConductProvider =
    AutoDisposeFutureProvider<LegalContentModel>.internal(
      codeOfConduct,
      name: r'codeOfConductProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$codeOfConductHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CodeOfConductRef = AutoDisposeFutureProviderRef<LegalContentModel>;
String _$needsLegalAcceptanceHash() =>
    r'6de11a589f1ca15eecadc7c50940860a7721bfd5';

/// See also [needsLegalAcceptance].
@ProviderFor(needsLegalAcceptance)
final needsLegalAcceptanceProvider = AutoDisposeFutureProvider<bool>.internal(
  needsLegalAcceptance,
  name: r'needsLegalAcceptanceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$needsLegalAcceptanceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NeedsLegalAcceptanceRef = AutoDisposeFutureProviderRef<bool>;
String _$legalAcceptanceNotifierHash() =>
    r'ed5acf04f46a7e34a25e205a2e1d1de07f3eb87b';

/// See also [LegalAcceptanceNotifier].
@ProviderFor(LegalAcceptanceNotifier)
final legalAcceptanceNotifierProvider =
    AutoDisposeAsyncNotifierProvider<LegalAcceptanceNotifier, void>.internal(
      LegalAcceptanceNotifier.new,
      name: r'legalAcceptanceNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$legalAcceptanceNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LegalAcceptanceNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
