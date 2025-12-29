// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppSettingsEntity {
  // Fee Configuration
  FeeSettingsEntity get fees =>
      throw _privateConstructorUsedError; // Boost Pricing
  BoostPricingEntity get boostPricing =>
      throw _privateConstructorUsedError; // Tax Rates
  TaxRatesEntity get taxRates =>
      throw _privateConstructorUsedError; // Exchange Rates (fallback)
  ExchangeRatesEntity get exchangeRates =>
      throw _privateConstructorUsedError; // Media Limits
  MediaLimitsEntity get mediaLimits =>
      throw _privateConstructorUsedError; // Validation Rules
  ValidationRulesEntity get validation =>
      throw _privateConstructorUsedError; // System Intervals
  SystemIntervalsEntity get intervals =>
      throw _privateConstructorUsedError; // URLs & Contact
  SystemUrlsEntity get urls =>
      throw _privateConstructorUsedError; // Feature Flags
  FeatureFlagsEntity get featureFlags =>
      throw _privateConstructorUsedError; // Metadata
  DateTime? get lastUpdated => throw _privateConstructorUsedError;
  String? get updatedBy => throw _privateConstructorUsedError;

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsEntityCopyWith<AppSettingsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsEntityCopyWith<$Res> {
  factory $AppSettingsEntityCopyWith(
    AppSettingsEntity value,
    $Res Function(AppSettingsEntity) then,
  ) = _$AppSettingsEntityCopyWithImpl<$Res, AppSettingsEntity>;
  @useResult
  $Res call({
    FeeSettingsEntity fees,
    BoostPricingEntity boostPricing,
    TaxRatesEntity taxRates,
    ExchangeRatesEntity exchangeRates,
    MediaLimitsEntity mediaLimits,
    ValidationRulesEntity validation,
    SystemIntervalsEntity intervals,
    SystemUrlsEntity urls,
    FeatureFlagsEntity featureFlags,
    DateTime? lastUpdated,
    String? updatedBy,
  });

  $FeeSettingsEntityCopyWith<$Res> get fees;
  $BoostPricingEntityCopyWith<$Res> get boostPricing;
  $TaxRatesEntityCopyWith<$Res> get taxRates;
  $ExchangeRatesEntityCopyWith<$Res> get exchangeRates;
  $MediaLimitsEntityCopyWith<$Res> get mediaLimits;
  $ValidationRulesEntityCopyWith<$Res> get validation;
  $SystemIntervalsEntityCopyWith<$Res> get intervals;
  $SystemUrlsEntityCopyWith<$Res> get urls;
  $FeatureFlagsEntityCopyWith<$Res> get featureFlags;
}

