import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audio_room_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Card widget displaying an audio room
class AudioRoomCard extends StatelessWidget {
  final AudioRoomEntity room;
  final VoidCallback onTap;
  final bool isScheduled;

  const AudioRoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.isScheduled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: context.surfaceColor,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with live badge or scheduled time
              Row(
                children: [
                  if (!isScheduled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'EN DIRECT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: context.adaptivePrimaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatScheduledTime(context, room.scheduledAt),
                      style: TextStyle(
                        color: context.adaptivePrimaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (room.isPrivate)
                    AppIcon(AppIcon.lock,
                      size: 16,
                      color: context.textTertiaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                room.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Description
              if (room.description != null && room.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  room.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Host info
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                    backgroundImage: room.hostPhotoUrl != null
                        ? NetworkImage(room.hostPhotoUrl!)
                        : null,
                    child: room.hostPhotoUrl == null
                        ? AppIcon(AppIcon.person,
                            size: 16,
                            color: context.adaptivePrimaryColor,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      room.hostName,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tags
              if (room.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: room.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Participants count
              Row(
                children: [
                  AppIcon(AppIcon.people,
                    size: 16,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${room.totalParticipants} participant${room.totalParticipants > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                  const Spacer(),
                  // Speakers count
                  AppIcon(AppIcon.mic,
                    size: 16,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${room.speakerCount}/${room.maxSpeakers}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),

              // Paid room indicator
              if (room.isPaid) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.warningColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(AppIcon.star,
                        size: 16,
                        color: context.warningColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.ticketPrice} ${room.ticketCurrency ?? 'XOF'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatScheduledTime(BuildContext context, DateTime? scheduledAt) {
    if (scheduledAt == null) return '';

    final now = DateTime.now();
    final difference = scheduledAt.difference(now);
    final l10n = AppLocalizations.of(context)!;
    final timeStr = DateFormat.Hm().format(scheduledAt);

    if (difference.inDays == 0) {
      return l10n.todayAt(timeStr);
    } else if (difference.inDays == 1) {
      return l10n.tomorrowAt(timeStr);
    } else {
      return '${DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(scheduledAt)} $timeStr';
    }
  }
}

/// Compact version of AudioRoomCard for horizontal lists
class AudioRoomCardCompact extends StatelessWidget {
  final AudioRoomEntity room;
  final VoidCallback onTap;

  const AudioRoomCardCompact({
    super.key,
    required this.room,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${room.totalParticipants}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                AppIcon(AppIcon.people,
                  size: 12,
                  color: context.textTertiaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              room.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Host
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                  backgroundImage: room.hostPhotoUrl != null
                      ? NetworkImage(room.hostPhotoUrl!)
                      : null,
                  child: room.hostPhotoUrl == null
                      ? AppIcon(AppIcon.person,
                          size: 12,
                          color: context.adaptivePrimaryColor,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    room.hostName,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
