import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}

enum TicketCategory {
  transaction,
  account,
  technical,
  other,
}

class SupportTicketEntity {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String description;
  final TicketCategory category;
  final TicketStatus status;
  final String? relatedTransactionId;
  final List<TicketMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasUnreadUserMessages;
  final bool hasUnreadSupportMessages;

  const SupportTicketEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    this.relatedTransactionId,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.hasUnreadUserMessages = false,
    this.hasUnreadSupportMessages = false,
  });

  factory SupportTicketEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SupportTicketEntity(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: TicketCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => TicketCategory.other,
      ),
      status: TicketStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TicketStatus.open,
      ),
      relatedTransactionId: data['relatedTransactionId'] as String?,
      messages: [],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasUnreadUserMessages: data['hasUnreadUserMessages'] as bool? ?? false,
      hasUnreadSupportMessages:
          data['hasUnreadSupportMessages'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'description': description,
      'category': category.name,
      'status': status.name,
      'relatedTransactionId': relatedTransactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'hasUnreadUserMessages': hasUnreadUserMessages,
      'hasUnreadSupportMessages': hasUnreadSupportMessages,
    };
  }

  SupportTicketEntity copyWith({
    TicketStatus? status,
    List<TicketMessage>? messages,
    bool? hasUnreadUserMessages,
    bool? hasUnreadSupportMessages,
  }) {
    return SupportTicketEntity(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      subject: subject,
      description: description,
      category: category,
      status: status ?? this.status,
      relatedTransactionId: relatedTransactionId,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      hasUnreadUserMessages:
          hasUnreadUserMessages ?? this.hasUnreadUserMessages,
      hasUnreadSupportMessages:
          hasUnreadSupportMessages ?? this.hasUnreadSupportMessages,
    );
  }
}

class TicketMessage {
  final String id;
  final String senderId;
  final String senderName;
  final bool isFromSupport;
  final String content;
  final DateTime createdAt;

  const TicketMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isFromSupport,
    required this.content,
    required this.createdAt,
  });

  factory TicketMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TicketMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      isFromSupport: data['isFromSupport'] as bool? ?? false,
      content: data['content'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'isFromSupport': isFromSupport,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
