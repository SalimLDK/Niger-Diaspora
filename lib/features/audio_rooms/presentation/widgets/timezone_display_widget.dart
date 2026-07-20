import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../../core/constants/app_colors.dart';
import '../../../admin/presentation/providers/app_settings_provider.dart';

/// Widget to display a time in multiple timezones for diaspora users
class TimezoneDisplayWidget extends ConsumerStatefulWidget {
  /// The UTC time to display
  final DateTime utcTime;

  /// Custom list of timezones to display (overrides settings)
  final List<String>? timezones;

  /// Whether to show in compact mode (single line)
  final bool compact;

  /// Whether to show the date as well
  final bool showDate;

  /// Label to show above the times (e.g., "Heure de début")
  final String? label;

  const TimezoneDisplayWidget({
    super.key,
    required this.utcTime,
    this.timezones,
    this.compact = false,
    this.showDate = true,
    this.label,
  });

  @override
  ConsumerState<TimezoneDisplayWidget> createState() => _TimezoneDisplayWidgetState();
}

class _TimezoneDisplayWidgetState extends ConsumerState<TimezoneDisplayWidget> {
  static bool _tzInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
    final defaultTimezones = settings?.audioRooms.defaultDisplayTimezones ??
        ['Africa/Niamey', 'Europe/Paris', 'America/New_York'];
    final timezonesToShow = widget.timezones ?? defaultTimezones;

    if (widget.compact) {
      return _buildCompactView(timezonesToShow);
    }

