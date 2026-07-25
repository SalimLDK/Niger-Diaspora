import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

/// Helper class for locale-aware operations
class LocaleHelper {
  /// Get the current locale code from context (e.g., 'fr', 'en')
  static String getLocaleCode(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }

  /// Get the full locale string for DateFormat (e.g., 'fr_FR', 'en_US')
  static String getDateFormatLocale(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    switch (languageCode) {
      case 'fr':
        return 'fr_FR';
      case 'en':
        return 'en_US';
      default:
        return 'fr_FR';
    }
  }

  /// Get AppLocalizations instance
  static AppLocalizations l10n(BuildContext context) {
    return AppLocalizations.of(context)!;
  }

  /// Create a DateFormat with the current locale
  static DateFormat dateFormat(BuildContext context, String pattern) {
    return DateFormat(pattern, getDateFormatLocale(context));
  }

  /// Common date formats with locale awareness
  static String formatDate(BuildContext context, DateTime date) {
    return dateFormat(context, 'dd/MM/yyyy').format(date);
  }

  static String formatDateTime(BuildContext context, DateTime date) {
    return dateFormat(context, 'dd/MM/yyyy HH:mm').format(date);
  }

  static String formatTime(BuildContext context, DateTime date) {
    return dateFormat(context, 'HH:mm').format(date);
  }

  static String formatFullDate(BuildContext context, DateTime date) {
    return dateFormat(context, 'EEEE dd MMMM yyyy').format(date);
  }

  static String formatShortDate(BuildContext context, DateTime date) {
    return dateFormat(context, 'dd MMM yyyy').format(date);
  }

  static String formatDayMonth(BuildContext context, DateTime date) {
    return dateFormat(context, 'EEE d MMM').format(date);
  }

  static String formatDayMonthTime(BuildContext context, DateTime date) {
    return dateFormat(context, 'EEE d MMM, HH:mm').format(date);
  }

  /// Format relative time with localization
  static String timeAgo(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return l10n.weeksAgo(weeks);
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return l10n.monthsAgo(months);
    } else {
      final years = (difference.inDays / 365).floor();
      return l10n.yearsAgo(years);
    }
  }

  /// Format message date with localization
  static String formatMessageDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return formatTime(context, date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return l10n.yesterday('');
    } else if (now.difference(date).inDays < 7) {
      return dateFormat(context, 'EEEE').format(date);
    } else {
      return formatDate(context, date);
    }
  }
}

/// Extension on BuildContext for easy access to locale helpers
extension LocaleContextExtension on BuildContext {
  /// Get the current locale code
  String get localeCode => LocaleHelper.getLocaleCode(this);

  /// Get the DateFormat locale string
  String get dateFormatLocale => LocaleHelper.getDateFormatLocale(this);

  /// Get AppLocalizations
  AppLocalizations get l10n => LocaleHelper.l10n(this);

  /// Create a DateFormat with current locale
  DateFormat dateFormat(String pattern) => LocaleHelper.dateFormat(this, pattern);
}
