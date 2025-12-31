import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../firebase_options.dart';

class BackgroundLocationService {
  static const String notificationChannelId = 'background_location_channel';
  static const String notificationChannelName = 'Diaspo Niger Location Service';
  static const String notificationChannelDescription =
      'Service de localisation en arrière-plan';
  static const int notificationId = 888;
  static const String prefKeyEnabled = 'background_location_enabled';
  static const String prefKeyLocationInterval = 'location_update_interval_minutes';
  static const int defaultLocationIntervalMinutes = 5;

  /// Save the location update interval to SharedPreferences
  /// Called from main app when settings change
  static Future<void> setLocationInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefKeyLocationInterval, minutes);
  }

  /// Get the location update interval from SharedPreferences
  static Future<int> getLocationInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefKeyLocationInterval) ?? defaultLocationIntervalMinutes;
  }

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Ensure permissions are handled in the UI before starting the service.
    // This initializer configures the service.

    // Pre-create the notification channel to prevent Samsung device crashes
    // This ensures the channel exists before any service start attempts
    await _ensureNotificationChannelExists();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Service de localisation Diaspo Niger',
        initialNotificationContent: 'Initialisation...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: false,
        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  }

  /// Ensure the notification channel exists before starting the foreground service.
  /// This is critical for Samsung devices which require the channel to exist
  /// before startForeground() is called.
  static Future<void> _ensureNotificationChannelExists() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          notificationChannelId,
          notificationChannelName,
          description: notificationChannelDescription,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      debugPrint('Background location notification channel ensured before service start');
    }
  }

  // Key to toggle specific logic if needed
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, enabled);

    final service = FlutterBackgroundService();
    if (enabled) {
      // CRITICAL: Ensure notification channel exists BEFORE starting service
      // This prevents "Bad notification for startForeground" crash on Samsung devices
      await _ensureNotificationChannelExists();

      if (!await service.isRunning()) {
        await service.startService();
      }
      service.invoke("setAsForeground");
    } else {
      service.invoke("stopService");
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Firebase might be already initialized
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // CRITICAL: Create notification channel FIRST before any foreground service operations
    // This is especially important for Samsung devices which have stricter requirements
    if (service is AndroidServiceInstance) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        // Create the notification channel with all required properties
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            notificationChannelId,
            notificationChannelName,
            description: notificationChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
        debugPrint('Background location notification channel created');
      }
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Set foreground notification info after channel is created
    if (service is AndroidServiceInstance) {
      // Get initial interval for notification message
      final prefs = await SharedPreferences.getInstance();
      final initialInterval = prefs.getInt(prefKeyLocationInterval) ?? defaultLocationIntervalMinutes;

      await service.setForegroundNotificationInfo(
        title: "Diaspo Niger",
        content: "Localisation active (Mise à jour toutes les $initialInterval min)",
      );
    }

    // Start recursive location update timer
    _scheduleNextLocationUpdate(service, flutterLocalNotificationsPlugin);
  }

  /// Recursive timer that reads interval from SharedPreferences each time
  /// This allows the interval to be changed dynamically by admin settings
  static void _scheduleNextLocationUpdate(
    ServiceInstance service,
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ) async {
    // Read current interval from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes = prefs.getInt(prefKeyLocationInterval) ?? defaultLocationIntervalMinutes;

    // Schedule next update
    Timer(Duration(minutes: intervalMinutes), () async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Check if user still wants tracking
          final prefs = await SharedPreferences.getInstance();
          final isEnabled = prefs.getBool(prefKeyEnabled) ?? false;

          if (!isEnabled) {
            service.stopSelf();
            return;
          }

          try {
            // 1. Get position
            Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );

            // 2. Get current user ID
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                    'location': GeoPoint(position.latitude, position.longitude),
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                    'lastSeen': FieldValue.serverTimestamp(),
                    'locationUpdatedAt': FieldValue.serverTimestamp(),
                  });

              debugPrint(
                'Background Location Updated: ${position.latitude}, ${position.longitude}',
              );

              // Update notification with current interval
              final currentInterval = prefs.getInt(prefKeyLocationInterval) ?? defaultLocationIntervalMinutes;
              flutterLocalNotificationsPlugin.show(
                notificationId,
                'Diaspo Niger',
                'Position mise à jour: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} (toutes les $currentInterval min)',
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    notificationChannelId,
                    notificationChannelName,
                    channelDescription: notificationChannelDescription,
                    icon: '@mipmap/ic_launcher',
                    ongoing: true,
                    importance: Importance.low,
                    priority: Priority.low,
                    showWhen: true,
                    onlyAlertOnce: true,
                  ),
                ),
              );
            } else {
              debugPrint('Background Location: No user logged in.');
            }
          } catch (e) {
            debugPrint('Background Location Error: $e');
          }

          // Schedule next update recursively
          _scheduleNextLocationUpdate(service, flutterLocalNotificationsPlugin);
        }
      }
    });
  }
}
