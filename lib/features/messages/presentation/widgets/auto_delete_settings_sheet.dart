import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/conversation_actions_provider.dart';

/// Bottom sheet for configuring auto-delete (ephemeral) messages
class AutoDeleteSettingsSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final int? currentDurationSeconds;

  const AutoDeleteSettingsSheet({
    super.key,
    required this.conversationId,
    this.currentDurationSeconds,
  });

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    int? currentDurationSeconds,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AutoDeleteSettingsSheet(
        conversationId: conversationId,
        currentDurationSeconds: currentDurationSeconds,
      ),
    );
  }

  @override
  ConsumerState<AutoDeleteSettingsSheet> createState() =>
      _AutoDeleteSettingsSheetState();
}

class _AutoDeleteSettingsSheetState
    extends ConsumerState<AutoDeleteSettingsSheet> {
  late int? _selectedDuration;
  bool _isLoading = false;

  // Duration options in seconds
  static const List<int?> _durationOptions = [
    null, // Off
    86400, // 24 hours
    604800, // 7 days
    2592000, // 30 days
  ];

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.currentDurationSeconds;
  }

  String _getDurationLabel(BuildContext context, int? seconds) {
    final l10n = AppLocalizations.of(context)!;
    if (seconds == null) return l10n.off;
    if (seconds == 86400) return l10n.hours24;
    if (seconds == 604800) return l10n.days7;
    if (seconds == 2592000) return l10n.days30;
    return '$seconds s';
  }

  Future<void> _saveSettings() async {
    if (_selectedDuration == widget.currentDurationSeconds) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref
        .read(conversationActionsNotifierProvider.notifier)
        .setAutoDeleteSettings(widget.conversationId, _selectedDuration);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedDuration != null
                ? l10n.disappearingMessagesEnabled(
                    _getDurationLabel(context, _selectedDuration),
                  )
                : l10n.disappearingMessagesDisabled,
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SheetHandle(),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 48,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.disappearingMessages,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.disappearingMessagesDescription,
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
            // Options
            ..._durationOptions.map((duration) {
              final isSelected = _selectedDuration == duration;
              return RadioMenuButton<int?>(
                value: duration,
                groupValue: _selectedDuration,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() => _selectedDuration = value);
                      },
                child: Text(
                  _getDurationLabel(context, duration),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
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
