// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_boost_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BusinessBoostModel _$BusinessBoostModelFromJson(Map<String, dynamic> json) {
  return _BusinessBoostModel.fromJson(json);
}

/// @nodoc
mixin _$BusinessBoostModel {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get duration => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get paymentReference => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this BusinessBoostModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BusinessBoostModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BusinessBoostModelCopyWith<BusinessBoostModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusinessBoostModelCopyWith<$Res> {
  factory $BusinessBoostModelCopyWith(
    BusinessBoostModel value,
    $Res Function(BusinessBoostModel) then,
  ) = _$BusinessBoostModelCopyWithImpl<$Res, BusinessBoostModel>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    String type,
    String duration,
    double amount,
    String currency,
    DateTime startDate,
    DateTime endDate,
    String status,
    String? paymentReference,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$BusinessBoostModelCopyWithImpl<$Res, $Val extends BusinessBoostModel>
    implements $BusinessBoostModelCopyWith<$Res> {
  _$BusinessBoostModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BusinessBoostModel
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
                        as String,
            duration:
                null == duration
                    ? _value.duration
                    : duration // ignore: cast_nullable_to_non_nullable
                        as String,
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
                        as String,
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
abstract class _$$BusinessBoostModelImplCopyWith<$Res>
    implements $BusinessBoostModelCopyWith<$Res> {
  factory _$$BusinessBoostModelImplCopyWith(
    _$BusinessBoostModelImpl value,
    $Res Function(_$BusinessBoostModelImpl) then,
  ) = __$$BusinessBoostModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String userId,
    String type,
    String duration,
    double amount,
    String currency,
    DateTime startDate,
    DateTime endDate,
    String status,
    String? paymentReference,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$BusinessBoostModelImplCopyWithImpl<$Res>
    extends _$BusinessBoostModelCopyWithImpl<$Res, _$BusinessBoostModelImpl>
    implements _$$BusinessBoostModelImplCopyWith<$Res> {
  __$$BusinessBoostModelImplCopyWithImpl(
    _$BusinessBoostModelImpl _value,
    $Res Function(_$BusinessBoostModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BusinessBoostModel
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
      _$BusinessBoostModelImpl(
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
                    as String,
        duration:
            null == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                    as String,
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
                    as String,
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
@JsonSerializable()
class _$BusinessBoostModelImpl extends _BusinessBoostModel {
  const _$BusinessBoostModelImpl({
    required this.id,
    required this.businessId,
    required this.userId,
    this.type = 'standard',
    this.duration = 'days7',
    required this.amount,
    this.currency = 'XOF',
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    this.paymentReference,
    this.createdAt,
  }) : super._();

  factory _$BusinessBoostModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BusinessBoostModelImplFromJson(json);

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String userId;
  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final String duration;
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
  final String status;
  @override
  final String? paymentReference;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'BusinessBoostModel(id: $id, businessId: $businessId, userId: $userId, type: $type, duration: $duration, amount: $amount, currency: $currency, startDate: $startDate, endDate: $endDate, status: $status, paymentReference: $paymentReference, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessBoostModelImpl &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of BusinessBoostModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessBoostModelImplCopyWith<_$BusinessBoostModelImpl> get copyWith =>
      __$$BusinessBoostModelImplCopyWithImpl<_$BusinessBoostModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BusinessBoostModelImplToJson(this);
  }
}

abstract class _BusinessBoostModel extends BusinessBoostModel {
  const factory _BusinessBoostModel({
    required final String id,
    required final String businessId,
    required final String userId,
    final String type,
    final String duration,
    required final double amount,
    final String currency,
    required final DateTime startDate,
    required final DateTime endDate,
    final String status,
    final String? paymentReference,
    final DateTime? createdAt,
  }) = _$BusinessBoostModelImpl;
  const _BusinessBoostModel._() : super._();

  factory _BusinessBoostModel.fromJson(Map<String, dynamic> json) =
      _$BusinessBoostModelImpl.fromJson;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get userId;
  @override
  String get type;
  @override
  String get duration;
  @override
  double get amount;
  @override
  String get currency;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  String get status;
  @override
  String? get paymentReference;
  @override
  DateTime? get createdAt;

  /// Create a copy of BusinessBoostModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessBoostModelImplCopyWith<_$BusinessBoostModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
