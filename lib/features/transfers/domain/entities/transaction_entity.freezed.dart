// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TransactionEntity {
  String get id => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get recipientId => throw _privateConstructorUsedError;
  String? get recipientName => throw _privateConstructorUsedError;
  String? get recipientPhone => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  double get exchangeRate => throw _privateConstructorUsedError;
  double get amountInXof => throw _privateConstructorUsedError;
  double get fee => throw _privateConstructorUsedError;
  double get totalCharged => throw _privateConstructorUsedError;
  TransactionStatus get status => throw _privateConstructorUsedError;
  PaymentProvider get provider => throw _privateConstructorUsedError;
  String? get paymentIntentId => throw _privateConstructorUsedError;
  String? get stripeChargeId => throw _privateConstructorUsedError;
  String? get mynitaReference => throw _privateConstructorUsedError;
  String? get failureReason => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Create a copy of TransactionEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionEntityCopyWith<TransactionEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionEntityCopyWith<$Res> {
  factory $TransactionEntityCopyWith(
    TransactionEntity value,
    $Res Function(TransactionEntity) then,
  ) = _$TransactionEntityCopyWithImpl<$Res, TransactionEntity>;
  @useResult
  $Res call({
    String id,
    String senderId,
    String recipientId,
    String? recipientName,
    String? recipientPhone,
    double amount,
    String currency,
    double exchangeRate,
    double amountInXof,
    double fee,
    double totalCharged,
    TransactionStatus status,
    PaymentProvider provider,
    String? paymentIntentId,
    String? stripeChargeId,
    String? mynitaReference,
    String? failureReason,
    DateTime? createdAt,
    DateTime? completedAt,
    String? notes,
  });
}

/// @nodoc
class _$TransactionEntityCopyWithImpl<$Res, $Val extends TransactionEntity>
    implements $TransactionEntityCopyWith<$Res> {
  _$TransactionEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransactionEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? recipientId = null,
    Object? recipientName = freezed,
    Object? recipientPhone = freezed,
    Object? amount = null,
    Object? currency = null,
    Object? exchangeRate = null,
    Object? amountInXof = null,
    Object? fee = null,
    Object? totalCharged = null,
    Object? status = null,
    Object? provider = null,
    Object? paymentIntentId = freezed,
    Object? stripeChargeId = freezed,
    Object? mynitaReference = freezed,
    Object? failureReason = freezed,
    Object? createdAt = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            senderId:
                null == senderId
                    ? _value.senderId
                    : senderId // ignore: cast_nullable_to_non_nullable
                        as String,
            recipientId:
                null == recipientId
                    ? _value.recipientId
                    : recipientId // ignore: cast_nullable_to_non_nullable
                        as String,
            recipientName:
                freezed == recipientName
                    ? _value.recipientName
                    : recipientName // ignore: cast_nullable_to_non_nullable
                        as String?,
            recipientPhone:
                freezed == recipientPhone
                    ? _value.recipientPhone
                    : recipientPhone // ignore: cast_nullable_to_non_nullable
                        as String?,
            amount:
                null == amount
                    ? _value.amount
                    : amount // ignore: cast_nullable_to_non_nullable
                        as double,
            currency:
                null == currency
                    ? _value.currency
                    : currency // ignore: cast_nullable_to_non_nullable
                        as String,
            exchangeRate:
                null == exchangeRate
                    ? _value.exchangeRate
                    : exchangeRate // ignore: cast_nullable_to_non_nullable
                        as double,
            amountInXof:
                null == amountInXof
                    ? _value.amountInXof
                    : amountInXof // ignore: cast_nullable_to_non_nullable
                        as double,
            fee:
                null == fee
                    ? _value.fee
                    : fee // ignore: cast_nullable_to_non_nullable
                        as double,
            totalCharged:
                null == totalCharged
                    ? _value.totalCharged
                    : totalCharged // ignore: cast_nullable_to_non_nullable
                        as double,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as TransactionStatus,
            provider:
                null == provider
                    ? _value.provider
                    : provider // ignore: cast_nullable_to_non_nullable
                        as PaymentProvider,
            paymentIntentId:
                freezed == paymentIntentId
                    ? _value.paymentIntentId
                    : paymentIntentId // ignore: cast_nullable_to_non_nullable
                        as String?,
            stripeChargeId:
                freezed == stripeChargeId
                    ? _value.stripeChargeId
                    : stripeChargeId // ignore: cast_nullable_to_non_nullable
                        as String?,
            mynitaReference:
                freezed == mynitaReference
                    ? _value.mynitaReference
                    : mynitaReference // ignore: cast_nullable_to_non_nullable
                        as String?,
            failureReason:
                freezed == failureReason
                    ? _value.failureReason
                    : failureReason // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionEntityImplCopyWith<$Res>
    implements $TransactionEntityCopyWith<$Res> {
  factory _$$TransactionEntityImplCopyWith(
    _$TransactionEntityImpl value,
    $Res Function(_$TransactionEntityImpl) then,
  ) = __$$TransactionEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String senderId,
    String recipientId,
    String? recipientName,
    String? recipientPhone,
    double amount,
    String currency,
    double exchangeRate,
    double amountInXof,
    double fee,
    double totalCharged,
    TransactionStatus status,
    PaymentProvider provider,
    String? paymentIntentId,
    String? stripeChargeId,
    String? mynitaReference,
    String? failureReason,
    DateTime? createdAt,
    DateTime? completedAt,
    String? notes,
  });
}

