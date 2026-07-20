import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_ticket_entity.dart';
import '../providers/support_ticket_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  TicketStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final datasource = ref.watch(supportTicketDatasourceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTickets)),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip(null, l10n.allTransactions, theme, l10n),
                const SizedBox(width: 8),
                _filterChip(TicketStatus.open, l10n.ticketOpen, theme, l10n),
                const SizedBox(width: 8),
                _filterChip(
                  TicketStatus.inProgress,
                  l10n.ticketInProgress,
                  theme,
                  l10n,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  TicketStatus.resolved,
                  l10n.ticketResolved,
                  theme,
                  l10n,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  TicketStatus.closed,
                  l10n.ticketClosed,
                  theme,
                  l10n,
                ),
              ],
            ),
          ),

          // Tickets list
          Expanded(
            child: StreamBuilder<List<SupportTicketEntity>>(
              stream: datasource.watchAllTickets(statusFilter: _statusFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tickets = snapshot.data ?? [];

                if (tickets.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noSupportTickets,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _AdminTicketCard(ticket: ticket);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    TicketStatus? status,
    String label,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color:
            isSelected ? theme.colorScheme.primary : context.textSecondaryColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _AdminTicketCard extends ConsumerWidget {
  final SupportTicketEntity ticket;

  const _AdminTicketCard({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              ticket.hasUnreadUserMessages
                  ? theme.colorScheme.error
                  : context.borderColor.withValues(alpha: 0.5),
          width: ticket.hasUnreadUserMessages ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAdminTicketDetail(context, ref, ticket),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (ticket.hasUnreadUserMessages)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(ticket.status, l10n),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${ticket.userName} (${ticket.userEmail})',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(ticket.updatedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAdminTicketDetail(
    BuildContext context,
    WidgetRef ref,
    SupportTicketEntity ticket,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminTicketDetailScreen(ticket: ticket),
      ),
    );
  }

  Widget _buildStatusChip(TicketStatus status, AppLocalizations l10n) {
    final (label, color) = switch (status) {
      TicketStatus.open => (l10n.ticketOpen, const Color(0xFF2196F3)),
      TicketStatus.inProgress => (
        l10n.ticketInProgress,
        const Color(0xFFFF9800),
      ),
      TicketStatus.resolved => (l10n.ticketResolved, const Color(0xFF4CAF50)),
      TicketStatus.closed => (l10n.ticketClosed, const Color(0xFF9E9E9E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Admin ticket detail screen with reply + status change capabilities
class _AdminTicketDetailScreen extends ConsumerStatefulWidget {
  final SupportTicketEntity ticket;

  const _AdminTicketDetailScreen({required this.ticket});

  @override
  ConsumerState<_AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState
    extends ConsumerState<_AdminTicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future(() {
      ref
          .read(supportTicketNotifierProvider.notifier)
          .markUserMessagesAsRead(widget.ticket.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref
          .read(supportTicketNotifierProvider.notifier)
          .sendSupportReply(widget.ticket.id, content, 'Support Diaspo Niger');

      // Auto-set status to inProgress if it was open
      if (widget.ticket.status == TicketStatus.open) {
        await ref
            .read(supportTicketNotifierProvider.notifier)
            .updateStatus(widget.ticket.id, TicketStatus.inProgress);
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.error)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _changeStatus(TicketStatus newStatus) async {
    try {
      await ref
          .read(supportTicketNotifierProvider.notifier)
          .updateStatus(widget.ticket.id, newStatus);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.supportTicketUpdated)));
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(ticketMessagesProvider(widget.ticket.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticket.subject, style: const TextStyle(fontSize: 16)),
            Text(
              '${widget.ticket.userName} - ${widget.ticket.userEmail}',
              style: TextStyle(fontSize: 11, color: context.textSecondaryColor),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<TicketStatus>(
            icon: const Icon(Icons.more_vert),
            onSelected: _changeStatus,
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: TicketStatus.open,
                    child: Text(l10n.ticketOpen),
                  ),
                  PopupMenuItem(
                    value: TicketStatus.inProgress,
                    child: Text(l10n.ticketInProgress),
                  ),
                  PopupMenuItem(
                    value: TicketStatus.resolved,
                    child: Text(l10n.ticketResolved),
                  ),
                  PopupMenuItem(
                    value: TicketStatus.closed,
                    child: Text(l10n.ticketClosed),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(l10n.error)),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _AdminMessageBubble(message: message);
                  },
                );
              },
            ),
          ),

          // Reply input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                top: BorderSide(
                  color: context.borderColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: l10n.supportReply,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendReply,
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : AppIcon(AppIcon.send, color: Theme.of(context).iconTheme.color!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  final TicketMessage message;

  const _AdminMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSupport = message.isFromSupport;
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isSupport ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSupport) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE0E0E0),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isSupport ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isSupport ? message.senderName : message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSupport
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : context.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isSupport ? 16 : 4),
                      topRight: Radius.circular(isSupport ? 4 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border:
                        isSupport
                            ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            )
                            : Border.all(
                              color: context.borderColor.withValues(alpha: 0.3),
                            ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isSupport) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
