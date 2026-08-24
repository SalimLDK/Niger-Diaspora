import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_settings_entity.dart';
import 'audio_rooms_settings_model.dart';

/// Model for app settings with Firebase serialization
class AppSettingsModel {
  final FeeSettingsModel fees;
  final BoostPricingModel boostPricing;
  final TaxRatesModel taxRates;
  final ExchangeRatesModel exchangeRates;
  final MediaLimitsModel mediaLimits;
  final ValidationRulesModel validation;
  final SystemIntervalsModel intervals;
  final SystemUrlsModel urls;
  final FeatureFlagsModel featureFlags;

  /// Réglages des salons audio. Ce champ manquait : l'entité correspondante
  /// était consommée par l'app mais jamais désérialisée, donc figée sur ses
  /// valeurs par défaut.
  final AudioRoomsSettingsEntity audioRooms;

  final DateTime? lastUpdated;
  final String? updatedBy;

  AppSettingsModel({
    FeeSettingsModel? fees,
    BoostPricingModel? boostPricing,
    TaxRatesModel? taxRates,
    ExchangeRatesModel? exchangeRates,
    MediaLimitsModel? mediaLimits,
    ValidationRulesModel? validation,
    SystemIntervalsModel? intervals,
    SystemUrlsModel? urls,
    FeatureFlagsModel? featureFlags,
    AudioRoomsSettingsEntity? audioRooms,
    this.lastUpdated,
    this.updatedBy,
  }) : fees = fees ?? FeeSettingsModel(),
       boostPricing = boostPricing ?? BoostPricingModel(),
       taxRates = taxRates ?? TaxRatesModel(),
       exchangeRates = exchangeRates ?? ExchangeRatesModel(),
       mediaLimits = mediaLimits ?? MediaLimitsModel(),
       validation = validation ?? ValidationRulesModel(),
       intervals = intervals ?? SystemIntervalsModel(),
       urls = urls ?? SystemUrlsModel(),
       featureFlags = featureFlags ?? FeatureFlagsModel(),
       audioRooms = audioRooms ?? const AudioRoomsSettingsEntity();

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppSettingsModel.fromJson(data);
  }

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      fees:
          json['fees'] != null
              ? FeeSettingsModel.fromJson(json['fees'] as Map<String, dynamic>)
              : null,
      boostPricing:
          json['boostPricing'] != null
              ? BoostPricingModel.fromJson(
                json['boostPricing'] as Map<String, dynamic>,
              )
              : null,
      taxRates:
          json['taxRates'] != null
              ? TaxRatesModel.fromJson(json['taxRates'] as Map<String, dynamic>)
              : null,
      exchangeRates:
          json['exchangeRates'] != null
              ? ExchangeRatesModel.fromJson(
                json['exchangeRates'] as Map<String, dynamic>,
              )
              : null,
      mediaLimits:
          json['mediaLimits'] != null
              ? MediaLimitsModel.fromJson(
                json['mediaLimits'] as Map<String, dynamic>,
              )
              : null,
      validation:
          json['validation'] != null
              ? ValidationRulesModel.fromJson(
                json['validation'] as Map<String, dynamic>,
              )
              : null,
      intervals:
          json['intervals'] != null
              ? SystemIntervalsModel.fromJson(
                json['intervals'] as Map<String, dynamic>,
              )
              : null,
      urls:
          json['urls'] != null
              ? SystemUrlsModel.fromJson(json['urls'] as Map<String, dynamic>)
              : null,
      featureFlags:
          json['featureFlags'] != null
              ? FeatureFlagsModel.fromJson(
                json['featureFlags'] as Map<String, dynamic>,
              )
              : null,
      audioRooms:
          json['audioRooms'] != null
              ? AudioRoomsSettingsModel.fromJson(
                json['audioRooms'] as Map<String, dynamic>,
              )
              : null,
      lastUpdated:
          json['lastUpdated'] is Timestamp
              ? (json['lastUpdated'] as Timestamp).toDate()
              : null,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'fees': fees.toJson(),
    'boostPricing': boostPricing.toJson(),
    'taxRates': taxRates.toJson(),
    'exchangeRates': exchangeRates.toJson(),
    'mediaLimits': mediaLimits.toJson(),
    'validation': validation.toJson(),
    'intervals': intervals.toJson(),
    'urls': urls.toJson(),
    'featureFlags': featureFlags.toJson(),
    'audioRooms': AudioRoomsSettingsModel.toJson(audioRooms),
    'lastUpdated':
        lastUpdated != null
            ? Timestamp.fromDate(lastUpdated!)
            : FieldValue.serverTimestamp(),
    'updatedBy': updatedBy,
  };

  AppSettingsEntity toEntity() => AppSettingsEntity(
    fees: fees.toEntity(),
    boostPricing: boostPricing.toEntity(),
    taxRates: taxRates.toEntity(),
    exchangeRates: exchangeRates.toEntity(),
    mediaLimits: mediaLimits.toEntity(),
    validation: validation.toEntity(),
    intervals: intervals.toEntity(),
    urls: urls.toEntity(),
    featureFlags: featureFlags.toEntity(),
    audioRooms: audioRooms,
    lastUpdated: lastUpdated,
    updatedBy: updatedBy,
  );

  static AppSettingsModel fromEntity(AppSettingsEntity entity) =>
      AppSettingsModel(
        fees: FeeSettingsModel.fromEntity(entity.fees),
        boostPricing: BoostPricingModel.fromEntity(entity.boostPricing),
        taxRates: TaxRatesModel.fromEntity(entity.taxRates),
        exchangeRates: ExchangeRatesModel.fromEntity(entity.exchangeRates),
        mediaLimits: MediaLimitsModel.fromEntity(entity.mediaLimits),
        validation: ValidationRulesModel.fromEntity(entity.validation),
        intervals: SystemIntervalsModel.fromEntity(entity.intervals),
        urls: SystemUrlsModel.fromEntity(entity.urls),
        featureFlags: FeatureFlagsModel.fromEntity(entity.featureFlags),
        audioRooms: entity.audioRooms,
        lastUpdated: entity.lastUpdated,
        updatedBy: entity.updatedBy,
      );
}

