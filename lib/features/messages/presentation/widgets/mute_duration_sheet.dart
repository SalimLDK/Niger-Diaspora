import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/conversation_actions_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Duration options for muting a conversation
enum MuteDuration {
  oneHour,
  eightHours,
  oneDay,
  oneWeek,
  forever,
}

extension MuteDurationExtension on MuteDuration {
  Duration? toDuration() {
    switch (this) {
      case MuteDuration.oneHour:
        return const Duration(hours: 1);
      case MuteDuration.eightHours:
        return const Duration(hours: 8);
      case MuteDuration.oneDay:
        return const Duration(days: 1);
      case MuteDuration.oneWeek:
        return const Duration(days: 7);
      case MuteDuration.forever:
        return null; // Forever
    }
  }

  String getLabel(AppLocalizations l10n) {
    switch (this) {
      case MuteDuration.oneHour:
        return l10n.muteFor1Hour;
      case MuteDuration.eightHours:
        return l10n.muteFor8Hours;
      case MuteDuration.oneDay:
        return l10n.muteFor24Hours;
      case MuteDuration.oneWeek:
        return l10n.muteFor1Week;
      case MuteDuration.forever:
        return l10n.muteForever;
    }
  }

  IconData get icon {
    switch (this) {
      case MuteDuration.oneHour:
      case MuteDuration.eightHours:
        return Icons.schedule;
      case MuteDuration.oneDay:
        return Icons.today;
      case MuteDuration.oneWeek:
        return Icons.date_range;
      case MuteDuration.forever:
        return Icons.notifications_off;
    }
  }
}

/// Bottom sheet for selecting mute duration
class MuteDurationSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final DateTime? currentMuteExpiration;

  const MuteDurationSheet({
    super.key,
    required this.conversationId,
    this.currentMuteExpiration,
  });

  /// Show the mute duration sheet and return true if muted successfully
  static Future<bool> show(
    BuildContext context, {
    required String conversationId,
    DateTime? currentMuteExpiration,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MuteDurationSheet(
        conversationId: conversationId,
        currentMuteExpiration: currentMuteExpiration,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<MuteDurationSheet> createState() => _MuteDurationSheetState();
}

class _MuteDurationSheetState extends ConsumerState<MuteDurationSheet> {
  MuteDuration? _selectedDuration;
  bool _isLoading = false;

  Future<void> _muteWithDuration(MuteDuration duration) async {
    setState(() {
      _selectedDuration = duration;
      _isLoading = true;
    });

    final success = await ref
        .read(conversationActionsNotifierProvider.notifier)
        .muteConversation(
          widget.conversationId,
          true,
          duration: duration.toDuration(),
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.conversationMuted),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.error),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.muteNotifications,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.muteNotificationsDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Duration options
            ...MuteDuration.values.map((duration) {
              final isSelected = _selectedDuration == duration;
              final isLoadingThis = _isLoading && isSelected;

              return ListTile(
                leading: Icon(
                  duration.icon,
                  color: isSelected
                      ? context.adaptivePrimaryColor
                      : context.textSecondaryColor,
                ),
                title: Text(
                  duration.getLabel(l10n),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isLoadingThis
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.adaptivePrimaryColor,
                        ),
                      )
                    : isSelected
                        ? AppIcon(AppIcon.check,
                            color: context.adaptivePrimaryColor,
                          )
                        : null,
                onTap: _isLoading ? null : () => _muteWithDuration(duration),
              );
            }),
            const SizedBox(height: 8),
            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
