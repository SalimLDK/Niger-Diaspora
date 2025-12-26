import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

part 'feature_flag_service.g.dart';

/// Feature flag keys for monetization features
class FeatureFlags {
  FeatureFlags._();

  /// Money transfer feature - hidden until ready for deployment
  static const String moneyTransfer = 'feature_money_transfer';

  /// Marketplace feature
  static const String marketplace = 'feature_marketplace';

  /// Business directory feature
  static const String businessDirectory = 'feature_business_directory';
}

/// Service to manage feature flags
///
/// This allows features to be hidden/shown without code changes.
/// Can be extended to use Firebase Remote Config for dynamic updates.
class FeatureFlagService {
  static FeatureFlagService? _instance;
  static FeatureFlagService get instance =>
      _instance ??= FeatureFlagService._();
  FeatureFlagService._();

  /// Default feature flag values
  /// Set to false to hide a feature, true to show it
  final Map<String, bool> _defaults = {
    FeatureFlags.moneyTransfer: true, // Enabled for testing
    FeatureFlags.marketplace: true,
    FeatureFlags.businessDirectory: true,
  };

  /// Local overrides for testing/development
  final Map<String, bool> _localOverrides = {};

  /// Check if a feature is enabled
  bool isEnabled(String featureKey) {
    // Check local override first (for testing)
    if (_localOverrides.containsKey(featureKey)) {
      return _localOverrides[featureKey]!;
    }

    // Then check defaults
    return _defaults[featureKey] ?? false;
  }

  /// Set a local override for a feature (for testing/development)
  void setLocalOverride(String featureKey, bool enabled) {
    _localOverrides[featureKey] = enabled;
  }

  /// Clear all local overrides
  void clearLocalOverrides() {
    _localOverrides.clear();
  }

  /// Check if money transfer feature is enabled
  bool get isMoneyTransferEnabled => isEnabled(FeatureFlags.moneyTransfer);

  /// Check if marketplace feature is enabled
  bool get isMarketplaceEnabled => isEnabled(FeatureFlags.marketplace);

  /// Check if business directory feature is enabled
  bool get isBusinessDirectoryEnabled =>
      isEnabled(FeatureFlags.businessDirectory);

  Future<void> fetchRemoteFlags() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      // Update flags from remote config
      _defaults[FeatureFlags.moneyTransfer] = remoteConfig.getBool(
        FeatureFlags.moneyTransfer,
      );
      _defaults[FeatureFlags.marketplace] = remoteConfig.getBool(
        FeatureFlags.marketplace,
      );
      _defaults[FeatureFlags.businessDirectory] = remoteConfig.getBool(
        FeatureFlags.businessDirectory,
      );
    } catch (e) {
      // Fallback to local defaults on error
      debugPrint('Error fetching remote config: $e');
    }
  }
}

/// Provider for FeatureFlagService
@riverpod
FeatureFlagService featureFlagService(Ref ref) {
  return FeatureFlagService.instance;
}

/// Provider to check if money transfer feature is enabled
@riverpod
bool isMoneyTransferEnabled(Ref ref) {
  return ref.watch(featureFlagServiceProvider).isMoneyTransferEnabled;
}

/// Provider to check if marketplace feature is enabled
@riverpod
bool isMarketplaceEnabled(Ref ref) {
  return ref.watch(featureFlagServiceProvider).isMarketplaceEnabled;
}

/// Provider to check if business directory feature is enabled
@riverpod
bool isBusinessDirectoryEnabled(Ref ref) {
  return ref.watch(featureFlagServiceProvider).isBusinessDirectoryEnabled;
}