// ============================================================================
// FEE SETTINGS
// ============================================================================

class FeeSettingsModel {
  final double transferFeePercent;
  final double transferFeeMin;
  final double transferFeeMax;
  final double marketplaceFeePercent;
  final double marketplaceFeeMin;
  final double marketplaceFeeMax;

  FeeSettingsModel({
    this.transferFeePercent = 0.025,
    this.transferFeeMin = 500,
    this.transferFeeMax = 10000,
    this.marketplaceFeePercent = 0.05,
    this.marketplaceFeeMin = 0,
    this.marketplaceFeeMax = 50000,
  });

  factory FeeSettingsModel.fromJson(Map<String, dynamic> json) =>
      FeeSettingsModel(
        transferFeePercent:
            (json['transferFeePercent'] as num?)?.toDouble() ?? 0.025,
        transferFeeMin: (json['transferFeeMin'] as num?)?.toDouble() ?? 500,
        transferFeeMax: (json['transferFeeMax'] as num?)?.toDouble() ?? 10000,
        marketplaceFeePercent:
            (json['marketplaceFeePercent'] as num?)?.toDouble() ?? 0.05,
        marketplaceFeeMin: (json['marketplaceFeeMin'] as num?)?.toDouble() ?? 0,
        marketplaceFeeMax:
            (json['marketplaceFeeMax'] as num?)?.toDouble() ?? 50000,
      );

