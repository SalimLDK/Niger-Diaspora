import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service for managing all app preferences using SharedPreferences.
/// Provides type-safe access to all settings and preferences.
class PreferencesService {
  static PreferencesService? _instance;
  static PreferencesService get instance {
    _instance ??= PreferencesService._();
    return _instance!;
  }

  PreferencesService._();

  SharedPreferences? _prefs;

  /// Initialize the service. Must be called before accessing preferences.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'PreferencesService not initialized. Call initialize() first.',
      );
    }
    return _prefs!;
  }

  // ============================
  // PREFERENCE KEYS
  // ============================

  // Onboarding & First-Time Experience
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _keyHasSeenCoachMarks = 'has_seen_coach_marks';
  static const String _keyAppFirstLaunch = 'app_first_launch';
  static const String _keyAppVersion = 'app_version';

  // App Settings
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocale = 'app_locale';

  // Notification Preferences
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyNotifyMessages = 'notify_messages';
  static const String _keyNotifyEvents = 'notify_events';
  static const String _keyNotifyFriendRequests = 'notify_friend_requests';
  static const String _keyNotifyGroups = 'notify_groups';
  static const String _keyNotifyEventReminders = 'notify_event_reminders';
  static const String _keyNotificationSound = 'notification_sound';
  static const String _keyNotificationVibration = 'notification_vibration';
  static const String _keyQuietHoursEnabled = 'quiet_hours_enabled';
  static const String _keyQuietHoursStartHour = 'quiet_hours_start_hour';
  static const String _keyQuietHoursStartMinute = 'quiet_hours_start_minute';
  static const String _keyQuietHoursEndHour = 'quiet_hours_end_hour';
  static const String _keyQuietHoursEndMinute = 'quiet_hours_end_minute';

  // Media Preferences
  static const String _keyAutoDownloadImages = 'auto_download_images';
  static const String _keyAutoDownloadVideos = 'auto_download_videos';
  static const String _keyDataSaverMode = 'data_saver_mode';

  // Privacy & Security
  // Privacy & Security
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyAnalyticsOptOut = 'analytics_opt_out';
  static const String _keySessionId = 'session_id'; // Internal session tracking

  // ============================
  // SESSION
  // ============================

  String? get sessionId => prefs.getString(_keySessionId);
  Future<void> setSessionId(String id) => prefs.setString(_keySessionId, id);
  Future<void> clearSessionId() => prefs.remove(_keySessionId);

  // ============================
  // ONBOARDING & FIRST-TIME
  // ============================

  bool get hasSeenOnboarding => prefs.getBool(_keyHasSeenOnboarding) ?? false;
  Future<void> setOnboardingComplete() =>
      prefs.setBool(_keyHasSeenOnboarding, true);

  bool get hasSeenCoachMarks => prefs.getBool(_keyHasSeenCoachMarks) ?? false;
  Future<void> setCoachMarksComplete() =>
      prefs.setBool(_keyHasSeenCoachMarks, true);

  bool get isFirstLaunch => prefs.getBool(_keyAppFirstLaunch) ?? true;
  Future<void> setNotFirstLaunch() => prefs.setBool(_keyAppFirstLaunch, false);

  String? get appVersion => prefs.getString(_keyAppVersion);
  Future<void> setAppVersion(String version) =>
      prefs.setString(_keyAppVersion, version);

  // ============================
  // APP SETTINGS
  // ============================

  String? get themeMode => prefs.getString(_keyThemeMode);
  Future<void> setThemeMode(String mode) =>
      prefs.setString(_keyThemeMode, mode);

  String? get locale => prefs.getString(_keyLocale);
  Future<void> setLocale(String localeCode) =>
      prefs.setString(_keyLocale, localeCode);

  // ============================
  // NOTIFICATION PREFERENCES
  // ============================

  bool get notificationsEnabled =>
      prefs.getBool(_keyNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) =>
      prefs.setBool(_keyNotificationsEnabled, enabled);

  bool get notifyMessages => prefs.getBool(_keyNotifyMessages) ?? true;
  Future<void> setNotifyMessages(bool enabled) =>
      prefs.setBool(_keyNotifyMessages, enabled);

  bool get notifyEvents => prefs.getBool(_keyNotifyEvents) ?? true;
  Future<void> setNotifyEvents(bool enabled) =>
      prefs.setBool(_keyNotifyEvents, enabled);

  bool get notifyFriendRequests =>
      prefs.getBool(_keyNotifyFriendRequests) ?? true;
  Future<void> setNotifyFriendRequests(bool enabled) =>
      prefs.setBool(_keyNotifyFriendRequests, enabled);

  bool get notifyGroups => prefs.getBool(_keyNotifyGroups) ?? true;
  Future<void> setNotifyGroups(bool enabled) =>
      prefs.setBool(_keyNotifyGroups, enabled);

  bool get notifyEventReminders =>
      prefs.getBool(_keyNotifyEventReminders) ?? true;
  Future<void> setNotifyEventReminders(bool enabled) =>
      prefs.setBool(_keyNotifyEventReminders, enabled);

  bool get notificationSound => prefs.getBool(_keyNotificationSound) ?? true;
  Future<void> setNotificationSound(bool enabled) =>
      prefs.setBool(_keyNotificationSound, enabled);

  bool get notificationVibration =>
      prefs.getBool(_keyNotificationVibration) ?? true;
  Future<void> setNotificationVibration(bool enabled) =>
      prefs.setBool(_keyNotificationVibration, enabled);

  // Quiet Hours
  bool get quietHoursEnabled => prefs.getBool(_keyQuietHoursEnabled) ?? false;
  Future<void> setQuietHoursEnabled(bool enabled) =>
      prefs.setBool(_keyQuietHoursEnabled, enabled);

  int get quietHoursStartHour =>
      prefs.getInt(_keyQuietHoursStartHour) ?? 22; // Default 22:00
  Future<void> setQuietHoursStartHour(int hour) =>
      prefs.setInt(_keyQuietHoursStartHour, hour);

  int get quietHoursStartMinute => prefs.getInt(_keyQuietHoursStartMinute) ?? 0;
  Future<void> setQuietHoursStartMinute(int minute) =>
      prefs.setInt(_keyQuietHoursStartMinute, minute);

  int get quietHoursEndHour =>
      prefs.getInt(_keyQuietHoursEndHour) ?? 8; // Default 08:00
  Future<void> setQuietHoursEndHour(int hour) =>
      prefs.setInt(_keyQuietHoursEndHour, hour);

  int get quietHoursEndMinute => prefs.getInt(_keyQuietHoursEndMinute) ?? 0;
  Future<void> setQuietHoursEndMinute(int minute) =>
      prefs.setInt(_keyQuietHoursEndMinute, minute);

  // ============================
  // MEDIA PREFERENCES
  // ============================

  bool get autoDownloadImages => prefs.getBool(_keyAutoDownloadImages) ?? true;
  Future<void> setAutoDownloadImages(bool enabled) =>
      prefs.setBool(_keyAutoDownloadImages, enabled);

  bool get autoDownloadVideos => prefs.getBool(_keyAutoDownloadVideos) ?? false;
  Future<void> setAutoDownloadVideos(bool enabled) =>
      prefs.setBool(_keyAutoDownloadVideos, enabled);

  bool get dataSaverMode => prefs.getBool(_keyDataSaverMode) ?? false;
  Future<void> setDataSaverMode(bool enabled) =>
      prefs.setBool(_keyDataSaverMode, enabled);

  // ============================
  // PRIVACY & SECURITY
  // ============================

  bool get biometricEnabled => prefs.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool enabled) =>
      prefs.setBool(_keyBiometricEnabled, enabled);

  bool get analyticsOptOut => prefs.getBool(_keyAnalyticsOptOut) ?? false;
  Future<void> setAnalyticsOptOut(bool optOut) =>
      prefs.setBool(_keyAnalyticsOptOut, optOut);

  // ============================
  // UTILITY METHODS
  // ============================

  /// Clear all preferences (use with caution)
  Future<void> clearAll() => prefs.clear();

  /// Remove a specific preference
  Future<void> remove(String key) => prefs.remove(key);

  /// Check if a preference exists
  bool containsKey(String key) => prefs.containsKey(key);
}
