import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_entity.freezed.dart';

@freezed
class TransactionEntity with _$TransactionEntity {
  const factory TransactionEntity({
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
    @Default(TransactionStatus.pending) TransactionStatus status,
    @Default(PaymentProvider.stripe) PaymentProvider provider,
    String? paymentIntentId,
    String? stripeChargeId,
    String? mynitaReference,
    String? failureReason,
    DateTime? createdAt,
    DateTime? completedAt,
    String? notes,
  }) = _TransactionEntity;
}

enum TransactionStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
  cancelled,
}

enum PaymentProvider {
  stripe,
  mynita,
}

extension TransactionStatusExtension on TransactionStatus {
  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'En attente';
      case TransactionStatus.processing:
        return 'En cours';
      case TransactionStatus.completed:
        return 'Termine';
      case TransactionStatus.failed:
        return 'Echoue';
      case TransactionStatus.refunded:
        return 'Rembourse';
      case TransactionStatus.cancelled:
        return 'Annule';
    }
  }

  bool get isActive {
    return this == TransactionStatus.pending || this == TransactionStatus.processing;
  }
}

extension PaymentProviderExtension on PaymentProvider {
  String get label {
    switch (this) {
      case PaymentProvider.stripe:
        return 'Carte bancaire';
      case PaymentProvider.mynita:
        return 'MyNita';
    }
  }
}
