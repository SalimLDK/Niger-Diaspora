import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_ticket_entity.dart';
import '../providers/support_ticket_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final SupportTicketEntity ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark support messages as read when opening
    Future(() {
      ref
          .read(supportTicketNotifierProvider.notifier)
          .markAsRead(widget.ticket.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref
          .read(supportTicketNotifierProvider.notifier)
          .sendUserMessage(widget.ticket.id, content);

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messagesAsync =
        ref.watch(ticketMessagesProvider(widget.ticket.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticket.subject,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _statusLabel(widget.ticket.status, l10n),
              style: TextStyle(
                fontSize: 12,
                color: _statusColor(widget.ticket.status),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(l10n.error)),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                    return _MessageBubble(
                      message: message,
                      supportTeamLabel: l10n.supportTeam,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar (only if ticket is not closed/resolved)
          if (widget.ticket.status != TicketStatus.closed)
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
                          hintText: l10n.yourMessage,
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
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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

  String _statusLabel(TicketStatus status, AppLocalizations l10n) {
    return switch (status) {
      TicketStatus.open => l10n.ticketOpen,
      TicketStatus.inProgress => l10n.ticketInProgress,
      TicketStatus.resolved => l10n.ticketResolved,
      TicketStatus.closed => l10n.ticketClosed,
    };
  }

  Color _statusColor(TicketStatus status) {
    return switch (status) {
      TicketStatus.open => const Color(0xFF2196F3),
      TicketStatus.inProgress => const Color(0xFFFF9800),
      TicketStatus.resolved => const Color(0xFF4CAF50),
      TicketStatus.closed => const Color(0xFF9E9E9E),
    };
  }
}

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;
  final String supportTeamLabel;

  const _MessageBubble({
    required this.message,
    required this.supportTeamLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSupport = message.isFromSupport;
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isSupport ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSupport) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.support_agent,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSupport
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  isSupport ? supportTeamLabel : message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSupport
                        ? theme.colorScheme.primary
                        : context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSupport
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : context.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isSupport ? 4 : 16),
                      topRight: Radius.circular(isSupport ? 16 : 4),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: isSupport
                        ? null
                        : Border.all(
                            color:
                                context.borderColor.withValues(alpha: 0.3),
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
