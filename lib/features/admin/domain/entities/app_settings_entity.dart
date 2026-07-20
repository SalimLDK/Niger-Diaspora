import 'package:equatable/equatable.dart';

/// Entite representant tous les parametres configurables de l'app
class AppSettingsEntity extends Equatable {
  final FeeSettingsEntity fees;
  final BoostPricingEntity boostPricing;
  final TaxRatesEntity taxRates;
  final ExchangeRatesEntity exchangeRates;
  final MediaLimitsEntity mediaLimits;
  final ValidationRulesEntity validation;
  final SystemIntervalsEntity intervals;
  final SystemUrlsEntity urls;
  final FeatureFlagsEntity featureFlags;
  final AudioRoomsSettingsEntity audioRooms;
  final DateTime? lastUpdated;
  final String? updatedBy;

  const AppSettingsEntity({
    this.fees = const FeeSettingsEntity(),
    this.boostPricing = const BoostPricingEntity(),
    this.taxRates = const TaxRatesEntity(),
    this.exchangeRates = const ExchangeRatesEntity(),
    this.mediaLimits = const MediaLimitsEntity(),
    this.validation = const ValidationRulesEntity(),
    this.intervals = const SystemIntervalsEntity(),
    this.urls = const SystemUrlsEntity(),
    this.featureFlags = const FeatureFlagsEntity(),
    this.audioRooms = const AudioRoomsSettingsEntity(),
    this.lastUpdated,
    this.updatedBy,
  });

