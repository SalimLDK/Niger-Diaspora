import 'package:equatable/equatable.dart';

import '../../../../core/services/currency_service.dart';
import '../monetization_rates.dart';

/// Status of a tip
enum TipStatus {
  /// Payment pending
  pending,

  /// Payment completed
  completed,

  /// Payment failed
  failed,

  /// Tip refunded
  refunded,
}

/// Entity representing a tip/pourboire sent to a speaker in an audio room
class TipEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// ID of the audio room
  final String roomId;

  /// ID of the sender
  final String senderId;

  /// Name of the sender
  final String senderName;

  /// Photo URL of the sender
  final String? senderPhotoUrl;

  /// ID of the recipient (speaker)
  final String recipientId;

  /// Name of the recipient
  final String recipientName;

  /// Amount in cents
  final int amount;

  /// Currency code
  final String currency;

  /// Status of the tip
  final TipStatus status;

  /// When the tip was sent
  final DateTime sentAt;

  /// Optional message with the tip
  final String? message;

  /// Stripe Payment Intent ID
  final String? stripePaymentIntentId;

  /// Platform commission amount in minor units (15%)
  final int commissionAmount;

  /// Recipient's net amount in cents
  final int recipientAmount;

  /// Whether the tip was displayed in the room
  final bool isDisplayed;

  const TipEntity({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.sentAt,
    this.message,
    this.stripePaymentIntentId,
    required this.commissionAmount,
    required this.recipientAmount,
    this.isDisplayed = false,
  });

  /// Commission de la plateforme (15 %).
  ///
  /// Doit rester alignée sur `PLATFORM_COMMISSION_RATE` de l'Edge Function
  /// `process-tip`, qui fait foi : c'est elle qui calcule et stocke le montant
  /// réellement prélevé. Cette constante valait 20 % — un taux qui n'existait
  /// nulle part côté serveur.
  static int calculateCommission(int amount) =>
      (amount * kAudioRoomsCommissionRate).round();

  /// Calculate recipient amount (85%)
  static int calculateRecipientAmount(int amount) =>
      amount - calculateCommission(amount);

  /// Format amount for display
  String get formattedAmount => CurrencyService.instance
      .formatMinor(amount, CurrencyExtension.fromCode(currency));

  /// Predefined tip amounts in XOF
  static const List<int> predefinedAmountsXOF = [500, 1000, 2000, 5000, 10000];

  /// Predefined tip amounts in EUR
  static const List<int> predefinedAmountsEUR = [1, 2, 5, 10, 20];

  TipEntity copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? recipientId,
    String? recipientName,
    int? amount,
    String? currency,
    TipStatus? status,
    DateTime? sentAt,
    String? message,
    String? stripePaymentIntentId,
    int? commissionAmount,
    int? recipientAmount,
    bool? isDisplayed,
  }) {
    return TipEntity(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      message: message ?? this.message,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      recipientAmount: recipientAmount ?? this.recipientAmount,
      isDisplayed: isDisplayed ?? this.isDisplayed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderId,
        recipientId,
        amount,
        status,
        sentAt,
      ];
}
