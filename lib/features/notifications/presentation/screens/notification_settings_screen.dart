import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../settings/presentation/providers/notification_preferences_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(notificationPreferencesNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.notificationSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Interrupteur maître (§8) — coupe toutes les notifications.
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                title: l10n.enableNotifications,
                subtitle:
                    preferences.masterEnabled
                        ? l10n.notificationsMasterOnDesc
                        : l10n.notificationsMasterOffDesc,
                value: preferences.masterEnabled,
                onChanged: (value) {
                  ref
                      .read(notificationPreferencesNotifierProvider.notifier)
                      .setMasterEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Les catégories sont désactivées quand le maître est coupé.
          IgnorePointer(
            ignoring: !preferences.masterEnabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: preferences.masterEnabled ? 1.0 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Content
                  _buildSectionHeader(
                    context,
                    l10n.notificationContent,
                    Icons.notifications_outlined,
                  ),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: l10n.notifyMessages,
                        subtitle: l10n.receiveNotificationsDesc,
                        value: preferences.messagesEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setMessagesEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyFriendRequests,
                        subtitle: l10n.receivedRequestsHint,
                        value: preferences.friendRequestsEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setFriendRequestsEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyGroups,
                        subtitle: l10n.groupActivity,
                        value: preferences.groupsEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setGroupsEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyEvents,
                        subtitle: l10n.newEvents,
                        value: preferences.eventsEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setEventsEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyEventReminders,
                        subtitle: l10n.eventReminders,
                        value: preferences.eventRemindersEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setEventRemindersEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: 'Evenements locaux',
                        subtitle:
                            'Recevoir des notifications pour les nouveaux evenements dans ma ville',
                        value: preferences.localEventsEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setLocalEventsEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: 'Messages système',
                        subtitle:
                            'Recevoir des notifications pour les évènements système (ex: nouveau membre)',
                        value: preferences.systemMessagesEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setSystemMessagesEnabled(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section: Alerts
                  _buildSectionHeader(
                    context,
                    l10n.notificationAlerts,
                    Icons.volume_up_outlined,
                  ),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: l10n.notificationSound,
                        subtitle: l10n.receiveNotifications,
                        value: preferences.soundEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setSoundEnabled(value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notificationVibration,
                        subtitle: l10n.receiveNotifications,
                        value: preferences.vibrationEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setVibrationEnabled(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section: Advanced
                  _buildSectionHeader(
                    context,
                    l10n.notificationAdvanced,
                    Icons.tune_outlined,
                  ),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: l10n.quietHours,
                        subtitle: l10n.quietHoursDesc,
                        value: preferences.quietHoursEnabled,
                        onChanged: (value) {
                          ref
                              .read(
                                notificationPreferencesNotifierProvider
                                    .notifier,
                              )
                              .setQuietHoursEnabled(value);
                        },
                      ),
                      if (preferences.quietHoursEnabled) ...[
                        const _SettingsDivider(),
                        _QuietHoursTimePicker(
                          label: l10n.quietHoursStart,
                          hour: preferences.quietHoursStartHour,
                          minute: preferences.quietHoursStartMinute,
                          onTimeChanged: (hour, minute) {
                            ref
                                .read(
                                  notificationPreferencesNotifierProvider
                                      .notifier,
                                )
                                .setQuietHoursStartTime(hour, minute);
                          },
                        ),
                        const _SettingsDivider(),
                        _QuietHoursTimePicker(
                          label: l10n.quietHoursEnd,
                          hour: preferences.quietHoursEndHour,
                          minute: preferences.quietHoursEndMinute,
                          onTimeChanged: (hour, minute) {
                            ref
                                .read(
                                  notificationPreferencesNotifierProvider
                                      .notifier,
                                )
                                .setQuietHoursEndTime(hour, minute);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.notificationPreferences,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: context.adaptivePrimaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.textTertiaryColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Quiet Hours Time Picker Widget
class _QuietHoursTimePicker extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onTimeChanged;

  const _QuietHoursTimePicker({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectTime(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.adaptivePrimaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _formatTime(hour, minute),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: context.surfaceColor,
              hourMinuteTextColor: context.textPrimaryColor,
              dayPeriodTextColor: context.textPrimaryColor,
              dialHandColor: context.adaptivePrimaryColor,
              dialBackgroundColor: context.adaptivePrimaryColor.withValues(
                alpha: 0.1,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onTimeChanged(picked.hour, picked.minute);
    }
  }
}

// Settings Card Widget
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Column(children: children),
    );
  }
}

// Settings Switch Tile Widget
class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }
}

// Divider Widget
class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: context.borderColor.withValues(alpha: 0.5),
    );
  }
}
