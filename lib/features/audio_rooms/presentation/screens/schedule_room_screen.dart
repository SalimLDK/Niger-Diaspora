import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
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

          Text(AppLocalizations.of(context)!.timezonesLabel,
              style: DNText.mono(size: 9, color: dn.onSurface3),),
          const SizedBox(height: 8),
          ..._zones.map((z) => _TimezoneRow(
                tzName: z.$1,
                label: z.$2,
                color: z.$3,
                convertedTime: _convertTime(_selectedDateTime, z.$1),
                enabled: _enabledZones[z.$1] ?? false,
                onToggle: (v) => setState(() => _enabledZones[z.$1] = v),
              ),),

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
          final typed = _titleController.text.trim();
          await session.createRoom(
            // Le titre saisi prime ; le libellé générique n'est plus qu'un
            // dernier recours si le champ est resté vide.
            title: typed.isEmpty
                ? AppLocalizations.of(context)!.scheduleNewRoomLabel
                : typed,
            scheduledAt: _selectedDateTime,
          );
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
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _TimezoneRow({
    required this.tzName,
    required this.label,
    required this.color,
    required this.convertedTime,
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
          Expanded(child: Text(label, style: DNText.sans(size: 13, color: dn.onSurface))),
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
