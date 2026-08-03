import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/audio_room_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// /audio-rooms/schedule — custom monthly calendar + multi-timezone display.
class ScheduleRoomScreen extends ConsumerStatefulWidget {
  /// Titre déjà saisi dans « Ouvrir un salon » avant le clic sur « Plus tard ».
  /// Sans lui, tous les salons programmés s'appelaient « Nouveau salon ».
  final String? initialTitle;

  const ScheduleRoomScreen({super.key, this.initialTitle});

  @override
  ConsumerState<ScheduleRoomScreen> createState() => _ScheduleRoomScreenState();
}

class _ScheduleRoomScreenState extends ConsumerState<ScheduleRoomScreen> {
  static const _zones = [
    ('Africa/Niamey', 'Niamey', DNColors.terra),
    ('Europe/Paris', 'Paris', DNColors.teal),
    ('America/New_York', 'New York', DNColors.ochre),
    ('America/Toronto', 'Montréal', DNColors.leaf),
  ];

  DateTime _selectedDay = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _tzInitialized = false;
  final Map<String, bool> _enabledZones = {
    'Africa/Niamey': true,
    'Europe/Paris': true,
    'America/New_York': false,
    'America/Toronto': false,
  };

  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle ?? '');

  /// Rappel local 15 min avant le début, programmé à la création.
  bool _remindMe = true;

  /// Qualifie une heure convertie (« 19:30 ») pour la zone concernée.
  String _slotQualifier(BuildContext context, String hhmm) {
    final l10n = AppLocalizations.of(context)!;
    final hour = int.tryParse(hhmm.split(':').first);
    if (hour == null) return '';
    if (hour >= 18 && hour < 23) return l10n.scheduleSlotEvening;
    if (hour >= 11 && hour < 15) return l10n.scheduleSlotMidday;
    if (hour >= 6 && hour < 11) return l10n.scheduleSlotMorning;
    return l10n.scheduleSlotNight;
  }

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    setState(() => _tzInitialized = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _selectedDateTime => DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String _convertTime(DateTime local, String tzName) {
    if (!_tzInitialized) return '--:--';
    try {
      final loc = tz.getLocation(tzName);
      final t = tz.TZDateTime.from(local.toUtc(), loc);
      return DateFormat('HH:mm').format(t);
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Scaffold(
      backgroundColor: dn.surface,
      appBar: AppBar(
        backgroundColor: dn.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.scheduleRoomTitle,
                style: DNText.serif(size: 18, color: dn.onSurface),),
            Text(AppLocalizations.of(context)!.scheduleRoomMultiTimezone,
                style: DNText.mono(size: 9, color: dn.onSurface3),),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              AppLocalizations.of(context)!.scheduleRoomIntro,
              style: DNText.sans(size: 12, color: dn.onSurface2),
            ),
          ),
          // Le titre était figé à « Nouveau salon » : tous les salons
          // programmés portaient le même nom. Il est saisissable ici, et
          // pré-rempli quand on vient de « Ouvrir un salon ».
          TextField(
            controller: _titleController,
            style: DNText.sans(size: 14, color: dn.onSurface),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.scheduleRoomTitleLabel,
              hintText: AppLocalizations.of(context)!.scheduleRoomTitleHint,
              hintStyle: DNText.sans(size: 13, color: dn.onSurface4),
              filled: true,
              fillColor: dn.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _MonthCalendar(
            selectedDay: _selectedDay,
            onDaySelected: (d) => setState(() => _selectedDay = d),
          ),
          const SizedBox(height: 16),

          _HourPicker(
            time: _selectedTime,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
                builder: (ctx, child) => Theme(
                  data: ThemeData(
                    colorScheme: dn.isDark
                        ? ColorScheme.dark(
                            primary: DNColors.terra,
                            surface: dn.surface,
                          )
                        : ColorScheme.light(
                            primary: DNColors.terra,
                            surface: dn.surface,
                          ),
                  ),
                  child: child!,
                ),
              );
              if (t != null) setState(() => _selectedTime = t);
            },
          ),
          const SizedBox(height: 16),

          // « HEURE LOCALE DES MEMBRES » dit à quoi sert la liste ;
          // « FUSEAUX HORAIRES » nommait seulement la donnée.
          Text(AppLocalizations.of(context)!.scheduleMembersLocalTime,
              style: DNText.mono(size: 9, color: dn.onSurface3),),
          const SizedBox(height: 8),
          ..._zones.map((z) => _TimezoneRow(
                tzName: z.$1,
                label: z.$2,
                color: z.$3,
                convertedTime: _convertTime(_selectedDateTime, z.$1),
                // Qualificatif du créneau : une heure convertie seule ne dit
                // pas si elle tombe bien pour les gens de cette zone.
                qualifier: _slotQualifier(
                  context,
                  _convertTime(_selectedDateTime, z.$1),
                ),
                enabled: _enabledZones[z.$1] ?? false,
                onToggle: (v) => setState(() => _enabledZones[z.$1] = v),
              ),),

          const SizedBox(height: 12),
          // Rappel local (la maquette parle de « prévenir mes abonnés », ce
          // qui demanderait un push serveur qui n'existe pas — on s'en tient
          // à ce qu'on sait vraiment faire : rappeler l'hôte).
          _RemindToggle(
            value: _remindMe,
            onChanged: (v) => setState(() => _remindMe = v),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dn.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '✏ ${AppLocalizations.of(context)!.scheduleRoomCaveat}',
              style: DNText.mono(size: 9, color: dn.onSurface2),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ScheduleFooter(
        scheduledAt: _selectedDateTime,
        onSchedule: () async {
          final session = ref.read(audioRoomSessionProvider.notifier);
          final l10n = AppLocalizations.of(context)!;
          final typed = _titleController.text.trim();
          final title =
              typed.isEmpty ? l10n.scheduleNewRoomLabel : typed;
          final room = await session.createRoom(
            // Le titre saisi prime ; le libellé générique n'est plus qu'un
            // dernier recours si le champ est resté vide.
            title: title,
            scheduledAt: _selectedDateTime,
          );

          // Le rappel est programmé 15 min avant, et seulement si ce moment
          // est encore dans le futur.
          final remindAt =
              _selectedDateTime.subtract(const Duration(minutes: 15));
          if (_remindMe && room != null && remindAt.isAfter(DateTime.now())) {
            await NotificationService().scheduleNotification(
              id: room.id.hashCode & 0x7fffffff,
              title: title,
              body: l10n.audioRoomsStartingSoon,
              scheduledDate: remindAt,
            );
          }

          if (context.mounted) context.pop();
        },
      ),
    );
  }
}

