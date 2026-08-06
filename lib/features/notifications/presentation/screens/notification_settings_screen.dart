import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../providers/notification_provider.dart';
import '../../../settings/presentation/providers/notification_preferences_provider.dart';

/// Réglages de notifications (fiche 20d).
///
/// Un interrupteur maître isolé, une seule liste « Ce qui vous alerte », les
/// sons, puis les heures calmes résumées sur une ligne.
///
/// La fiche verrouille « Messages système » ; on ne l'a pas suivie sur ce
/// point (choix de Salim) : la catégorie reste désactivable comme les autres.
///
/// Cet écran était la dernière exception de
/// `test/core/theme/reglages_sans_doublon_test.dart` : il redéclarait ses
/// propres `_SettingsCard` / `_SettingsSwitchTile` / `_SettingsDivider`. Il
/// passe au kit — ce qui lui donne les pictogrammes 42 en dégradé et le rayon
/// commun, et lui retire son ombre et son rayon 18 propres.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(notificationPreferencesNotifierProvider);

    final notifier = ref.read(
      notificationPreferencesNotifierProvider.notifier,
    );

    /// Les catégories suivent l'interrupteur maître. On passe `null` plutôt
    /// que d'envelopper la liste dans un `IgnorePointer` : c'est au kit de
    /// rendre la bascule inerte et de l'estomper, pas à l'écran de l'imiter.
    ValueChanged<bool>? gated(ValueChanged<bool> onChanged) {
      if (!preferences.masterEnabled) return null;
      return (value) {
        HapticFeedback.lightImpact();
        onChanged(value);
      };
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.notifications, size: 22),
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
          DesignSettingsCard(
            children: [
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.notifications_active_outlined),
                title: l10n.pushNotifications,
                subtitle: "Coupe tout d'un seul geste",
                value: preferences.masterEnabled,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  notifier.setMasterEnabled(value);
                },
              ),
            ],
          ),

          DesignSectionLabel('Ce qui vous alerte'),
          DesignSettingsCard(
            children: [
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.chat_bubble_outline),
                title: l10n.notifyMessages,
                subtitle: 'Conversations et groupes',
                value: preferences.messagesEnabled,
                onChanged: gated(notifier.setMessagesEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.person_add_alt),
                title: l10n.notifyFriendRequests,
                // `receivedRequestsHint` décrit un écran (« … apparaîtront
                // ici »), pas ce qui vous alerte.
                subtitle: 'Quand quelqu\'un veut se connecter',
                value: preferences.friendRequestsEnabled,
                onChanged: gated(notifier.setFriendRequestsEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.groups_outlined),
                title: l10n.notifyGroups,
                subtitle: l10n.groupActivity,
                value: preferences.groupsEnabled,
                onChanged: gated(notifier.setGroupsEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.event_outlined),
                title: l10n.notifyEvents,
                subtitle: 'Invitations et changements d\'horaire',
                value: preferences.eventsEnabled,
                onChanged: gated(notifier.setEventsEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.alarm),
                title: l10n.notifyEventReminders,
                // `eventReminders` répétait le titre mot pour mot.
                subtitle: 'La veille et une heure avant',
                value: preferences.eventRemindersEnabled,
                onChanged: gated(notifier.setEventRemindersEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.location_on_outlined),
                title: l10n.localEvents,
                subtitle: l10n.profileNewEventsInCity,
                value: preferences.localEventsEnabled,
                onChanged: gated(notifier.setLocalEventsEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.shield_outlined),
                title: l10n.systemMessages,
                subtitle: 'Sécurité, mises à jour importantes',
                value: preferences.systemMessagesEnabled,
                onChanged: gated(notifier.setSystemMessagesEnabled),
              ),
            ],
          ),

          DesignSectionLabel('Sons et vibrations'),
          DesignSettingsCard(
            children: [
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.volume_up_outlined),
                title: l10n.notificationSound,
                // Les deux portaient « Recevoir des notifications » : le même
                // sous-titre pour deux réglages différents.
                subtitle: 'Sonnerie à chaque alerte',
                value: preferences.soundEnabled,
                onChanged: gated(notifier.setSoundEnabled),
              ),
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.vibration),
                title: l10n.notificationVibration,
                subtitle: 'Vibrer même en silencieux',
                value: preferences.vibrationEnabled,
                onChanged: gated(notifier.setVibrationEnabled),
              ),
            ],
          ),

          DesignSectionLabel('Heures calmes'),
          DesignSettingsCard(
            children: [
              DesignSettingsSwitchTile(
                icon: const Icon(Icons.bedtime_outlined),
                title: 'Silence la nuit',
                subtitle: l10n.notifTimezoneHint,
                value: preferences.quietHoursEnabled,
                onChanged: gated(notifier.setQuietHoursEnabled),
              ),
              // Une seule ligne « De 22:00 à 07:00 » au lieu de deux
              // sélecteurs : la plage se lit d'un coup d'œil, et le tap
              // enchaîne les deux heures.
              if (preferences.masterEnabled && preferences.quietHoursEnabled)
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
          ),

          // « Tout supprimer » vient de l'en-tête de la liste (§12c), qui n'a
          // plus qu'un bouton ⚙. C'est sa place : une action destructive sur
          // l'historique, rangée avec les réglages, pas à portée du pouce sur
          // la liste elle-même.
          DesignSectionLabel(l10n.history, color: context.errorColor),
          DesignSettingsCard(
            isDanger: true,
            children: [
              DesignSettingsTile(
                icon: const Icon(Icons.delete_sweep_outlined),
                iconColor: context.errorColor,
                titleColor: context.errorColor,
                title: l10n.deleteAll,
                subtitle: 'Efface toutes vos notifications',
                onTap: () => _confirmDeleteAll(context, ref),
              ),
            ],
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
                  // La note de la fiche (« Les messages système restent
                  // toujours actifs ») décrivait le verrou, abandonné : elle
                  // serait fausse. Celle-ci dit ce qui reste vrai.
                  'Couper les notifications push suspend toutes les '
                      'catégories, messages système compris.',
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

/// Confirmation avant d'effacer tout l'historique de notifications.
Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirme = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteAllNotifications),
      content: Text(l10n.deleteAllNotificationsConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            l10n.delete,
            style: TextStyle(color: context.errorColor),
          ),
        ),
      ],
    ),
  );

  if (confirme != true) return;
  await ref
      .read(notificationsNotifierProvider.notifier)
      .deleteAllNotifications();
}

/// Ligne « De 22:00 à 07:00 » : ouvre le sélecteur du début puis celui de la
/// fin, et n'enregistre que si les deux ont été confirmés.
///
/// C'est une [DesignSettingsTile] et non une rangée à la main : sans le
/// pictogramme de 42, le texte ne tomberait pas sur le filet que la carte pose
/// à 72.
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
    return DesignSettingsTile(
      icon: const Icon(Icons.schedule),
      title: 'De ${_fmt(startHour, startMinute)} à ${_fmt(endHour, endMinute)}',
      subtitle: 'Plage de silence',
      onTap: () => _pick(context),
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
