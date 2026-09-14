import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';

import 'shared_card_palette.dart';

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

  /// Le texte posé tout seul sous la carte (« 📅 Titre ») : utile à l'aperçu
  /// de la liste et aux notifications, redondant dans la bulle.
  static bool isDefaultCaption(String content, Map<String, dynamic> eventData) {
    final titre = eventData['title'] as String? ?? '';
    return content.trim() == '📅 $titre';
  }

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

    final palette = SharedCardPalette.of(context, isMe: isMe);
    final accent = palette.accent;
    final onAccentSurface = palette.body;

    return GestureDetector(
      onTap: eventId != null ? () => context.push('/events/$eventId') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: palette.decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_rounded, size: 20, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Événement',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 16,
                      color: accent,
                      fontWeight: FontWeight.w700,
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
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: palette.title,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (dateLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 17, color: onAccentSurface),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 16, color: onAccentSurface),
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
                          size: 17,
                          color: onAccentSurface,
                        )
                      : Icon(
                          Icons.place_outlined,
                          size: 17,
                          color: onAccentSurface,
                        ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      placeLabel,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 16, color: onAccentSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Voir l\'événement →',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 16,
                color: accent,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
