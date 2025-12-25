import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/firebase_collections.dart';
import '../constants/app_colors.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification', // Assurez-vous d'avoir cette icône ou utilisez '@mipmap/ic_launcher'
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          debugPrint('Local notification tapped: ${details.payload}');
          try {
            final data = jsonDecode(details.payload!);
            final type = data['type'];
            final targetId = data['targetId'];

            if (type != null && targetId != null) {
              _notificationTapCallback?.call(type, targetId);
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  /// Request notification permission
  Future<bool> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    return isAuthorized;
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      // For iOS, we need to get the APNS token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNS token not available yet');
          return null;
        }
      }

      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore for a specific user
  Future<void> saveTokenForUser(String userId) async {
    if (_fcmToken == null) {
      await _getToken();
    }

    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!, userId: userId);
    }
  }

  /// Save token to Firestore
  Future<void> _saveTokenToDatabase(String token, {String? userId}) async {
    if (userId == null) return;

    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        },
      );

      debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeTokenForUser(String userId) async {
    if (_fcmToken == null) return;

    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {
          'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
        },
      );

      debugPrint('FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Store notification in Firestore
    _storeNotification(message);

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher', // Fallback icon
            color: AppColors.primary,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    // Navigate based on notification type
    final type = message.data['type'];
    final targetId = message.data['targetId'];

    if (type != null && targetId != null) {
      // This will be handled by the app's navigation
      _notificationTapCallback?.call(type, targetId);
    }
  }

  // Callback for notification tap navigation
  void Function(String type, String targetId)? _notificationTapCallback;

  void setNotificationTapCallback(
    void Function(String type, String targetId) callback,
  ) {
    _notificationTapCallback = callback;
  }

  /// Store notification in Firestore for the user's notification history
  Future<void> _storeNotification(RemoteMessage message) async {
    final userId = message.data['userId'];
    if (userId == null) return;

    try {
      await _firestore.collection(FirebaseCollections.notifications).add({
        'userId': userId,
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'type': message.data['type'],
        'targetId': message.data['targetId'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }
  }

  /// Manually create a notification (e.g. for friend requests when no backend triggers exist)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String targetId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection(FirebaseCollections.notifications).add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'type': type,
        'targetId': targetId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Notification created manually for user: $userId');
    } catch (e) {
      debugPrint('Error creating manual notification: $e');
    }
  }

  /// Show proximity notification
  Future<void> showProximityNotification(int count) async {
    await _localNotifications.show(
      0, // ID 0 for generic proximity alert (replaces previous one)
      'Membres à proximité',
      '$count membres de la diaspora sont à moins de 5km de vous',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'proximity_channel', // id
          'Proximity Notifications', // title
          channelDescription: 'Notifications for nearby members',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: AppColors.primary,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
}
