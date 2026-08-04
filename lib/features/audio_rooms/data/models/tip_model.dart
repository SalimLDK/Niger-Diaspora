import 'package:equatable/equatable.dart';

import '../../domain/entities/tip_entity.dart';

class TipModel extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String recipientId;
  final String recipientName;
  final int amount;
  final String currency;
  final String status;
  final String? sentAt;
  final String? message;
  final String? stripePaymentIntentId;
  final int commissionAmount;
  final int recipientAmount;
  final bool isDisplayed;

  const TipModel({
    this.id = '',
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    this.currency = 'XOF',
    this.status = 'pending',
    this.sentAt,
    this.message,
    this.stripePaymentIntentId,
    required this.commissionAmount,
    required this.recipientAmount,
    this.isDisplayed = false,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    return TipModel(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      recipientId: json['recipientId'] as String? ?? '',
      recipientName: json['recipientName'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'XOF',
      status: json['status'] as String? ?? 'pending',
      sentAt: _timestampToString(json['sentAt']),
      message: json['message'] as String?,
      stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
      commissionAmount: json['commissionAmount'] as int? ?? 0,
      recipientAmount: json['recipientAmount'] as int? ?? 0,
      isDisplayed: json['isDisplayed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'sentAt': sentAt,
      'message': message,
      'stripePaymentIntentId': stripePaymentIntentId,
      'commissionAmount': commissionAmount,
      'recipientAmount': recipientAmount,
      'isDisplayed': isDisplayed,
    };
  }
  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'sentAt': sentAt ?? DateTime.now().toIso8601String(),
      'message': message,
      'stripePaymentIntentId': stripePaymentIntentId,
      'commissionAmount': commissionAmount,
      'recipientAmount': recipientAmount,
      'isDisplayed': isDisplayed,
    };
  }

  TipEntity toEntity() {
    return TipEntity(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      recipientId: recipientId,
      recipientName: recipientName,
      amount: amount,
      currency: currency,
      status: _parseStatus(status),
      sentAt: sentAt != null ? DateTime.parse(sentAt!).toLocal() : DateTime.now(),
      message: message,
      stripePaymentIntentId: stripePaymentIntentId,
      commissionAmount: commissionAmount,
      recipientAmount: recipientAmount,
      isDisplayed: isDisplayed,
    );
  }

  static TipModel fromEntity(TipEntity entity) {
    return TipModel(
      id: entity.id,
      roomId: entity.roomId,
      senderId: entity.senderId,
      senderName: entity.senderName,
      senderPhotoUrl: entity.senderPhotoUrl,
      recipientId: entity.recipientId,
      recipientName: entity.recipientName,
      amount: entity.amount,
      currency: entity.currency,
      status: entity.status.name,
      sentAt: entity.sentAt.toIso8601String(),
      message: entity.message,
      stripePaymentIntentId: entity.stripePaymentIntentId,
      commissionAmount: entity.commissionAmount,
      recipientAmount: entity.recipientAmount,
      isDisplayed: entity.isDisplayed,
    );
  }

  TipModel copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? recipientId,
    String? recipientName,
    int? amount,
    String? currency,
    String? status,
    String? sentAt,
    String? message,
    String? stripePaymentIntentId,
    int? commissionAmount,
    int? recipientAmount,
    bool? isDisplayed,
  }) {
    return TipModel(
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

  static TipStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return TipStatus.pending;
      case 'completed':
        return TipStatus.completed;
      case 'failed':
        return TipStatus.failed;
      case 'refunded':
        return TipStatus.refunded;
      default:
        return TipStatus.pending;
    }
  }

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderId,
        recipientId,
        amount,
        currency,
        status,
        sentAt,
        message,
        stripePaymentIntentId,
        commissionAmount,
        recipientAmount,
        isDisplayed,
      ];
}