// ─── Calendar ─────────────────────────────────────────────────────────────────

class _MonthCalendar extends StatefulWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCalendar({
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.selectedDay.year, widget.selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final today = DateTime.now();
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;
    final cells = startOffset + daysInMonth;
    final monthYear = DateFormat(
            'MMMM yyyy', LocaleHelper.getDateFormatLocale(context),)
        .format(_viewMonth);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: dn.onSurface),
              onPressed: () => setState(() => _viewMonth =
                  DateTime(_viewMonth.year, _viewMonth.month - 1),),
            ),
            Text(monthYear, style: DNText.serif(size: 16, color: dn.onSurface)),
            IconButton(
              icon: AppIcon(AppIcon.chevronRight, color: dn.onSurface),
              onPressed: () => setState(() => _viewMonth =
                  DateTime(_viewMonth.year, _viewMonth.month + 1),),
            ),
          ],
        ),
        Row(
          children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: DNText.mono(size: 9, color: dn.onSurface3)),
                    ),
                  ),)
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: ((cells / 7).ceil() * 7),
          itemBuilder: (_, i) {
            final dayNum = i - startOffset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
            final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
            final isSelected = date.day == widget.selectedDay.day &&
                date.month == widget.selectedDay.month &&
                date.year == widget.selectedDay.year;
            final isToday = date.day == today.day &&
                date.month == today.month &&
                date.year == today.year;

            return GestureDetector(
              onTap: () => widget.onDaySelected(date),
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected ? DNColors.terra : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: dn.onSurface, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: DNText.sans(
                      size: 13,
                      color: isSelected ? DNColors.paper : dn.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Hour picker ──────────────────────────────────────────────────────────────

class _HourPicker extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _HourPicker({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: DNColors.terra, width: 2),
          borderRadius: BorderRadius.circular(10),
          color: dn.surface,
        ),
        child: Row(
          children: [
            Text(
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}',
              style: DNText.serif(size: 32, color: dn.onSurface),
            ),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.niamieyTimezoneLabel,
                style: DNText.mono(size: 9, color: dn.onSurface3),),
          ],
        ),
      ),
    );
  }
}

// ─── Timezone row ─────────────────────────────────────────────────────────────

class _TimezoneRow extends StatelessWidget {
  final String tzName;
  final String label;
  final Color color;
  final String convertedTime;

  /// « Bonne heure · soirée », « Tard · risque de nuit »…
  final String qualifier;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _TimezoneRow({
    required this.tzName,
    required this.label,
    required this.color,
    required this.convertedTime,
    required this.qualifier,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: DNText.sans(size: 13, color: dn.onSurface),),
                if (qualifier.isNotEmpty)
                  Text(qualifier,
                      style: DNText.mono(size: 8, color: dn.onSurface3),),
              ],
            ),
          ),
          Text(convertedTime, style: DNText.mono(size: 12, color: dn.onSurface2)),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: DNColors.terra,
          ),
        ],
      ),
    );
  }
}

/// Rappel local avant le début du salon.
class _RemindToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RemindToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.scheduleRemindMe,
                  style: DNText.sans(size: 13, color: dn.onSurface),),
              Text(l10n.scheduleRemindMeHint,
                  style: DNText.mono(size: 9, color: dn.onSurface3),),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: DNColors.terra,
        ),
      ],
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _ScheduleFooter extends StatelessWidget {
  final VoidCallback onSchedule;

  /// Rappelé dans le bouton : c'est la dernière occasion de voir la date
  /// choisie avant de valider.
  final DateTime scheduledAt;

  const _ScheduleFooter({required this.onSchedule, required this.scheduledAt});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Container(
      color: dn.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: ElevatedButton(
        onPressed: onSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: DNColors.terra,
          foregroundColor: DNColors.paper,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(
          AppLocalizations.of(context)!.scheduleRoomOnDate(
            context.dateFormat('d MMMM').format(scheduledAt),
            DateFormat('HH:mm').format(scheduledAt),
          ),
          style: DNText.sans(size: 15, w: FontWeight.w600, color: DNColors.paper),
        ),
      ),
    );
  }
}
