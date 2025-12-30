import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/app_settings_datasource.dart';
import '../../data/models/app_settings_model.dart';
import '../../domain/entities/app_settings_entity.dart';

part 'app_settings_provider.g.dart';

/// Provider for the app settings datasource
@riverpod
AppSettingsDataSource appSettingsDataSource(Ref ref) {
  return AppSettingsDataSourceImpl();
}

/// Provider that streams app settings
@riverpod
Stream<AppSettingsEntity> appSettingsStream(Ref ref) {
  final dataSource = ref.watch(appSettingsDataSourceProvider);
  return dataSource.watchSettings().map((model) => model.toEntity());
}

/// Provider for current app settings with caching
@riverpod
class AppSettingsNotifier extends _$AppSettingsNotifier {
  AppSettingsDataSource get _dataSource =>
      ref.read(appSettingsDataSourceProvider);

  @override
  Future<AppSettingsEntity> build() async {
    // Watch the stream provider for real-time updates
    ref.listen<AsyncValue<AppSettingsEntity>>(
      appSettingsStreamProvider,
      (previous, next) {
        next.whenData((settings) {
          // Only update if we already have data and the new data is different
          final currentData = state.valueOrNull;
          if (currentData != null && currentData != settings) {
            state = AsyncValue.data(settings);
          }
        });
      },
      fireImmediately: false,
    );

    final model = await _dataSource.getSettings();
    return model.toEntity();
  }

  /// Update fee settings
  Future<void> updateFees(FeeSettingsEntity fees, String updatedBy) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'fees',
        FeeSettingsModel.fromEntity(fees).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update boost pricing
  Future<void> updateBoostPricing(
    BoostPricingEntity pricing,
    String updatedBy,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'boostPricing',
        BoostPricingModel.fromEntity(pricing).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update tax rates
  Future<void> updateTaxRates(TaxRatesEntity rates, String updatedBy) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'taxRates',
        TaxRatesModel.fromEntity(rates).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update exchange rates
  Future<void> updateExchangeRates(
    ExchangeRatesEntity rates,
    String updatedBy,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'exchangeRates',
        ExchangeRatesModel.fromEntity(rates).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update media limits
  Future<void> updateMediaLimits(
    MediaLimitsEntity limits,
    String updatedBy,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'mediaLimits',
        MediaLimitsModel.fromEntity(limits).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update validation rules
  Future<void> updateValidation(
    ValidationRulesEntity rules,
    String updatedBy,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'validation',
        ValidationRulesModel.fromEntity(rules).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update system intervals
  Future<void> updateIntervals(
    SystemIntervalsEntity intervals,
    String updatedBy,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'intervals',
        SystemIntervalsModel.fromEntity(intervals).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update system URLs
  Future<void> updateUrls(SystemUrlsEntity urls, String updatedBy) async {
    state = const AsyncValue.loading();
    try {
      await _dataSource.updateSection(
        'urls',
        SystemUrlsModel.fromEntity(urls).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update feature flags
  Future<void> updateFeatureFlags(
    FeatureFlagsEntity flags,
    String updatedBy,
  ) async {
    try {
      await _dataSource.updateSection(
        'featureFlags',
        FeatureFlagsModel.fromEntity(flags).toJson(),
        updatedBy,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Toggle maintenance mode
  Future<void> toggleMaintenanceMode(
    bool enabled,
    String? message,
    String updatedBy,
  ) async {
    final current =
        state.valueOrNull?.featureFlags ?? const FeatureFlagsEntity();
    await updateFeatureFlags(
      FeatureFlagsEntity(
        moneyTransfer: current.moneyTransfer,
        marketplace: current.marketplace,
        businessDirectory: current.businessDirectory,
        events: current.events,
        groups: current.groups,
        embassies: current.embassies,
        maintenanceMode: enabled,
        maintenanceMessage: message,
      ),
      updatedBy,
    );
  }
}

// ============================================================================
// CONVENIENCE PROVIDERS FOR SPECIFIC SETTINGS
// ============================================================================

/// Provider for fee settings only
@riverpod
FeeSettingsEntity feeSettings(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.fees ??
      const FeeSettingsEntity();
}

/// Provider for boost pricing only
@riverpod
BoostPricingEntity boostPricing(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.boostPricing ??
      const BoostPricingEntity();
}

/// Provider for tax rates only
@riverpod
TaxRatesEntity taxRates(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.taxRates ??
      const TaxRatesEntity();
}

/// Provider for exchange rates only
@riverpod
ExchangeRatesEntity exchangeRates(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.exchangeRates ??
      const ExchangeRatesEntity();
}

/// Provider for media limits only
@riverpod
MediaLimitsEntity mediaLimits(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.mediaLimits ??
      const MediaLimitsEntity();
}

/// Provider for feature flags only
@riverpod
FeatureFlagsEntity featureFlags(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.featureFlags ??
      const FeatureFlagsEntity();
}

/// Provider to check if maintenance mode is enabled
@riverpod
bool isMaintenanceMode(Ref ref) {
  return ref.watch(featureFlagsProvider).maintenanceMode;
}

/// Provider to check if a specific feature is enabled
@riverpod
class FeatureChecker extends _$FeatureChecker {
  @override
  FeatureFlagsEntity build() {
    return ref.watch(featureFlagsProvider);
  }

  bool isMoneyTransferEnabled() => state.moneyTransfer;
  bool isMarketplaceEnabled() => state.marketplace;
  bool isBusinessDirectoryEnabled() => state.businessDirectory;
  bool isEventsEnabled() => state.events;
  bool isGroupsEnabled() => state.groups;
  bool isEmbassiesEnabled() => state.embassies;
}

/// Provider for system URLs and emails
@riverpod
SystemUrlsEntity systemUrls(Ref ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.urls ??
      const SystemUrlsEntity();
}

/// Provider for support email
@riverpod
String supportEmail(Ref ref) {
  return ref.watch(systemUrlsProvider).supportEmail;
}

/// Provider for privacy email
@riverpod
String privacyEmail(Ref ref) {
  return ref.watch(systemUrlsProvider).privacyEmail;
}

/// Provider for bugs email
@riverpod
String bugsEmail(Ref ref) {
  return ref.watch(systemUrlsProvider).bugsEmail;
}

/// Provider for feedback email
@riverpod
String feedbackEmail(Ref ref) {
  return ref.watch(systemUrlsProvider).feedbackEmail;
}

/// Provider for moderation email
@riverpod
String moderationEmail(Ref ref) {
  return ref.watch(systemUrlsProvider).moderationEmail;
}
