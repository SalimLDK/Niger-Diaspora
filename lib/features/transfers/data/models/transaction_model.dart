import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/transaction_entity.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
class TransactionModel with _$TransactionModel {
  const TransactionModel._();

  const factory TransactionModel({
    required String id,
    required String senderId,
    required String recipientId,
    String? recipientName,
    String? recipientPhone,
    required double amount,
    required String currency,
    required double exchangeRate,
    required double amountInXof,
    required double fee,
    required double totalCharged,
    @Default('pending') String status,
    @Default('stripe') String provider,
    String? paymentIntentId,
    String? stripeChargeId,
    String? mynitaReference,
    String? failureReason,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert Timestamps to DateTime
    final processedData = <String, dynamic>{'id': doc.id};
    data.forEach((key, value) {
      if (value is Timestamp) {
        processedData[key] = value.toDate();
      } else {
        processedData[key] = value;
      }
    });

    return TransactionModel.fromJson(processedData);
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      senderId: entity.senderId,
      recipientId: entity.recipientId,
      recipientName: entity.recipientName,
      recipientPhone: entity.recipientPhone,
      amount: entity.amount,
      currency: entity.currency,
      exchangeRate: entity.exchangeRate,
      amountInXof: entity.amountInXof,
      fee: entity.fee,
      totalCharged: entity.totalCharged,
      status: entity.status.name,
      provider: entity.provider.name,
      paymentIntentId: entity.paymentIntentId,
      stripeChargeId: entity.stripeChargeId,
      mynitaReference: entity.mynitaReference,
      failureReason: entity.failureReason,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      notes: entity.notes,
    );
  }

  TransactionEntity toEntity() {
    return TransactionEntity(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      amount: amount,
      currency: currency,
      exchangeRate: exchangeRate,
      amountInXof: amountInXof,
      fee: fee,
      totalCharged: totalCharged,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => TransactionStatus.pending,
      ),
      provider: PaymentProvider.values.firstWhere(
        (e) => e.name == provider,
        orElse: () => PaymentProvider.stripe,
      ),
      paymentIntentId: paymentIntentId,
      stripeChargeId: stripeChargeId,
      mynitaReference: mynitaReference,
      failureReason: failureReason,
      createdAt: createdAt,
      completedAt: completedAt,
      notes: notes,
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
