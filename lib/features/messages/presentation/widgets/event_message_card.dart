import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Carte affichée dans une bulle de message pour un événement créé depuis
/// une discussion ou un groupe.
/// eventData structure: {eventId, title, startDate, location, isOnline}
class EventMessageCard extends StatelessWidget {
  final Map<String, dynamic> eventData;
  final bool isMe;

  const EventMessageCard({
    super.key,
    required this.eventData,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = eventData['title'] as String? ?? 'Événement';
    final eventId = eventData['eventId'] as String?;
    final isOnline = eventData['isOnline'] as bool? ?? false;
    final location = eventData['location'] as String?;
    final startDateRaw = eventData['startDate'] as String?;
    final startDate =
        startDateRaw != null ? DateTime.tryParse(startDateRaw)?.toLocal() : null;

    final dateLabel = startDate != null
        ? DateFormat('dd MMM yyyy · HH:mm').format(startDate)
        : null;
    final placeLabel = isOnline ? 'En ligne' : location;

    const accent = Colors.deepPurple;
    final onAccentSurface = isMe ? Colors.white70 : null;

    return GestureDetector(
      onTap: eventId != null ? () => context.push('/events/$eventId') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? Colors.white.withValues(alpha: 0.3)
                : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_rounded, size: 14, color: accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '📅 Événement',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (dateLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: onAccentSurface),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: onAccentSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (placeLabel != null && placeLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  isOnline
                      ? AppIcon(
                          AppIcon.video,
                          size: 12,
                          color: onAccentSurface,
                        )
                      : Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: onAccentSurface,
                        ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      placeLabel,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: onAccentSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Voir l\'événement →',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