/// @nodoc
class __$$TransactionEntityImplCopyWithImpl<$Res>
    extends _$TransactionEntityCopyWithImpl<$Res, _$TransactionEntityImpl>
    implements _$$TransactionEntityImplCopyWith<$Res> {
  __$$TransactionEntityImplCopyWithImpl(
    _$TransactionEntityImpl _value,
    $Res Function(_$TransactionEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TransactionEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? recipientId = null,
    Object? recipientName = freezed,
    Object? recipientPhone = freezed,
    Object? amount = null,
    Object? currency = null,
    Object? exchangeRate = null,
    Object? amountInXof = null,
    Object? fee = null,
    Object? totalCharged = null,
    Object? status = null,
    Object? provider = null,
    Object? paymentIntentId = freezed,
    Object? stripeChargeId = freezed,
    Object? mynitaReference = freezed,
    Object? failureReason = freezed,
    Object? createdAt = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$TransactionEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        senderId:
            null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                    as String,
        recipientId:
            null == recipientId
                ? _value.recipientId
                : recipientId // ignore: cast_nullable_to_non_nullable
                    as String,
        recipientName:
            freezed == recipientName
                ? _value.recipientName
                : recipientName // ignore: cast_nullable_to_non_nullable
                    as String?,
        recipientPhone:
            freezed == recipientPhone
                ? _value.recipientPhone
                : recipientPhone // ignore: cast_nullable_to_non_nullable
                    as String?,
        amount:
            null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                    as double,
        currency:
            null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                    as String,
        exchangeRate:
            null == exchangeRate
                ? _value.exchangeRate
                : exchangeRate // ignore: cast_nullable_to_non_nullable
                    as double,
        amountInXof:
            null == amountInXof
                ? _value.amountInXof
                : amountInXof // ignore: cast_nullable_to_non_nullable
                    as double,
        fee:
            null == fee
                ? _value.fee
                : fee // ignore: cast_nullable_to_non_nullable
                    as double,
        totalCharged:
            null == totalCharged
                ? _value.totalCharged
                : totalCharged // ignore: cast_nullable_to_non_nullable
                    as double,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as TransactionStatus,
        provider:
            null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                    as PaymentProvider,
        paymentIntentId:
            freezed == paymentIntentId
                ? _value.paymentIntentId
                : paymentIntentId // ignore: cast_nullable_to_non_nullable
                    as String?,
        stripeChargeId:
            freezed == stripeChargeId
                ? _value.stripeChargeId
                : stripeChargeId // ignore: cast_nullable_to_non_nullable
                    as String?,
        mynitaReference:
            freezed == mynitaReference
                ? _value.mynitaReference
                : mynitaReference // ignore: cast_nullable_to_non_nullable
                    as String?,
        failureReason:
            freezed == failureReason
                ? _value.failureReason
                : failureReason // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$TransactionEntityImpl implements _TransactionEntity {
  const _$TransactionEntityImpl({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.recipientName,
    this.recipientPhone,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.amountInXof,
    required this.fee,
    required this.totalCharged,
    this.status = TransactionStatus.pending,
    this.provider = PaymentProvider.stripe,
    this.paymentIntentId,
    this.stripeChargeId,
    this.mynitaReference,
    this.failureReason,
    this.createdAt,
    this.completedAt,
    this.notes,
  });

  @override
  final String id;
  @override
  final String senderId;
  @override
  final String recipientId;
  @override
  final String? recipientName;
  @override
  final String? recipientPhone;
  @override
  final double amount;
  @override
  final String currency;
  @override
  final double exchangeRate;
  @override
  final double amountInXof;
  @override
  final double fee;
  @override
  final double totalCharged;
  @override
  @JsonKey()
  final TransactionStatus status;
  @override
  @JsonKey()
  final PaymentProvider provider;
  @override
  final String? paymentIntentId;
  @override
  final String? stripeChargeId;
  @override
  final String? mynitaReference;
  @override
  final String? failureReason;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? completedAt;
  @override
  final String? notes;

  @override
  String toString() {
    return 'TransactionEntity(id: $id, senderId: $senderId, recipientId: $recipientId, recipientName: $recipientName, recipientPhone: $recipientPhone, amount: $amount, currency: $currency, exchangeRate: $exchangeRate, amountInXof: $amountInXof, fee: $fee, totalCharged: $totalCharged, status: $status, provider: $provider, paymentIntentId: $paymentIntentId, stripeChargeId: $stripeChargeId, mynitaReference: $mynitaReference, failureReason: $failureReason, createdAt: $createdAt, completedAt: $completedAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.recipientName, recipientName) ||
                other.recipientName == recipientName) &&
            (identical(other.recipientPhone, recipientPhone) ||
                other.recipientPhone == recipientPhone) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.exchangeRate, exchangeRate) ||
                other.exchangeRate == exchangeRate) &&
            (identical(other.amountInXof, amountInXof) ||
                other.amountInXof == amountInXof) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.totalCharged, totalCharged) ||
                other.totalCharged == totalCharged) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.paymentIntentId, paymentIntentId) ||
                other.paymentIntentId == paymentIntentId) &&
            (identical(other.stripeChargeId, stripeChargeId) ||
                other.stripeChargeId == stripeChargeId) &&
            (identical(other.mynitaReference, mynitaReference) ||
                other.mynitaReference == mynitaReference) &&
            (identical(other.failureReason, failureReason) ||
                other.failureReason == failureReason) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    senderId,
    recipientId,
    recipientName,
    recipientPhone,
    amount,
    currency,
    exchangeRate,
    amountInXof,
    fee,
    totalCharged,
    status,
    provider,
    paymentIntentId,
    stripeChargeId,
    mynitaReference,
    failureReason,
    createdAt,
    completedAt,
    notes,
  ]);

  /// Create a copy of TransactionEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionEntityImplCopyWith<_$TransactionEntityImpl> get copyWith =>
      __$$TransactionEntityImplCopyWithImpl<_$TransactionEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _TransactionEntity implements TransactionEntity {
  const factory _TransactionEntity({
    required final String id,
    required final String senderId,
    required final String recipientId,
    final String? recipientName,
    final String? recipientPhone,
    required final double amount,
    required final String currency,
    required final double exchangeRate,
    required final double amountInXof,
    required final double fee,
    required final double totalCharged,
    final TransactionStatus status,
    final PaymentProvider provider,
    final String? paymentIntentId,
    final String? stripeChargeId,
    final String? mynitaReference,
    final String? failureReason,
    final DateTime? createdAt,
    final DateTime? completedAt,
    final String? notes,
  }) = _$TransactionEntityImpl;

  @override
  String get id;
  @override
  String get senderId;
  @override
  String get recipientId;
  @override
  String? get recipientName;
  @override
  String? get recipientPhone;
  @override
  double get amount;
  @override
  String get currency;
  @override
  double get exchangeRate;
  @override
  double get amountInXof;
  @override
  double get fee;
  @override
  double get totalCharged;
  @override
  TransactionStatus get status;
  @override
  PaymentProvider get provider;
  @override
  String? get paymentIntentId;
  @override
  String? get stripeChargeId;
  @override
  String? get mynitaReference;
  @override
  String? get failureReason;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get completedAt;
  @override
  String? get notes;

  /// Create a copy of TransactionEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionEntityImplCopyWith<_$TransactionEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
