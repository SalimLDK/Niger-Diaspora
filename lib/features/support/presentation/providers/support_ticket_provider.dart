import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/support_ticket_supabase_datasource.dart';
import '../../domain/entities/support_ticket_entity.dart';

/// Provider for support ticket datasource
final supportTicketDatasourceProvider = Provider<SupportTicketSupabaseDatasource>((ref) {
  return SupportTicketSupabaseDatasource();
});

/// Stream of current user's support tickets
final userSupportTicketsProvider =
    StreamProvider<List<SupportTicketEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserAsyncProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final datasource = ref.watch(supportTicketDatasourceProvider);
  yield* datasource.watchUserTickets(currentUser.id);
});

/// Stream of messages for a specific ticket
final ticketMessagesProvider =
    StreamProvider.family<List<TicketMessage>, String>((ref, ticketId) {
  final datasource = ref.watch(supportTicketDatasourceProvider);
  return datasource.watchMessages(ticketId);
});

/// Unread support messages count for badge
final unreadSupportCountProvider = StreamProvider<int>((ref) async* {
  final currentUser = await ref.watch(currentUserAsyncProvider.future);
  if (currentUser == null) {
    yield 0;
    return;
  }

  final datasource = ref.watch(supportTicketDatasourceProvider);
  yield* datasource.watchUnreadCount(currentUser.id);
});

/// Admin filter for ticket status
final adminTicketFilterProvider = StateProvider<TicketStatus?>((ref) => null);

/// Notifier for support ticket actions
final supportTicketNotifierProvider =
    NotifierProvider<SupportTicketNotifier, AsyncValue<void>>(
  SupportTicketNotifier.new,
);

class SupportTicketNotifier extends Notifier<AsyncValue<void>> {
  SupportTicketSupabaseDatasource get _datasource =>
      ref.read(supportTicketDatasourceProvider);

  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Create a new ticket
  Future<String> createTicket({
    required String subject,
    required String description,
    required TicketCategory category,
    String? relatedTransactionId,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) throw Exception('User not authenticated');

    final ticket = SupportTicketEntity(
      id: '',
      userId: currentUser.id,
      userName: currentUser.displayName ?? '',
      userEmail: currentUser.email ?? '',
      subject: subject,
      description: description,
      category: category,
      status: TicketStatus.open,
      relatedTransactionId: relatedTransactionId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await _datasource.createTicket(ticket);
  }

  /// Send a user message
  Future<void> sendUserMessage(String ticketId, String content) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final message = TicketMessage(
      id: '',
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? '',
      isFromSupport: false,
      content: content,
      createdAt: DateTime.now(),
    );

    await _datasource.sendMessage(ticketId, message);
  }

  /// Send a support reply (admin)
  Future<void> sendSupportReply(
    String ticketId,
    String content,
    String adminName,
  ) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final message = TicketMessage(
      id: '',
      senderId: currentUser.id,
      senderName: adminName,
      isFromSupport: true,
      content: content,
      createdAt: DateTime.now(),
    );

    await _datasource.sendMessage(ticketId, message);
  }

  /// Update ticket status (admin)
  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    await _datasource.updateTicketStatus(ticketId, status);
  }

  /// Mark support messages as read (user side)
  Future<void> markAsRead(String ticketId) async {
    await _datasource.markSupportMessagesRead(ticketId);
  }

  /// Mark user messages as read (admin side)
  Future<void> markUserMessagesAsRead(String ticketId) async {
    await _datasource.markUserMessagesRead(ticketId);
  }
}
