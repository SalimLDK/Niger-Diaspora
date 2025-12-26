// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_boost_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BusinessBoostEntity {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  BoostType get type => throw _privateConstructorUsedError;
  BoostDuration get duration => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  BoostStatus get status => throw _privateConstructorUsedError;
  String? get paymentReference => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of BusinessBoostEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BusinessBoostEntityCopyWith<BusinessBoostEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusinessBoostEntityCopyWith<$Res> {
  factory $BusinessBoostEntityCopyWith(
    BusinessBoostEntity value,
    $Res Function(BusinessBoostEntity) then,
  ) = _$BusinessBoostEntityCopyWithImpl<$Res, BusinessBoostEntity>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    BoostType type,
    BoostDuration duration,
    double amount,
    String currency,
    DateTime startDate,
    DateTime endDate,
    BoostStatus status,
    String? paymentReference,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$BusinessBoostEntityCopyWithImpl<$Res, $Val extends BusinessBoostEntity>
    implements $BusinessBoostEntityCopyWith<$Res> {
  _$BusinessBoostEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BusinessBoostEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? userId = null,
    Object? type = null,
    Object? duration = null,
    Object? amount = null,
    Object? currency = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? status = null,
    Object? paymentReference = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            businessId:
                null == businessId
                    ? _value.businessId
                    : businessId // ignore: cast_nullable_to_non_nullable
                        as String,
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as BoostType,
            duration:
                null == duration
                    ? _value.duration
                    : duration // ignore: cast_nullable_to_non_nullable
                        as BoostDuration,
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
            startDate:
                null == startDate
                    ? _value.startDate
                    : startDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            endDate:
                null == endDate
                    ? _value.endDate
                    : endDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as BoostStatus,
            paymentReference:
                freezed == paymentReference
                    ? _value.paymentReference
                    : paymentReference // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BusinessBoostEntityImplCopyWith<$Res>
    implements $BusinessBoostEntityCopyWith<$Res> {
  factory _$$BusinessBoostEntityImplCopyWith(
    _$BusinessBoostEntityImpl value,
    $Res Function(_$BusinessBoostEntityImpl) then,
  ) = __$$BusinessBoostEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    BoostType type,
    BoostDuration duration,
    double amount,
    String currency,
    DateTime startDate,
    DateTime endDate,
    BoostStatus status,
    String? paymentReference,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$BusinessBoostEntityImplCopyWithImpl<$Res>
    extends _$BusinessBoostEntityCopyWithImpl<$Res, _$BusinessBoostEntityImpl>
    implements _$$BusinessBoostEntityImplCopyWith<$Res> {
  __$$BusinessBoostEntityImplCopyWithImpl(
    _$BusinessBoostEntityImpl _value,
    $Res Function(_$BusinessBoostEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BusinessBoostEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? userId = null,
    Object? type = null,
    Object? duration = null,
    Object? amount = null,
    Object? currency = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? status = null,
    Object? paymentReference = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$BusinessBoostEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        businessId:
            null == businessId
                ? _value.businessId
                : businessId // ignore: cast_nullable_to_non_nullable
                    as String,
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as BoostType,
        duration:
            null == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                    as BoostDuration,
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
        startDate:
            null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        endDate:
            null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as BoostStatus,
        paymentReference:
            freezed == paymentReference
                ? _value.paymentReference
                : paymentReference // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$BusinessBoostEntityImpl implements _BusinessBoostEntity {
  const _$BusinessBoostEntityImpl({
    required this.id,
    required this.businessId,
    required this.userId,
    this.type = BoostType.standard,
    this.duration = BoostDuration.days7,
    required this.amount,
    this.currency = 'XOF',
    required this.startDate,
    required this.endDate,
    this.status = BoostStatus.active,
    this.paymentReference,
    this.createdAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String userId;
  @override
  @JsonKey()
  final BoostType type;
  @override
  @JsonKey()
  final BoostDuration duration;
  @override
  final double amount;
  @override
  @JsonKey()
  final String currency;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  @JsonKey()
  final BoostStatus status;
  @override
  final String? paymentReference;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'BusinessBoostEntity(id: $id, businessId: $businessId, userId: $userId, type: $type, duration: $duration, amount: $amount, currency: $currency, startDate: $startDate, endDate: $endDate, status: $status, paymentReference: $paymentReference, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessBoostEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.paymentReference, paymentReference) ||
                other.paymentReference == paymentReference) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    userId,
    type,
    duration,
    amount,
    currency,
    startDate,
    endDate,
    status,
    paymentReference,
    createdAt,
  );

  /// Create a copy of BusinessBoostEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessBoostEntityImplCopyWith<_$BusinessBoostEntityImpl> get copyWith =>
      __$$BusinessBoostEntityImplCopyWithImpl<_$BusinessBoostEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _BusinessBoostEntity implements BusinessBoostEntity {
  const factory _BusinessBoostEntity({
    required final String id,
    required final String businessId,
    required final String userId,
    final BoostType type,
    final BoostDuration duration,
    required final double amount,
    final String currency,
    required final DateTime startDate,
    required final DateTime endDate,
    final BoostStatus status,
    final String? paymentReference,
    final DateTime? createdAt,
  }) = _$BusinessBoostEntityImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get userId;
  @override
  BoostType get type;
  @override
  BoostDuration get duration;
  @override
  double get amount;
  @override
  String get currency;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  BoostStatus get status;
  @override
  String? get paymentReference;
  @override
  DateTime? get createdAt;

  /// Create a copy of BusinessBoostEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessBoostEntityImplCopyWith<_$BusinessBoostEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
