// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  String get productTitle => throw _privateConstructorUsedError;
  String? get productImageUrl => throw _privateConstructorUsedError;
  String get buyerId => throw _privateConstructorUsedError;
  String? get buyerName => throw _privateConstructorUsedError;
  String get sellerId => throw _privateConstructorUsedError;
  String? get sellerName => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  double get platformFee => throw _privateConstructorUsedError;
  double get sellerAmount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get escrowStatus => throw _privateConstructorUsedError;
  String? get escrowId => throw _privateConstructorUsedError;
  String? get shippingAddress => throw _privateConstructorUsedError;
  String? get trackingNumber => throw _privateConstructorUsedError;
  String? get buyerNote => throw _privateConstructorUsedError;
  String? get sellerNote => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get paidAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get shippedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get deliveredAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  String? get cancellationReason => throw _privateConstructorUsedError;

  /// Serializes this OrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
    OrderModel value,
    $Res Function(OrderModel) then,
  ) = _$OrderModelCopyWithImpl<$Res, OrderModel>;
  @useResult
  $Res call({
    String id,
    String productId,
    String productTitle,
    String? productImageUrl,
    String buyerId,
    String? buyerName,
    String sellerId,
    String? sellerName,
    double amount,
    double platformFee,
    double sellerAmount,
    String currency,
    int quantity,
    String status,
    String escrowStatus,
    String? escrowId,
    String? shippingAddress,
    String? trackingNumber,
    String? buyerNote,
    String? sellerNote,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? paidAt,
    @TimestampConverter() DateTime? shippedAt,
    @TimestampConverter() DateTime? deliveredAt,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime? cancelledAt,
    String? cancellationReason,
  });
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? productTitle = null,
    Object? productImageUrl = freezed,
    Object? buyerId = null,
    Object? buyerName = freezed,
    Object? sellerId = null,
    Object? sellerName = freezed,
    Object? amount = null,
    Object? platformFee = null,
    Object? sellerAmount = null,
    Object? currency = null,
    Object? quantity = null,
    Object? status = null,
    Object? escrowStatus = null,
    Object? escrowId = freezed,
    Object? shippingAddress = freezed,
    Object? trackingNumber = freezed,
    Object? buyerNote = freezed,
    Object? sellerNote = freezed,
    Object? createdAt = freezed,
    Object? paidAt = freezed,
    Object? shippedAt = freezed,
    Object? deliveredAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            productId:
                null == productId
                    ? _value.productId
                    : productId // ignore: cast_nullable_to_non_nullable
                        as String,
            productTitle:
                null == productTitle
                    ? _value.productTitle
                    : productTitle // ignore: cast_nullable_to_non_nullable
                        as String,
            productImageUrl:
                freezed == productImageUrl
                    ? _value.productImageUrl
                    : productImageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            buyerId:
                null == buyerId
                    ? _value.buyerId
                    : buyerId // ignore: cast_nullable_to_non_nullable
                        as String,
            buyerName:
                freezed == buyerName
                    ? _value.buyerName
                    : buyerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            sellerId:
                null == sellerId
                    ? _value.sellerId
                    : sellerId // ignore: cast_nullable_to_non_nullable
                        as String,
            sellerName:
                freezed == sellerName
                    ? _value.sellerName
                    : sellerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            amount:
                null == amount
                    ? _value.amount
                    : amount // ignore: cast_nullable_to_non_nullable
                        as double,
            platformFee:
                null == platformFee
                    ? _value.platformFee
                    : platformFee // ignore: cast_nullable_to_non_nullable
                        as double,
            sellerAmount:
                null == sellerAmount
                    ? _value.sellerAmount
                    : sellerAmount // ignore: cast_nullable_to_non_nullable
                        as double,
            currency:
                null == currency
                    ? _value.currency
                    : currency // ignore: cast_nullable_to_non_nullable
                        as String,
            quantity:
                null == quantity
                    ? _value.quantity
                    : quantity // ignore: cast_nullable_to_non_nullable
                        as int,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            escrowStatus:
                null == escrowStatus
                    ? _value.escrowStatus
                    : escrowStatus // ignore: cast_nullable_to_non_nullable
                        as String,
            escrowId:
                freezed == escrowId
                    ? _value.escrowId
                    : escrowId // ignore: cast_nullable_to_non_nullable
                        as String?,
            shippingAddress:
                freezed == shippingAddress
                    ? _value.shippingAddress
                    : shippingAddress // ignore: cast_nullable_to_non_nullable
                        as String?,
            trackingNumber:
                freezed == trackingNumber
                    ? _value.trackingNumber
                    : trackingNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            buyerNote:
                freezed == buyerNote
                    ? _value.buyerNote
                    : buyerNote // ignore: cast_nullable_to_non_nullable
                        as String?,
            sellerNote:
                freezed == sellerNote
                    ? _value.sellerNote
                    : sellerNote // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            paidAt:
                freezed == paidAt
                    ? _value.paidAt
                    : paidAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            shippedAt:
                freezed == shippedAt
                    ? _value.shippedAt
                    : shippedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            deliveredAt:
                freezed == deliveredAt
                    ? _value.deliveredAt
                    : deliveredAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            cancelledAt:
                freezed == cancelledAt
                    ? _value.cancelledAt
                    : cancelledAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            cancellationReason:
                freezed == cancellationReason
                    ? _value.cancellationReason
                    : cancellationReason // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
    _$OrderModelImpl value,
    $Res Function(_$OrderModelImpl) then,
  ) = __$$OrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    String productTitle,
    String? productImageUrl,
    String buyerId,
    String? buyerName,
    String sellerId,
    String? sellerName,
    double amount,
    double platformFee,
    double sellerAmount,
    String currency,
    int quantity,
    String status,
    String escrowStatus,
    String? escrowId,
    String? shippingAddress,
    String? trackingNumber,
    String? buyerNote,
    String? sellerNote,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? paidAt,
    @TimestampConverter() DateTime? shippedAt,
    @TimestampConverter() DateTime? deliveredAt,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime? cancelledAt,
    String? cancellationReason,
  });
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
    _$OrderModelImpl _value,
    $Res Function(_$OrderModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? productTitle = null,
    Object? productImageUrl = freezed,
    Object? buyerId = null,
    Object? buyerName = freezed,
    Object? sellerId = null,
    Object? sellerName = freezed,
    Object? amount = null,
    Object? platformFee = null,
    Object? sellerAmount = null,
    Object? currency = null,
    Object? quantity = null,
    Object? status = null,
    Object? escrowStatus = null,
    Object? escrowId = freezed,
    Object? shippingAddress = freezed,
    Object? trackingNumber = freezed,
    Object? buyerNote = freezed,
    Object? sellerNote = freezed,
    Object? createdAt = freezed,
    Object? paidAt = freezed,
    Object? shippedAt = freezed,
    Object? deliveredAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
  }) {
    return _then(
      _$OrderModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        productId:
            null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                    as String,
        productTitle:
            null == productTitle
                ? _value.productTitle
                : productTitle // ignore: cast_nullable_to_non_nullable
                    as String,
        productImageUrl:
            freezed == productImageUrl
                ? _value.productImageUrl
                : productImageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        buyerId:
            null == buyerId
                ? _value.buyerId
                : buyerId // ignore: cast_nullable_to_non_nullable
                    as String,
        buyerName:
            freezed == buyerName
                ? _value.buyerName
                : buyerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        sellerId:
            null == sellerId
                ? _value.sellerId
                : sellerId // ignore: cast_nullable_to_non_nullable
                    as String,
        sellerName:
            freezed == sellerName
                ? _value.sellerName
                : sellerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        amount:
            null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                    as double,
        platformFee:
            null == platformFee
                ? _value.platformFee
                : platformFee // ignore: cast_nullable_to_non_nullable
                    as double,
        sellerAmount:
            null == sellerAmount
                ? _value.sellerAmount
                : sellerAmount // ignore: cast_nullable_to_non_nullable
                    as double,
        currency:
            null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                    as String,
        quantity:
            null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                    as int,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        escrowStatus:
            null == escrowStatus
                ? _value.escrowStatus
                : escrowStatus // ignore: cast_nullable_to_non_nullable
                    as String,
        escrowId:
            freezed == escrowId
                ? _value.escrowId
                : escrowId // ignore: cast_nullable_to_non_nullable
                    as String?,
        shippingAddress:
            freezed == shippingAddress
                ? _value.shippingAddress
                : shippingAddress // ignore: cast_nullable_to_non_nullable
                    as String?,
        trackingNumber:
            freezed == trackingNumber
                ? _value.trackingNumber
                : trackingNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        buyerNote:
            freezed == buyerNote
                ? _value.buyerNote
                : buyerNote // ignore: cast_nullable_to_non_nullable
                    as String?,
        sellerNote:
            freezed == sellerNote
                ? _value.sellerNote
                : sellerNote // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        paidAt:
            freezed == paidAt
                ? _value.paidAt
                : paidAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        shippedAt:
            freezed == shippedAt
                ? _value.shippedAt
                : shippedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        deliveredAt:
            freezed == deliveredAt
                ? _value.deliveredAt
                : deliveredAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        cancelledAt:
            freezed == cancelledAt
                ? _value.cancelledAt
                : cancelledAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        cancellationReason:
            freezed == cancellationReason
                ? _value.cancellationReason
                : cancellationReason // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl extends _OrderModel {
  const _$OrderModelImpl({
    required this.id,
    required this.productId,
    required this.productTitle,
    this.productImageUrl,
    required this.buyerId,
    this.buyerName,
    required this.sellerId,
    this.sellerName,
    required this.amount,
    required this.platformFee,
    required this.sellerAmount,
    this.currency = 'XOF',
    required this.quantity,
    this.status = 'pending',
    this.escrowStatus = 'notCreated',
    this.escrowId,
    this.shippingAddress,
    this.trackingNumber,
    this.buyerNote,
    this.sellerNote,
    @TimestampConverter() this.createdAt,
    @TimestampConverter() this.paidAt,
    @TimestampConverter() this.shippedAt,
    @TimestampConverter() this.deliveredAt,
    @TimestampConverter() this.completedAt,
    @TimestampConverter() this.cancelledAt,
    this.cancellationReason,
  }) : super._();

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;
  @override
  final String productTitle;
  @override
  final String? productImageUrl;
  @override
  final String buyerId;
  @override
  final String? buyerName;
  @override
  final String sellerId;
  @override
  final String? sellerName;
  @override
  final double amount;
  @override
  final double platformFee;
  @override
  final double sellerAmount;
  @override
  @JsonKey()
  final String currency;
  @override
  final int quantity;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final String escrowStatus;
  @override
  final String? escrowId;
  @override
  final String? shippingAddress;
  @override
  final String? trackingNumber;
  @override
  final String? buyerNote;
  @override
  final String? sellerNote;
  @override
  @TimestampConverter()
  final DateTime? createdAt;
  @override
  @TimestampConverter()
  final DateTime? paidAt;
  @override
  @TimestampConverter()
  final DateTime? shippedAt;
  @override
  @TimestampConverter()
  final DateTime? deliveredAt;
  @override
  @TimestampConverter()
  final DateTime? completedAt;
  @override
  @TimestampConverter()
  final DateTime? cancelledAt;
  @override
  final String? cancellationReason;

  @override
  String toString() {
    return 'OrderModel(id: $id, productId: $productId, productTitle: $productTitle, productImageUrl: $productImageUrl, buyerId: $buyerId, buyerName: $buyerName, sellerId: $sellerId, sellerName: $sellerName, amount: $amount, platformFee: $platformFee, sellerAmount: $sellerAmount, currency: $currency, quantity: $quantity, status: $status, escrowStatus: $escrowStatus, escrowId: $escrowId, shippingAddress: $shippingAddress, trackingNumber: $trackingNumber, buyerNote: $buyerNote, sellerNote: $sellerNote, createdAt: $createdAt, paidAt: $paidAt, shippedAt: $shippedAt, deliveredAt: $deliveredAt, completedAt: $completedAt, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productTitle, productTitle) ||
                other.productTitle == productTitle) &&
            (identical(other.productImageUrl, productImageUrl) ||
                other.productImageUrl == productImageUrl) &&
            (identical(other.buyerId, buyerId) || other.buyerId == buyerId) &&
            (identical(other.buyerName, buyerName) ||
                other.buyerName == buyerName) &&
            (identical(other.sellerId, sellerId) ||
                other.sellerId == sellerId) &&
            (identical(other.sellerName, sellerName) ||
                other.sellerName == sellerName) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.sellerAmount, sellerAmount) ||
                other.sellerAmount == sellerAmount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.escrowStatus, escrowStatus) ||
                other.escrowStatus == escrowStatus) &&
            (identical(other.escrowId, escrowId) ||
                other.escrowId == escrowId) &&
            (identical(other.shippingAddress, shippingAddress) ||
                other.shippingAddress == shippingAddress) &&
            (identical(other.trackingNumber, trackingNumber) ||
                other.trackingNumber == trackingNumber) &&
            (identical(other.buyerNote, buyerNote) ||
                other.buyerNote == buyerNote) &&
            (identical(other.sellerNote, sellerNote) ||
                other.sellerNote == sellerNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.paidAt, paidAt) || other.paidAt == paidAt) &&
            (identical(other.shippedAt, shippedAt) ||
                other.shippedAt == shippedAt) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    productId,
    productTitle,
    productImageUrl,
    buyerId,
    buyerName,
    sellerId,
    sellerName,
    amount,
    platformFee,
    sellerAmount,
    currency,
    quantity,
    status,
    escrowStatus,
    escrowId,
    shippingAddress,
    trackingNumber,
    buyerNote,
    sellerNote,
    createdAt,
    paidAt,
    shippedAt,
    deliveredAt,
    completedAt,
    cancelledAt,
    cancellationReason,
  ]);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(this);
  }
}

