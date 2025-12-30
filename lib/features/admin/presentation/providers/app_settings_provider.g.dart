// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appSettingsDataSourceHash() =>
    r'94cfe9e2290678a8409d5fe4acd3a0fe41523932';

/// Provider for the app settings datasource
///
/// Copied from [appSettingsDataSource].
@ProviderFor(appSettingsDataSource)
final appSettingsDataSourceProvider =
    AutoDisposeProvider<AppSettingsDataSource>.internal(
      appSettingsDataSource,
      name: r'appSettingsDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$appSettingsDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppSettingsDataSourceRef =
    AutoDisposeProviderRef<AppSettingsDataSource>;
String _$appSettingsStreamHash() => r'672c759827a4a6dd205e834436cad18e59bdbefe';

/// Provider that streams app settings
///
/// Copied from [appSettingsStream].
@ProviderFor(appSettingsStream)
final appSettingsStreamProvider =
    AutoDisposeStreamProvider<AppSettingsEntity>.internal(
      appSettingsStream,
      name: r'appSettingsStreamProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$appSettingsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppSettingsStreamRef = AutoDisposeStreamProviderRef<AppSettingsEntity>;
String _$feeSettingsHash() => r'c06ff5bd282bb1672d6dd29dc8485cc09caa27fd';

/// Provider for fee settings only
///
/// Copied from [feeSettings].
@ProviderFor(feeSettings)
final feeSettingsProvider = AutoDisposeProvider<FeeSettingsEntity>.internal(
  feeSettings,
  name: r'feeSettingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$feeSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeeSettingsRef = AutoDisposeProviderRef<FeeSettingsEntity>;
String _$boostPricingHash() => r'533231a0b18db54151445ef855c0d8c63eff068f';

/// Provider for boost pricing only
///
/// Copied from [boostPricing].
@ProviderFor(boostPricing)
final boostPricingProvider = AutoDisposeProvider<BoostPricingEntity>.internal(
  boostPricing,
  name: r'boostPricingProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$boostPricingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BoostPricingRef = AutoDisposeProviderRef<BoostPricingEntity>;
String _$taxRatesHash() => r'37449af71d920c8de118bcdf95915bd1976fbc8f';

/// Provider for tax rates only
///
/// Copied from [taxRates].
@ProviderFor(taxRates)
final taxRatesProvider = AutoDisposeProvider<TaxRatesEntity>.internal(
  taxRates,
  name: r'taxRatesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$taxRatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaxRatesRef = AutoDisposeProviderRef<TaxRatesEntity>;
String _$exchangeRatesHash() => r'a488058cd5008f59778af64cb41da4ea9af4ee1d';

/// Provider for exchange rates only
///
/// Copied from [exchangeRates].
@ProviderFor(exchangeRates)
final exchangeRatesProvider = AutoDisposeProvider<ExchangeRatesEntity>.internal(
  exchangeRates,
  name: r'exchangeRatesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$exchangeRatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExchangeRatesRef = AutoDisposeProviderRef<ExchangeRatesEntity>;
String _$mediaLimitsHash() => r'e3fe6cfa2b679843fe8c6cf307382b3ad0eaf19e';

/// Provider for media limits only
///
/// Copied from [mediaLimits].
@ProviderFor(mediaLimits)
final mediaLimitsProvider = AutoDisposeProvider<MediaLimitsEntity>.internal(
  mediaLimits,
  name: r'mediaLimitsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mediaLimitsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MediaLimitsRef = AutoDisposeProviderRef<MediaLimitsEntity>;
String _$featureFlagsHash() => r'adabbe8343fd2fb0ec082691718ea75aab37065b';

/// Provider for feature flags only
///
/// Copied from [featureFlags].
@ProviderFor(featureFlags)
final featureFlagsProvider = AutoDisposeProvider<FeatureFlagsEntity>.internal(
  featureFlags,
  name: r'featureFlagsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$featureFlagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeatureFlagsRef = AutoDisposeProviderRef<FeatureFlagsEntity>;
String _$isMaintenanceModeHash() => r'cf17e003455a0a28a66e3c615192920831316300';

/// Provider to check if maintenance mode is enabled
///
/// Copied from [isMaintenanceMode].
@ProviderFor(isMaintenanceMode)
final isMaintenanceModeProvider = AutoDisposeProvider<bool>.internal(
  isMaintenanceMode,
  name: r'isMaintenanceModeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$isMaintenanceModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsMaintenanceModeRef = AutoDisposeProviderRef<bool>;
String _$systemUrlsHash() => r'e356ae37d7b65625bd9675b8019ffa6423e3e2a6';

/// Provider for system URLs and emails
///
/// Copied from [systemUrls].
@ProviderFor(systemUrls)
final systemUrlsProvider = AutoDisposeProvider<SystemUrlsEntity>.internal(
  systemUrls,
  name: r'systemUrlsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$systemUrlsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SystemUrlsRef = AutoDisposeProviderRef<SystemUrlsEntity>;
String _$supportEmailHash() => r'227c9240b81ac8c0fd2f56a5963bf5233b0cd786';

/// Provider for support email
///
/// Copied from [supportEmail].
@ProviderFor(supportEmail)
final supportEmailProvider = AutoDisposeProvider<String>.internal(
  supportEmail,
  name: r'supportEmailProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$supportEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupportEmailRef = AutoDisposeProviderRef<String>;
String _$privacyEmailHash() => r'83297073987c97e0fc98729c5fbe5122fcf07c37';

/// Provider for privacy email
///
/// Copied from [privacyEmail].
@ProviderFor(privacyEmail)
final privacyEmailProvider = AutoDisposeProvider<String>.internal(
  privacyEmail,
  name: r'privacyEmailProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$privacyEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PrivacyEmailRef = AutoDisposeProviderRef<String>;
String _$bugsEmailHash() => r'28c38361b3ccd17e83e18775af9d3a858788795b';

/// Provider for bugs email
///
/// Copied from [bugsEmail].
@ProviderFor(bugsEmail)
final bugsEmailProvider = AutoDisposeProvider<String>.internal(
  bugsEmail,
  name: r'bugsEmailProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bugsEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BugsEmailRef = AutoDisposeProviderRef<String>;
String _$feedbackEmailHash() => r'1dd7ba2d7ad8e546e11d9d7997e44f6cbe677fef';

/// Provider for feedback email
///
/// Copied from [feedbackEmail].
@ProviderFor(feedbackEmail)
final feedbackEmailProvider = AutoDisposeProvider<String>.internal(
  feedbackEmail,
  name: r'feedbackEmailProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$feedbackEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeedbackEmailRef = AutoDisposeProviderRef<String>;
String _$moderationEmailHash() => r'867be25e6dbf0fef5482d1977cdf7cdad84b6a1e';

/// Provider for moderation email
///
/// Copied from [moderationEmail].
@ProviderFor(moderationEmail)
final moderationEmailProvider = AutoDisposeProvider<String>.internal(
  moderationEmail,
  name: r'moderationEmailProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$moderationEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ModerationEmailRef = AutoDisposeProviderRef<String>;
String _$appSettingsNotifierHash() =>
    r'7d18c40bd02bc2badc3f4bf88a11c367bc5a1237';

/// Provider for current app settings with caching
///
/// Copied from [AppSettingsNotifier].
@ProviderFor(AppSettingsNotifier)
final appSettingsNotifierProvider = AutoDisposeAsyncNotifierProvider<
  AppSettingsNotifier,
  AppSettingsEntity
>.internal(
  AppSettingsNotifier.new,
  name: r'appSettingsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appSettingsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppSettingsNotifier = AutoDisposeAsyncNotifier<AppSettingsEntity>;
String _$featureCheckerHash() => r'2ca66109e6b04ae4e81e345d48fd8286c0575c78';

/// Provider to check if a specific feature is enabled
///
/// Copied from [FeatureChecker].
@ProviderFor(FeatureChecker)
final featureCheckerProvider =
    AutoDisposeNotifierProvider<FeatureChecker, FeatureFlagsEntity>.internal(
      FeatureChecker.new,
      name: r'featureCheckerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$featureCheckerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FeatureChecker = AutoDisposeNotifier<FeatureFlagsEntity>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
