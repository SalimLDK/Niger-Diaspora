import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../settings/presentation/providers/notification_preferences_provider.dart';

/// Réglages de notifications (fiche 20d).
///
/// Un interrupteur maître isolé, une seule liste « Ce qui vous alerte », les
/// sons, puis les heures calmes résumées sur une ligne. « Messages système »
/// est verrouillé : la fiche en fait une catégorie non désactivable.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(notificationPreferencesNotifierProvider);

    // « Messages système » devient verrouillé actif : si la préférence
    // enregistrée dit le contraire, on la remet d'aplomb une fois, sinon
    // l'interrupteur afficherait un état que plus rien ne peut changer.
    if (!preferences.systemMessagesEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(notificationPreferencesNotifierProvider.notifier)
            .setSystemMessagesEnabled(true);
      });
    }

    final notifier = ref.read(
      notificationPreferencesNotifierProvider.notifier,
    );

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const DesignTitle('Notifications', size: 22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // Interrupteur maître — carte isolée, sous-titre invariable : il
          // décrit ce que fait le geste, pas l'état courant.
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                title: 'Notifications push',
                subtitle: "Coupe tout d'un seul geste",
                value: preferences.masterEnabled,
                onChanged: notifier.setMasterEnabled,
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
                  _SectionLabel('Ce qui vous alerte'),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: l10n.notifyMessages,
                        subtitle: 'Conversations et groupes',
                        value: preferences.messagesEnabled,
                        onChanged: notifier.setMessagesEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyFriendRequests,
                        // `receivedRequestsHint` décrit un écran (« …
                        // apparaîtront ici »), pas ce qui vous alerte.
                        subtitle: 'Quand quelqu\'un veut se connecter',
                        value: preferences.friendRequestsEnabled,
                        onChanged: notifier.setFriendRequestsEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyGroups,
                        subtitle: l10n.groupActivity,
                        value: preferences.groupsEnabled,
                        onChanged: notifier.setGroupsEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyEvents,
                        subtitle: 'Invitations et changements d\'horaire',
                        value: preferences.eventsEnabled,
                        onChanged: notifier.setEventsEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notifyEventReminders,
                        // `eventReminders` répétait le titre mot pour mot.
                        subtitle: 'La veille et une heure avant',
                        value: preferences.eventRemindersEnabled,
                        onChanged: notifier.setEventRemindersEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: 'Événements locaux',
                        subtitle: 'Nouveaux événements dans votre ville',
                        value: preferences.localEventsEnabled,
                        onChanged: notifier.setLocalEventsEnabled,
                      ),
                      const _SettingsDivider(),
                      const _SettingsSwitchTile(
                        title: 'Messages système',
                        subtitle: 'Sécurité, mises à jour importantes',
                        value: true,
                        onChanged: null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Sons et vibrations'),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: l10n.notificationSound,
                        // Les deux portaient « Recevoir des notifications » :
                        // le même sous-titre pour deux réglages différents.
                        subtitle: 'Sonnerie à chaque alerte',
                        value: preferences.soundEnabled,
                        onChanged: notifier.setSoundEnabled,
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchTile(
                        title: l10n.notificationVibration,
                        subtitle: 'Vibrer même en silencieux',
                        value: preferences.vibrationEnabled,
                        onChanged: notifier.setVibrationEnabled,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Heures calmes'),
                  _SettingsCard(
                    children: [
                      _SettingsSwitchTile(
                        title: 'Silence la nuit',
                        subtitle: 'Utile avec le décalage Niamey – Paris',
                        value: preferences.quietHoursEnabled,
                        onChanged: notifier.setQuietHoursEnabled,
                      ),
                      if (preferences.quietHoursEnabled) ...[
                        const _SettingsDivider(),
                        // Une seule ligne « De 22:00 à 07:00 » au lieu de deux
                        // sélecteurs : la plage se lit d'un coup d'œil, et le
                        // tap enchaîne les deux heures.
                        _QuietHoursRange(
                          startHour: preferences.quietHoursStartHour,
                          startMinute: preferences.quietHoursStartMinute,
                          endHour: preferences.quietHoursEndHour,
                          endMinute: preferences.quietHoursEndMinute,
                          onChanged: (sh, sm, eh, em) async {
                            await notifier.setQuietHoursStartTime(sh, sm);
                            await notifier.setQuietHoursEndTime(eh, em);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: context.textSecondaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Les messages système restent toujours actifs.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Étiquette de section en chasse fixe (§20d) : elle se lit et s'oublie, là
/// où la pastille teintée attirait l'œil autant que les réglages eux-mêmes.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.robotoMono(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: context.adaptivePrimaryColor,
        ),
      ),
    );
  }
}

/// Ligne « De 22:00 à 07:00 » : ouvre le sélecteur du début puis celui de la
/// fin, et n'enregistre que si les deux ont été confirmés.
class _QuietHoursRange extends StatelessWidget {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final Future<void> Function(int, int, int, int) onChanged;

  const _QuietHoursRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.onChanged,
  });

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'De ${_fmt(startHour, startMinute)} à ${_fmt(endHour, endMinute)}',
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 19,
              color: context.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final start = await _showPicker(
      context,
      TimeOfDay(hour: startHour, minute: startMinute),
      'Début du silence',
    );
    if (start == null || !context.mounted) return;
    final end = await _showPicker(
      context,
      TimeOfDay(hour: endHour, minute: endMinute),
      'Fin du silence',
    );
    if (end == null) return;
    await onChanged(start.hour, start.minute, end.hour, end.minute);
  }

  Future<TimeOfDay?> _showPicker(
    BuildContext context,
    TimeOfDay initial,
    String helpText,
  ) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
      builder:
          (context, child) => Theme(
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
          ),
    );
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.6)),
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

/// Ligne à interrupteur. [onChanged] à `null` = catégorie verrouillée : elle
/// s'affiche active mais grisée, pour signaler qu'elle n'est pas au choix de
/// l'utilisateur plutôt que de faire croire à un simple « activé ».
class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Opacity(
            opacity: locked ? 0.6 : 1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.adaptivePrimaryColor,
            ),
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
      indent: 14,
      endIndent: 14,
      color: context.borderColor.withValues(alpha: 0.5),
    );
  }
}