abstract class _OrderModel extends OrderModel {
  const factory _OrderModel({
    required final String id,
    required final String productId,
    required final String productTitle,
    final String? productImageUrl,
    required final String buyerId,
    final String? buyerName,
    required final String sellerId,
    final String? sellerName,
    required final double amount,
    required final double platformFee,
    required final double sellerAmount,
    final String currency,
    required final int quantity,
    final String status,
    final String escrowStatus,
    final String? escrowId,
    final String? shippingAddress,
    final String? trackingNumber,
    final String? buyerNote,
    final String? sellerNote,
    @TimestampConverter() final DateTime? createdAt,
    @TimestampConverter() final DateTime? paidAt,
    @TimestampConverter() final DateTime? shippedAt,
    @TimestampConverter() final DateTime? deliveredAt,
    @TimestampConverter() final DateTime? completedAt,
    @TimestampConverter() final DateTime? cancelledAt,
    final String? cancellationReason,
  }) = _$OrderModelImpl;
  const _OrderModel._() : super._();

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;
  @override
  String get productTitle;
  @override
  String? get productImageUrl;
  @override
  String get buyerId;
  @override
  String? get buyerName;
  @override
  String get sellerId;
  @override
  String? get sellerName;
  @override
  double get amount;
  @override
  double get platformFee;
  @override
  double get sellerAmount;
  @override
  String get currency;
  @override
  int get quantity;
  @override
  String get status;
  @override
  String get escrowStatus;
  @override
  String? get escrowId;
  @override
  String? get shippingAddress;
  @override
  String? get trackingNumber;
  @override
  String? get buyerNote;
  @override
  String? get sellerNote;
  @override
  @TimestampConverter()
  DateTime? get createdAt;
  @override
  @TimestampConverter()
  DateTime? get paidAt;
  @override
  @TimestampConverter()
  DateTime? get shippedAt;
  @override
  @TimestampConverter()
  DateTime? get deliveredAt;
  @override
  @TimestampConverter()
  DateTime? get completedAt;
  @override
  @TimestampConverter()
  DateTime? get cancelledAt;
  @override
  String? get cancellationReason;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