/// @nodoc
class _$AppSettingsEntityCopyWithImpl<$Res, $Val extends AppSettingsEntity>
    implements $AppSettingsEntityCopyWith<$Res> {
  _$AppSettingsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fees = null,
    Object? boostPricing = null,
    Object? taxRates = null,
    Object? exchangeRates = null,
    Object? mediaLimits = null,
    Object? validation = null,
    Object? intervals = null,
    Object? urls = null,
    Object? featureFlags = null,
    Object? lastUpdated = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            fees:
                null == fees
                    ? _value.fees
                    : fees // ignore: cast_nullable_to_non_nullable
                        as FeeSettingsEntity,
            boostPricing:
                null == boostPricing
                    ? _value.boostPricing
                    : boostPricing // ignore: cast_nullable_to_non_nullable
                        as BoostPricingEntity,
            taxRates:
                null == taxRates
                    ? _value.taxRates
                    : taxRates // ignore: cast_nullable_to_non_nullable
                        as TaxRatesEntity,
            exchangeRates:
                null == exchangeRates
                    ? _value.exchangeRates
                    : exchangeRates // ignore: cast_nullable_to_non_nullable
                        as ExchangeRatesEntity,
            mediaLimits:
                null == mediaLimits
                    ? _value.mediaLimits
                    : mediaLimits // ignore: cast_nullable_to_non_nullable
                        as MediaLimitsEntity,
            validation:
                null == validation
                    ? _value.validation
                    : validation // ignore: cast_nullable_to_non_nullable
                        as ValidationRulesEntity,
            intervals:
                null == intervals
                    ? _value.intervals
                    : intervals // ignore: cast_nullable_to_non_nullable
                        as SystemIntervalsEntity,
            urls:
                null == urls
                    ? _value.urls
                    : urls // ignore: cast_nullable_to_non_nullable
                        as SystemUrlsEntity,
            featureFlags:
                null == featureFlags
                    ? _value.featureFlags
                    : featureFlags // ignore: cast_nullable_to_non_nullable
                        as FeatureFlagsEntity,
            lastUpdated:
                freezed == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            updatedBy:
                freezed == updatedBy
                    ? _value.updatedBy
                    : updatedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeSettingsEntityCopyWith<$Res> get fees {
    return $FeeSettingsEntityCopyWith<$Res>(_value.fees, (value) {
      return _then(_value.copyWith(fees: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BoostPricingEntityCopyWith<$Res> get boostPricing {
    return $BoostPricingEntityCopyWith<$Res>(_value.boostPricing, (value) {
      return _then(_value.copyWith(boostPricing: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaxRatesEntityCopyWith<$Res> get taxRates {
    return $TaxRatesEntityCopyWith<$Res>(_value.taxRates, (value) {
      return _then(_value.copyWith(taxRates: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExchangeRatesEntityCopyWith<$Res> get exchangeRates {
    return $ExchangeRatesEntityCopyWith<$Res>(_value.exchangeRates, (value) {
      return _then(_value.copyWith(exchangeRates: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MediaLimitsEntityCopyWith<$Res> get mediaLimits {
    return $MediaLimitsEntityCopyWith<$Res>(_value.mediaLimits, (value) {
      return _then(_value.copyWith(mediaLimits: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValidationRulesEntityCopyWith<$Res> get validation {
    return $ValidationRulesEntityCopyWith<$Res>(_value.validation, (value) {
      return _then(_value.copyWith(validation: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SystemIntervalsEntityCopyWith<$Res> get intervals {
    return $SystemIntervalsEntityCopyWith<$Res>(_value.intervals, (value) {
      return _then(_value.copyWith(intervals: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SystemUrlsEntityCopyWith<$Res> get urls {
    return $SystemUrlsEntityCopyWith<$Res>(_value.urls, (value) {
      return _then(_value.copyWith(urls: value) as $Val);
    });
  }

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeatureFlagsEntityCopyWith<$Res> get featureFlags {
    return $FeatureFlagsEntityCopyWith<$Res>(_value.featureFlags, (value) {
      return _then(_value.copyWith(featureFlags: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppSettingsEntityImplCopyWith<$Res>
    implements $AppSettingsEntityCopyWith<$Res> {
  factory _$$AppSettingsEntityImplCopyWith(
    _$AppSettingsEntityImpl value,
    $Res Function(_$AppSettingsEntityImpl) then,
  ) = __$$AppSettingsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    FeeSettingsEntity fees,
    BoostPricingEntity boostPricing,
    TaxRatesEntity taxRates,
    ExchangeRatesEntity exchangeRates,
    MediaLimitsEntity mediaLimits,
    ValidationRulesEntity validation,
    SystemIntervalsEntity intervals,
    SystemUrlsEntity urls,
    FeatureFlagsEntity featureFlags,
    DateTime? lastUpdated,
    String? updatedBy,
  });

  @override
  $FeeSettingsEntityCopyWith<$Res> get fees;
  @override
  $BoostPricingEntityCopyWith<$Res> get boostPricing;
  @override
  $TaxRatesEntityCopyWith<$Res> get taxRates;
  @override
  $ExchangeRatesEntityCopyWith<$Res> get exchangeRates;
  @override
  $MediaLimitsEntityCopyWith<$Res> get mediaLimits;
  @override
  $ValidationRulesEntityCopyWith<$Res> get validation;
  @override
  $SystemIntervalsEntityCopyWith<$Res> get intervals;
  @override
  $SystemUrlsEntityCopyWith<$Res> get urls;
  @override
  $FeatureFlagsEntityCopyWith<$Res> get featureFlags;
}

/// @nodoc
class __$$AppSettingsEntityImplCopyWithImpl<$Res>
    extends _$AppSettingsEntityCopyWithImpl<$Res, _$AppSettingsEntityImpl>
    implements _$$AppSettingsEntityImplCopyWith<$Res> {
  __$$AppSettingsEntityImplCopyWithImpl(
    _$AppSettingsEntityImpl _value,
    $Res Function(_$AppSettingsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fees = null,
    Object? boostPricing = null,
    Object? taxRates = null,
    Object? exchangeRates = null,
    Object? mediaLimits = null,
    Object? validation = null,
    Object? intervals = null,
    Object? urls = null,
    Object? featureFlags = null,
    Object? lastUpdated = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(
      _$AppSettingsEntityImpl(
        fees:
            null == fees
                ? _value.fees
                : fees // ignore: cast_nullable_to_non_nullable
                    as FeeSettingsEntity,
        boostPricing:
            null == boostPricing
                ? _value.boostPricing
                : boostPricing // ignore: cast_nullable_to_non_nullable
                    as BoostPricingEntity,
        taxRates:
            null == taxRates
                ? _value.taxRates
                : taxRates // ignore: cast_nullable_to_non_nullable
                    as TaxRatesEntity,
        exchangeRates:
            null == exchangeRates
                ? _value.exchangeRates
                : exchangeRates // ignore: cast_nullable_to_non_nullable
                    as ExchangeRatesEntity,
        mediaLimits:
            null == mediaLimits
                ? _value.mediaLimits
                : mediaLimits // ignore: cast_nullable_to_non_nullable
                    as MediaLimitsEntity,
        validation:
            null == validation
                ? _value.validation
                : validation // ignore: cast_nullable_to_non_nullable
                    as ValidationRulesEntity,
        intervals:
            null == intervals
                ? _value.intervals
                : intervals // ignore: cast_nullable_to_non_nullable
                    as SystemIntervalsEntity,
        urls:
            null == urls
                ? _value.urls
                : urls // ignore: cast_nullable_to_non_nullable
                    as SystemUrlsEntity,
        featureFlags:
            null == featureFlags
                ? _value.featureFlags
                : featureFlags // ignore: cast_nullable_to_non_nullable
                    as FeatureFlagsEntity,
        lastUpdated:
            freezed == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        updatedBy:
            freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$AppSettingsEntityImpl implements _AppSettingsEntity {
  const _$AppSettingsEntityImpl({
    this.fees = const FeeSettingsEntity(),
    this.boostPricing = const BoostPricingEntity(),
    this.taxRates = const TaxRatesEntity(),
    this.exchangeRates = const ExchangeRatesEntity(),
    this.mediaLimits = const MediaLimitsEntity(),
    this.validation = const ValidationRulesEntity(),
    this.intervals = const SystemIntervalsEntity(),
    this.urls = const SystemUrlsEntity(),
    this.featureFlags = const FeatureFlagsEntity(),
    this.lastUpdated,
    this.updatedBy,
  });

  // Fee Configuration
  @override
  @JsonKey()
  final FeeSettingsEntity fees;
  // Boost Pricing
  @override
  @JsonKey()
  final BoostPricingEntity boostPricing;
  // Tax Rates
  @override
  @JsonKey()
  final TaxRatesEntity taxRates;
  // Exchange Rates (fallback)
  @override
  @JsonKey()
  final ExchangeRatesEntity exchangeRates;
  // Media Limits
  @override
  @JsonKey()
  final MediaLimitsEntity mediaLimits;
  // Validation Rules
  @override
  @JsonKey()
  final ValidationRulesEntity validation;
  // System Intervals
  @override
  @JsonKey()
  final SystemIntervalsEntity intervals;
  // URLs & Contact
  @override
  @JsonKey()
  final SystemUrlsEntity urls;
  // Feature Flags
  @override
  @JsonKey()
  final FeatureFlagsEntity featureFlags;
  // Metadata
  @override
  final DateTime? lastUpdated;
  @override
  final String? updatedBy;

  @override
  String toString() {
    return 'AppSettingsEntity(fees: $fees, boostPricing: $boostPricing, taxRates: $taxRates, exchangeRates: $exchangeRates, mediaLimits: $mediaLimits, validation: $validation, intervals: $intervals, urls: $urls, featureFlags: $featureFlags, lastUpdated: $lastUpdated, updatedBy: $updatedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsEntityImpl &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.boostPricing, boostPricing) ||
                other.boostPricing == boostPricing) &&
            (identical(other.taxRates, taxRates) ||
                other.taxRates == taxRates) &&
            (identical(other.exchangeRates, exchangeRates) ||
                other.exchangeRates == exchangeRates) &&
            (identical(other.mediaLimits, mediaLimits) ||
                other.mediaLimits == mediaLimits) &&
            (identical(other.validation, validation) ||
                other.validation == validation) &&
            (identical(other.intervals, intervals) ||
                other.intervals == intervals) &&
            (identical(other.urls, urls) || other.urls == urls) &&
            (identical(other.featureFlags, featureFlags) ||
                other.featureFlags == featureFlags) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    fees,
    boostPricing,
    taxRates,
    exchangeRates,
    mediaLimits,
    validation,
    intervals,
    urls,
    featureFlags,
    lastUpdated,
    updatedBy,
  );

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsEntityImplCopyWith<_$AppSettingsEntityImpl> get copyWith =>
      __$$AppSettingsEntityImplCopyWithImpl<_$AppSettingsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _AppSettingsEntity implements AppSettingsEntity {
  const factory _AppSettingsEntity({
    final FeeSettingsEntity fees,
    final BoostPricingEntity boostPricing,
    final TaxRatesEntity taxRates,
    final ExchangeRatesEntity exchangeRates,
    final MediaLimitsEntity mediaLimits,
    final ValidationRulesEntity validation,
    final SystemIntervalsEntity intervals,
    final SystemUrlsEntity urls,
    final FeatureFlagsEntity featureFlags,
    final DateTime? lastUpdated,
    final String? updatedBy,
  }) = _$AppSettingsEntityImpl;

  // Fee Configuration
  @override
  FeeSettingsEntity get fees; // Boost Pricing
  @override
  BoostPricingEntity get boostPricing; // Tax Rates
  @override
  TaxRatesEntity get taxRates; // Exchange Rates (fallback)
  @override
  ExchangeRatesEntity get exchangeRates; // Media Limits
  @override
  MediaLimitsEntity get mediaLimits; // Validation Rules
  @override
  ValidationRulesEntity get validation; // System Intervals
  @override
  SystemIntervalsEntity get intervals; // URLs & Contact
  @override
  SystemUrlsEntity get urls; // Feature Flags
  @override
  FeatureFlagsEntity get featureFlags; // Metadata
  @override
  DateTime? get lastUpdated;
  @override
  String? get updatedBy;

  /// Create a copy of AppSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsEntityImplCopyWith<_$AppSettingsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FeeSettingsEntity {
  // Transfer fees
  double get transferFeePercent => throw _privateConstructorUsedError;
  double get transferFeeMin => throw _privateConstructorUsedError;
  double get transferFeeMax =>
      throw _privateConstructorUsedError; // Marketplace fees
  double get marketplaceFeePercent => throw _privateConstructorUsedError;
  double get marketplaceFeeMin => throw _privateConstructorUsedError;
  double get marketplaceFeeMax => throw _privateConstructorUsedError;

  /// Create a copy of FeeSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeeSettingsEntityCopyWith<FeeSettingsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeeSettingsEntityCopyWith<$Res> {
  factory $FeeSettingsEntityCopyWith(
    FeeSettingsEntity value,
    $Res Function(FeeSettingsEntity) then,
  ) = _$FeeSettingsEntityCopyWithImpl<$Res, FeeSettingsEntity>;
  @useResult
  $Res call({
    double transferFeePercent,
    double transferFeeMin,
    double transferFeeMax,
    double marketplaceFeePercent,
    double marketplaceFeeMin,
    double marketplaceFeeMax,
  });
}

/// @nodoc
class _$FeeSettingsEntityCopyWithImpl<$Res, $Val extends FeeSettingsEntity>
    implements $FeeSettingsEntityCopyWith<$Res> {
  _$FeeSettingsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeeSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transferFeePercent = null,
    Object? transferFeeMin = null,
    Object? transferFeeMax = null,
    Object? marketplaceFeePercent = null,
    Object? marketplaceFeeMin = null,
    Object? marketplaceFeeMax = null,
  }) {
    return _then(
      _value.copyWith(
            transferFeePercent:
                null == transferFeePercent
                    ? _value.transferFeePercent
                    : transferFeePercent // ignore: cast_nullable_to_non_nullable
                        as double,
            transferFeeMin:
                null == transferFeeMin
                    ? _value.transferFeeMin
                    : transferFeeMin // ignore: cast_nullable_to_non_nullable
                        as double,
            transferFeeMax:
                null == transferFeeMax
                    ? _value.transferFeeMax
                    : transferFeeMax // ignore: cast_nullable_to_non_nullable
                        as double,
            marketplaceFeePercent:
                null == marketplaceFeePercent
                    ? _value.marketplaceFeePercent
                    : marketplaceFeePercent // ignore: cast_nullable_to_non_nullable
                        as double,
            marketplaceFeeMin:
                null == marketplaceFeeMin
                    ? _value.marketplaceFeeMin
                    : marketplaceFeeMin // ignore: cast_nullable_to_non_nullable
                        as double,
            marketplaceFeeMax:
                null == marketplaceFeeMax
                    ? _value.marketplaceFeeMax
                    : marketplaceFeeMax // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeeSettingsEntityImplCopyWith<$Res>
    implements $FeeSettingsEntityCopyWith<$Res> {
  factory _$$FeeSettingsEntityImplCopyWith(
    _$FeeSettingsEntityImpl value,
    $Res Function(_$FeeSettingsEntityImpl) then,
  ) = __$$FeeSettingsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double transferFeePercent,
    double transferFeeMin,
    double transferFeeMax,
    double marketplaceFeePercent,
    double marketplaceFeeMin,
    double marketplaceFeeMax,
  });
}

/// @nodoc
class __$$FeeSettingsEntityImplCopyWithImpl<$Res>
    extends _$FeeSettingsEntityCopyWithImpl<$Res, _$FeeSettingsEntityImpl>
    implements _$$FeeSettingsEntityImplCopyWith<$Res> {
  __$$FeeSettingsEntityImplCopyWithImpl(
    _$FeeSettingsEntityImpl _value,
    $Res Function(_$FeeSettingsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeeSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transferFeePercent = null,
    Object? transferFeeMin = null,
    Object? transferFeeMax = null,
    Object? marketplaceFeePercent = null,
    Object? marketplaceFeeMin = null,
    Object? marketplaceFeeMax = null,
  }) {
    return _then(
      _$FeeSettingsEntityImpl(
        transferFeePercent:
            null == transferFeePercent
                ? _value.transferFeePercent
                : transferFeePercent // ignore: cast_nullable_to_non_nullable
                    as double,
        transferFeeMin:
            null == transferFeeMin
                ? _value.transferFeeMin
                : transferFeeMin // ignore: cast_nullable_to_non_nullable
                    as double,
        transferFeeMax:
            null == transferFeeMax
                ? _value.transferFeeMax
                : transferFeeMax // ignore: cast_nullable_to_non_nullable
                    as double,
        marketplaceFeePercent:
            null == marketplaceFeePercent
                ? _value.marketplaceFeePercent
                : marketplaceFeePercent // ignore: cast_nullable_to_non_nullable
                    as double,
        marketplaceFeeMin:
            null == marketplaceFeeMin
                ? _value.marketplaceFeeMin
                : marketplaceFeeMin // ignore: cast_nullable_to_non_nullable
                    as double,
        marketplaceFeeMax:
            null == marketplaceFeeMax
                ? _value.marketplaceFeeMax
                : marketplaceFeeMax // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc

class _$FeeSettingsEntityImpl implements _FeeSettingsEntity {
  const _$FeeSettingsEntityImpl({
    this.transferFeePercent = 0.025,
    this.transferFeeMin = 500,
    this.transferFeeMax = 10000,
    this.marketplaceFeePercent = 0.05,
    this.marketplaceFeeMin = 0,
    this.marketplaceFeeMax = 50000,
  });

  // Transfer fees
  @override
  @JsonKey()
  final double transferFeePercent;
  @override
  @JsonKey()
  final double transferFeeMin;
  @override
  @JsonKey()
  final double transferFeeMax;
  // Marketplace fees
  @override
  @JsonKey()
  final double marketplaceFeePercent;
  @override
  @JsonKey()
  final double marketplaceFeeMin;
  @override
  @JsonKey()
  final double marketplaceFeeMax;

  @override
  String toString() {
    return 'FeeSettingsEntity(transferFeePercent: $transferFeePercent, transferFeeMin: $transferFeeMin, transferFeeMax: $transferFeeMax, marketplaceFeePercent: $marketplaceFeePercent, marketplaceFeeMin: $marketplaceFeeMin, marketplaceFeeMax: $marketplaceFeeMax)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeeSettingsEntityImpl &&
            (identical(other.transferFeePercent, transferFeePercent) ||
                other.transferFeePercent == transferFeePercent) &&
            (identical(other.transferFeeMin, transferFeeMin) ||
                other.transferFeeMin == transferFeeMin) &&
            (identical(other.transferFeeMax, transferFeeMax) ||
                other.transferFeeMax == transferFeeMax) &&
            (identical(other.marketplaceFeePercent, marketplaceFeePercent) ||
                other.marketplaceFeePercent == marketplaceFeePercent) &&
            (identical(other.marketplaceFeeMin, marketplaceFeeMin) ||
                other.marketplaceFeeMin == marketplaceFeeMin) &&
            (identical(other.marketplaceFeeMax, marketplaceFeeMax) ||
                other.marketplaceFeeMax == marketplaceFeeMax));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    transferFeePercent,
    transferFeeMin,
    transferFeeMax,
    marketplaceFeePercent,
    marketplaceFeeMin,
    marketplaceFeeMax,
  );

  /// Create a copy of FeeSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeeSettingsEntityImplCopyWith<_$FeeSettingsEntityImpl> get copyWith =>
      __$$FeeSettingsEntityImplCopyWithImpl<_$FeeSettingsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _FeeSettingsEntity implements FeeSettingsEntity {
  const factory _FeeSettingsEntity({
    final double transferFeePercent,
    final double transferFeeMin,
    final double transferFeeMax,
    final double marketplaceFeePercent,
    final double marketplaceFeeMin,
    final double marketplaceFeeMax,
  }) = _$FeeSettingsEntityImpl;

  // Transfer fees
  @override
  double get transferFeePercent;
  @override
  double get transferFeeMin;
  @override
  double get transferFeeMax; // Marketplace fees
  @override
  double get marketplaceFeePercent;
  @override
  double get marketplaceFeeMin;
  @override
  double get marketplaceFeeMax;

  /// Create a copy of FeeSettingsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeeSettingsEntityImplCopyWith<_$FeeSettingsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BoostPricingEntity {
  // Base prices (7 days)
  double get standardBase => throw _privateConstructorUsedError;
  double get featuredBase => throw _privateConstructorUsedError;
  double get premiumBase =>
      throw _privateConstructorUsedError; // Duration multipliers
  double get multiplier7Days => throw _privateConstructorUsedError;
  double get multiplier30Days => throw _privateConstructorUsedError;
  double get multiplier90Days => throw _privateConstructorUsedError;

  /// Create a copy of BoostPricingEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BoostPricingEntityCopyWith<BoostPricingEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BoostPricingEntityCopyWith<$Res> {
  factory $BoostPricingEntityCopyWith(
    BoostPricingEntity value,
    $Res Function(BoostPricingEntity) then,
  ) = _$BoostPricingEntityCopyWithImpl<$Res, BoostPricingEntity>;
  @useResult
  $Res call({
    double standardBase,
    double featuredBase,
    double premiumBase,
    double multiplier7Days,
    double multiplier30Days,
    double multiplier90Days,
  });
}

/// @nodoc
class _$BoostPricingEntityCopyWithImpl<$Res, $Val extends BoostPricingEntity>
    implements $BoostPricingEntityCopyWith<$Res> {
  _$BoostPricingEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BoostPricingEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? standardBase = null,
    Object? featuredBase = null,
    Object? premiumBase = null,
    Object? multiplier7Days = null,
    Object? multiplier30Days = null,
    Object? multiplier90Days = null,
  }) {
    return _then(
      _value.copyWith(
            standardBase:
                null == standardBase
                    ? _value.standardBase
                    : standardBase // ignore: cast_nullable_to_non_nullable
                        as double,
            featuredBase:
                null == featuredBase
                    ? _value.featuredBase
                    : featuredBase // ignore: cast_nullable_to_non_nullable
                        as double,
            premiumBase:
                null == premiumBase
                    ? _value.premiumBase
                    : premiumBase // ignore: cast_nullable_to_non_nullable
                        as double,
            multiplier7Days:
                null == multiplier7Days
                    ? _value.multiplier7Days
                    : multiplier7Days // ignore: cast_nullable_to_non_nullable
                        as double,
            multiplier30Days:
                null == multiplier30Days
                    ? _value.multiplier30Days
                    : multiplier30Days // ignore: cast_nullable_to_non_nullable
                        as double,
            multiplier90Days:
                null == multiplier90Days
                    ? _value.multiplier90Days
                    : multiplier90Days // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BoostPricingEntityImplCopyWith<$Res>
    implements $BoostPricingEntityCopyWith<$Res> {
  factory _$$BoostPricingEntityImplCopyWith(
    _$BoostPricingEntityImpl value,
    $Res Function(_$BoostPricingEntityImpl) then,
  ) = __$$BoostPricingEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double standardBase,
    double featuredBase,
    double premiumBase,
    double multiplier7Days,
    double multiplier30Days,
    double multiplier90Days,
  });
}

/// @nodoc
class __$$BoostPricingEntityImplCopyWithImpl<$Res>
    extends _$BoostPricingEntityCopyWithImpl<$Res, _$BoostPricingEntityImpl>
    implements _$$BoostPricingEntityImplCopyWith<$Res> {
  __$$BoostPricingEntityImplCopyWithImpl(
    _$BoostPricingEntityImpl _value,
    $Res Function(_$BoostPricingEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BoostPricingEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? standardBase = null,
    Object? featuredBase = null,
    Object? premiumBase = null,
    Object? multiplier7Days = null,
    Object? multiplier30Days = null,
    Object? multiplier90Days = null,
  }) {
    return _then(
      _$BoostPricingEntityImpl(
        standardBase:
            null == standardBase
                ? _value.standardBase
                : standardBase // ignore: cast_nullable_to_non_nullable
                    as double,
        featuredBase:
            null == featuredBase
                ? _value.featuredBase
                : featuredBase // ignore: cast_nullable_to_non_nullable
                    as double,
        premiumBase:
            null == premiumBase
                ? _value.premiumBase
                : premiumBase // ignore: cast_nullable_to_non_nullable
                    as double,
        multiplier7Days:
            null == multiplier7Days
                ? _value.multiplier7Days
                : multiplier7Days // ignore: cast_nullable_to_non_nullable
                    as double,
        multiplier30Days:
            null == multiplier30Days
                ? _value.multiplier30Days
                : multiplier30Days // ignore: cast_nullable_to_non_nullable
                    as double,
        multiplier90Days:
            null == multiplier90Days
                ? _value.multiplier90Days
                : multiplier90Days // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc

class _$BoostPricingEntityImpl extends _BoostPricingEntity {
  const _$BoostPricingEntityImpl({
    this.standardBase = 5000,
    this.featuredBase = 10000,
    this.premiumBase = 25000,
    this.multiplier7Days = 1.0,
    this.multiplier30Days = 3.0,
    this.multiplier90Days = 7.0,
  }) : super._();

  // Base prices (7 days)
  @override
  @JsonKey()
  final double standardBase;
  @override
  @JsonKey()
  final double featuredBase;
  @override
  @JsonKey()
  final double premiumBase;
  // Duration multipliers
  @override
  @JsonKey()
  final double multiplier7Days;
  @override
  @JsonKey()
  final double multiplier30Days;
  @override
  @JsonKey()
  final double multiplier90Days;

  @override
  String toString() {
    return 'BoostPricingEntity(standardBase: $standardBase, featuredBase: $featuredBase, premiumBase: $premiumBase, multiplier7Days: $multiplier7Days, multiplier30Days: $multiplier30Days, multiplier90Days: $multiplier90Days)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BoostPricingEntityImpl &&
            (identical(other.standardBase, standardBase) ||
                other.standardBase == standardBase) &&
            (identical(other.featuredBase, featuredBase) ||
                other.featuredBase == featuredBase) &&
            (identical(other.premiumBase, premiumBase) ||
                other.premiumBase == premiumBase) &&
            (identical(other.multiplier7Days, multiplier7Days) ||
                other.multiplier7Days == multiplier7Days) &&
            (identical(other.multiplier30Days, multiplier30Days) ||
                other.multiplier30Days == multiplier30Days) &&
            (identical(other.multiplier90Days, multiplier90Days) ||
                other.multiplier90Days == multiplier90Days));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    standardBase,
    featuredBase,
    premiumBase,
    multiplier7Days,
    multiplier30Days,
    multiplier90Days,
  );

  /// Create a copy of BoostPricingEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BoostPricingEntityImplCopyWith<_$BoostPricingEntityImpl> get copyWith =>
      __$$BoostPricingEntityImplCopyWithImpl<_$BoostPricingEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _BoostPricingEntity extends BoostPricingEntity {
  const factory _BoostPricingEntity({
    final double standardBase,
    final double featuredBase,
    final double premiumBase,
    final double multiplier7Days,
    final double multiplier30Days,
    final double multiplier90Days,
  }) = _$BoostPricingEntityImpl;
  const _BoostPricingEntity._() : super._();

  // Base prices (7 days)
  @override
  double get standardBase;
  @override
  double get featuredBase;
  @override
  double get premiumBase; // Duration multipliers
  @override
  double get multiplier7Days;
  @override
  double get multiplier30Days;
  @override
  double get multiplier90Days;

  /// Create a copy of BoostPricingEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BoostPricingEntityImplCopyWith<_$BoostPricingEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TaxRatesEntity {
  double get alimentation => throw _privateConstructorUsedError;
  double get artisanat => throw _privateConstructorUsedError;
  double get standard => throw _privateConstructorUsedError;
  double get electronique => throw _privateConstructorUsedError;
  double get vetements => throw _privateConstructorUsedError;
  double get services => throw _privateConstructorUsedError;
  double get immobilier => throw _privateConstructorUsedError;

  /// Create a copy of TaxRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaxRatesEntityCopyWith<TaxRatesEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaxRatesEntityCopyWith<$Res> {
  factory $TaxRatesEntityCopyWith(
    TaxRatesEntity value,
    $Res Function(TaxRatesEntity) then,
  ) = _$TaxRatesEntityCopyWithImpl<$Res, TaxRatesEntity>;
  @useResult
  $Res call({
    double alimentation,
    double artisanat,
    double standard,
    double electronique,
    double vetements,
    double services,
    double immobilier,
  });
}

/// @nodoc
class _$TaxRatesEntityCopyWithImpl<$Res, $Val extends TaxRatesEntity>
    implements $TaxRatesEntityCopyWith<$Res> {
  _$TaxRatesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaxRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? alimentation = null,
    Object? artisanat = null,
    Object? standard = null,
    Object? electronique = null,
    Object? vetements = null,
    Object? services = null,
    Object? immobilier = null,
  }) {
    return _then(
      _value.copyWith(
            alimentation:
                null == alimentation
                    ? _value.alimentation
                    : alimentation // ignore: cast_nullable_to_non_nullable
                        as double,
            artisanat:
                null == artisanat
                    ? _value.artisanat
                    : artisanat // ignore: cast_nullable_to_non_nullable
                        as double,
            standard:
                null == standard
                    ? _value.standard
                    : standard // ignore: cast_nullable_to_non_nullable
                        as double,
            electronique:
                null == electronique
                    ? _value.electronique
                    : electronique // ignore: cast_nullable_to_non_nullable
                        as double,
            vetements:
                null == vetements
                    ? _value.vetements
                    : vetements // ignore: cast_nullable_to_non_nullable
                        as double,
            services:
                null == services
                    ? _value.services
                    : services // ignore: cast_nullable_to_non_nullable
                        as double,
            immobilier:
                null == immobilier
                    ? _value.immobilier
                    : immobilier // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaxRatesEntityImplCopyWith<$Res>
    implements $TaxRatesEntityCopyWith<$Res> {
  factory _$$TaxRatesEntityImplCopyWith(
    _$TaxRatesEntityImpl value,
    $Res Function(_$TaxRatesEntityImpl) then,
  ) = __$$TaxRatesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double alimentation,
    double artisanat,
    double standard,
    double electronique,
    double vetements,
    double services,
    double immobilier,
  });
}

/// @nodoc
class __$$TaxRatesEntityImplCopyWithImpl<$Res>
    extends _$TaxRatesEntityCopyWithImpl<$Res, _$TaxRatesEntityImpl>
    implements _$$TaxRatesEntityImplCopyWith<$Res> {
  __$$TaxRatesEntityImplCopyWithImpl(
    _$TaxRatesEntityImpl _value,
    $Res Function(_$TaxRatesEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaxRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? alimentation = null,
    Object? artisanat = null,
    Object? standard = null,
    Object? electronique = null,
    Object? vetements = null,
    Object? services = null,
    Object? immobilier = null,
  }) {
    return _then(
      _$TaxRatesEntityImpl(
        alimentation:
            null == alimentation
                ? _value.alimentation
                : alimentation // ignore: cast_nullable_to_non_nullable
                    as double,
        artisanat:
            null == artisanat
                ? _value.artisanat
                : artisanat // ignore: cast_nullable_to_non_nullable
                    as double,
        standard:
            null == standard
                ? _value.standard
                : standard // ignore: cast_nullable_to_non_nullable
                    as double,
        electronique:
            null == electronique
                ? _value.electronique
                : electronique // ignore: cast_nullable_to_non_nullable
                    as double,
        vetements:
            null == vetements
                ? _value.vetements
                : vetements // ignore: cast_nullable_to_non_nullable
                    as double,
        services:
            null == services
                ? _value.services
                : services // ignore: cast_nullable_to_non_nullable
                    as double,
        immobilier:
            null == immobilier
                ? _value.immobilier
                : immobilier // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc

class _$TaxRatesEntityImpl extends _TaxRatesEntity {
  const _$TaxRatesEntityImpl({
    this.alimentation = 0.0,
    this.artisanat = 0.10,
    this.standard = 0.19,
    this.electronique = 0.19,
    this.vetements = 0.19,
    this.services = 0.0,
    this.immobilier = 0.0,
  }) : super._();

  @override
  @JsonKey()
  final double alimentation;
  @override
  @JsonKey()
  final double artisanat;
  @override
  @JsonKey()
  final double standard;
  @override
  @JsonKey()
  final double electronique;
  @override
  @JsonKey()
  final double vetements;
  @override
  @JsonKey()
  final double services;
  @override
  @JsonKey()
  final double immobilier;

  @override
  String toString() {
    return 'TaxRatesEntity(alimentation: $alimentation, artisanat: $artisanat, standard: $standard, electronique: $electronique, vetements: $vetements, services: $services, immobilier: $immobilier)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaxRatesEntityImpl &&
            (identical(other.alimentation, alimentation) ||
                other.alimentation == alimentation) &&
            (identical(other.artisanat, artisanat) ||
                other.artisanat == artisanat) &&
            (identical(other.standard, standard) ||
                other.standard == standard) &&
            (identical(other.electronique, electronique) ||
                other.electronique == electronique) &&
            (identical(other.vetements, vetements) ||
                other.vetements == vetements) &&
            (identical(other.services, services) ||
                other.services == services) &&
            (identical(other.immobilier, immobilier) ||
                other.immobilier == immobilier));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    alimentation,
    artisanat,
    standard,
    electronique,
    vetements,
    services,
    immobilier,
  );

  /// Create a copy of TaxRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaxRatesEntityImplCopyWith<_$TaxRatesEntityImpl> get copyWith =>
      __$$TaxRatesEntityImplCopyWithImpl<_$TaxRatesEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _TaxRatesEntity extends TaxRatesEntity {
  const factory _TaxRatesEntity({
    final double alimentation,
    final double artisanat,
    final double standard,
    final double electronique,
    final double vetements,
    final double services,
    final double immobilier,
  }) = _$TaxRatesEntityImpl;
  const _TaxRatesEntity._() : super._();

  @override
  double get alimentation;
  @override
  double get artisanat;
  @override
  double get standard;
  @override
  double get electronique;
  @override
  double get vetements;
  @override
  double get services;
  @override
  double get immobilier;

  /// Create a copy of TaxRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaxRatesEntityImplCopyWith<_$TaxRatesEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ExchangeRatesEntity {
  double get eurToXof => throw _privateConstructorUsedError;
  double get usdToXof => throw _privateConstructorUsedError;
  double get gbpToXof => throw _privateConstructorUsedError;
  double get cadToXof => throw _privateConstructorUsedError;
  double get chfToXof => throw _privateConstructorUsedError;
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  /// API key for exchangerate-api.com (stored in Firestore admin settings)
  String? get exchangeRateApiKey => throw _privateConstructorUsedError;

  /// Refresh interval in minutes for fetching new rates (default: 60)
  int get refreshIntervalMinutes => throw _privateConstructorUsedError;

  /// Create a copy of ExchangeRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExchangeRatesEntityCopyWith<ExchangeRatesEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExchangeRatesEntityCopyWith<$Res> {
  factory $ExchangeRatesEntityCopyWith(
    ExchangeRatesEntity value,
    $Res Function(ExchangeRatesEntity) then,
  ) = _$ExchangeRatesEntityCopyWithImpl<$Res, ExchangeRatesEntity>;
  @useResult
  $Res call({
    double eurToXof,
    double usdToXof,
    double gbpToXof,
    double cadToXof,
    double chfToXof,
    DateTime? lastUpdated,
    String? exchangeRateApiKey,
    int refreshIntervalMinutes,
  });
}

/// @nodoc
class _$ExchangeRatesEntityCopyWithImpl<$Res, $Val extends ExchangeRatesEntity>
    implements $ExchangeRatesEntityCopyWith<$Res> {
  _$ExchangeRatesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExchangeRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eurToXof = null,
    Object? usdToXof = null,
    Object? gbpToXof = null,
    Object? cadToXof = null,
    Object? chfToXof = null,
    Object? lastUpdated = freezed,
    Object? exchangeRateApiKey = freezed,
    Object? refreshIntervalMinutes = null,
  }) {
    return _then(
      _value.copyWith(
            eurToXof:
                null == eurToXof
                    ? _value.eurToXof
                    : eurToXof // ignore: cast_nullable_to_non_nullable
                        as double,
            usdToXof:
                null == usdToXof
                    ? _value.usdToXof
                    : usdToXof // ignore: cast_nullable_to_non_nullable
                        as double,
            gbpToXof:
                null == gbpToXof
                    ? _value.gbpToXof
                    : gbpToXof // ignore: cast_nullable_to_non_nullable
                        as double,
            cadToXof:
                null == cadToXof
                    ? _value.cadToXof
                    : cadToXof // ignore: cast_nullable_to_non_nullable
                        as double,
            chfToXof:
                null == chfToXof
                    ? _value.chfToXof
                    : chfToXof // ignore: cast_nullable_to_non_nullable
                        as double,
            lastUpdated:
                freezed == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            exchangeRateApiKey:
                freezed == exchangeRateApiKey
                    ? _value.exchangeRateApiKey
                    : exchangeRateApiKey // ignore: cast_nullable_to_non_nullable
                        as String?,
            refreshIntervalMinutes:
                null == refreshIntervalMinutes
                    ? _value.refreshIntervalMinutes
                    : refreshIntervalMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExchangeRatesEntityImplCopyWith<$Res>
    implements $ExchangeRatesEntityCopyWith<$Res> {
  factory _$$ExchangeRatesEntityImplCopyWith(
    _$ExchangeRatesEntityImpl value,
    $Res Function(_$ExchangeRatesEntityImpl) then,
  ) = __$$ExchangeRatesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double eurToXof,
    double usdToXof,
    double gbpToXof,
    double cadToXof,
    double chfToXof,
    DateTime? lastUpdated,
    String? exchangeRateApiKey,
    int refreshIntervalMinutes,
  });
}

/// @nodoc
class __$$ExchangeRatesEntityImplCopyWithImpl<$Res>
    extends _$ExchangeRatesEntityCopyWithImpl<$Res, _$ExchangeRatesEntityImpl>
    implements _$$ExchangeRatesEntityImplCopyWith<$Res> {
  __$$ExchangeRatesEntityImplCopyWithImpl(
    _$ExchangeRatesEntityImpl _value,
    $Res Function(_$ExchangeRatesEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExchangeRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eurToXof = null,
    Object? usdToXof = null,
    Object? gbpToXof = null,
    Object? cadToXof = null,
    Object? chfToXof = null,
    Object? lastUpdated = freezed,
    Object? exchangeRateApiKey = freezed,
    Object? refreshIntervalMinutes = null,
  }) {
    return _then(
      _$ExchangeRatesEntityImpl(
        eurToXof:
            null == eurToXof
                ? _value.eurToXof
                : eurToXof // ignore: cast_nullable_to_non_nullable
                    as double,
        usdToXof:
            null == usdToXof
                ? _value.usdToXof
                : usdToXof // ignore: cast_nullable_to_non_nullable
                    as double,
        gbpToXof:
            null == gbpToXof
                ? _value.gbpToXof
                : gbpToXof // ignore: cast_nullable_to_non_nullable
                    as double,
        cadToXof:
            null == cadToXof
                ? _value.cadToXof
                : cadToXof // ignore: cast_nullable_to_non_nullable
                    as double,
        chfToXof:
            null == chfToXof
                ? _value.chfToXof
                : chfToXof // ignore: cast_nullable_to_non_nullable
                    as double,
        lastUpdated:
            freezed == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        exchangeRateApiKey:
            freezed == exchangeRateApiKey
                ? _value.exchangeRateApiKey
                : exchangeRateApiKey // ignore: cast_nullable_to_non_nullable
                    as String?,
        refreshIntervalMinutes:
            null == refreshIntervalMinutes
                ? _value.refreshIntervalMinutes
                : refreshIntervalMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$ExchangeRatesEntityImpl extends _ExchangeRatesEntity {
  const _$ExchangeRatesEntityImpl({
    this.eurToXof = 655.957,
    this.usdToXof = 615.0,
    this.gbpToXof = 770.0,
    this.cadToXof = 455.0,
    this.chfToXof = 690.0,
    this.lastUpdated,
    this.exchangeRateApiKey,
    this.refreshIntervalMinutes = 60,
  }) : super._();

  @override
  @JsonKey()
  final double eurToXof;
  @override
  @JsonKey()
  final double usdToXof;
  @override
  @JsonKey()
  final double gbpToXof;
  @override
  @JsonKey()
  final double cadToXof;
  @override
  @JsonKey()
  final double chfToXof;
  @override
  final DateTime? lastUpdated;

  /// API key for exchangerate-api.com (stored in Firestore admin settings)
  @override
  final String? exchangeRateApiKey;

  /// Refresh interval in minutes for fetching new rates (default: 60)
  @override
  @JsonKey()
  final int refreshIntervalMinutes;

  @override
  String toString() {
    return 'ExchangeRatesEntity(eurToXof: $eurToXof, usdToXof: $usdToXof, gbpToXof: $gbpToXof, cadToXof: $cadToXof, chfToXof: $chfToXof, lastUpdated: $lastUpdated, exchangeRateApiKey: $exchangeRateApiKey, refreshIntervalMinutes: $refreshIntervalMinutes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExchangeRatesEntityImpl &&
            (identical(other.eurToXof, eurToXof) ||
                other.eurToXof == eurToXof) &&
            (identical(other.usdToXof, usdToXof) ||
                other.usdToXof == usdToXof) &&
            (identical(other.gbpToXof, gbpToXof) ||
                other.gbpToXof == gbpToXof) &&
            (identical(other.cadToXof, cadToXof) ||
                other.cadToXof == cadToXof) &&
            (identical(other.chfToXof, chfToXof) ||
                other.chfToXof == chfToXof) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.exchangeRateApiKey, exchangeRateApiKey) ||
                other.exchangeRateApiKey == exchangeRateApiKey) &&
            (identical(other.refreshIntervalMinutes, refreshIntervalMinutes) ||
                other.refreshIntervalMinutes == refreshIntervalMinutes));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    eurToXof,
    usdToXof,
    gbpToXof,
    cadToXof,
    chfToXof,
    lastUpdated,
    exchangeRateApiKey,
    refreshIntervalMinutes,
  );

  /// Create a copy of ExchangeRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExchangeRatesEntityImplCopyWith<_$ExchangeRatesEntityImpl> get copyWith =>
      __$$ExchangeRatesEntityImplCopyWithImpl<_$ExchangeRatesEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _ExchangeRatesEntity extends ExchangeRatesEntity {
  const factory _ExchangeRatesEntity({
    final double eurToXof,
    final double usdToXof,
    final double gbpToXof,
    final double cadToXof,
    final double chfToXof,
    final DateTime? lastUpdated,
    final String? exchangeRateApiKey,
    final int refreshIntervalMinutes,
  }) = _$ExchangeRatesEntityImpl;
  const _ExchangeRatesEntity._() : super._();

  @override
  double get eurToXof;
  @override
  double get usdToXof;
  @override
  double get gbpToXof;
  @override
  double get cadToXof;
  @override
  double get chfToXof;
  @override
  DateTime? get lastUpdated;

  /// API key for exchangerate-api.com (stored in Firestore admin settings)
  @override
  String? get exchangeRateApiKey;

  /// Refresh interval in minutes for fetching new rates (default: 60)
  @override
  int get refreshIntervalMinutes;

  /// Create a copy of ExchangeRatesEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExchangeRatesEntityImplCopyWith<_$ExchangeRatesEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MediaLimitsEntity {
  // Image settings
  int get imageMaxWidth => throw _privateConstructorUsedError;
  int get imageMaxHeight => throw _privateConstructorUsedError;
  int get imageQuality => throw _privateConstructorUsedError;
  int get maxImagesPerUpload => throw _privateConstructorUsedError;
  int get minWidthForCompression =>
      throw _privateConstructorUsedError; // Message settings
  int get messageMaxChars => throw _privateConstructorUsedError;
  int get messageCharCountThreshold =>
      throw _privateConstructorUsedError; // File limits (in MB)
  int get maxImageSizeMb => throw _privateConstructorUsedError;
  int get maxVideoSizeMb => throw _privateConstructorUsedError;
  int get maxDocumentSizeMb =>
      throw _privateConstructorUsedError; // Audio settings
  int get maxAudioDurationSeconds => throw _privateConstructorUsedError;

  /// Create a copy of MediaLimitsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaLimitsEntityCopyWith<MediaLimitsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaLimitsEntityCopyWith<$Res> {
  factory $MediaLimitsEntityCopyWith(
    MediaLimitsEntity value,
    $Res Function(MediaLimitsEntity) then,
  ) = _$MediaLimitsEntityCopyWithImpl<$Res, MediaLimitsEntity>;
  @useResult
  $Res call({
    int imageMaxWidth,
    int imageMaxHeight,
    int imageQuality,
    int maxImagesPerUpload,
    int minWidthForCompression,
    int messageMaxChars,
    int messageCharCountThreshold,
    int maxImageSizeMb,
    int maxVideoSizeMb,
    int maxDocumentSizeMb,
    int maxAudioDurationSeconds,
  });
}

/// @nodoc
class _$MediaLimitsEntityCopyWithImpl<$Res, $Val extends MediaLimitsEntity>
    implements $MediaLimitsEntityCopyWith<$Res> {
  _$MediaLimitsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaLimitsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imageMaxWidth = null,
    Object? imageMaxHeight = null,
    Object? imageQuality = null,
    Object? maxImagesPerUpload = null,
    Object? minWidthForCompression = null,
    Object? messageMaxChars = null,
    Object? messageCharCountThreshold = null,
    Object? maxImageSizeMb = null,
    Object? maxVideoSizeMb = null,
    Object? maxDocumentSizeMb = null,
    Object? maxAudioDurationSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            imageMaxWidth:
                null == imageMaxWidth
                    ? _value.imageMaxWidth
                    : imageMaxWidth // ignore: cast_nullable_to_non_nullable
                        as int,
            imageMaxHeight:
                null == imageMaxHeight
                    ? _value.imageMaxHeight
                    : imageMaxHeight // ignore: cast_nullable_to_non_nullable
                        as int,
            imageQuality:
                null == imageQuality
                    ? _value.imageQuality
                    : imageQuality // ignore: cast_nullable_to_non_nullable
                        as int,
            maxImagesPerUpload:
                null == maxImagesPerUpload
                    ? _value.maxImagesPerUpload
                    : maxImagesPerUpload // ignore: cast_nullable_to_non_nullable
                        as int,
            minWidthForCompression:
                null == minWidthForCompression
                    ? _value.minWidthForCompression
                    : minWidthForCompression // ignore: cast_nullable_to_non_nullable
                        as int,
            messageMaxChars:
                null == messageMaxChars
                    ? _value.messageMaxChars
                    : messageMaxChars // ignore: cast_nullable_to_non_nullable
                        as int,
            messageCharCountThreshold:
                null == messageCharCountThreshold
                    ? _value.messageCharCountThreshold
                    : messageCharCountThreshold // ignore: cast_nullable_to_non_nullable
                        as int,
            maxImageSizeMb:
                null == maxImageSizeMb
                    ? _value.maxImageSizeMb
                    : maxImageSizeMb // ignore: cast_nullable_to_non_nullable
                        as int,
            maxVideoSizeMb:
                null == maxVideoSizeMb
                    ? _value.maxVideoSizeMb
                    : maxVideoSizeMb // ignore: cast_nullable_to_non_nullable
                        as int,
            maxDocumentSizeMb:
                null == maxDocumentSizeMb
                    ? _value.maxDocumentSizeMb
                    : maxDocumentSizeMb // ignore: cast_nullable_to_non_nullable
                        as int,
            maxAudioDurationSeconds:
                null == maxAudioDurationSeconds
                    ? _value.maxAudioDurationSeconds
                    : maxAudioDurationSeconds // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MediaLimitsEntityImplCopyWith<$Res>
    implements $MediaLimitsEntityCopyWith<$Res> {
  factory _$$MediaLimitsEntityImplCopyWith(
    _$MediaLimitsEntityImpl value,
    $Res Function(_$MediaLimitsEntityImpl) then,
  ) = __$$MediaLimitsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int imageMaxWidth,
    int imageMaxHeight,
    int imageQuality,
    int maxImagesPerUpload,
    int minWidthForCompression,
    int messageMaxChars,
    int messageCharCountThreshold,
    int maxImageSizeMb,
    int maxVideoSizeMb,
    int maxDocumentSizeMb,
    int maxAudioDurationSeconds,
  });
}

/// @nodoc
class __$$MediaLimitsEntityImplCopyWithImpl<$Res>
    extends _$MediaLimitsEntityCopyWithImpl<$Res, _$MediaLimitsEntityImpl>
    implements _$$MediaLimitsEntityImplCopyWith<$Res> {
  __$$MediaLimitsEntityImplCopyWithImpl(
    _$MediaLimitsEntityImpl _value,
    $Res Function(_$MediaLimitsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MediaLimitsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imageMaxWidth = null,
    Object? imageMaxHeight = null,
    Object? imageQuality = null,
    Object? maxImagesPerUpload = null,
    Object? minWidthForCompression = null,
    Object? messageMaxChars = null,
    Object? messageCharCountThreshold = null,
    Object? maxImageSizeMb = null,
    Object? maxVideoSizeMb = null,
    Object? maxDocumentSizeMb = null,
    Object? maxAudioDurationSeconds = null,
  }) {
    return _then(
      _$MediaLimitsEntityImpl(
        imageMaxWidth:
            null == imageMaxWidth
                ? _value.imageMaxWidth
                : imageMaxWidth // ignore: cast_nullable_to_non_nullable
                    as int,
        imageMaxHeight:
            null == imageMaxHeight
                ? _value.imageMaxHeight
                : imageMaxHeight // ignore: cast_nullable_to_non_nullable
                    as int,
        imageQuality:
            null == imageQuality
                ? _value.imageQuality
                : imageQuality // ignore: cast_nullable_to_non_nullable
                    as int,
        maxImagesPerUpload:
            null == maxImagesPerUpload
                ? _value.maxImagesPerUpload
                : maxImagesPerUpload // ignore: cast_nullable_to_non_nullable
                    as int,
        minWidthForCompression:
            null == minWidthForCompression
                ? _value.minWidthForCompression
                : minWidthForCompression // ignore: cast_nullable_to_non_nullable
                    as int,
        messageMaxChars:
            null == messageMaxChars
                ? _value.messageMaxChars
                : messageMaxChars // ignore: cast_nullable_to_non_nullable
                    as int,
        messageCharCountThreshold:
            null == messageCharCountThreshold
                ? _value.messageCharCountThreshold
                : messageCharCountThreshold // ignore: cast_nullable_to_non_nullable
                    as int,
        maxImageSizeMb:
            null == maxImageSizeMb
                ? _value.maxImageSizeMb
                : maxImageSizeMb // ignore: cast_nullable_to_non_nullable
                    as int,
        maxVideoSizeMb:
            null == maxVideoSizeMb
                ? _value.maxVideoSizeMb
                : maxVideoSizeMb // ignore: cast_nullable_to_non_nullable
                    as int,
        maxDocumentSizeMb:
            null == maxDocumentSizeMb
                ? _value.maxDocumentSizeMb
                : maxDocumentSizeMb // ignore: cast_nullable_to_non_nullable
                    as int,
        maxAudioDurationSeconds:
            null == maxAudioDurationSeconds
                ? _value.maxAudioDurationSeconds
                : maxAudioDurationSeconds // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$MediaLimitsEntityImpl implements _MediaLimitsEntity {
  const _$MediaLimitsEntityImpl({
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

  // Image settings
  @override
  @JsonKey()
  final int imageMaxWidth;
  @override
  @JsonKey()
  final int imageMaxHeight;
  @override
  @JsonKey()
  final int imageQuality;
  @override
  @JsonKey()
  final int maxImagesPerUpload;
  @override
  @JsonKey()
  final int minWidthForCompression;
  // Message settings
  @override
  @JsonKey()
  final int messageMaxChars;
  @override
  @JsonKey()
  final int messageCharCountThreshold;
  // File limits (in MB)
  @override
  @JsonKey()
  final int maxImageSizeMb;
  @override
  @JsonKey()
  final int maxVideoSizeMb;
  @override
  @JsonKey()
  final int maxDocumentSizeMb;
  // Audio settings
  @override
  @JsonKey()
  final int maxAudioDurationSeconds;

  @override
  String toString() {
    return 'MediaLimitsEntity(imageMaxWidth: $imageMaxWidth, imageMaxHeight: $imageMaxHeight, imageQuality: $imageQuality, maxImagesPerUpload: $maxImagesPerUpload, minWidthForCompression: $minWidthForCompression, messageMaxChars: $messageMaxChars, messageCharCountThreshold: $messageCharCountThreshold, maxImageSizeMb: $maxImageSizeMb, maxVideoSizeMb: $maxVideoSizeMb, maxDocumentSizeMb: $maxDocumentSizeMb, maxAudioDurationSeconds: $maxAudioDurationSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaLimitsEntityImpl &&
            (identical(other.imageMaxWidth, imageMaxWidth) ||
                other.imageMaxWidth == imageMaxWidth) &&
            (identical(other.imageMaxHeight, imageMaxHeight) ||
                other.imageMaxHeight == imageMaxHeight) &&
            (identical(other.imageQuality, imageQuality) ||
                other.imageQuality == imageQuality) &&
            (identical(other.maxImagesPerUpload, maxImagesPerUpload) ||
                other.maxImagesPerUpload == maxImagesPerUpload) &&
            (identical(other.minWidthForCompression, minWidthForCompression) ||
                other.minWidthForCompression == minWidthForCompression) &&
            (identical(other.messageMaxChars, messageMaxChars) ||
                other.messageMaxChars == messageMaxChars) &&
            (identical(
                  other.messageCharCountThreshold,
                  messageCharCountThreshold,
                ) ||
                other.messageCharCountThreshold == messageCharCountThreshold) &&
            (identical(other.maxImageSizeMb, maxImageSizeMb) ||
                other.maxImageSizeMb == maxImageSizeMb) &&
            (identical(other.maxVideoSizeMb, maxVideoSizeMb) ||
                other.maxVideoSizeMb == maxVideoSizeMb) &&
            (identical(other.maxDocumentSizeMb, maxDocumentSizeMb) ||
                other.maxDocumentSizeMb == maxDocumentSizeMb) &&
            (identical(
                  other.maxAudioDurationSeconds,
                  maxAudioDurationSeconds,
                ) ||
                other.maxAudioDurationSeconds == maxAudioDurationSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
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
  );

  /// Create a copy of MediaLimitsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaLimitsEntityImplCopyWith<_$MediaLimitsEntityImpl> get copyWith =>
      __$$MediaLimitsEntityImplCopyWithImpl<_$MediaLimitsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _MediaLimitsEntity implements MediaLimitsEntity {
  const factory _MediaLimitsEntity({
    final int imageMaxWidth,
    final int imageMaxHeight,
    final int imageQuality,
    final int maxImagesPerUpload,
    final int minWidthForCompression,
    final int messageMaxChars,
    final int messageCharCountThreshold,
    final int maxImageSizeMb,
    final int maxVideoSizeMb,
    final int maxDocumentSizeMb,
    final int maxAudioDurationSeconds,
  }) = _$MediaLimitsEntityImpl;

  // Image settings
  @override
  int get imageMaxWidth;
  @override
  int get imageMaxHeight;
  @override
  int get imageQuality;
  @override
  int get maxImagesPerUpload;
  @override
  int get minWidthForCompression; // Message settings
  @override
  int get messageMaxChars;
  @override
  int get messageCharCountThreshold; // File limits (in MB)
  @override
  int get maxImageSizeMb;
  @override
  int get maxVideoSizeMb;
  @override
  int get maxDocumentSizeMb; // Audio settings
  @override
  int get maxAudioDurationSeconds;

  /// Create a copy of MediaLimitsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaLimitsEntityImplCopyWith<_$MediaLimitsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ValidationRulesEntity {
  int get passwordMinLength => throw _privateConstructorUsedError;
  int get passwordMaxLength => throw _privateConstructorUsedError;
  int get shareCodeLength => throw _privateConstructorUsedError;
  int get minSearchQueryLength => throw _privateConstructorUsedError;
  int get maxSearchQueryLength =>
      throw _privateConstructorUsedError; // Delete window for messages (in hours)
  int get messageDeleteWindowHours => throw _privateConstructorUsedError;

  /// Create a copy of ValidationRulesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ValidationRulesEntityCopyWith<ValidationRulesEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ValidationRulesEntityCopyWith<$Res> {
  factory $ValidationRulesEntityCopyWith(
    ValidationRulesEntity value,
    $Res Function(ValidationRulesEntity) then,
  ) = _$ValidationRulesEntityCopyWithImpl<$Res, ValidationRulesEntity>;
  @useResult
  $Res call({
    int passwordMinLength,
    int passwordMaxLength,
    int shareCodeLength,
    int minSearchQueryLength,
    int maxSearchQueryLength,
    int messageDeleteWindowHours,
  });
}

/// @nodoc
class _$ValidationRulesEntityCopyWithImpl<
  $Res,
  $Val extends ValidationRulesEntity
>
    implements $ValidationRulesEntityCopyWith<$Res> {
  _$ValidationRulesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ValidationRulesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passwordMinLength = null,
    Object? passwordMaxLength = null,
    Object? shareCodeLength = null,
    Object? minSearchQueryLength = null,
    Object? maxSearchQueryLength = null,
    Object? messageDeleteWindowHours = null,
  }) {
    return _then(
      _value.copyWith(
            passwordMinLength:
                null == passwordMinLength
                    ? _value.passwordMinLength
                    : passwordMinLength // ignore: cast_nullable_to_non_nullable
                        as int,
            passwordMaxLength:
                null == passwordMaxLength
                    ? _value.passwordMaxLength
                    : passwordMaxLength // ignore: cast_nullable_to_non_nullable
                        as int,
            shareCodeLength:
                null == shareCodeLength
                    ? _value.shareCodeLength
                    : shareCodeLength // ignore: cast_nullable_to_non_nullable
                        as int,
            minSearchQueryLength:
                null == minSearchQueryLength
                    ? _value.minSearchQueryLength
                    : minSearchQueryLength // ignore: cast_nullable_to_non_nullable
                        as int,
            maxSearchQueryLength:
                null == maxSearchQueryLength
                    ? _value.maxSearchQueryLength
                    : maxSearchQueryLength // ignore: cast_nullable_to_non_nullable
                        as int,
            messageDeleteWindowHours:
                null == messageDeleteWindowHours
                    ? _value.messageDeleteWindowHours
                    : messageDeleteWindowHours // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ValidationRulesEntityImplCopyWith<$Res>
    implements $ValidationRulesEntityCopyWith<$Res> {
  factory _$$ValidationRulesEntityImplCopyWith(
    _$ValidationRulesEntityImpl value,
    $Res Function(_$ValidationRulesEntityImpl) then,
  ) = __$$ValidationRulesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int passwordMinLength,
    int passwordMaxLength,
    int shareCodeLength,
    int minSearchQueryLength,
    int maxSearchQueryLength,
    int messageDeleteWindowHours,
  });
}

/// @nodoc
class __$$ValidationRulesEntityImplCopyWithImpl<$Res>
    extends
        _$ValidationRulesEntityCopyWithImpl<$Res, _$ValidationRulesEntityImpl>
    implements _$$ValidationRulesEntityImplCopyWith<$Res> {
  __$$ValidationRulesEntityImplCopyWithImpl(
    _$ValidationRulesEntityImpl _value,
    $Res Function(_$ValidationRulesEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ValidationRulesEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passwordMinLength = null,
    Object? passwordMaxLength = null,
    Object? shareCodeLength = null,
    Object? minSearchQueryLength = null,
    Object? maxSearchQueryLength = null,
    Object? messageDeleteWindowHours = null,
  }) {
    return _then(
      _$ValidationRulesEntityImpl(
        passwordMinLength:
            null == passwordMinLength
                ? _value.passwordMinLength
                : passwordMinLength // ignore: cast_nullable_to_non_nullable
                    as int,
        passwordMaxLength:
            null == passwordMaxLength
                ? _value.passwordMaxLength
                : passwordMaxLength // ignore: cast_nullable_to_non_nullable
                    as int,
        shareCodeLength:
            null == shareCodeLength
                ? _value.shareCodeLength
                : shareCodeLength // ignore: cast_nullable_to_non_nullable
                    as int,
        minSearchQueryLength:
            null == minSearchQueryLength
                ? _value.minSearchQueryLength
                : minSearchQueryLength // ignore: cast_nullable_to_non_nullable
                    as int,
        maxSearchQueryLength:
            null == maxSearchQueryLength
                ? _value.maxSearchQueryLength
                : maxSearchQueryLength // ignore: cast_nullable_to_non_nullable
                    as int,
        messageDeleteWindowHours:
            null == messageDeleteWindowHours
                ? _value.messageDeleteWindowHours
                : messageDeleteWindowHours // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$ValidationRulesEntityImpl implements _ValidationRulesEntity {
  const _$ValidationRulesEntityImpl({
    this.passwordMinLength = 6,
    this.passwordMaxLength = 128,
    this.shareCodeLength = 8,
    this.minSearchQueryLength = 3,
    this.maxSearchQueryLength = 100,
    this.messageDeleteWindowHours = 1,
  });

  @override
  @JsonKey()
  final int passwordMinLength;
  @override
  @JsonKey()
  final int passwordMaxLength;
  @override
  @JsonKey()
  final int shareCodeLength;
  @override
  @JsonKey()
  final int minSearchQueryLength;
  @override
  @JsonKey()
  final int maxSearchQueryLength;
  // Delete window for messages (in hours)
  @override
  @JsonKey()
  final int messageDeleteWindowHours;

  @override
  String toString() {
    return 'ValidationRulesEntity(passwordMinLength: $passwordMinLength, passwordMaxLength: $passwordMaxLength, shareCodeLength: $shareCodeLength, minSearchQueryLength: $minSearchQueryLength, maxSearchQueryLength: $maxSearchQueryLength, messageDeleteWindowHours: $messageDeleteWindowHours)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ValidationRulesEntityImpl &&
            (identical(other.passwordMinLength, passwordMinLength) ||
                other.passwordMinLength == passwordMinLength) &&
            (identical(other.passwordMaxLength, passwordMaxLength) ||
                other.passwordMaxLength == passwordMaxLength) &&
            (identical(other.shareCodeLength, shareCodeLength) ||
                other.shareCodeLength == shareCodeLength) &&
            (identical(other.minSearchQueryLength, minSearchQueryLength) ||
                other.minSearchQueryLength == minSearchQueryLength) &&
            (identical(other.maxSearchQueryLength, maxSearchQueryLength) ||
                other.maxSearchQueryLength == maxSearchQueryLength) &&
            (identical(
                  other.messageDeleteWindowHours,
                  messageDeleteWindowHours,
                ) ||
                other.messageDeleteWindowHours == messageDeleteWindowHours));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    passwordMinLength,
    passwordMaxLength,
    shareCodeLength,
    minSearchQueryLength,
    maxSearchQueryLength,
    messageDeleteWindowHours,
  );

  /// Create a copy of ValidationRulesEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ValidationRulesEntityImplCopyWith<_$ValidationRulesEntityImpl>
  get copyWith =>
      __$$ValidationRulesEntityImplCopyWithImpl<_$ValidationRulesEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _ValidationRulesEntity implements ValidationRulesEntity {
  const factory _ValidationRulesEntity({
    final int passwordMinLength,
    final int passwordMaxLength,
    final int shareCodeLength,
    final int minSearchQueryLength,
    final int maxSearchQueryLength,
    final int messageDeleteWindowHours,
  }) = _$ValidationRulesEntityImpl;

  @override
  int get passwordMinLength;
  @override
  int get passwordMaxLength;
  @override
  int get shareCodeLength;
  @override
  int get minSearchQueryLength;
  @override
  int get maxSearchQueryLength; // Delete window for messages (in hours)
  @override
  int get messageDeleteWindowHours;

  /// Create a copy of ValidationRulesEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ValidationRulesEntityImplCopyWith<_$ValidationRulesEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SystemIntervalsEntity {
  int get locationUpdateMinutes => throw _privateConstructorUsedError;
  int get heartbeatMinutes => throw _privateConstructorUsedError;
  int get cacheMinutes => throw _privateConstructorUsedError;
  int get remoteConfigFetchMinutes => throw _privateConstructorUsedError;
  int get typingIndicatorSeconds => throw _privateConstructorUsedError;

  /// Create a copy of SystemIntervalsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemIntervalsEntityCopyWith<SystemIntervalsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemIntervalsEntityCopyWith<$Res> {
  factory $SystemIntervalsEntityCopyWith(
    SystemIntervalsEntity value,
    $Res Function(SystemIntervalsEntity) then,
  ) = _$SystemIntervalsEntityCopyWithImpl<$Res, SystemIntervalsEntity>;
  @useResult
  $Res call({
    int locationUpdateMinutes,
    int heartbeatMinutes,
    int cacheMinutes,
    int remoteConfigFetchMinutes,
    int typingIndicatorSeconds,
  });
}

/// @nodoc
class _$SystemIntervalsEntityCopyWithImpl<
  $Res,
  $Val extends SystemIntervalsEntity
>
    implements $SystemIntervalsEntityCopyWith<$Res> {
  _$SystemIntervalsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemIntervalsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locationUpdateMinutes = null,
    Object? heartbeatMinutes = null,
    Object? cacheMinutes = null,
    Object? remoteConfigFetchMinutes = null,
    Object? typingIndicatorSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            locationUpdateMinutes:
                null == locationUpdateMinutes
                    ? _value.locationUpdateMinutes
                    : locationUpdateMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            heartbeatMinutes:
                null == heartbeatMinutes
                    ? _value.heartbeatMinutes
                    : heartbeatMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            cacheMinutes:
                null == cacheMinutes
                    ? _value.cacheMinutes
                    : cacheMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            remoteConfigFetchMinutes:
                null == remoteConfigFetchMinutes
                    ? _value.remoteConfigFetchMinutes
                    : remoteConfigFetchMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            typingIndicatorSeconds:
                null == typingIndicatorSeconds
                    ? _value.typingIndicatorSeconds
                    : typingIndicatorSeconds // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SystemIntervalsEntityImplCopyWith<$Res>
    implements $SystemIntervalsEntityCopyWith<$Res> {
  factory _$$SystemIntervalsEntityImplCopyWith(
    _$SystemIntervalsEntityImpl value,
    $Res Function(_$SystemIntervalsEntityImpl) then,
  ) = __$$SystemIntervalsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int locationUpdateMinutes,
    int heartbeatMinutes,
    int cacheMinutes,
    int remoteConfigFetchMinutes,
    int typingIndicatorSeconds,
  });
}

/// @nodoc
class __$$SystemIntervalsEntityImplCopyWithImpl<$Res>
    extends
        _$SystemIntervalsEntityCopyWithImpl<$Res, _$SystemIntervalsEntityImpl>
    implements _$$SystemIntervalsEntityImplCopyWith<$Res> {
  __$$SystemIntervalsEntityImplCopyWithImpl(
    _$SystemIntervalsEntityImpl _value,
    $Res Function(_$SystemIntervalsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SystemIntervalsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locationUpdateMinutes = null,
    Object? heartbeatMinutes = null,
    Object? cacheMinutes = null,
    Object? remoteConfigFetchMinutes = null,
    Object? typingIndicatorSeconds = null,
  }) {
    return _then(
      _$SystemIntervalsEntityImpl(
        locationUpdateMinutes:
            null == locationUpdateMinutes
                ? _value.locationUpdateMinutes
                : locationUpdateMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        heartbeatMinutes:
            null == heartbeatMinutes
                ? _value.heartbeatMinutes
                : heartbeatMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        cacheMinutes:
            null == cacheMinutes
                ? _value.cacheMinutes
                : cacheMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        remoteConfigFetchMinutes:
            null == remoteConfigFetchMinutes
                ? _value.remoteConfigFetchMinutes
                : remoteConfigFetchMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        typingIndicatorSeconds:
            null == typingIndicatorSeconds
                ? _value.typingIndicatorSeconds
                : typingIndicatorSeconds // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$SystemIntervalsEntityImpl implements _SystemIntervalsEntity {
  const _$SystemIntervalsEntityImpl({
    this.locationUpdateMinutes = 5,
    this.heartbeatMinutes = 10,
    this.cacheMinutes = 60,
    this.remoteConfigFetchMinutes = 60,
    this.typingIndicatorSeconds = 3,
  });

  @override
  @JsonKey()
  final int locationUpdateMinutes;
  @override
  @JsonKey()
  final int heartbeatMinutes;
  @override
  @JsonKey()
  final int cacheMinutes;
  @override
  @JsonKey()
  final int remoteConfigFetchMinutes;
  @override
  @JsonKey()
  final int typingIndicatorSeconds;

  @override
  String toString() {
    return 'SystemIntervalsEntity(locationUpdateMinutes: $locationUpdateMinutes, heartbeatMinutes: $heartbeatMinutes, cacheMinutes: $cacheMinutes, remoteConfigFetchMinutes: $remoteConfigFetchMinutes, typingIndicatorSeconds: $typingIndicatorSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemIntervalsEntityImpl &&
            (identical(other.locationUpdateMinutes, locationUpdateMinutes) ||
                other.locationUpdateMinutes == locationUpdateMinutes) &&
            (identical(other.heartbeatMinutes, heartbeatMinutes) ||
                other.heartbeatMinutes == heartbeatMinutes) &&
            (identical(other.cacheMinutes, cacheMinutes) ||
                other.cacheMinutes == cacheMinutes) &&
            (identical(
                  other.remoteConfigFetchMinutes,
                  remoteConfigFetchMinutes,
                ) ||
                other.remoteConfigFetchMinutes == remoteConfigFetchMinutes) &&
            (identical(other.typingIndicatorSeconds, typingIndicatorSeconds) ||
                other.typingIndicatorSeconds == typingIndicatorSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    locationUpdateMinutes,
    heartbeatMinutes,
    cacheMinutes,
    remoteConfigFetchMinutes,
    typingIndicatorSeconds,
  );

  /// Create a copy of SystemIntervalsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemIntervalsEntityImplCopyWith<_$SystemIntervalsEntityImpl>
  get copyWith =>
      __$$SystemIntervalsEntityImplCopyWithImpl<_$SystemIntervalsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _SystemIntervalsEntity implements SystemIntervalsEntity {
  const factory _SystemIntervalsEntity({
    final int locationUpdateMinutes,
    final int heartbeatMinutes,
    final int cacheMinutes,
    final int remoteConfigFetchMinutes,
    final int typingIndicatorSeconds,
  }) = _$SystemIntervalsEntityImpl;

  @override
  int get locationUpdateMinutes;
  @override
  int get heartbeatMinutes;
  @override
  int get cacheMinutes;
  @override
  int get remoteConfigFetchMinutes;
  @override
  int get typingIndicatorSeconds;

  /// Create a copy of SystemIntervalsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemIntervalsEntityImplCopyWith<_$SystemIntervalsEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SystemUrlsEntity {
  String get shareBaseUrl => throw _privateConstructorUsedError;
  String get supportEmail => throw _privateConstructorUsedError;
  String get stripeMerchantId => throw _privateConstructorUsedError;
  String get termsUrl => throw _privateConstructorUsedError;
  String get privacyUrl => throw _privateConstructorUsedError;

  /// Create a copy of SystemUrlsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemUrlsEntityCopyWith<SystemUrlsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemUrlsEntityCopyWith<$Res> {
  factory $SystemUrlsEntityCopyWith(
    SystemUrlsEntity value,
    $Res Function(SystemUrlsEntity) then,
  ) = _$SystemUrlsEntityCopyWithImpl<$Res, SystemUrlsEntity>;
  @useResult
  $Res call({
    String shareBaseUrl,
    String supportEmail,
    String stripeMerchantId,
    String termsUrl,
    String privacyUrl,
  });
}

/// @nodoc
class _$SystemUrlsEntityCopyWithImpl<$Res, $Val extends SystemUrlsEntity>
    implements $SystemUrlsEntityCopyWith<$Res> {
  _$SystemUrlsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemUrlsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shareBaseUrl = null,
    Object? supportEmail = null,
    Object? stripeMerchantId = null,
    Object? termsUrl = null,
    Object? privacyUrl = null,
  }) {
    return _then(
      _value.copyWith(
            shareBaseUrl:
                null == shareBaseUrl
                    ? _value.shareBaseUrl
                    : shareBaseUrl // ignore: cast_nullable_to_non_nullable
                        as String,
            supportEmail:
                null == supportEmail
                    ? _value.supportEmail
                    : supportEmail // ignore: cast_nullable_to_non_nullable
                        as String,
            stripeMerchantId:
                null == stripeMerchantId
                    ? _value.stripeMerchantId
                    : stripeMerchantId // ignore: cast_nullable_to_non_nullable
                        as String,
            termsUrl:
                null == termsUrl
                    ? _value.termsUrl
                    : termsUrl // ignore: cast_nullable_to_non_nullable
                        as String,
            privacyUrl:
                null == privacyUrl
                    ? _value.privacyUrl
                    : privacyUrl // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SystemUrlsEntityImplCopyWith<$Res>
    implements $SystemUrlsEntityCopyWith<$Res> {
  factory _$$SystemUrlsEntityImplCopyWith(
    _$SystemUrlsEntityImpl value,
    $Res Function(_$SystemUrlsEntityImpl) then,
  ) = __$$SystemUrlsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String shareBaseUrl,
    String supportEmail,
    String stripeMerchantId,
    String termsUrl,
    String privacyUrl,
  });
}

/// @nodoc
class __$$SystemUrlsEntityImplCopyWithImpl<$Res>
    extends _$SystemUrlsEntityCopyWithImpl<$Res, _$SystemUrlsEntityImpl>
    implements _$$SystemUrlsEntityImplCopyWith<$Res> {
  __$$SystemUrlsEntityImplCopyWithImpl(
    _$SystemUrlsEntityImpl _value,
    $Res Function(_$SystemUrlsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SystemUrlsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shareBaseUrl = null,
    Object? supportEmail = null,
    Object? stripeMerchantId = null,
    Object? termsUrl = null,
    Object? privacyUrl = null,
  }) {
    return _then(
      _$SystemUrlsEntityImpl(
        shareBaseUrl:
            null == shareBaseUrl
                ? _value.shareBaseUrl
                : shareBaseUrl // ignore: cast_nullable_to_non_nullable
                    as String,
        supportEmail:
            null == supportEmail
                ? _value.supportEmail
                : supportEmail // ignore: cast_nullable_to_non_nullable
                    as String,
        stripeMerchantId:
            null == stripeMerchantId
                ? _value.stripeMerchantId
                : stripeMerchantId // ignore: cast_nullable_to_non_nullable
                    as String,
        termsUrl:
            null == termsUrl
                ? _value.termsUrl
                : termsUrl // ignore: cast_nullable_to_non_nullable
                    as String,
        privacyUrl:
            null == privacyUrl
                ? _value.privacyUrl
                : privacyUrl // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc

class _$SystemUrlsEntityImpl implements _SystemUrlsEntity {
  const _$SystemUrlsEntityImpl({
    this.shareBaseUrl = 'https://diaspo-niger.web.app/p/',
    this.supportEmail = 'support@diasponiger.com',
    this.stripeMerchantId = 'merchant.com.diasponiger',
    this.termsUrl = 'https://diaspo-niger.web.app/terms',
    this.privacyUrl = 'https://diaspo-niger.web.app/privacy',
  });

  @override
  @JsonKey()
  final String shareBaseUrl;
  @override
  @JsonKey()
  final String supportEmail;
  @override
  @JsonKey()
  final String stripeMerchantId;
  @override
  @JsonKey()
  final String termsUrl;
  @override
  @JsonKey()
  final String privacyUrl;

  @override
  String toString() {
    return 'SystemUrlsEntity(shareBaseUrl: $shareBaseUrl, supportEmail: $supportEmail, stripeMerchantId: $stripeMerchantId, termsUrl: $termsUrl, privacyUrl: $privacyUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemUrlsEntityImpl &&
            (identical(other.shareBaseUrl, shareBaseUrl) ||
                other.shareBaseUrl == shareBaseUrl) &&
            (identical(other.supportEmail, supportEmail) ||
                other.supportEmail == supportEmail) &&
            (identical(other.stripeMerchantId, stripeMerchantId) ||
                other.stripeMerchantId == stripeMerchantId) &&
            (identical(other.termsUrl, termsUrl) ||
                other.termsUrl == termsUrl) &&
            (identical(other.privacyUrl, privacyUrl) ||
                other.privacyUrl == privacyUrl));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    shareBaseUrl,
    supportEmail,
    stripeMerchantId,
    termsUrl,
    privacyUrl,
  );

  /// Create a copy of SystemUrlsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemUrlsEntityImplCopyWith<_$SystemUrlsEntityImpl> get copyWith =>
      __$$SystemUrlsEntityImplCopyWithImpl<_$SystemUrlsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _SystemUrlsEntity implements SystemUrlsEntity {
  const factory _SystemUrlsEntity({
    final String shareBaseUrl,
    final String supportEmail,
    final String stripeMerchantId,
    final String termsUrl,
    final String privacyUrl,
  }) = _$SystemUrlsEntityImpl;

  @override
  String get shareBaseUrl;
  @override
  String get supportEmail;
  @override
  String get stripeMerchantId;
  @override
  String get termsUrl;
  @override
  String get privacyUrl;

  /// Create a copy of SystemUrlsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemUrlsEntityImplCopyWith<_$SystemUrlsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FeatureFlagsEntity {
  bool get moneyTransfer => throw _privateConstructorUsedError;
  bool get marketplace => throw _privateConstructorUsedError;
  bool get businessDirectory => throw _privateConstructorUsedError;
  bool get events => throw _privateConstructorUsedError;
  bool get groups => throw _privateConstructorUsedError;
  bool get embassies => throw _privateConstructorUsedError;
  bool get maintenanceMode => throw _privateConstructorUsedError;
  String? get maintenanceMessage => throw _privateConstructorUsedError;

  /// Create a copy of FeatureFlagsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeatureFlagsEntityCopyWith<FeatureFlagsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeatureFlagsEntityCopyWith<$Res> {
  factory $FeatureFlagsEntityCopyWith(
    FeatureFlagsEntity value,
    $Res Function(FeatureFlagsEntity) then,
  ) = _$FeatureFlagsEntityCopyWithImpl<$Res, FeatureFlagsEntity>;
  @useResult
  $Res call({
    bool moneyTransfer,
    bool marketplace,
    bool businessDirectory,
    bool events,
    bool groups,
    bool embassies,
    bool maintenanceMode,
    String? maintenanceMessage,
  });
}

/// @nodoc
class _$FeatureFlagsEntityCopyWithImpl<$Res, $Val extends FeatureFlagsEntity>
    implements $FeatureFlagsEntityCopyWith<$Res> {
  _$FeatureFlagsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeatureFlagsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? moneyTransfer = null,
    Object? marketplace = null,
    Object? businessDirectory = null,
    Object? events = null,
    Object? groups = null,
    Object? embassies = null,
    Object? maintenanceMode = null,
    Object? maintenanceMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            moneyTransfer:
                null == moneyTransfer
                    ? _value.moneyTransfer
                    : moneyTransfer // ignore: cast_nullable_to_non_nullable
                        as bool,
            marketplace:
                null == marketplace
                    ? _value.marketplace
                    : marketplace // ignore: cast_nullable_to_non_nullable
                        as bool,
            businessDirectory:
                null == businessDirectory
                    ? _value.businessDirectory
                    : businessDirectory // ignore: cast_nullable_to_non_nullable
                        as bool,
            events:
                null == events
                    ? _value.events
                    : events // ignore: cast_nullable_to_non_nullable
                        as bool,
            groups:
                null == groups
                    ? _value.groups
                    : groups // ignore: cast_nullable_to_non_nullable
                        as bool,
            embassies:
                null == embassies
                    ? _value.embassies
                    : embassies // ignore: cast_nullable_to_non_nullable
                        as bool,
            maintenanceMode:
                null == maintenanceMode
                    ? _value.maintenanceMode
                    : maintenanceMode // ignore: cast_nullable_to_non_nullable
                        as bool,
            maintenanceMessage:
                freezed == maintenanceMessage
                    ? _value.maintenanceMessage
                    : maintenanceMessage // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeatureFlagsEntityImplCopyWith<$Res>
    implements $FeatureFlagsEntityCopyWith<$Res> {
  factory _$$FeatureFlagsEntityImplCopyWith(
    _$FeatureFlagsEntityImpl value,
    $Res Function(_$FeatureFlagsEntityImpl) then,
  ) = __$$FeatureFlagsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool moneyTransfer,
    bool marketplace,
    bool businessDirectory,
    bool events,
    bool groups,
    bool embassies,
    bool maintenanceMode,
    String? maintenanceMessage,
  });
}

/// @nodoc
class __$$FeatureFlagsEntityImplCopyWithImpl<$Res>
    extends _$FeatureFlagsEntityCopyWithImpl<$Res, _$FeatureFlagsEntityImpl>
    implements _$$FeatureFlagsEntityImplCopyWith<$Res> {
  __$$FeatureFlagsEntityImplCopyWithImpl(
    _$FeatureFlagsEntityImpl _value,
    $Res Function(_$FeatureFlagsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeatureFlagsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? moneyTransfer = null,
    Object? marketplace = null,
    Object? businessDirectory = null,
    Object? events = null,
    Object? groups = null,
    Object? embassies = null,
    Object? maintenanceMode = null,
    Object? maintenanceMessage = freezed,
  }) {
    return _then(
      _$FeatureFlagsEntityImpl(
        moneyTransfer:
            null == moneyTransfer
                ? _value.moneyTransfer
                : moneyTransfer // ignore: cast_nullable_to_non_nullable
                    as bool,
        marketplace:
            null == marketplace
                ? _value.marketplace
                : marketplace // ignore: cast_nullable_to_non_nullable
                    as bool,
        businessDirectory:
            null == businessDirectory
                ? _value.businessDirectory
                : businessDirectory // ignore: cast_nullable_to_non_nullable
                    as bool,
        events:
            null == events
                ? _value.events
                : events // ignore: cast_nullable_to_non_nullable
                    as bool,
        groups:
            null == groups
                ? _value.groups
                : groups // ignore: cast_nullable_to_non_nullable
                    as bool,
        embassies:
            null == embassies
                ? _value.embassies
                : embassies // ignore: cast_nullable_to_non_nullable
                    as bool,
        maintenanceMode:
            null == maintenanceMode
                ? _value.maintenanceMode
                : maintenanceMode // ignore: cast_nullable_to_non_nullable
                    as bool,
        maintenanceMessage:
            freezed == maintenanceMessage
                ? _value.maintenanceMessage
                : maintenanceMessage // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$FeatureFlagsEntityImpl implements _FeatureFlagsEntity {
  const _$FeatureFlagsEntityImpl({
    this.moneyTransfer = true,
    this.marketplace = true,
    this.businessDirectory = true,
    this.events = true,
    this.groups = true,
    this.embassies = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,
  });

  @override
  @JsonKey()
  final bool moneyTransfer;
  @override
  @JsonKey()
  final bool marketplace;
  @override
  @JsonKey()
  final bool businessDirectory;
  @override
  @JsonKey()
  final bool events;
  @override
  @JsonKey()
  final bool groups;
  @override
  @JsonKey()
  final bool embassies;
  @override
  @JsonKey()
  final bool maintenanceMode;
  @override
  final String? maintenanceMessage;

  @override
  String toString() {
    return 'FeatureFlagsEntity(moneyTransfer: $moneyTransfer, marketplace: $marketplace, businessDirectory: $businessDirectory, events: $events, groups: $groups, embassies: $embassies, maintenanceMode: $maintenanceMode, maintenanceMessage: $maintenanceMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeatureFlagsEntityImpl &&
            (identical(other.moneyTransfer, moneyTransfer) ||
                other.moneyTransfer == moneyTransfer) &&
            (identical(other.marketplace, marketplace) ||
                other.marketplace == marketplace) &&
            (identical(other.businessDirectory, businessDirectory) ||
                other.businessDirectory == businessDirectory) &&
            (identical(other.events, events) || other.events == events) &&
            (identical(other.groups, groups) || other.groups == groups) &&
            (identical(other.embassies, embassies) ||
                other.embassies == embassies) &&
            (identical(other.maintenanceMode, maintenanceMode) ||
                other.maintenanceMode == maintenanceMode) &&
            (identical(other.maintenanceMessage, maintenanceMessage) ||
                other.maintenanceMessage == maintenanceMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    moneyTransfer,
    marketplace,
    businessDirectory,
    events,
    groups,
    embassies,
    maintenanceMode,
    maintenanceMessage,
  );

  /// Create a copy of FeatureFlagsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeatureFlagsEntityImplCopyWith<_$FeatureFlagsEntityImpl> get copyWith =>
      __$$FeatureFlagsEntityImplCopyWithImpl<_$FeatureFlagsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _FeatureFlagsEntity implements FeatureFlagsEntity {
  const factory _FeatureFlagsEntity({
    final bool moneyTransfer,
    final bool marketplace,
    final bool businessDirectory,
    final bool events,
    final bool groups,
    final bool embassies,
    final bool maintenanceMode,
    final String? maintenanceMessage,
  }) = _$FeatureFlagsEntityImpl;

  @override
  bool get moneyTransfer;
  @override
  bool get marketplace;
  @override
  bool get businessDirectory;
  @override
  bool get events;
  @override
  bool get groups;
  @override
  bool get embassies;
  @override
  bool get maintenanceMode;
  @override
  String? get maintenanceMessage;

  /// Create a copy of FeatureFlagsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeatureFlagsEntityImplCopyWith<_$FeatureFlagsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