  AppSettingsEntity copyWith({
    FeeSettingsEntity? fees,
    BoostPricingEntity? boostPricing,
    TaxRatesEntity? taxRates,
    ExchangeRatesEntity? exchangeRates,
    MediaLimitsEntity? mediaLimits,
    ValidationRulesEntity? validation,
    SystemIntervalsEntity? intervals,
    SystemUrlsEntity? urls,
    FeatureFlagsEntity? featureFlags,
    AudioRoomsSettingsEntity? audioRooms,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return AppSettingsEntity(
      fees: fees ?? this.fees,
      boostPricing: boostPricing ?? this.boostPricing,
      taxRates: taxRates ?? this.taxRates,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      mediaLimits: mediaLimits ?? this.mediaLimits,
      validation: validation ?? this.validation,
      intervals: intervals ?? this.intervals,
      urls: urls ?? this.urls,
      featureFlags: featureFlags ?? this.featureFlags,
      audioRooms: audioRooms ?? this.audioRooms,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
    fees,
    boostPricing,
    taxRates,
    exchangeRates,
    mediaLimits,
    validation,
    intervals,
    urls,
    featureFlags,
    audioRooms,
    lastUpdated,
    updatedBy,
  ];
}

/// Parametres des frais pour les transferts et le marketplace
class FeeSettingsEntity extends Equatable {
  final double transferFeePercent;
  final double transferFeeMin;
  final double transferFeeMax;
  final double marketplaceFeePercent;
  final double marketplaceFeeMin;
  final double marketplaceFeeMax;

  const FeeSettingsEntity({
    this.transferFeePercent = 0.025,
    this.transferFeeMin = 500,
    this.transferFeeMax = 10000,
    this.marketplaceFeePercent = 0.05,
    this.marketplaceFeeMin = 0,
    this.marketplaceFeeMax = 50000,
  });

  FeeSettingsEntity copyWith({
    double? transferFeePercent,
    double? transferFeeMin,
    double? transferFeeMax,
    double? marketplaceFeePercent,
    double? marketplaceFeeMin,
    double? marketplaceFeeMax,
  }) {
    return FeeSettingsEntity(
      transferFeePercent: transferFeePercent ?? this.transferFeePercent,
      transferFeeMin: transferFeeMin ?? this.transferFeeMin,
      transferFeeMax: transferFeeMax ?? this.transferFeeMax,
      marketplaceFeePercent:
          marketplaceFeePercent ?? this.marketplaceFeePercent,
      marketplaceFeeMin: marketplaceFeeMin ?? this.marketplaceFeeMin,
      marketplaceFeeMax: marketplaceFeeMax ?? this.marketplaceFeeMax,
    );
  }

  @override
  List<Object?> get props => [
    transferFeePercent,
    transferFeeMin,
    transferFeeMax,
    marketplaceFeePercent,
    marketplaceFeeMin,
    marketplaceFeeMax,
  ];
}

/// Configuration des prix de boost
class BoostPricingEntity extends Equatable {
  final double standardBase;
  final double featuredBase;
  final double premiumBase;
  final double multiplier7Days;
  final double multiplier30Days;
  final double multiplier90Days;

  const BoostPricingEntity({
    this.standardBase = 5000,
    this.featuredBase = 10000,
    this.premiumBase = 25000,
    this.multiplier7Days = 1.0,
    this.multiplier30Days = 3.0,
    this.multiplier90Days = 7.0,
  });

  /// Obtenir le prix pour un type et une duree specifiques
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

  BoostPricingEntity copyWith({
    double? standardBase,
    double? featuredBase,
    double? premiumBase,
    double? multiplier7Days,
    double? multiplier30Days,
    double? multiplier90Days,
  }) {
    return BoostPricingEntity(
      standardBase: standardBase ?? this.standardBase,
      featuredBase: featuredBase ?? this.featuredBase,
      premiumBase: premiumBase ?? this.premiumBase,
      multiplier7Days: multiplier7Days ?? this.multiplier7Days,
      multiplier30Days: multiplier30Days ?? this.multiplier30Days,
      multiplier90Days: multiplier90Days ?? this.multiplier90Days,
    );
  }

  @override
  List<Object?> get props => [
    standardBase,
    featuredBase,
    premiumBase,
    multiplier7Days,
    multiplier30Days,
    multiplier90Days,
  ];
}

/// Taux de taxe par categorie
class TaxRatesEntity extends Equatable {
  final double alimentation;
  final double artisanat;
  final double standard;
  final double electronique;
  final double vetements;
  final double services;
  final double immobilier;

  const TaxRatesEntity({
    this.alimentation = 0.0,
    this.artisanat = 0.10,
    this.standard = 0.19,
    this.electronique = 0.19,
    this.vetements = 0.19,
    this.services = 0.0,
    this.immobilier = 0.0,
  });

  /// Obtenir le taux de taxe pour une categorie
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

  TaxRatesEntity copyWith({
    double? alimentation,
    double? artisanat,
    double? standard,
    double? electronique,
    double? vetements,
    double? services,
    double? immobilier,
  }) {
    return TaxRatesEntity(
      alimentation: alimentation ?? this.alimentation,
      artisanat: artisanat ?? this.artisanat,
      standard: standard ?? this.standard,
      electronique: electronique ?? this.electronique,
      vetements: vetements ?? this.vetements,
      services: services ?? this.services,
      immobilier: immobilier ?? this.immobilier,
    );
  }

  @override
  List<Object?> get props => [
    alimentation,
    artisanat,
    standard,
    electronique,
    vetements,
    services,
    immobilier,
  ];
}

/// Taux de change de secours et configuration API
class ExchangeRatesEntity extends Equatable {
  final double eurToXof;
  final double usdToXof;
  final double gbpToXof;
  final double cadToXof;
  final double chfToXof;
  final DateTime? lastUpdated;
  final String? exchangeRateApiKey;
  final int refreshIntervalMinutes;

  const ExchangeRatesEntity({
    this.eurToXof = 655.957,
    this.usdToXof = 615.0,
    this.gbpToXof = 770.0,
    this.cadToXof = 455.0,
    this.chfToXof = 690.0,
    this.lastUpdated,
    this.exchangeRateApiKey,
    this.refreshIntervalMinutes = 60,
  });

  /// Obtenir le taux pour une paire de devises
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

  ExchangeRatesEntity copyWith({
    double? eurToXof,
    double? usdToXof,
    double? gbpToXof,
    double? cadToXof,
    double? chfToXof,
    DateTime? lastUpdated,
    String? exchangeRateApiKey,
    int? refreshIntervalMinutes,
  }) {
    return ExchangeRatesEntity(
      eurToXof: eurToXof ?? this.eurToXof,
      usdToXof: usdToXof ?? this.usdToXof,
      gbpToXof: gbpToXof ?? this.gbpToXof,
      cadToXof: cadToXof ?? this.cadToXof,
      chfToXof: chfToXof ?? this.chfToXof,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      exchangeRateApiKey: exchangeRateApiKey ?? this.exchangeRateApiKey,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
    );
  }

  @override
  List<Object?> get props => [
    eurToXof,
    usdToXof,
    gbpToXof,
    cadToXof,
    chfToXof,
    lastUpdated,
    exchangeRateApiKey,
    refreshIntervalMinutes,
  ];
}

/// Limites d'upload media
class MediaLimitsEntity extends Equatable {
  final int imageMaxWidth;
  final int imageMaxHeight;
  final int imageQuality;
  final int maxImagesPerUpload;
  final int minWidthForCompression;
  final int messageMaxChars;
  final int messageCharCountThreshold;
  final int maxImageSizeMb;
  final int maxVideoSizeMb;
  final int maxDocumentSizeMb;
  final int maxAudioDurationSeconds;

  const MediaLimitsEntity({
    this.imageMaxWidth = 1024,
    this.imageMaxHeight = 1024,
    this.imageQuality = 85,
    this.maxImagesPerUpload = 5,
    this.minWidthForCompression = 800,
    this.messageMaxChars = 2000,
    this.messageCharCountThreshold = 200,
    this.maxImageSizeMb = 10,
    this.maxVideoSizeMb = 50,
    this.maxDocumentSizeMb = 25,
    this.maxAudioDurationSeconds = 300,
  });

  MediaLimitsEntity copyWith({
    int? imageMaxWidth,
    int? imageMaxHeight,
    int? imageQuality,
    int? maxImagesPerUpload,
    int? minWidthForCompression,
    int? messageMaxChars,
    int? messageCharCountThreshold,
    int? maxImageSizeMb,
    int? maxVideoSizeMb,
    int? maxDocumentSizeMb,
    int? maxAudioDurationSeconds,
  }) {
    return MediaLimitsEntity(
      imageMaxWidth: imageMaxWidth ?? this.imageMaxWidth,
      imageMaxHeight: imageMaxHeight ?? this.imageMaxHeight,
      imageQuality: imageQuality ?? this.imageQuality,
      maxImagesPerUpload: maxImagesPerUpload ?? this.maxImagesPerUpload,
      minWidthForCompression:
          minWidthForCompression ?? this.minWidthForCompression,
      messageMaxChars: messageMaxChars ?? this.messageMaxChars,
      messageCharCountThreshold:
          messageCharCountThreshold ?? this.messageCharCountThreshold,
      maxImageSizeMb: maxImageSizeMb ?? this.maxImageSizeMb,
      maxVideoSizeMb: maxVideoSizeMb ?? this.maxVideoSizeMb,
      maxDocumentSizeMb: maxDocumentSizeMb ?? this.maxDocumentSizeMb,
      maxAudioDurationSeconds:
          maxAudioDurationSeconds ?? this.maxAudioDurationSeconds,
    );
  }

  @override
  List<Object?> get props => [
    imageMaxWidth,
    imageMaxHeight,
    imageQuality,
    maxImagesPerUpload,
    minWidthForCompression,
    messageMaxChars,
    messageCharCountThreshold,
    maxImageSizeMb,
    maxVideoSizeMb,
    maxDocumentSizeMb,
    maxAudioDurationSeconds,
  ];
}

/// Regles de validation
class ValidationRulesEntity extends Equatable {
  final int passwordMinLength;
  final int passwordMaxLength;
  final int shareCodeLength;
  final int minSearchQueryLength;
  final int maxSearchQueryLength;
  final int messageDeleteWindowHours;

  const ValidationRulesEntity({
    this.passwordMinLength = 6,
    this.passwordMaxLength = 128,
    this.shareCodeLength = 8,
    this.minSearchQueryLength = 3,
    this.maxSearchQueryLength = 100,
    this.messageDeleteWindowHours = 1,
  });

  ValidationRulesEntity copyWith({
    int? passwordMinLength,
    int? passwordMaxLength,
    int? shareCodeLength,
    int? minSearchQueryLength,
    int? maxSearchQueryLength,
    int? messageDeleteWindowHours,
  }) {
    return ValidationRulesEntity(
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
      passwordMaxLength: passwordMaxLength ?? this.passwordMaxLength,
      shareCodeLength: shareCodeLength ?? this.shareCodeLength,
      minSearchQueryLength: minSearchQueryLength ?? this.minSearchQueryLength,
      maxSearchQueryLength: maxSearchQueryLength ?? this.maxSearchQueryLength,
      messageDeleteWindowHours:
          messageDeleteWindowHours ?? this.messageDeleteWindowHours,
    );
  }

  @override
  List<Object?> get props => [
    passwordMinLength,
    passwordMaxLength,
    shareCodeLength,
    minSearchQueryLength,
    maxSearchQueryLength,
    messageDeleteWindowHours,
  ];
}

/// Intervalles systeme
class SystemIntervalsEntity extends Equatable {
  final int locationUpdateMinutes;
  final int heartbeatMinutes;
  final int cacheMinutes;
  final int remoteConfigFetchMinutes;
  final int typingIndicatorSeconds;

  const SystemIntervalsEntity({
    this.locationUpdateMinutes = 5,
    this.heartbeatMinutes = 10,
    this.cacheMinutes = 60,
    this.remoteConfigFetchMinutes = 60,
    this.typingIndicatorSeconds = 3,
  });

  SystemIntervalsEntity copyWith({
    int? locationUpdateMinutes,
    int? heartbeatMinutes,
    int? cacheMinutes,
    int? remoteConfigFetchMinutes,
    int? typingIndicatorSeconds,
  }) {
    return SystemIntervalsEntity(
      locationUpdateMinutes:
          locationUpdateMinutes ?? this.locationUpdateMinutes,
      heartbeatMinutes: heartbeatMinutes ?? this.heartbeatMinutes,
      cacheMinutes: cacheMinutes ?? this.cacheMinutes,
      remoteConfigFetchMinutes:
          remoteConfigFetchMinutes ?? this.remoteConfigFetchMinutes,
      typingIndicatorSeconds:
          typingIndicatorSeconds ?? this.typingIndicatorSeconds,
    );
  }

  @override
  List<Object?> get props => [
    locationUpdateMinutes,
    heartbeatMinutes,
    cacheMinutes,
    remoteConfigFetchMinutes,
    typingIndicatorSeconds,
  ];
}

/// URLs systeme et informations de contact
class SystemUrlsEntity extends Equatable {
  final String shareBaseUrl;
  final String supportEmail;
  final String privacyEmail;
  final String bugsEmail;
  final String feedbackEmail;
  final String moderationEmail;
  final String stripeMerchantId;
  final String termsUrl;
  final String privacyUrl;

  const SystemUrlsEntity({
    this.shareBaseUrl = 'https://diasponiger.com/p/',
    this.supportEmail = 'support@diasponiger.com',
    this.privacyEmail = 'privacy@diasponiger.com',
    this.bugsEmail = 'bugs@diasponiger.com',
    this.feedbackEmail = 'feedback@diasponiger.com',
    this.moderationEmail = 'moderation@diasponiger.com',
    this.stripeMerchantId = 'merchant.com.diasponiger',
    this.termsUrl = 'https://diasponiger.com/terms',
    this.privacyUrl = 'https://diasponiger.com/privacy',
  });

  SystemUrlsEntity copyWith({
    String? shareBaseUrl,
    String? supportEmail,
    String? privacyEmail,
    String? bugsEmail,
    String? feedbackEmail,
    String? moderationEmail,
    String? stripeMerchantId,
    String? termsUrl,
    String? privacyUrl,
  }) {
    return SystemUrlsEntity(
      shareBaseUrl: shareBaseUrl ?? this.shareBaseUrl,
      supportEmail: supportEmail ?? this.supportEmail,
      privacyEmail: privacyEmail ?? this.privacyEmail,
      bugsEmail: bugsEmail ?? this.bugsEmail,
      feedbackEmail: feedbackEmail ?? this.feedbackEmail,
      moderationEmail: moderationEmail ?? this.moderationEmail,
      stripeMerchantId: stripeMerchantId ?? this.stripeMerchantId,
      termsUrl: termsUrl ?? this.termsUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
    );
  }

  @override
  List<Object?> get props => [
    shareBaseUrl,
    supportEmail,
    privacyEmail,
    bugsEmail,
    feedbackEmail,
    moderationEmail,
    stripeMerchantId,
    termsUrl,
    privacyUrl,
  ];
}

/// Feature flags
class FeatureFlagsEntity extends Equatable {
  final bool moneyTransfer;
  final bool marketplace;
  final bool businessDirectory;
  final bool events;
  final bool groups;
  final bool embassies;
  final bool audioRooms;
  final bool podcasts;
  final bool feed;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  const FeatureFlagsEntity({
    this.moneyTransfer = false,
    this.marketplace = false,
    this.businessDirectory = true,
    this.events = true,
    this.groups = true,
    this.embassies = true,
    this.audioRooms = false,
    this.podcasts = false,
    this.feed = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,
  });

  FeatureFlagsEntity copyWith({
    bool? moneyTransfer,
    bool? marketplace,
    bool? businessDirectory,
    bool? events,
    bool? groups,
    bool? embassies,
    bool? audioRooms,
    bool? podcasts,
    bool? feed,
    bool? maintenanceMode,
    String? maintenanceMessage,
  }) {
    return FeatureFlagsEntity(
      moneyTransfer: moneyTransfer ?? this.moneyTransfer,
      marketplace: marketplace ?? this.marketplace,
      businessDirectory: businessDirectory ?? this.businessDirectory,
      events: events ?? this.events,
      groups: groups ?? this.groups,
      embassies: embassies ?? this.embassies,
      audioRooms: audioRooms ?? this.audioRooms,
      podcasts: podcasts ?? this.podcasts,
      feed: feed ?? this.feed,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
    );
  }

  @override
  List<Object?> get props => [
    moneyTransfer,
    marketplace,
    businessDirectory,
    events,
    groups,
    embassies,
    audioRooms,
    podcasts,
    feed,
    maintenanceMode,
    maintenanceMessage,
  ];
}

/// Parametres de monetisation et configuration des audio rooms
class AudioRoomsSettingsEntity extends Equatable {
  // Feature toggles
  final bool isEnabled;
  final bool allowPaidRooms;
  final bool allowTips;
  final bool allowReplays;
  final bool allowSubscriptions;
  final bool allowRecording;
  final bool allowVideoRooms;

  // Diaspora-specific feature toggles
  final bool allowCollections;
  final bool allowHeritageContent;
  final bool allowLinkedEvents;
  final bool allowLinkedGroups;
  final bool allowLinkedEmbassies;
  final bool showMultipleTimezones;

  // Diaspora collection settings
  final int collectionCommissionPercent;
  final int minCollectionGoal;
  final int maxCollectionGoal;

  // Default timezones for diaspora display
  final List<String> defaultDisplayTimezones;

  // Heritage content settings
  final bool requireHeritageModeration;
  final List<String> heritageLanguages;
  final List<String> heritageRegions;

  // Commission rates (in percentage)
  final int ticketCommissionPercent;
  final int tipCommissionPercent;
  final int replayCommissionPercent;
  final int subscriptionCommissionPercent;

  // Minimum prices (in cents)
  final int minTicketPrice;
  final int minTipAmount;
  final int minReplayPrice;
  final int minSubscriptionPrice;

  // Maximum prices (in cents)
  final int maxTicketPrice;
  final int maxTipAmount;
  final int maxReplayPrice;
  final int maxSubscriptionPrice;

  // Room limits
  final int maxSpeakers;
  final int maxListeners;
  final int maxRoomDurationMinutes;

  // Recording limits
  final int maxRecordingDurationMinutes;
  final int maxRecordingFileSizeMb;

  // Default currency
  final String defaultCurrency;

  // Supported currencies
  final List<String> supportedCurrencies;

  // Predefined tip amounts
  final List<int> predefinedTipAmountsUSD;
  final List<int> predefinedTipAmountsEUR;
  final List<int> predefinedTipAmountsGBP;
  final List<int> predefinedTipAmountsCAD;
  final List<int> predefinedTipAmountsCHF;
  final List<int> predefinedTipAmountsXOF;

  // Payout settings
  final bool requireStripeConnect;
  final String defaultPayoutCurrency;
  final List<String> supportedPayoutCurrencies;

  // Minimum payout amounts by currency
  final int minPayoutXOF;
  final int minPayoutEUR;
  final int minPayoutUSD;
  final int minPayoutGBP;
  final int minPayoutCAD;
  final int minPayoutCHF;

  // Maximum payout amounts by currency
  final int maxPayoutXOF;
  final int maxPayoutEUR;
  final int maxPayoutUSD;
  final int maxPayoutGBP;
  final int maxPayoutCAD;
  final int maxPayoutCHF;

  const AudioRoomsSettingsEntity({
    this.isEnabled = true,
    this.allowPaidRooms = true,
    this.allowTips = true,
    this.allowReplays = true,
    this.allowSubscriptions = true,
    this.allowRecording = true,
    this.allowVideoRooms = true,
    this.allowCollections = true,
    this.allowHeritageContent = true,
    this.allowLinkedEvents = true,
    this.allowLinkedGroups = true,
    this.allowLinkedEmbassies = true,
    this.showMultipleTimezones = true,
    this.collectionCommissionPercent = 10,
    this.minCollectionGoal = 1000,
    this.maxCollectionGoal = 100000000,
    this.defaultDisplayTimezones = const [
      'Africa/Niamey',
      'Europe/Paris',
      'America/New_York',
      'America/Toronto',
    ],
    this.requireHeritageModeration = true,
    this.heritageLanguages = const [
      'Hausa',
      'Zarma',
      'Fulfulde',
      'Tamashek',
      'Kanuri',
      'Arabic',
      'French',
    ],
    this.heritageRegions = const [
      'Niamey',
      'Zinder',
      'Maradi',
      'Tahoua',
      'Agadez',
      'Dosso',
      'Diffa',
      'Tillabéri',
    ],
    this.ticketCommissionPercent = 15,
    this.tipCommissionPercent = 20,
    this.replayCommissionPercent = 15,
    this.subscriptionCommissionPercent = 20,
    this.minTicketPrice = 500,
    this.minTipAmount = 100,
    this.minReplayPrice = 500,
    this.minSubscriptionPrice = 1000,
    this.maxTicketPrice = 10000000,
    this.maxTipAmount = 1000000,
    this.maxReplayPrice = 5000000,
    this.maxSubscriptionPrice = 1000000,
    this.maxSpeakers = 10,
    this.maxListeners = 1000,
    this.maxRoomDurationMinutes = 180,
    this.maxRecordingDurationMinutes = 180,
    this.maxRecordingFileSizeMb = 500,
    this.defaultCurrency = 'USD',
    this.supportedCurrencies = const ['XOF', 'EUR', 'USD', 'GBP', 'CAD', 'CHF'],
    this.predefinedTipAmountsUSD = const [100, 200, 500, 1000, 2500],
    this.predefinedTipAmountsEUR = const [100, 200, 500, 1000, 2300],
    this.predefinedTipAmountsGBP = const [100, 200, 400, 800, 2000],
    this.predefinedTipAmountsCAD = const [150, 300, 700, 1400, 3500],
    this.predefinedTipAmountsCHF = const [100, 200, 500, 900, 2200],
    this.predefinedTipAmountsXOF = const [
      50000,
      100000,
      300000,
      600000,
      1500000,
    ],
    this.requireStripeConnect = true,
    this.defaultPayoutCurrency = 'XOF',
    this.supportedPayoutCurrencies = const [
      'XOF',
      'EUR',
      'USD',
      'GBP',
      'CAD',
      'CHF',
    ],
    this.minPayoutXOF = 500000,
    this.minPayoutEUR = 1000,
    this.minPayoutUSD = 1000,
    this.minPayoutGBP = 1000,
    this.minPayoutCAD = 1500,
    this.minPayoutCHF = 1000,
    this.maxPayoutXOF = 100000000,
    this.maxPayoutEUR = 1000000,
    this.maxPayoutUSD = 1000000,
    this.maxPayoutGBP = 1000000,
    this.maxPayoutCAD = 1500000,
    this.maxPayoutCHF = 1000000,
  });

  /// Obtenir le taux de commission pour un type specifique
  int getCommissionRate(String type) {
    return switch (type) {
      'ticket' => ticketCommissionPercent,
      'tip' => tipCommissionPercent,
      'replay' => replayCommissionPercent,
      'subscription' => subscriptionCommissionPercent,
      _ => 15,
    };
  }

  /// Calculer le montant de la commission
  int calculateCommission(int amount, String type) {
    final rate = getCommissionRate(type);
    return (amount * rate / 100).round();
  }

  /// Calculer le montant pour le createur apres commission
  int calculateCreatorAmount(int amount, String type) {
    return amount - calculateCommission(amount, type);
  }

  /// Obtenir les montants de pourboire predefinis pour une devise
  List<int> getPredefinedTipAmounts(String currency) {
    return switch (currency.toUpperCase()) {
      'EUR' => predefinedTipAmountsEUR,
      'USD' => predefinedTipAmountsUSD,
      'GBP' => predefinedTipAmountsGBP,
      'CAD' => predefinedTipAmountsCAD,
      'CHF' => predefinedTipAmountsCHF,
      _ => predefinedTipAmountsXOF,
    };
  }

  /// Obtenir le montant minimum de paiement pour une devise
  int getMinPayoutAmount(String currency) {
    return switch (currency.toUpperCase()) {
      'XOF' => minPayoutXOF,
      'EUR' => minPayoutEUR,
      'USD' => minPayoutUSD,
      'GBP' => minPayoutGBP,
      'CAD' => minPayoutCAD,
      'CHF' => minPayoutCHF,
      _ => minPayoutXOF,
    };
  }

  /// Obtenir le montant maximum de paiement pour une devise
  int getMaxPayoutAmount(String currency) {
    return switch (currency.toUpperCase()) {
      'XOF' => maxPayoutXOF,
      'EUR' => maxPayoutEUR,
      'USD' => maxPayoutUSD,
      'GBP' => maxPayoutGBP,
      'CAD' => maxPayoutCAD,
      'CHF' => maxPayoutCHF,
      _ => maxPayoutXOF,
    };
  }

  /// Verifier si le montant atteint le minimum de paiement
  bool meetsMinimumPayout(int amount, String currency) {
    return amount >= getMinPayoutAmount(currency);
  }

  /// Verifier si le montant est dans les limites de paiement
  bool isWithinPayoutLimits(int amount, String currency) {
    return amount >= getMinPayoutAmount(currency) &&
        amount <= getMaxPayoutAmount(currency);
  }

  /// Verifier si une devise est supportee pour les paiements
  bool isPayoutCurrencySupported(String currency) {
    return supportedPayoutCurrencies.contains(currency.toUpperCase());
  }

  AudioRoomsSettingsEntity copyWith({
    bool? isEnabled,
    bool? allowPaidRooms,
    bool? allowTips,
    bool? allowReplays,
    bool? allowSubscriptions,
    bool? allowRecording,
    bool? allowVideoRooms,
    bool? allowCollections,
    bool? allowHeritageContent,
    bool? allowLinkedEvents,
    bool? allowLinkedGroups,
    bool? allowLinkedEmbassies,
    bool? showMultipleTimezones,
    int? collectionCommissionPercent,
    int? minCollectionGoal,
    int? maxCollectionGoal,
    List<String>? defaultDisplayTimezones,
    bool? requireHeritageModeration,
    List<String>? heritageLanguages,
    List<String>? heritageRegions,
    int? ticketCommissionPercent,
    int? tipCommissionPercent,
    int? replayCommissionPercent,
    int? subscriptionCommissionPercent,
    int? minTicketPrice,
    int? minTipAmount,
    int? minReplayPrice,
    int? minSubscriptionPrice,
    int? maxTicketPrice,
    int? maxTipAmount,
    int? maxReplayPrice,
    int? maxSubscriptionPrice,
    int? maxSpeakers,
    int? maxListeners,
    int? maxRoomDurationMinutes,
    int? maxRecordingDurationMinutes,
    int? maxRecordingFileSizeMb,
    String? defaultCurrency,
    List<String>? supportedCurrencies,
    List<int>? predefinedTipAmountsUSD,
    List<int>? predefinedTipAmountsEUR,
    List<int>? predefinedTipAmountsGBP,
    List<int>? predefinedTipAmountsCAD,
    List<int>? predefinedTipAmountsCHF,
    List<int>? predefinedTipAmountsXOF,
    bool? requireStripeConnect,
    String? defaultPayoutCurrency,
    List<String>? supportedPayoutCurrencies,
    int? minPayoutXOF,
    int? minPayoutEUR,
    int? minPayoutUSD,
    int? minPayoutGBP,
    int? minPayoutCAD,
    int? minPayoutCHF,
    int? maxPayoutXOF,
    int? maxPayoutEUR,
    int? maxPayoutUSD,
    int? maxPayoutGBP,
    int? maxPayoutCAD,
    int? maxPayoutCHF,
  }) {
    return AudioRoomsSettingsEntity(
      isEnabled: isEnabled ?? this.isEnabled,
      allowPaidRooms: allowPaidRooms ?? this.allowPaidRooms,
      allowTips: allowTips ?? this.allowTips,
      allowReplays: allowReplays ?? this.allowReplays,
      allowSubscriptions: allowSubscriptions ?? this.allowSubscriptions,
      allowRecording: allowRecording ?? this.allowRecording,
      allowVideoRooms: allowVideoRooms ?? this.allowVideoRooms,
      allowCollections: allowCollections ?? this.allowCollections,
      allowHeritageContent: allowHeritageContent ?? this.allowHeritageContent,
      allowLinkedEvents: allowLinkedEvents ?? this.allowLinkedEvents,
      allowLinkedGroups: allowLinkedGroups ?? this.allowLinkedGroups,
      allowLinkedEmbassies: allowLinkedEmbassies ?? this.allowLinkedEmbassies,
      showMultipleTimezones:
          showMultipleTimezones ?? this.showMultipleTimezones,
      collectionCommissionPercent:
          collectionCommissionPercent ?? this.collectionCommissionPercent,
      minCollectionGoal: minCollectionGoal ?? this.minCollectionGoal,
      maxCollectionGoal: maxCollectionGoal ?? this.maxCollectionGoal,
      defaultDisplayTimezones:
          defaultDisplayTimezones ?? this.defaultDisplayTimezones,
      requireHeritageModeration:
          requireHeritageModeration ?? this.requireHeritageModeration,
      heritageLanguages: heritageLanguages ?? this.heritageLanguages,
      heritageRegions: heritageRegions ?? this.heritageRegions,
      ticketCommissionPercent:
          ticketCommissionPercent ?? this.ticketCommissionPercent,
      tipCommissionPercent: tipCommissionPercent ?? this.tipCommissionPercent,
      replayCommissionPercent:
          replayCommissionPercent ?? this.replayCommissionPercent,
      subscriptionCommissionPercent:
          subscriptionCommissionPercent ?? this.subscriptionCommissionPercent,
      minTicketPrice: minTicketPrice ?? this.minTicketPrice,
      minTipAmount: minTipAmount ?? this.minTipAmount,
      minReplayPrice: minReplayPrice ?? this.minReplayPrice,
      minSubscriptionPrice: minSubscriptionPrice ?? this.minSubscriptionPrice,
      maxTicketPrice: maxTicketPrice ?? this.maxTicketPrice,
      maxTipAmount: maxTipAmount ?? this.maxTipAmount,
      maxReplayPrice: maxReplayPrice ?? this.maxReplayPrice,
      maxSubscriptionPrice: maxSubscriptionPrice ?? this.maxSubscriptionPrice,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      maxListeners: maxListeners ?? this.maxListeners,
      maxRoomDurationMinutes:
          maxRoomDurationMinutes ?? this.maxRoomDurationMinutes,
      maxRecordingDurationMinutes:
          maxRecordingDurationMinutes ?? this.maxRecordingDurationMinutes,
      maxRecordingFileSizeMb:
          maxRecordingFileSizeMb ?? this.maxRecordingFileSizeMb,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
      predefinedTipAmountsUSD:
          predefinedTipAmountsUSD ?? this.predefinedTipAmountsUSD,
      predefinedTipAmountsEUR:
          predefinedTipAmountsEUR ?? this.predefinedTipAmountsEUR,
      predefinedTipAmountsGBP:
          predefinedTipAmountsGBP ?? this.predefinedTipAmountsGBP,
      predefinedTipAmountsCAD:
          predefinedTipAmountsCAD ?? this.predefinedTipAmountsCAD,
      predefinedTipAmountsCHF:
          predefinedTipAmountsCHF ?? this.predefinedTipAmountsCHF,
      predefinedTipAmountsXOF:
          predefinedTipAmountsXOF ?? this.predefinedTipAmountsXOF,
      requireStripeConnect: requireStripeConnect ?? this.requireStripeConnect,
      defaultPayoutCurrency:
          defaultPayoutCurrency ?? this.defaultPayoutCurrency,
      supportedPayoutCurrencies:
          supportedPayoutCurrencies ?? this.supportedPayoutCurrencies,
      minPayoutXOF: minPayoutXOF ?? this.minPayoutXOF,
      minPayoutEUR: minPayoutEUR ?? this.minPayoutEUR,
      minPayoutUSD: minPayoutUSD ?? this.minPayoutUSD,
      minPayoutGBP: minPayoutGBP ?? this.minPayoutGBP,
      minPayoutCAD: minPayoutCAD ?? this.minPayoutCAD,
      minPayoutCHF: minPayoutCHF ?? this.minPayoutCHF,
      maxPayoutXOF: maxPayoutXOF ?? this.maxPayoutXOF,
      maxPayoutEUR: maxPayoutEUR ?? this.maxPayoutEUR,
      maxPayoutUSD: maxPayoutUSD ?? this.maxPayoutUSD,
      maxPayoutGBP: maxPayoutGBP ?? this.maxPayoutGBP,
      maxPayoutCAD: maxPayoutCAD ?? this.maxPayoutCAD,
      maxPayoutCHF: maxPayoutCHF ?? this.maxPayoutCHF,
    );
  }

  @override
  List<Object?> get props => [
    isEnabled,
    allowPaidRooms,
    allowTips,
    allowReplays,
    allowSubscriptions,
    allowRecording,
    allowVideoRooms,
    allowCollections,
    allowHeritageContent,
    allowLinkedEvents,
    allowLinkedGroups,
    allowLinkedEmbassies,
    showMultipleTimezones,
    collectionCommissionPercent,
    minCollectionGoal,
    maxCollectionGoal,
    defaultDisplayTimezones,
    requireHeritageModeration,
    heritageLanguages,
    heritageRegions,
    ticketCommissionPercent,
    tipCommissionPercent,
    replayCommissionPercent,
    subscriptionCommissionPercent,
    minTicketPrice,
    minTipAmount,
    minReplayPrice,
    minSubscriptionPrice,
    maxTicketPrice,
    maxTipAmount,
    maxReplayPrice,
    maxSubscriptionPrice,
    maxSpeakers,
    maxListeners,
    maxRoomDurationMinutes,
    maxRecordingDurationMinutes,
    maxRecordingFileSizeMb,
    defaultCurrency,
    supportedCurrencies,
    predefinedTipAmountsUSD,
    predefinedTipAmountsEUR,
    predefinedTipAmountsGBP,
    predefinedTipAmountsCAD,
    predefinedTipAmountsCHF,
    predefinedTipAmountsXOF,
    requireStripeConnect,
    defaultPayoutCurrency,
    supportedPayoutCurrencies,
    minPayoutXOF,
    minPayoutEUR,
    minPayoutUSD,
    minPayoutGBP,
    minPayoutCAD,
    minPayoutCHF,
    maxPayoutXOF,
    maxPayoutEUR,
    maxPayoutUSD,
    maxPayoutGBP,
    maxPayoutCAD,
    maxPayoutCHF,
  ];
}
