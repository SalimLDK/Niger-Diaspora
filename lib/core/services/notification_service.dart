import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/firebase_collections.dart';
import '../constants/app_colors.dart';
import 'background_location_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service
  Future<void> initialize() async {
    // debugPrint('Initializing NotificationService...');

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();
    // debugPrint('FCM Token: $_fcmToken');

    // Configure foreground notification presentation options (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    // debugPrint('Foreground notification presentation options configured');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(
      _saveTokenToDatabase,
      onError: (error) {
        // debugPrint('❌ Error in token refresh listener: $error');
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (error) {
        // debugPrint('❌ Error in foreground message listener: $error');
      },
    );
    // debugPrint('Foreground message listener registered');

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (error) {
        // debugPrint('❌ Error in message opened listener: $error');
      },
    );

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // debugPrint('NotificationService initialization complete');
  }

  /// Initialize local notifications with Android channels
  Future<void> _initializeLocalNotifications() async {
    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
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
          // debugPrint('Local notification tapped: ${details.payload}');
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            final type = data['type'] as String?;
            final targetId = data['targetId'] as String? ?? '';

            if (type != null) {
              if (_notificationTapCallback != null) {
                _notificationTapCallback!.call(type, targetId, data);
              } else {
                // debugPrint('Queueing local notification tap: $type');
                _pendingNotificationTap = (
                  type: type,
                  targetId: targetId,
                  data: data,
                );
              }
            }
          } catch (e) {
            // debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Request notification permission for Android 13+ (API 33+)
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidPlugin != null) {
        // final granted = await androidPlugin.requestNotificationsPermission();
        // debugPrint('Android notification permission granted: $granted');
      }
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) return;

    // Messages channel (matches Firebase function channel ID)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'messages',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Friend requests channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'friends_channel',
        'Friend Requests',
        description: 'Notifications for friend requests',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Groups channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'groups_channel',
        'Groups',
        description: 'Notifications for group activities',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Events channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'events_channel',
        'Events',
        description: 'Notifications for events',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Event reminders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'event_reminders_channel',
        'Event Reminders',
        description: 'Reminders for upcoming events',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // General channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'general_channel',
        'General Notifications',
        description: 'General application notifications',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    // Background Location Channel (Critical for OnePlus/Android 12+ crash prevention)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        BackgroundLocationService.notificationChannelId,
        BackgroundLocationService.notificationChannelName,
        description: BackgroundLocationService.notificationChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    // Proximity channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'proximity_channel',
        'Proximity Notifications',
        description: 'Notifications for nearby members',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Orders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'orders_channel',
        'Orders',
        description: 'Notifications for marketplace orders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // debugPrint('Android notification channels created');
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

    // debugPrint('Notification permission: ${settings.authorizationStatus}');

    return isAuthorized;
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      // For iOS, we need to get the APNS token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          // debugPrint('APNS token not available yet');
          return null;
        }
      }

      _fcmToken = await _messaging.getToken();
      // debugPrint('FCM Token: $_fcmToken');

      return _fcmToken;
    } catch (e) {
      // debugPrint('Error getting FCM token: $e');
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

      // debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      // debugPrint('Error saving FCM token: $e');
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

      // debugPrint('FCM token removed for user: $userId');
    } catch (e) {
      // debugPrint('Error removing FCM token: $e');
    }
  }

  /// Handle foreground messages with preference filtering
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // debugPrint('========== FOREGROUND MESSAGE RECEIVED ==========');
    // debugPrint('Message ID: ${message.messageId}');
    // debugPrint('Notification Title: ${message.notification?.title}');
    // debugPrint('Notification Body: ${message.notification?.body}');
    // debugPrint('Data payload: ${message.data}');
    // debugPrint('=================================================');

    // Store notification in Firestore
    _storeNotification(message);

    // Check if notification should be shown based on user preferences
    final shouldShow = await _shouldShowNotification(message.data['type']);
    // debugPrint('Should show notification: $shouldShow');

    if (shouldShow) {
      // Show local notification
      // debugPrint('Attempting to show local notification...');
      try {
        await _showLocalNotification(message);
        // debugPrint('Local notification display completed');
      } catch (
        e //, stackTrace
      ) {
        // debugPrint('ERROR showing local notification: $e');
        // debugPrint('Stack trace: $stackTrace');
      }
    } else {
      // debugPrint(
      //   'Notification filtered by user preferences: ${message.data['type']}',
      // );
    }
  }

  /// Check if notification should be shown based on user preferences
  Future<bool> _shouldShowNotification(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (type == null) return true;

      switch (type) {
        case 'message':
          return prefs.getBool('notify_messages') ?? true;
        case 'friendRequest':
        case 'friendRequestAccepted':
          return prefs.getBool('notify_friend_requests') ?? true;
        case 'groupInvite':
        case 'groupJoinRequest':
        case 'groupRequestApproved':
        case 'groupRequestRejected':
          return prefs.getBool('notify_groups') ?? true;
        case 'eventUpdate':
          return prefs.getBool('notify_events') ?? true;
        case 'eventReminder':
          return prefs.getBool('notify_event_reminders') ?? true;
        case 'newOrder':
        case 'orderPaid':
        case 'orderShipped':
        case 'orderDelivered':
        case 'orderCancelled':
          return prefs.getBool('notify_orders') ?? true;
        default:
          return true;
      }
    } catch (e) {
      // debugPrint('Error checking notification preferences: $e');
      return true; // Show notification if error
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Rappels',
          channelDescription: 'Canal pour les rappels programmés',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      payload: payload,
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = data['type'];

    // Get title and body from notification or fallback to data payload
    final title =
        notification?.title ?? data['title'] ?? 'Nouvelle notification';
    final body = notification?.body ?? data['body'] ?? '';

    // Skip if no content to show
    if (title.isEmpty && body.isEmpty) {
      // debugPrint('Skipping notification: no title or body');
      return;
    }

    final (channelId, channelName, defaultImportance) = _getChannelForType(
      type,
    );

    // Override importance if priority is specified in data
    final priority = data['priority'];
    final importance =
        priority != null
            ? _getImportanceForPriority(priority)
            : defaultImportance;

    // Get sound and vibration preferences
    final prefs = await SharedPreferences.getInstance();
    var soundEnabled = prefs.getBool('notification_sound') ?? true;
    var vibrationEnabled = prefs.getBool('notification_vibration') ?? true;

    // Check if we're in quiet hours
    if (await _isInQuietHours(prefs)) {
      soundEnabled = false;
      vibrationEnabled = false;
      // debugPrint('Quiet hours active - sound and vibration disabled');
    }

    // Generate unique notification ID
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Notifications for $channelName',
          importance: importance,
          priority:
              importance == Importance.max
                  ? Priority.max
                  : importance == Importance.high
                  ? Priority.high
                  : importance == Importance.low
                  ? Priority.low
                  : Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          color: AppColors.primary,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
          groupKey: data['groupKey'],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
        ),
      ),
      payload: jsonEncode(data),
    );

    // debugPrint('Local notification shown: $title');
  }

  /// Check if current time is within quiet hours
  Future<bool> _isInQuietHours(SharedPreferences prefs) async {
    final quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
    if (!quietHoursEnabled) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startHour = prefs.getInt('quiet_hours_start_hour') ?? 22;
    final startMinute = prefs.getInt('quiet_hours_start_minute') ?? 0;
    final endHour = prefs.getInt('quiet_hours_end_hour') ?? 8;
    final endMinute = prefs.getInt('quiet_hours_end_minute') ?? 0;

    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Handle cases where quiet hours span midnight
    if (startMinutes > endMinutes) {
      // e.g., 22:00 to 08:00
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // e.g., 13:00 to 15:00 (siesta)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  /// Get notification channel based on type
  (String, String, Importance) _getChannelForType(String? type) {
    switch (type) {
      case 'message':
        return ('messages', 'Messages', Importance.high);
      case 'friendRequest':
      case 'friendRequestAccepted':
        return ('friends_channel', 'Friend Requests', Importance.high);
      case 'groupInvite':
      case 'groupJoinRequest':
      case 'groupRequestApproved':
      case 'groupRequestRejected':
        return ('groups_channel', 'Groups', Importance.defaultImportance);
      case 'eventUpdate':
        return ('events_channel', 'Events', Importance.defaultImportance);
      case 'eventReminder':
        return ('event_reminders_channel', 'Event Reminders', Importance.high);
      case 'newOrder':
      case 'orderPaid':
      case 'orderShipped':
      case 'orderDelivered':
      case 'orderCancelled':
        return ('orders_channel', 'Orders', Importance.high);
      default:
        return (
          'general_channel',
          'General Notifications',
          Importance.defaultImportance,
        );
    }
  }

  /// Get importance based on priority string
  Importance _getImportanceForPriority(String? priority) {
    if (priority == null) return Importance.defaultImportance;

    switch (priority) {
      case 'urgent':
        return Importance.max;
      case 'high':
        return Importance.high;
      case 'low':
        return Importance.low;
      case 'normal':
      default:
        return Importance.defaultImportance;
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // debugPrint('Notification tapped: ${message.messageId}');
    // debugPrint('Data: ${message.data}');

    // Navigate based on notification type
    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String? ?? '';
    final data = Map<String, dynamic>.from(message.data);

    if (type != null) {
      if (_notificationTapCallback != null) {
        // Callback is set, navigate immediately
        _notificationTapCallback!.call(type, targetId, data);
      } else {
        // Callback not set yet (app still initializing), queue for later
        // debugPrint('Queueing notification tap for later processing: $type');
        _pendingNotificationTap = (type: type, targetId: targetId, data: data);
      }
    }
  }

  // Callback for notification tap navigation
  void Function(String type, String targetId, Map<String, dynamic> data)?
  _notificationTapCallback;

  // Queue for pending notification taps (when callback isn't set yet)
  ({String type, String targetId, Map<String, dynamic> data})?
  _pendingNotificationTap;

  void setNotificationTapCallback(
    void Function(String type, String targetId, Map<String, dynamic> data)
    callback,
  ) {
    _notificationTapCallback = callback;

    // Process any pending notification tap
    if (_pendingNotificationTap != null) {
      // debugPrint(
      //   'Processing pending notification tap: ${_pendingNotificationTap!.type}',
      // );
      callback(
        _pendingNotificationTap!.type,
        _pendingNotificationTap!.targetId,
        _pendingNotificationTap!.data,
      );
      _pendingNotificationTap = null;
    }
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
      // debugPrint('Error storing notification: $e');
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
      // debugPrint('Notification created manually for user: $userId');
    } catch (e) {
      // debugPrint('Error creating manual notification: $e');
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
      // debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      // debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      // debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      // debugPrint('Error unsubscribing from topic: $e');
    }
  }
}