    return _buildExpandedView(timezonesToShow);
  }

  Widget _buildCompactView(List<String> timezones) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: timezones.map((tz) {
          final info = _getTimezoneInfo(tz);
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.flag,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  info.formattedTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedView(List<String> timezones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: timezones.asMap().entries.map((entry) {
              final index = entry.key;
              final timezone = entry.value;
              final info = _getTimezoneInfo(timezone);
              final isLast = index == timezones.length - 1;

              return Column(
                children: [
                  _buildTimezoneRow(info),
                  if (!isLast)
                    Divider(
                      height: 16,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimezoneRow(_TimezoneInfo info) {
    return Row(
      children: [
        // Flag and city
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              info.flag,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.cityName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                info.abbreviation,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        // Time
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              info.formattedTime,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.secondary,
              ),
            ),
            if (widget.showDate)
              Text(
                info.formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ],
    );
  }

  _TimezoneInfo _getTimezoneInfo(String timezoneId) {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final location = tz.getLocation(timezoneId);
      final localTime = tz.TZDateTime.from(widget.utcTime.toUtc(), location);

      return _TimezoneInfo(
        timezoneId: timezoneId,
        cityName: _getCityName(timezoneId),
        flag: _getFlag(timezoneId),
        abbreviation: _getAbbreviation(timezoneId, localTime),
        formattedTime: DateFormat('HH:mm').format(localTime),
        formattedDate: DateFormat('EEE d MMM', locale).format(localTime),
        offset: localTime.timeZoneOffset,
      );
    } catch (e) {
      // Fallback for unknown timezone
      return _TimezoneInfo(
        timezoneId: timezoneId,
        cityName: timezoneId.split('/').last.replaceAll('_', ' '),
        flag: '🌍',
        abbreviation: 'UTC',
        formattedTime: DateFormat('HH:mm').format(widget.utcTime),
        formattedDate: DateFormat('EEE d MMM', locale).format(widget.utcTime),
        offset: Duration.zero,
      );
    }
  }

  String _getCityName(String timezoneId) {
    final city = timezoneId.split('/').last.replaceAll('_', ' ');

    // French translations for common cities
    return switch (city) {
      'Niamey' => 'Niamey',
      'Paris' => 'Paris',
      'New York' => 'New York',
      'Toronto' => 'Toronto',
      'London' => 'Londres',
      'Lagos' => 'Lagos',
      'Dakar' => 'Dakar',
      'Abidjan' => 'Abidjan',
      'Casablanca' => 'Casablanca',
      'Cairo' => 'Le Caire',
      'Johannesburg' => 'Johannesburg',
      'Dubai' => 'Dubaï',
      'Montreal' => 'Montréal',
      'Los Angeles' => 'Los Angeles',
      'Chicago' => 'Chicago',
      'Brussels' => 'Bruxelles',
      'Geneva' => 'Genève',
      'Zurich' => 'Zurich',
      _ => city,
    };
  }

  String _getFlag(String timezoneId) {
    // Extract country/region from timezone
    final parts = timezoneId.split('/');
    final region = parts.first;
    final city = parts.length > 1 ? parts.last : '';

    // Map timezones to flags
    if (timezoneId.contains('Niamey')) {
      return '🇳🇪';
    }
    if (timezoneId.contains('Paris') || region == 'Europe' && city == 'Paris') {
      return '🇫🇷';
    }
    if (timezoneId.contains('New_York') ||
        timezoneId.contains('Chicago') ||
        timezoneId.contains('Los_Angeles')) {
      return '🇺🇸';
    }
    if (timezoneId.contains('Toronto') || timezoneId.contains('Montreal')) {
      return '🇨🇦';
    }
    if (timezoneId.contains('London')) {
      return '🇬🇧';
    }
    if (timezoneId.contains('Lagos') || timezoneId.contains('Abuja')) {
      return '🇳🇬';
    }
    if (timezoneId.contains('Dakar')) {
      return '🇸🇳';
    }
    if (timezoneId.contains('Abidjan')) {
      return '🇨🇮';
    }
    if (timezoneId.contains('Casablanca')) {
      return '🇲🇦';
    }
    if (timezoneId.contains('Cairo')) {
      return '🇪🇬';
    }
    if (timezoneId.contains('Johannesburg')) {
      return '🇿🇦';
    }
    if (timezoneId.contains('Dubai')) {
      return '🇦🇪';
    }
    if (timezoneId.contains('Brussels')) {
      return '🇧🇪';
    }
    if (timezoneId.contains('Geneva') || timezoneId.contains('Zurich')) {
      return '🇨🇭';
    }
    if (timezoneId.contains('Berlin')) {
      return '🇩🇪';
    }
    if (timezoneId.contains('Rome')) {
      return '🇮🇹';
    }
    if (timezoneId.contains('Madrid')) {
      return '🇪🇸';
    }

    // Region-based fallbacks
    if (region == 'Africa') {
      return '🌍';
    }
    if (region == 'Europe') {
      return '🇪🇺';
    }
    if (region == 'America') {
      return '🌎';
    }
    if (region == 'Asia') {
      return '🌏';
    }

    return '🌐';
  }

  String _getAbbreviation(String timezoneId, DateTime localTime) {
    // Get UTC offset
    final offset = localTime.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();

    final sign = hours >= 0 ? '+' : '';
    if (minutes > 0) {
      return 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}';
    }
    return 'UTC$sign$hours';
  }
}

class _TimezoneInfo {
  final String timezoneId;
  final String cityName;
  final String flag;
  final String abbreviation;
  final String formattedTime;
  final String formattedDate;
  final Duration offset;

  _TimezoneInfo({
    required this.timezoneId,
    required this.cityName,
    required this.flag,
    required this.abbreviation,
    required this.formattedTime,
    required this.formattedDate,
    required this.offset,
  });
}

/// Chip-style compact timezone display for room cards
class TimezoneChipsWidget extends ConsumerWidget {
  final DateTime utcTime;
  final List<String>? timezones;
  final int maxChips;

  const TimezoneChipsWidget({
    super.key,
    required this.utcTime,
    this.timezones,
    this.maxChips = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
    final defaultTimezones = settings?.audioRooms.defaultDisplayTimezones ??
        ['Africa/Niamey', 'Europe/Paris', 'America/New_York'];
    final timezonesToShow = (timezones ?? defaultTimezones).take(maxChips).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: timezonesToShow.map((tzId) {
        final info = _getQuickTimezoneInfo(tzId, utcTime);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.flag, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                info.time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  ({String flag, String time}) _getQuickTimezoneInfo(String timezoneId, DateTime utcTime) {
    try {
      final location = tz.getLocation(timezoneId);
      final localTime = tz.TZDateTime.from(utcTime.toUtc(), location);

      String flag = '🌍';
      if (timezoneId.contains('Niamey')) {
        flag = '🇳🇪';
      } else if (timezoneId.contains('Paris')) {
        flag = '🇫🇷';
      } else if (timezoneId.contains('New_York')) {
        flag = '🇺🇸';
      } else if (timezoneId.contains('Toronto')) {
        flag = '🇨🇦';
      } else if (timezoneId.contains('London')) {
        flag = '🇬🇧';
      }

      return (flag: flag, time: DateFormat('HH:mm').format(localTime));
    } catch (e) {
      return (flag: '🌐', time: DateFormat('HH:mm').format(utcTime));
    }
  }
}

/// Header widget showing current time across diaspora locations
class DiasporaTimeHeader extends ConsumerWidget {
  const DiasporaTimeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
    final timezones = settings?.audioRooms.defaultDisplayTimezones ??
        ['Africa/Niamey', 'Europe/Paris', 'America/New_York'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: timezones.take(4).map((tzId) {
          return _buildTimeColumn(tzId);
        }).toList(),
      ),
    );
  }

  Widget _buildTimeColumn(String timezoneId) {
    try {
      final location = tz.getLocation(timezoneId);
      final now = tz.TZDateTime.now(location);

      String flag = '🌍';
      String cityShort = timezoneId.split('/').last.substring(0, 3).toUpperCase();

      if (timezoneId.contains('Niamey')) {
        flag = '🇳🇪';
        cityShort = 'NIA';
      } else if (timezoneId.contains('Paris')) {
        flag = '🇫🇷';
        cityShort = 'PAR';
      } else if (timezoneId.contains('New_York')) {
        flag = '🇺🇸';
        cityShort = 'NYC';
      } else if (timezoneId.contains('Toronto')) {
        flag = '🇨🇦';
        cityShort = 'TOR';
      } else if (timezoneId.contains('London')) {
        flag = '🇬🇧';
        cityShort = 'LON';
      } else if (timezoneId.contains('Montreal')) {
        flag = '🇨🇦';
        cityShort = 'MTL';
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            DateFormat('HH:mm').format(now),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            cityShort,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}