  Map<String, dynamic> toJson() => {
    'transferFeePercent': transferFeePercent,
    'transferFeeMin': transferFeeMin,
    'transferFeeMax': transferFeeMax,
    'marketplaceFeePercent': marketplaceFeePercent,
    'marketplaceFeeMin': marketplaceFeeMin,
    'marketplaceFeeMax': marketplaceFeeMax,
  };

  FeeSettingsEntity toEntity() => FeeSettingsEntity(
    transferFeePercent: transferFeePercent,
    transferFeeMin: transferFeeMin,
    transferFeeMax: transferFeeMax,
    marketplaceFeePercent: marketplaceFeePercent,
    marketplaceFeeMin: marketplaceFeeMin,
    marketplaceFeeMax: marketplaceFeeMax,
  );

  static FeeSettingsModel fromEntity(FeeSettingsEntity entity) =>
      FeeSettingsModel(
        transferFeePercent: entity.transferFeePercent,
        transferFeeMin: entity.transferFeeMin,
        transferFeeMax: entity.transferFeeMax,
        marketplaceFeePercent: entity.marketplaceFeePercent,
        marketplaceFeeMin: entity.marketplaceFeeMin,
        marketplaceFeeMax: entity.marketplaceFeeMax,
      );
}

// ============================================================================
// BOOST PRICING
// ============================================================================

class BoostPricingModel {
  final double standardBase;
  final double featuredBase;
  final double premiumBase;
  final double multiplier7Days;
  final double multiplier30Days;
  final double multiplier90Days;

  BoostPricingModel({
    this.standardBase = 5000,
    this.featuredBase = 10000,
    this.premiumBase = 25000,
    this.multiplier7Days = 1.0,
    this.multiplier30Days = 3.0,
    this.multiplier90Days = 7.0,
  });

  factory BoostPricingModel.fromJson(Map<String, dynamic> json) =>
      BoostPricingModel(
        standardBase: (json['standardBase'] as num?)?.toDouble() ?? 5000,
        featuredBase: (json['featuredBase'] as num?)?.toDouble() ?? 10000,
        premiumBase: (json['premiumBase'] as num?)?.toDouble() ?? 25000,
        multiplier7Days: (json['multiplier7Days'] as num?)?.toDouble() ?? 1.0,
        multiplier30Days: (json['multiplier30Days'] as num?)?.toDouble() ?? 3.0,
        multiplier90Days: (json['multiplier90Days'] as num?)?.toDouble() ?? 7.0,
      );

  Map<String, dynamic> toJson() => {
    'standardBase': standardBase,
    'featuredBase': featuredBase,
    'premiumBase': premiumBase,
    'multiplier7Days': multiplier7Days,
    'multiplier30Days': multiplier30Days,
    'multiplier90Days': multiplier90Days,
  };

  BoostPricingEntity toEntity() => BoostPricingEntity(
    standardBase: standardBase,
    featuredBase: featuredBase,
    premiumBase: premiumBase,
    multiplier7Days: multiplier7Days,
    multiplier30Days: multiplier30Days,
    multiplier90Days: multiplier90Days,
  );

  static BoostPricingModel fromEntity(BoostPricingEntity entity) =>
      BoostPricingModel(
        standardBase: entity.standardBase,
        featuredBase: entity.featuredBase,
        premiumBase: entity.premiumBase,
        multiplier7Days: entity.multiplier7Days,
        multiplier30Days: entity.multiplier30Days,
        multiplier90Days: entity.multiplier90Days,
      );
}

// ============================================================================
// TAX RATES
// ============================================================================

class TaxRatesModel {
  final double alimentation;
  final double artisanat;
  final double standard;
  final double electronique;
  final double vetements;
  final double services;
  final double immobilier;

  TaxRatesModel({
    this.alimentation = 0.0,
    this.artisanat = 0.10,
    this.standard = 0.19,
    this.electronique = 0.19,
    this.vetements = 0.19,
    this.services = 0.0,
    this.immobilier = 0.0,
  });

