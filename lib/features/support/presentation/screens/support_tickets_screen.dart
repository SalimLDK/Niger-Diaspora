import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_ticket_entity.dart';
import '../providers/support_ticket_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ticketsAsync = ref.watch(userSupportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportTickets),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
        label: Text(l10n.newSupportTicket),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.error)),
        data: (tickets) {
          if (tickets.isEmpty) {
            return _EmptyStatePrompts(l10n: l10n);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return _TicketCard(ticket: ticket);
            },
          );
        },
      ),
    );
  }
}

/// État vide §11 : au lieu d'un simple texte gris, trois amorces typées qui
/// pré-remplissent le sujet et la catégorie du nouveau ticket.
class _EmptyStatePrompts extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyStatePrompts({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final prompts = <(IconData, String, TicketCategory)>[
      (Icons.receipt_long_outlined, l10n.supportPromptTransfer,
          TicketCategory.transaction),
      (Icons.person_outline, l10n.supportPromptAccount,
          TicketCategory.account),
      (Icons.build_outlined, l10n.supportPromptBug, TicketCategory.technical),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Icon(
            Icons.support_agent_outlined,
            size: 64,
            color: context.textTertiaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noSupportTickets,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.noSupportTicketsDesc,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.textTertiaryColor),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.supportPromptHeader,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 10),
        for (final (icon, label, category) in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(
                '/support/new',
                extra: {'subject': label, 'category': category},
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.borderColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: context.textSecondaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textTertiaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TicketCard extends ConsumerWidget {
  final SupportTicketEntity ticket;

  const _TicketCard({required this.ticket});

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
          color: ticket.hasUnreadSupportMessages
              ? theme.colorScheme.primary
              : context.borderColor.withValues(alpha: 0.5),
          width: ticket.hasUnreadSupportMessages ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/support/${ticket.id}', extra: ticket),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  const SizedBox(width: 8),
                  _buildStatusChip(ticket.status, l10n, theme),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.description,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _categoryIcon(ticket.category),
                    size: 14,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _categoryLabel(ticket.category, l10n),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (ticket.hasUnreadSupportMessages)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    dateFormat.format(ticket.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    TicketStatus status,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final (label, color) = switch (status) {
      TicketStatus.open => (l10n.ticketOpen, const Color(0xFF2196F3)),
      TicketStatus.inProgress =>
        (l10n.ticketInProgress, const Color(0xFFFF9800)),
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

  IconData _categoryIcon(TicketCategory category) {
    return switch (category) {
      TicketCategory.transaction => Icons.receipt_long_outlined,
      TicketCategory.account => Icons.person_outline,
      TicketCategory.technical => Icons.build_outlined,
      TicketCategory.other => Icons.help_outline,
    };
  }

  String _categoryLabel(TicketCategory category, AppLocalizations l10n) {
    return switch (category) {
      TicketCategory.transaction => l10n.ticketCategoryTransaction,
      TicketCategory.account => l10n.ticketCategoryAccount,
      TicketCategory.technical => l10n.ticketCategoryTechnical,
      TicketCategory.other => l10n.ticketCategoryOther,
    };
  }
}
