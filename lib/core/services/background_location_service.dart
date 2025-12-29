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

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Ensure permissions are handled in the UI before starting the service.
    // This initializer configures the service.

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

  // Key to toggle specific logic if needed
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, enabled);

    final service = FlutterBackgroundService();
    if (enabled) {
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

    // Bring up the notification channel
    if (service is AndroidServiceInstance) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              notificationChannelId,
              'Diaspo Niger Location Service',
              description: 'Service de localisation en arrière-plan',
              importance:
                  Importance.low, // Low importance to minimize intrusion
            ),
          );

      await service.setForegroundNotificationInfo(
        title: "Diaspo Niger",
        content: "Localisation active (Mise à jour toutes les 5 min)",
      );
    }

    // Periodic timer for 5 minutes
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Check if user still wants tracking (double check via prefs inside isolate)
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

            // 2. Get current user ID (needs auth to be persisted or passed)
            // Firebase Auth in background isolate might need re-auth or use local storage for UID
            // Safest is to rely on current currentUser if persisted,
            // BUT `FirebaseAuth.instance.currentUser` might be null in a fresh isolate.
            // Strategy: We will assume the main app has signed in.
            // If currentUser is null, we can try to reload or just skip.

            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                    'location': GeoPoint(position.latitude, position.longitude),
                    'latitude':
                        position
                            .latitude, // Ensure these flat fields are also updated for queries
                    'longitude': position.longitude,
                    'lastSeen': FieldValue.serverTimestamp(),
                    'locationUpdatedAt':
                        FieldValue.serverTimestamp(), // Link to presence filter
                  });

              debugPrint(
                'Background Location Updated: ${position.latitude}, ${position.longitude}',
              );

              flutterLocalNotificationsPlugin.show(
                notificationId,
                'Diaspo Niger',
                'Position mise à jour: ${DateTime.now().hour}:${DateTime.now().minute}',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    notificationChannelId,
                    'Diaspo Niger Location Service',
                    icon: 'ic_bg_service_small',
                    ongoing: true,
                    importance: Importance.low,
                    priority: Priority.low,
                    showWhen: true,
                  ),
                ),
              );
            } else {
              debugPrint('Background Location: No user logged in.');
            }
          } catch (e) {
            debugPrint('Background Location Error: $e');
          }
        }
      }
    });
  }
}
