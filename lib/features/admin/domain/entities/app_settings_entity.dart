import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings_entity.freezed.dart';

/// Entity representing all configurable app settings
@freezed
class AppSettingsEntity with _$AppSettingsEntity {
  const factory AppSettingsEntity({
    // Fee Configuration
    @Default(FeeSettingsEntity()) FeeSettingsEntity fees,
    // Boost Pricing
    @Default(BoostPricingEntity()) BoostPricingEntity boostPricing,
    // Tax Rates
    @Default(TaxRatesEntity()) TaxRatesEntity taxRates,
    // Exchange Rates (fallback)
    @Default(ExchangeRatesEntity()) ExchangeRatesEntity exchangeRates,
    // Media Limits
    @Default(MediaLimitsEntity()) MediaLimitsEntity mediaLimits,
    // Validation Rules
    @Default(ValidationRulesEntity()) ValidationRulesEntity validation,
    // System Intervals
    @Default(SystemIntervalsEntity()) SystemIntervalsEntity intervals,
    // URLs & Contact
    @Default(SystemUrlsEntity()) SystemUrlsEntity urls,
    // Feature Flags
    @Default(FeatureFlagsEntity()) FeatureFlagsEntity featureFlags,
    // Metadata
    DateTime? lastUpdated,
    String? updatedBy,
  }) = _AppSettingsEntity;
}

/// Fee settings for transfers and marketplace
@freezed
class FeeSettingsEntity with _$FeeSettingsEntity {
  const factory FeeSettingsEntity({
    // Transfer fees
    @Default(0.025) double transferFeePercent,
    @Default(500) double transferFeeMin,
    @Default(10000) double transferFeeMax,
    // Marketplace fees
    @Default(0.05) double marketplaceFeePercent,
    @Default(0) double marketplaceFeeMin,
    @Default(50000) double marketplaceFeeMax,
  }) = _FeeSettingsEntity;
}

/// Boost pricing configuration
@freezed
class BoostPricingEntity with _$BoostPricingEntity {
  const factory BoostPricingEntity({
    // Base prices (7 days)
    @Default(5000) double standardBase,
    @Default(10000) double featuredBase,
    @Default(25000) double premiumBase,
    // Duration multipliers
    @Default(1.0) double multiplier7Days,
    @Default(3.0) double multiplier30Days,
    @Default(7.0) double multiplier90Days,
  }) = _BoostPricingEntity;

  const BoostPricingEntity._();

  /// Get price for a specific type and duration
  double getPrice(String type, int days) {
    final basePrice = switch (type) {
      'standard' => standardBase,
      'featured' => featuredBase,
      'premium' => premiumBase,
      _ => standardBase,
    };

    final multiplier = switch (days) {
      7 => multiplier7Days,
      30 => multiplier30Days,
      90 => multiplier90Days,
      _ => 1.0,
    };

    return basePrice * multiplier;
  }
}

/// Tax rates by category
@freezed
class TaxRatesEntity with _$TaxRatesEntity {
  const factory TaxRatesEntity({
    @Default(0.0) double alimentation,
    @Default(0.10) double artisanat,
    @Default(0.19) double standard,
    @Default(0.19) double electronique,
    @Default(0.19) double vetements,
    @Default(0.0) double services,
    @Default(0.0) double immobilier,
  }) = _TaxRatesEntity;

  const TaxRatesEntity._();

  /// Get tax rate for a category
  double getRateForCategory(String category) {
    return switch (category.toLowerCase()) {
      'alimentation' => alimentation,
      'artisanat' => artisanat,
      'electronique' => electronique,
      'vetements' => vetements,
      'services' => services,
      'immobilier' => immobilier,
      _ => standard,
    };
  }
}

/// Fallback exchange rates
@freezed
class ExchangeRatesEntity with _$ExchangeRatesEntity {
  const factory ExchangeRatesEntity({
    @Default(655.957) double eurToXof,
    @Default(615.0) double usdToXof,
    @Default(770.0) double gbpToXof,
    @Default(455.0) double cadToXof,
    @Default(690.0) double chfToXof,
    DateTime? lastUpdated,
  }) = _ExchangeRatesEntity;

  const ExchangeRatesEntity._();

  /// Get rate for a currency pair
  double getRate(String from, String to) {
    if (to.toUpperCase() != 'XOF') return 1.0;

    return switch (from.toUpperCase()) {
      'EUR' => eurToXof,
      'USD' => usdToXof,
      'GBP' => gbpToXof,
      'CAD' => cadToXof,
      'CHF' => chfToXof,
      'XOF' => 1.0,
      _ => 1.0,
    };
  }
}

/// Media upload limits
@freezed
class MediaLimitsEntity with _$MediaLimitsEntity {
  const factory MediaLimitsEntity({
    // Image settings
    @Default(1024) int imageMaxWidth,
    @Default(1024) int imageMaxHeight,
    @Default(85) int imageQuality,
    @Default(5) int maxImagesPerUpload,
    @Default(800) int minWidthForCompression,
    // Message settings
    @Default(2000) int messageMaxChars,
    @Default(200) int messageCharCountThreshold,
    // File limits (in MB)
    @Default(10) int maxImageSizeMb,
    @Default(50) int maxVideoSizeMb,
    @Default(25) int maxDocumentSizeMb,
    // Audio settings
    @Default(300) int maxAudioDurationSeconds,
  }) = _MediaLimitsEntity;
}

/// Validation rules
@freezed
class ValidationRulesEntity with _$ValidationRulesEntity {
  const factory ValidationRulesEntity({
    @Default(6) int passwordMinLength,
    @Default(128) int passwordMaxLength,
    @Default(8) int shareCodeLength,
    @Default(3) int minSearchQueryLength,
    @Default(100) int maxSearchQueryLength,
    // Delete window for messages (in hours)
    @Default(1) int messageDeleteWindowHours,
  }) = _ValidationRulesEntity;
}

/// System intervals
@freezed
class SystemIntervalsEntity with _$SystemIntervalsEntity {
  const factory SystemIntervalsEntity({
    @Default(5) int locationUpdateMinutes,
    @Default(10) int heartbeatMinutes,
    @Default(60) int cacheMinutes,
    @Default(60) int remoteConfigFetchMinutes,
    @Default(3) int typingIndicatorSeconds,
  }) = _SystemIntervalsEntity;
}

/// System URLs and contact info
@freezed
class SystemUrlsEntity with _$SystemUrlsEntity {
  const factory SystemUrlsEntity({
    @Default('https://diaspo-niger.web.app/p/') String shareBaseUrl,
    @Default('support@diasponiger.com') String supportEmail,
    @Default('merchant.com.diasponiger') String stripeMerchantId,
    @Default('https://diaspo-niger.web.app/terms') String termsUrl,
    @Default('https://diaspo-niger.web.app/privacy') String privacyUrl,
  }) = _SystemUrlsEntity;
}

/// Feature flags
@freezed
class FeatureFlagsEntity with _$FeatureFlagsEntity {
  const factory FeatureFlagsEntity({
    @Default(true) bool moneyTransfer,
    @Default(true) bool marketplace,
    @Default(true) bool businessDirectory,
    @Default(true) bool events,
    @Default(true) bool groups,
    @Default(true) bool embassies,
    @Default(false) bool maintenanceMode,
    String? maintenanceMessage,
  }) = _FeatureFlagsEntity;
}