  factory TaxRatesModel.fromJson(Map<String, dynamic> json) => TaxRatesModel(
    alimentation: (json['alimentation'] as num?)?.toDouble() ?? 0.0,
    artisanat: (json['artisanat'] as num?)?.toDouble() ?? 0.10,
    standard: (json['standard'] as num?)?.toDouble() ?? 0.19,
    electronique: (json['electronique'] as num?)?.toDouble() ?? 0.19,
    vetements: (json['vetements'] as num?)?.toDouble() ?? 0.19,
    services: (json['services'] as num?)?.toDouble() ?? 0.0,
    immobilier: (json['immobilier'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'alimentation': alimentation,
    'artisanat': artisanat,
    'standard': standard,
    'electronique': electronique,
    'vetements': vetements,
    'services': services,
    'immobilier': immobilier,
  };

  TaxRatesEntity toEntity() => TaxRatesEntity(
    alimentation: alimentation,
    artisanat: artisanat,
    standard: standard,
    electronique: electronique,
    vetements: vetements,
    services: services,
    immobilier: immobilier,
  );

  static TaxRatesModel fromEntity(TaxRatesEntity entity) => TaxRatesModel(
    alimentation: entity.alimentation,
    artisanat: entity.artisanat,
    standard: entity.standard,
    electronique: entity.electronique,
    vetements: entity.vetements,
    services: entity.services,
    immobilier: entity.immobilier,
  );
}

// ============================================================================
// EXCHANGE RATES
// ============================================================================

class ExchangeRatesModel {
  final double eurToXof;
  final double usdToXof;
  final double gbpToXof;
  final double cadToXof;
  final double chfToXof;
  final DateTime? lastUpdated;
  final String? exchangeRateApiKey;
  final int refreshIntervalMinutes;

  ExchangeRatesModel({
    this.eurToXof = 655.957,
    this.usdToXof = 615.0,
    this.gbpToXof = 770.0,
    this.cadToXof = 455.0,
    this.chfToXof = 690.0,
    this.lastUpdated,
    this.exchangeRateApiKey,
    this.refreshIntervalMinutes = 60,
  });

  factory ExchangeRatesModel.fromJson(Map<String, dynamic> json) =>
      ExchangeRatesModel(
        eurToXof: (json['eurToXof'] as num?)?.toDouble() ?? 655.957,
        usdToXof: (json['usdToXof'] as num?)?.toDouble() ?? 615.0,
        gbpToXof: (json['gbpToXof'] as num?)?.toDouble() ?? 770.0,
        cadToXof: (json['cadToXof'] as num?)?.toDouble() ?? 455.0,
        chfToXof: (json['chfToXof'] as num?)?.toDouble() ?? 690.0,
        lastUpdated:
            json['lastUpdated'] is Timestamp
                ? (json['lastUpdated'] as Timestamp).toDate()
                : null,
        exchangeRateApiKey: json['exchangeRateApiKey'] as String?,
        refreshIntervalMinutes: json['refreshIntervalMinutes'] as int? ?? 60,
      );

  Map<String, dynamic> toJson() => {
    'eurToXof': eurToXof,
    'usdToXof': usdToXof,
    'gbpToXof': gbpToXof,
    'cadToXof': cadToXof,
    'chfToXof': chfToXof,
    'lastUpdated':
        lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    'exchangeRateApiKey': exchangeRateApiKey,
    'refreshIntervalMinutes': refreshIntervalMinutes,
  };

  ExchangeRatesEntity toEntity() => ExchangeRatesEntity(
    eurToXof: eurToXof,
    usdToXof: usdToXof,
    gbpToXof: gbpToXof,
    cadToXof: cadToXof,
    chfToXof: chfToXof,
    lastUpdated: lastUpdated,
    exchangeRateApiKey: exchangeRateApiKey,
    refreshIntervalMinutes: refreshIntervalMinutes,
  );

  static ExchangeRatesModel fromEntity(ExchangeRatesEntity entity) =>
      ExchangeRatesModel(
        eurToXof: entity.eurToXof,
        usdToXof: entity.usdToXof,
        gbpToXof: entity.gbpToXof,
        cadToXof: entity.cadToXof,
        chfToXof: entity.chfToXof,
        lastUpdated: entity.lastUpdated,
        exchangeRateApiKey: entity.exchangeRateApiKey,
        refreshIntervalMinutes: entity.refreshIntervalMinutes,
      );
}

// ============================================================================
// MEDIA LIMITS
// ============================================================================

class MediaLimitsModel {
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

  MediaLimitsModel({
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

  factory MediaLimitsModel.fromJson(Map<String, dynamic> json) =>
      MediaLimitsModel(
        imageMaxWidth: json['imageMaxWidth'] as int? ?? 1024,
        imageMaxHeight: json['imageMaxHeight'] as int? ?? 1024,
        imageQuality: json['imageQuality'] as int? ?? 85,
        maxImagesPerUpload: json['maxImagesPerUpload'] as int? ?? 5,
        minWidthForCompression: json['minWidthForCompression'] as int? ?? 800,
        messageMaxChars: json['messageMaxChars'] as int? ?? 2000,
        messageCharCountThreshold:
            json['messageCharCountThreshold'] as int? ?? 200,
        maxImageSizeMb: json['maxImageSizeMb'] as int? ?? 10,
        maxVideoSizeMb: json['maxVideoSizeMb'] as int? ?? 50,
        maxDocumentSizeMb: json['maxDocumentSizeMb'] as int? ?? 25,
        maxAudioDurationSeconds: json['maxAudioDurationSeconds'] as int? ?? 300,
      );

  Map<String, dynamic> toJson() => {
    'imageMaxWidth': imageMaxWidth,
    'imageMaxHeight': imageMaxHeight,
    'imageQuality': imageQuality,
    'maxImagesPerUpload': maxImagesPerUpload,
    'minWidthForCompression': minWidthForCompression,
    'messageMaxChars': messageMaxChars,
    'messageCharCountThreshold': messageCharCountThreshold,
    'maxImageSizeMb': maxImageSizeMb,
    'maxVideoSizeMb': maxVideoSizeMb,
    'maxDocumentSizeMb': maxDocumentSizeMb,
    'maxAudioDurationSeconds': maxAudioDurationSeconds,
  };

  MediaLimitsEntity toEntity() => MediaLimitsEntity(
    imageMaxWidth: imageMaxWidth,
    imageMaxHeight: imageMaxHeight,
    imageQuality: imageQuality,
    maxImagesPerUpload: maxImagesPerUpload,
    minWidthForCompression: minWidthForCompression,
    messageMaxChars: messageMaxChars,
    messageCharCountThreshold: messageCharCountThreshold,
    maxImageSizeMb: maxImageSizeMb,
    maxVideoSizeMb: maxVideoSizeMb,
    maxDocumentSizeMb: maxDocumentSizeMb,
    maxAudioDurationSeconds: maxAudioDurationSeconds,
  );

  static MediaLimitsModel fromEntity(MediaLimitsEntity entity) =>
      MediaLimitsModel(
        imageMaxWidth: entity.imageMaxWidth,
        imageMaxHeight: entity.imageMaxHeight,
        imageQuality: entity.imageQuality,
        maxImagesPerUpload: entity.maxImagesPerUpload,
        minWidthForCompression: entity.minWidthForCompression,
        messageMaxChars: entity.messageMaxChars,
        messageCharCountThreshold: entity.messageCharCountThreshold,
        maxImageSizeMb: entity.maxImageSizeMb,
        maxVideoSizeMb: entity.maxVideoSizeMb,
        maxDocumentSizeMb: entity.maxDocumentSizeMb,
        maxAudioDurationSeconds: entity.maxAudioDurationSeconds,
      );
}

// ============================================================================
// VALIDATION RULES
// ============================================================================

class ValidationRulesModel {
  final int passwordMinLength;
  final int passwordMaxLength;
  final int shareCodeLength;
  final int minSearchQueryLength;
  final int maxSearchQueryLength;
  final int messageDeleteWindowHours;

  ValidationRulesModel({
    this.passwordMinLength = 6,
    this.passwordMaxLength = 128,
    this.shareCodeLength = 8,
    this.minSearchQueryLength = 3,
    this.maxSearchQueryLength = 100,
    this.messageDeleteWindowHours = 1,
  });

  factory ValidationRulesModel.fromJson(Map<String, dynamic> json) =>
      ValidationRulesModel(
        passwordMinLength: json['passwordMinLength'] as int? ?? 6,
        passwordMaxLength: json['passwordMaxLength'] as int? ?? 128,
        shareCodeLength: json['shareCodeLength'] as int? ?? 8,
        minSearchQueryLength: json['minSearchQueryLength'] as int? ?? 3,
        maxSearchQueryLength: json['maxSearchQueryLength'] as int? ?? 100,
        messageDeleteWindowHours: json['messageDeleteWindowHours'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
    'passwordMinLength': passwordMinLength,
    'passwordMaxLength': passwordMaxLength,
    'shareCodeLength': shareCodeLength,
    'minSearchQueryLength': minSearchQueryLength,
    'maxSearchQueryLength': maxSearchQueryLength,
    'messageDeleteWindowHours': messageDeleteWindowHours,
  };

  ValidationRulesEntity toEntity() => ValidationRulesEntity(
    passwordMinLength: passwordMinLength,
    passwordMaxLength: passwordMaxLength,
    shareCodeLength: shareCodeLength,
    minSearchQueryLength: minSearchQueryLength,
    maxSearchQueryLength: maxSearchQueryLength,
    messageDeleteWindowHours: messageDeleteWindowHours,
  );

  static ValidationRulesModel fromEntity(ValidationRulesEntity entity) =>
      ValidationRulesModel(
        passwordMinLength: entity.passwordMinLength,
        passwordMaxLength: entity.passwordMaxLength,
        shareCodeLength: entity.shareCodeLength,
        minSearchQueryLength: entity.minSearchQueryLength,
        maxSearchQueryLength: entity.maxSearchQueryLength,
        messageDeleteWindowHours: entity.messageDeleteWindowHours,
      );
}

// ============================================================================
// SYSTEM INTERVALS
// ============================================================================

class SystemIntervalsModel {
  final int locationUpdateMinutes;
  final int heartbeatMinutes;
  final int cacheMinutes;
  final int remoteConfigFetchMinutes;
  final int typingIndicatorSeconds;

  SystemIntervalsModel({
    this.locationUpdateMinutes = 5,
    this.heartbeatMinutes = 10,
    this.cacheMinutes = 60,
    this.remoteConfigFetchMinutes = 60,
    this.typingIndicatorSeconds = 3,
  });

  factory SystemIntervalsModel.fromJson(Map<String, dynamic> json) =>
      SystemIntervalsModel(
        locationUpdateMinutes: json['locationUpdateMinutes'] as int? ?? 5,
        heartbeatMinutes: json['heartbeatMinutes'] as int? ?? 10,
        cacheMinutes: json['cacheMinutes'] as int? ?? 60,
        remoteConfigFetchMinutes:
            json['remoteConfigFetchMinutes'] as int? ?? 60,
        typingIndicatorSeconds: json['typingIndicatorSeconds'] as int? ?? 3,
      );

  Map<String, dynamic> toJson() => {
    'locationUpdateMinutes': locationUpdateMinutes,
    'heartbeatMinutes': heartbeatMinutes,
    'cacheMinutes': cacheMinutes,
    'remoteConfigFetchMinutes': remoteConfigFetchMinutes,
    'typingIndicatorSeconds': typingIndicatorSeconds,
  };

  SystemIntervalsEntity toEntity() => SystemIntervalsEntity(
    locationUpdateMinutes: locationUpdateMinutes,
    heartbeatMinutes: heartbeatMinutes,
    cacheMinutes: cacheMinutes,
    remoteConfigFetchMinutes: remoteConfigFetchMinutes,
    typingIndicatorSeconds: typingIndicatorSeconds,
  );

  static SystemIntervalsModel fromEntity(SystemIntervalsEntity entity) =>
      SystemIntervalsModel(
        locationUpdateMinutes: entity.locationUpdateMinutes,
        heartbeatMinutes: entity.heartbeatMinutes,
        cacheMinutes: entity.cacheMinutes,
        remoteConfigFetchMinutes: entity.remoteConfigFetchMinutes,
        typingIndicatorSeconds: entity.typingIndicatorSeconds,
      );
}

// ============================================================================
// SYSTEM URLS
// ============================================================================

class SystemUrlsModel {
  final String shareBaseUrl;
  final String supportEmail;
  final String supportPhone;
  final String privacyEmail;
  final String bugsEmail;
  final String feedbackEmail;
  final String moderationEmail;
  final String stripeMerchantId;
  final String termsUrl;
  final String privacyUrl;

  SystemUrlsModel({
    this.shareBaseUrl = 'https://diasponiger.com/p/',
    this.supportEmail = 'support@diasponiger.com',
    this.supportPhone = '',
    this.privacyEmail = 'privacy@diasponiger.com',
    this.bugsEmail = 'bugs@diasponiger.com',
    this.feedbackEmail = 'feedback@diasponiger.com',
    this.moderationEmail = 'moderation@diasponiger.com',
    this.stripeMerchantId = 'merchant.com.diasponiger',
    this.termsUrl = 'https://diasponiger.com/terms',
    this.privacyUrl = 'https://diasponiger.com/privacy',
  });

  factory SystemUrlsModel.fromJson(
    Map<String, dynamic> json,
  ) => SystemUrlsModel(
    shareBaseUrl:
        json['shareBaseUrl'] as String? ?? 'https://diasponiger.com/p/',
    supportEmail: json['supportEmail'] as String? ?? 'support@diasponiger.com',
    supportPhone: json['supportPhone'] as String? ?? '',
    privacyEmail: json['privacyEmail'] as String? ?? 'privacy@diasponiger.com',
    bugsEmail: json['bugsEmail'] as String? ?? 'bugs@diasponiger.com',
    feedbackEmail:
        json['feedbackEmail'] as String? ?? 'feedback@diasponiger.com',
    moderationEmail:
        json['moderationEmail'] as String? ?? 'moderation@diasponiger.com',
    stripeMerchantId:
        json['stripeMerchantId'] as String? ?? 'merchant.com.diasponiger',
    termsUrl: json['termsUrl'] as String? ?? 'https://diasponiger.com/terms',
    privacyUrl:
        json['privacyUrl'] as String? ?? 'https://diasponiger.com/privacy',
  );

  Map<String, dynamic> toJson() => {
    'shareBaseUrl': shareBaseUrl,
    'supportEmail': supportEmail,
    'supportPhone': supportPhone,
    'privacyEmail': privacyEmail,
    'bugsEmail': bugsEmail,
    'feedbackEmail': feedbackEmail,
    'moderationEmail': moderationEmail,
    'stripeMerchantId': stripeMerchantId,
    'termsUrl': termsUrl,
    'privacyUrl': privacyUrl,
  };

  SystemUrlsEntity toEntity() => SystemUrlsEntity(
    shareBaseUrl: shareBaseUrl,
    supportEmail: supportEmail,
    supportPhone: supportPhone,
    privacyEmail: privacyEmail,
    bugsEmail: bugsEmail,
    feedbackEmail: feedbackEmail,
    moderationEmail: moderationEmail,
    stripeMerchantId: stripeMerchantId,
    termsUrl: termsUrl,
    privacyUrl: privacyUrl,
  );

  static SystemUrlsModel fromEntity(SystemUrlsEntity entity) => SystemUrlsModel(
    shareBaseUrl: entity.shareBaseUrl,
    supportEmail: entity.supportEmail,
    privacyEmail: entity.privacyEmail,
    bugsEmail: entity.bugsEmail,
    feedbackEmail: entity.feedbackEmail,
    moderationEmail: entity.moderationEmail,
    stripeMerchantId: entity.stripeMerchantId,
    termsUrl: entity.termsUrl,
    privacyUrl: entity.privacyUrl,
  );
}

// ============================================================================
// FEATURE FLAGS
// ============================================================================

class FeatureFlagsModel {
  final bool moneyTransfer;
  final bool marketplace;
  final bool businessDirectory;
  final bool events;
  final bool groups;
  final bool embassies;

  /// Ces trois flags manquaient au modèle alors que l'entité et le routeur
  /// les consomment : les interrupteurs du back-office étaient perdus à la
  /// sérialisation et la lecture retombait sur les défauts de l'entité.
  final bool audioRooms;
  final bool podcasts;
  final bool feed;

  final bool maintenanceMode;
  final String? maintenanceMessage;

  FeatureFlagsModel({
    this.moneyTransfer = true,
    this.marketplace = true,
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

  factory FeatureFlagsModel.fromJson(Map<String, dynamic> json) =>
      FeatureFlagsModel(
        moneyTransfer: json['moneyTransfer'] as bool? ?? true,
        marketplace: json['marketplace'] as bool? ?? true,
        businessDirectory: json['businessDirectory'] as bool? ?? true,
        events: json['events'] as bool? ?? true,
        groups: json['groups'] as bool? ?? true,
        embassies: json['embassies'] as bool? ?? true,
        // Repli aligné sur les défauts de FeatureFlagsEntity : un document
        // qui n'a pas encore ces clés garde le comportement d'avant.
        audioRooms: json['audioRooms'] as bool? ?? false,
        podcasts: json['podcasts'] as bool? ?? false,
        feed: json['feed'] as bool? ?? true,
        maintenanceMode: json['maintenanceMode'] as bool? ?? false,
        maintenanceMessage: json['maintenanceMessage'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'moneyTransfer': moneyTransfer,
    'marketplace': marketplace,
    'businessDirectory': businessDirectory,
    'events': events,
    'groups': groups,
    'embassies': embassies,
    'audioRooms': audioRooms,
    'podcasts': podcasts,
    'feed': feed,
    'maintenanceMode': maintenanceMode,
    'maintenanceMessage': maintenanceMessage,
  };

  FeatureFlagsEntity toEntity() => FeatureFlagsEntity(
    moneyTransfer: moneyTransfer,
    marketplace: marketplace,
    businessDirectory: businessDirectory,
    events: events,
    groups: groups,
    embassies: embassies,
    audioRooms: audioRooms,
    podcasts: podcasts,
    feed: feed,
    maintenanceMode: maintenanceMode,
    maintenanceMessage: maintenanceMessage,
  );

  static FeatureFlagsModel fromEntity(FeatureFlagsEntity entity) =>
      FeatureFlagsModel(
        moneyTransfer: entity.moneyTransfer,
        marketplace: entity.marketplace,
        businessDirectory: entity.businessDirectory,
        events: entity.events,
        groups: entity.groups,
        embassies: entity.embassies,
        audioRooms: entity.audioRooms,
        podcasts: entity.podcasts,
        feed: entity.feed,
        maintenanceMode: entity.maintenanceMode,
        maintenanceMessage: entity.maintenanceMessage,
      );
}
