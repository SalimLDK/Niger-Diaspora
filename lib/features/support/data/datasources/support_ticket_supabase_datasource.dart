import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/support_ticket_entity.dart';

class SupportTicketSupabaseDatasource {
  SupabaseClient get _supabase => Supabase.instance.client;

  SupportTicketEntity _fromRow(Map<String, dynamic> row) {
    final messages = (row['messages'] as List<dynamic>? ?? [])
        .map((m) {
          final msg = Map<String, dynamic>.from(m as Map);
          return TicketMessage(
            id: msg['id'] as String? ?? '',
            senderId: msg['senderId'] as String? ?? '',
            senderName: msg['senderName'] as String? ?? '',
            isFromSupport: msg['isFromSupport'] as bool? ?? false,
            content: msg['content'] as String? ?? '',
            createdAt: _parseDateTime(msg['createdAt']) ?? DateTime.now(),
          );
        })
        .toList();

    return SupportTicketEntity(
      id: row['id'].toString(),
      userId: row['user_id'] as String? ?? '',
      userName: row['user_name'] as String? ?? '',
      userEmail: row['user_email'] as String? ?? '',
      subject: row['subject'] as String? ?? '',
      description: row['description'] as String? ?? '',
      category: TicketCategory.values.firstWhere(
        (c) => c.name == row['category'],
        orElse: () => TicketCategory.other,
      ),
      status: TicketStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => TicketStatus.open,
      ),
      relatedTransactionId: row['related_transaction_id'] as String?,
      messages: messages,
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(row['updated_at']) ?? DateTime.now(),
      hasUnreadUserMessages: row['has_unread_user_messages'] as bool? ?? false,
      hasUnreadSupportMessages:
          row['has_unread_support_messages'] as bool? ?? false,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  /// Create a new support ticket
  Future<String> createTicket(SupportTicketEntity ticket) async {
    final firstMessage = {
      'id': 'msg_0',
      'senderId': ticket.userId,
      'senderName': ticket.userName,
      'isFromSupport': false,
      'content': ticket.description,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _supabase
        .from('support_tickets')
        .insert({
          'user_id': ticket.userId,
          'user_name': ticket.userName,
          'user_email': ticket.userEmail,
          'subject': ticket.subject,
          'description': ticket.description,
          'category': ticket.category.name,
          'status': ticket.status.name,
          'related_transaction_id': ticket.relatedTransactionId,
          'messages': [firstMessage],
          'has_unread_user_messages': false,
          'has_unread_support_messages': false,
        })
        .select('id')
        .single();

    return row['id'].toString();
  }

  /// Stream tickets for a specific user
  Stream<List<SupportTicketEntity>> watchUserTickets(String userId) {
    final controller = StreamController<List<SupportTicketEntity>>();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('support_tickets')
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(rows.map(_fromRow).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('support_tickets_user_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Stream all tickets (for admin)
  Stream<List<SupportTicketEntity>> watchAllTickets({
    TicketStatus? statusFilter,
  }) {
    final controller = StreamController<List<SupportTicketEntity>>();

    Future<void> fetch() async {
      try {
        var query = _supabase
            .from('support_tickets')
            .select();
        if (statusFilter != null) {
          query = query.eq('status', statusFilter.name);
        }
        final rows = await query.order('updated_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(rows.map(_fromRow).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('support_tickets_admin');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Stream messages for a ticket (read from JSONB column)
  Stream<List<TicketMessage>> watchMessages(String ticketId) {
    final controller = StreamController<List<TicketMessage>>();

    Future<void> fetch() async {
      try {
        final row = await _supabase
            .from('support_tickets')
            .select('messages')
            .eq('id', ticketId)
            .maybeSingle();

        if (row == null) {
          if (!controller.isClosed) controller.add([]);
          return;
        }

        final messages = (row['messages'] as List<dynamic>? ?? [])
            .map((m) {
              final msg = Map<String, dynamic>.from(m as Map);
              return TicketMessage(
                id: msg['id'] as String? ?? '',
                senderId: msg['senderId'] as String? ?? '',
                senderName: msg['senderName'] as String? ?? '',
                isFromSupport: msg['isFromSupport'] as bool? ?? false,
                content: msg['content'] as String? ?? '',
                createdAt:
                    _parseDateTime(msg['createdAt']) ?? DateTime.now(),
              );
            })
            .toList();

        if (!controller.isClosed) controller.add(messages);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('support_ticket_msgs_$ticketId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: ticketId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Send a message in a ticket (append to JSONB array via RPC or read-modify-write)
  Future<void> sendMessage(String ticketId, TicketMessage message) async {
    // Read current messages, append, then write back
    final row = await _supabase
        .from('support_tickets')
        .select('messages')
        .eq('id', ticketId)
        .single();

    final current = List<dynamic>.from(row['messages'] as List? ?? []);
    current.add({
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': message.senderId,
      'senderName': message.senderName,
      'isFromSupport': message.isFromSupport,
      'content': message.content,
      'createdAt': message.createdAt.toUtc().toIso8601String(),
    });

    await _supabase.from('support_tickets').update({
      'messages': current,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (message.isFromSupport) 'has_unread_support_messages': true,
      if (!message.isFromSupport) 'has_unread_user_messages': true,
    }).eq('id', ticketId);
  }

  /// Update ticket status
  Future<void> updateTicketStatus(
    String ticketId,
    TicketStatus status,
  ) async {
    await _supabase.from('support_tickets').update({
      'status': status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ticketId);
  }

  /// Mark support messages as read (user side)
  Future<void> markSupportMessagesRead(String ticketId) async {
    await _supabase
        .from('support_tickets')
        .update({'has_unread_support_messages': false})
        .eq('id', ticketId);
  }

  /// Mark user messages as read (admin side)
  Future<void> markUserMessagesRead(String ticketId) async {
    await _supabase
        .from('support_tickets')
        .update({'has_unread_user_messages': false})
        .eq('id', ticketId);
  }

  /// Get a single ticket
  Future<SupportTicketEntity?> getTicket(String ticketId) async {
    final row = await _supabase
        .from('support_tickets')
        .select()
        .eq('id', ticketId)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Count unread tickets for a user
  Stream<int> watchUnreadCount(String userId) {
    final controller = StreamController<int>();

    Future<void> fetch() async {
      try {
        final response = await _supabase
            .from('support_tickets')
            .select()
            .eq('user_id', userId)
            .eq('has_unread_support_messages', true)
            .count(CountOption.exact);
        if (!controller.isClosed) {
          controller.add(response.count);
        }
      } catch (_) {
        if (!controller.isClosed) controller.add(0);
      }
    }

    fetch();

    final channel = _supabase.channel('support_tickets_unread_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
