import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/app_colors.dart';
import 'e2ee/notification_decryption_service.dart';
import 'background_location_service.dart';
import 'background_reply_service.dart';
import 'native_call_service.dart';
import '../../l10n/app_localizations.dart';
import 'preferences_service.dart';
import 'supabase_auth_bridge.dart';

/// Représente un message pour le style MessagingStyle (comme WhatsApp)
class NotificationMessage {
  final String text;
  final DateTime timestamp;
  final Person? sender;

  NotificationMessage({
    required this.text,
    required this.timestamp,
    this.sender,
  });

  Message toMessage() {
    return Message(text, timestamp, sender);
  }
}

/// Représente une notification active pour le groupement style WhatsApp
class ActiveNotification {
  final int id;
  final String title;
  final String body;
  final String? senderName;
  final String? senderPhotoUrl;
  final DateTime timestamp;
  final String? messageType; // text, image, video, audio, document

  ActiveNotification({
    required this.id,
    required this.title,
    required this.body,
    this.senderName,
    this.senderPhotoUrl,
    required this.timestamp,
    this.messageType,
  });
}

/// Groupe de notifications actives
class NotificationGroup {
  final String groupKey;
  final String type;
  final List<ActiveNotification> notifications;
  final String? targetId;
  final String? conversationTitle; // Nom du groupe ou de la personne
  final String? conversationPhotoUrl;
  final bool isGroup;

  NotificationGroup({
    required this.groupKey,
    required this.type,
    required this.notifications,
    this.targetId,
    this.conversationTitle,
    this.conversationPhotoUrl,
    this.isGroup = false,
  });

  int get count => notifications.length;
  int get unreadCount => notifications.length;

  /// Retourne les expéditeurs uniques dans ce groupe
  Set<String> get uniqueSenders =>
      notifications
          .map((n) => n.senderName ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
}

/// Constantes pour les actions de notification
const String kReplyActionId = 'reply_action';
const String kMarkReadActionId = 'mark_read_action';

/// Masque les boutons Répondre/Marquer comme lu sur Android (iOS non
/// concerné, mécanisme différent — voir plus bas).
///
/// Les deux actions passent par `showsUserInterface: false`, donc par le
/// même dispatch background natif → Dart de flutter_local_notifications
/// (`ActionBroadcastReceiver` → `notificationActionBackgroundHandler`).
/// Vérifié sur SM A515F le 2026-08-14, à trois reprises (build debug, build
/// profile, après redémarrage complet de l'app à chaque fois) : le broadcast
/// est bien délivré par Android (confirmé dans `dumpsys`/logcat système),
/// mais AUCUN code Dart ne s'exécute ensuite — aucune ligne de log, y compris
/// une ligne ajoutée spécifiquement pour ce diagnostic. Le bouton restait
/// donc silencieusement mort : le champ de saisie s'ouvrait, l'envoi semblait
/// fonctionner côté UI, mais rien n'atteignait jamais la base.
///
/// Remettre à `true` seulement après avoir confirmé que ce dispatch
/// fonctionne de nouveau sur appareil réel (pas seulement `flutter analyze`).
const bool kNotificationQuickActionsEnabled = false;

/// Helper to get localized strings in background context where BuildContext is unavailable
/// Uses stored locale preference to determine which language to use
String _getLocalizedString(String key) {
  // PreferencesService.instance est un singleton PAR ISOLATE — dans un
  // isolate background frais (celui que spawn firebaseMessagingBackgroundHandler
  // / notificationActionBackgroundHandler), `initialize()` n'a jamais été
  // appelé, donc `.locale` lève un StateError. Vérifié sur SM A515F le
  // 2026-08-13 : « FlutterFire Messaging: An error occurred in your
  // background messaging handler / Bad state: PreferencesService not
  // initialized » — la notification (et ses actions Répondre/Marquer comme
  // lu) n'était alors jamais affichée du tout, l'exception remontant non
  // rattrapée jusqu'au plugin. Repli sur 'fr', comme si la préférence était
  // simplement absente.
  String? locale;
  try {
    locale = PreferencesService.instance.locale;
  } catch (e) {
    debugPrint('_getLocalizedString: PreferencesService indisponible ($e)');
  }
  locale ??= 'fr'; // Default to French

  // Notification strings map
  final strings = {
    'en': {
      'reply_sent': 'Message sent',
      'reply_confirmation': 'Your reply has been sent',
      'pending_message': 'Pending message',
      'pending_reply': 'Your reply will be sent as soon as possible',
      'incoming_video_call': 'Incoming video call...',
      'incoming_audio_call': 'Incoming audio call...',
      'answer': 'Answer',
      'decline': 'Decline',
      'reply': 'Reply',
      'mark_read': 'Mark as read',
      'send': 'Send',
      'type_reply': 'Type your reply...',
      'calls': 'Calls',
      'calls_description': 'Notifications for incoming calls',
      'unknown': 'Unknown',
    },
    'fr': {
      'reply_sent': 'Message envoyé',
      'reply_confirmation': 'Votre réponse a été envoyée',
      'pending_message': 'Message en attente',
      'pending_reply': 'Votre réponse sera envoyée dès que possible',
      'incoming_video_call': 'Appel vidéo entrant...',
      'incoming_audio_call': 'Appel vocal entrant...',
      'answer': 'Répondre',
      'decline': 'Refuser',
      'reply': 'Répondre',
      'mark_read': 'Marquer comme lu',
      'send': 'Envoyer',
      'type_reply': 'Tapez votre réponse...',
      'calls': 'Appels',
      'calls_description': 'Notifications pour les appels entrants',
      'unknown': 'Inconnu',
    },
  };

  return strings[locale]?[key] ?? strings['fr']![key]!;
}

/// Handler background pour les réponses aux actions de notification
/// DOIT être une fonction top-level (en dehors de toute classe)
@pragma('vm:entry-point')
Future<void> notificationActionBackgroundHandler(
  NotificationResponse response,
) async {
  // Initialiser Firebase si nécessaire
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  final actionId = response.actionId;
  final payload = response.payload;
  final input = response.input; // Texte de la réponse directe
  final notificationId = response.id;

  if (payload == null) {
    debugPrint('notificationActionBackgroundHandler: action "$actionId" reçue sans payload');
    return;
  }

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final conversationId = data['conversationId'] as String?;

    if (conversationId == null) {
      debugPrint(
        'notificationActionBackgroundHandler: conversationId absent du payload pour "$actionId"',
      );
      return;
    }

    if (actionId == kReplyActionId && input != null && input.isNotEmpty) {
      // Envoyer la réponse via le service background
      final success = await BackgroundReplyService.sendReply(
        conversationId: conversationId,
        replyText: input,
      );

      // Show confirmation notification
      await _showQuickReplyConfirmation(
        conversationId: conversationId,
        success: success,
        notificationId: notificationId,
      );
    } else if (actionId == kReplyActionId) {
      // `input` null/vide : Android n'a pas remonté le texte du RemoteInput.
      // Sans cette branche, ce cas retombait en silence dans le fond du
      // bloc try — zéro log, zéro notification, indiscernable d'un succès
      // tant qu'on n'a pas vérifié la base. Repéré sur SM A515F le
      // 2026-08-14 : le bouton Répondre affichait bien le champ de saisie,
      // l'envoi semblait fonctionner côté UI, mais rien n'atteignait jamais
      // BackgroundReplyService.sendReply.
      debugPrint(
        'notificationActionBackgroundHandler: action reply reçue sans texte '
        '(input=${input == null ? "null" : "vide"}) — rien envoyé',
      );
    } else if (actionId == kMarkReadActionId) {
      // Marquer la conversation comme lue
      await BackgroundReplyService.markAsRead(conversationId: conversationId);
      // Fermer les notifications de cette conversation
      await _cancelNotificationsForConversation(conversationId, notificationId);
    }
  } catch (e) {
    debugPrint('notificationActionBackgroundHandler error: $e');
  }
}

/// Show a brief confirmation notification after quick reply
/// This replaces the original notification with a status update
Future<void> _showQuickReplyConfirmation({
  required String conversationId,
  required bool success,
  int? notificationId,
}) async {
  final localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize for background
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await localNotifications.initialize(initSettings);

  // Use the same notification ID to replace the original, or generate one
  final confirmationId = notificationId ?? conversationId.hashCode;

  if (success) {
    // Show success confirmation briefly
    const androidDetails = AndroidNotificationDetails(
      'quick_reply_confirmation',
      'Reply Confirmation',
      channelDescription: 'Confirmation of sent messages',
      importance: Importance.low,
      priority: Priority.low,
      autoCancel: true,
      timeoutAfter: 3000, // Auto-dismiss after 3 seconds
      icon: '@drawable/ic_stat_notification',
      color: Color(0xFF4CAF50), // Green for success
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      confirmationId,
      _getLocalizedString('reply_sent'),
      _getLocalizedString('reply_confirmation'),
      details,
    );

    // Cancel after a short delay (Android handles this with timeoutAfter)
    // For iOS, we cancel manually
    Future.delayed(const Duration(seconds: 3), () {
      localNotifications.cancel(confirmationId);
    });
  } else {
    // Show failure notification with option to retry when app opens
    const androidDetails = AndroidNotificationDetails(
      'quick_reply_confirmation',
      'Reply Confirmation',
      channelDescription: 'Confirmation of sent messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      icon: '@drawable/ic_stat_notification',
      color: Color(0xFFFF9800), // Orange for pending/retry
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      confirmationId,
      _getLocalizedString('pending_message'),
      _getLocalizedString('pending_reply'),
      details,
      payload: jsonEncode({
        'conversationId': conversationId,
        'action': 'pending_reply',
      }),
    );
  }
}

/// Gère le dismiss de notification depuis un autre appareil (background)
Future<void> _handleNotificationDismissBackground(
  Map<String, dynamic> data,
) async {
  final notificationType = data['notificationType'] as String?;
  final conversationId = data['conversationId'] as String?;
  final targetId = data['targetId'] as String?;

  final localNotifications = FlutterLocalNotificationsPlugin();

  // Initialiser les notifications locales pour le background
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await localNotifications.initialize(initSettings);

  try {
    if (notificationType == 'message' && conversationId != null) {
      // Récupérer et annuler les IDs de notification de cette conversation
      final prefs = await SharedPreferences.getInstance();
      final key = 'notification_ids_$conversationId';
      final idsJson = prefs.getString(key);

      if (idsJson != null) {
        final ids = (jsonDecode(idsJson) as List).cast<int>();
        for (final id in ids) {
          await localNotifications.cancel(id);
        }
        await prefs.remove(key);
      }

      // Annuler aussi le groupe de notification
      await localNotifications.cancel('msg_$conversationId'.hashCode);
    } else if (targetId != null) {
      // Pour les autres types, annuler par targetId
      await localNotifications.cancel(targetId.hashCode);
    }

    // Mettre à jour le badge de l'app
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId != null) {
      // Compter les notifications non lues depuis Supabase
      final countResult = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      final count = countResult.count;
      if (count > 0) {
        AppBadgePlus.updateBadge(count);
      } else {
        AppBadgePlus.updateBadge(0);
      }
    }
  } catch (e) {
    // Silently fail - dismiss is best effort
  }
}

/// Ferme les notifications pour une conversation (utilisé depuis le handler background)
Future<void> _cancelNotificationsForConversation(
  String conversationId,
  int? currentNotificationId,
) async {
  final localNotifications = FlutterLocalNotificationsPlugin();

  // Initialiser les notifications locales pour le background
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await localNotifications.initialize(initSettings);

  // Annuler la notification actuelle
  if (currentNotificationId != null) {
    await localNotifications.cancel(currentNotificationId);
  }

  // Récupérer et annuler les autres IDs de notification de cette conversation depuis SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final key = 'notification_ids_$conversationId';
  final idsJson = prefs.getString(key);

  if (idsJson != null) {
    try {
      final ids = (jsonDecode(idsJson) as List).cast<int>();
      for (final id in ids) {
        if (id != currentNotificationId) {
          await localNotifications.cancel(id);
        }
      }
      // Nettoyer les IDs sauvegardés
      await prefs.remove(key);
    } catch (_) {}
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (required for background)
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'];

  // Handle incoming call notifications in background
  if (type == 'incoming_call') {
    await _showIncomingCallNotificationBackground(data);
    return;
  }

  // Handle notification dismiss from another device (multi-device sync)
  if (type == 'notification_dismiss') {
    await _handleNotificationDismissBackground(data);
    return;
  }

  // Only handle message notifications for delivery confirmation
  if (type == 'message') {
    final conversationId = data['conversationId'];
    final messageId = data['messageId'];

    // Get current user ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');

    if (conversationId != null && messageId != null && userId != null) {
      try {
        // Confirm delivery directly via Supabase RPC (single source of truth).
        // RTDB delivery tracking has been retired; all delivery/read state lives
        // in the messages.data JSONB column and is surfaced by Supabase Realtime.
        await Supabase.instance.client.rpc('mark_messages_as_delivered', params: {
          'p_conversation_id': conversationId,
          'p_user_id': userId,
        });
      } catch (e) {
        // Silently fail - delivery confirmation is best effort
      }
    }

    // Fallback local notification for Android OEM devices (Xiaomi, Huawei, OPPO…)
    // that may suppress the FCM notification field in background state.
    // Same tag as Cloud Functions (msg_{conversationId}) → replaces FCM notification,
    // no duplicate. On iOS, this handler is never called for notification messages.
    if (conversationId != null) {
      final title =
          data['title'] as String? ?? data['senderName'] as String? ?? 'Message';
      final body = data['isE2EE'] == 'true'
          ? '🔒 Nouveau message'
          : (data['body'] as String? ?? 'Nouveau message');
      try {
        await _showFallbackMessageNotification(
          conversationId: conversationId,
          title: title,
          body: body,
          data: data,
        );
      } catch (e) {
        // Sans ce try/catch dédié, une exception ici remonte non rattrapée
        // jusqu'au wrapper FlutterFire Messaging générique — le message
        // « An error occurred in your background messaging handler » ne dit
        // pas QUELLE étape a échoué. Vécu sur SM A515F le 2026-08-13
        // (PreferencesService non initialisé dans cet isolate).
        debugPrint('firebaseMessagingBackgroundHandler: notification fallback error: $e');
      }
    }
  }
}

/// Shows a minimal local notification for a message when the OS may have
/// suppressed the FCM notification (background state on restrictive Android OEMs).
///
/// C'est aussi, en pratique, le SEUL chemin qui affiche une notification de
/// message quand l'app est en arrière-plan ou fermée : `_showLocalNotification`
/// (avec les actions Répondre/Marquer comme lu) n'est câblée que sur
/// `FirebaseMessaging.onMessage`, strictement premier plan. Sans `actions`
/// ici, la réponse rapide n'était donc jamais accessible dans le scénario où
/// elle sert réellement — vérifié sur SM A515F le 2026-08-13 (notification
/// reçue, zéro bouton d'action). Le payload doit être le même JSON que celui
/// que `notificationActionBackgroundHandler` décode (`jsonDecode(payload)`) :
/// l'ancien payload `'message:$conversationId'` n'était pas du JSON valide et
/// aurait fait échouer même un simple tap sur la notification.
@pragma('vm:entry-point')
Future<void> _showFallbackMessageNotification({
  required String conversationId,
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
  // Android identifie une notification par le COUPLE (tag, id), pas par le tag
  // seul. Avec un id dérivé de la conversation, ce repli s'ajoutait à celle du
  // SDK Firebase au lieu de la remplacer — deux bannières pour un message.
  // Le SDK poste sous l'id 0 dès qu'un tag est fourni : on s'aligne dessus.
  const notifId = 0;
  await plugin.show(
    notifId,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'messages',
        'Messages',
        channelDescription: 'Notifications pour les messages',
        importance: Importance.high,
        priority: Priority.high,
        tag: 'msg_$conversationId', // same tag as Cloud Functions → no duplicate
        // Sans ça, le repli retombait sur l'icône par défaut du plugin
        // (`@mipmap/ic_launcher`), que la barre d'état réduit à un disque
        // blanc — vérifié à l'écran le 2026-08-06.
        icon: '@drawable/ic_stat_notification',
        color: AppColors.primary,
        actions: kNotificationQuickActionsEnabled
            ? <AndroidNotificationAction>[
                AndroidNotificationAction(
                  kReplyActionId,
                  _getLocalizedString('reply'),
                  icon: const DrawableResourceAndroidBitmap('@drawable/ic_reply'),
                  showsUserInterface: false,
                  inputs: <AndroidNotificationActionInput>[
                    AndroidNotificationActionInput(
                      label: _getLocalizedString('type_reply'),
                      allowFreeFormInput: true,
                    ),
                  ],
                ),
                AndroidNotificationAction(
                  kMarkReadActionId,
                  _getLocalizedString('mark_read'),
                  icon: const DrawableResourceAndroidBitmap('@drawable/ic_mark_read'),
                  showsUserInterface: false,
                ),
              ]
            : const <AndroidNotificationAction>[],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(data),
  );
}

/// Show incoming call notification in background using native call UI
/// Uses flutter_callkit_incoming to display CallKit (iOS) / ConnectionService (Android)
/// This provides the native full-screen call experience like WhatsApp/Messenger
@pragma('vm:entry-point')
Future<void> _showIncomingCallNotificationBackground(
  Map<String, dynamic> data,
) async {
  final callerName =
      data['callerName'] as String? ?? _getLocalizedString('unknown');
  final callerPhotoUrl = data['callerPhotoUrl'] as String?;
  final callType = data['callType'] as String? ?? 'audio';
  final callId = data['callId'] as String? ?? '';
  final isVideo = callType == 'video';

  // Use flutter_callkit_incoming for native call UI
  // This works even when the app is killed and shows on lock screen
  final params = CallKitParams(
    // MÊME UUID que celui utilisé par NativeCallService dans l'isolate de
    // l'app : sans ça, l'app est incapable d'éteindre la bannière affichée
    // depuis l'arrière-plan et en empile une seconde au retour au premier plan.
    id: NativeCallService.callKitUuidFor(callId),
    nameCaller: callerName,
    appName: 'Diaspo Niger',
    avatar: callerPhotoUrl,
    handle: callerName,
    type: isVideo ? 1 : 0, // 0 = audio, 1 = video
    textAccept: 'Accepter',
    textDecline: 'Refuser',
    missedCallNotification: NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: isVideo ? 'Appel vidéo manqué' : 'Appel manqué',
      callbackText: 'Rappeler',
    ),
    duration: 45000, // Ring for 45 seconds
    extra: <String, dynamic>{
      'callId': callId,
      'isVideo': isVideo,
    },
    headers: <String, dynamic>{'callId': callId},
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: true,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#E97424',
      actionColor: '#4CAF50',
      textColor: '#FFFFFF',
      incomingCallNotificationChannelName: 'Appels entrants',
      missedCallNotificationChannelName: 'Appels manqués',
      isShowCallID: false,
    ),
    ios: IOSParams(
      iconName: 'CallKitIcon',
      handleType: 'generic',
      supportsVideo: isVideo,
      maximumCallGroups: 1,
      maximumCallsPerCallGroup: 1,
      audioSessionMode: 'voiceChat',
      audioSessionActive: true,
      audioSessionPreferredSampleRate: 16000.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF: false,
      supportsHolding: true,
      supportsGrouping: false,
      supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Cache des groupes de notifications actives (style WhatsApp)
  final Map<String, NotificationGroup> _activeGroups = {};

  /// Cache des photos de profil téléchargées
  final Map<String, String> _avatarPathCache = {};

  /// Cache des Person pour MessagingStyle
  final Map<String, Person> _personCache = {};

  /// IDs réservés pour les notifications de résumé par type
  static const int _messageSummaryId = 100000;
  static const int _groupSummaryId = 100001;
  static const int _eventSummaryId = 100002;
  static const int _friendSummaryId = 100003;
  static const int _orderSummaryId = 100004;

  /// Préfixes pour les groupKeys automatiques
  static const String _messageGroupPrefix = 'messages_';
  static const String _groupGroupPrefix = 'group_';
  static const String _eventGroupPrefix = 'event_';
  static const String _friendGroupPrefix = 'friend_';
  static const String _orderGroupPrefix = 'order_';

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

    // Nettoyer les anciens fichiers d'avatar en arrière-plan
    cleanupOldAvatarCache();
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

    // Configuration iOS avec catégories pour les actions de notification
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'message_category',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              kReplyActionId,
              _getLocalizedString('reply'),
              buttonTitle: _getLocalizedString('send'),
              placeholder: _getLocalizedString('type_reply'),
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              kMarkReadActionId,
              _getLocalizedString('mark_read'),
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationActionBackgroundHandler,
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

  /// Télécharge et cache une photo de profil pour les notifications
  Future<String?> _downloadAndCacheAvatar(
    String? photoUrl,
    String uniqueId,
  ) async {
    if (photoUrl == null || photoUrl.isEmpty) return null;

    // Vérifier le cache en mémoire
    if (_avatarPathCache.containsKey(uniqueId)) {
      final cachedPath = _avatarPathCache[uniqueId]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }

    try {
      final response = await http
          .get(Uri.parse(photoUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/notification_avatar_$uniqueId.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        _avatarPathCache[uniqueId] = filePath;
        return filePath;
      }
    } catch (e) {
      // Silently fail - use default icon
    }
    return null;
  }

  /// Crée un objet Person pour MessagingStyle avec photo
  Future<Person> _getOrCreatePerson({
    required String name,
    required String uniqueKey,
    String? photoUrl,
    bool isBot = false,
  }) async {
    // Vérifier le cache
    if (_personCache.containsKey(uniqueKey)) {
      return _personCache[uniqueKey]!;
    }

    String? iconPath;

    // Télécharger la photo si disponible (Android seulement)
    if (Platform.isAndroid && photoUrl != null && photoUrl.isNotEmpty) {
      iconPath = await _downloadAndCacheAvatar(photoUrl, uniqueKey);
    }

    final person = Person(
      name: name,
      key: uniqueKey,
      icon: iconPath != null ? BitmapFilePathAndroidIcon(iconPath) : null,
      bot: isBot,
    );

    _personCache[uniqueKey] = person;
    return person;
  }

  /// Génère le pattern de vibration selon le type
  Int64List _getVibrationPattern(String? type) {
    switch (type) {
      case 'message':
        // Pattern court pour les messages (comme WhatsApp)
        return Int64List.fromList([0, 100, 50, 100]);
      case 'incoming_call':
        // Pattern long répétitif pour les appels
        return Int64List.fromList([0, 500, 200, 500, 200, 500]);
      case 'friendRequest':
      case 'friendRequestAccepted':
        return Int64List.fromList([0, 200, 100, 200]);
      default:
        return Int64List.fromList([0, 250, 100, 250]);
    }
  }

  /// Retourne la couleur LED selon le type
  Color _getLedColorForType(String? type) {
    switch (type) {
      case 'message':
        return AppColors.primary;
      case 'friendRequest':
      case 'friendRequestAccepted':
        return Colors.blue;
      case 'groupInvite':
      case 'groupJoinRequest':
        return Colors.purple;
      case 'eventUpdate':
      case 'eventReminder':
        return Colors.orange;
      case 'incoming_call':
        return Colors.green;
      case 'newOrder':
      case 'orderPaid':
        return Colors.teal;
      default:
        return AppColors.primary;
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

    // Messages channel optimisé (style WhatsApp)
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'messages',
        'Messages',
        description: 'Notifications pour les nouveaux messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: AppColors.primary,
        showBadge: true,
        vibrationPattern: Int64List.fromList([0, 100, 50, 100]),
      ),
    );

    // Friend requests channel avec LED bleue
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'friends_channel',
        'Demandes d\'amis',
        description: 'Notifications pour les demandes d\'amis',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue,
        showBadge: true,
      ),
    );

    // Groups channel avec LED violette
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'groups_channel',
        'Groupes',
        description: 'Notifications pour les activités de groupe',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.purple,
        showBadge: true,
      ),
    );

    // Events channel avec LED orange
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'events_channel',
        'Événements',
        description: 'Notifications pour les événements',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.orange,
        showBadge: true,
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

    // Audio rooms reminders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'audio_rooms_reminders_channel',
        'Rappels de salles audio',
        description: 'Rappels pour les salles audio programmées',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Audio room active channel (ongoing while in a room)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'audio_room_active_channel',
        'Salon Audio Actif',
        description: 'Notification pendant la participation à un salon audio',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    // Podcast reminders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'podcast_reminders_channel',
        'Nouveaux épisodes',
        description: 'Notifications pour les nouveaux épisodes de podcasts',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Podcast playback channel (ongoing while playing)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'podcast_playback_channel',
        'Lecture Podcast',
        description: 'Contrôles de lecture audio',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    // Transfer reminders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'transfer_reminders_channel',
        'Rappels de transferts',
        description: 'Rappels pour les transferts programmés',
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

    // Calls channel - HIGH PRIORITY for incoming calls
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'calls_channel',
        'Appels',
        description: 'Notifications pour les appels entrants',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: AppColors.primary,
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

  /// Key for tracking if notification permission dialog has been shown
  static const String _notificationPermissionCheckedKey =
      'notification_permission_checked';

  /// Check if permission has already been requested
  Future<bool> hasRequestedNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionCheckedKey) ?? false;
  }

  /// Mark that permission has been requested
  Future<void> _markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPermissionCheckedKey, true);
  }

  /// Check current notification permission status without requesting
  Future<bool> isNotificationPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Show notification permission dialog
  Future<bool?> _showNotificationPermissionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Navigator.of(context).push<bool>(
      DialogRoute<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFE97424),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.enableNotifications)),
                ],
              ),
              content: Text(l10n.notificationEnableDescription),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.later),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.enable),
                ),
              ],
            ),
      ),
    );
  }

  /// Public method to request notification permission with optional contextual dialog
  /// Call this at an optimal moment (e.g., before first message send, or from settings)
  /// Returns true if permission was granted, false otherwise
  Future<bool> requestNotificationPermission({
    BuildContext? context,
    bool showContextDialog = true,
  }) async {
    // Check if already granted
    if (await isNotificationPermissionGranted()) {
      return true;
    }

    // Check if already requested and denied (don't show dialog again)
    final alreadyRequested = await hasRequestedNotificationPermission();

    // If context provided and showContextDialog is true, show contextual dialog first
    if (context != null &&
        showContextDialog &&
        context.mounted &&
        !alreadyRequested) {
      final shouldProceed = await _showNotificationPermissionDialog(context);

      if (shouldProceed != true) {
        return false;
      }
    }

    // Request the actual system permission
    await _markPermissionRequested();
    final granted = await _requestPermission();

    // If granted, get the token
    if (granted) {
      await _getToken();
    } else if (context != null && context.mounted) {
      // Permission was denied - show denial handling dialog
      await _showPermissionDeniedDialog(context);
    }

    return granted;
  }

  /// Show dialog when notification permission is denied
  /// Offers option to open app settings
  Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldOpenSettings = await Navigator.of(context).push<bool>(
      DialogRoute<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.notifications_off, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.notificationsDisabled)),
                ],
              ),
              content: Text(l10n.notificationDisabledDescription),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.later),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.settings, size: 18),
                  label: Text(l10n.settings),
                ),
              ],
            ),
      ),
    );

    if (shouldOpenSettings == true) {
      await openNotificationSettings();
    }
  }

  /// Open system app settings for notifications
  /// Works on both Android and iOS
  Future<bool> openNotificationSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Check if notification permission is permanently denied
  /// Returns true if user selected "Don't ask again" on Android
  Future<bool> isNotificationPermissionPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.notification.status;
      return status.isPermanentlyDenied;
    }
    // iOS doesn't have "permanently denied" - user can always change in settings
    return false;
  }

  /// Request notification permission again after it was denied
  /// If permanently denied, opens app settings instead
  Future<bool> retryNotificationPermission({BuildContext? context}) async {
    // Check if already granted
    if (await isNotificationPermissionGranted()) {
      return true;
    }

    // Check if permanently denied (Android)
    if (await isNotificationPermissionPermanentlyDenied()) {
      if (context != null && context.mounted) {
        await _showPermanentlyDeniedDialog(context);
      }
      return false;
    }

    // Try requesting again (check mounted before passing context)
    return requestNotificationPermission(
      context: (context != null && context.mounted) ? context : null,
      showContextDialog:
          false, // Don't show intro dialog, user knows what they want
    );
  }

  /// Show dialog when permission is permanently denied
  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldOpenSettings = await Navigator.of(context).push<bool>(
      DialogRoute<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.permissionBlocked)),
                ],
              ),
              content: Text(l10n.notificationBlockedDescription),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.settings, size: 18),
                  label: Text(l10n.openSettings),
                ),
              ],
            ),
      ),
    );

    if (shouldOpenSettings == true) {
      await openNotificationSettings();
    }
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
  /// Dernier userId connu : permet au listener onTokenRefresh (qui ne reçoit
  /// que le token) de sauvegarder sous le bon utilisateur.
  String? _lastKnownUserId;

  /// Utilisateur déjà synchronisé pendant cette exécution du process, pour que
  /// l'appel depuis `authStateChanges` (qui émet à répétition) ne relance pas
  /// un aller-retour base à chaque émission.
  String? _tokenSyncedForUser;

  Future<void> saveTokenForUser(
    String userId, {
    String? displayName,
    String? photoUrl,
  }) async {
    _lastKnownUserId = userId;

    // Cache pour les isolates background (action de notification, message
    // FCM en arrière-plan) : ils n'ont pas accès à Riverpod ni à
    // FirebaseAuth.currentUser au moment où ils se réveillent, seulement à
    // SharedPreferences. Sans ce cache, `currentUserId` restait `null` pour
    // toujours — la réponse rapide depuis une notification et la
    // confirmation de livraison en arrière-plan étaient silencieusement
    // court-circuitées avant même de tenter une écriture.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', userId);
      if (displayName != null && displayName.isNotEmpty) {
        await prefs.setString('currentUserDisplayName', displayName);
      }
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await prefs.setString('currentUserPhotoUrl', photoUrl);
      }
    } catch (e) {
      debugPrint('NotificationService: cache currentUserId error: $e');
    }

    // Vide la file des réponses de notification qui ont échoué pendant que
    // `currentUserId` était vide (offline, ou app pas encore lancée depuis).
    // Fire-and-forget : ne doit pas retarder le reste de saveTokenForUser.
    unawaited(BackgroundReplyService.processPendingMessages());

    if (_tokenSyncedForUser == userId) return;
    _tokenSyncedForUser = userId;

    if (_fcmToken == null) {
      await _getToken();
    }

    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!, userId: userId);
    }

    await _bindVoipTokenTo(userId);
  }

  /// Branche le jeton VoIP (PushKit, iOS) sur `users.voip_token`.
  ///
  /// `NativeCallService` exposait `onVoipTokenUpdated` mais personne ne lui
  /// affectait de callback, et `saveVoipTokenForUser` n'était appelée nulle
  /// part : la colonne restait vide, donc aucun appel CallKit ne pouvait
  /// sonner sur iOS. Le jeton peut arriver avant ou après la connexion, d'où
  /// les deux chemins — le callback pour la suite, et la lecture immédiate
  /// pour celui déjà reçu.
  Future<void> _bindVoipTokenTo(String userId) async {
    if (!Platform.isIOS) return;
    final callService = NativeCallService.instance;
    callService.onVoipTokenUpdated = (token) {
      saveVoipTokenForUser(userId, token);
    };
    final existing = callService.voipToken;
    if (existing != null && existing.isNotEmpty) {
      await saveVoipTokenForUser(userId, existing);
    }
  }

  /// Save token to Supabase
  Future<void> _saveTokenToDatabase(String token, {String? userId}) async {
    final uid = userId ?? _lastKnownUserId;
    if (uid == null) return;
    try {
      // Sans session Supabase authentifiée, RLS bloque l'update de `users` :
      // le token n'était jamais enregistré → aucune notification push.
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final row = await Supabase.instance.client
          .from('users')
          .select('fcm_tokens')
          .eq('id', uid)
          .maybeSingle();
      final tokens = List<String>.from(row?['fcm_tokens'] as List? ?? []);
      if (!tokens.contains(token)) tokens.add(token);
      await Supabase.instance.client
          .from('users')
          .update({'fcm_tokens': tokens, 'last_token_update': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
    } catch (e) {
      debugPrint('Error saving FCM token to database: $e');
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeTokenForUser(String userId) async {
    // Sinon une reconnexion sur le même compte serait ignorée par la garde de
    // saveTokenForUser, et le jeton ne repartirait jamais en base.
    _tokenSyncedForUser = null;
    _lastKnownUserId = null;

    // Sans ça, un isolate background réveillé après déconnexion (réponse
    // rapide, confirmation de livraison) agirait encore sous l'identité de
    // l'utilisateur précédent.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserId');
      await prefs.remove('currentUserDisplayName');
      await prefs.remove('currentUserPhotoUrl');
    } catch (e) {
      debugPrint('NotificationService: clear currentUserId cache error: $e');
    }

    // Le jeton VoIP est nominatif lui aussi : le laisser en base ferait sonner
    // l'appareil pour l'ancien compte.
    if (Platform.isIOS) {
      NativeCallService.instance.onVoipTokenUpdated = null;
      await removeVoipTokenForUser(userId);
    }
    if (_fcmToken == null) return;
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final row = await Supabase.instance.client
          .from('users')
          .select('fcm_tokens')
          .eq('id', userId)
          .maybeSingle();
      final tokens = List<String>.from(row?['fcm_tokens'] as List? ?? [])
        ..remove(_fcmToken);
      await Supabase.instance.client
          .from('users')
          .update({'fcm_tokens': tokens})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error removing FCM token from database: $e');
    }
  }

  /// Save VoIP push token for iOS (for CallKit incoming calls)
  Future<void> saveVoipTokenForUser(String userId, String voipToken) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await Supabase.instance.client
          .from('users')
          .update({'voip_token': voipToken, 'last_token_update': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error saving VoIP token: $e');
    }
  }

  /// Remove VoIP token when user logs out
  Future<void> removeVoipTokenForUser(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'voip_token': null})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error removing VoIP token: $e');
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

    final data = message.data;
    final type = data['type'];

    // Handle incoming call notifications specially
    if (type == 'incoming_call') {
      _handleIncomingCallNotification(data);
      return; // Don't show standard notification for calls
    }

    // Handle call status updates
    if (type == 'call_status') {
      _handleCallStatusNotification(data);
      return;
    }

    // Handle notification dismiss from other devices (multi-device sync)
    if (type == 'notification_dismiss') {
      await _handleNotificationDismiss(data);
      return;
    }

    // Confirm delivery for message notifications
    if (type == 'message') {
      await _confirmMessageDelivery(
        conversationId: data['conversationId'],
        messageId: data['messageId'],
      );

      // Check if this is for the currently open conversation
      final conversationId = data['conversationId'] as String?;
      if (conversationId != null &&
          conversationId == _currentOpenConversationId) {
        // Don't show any notification - message will appear directly in the conversation
        // debugPrint('Skipping notification - conversation is already open');
        return;
      }
    }

    // Volontairement AUCUNE écriture en base ici : la ligne `notifications` est
    // créée côté serveur AVANT le push (c'est son INSERT qui déclenche le
    // trigger -> send-push). Ré-insérer ici créerait un doublon dans la cloche
    // in-app, et surtout une boucle infinie (insert -> trigger -> push ->
    // insert -> ...). Le foreground se contente d'AFFICHER.

    // Check if notification should be shown based on user preferences
    final shouldShow = await _shouldShowNotification(type);
    // debugPrint('Should show notification: $shouldShow');

    if (shouldShow) {
      // For message notifications in foreground, try to show in-app banner first
      if (type == 'message' && _inAppNotificationCallback != null) {
        final showedBanner = _inAppNotificationCallback!(data);
        if (showedBanner) {
          // Banner was shown, don't show system notification
          // debugPrint('In-app banner shown, skipping system notification');
          return;
        }
      }

      // Show local notification (system notification)
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

  /// Handle incoming call notification
  void _handleIncomingCallNotification(Map<String, dynamic> data) {
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String?;
    final callerPhotoUrl = data['callerPhotoUrl'] as String?;
    final callType = data['callType'] as String?;

    if (callId == null || callerId == null) return;

    if (_incomingCallCallback != null) {
      _incomingCallCallback!(
        callId: callId,
        callerId: callerId,
        callerName: callerName ?? _getLocalizedString('unknown'),
        callerPhotoUrl: callerPhotoUrl,
        isVideo: callType == 'video',
      );
    }
  }

  /// Handle call status notification (declined, missed, etc.)
  void _handleCallStatusNotification(Map<String, dynamic> data) {
    final callId = data['callId'] as String?;
    final status = data['status'] as String?;

    if (callId == null || status == null) return;

    if (_callStatusCallback != null) {
      _callStatusCallback!(callId: callId, status: status);
    }
  }

  /// Handle notification dismiss from another device (multi-device sync)
  /// When a user reads a message/notification on one device, this clears
  /// the local notification on all other devices.
  Future<void> _handleNotificationDismiss(Map<String, dynamic> data) async {
    final notificationType = data['notificationType'] as String?;
    final conversationId = data['conversationId'] as String?;
    final targetId = data['targetId'] as String?;

    debugPrint(
      'NotificationService: Received dismiss sync - type: $notificationType, conversationId: $conversationId',
    );

    try {
      if (notificationType == 'message' && conversationId != null) {
        // Clear all notifications for this conversation
        await clearConversationNotifications(conversationId);
        debugPrint(
          'NotificationService: Cleared notifications for conversation $conversationId',
        );
      } else if (targetId != null) {
        // For other notification types, try to clear by targetId
        // The notification ID is typically based on the targetId hash
        await _localNotifications.cancel(targetId.hashCode);
        debugPrint(
          'NotificationService: Cancelled notification for targetId $targetId',
        );
      }

      // Also update app badge count
      await _updateAppBadge();
    } catch (e) {
      debugPrint('NotificationService: Error handling dismiss sync: $e');
    }
  }

  /// Update app badge count based on unread notifications
  Future<void> _updateAppBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId != null) {
        await refreshAppBadge(userId);
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if notification should be shown based on user preferences
  Future<bool> _shouldShowNotification(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Interrupteur maître : coupe toutes les notifications.
      if (!(prefs.getBool('notifications_enabled') ?? true)) return false;

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
        case 'audioRoomReminder':
        case 'audioRoomLive':
        case 'audioRoomInvite':
        case 'audioRoomSpeakerRequest':
        case 'audioRoomEnded':
          return prefs.getBool('notify_audio_room_reminders') ?? true;
        case 'podcastNewEpisode':
        case 'podcastLiveStarting':
        case 'podcastLiveNow':
          return prefs.getBool('notify_podcast_episodes') ?? true;
        case 'transferReminder':
        case 'transferCompleted':
        case 'transferReceived':
        case 'transferFailed':
          return prefs.getBool('notify_transfer_reminders') ?? true;
        case 'missedCall':
          return prefs.getBool('notify_calls') ?? true;
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

  /// Show local notification avec groupement style WhatsApp et MessagingStyle
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = data['type'] as String?;

    // Get title and body from notification or fallback to data payload
    final title =
        notification?.title ?? data['title'] ?? 'Nouvelle notification';
    var body = notification?.body ?? data['body'] ?? '';

    // Récupérer les infos de l'expéditeur pour MessagingStyle
    final senderName = data['senderName'] as String? ?? title;
    final senderPhotoUrl = data['senderPhotoUrl'] as String?;
    final senderId = data['senderId'] as String? ?? '';
    final conversationType = data['conversationType'] as String?;
    final messageType = data['messageType'] as String? ?? 'text';
    final conversationId = data['conversationId'] as String?;
    final conversationTitle = data['conversationTitle'] as String?;
    final conversationPhotoUrl = data['conversationPhotoUrl'] as String?;
    final isGroup = conversationType == 'group';

    // Pour les messages E2EE, tenter de déchiffrer le contenu au premier plan
    final isE2EE = data['isE2EE'] == 'true';
    if (isE2EE && _e2eeDecryptionCallback != null && type == 'message') {
      final cryptoPayload =
          NotificationDecryptionService.cryptoPayloadFromFcmData(data);

      if (cryptoPayload.isNotEmpty) {
        try {
          body = await _e2eeDecryptionCallback!(
            senderId,
            cryptoPayload,
            messageType,
          );
        } catch (e) {
          // En cas d'erreur, garder le body générique de FCM
        }
      }
    }

    // Skip if no content to show
    if (title.isEmpty && body.isEmpty) {
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
    }

    // Generate unique notification ID basé sur la conversation pour regrouper
    final notificationId =
        conversationId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Générer automatiquement le groupKey style WhatsApp
    final groupKey = _generateGroupKey(type, data);
    final targetId = data['targetId'] as String?;

    // Ajouter au cache des groupes actifs
    _addToActiveGroup(
      groupKey: groupKey,
      type: type ?? 'general',
      targetId: targetId,
      conversationTitle: isGroup ? conversationTitle : senderName,
      conversationPhotoUrl: isGroup ? conversationPhotoUrl : senderPhotoUrl,
      isGroup: isGroup,
      notification: ActiveNotification(
        id: notificationId,
        title: title,
        body: body,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        timestamp: DateTime.now(),
        messageType: messageType,
      ),
    );

    // Construire les détails Android avec MessagingStyle pour les messages
    final isMessageNotification = type == 'message' && conversationId != null;

    // Actions de notification pour les messages (répondre, marquer comme lu)
    final List<AndroidNotificationAction> androidActions =
        isMessageNotification && kNotificationQuickActionsEnabled
            ? [
              AndroidNotificationAction(
                kReplyActionId,
                _getLocalizedString('reply'),
                icon: const DrawableResourceAndroidBitmap('@drawable/ic_reply'),
                showsUserInterface: false,
                inputs: <AndroidNotificationActionInput>[
                  AndroidNotificationActionInput(
                    label: _getLocalizedString('type_reply'),
                    allowFreeFormInput: true,
                  ),
                ],
              ),
              AndroidNotificationAction(
                kMarkReadActionId,
                _getLocalizedString('mark_read'),
                icon: const DrawableResourceAndroidBitmap(
                  '@drawable/ic_mark_read',
                ),
                showsUserInterface: false,
              ),
            ]
            : [];

    // Préparer le StyleInformation selon le type
    StyleInformation? styleInformation;

    if (isMessageNotification) {
      // Utiliser MessagingStyle pour les messages (style WhatsApp)
      styleInformation = await _buildMessagingStyle(
        groupKey: groupKey,
        isGroup: isGroup,
        conversationTitle: isGroup ? (conversationTitle ?? title) : null,
      );
    } else if (_hasImageAttachment(messageType, data)) {
      // Utiliser BigPictureStyle pour les images
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null) {
        styleInformation = await _buildBigPictureStyle(imageUrl, body);
      }
    }

    // Couleur LED selon le type
    final ledColor = _getLedColorForType(type);

    // Pattern de vibration personnalisé
    final vibrationPattern = _getVibrationPattern(type);

    // Afficher la notification avec MessagingStyle
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
          icon: '@drawable/ic_stat_notification',
          color: AppColors.primary,
          colorized: true,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
          vibrationPattern: vibrationEnabled ? vibrationPattern : null,
          enableLights: true,
          ledColor: ledColor,
          ledOnMs: 1000,
          ledOffMs: 500,
          groupKey: groupKey,
          setAsGroupSummary: false,
          styleInformation: styleInformation,
          actions: androidActions,
          category:
              isMessageNotification
                  ? AndroidNotificationCategory.message
                  : AndroidNotificationCategory.social,
          visibility: NotificationVisibility.private,
          showWhen: true,
          when: DateTime.now().millisecondsSinceEpoch,
          usesChronometer: false,
          autoCancel: true,
          onlyAlertOnce: false,
          showProgress: false,
          ticker: body,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
          threadIdentifier: groupKey,
          categoryIdentifier: isMessageNotification ? 'message_category' : null,
          interruptionLevel:
              importance == Importance.high
                  ? InterruptionLevel.timeSensitive
                  : InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode(data),
    );

    // Sauvegarder l'ID de notification pour pouvoir l'annuler depuis le background
    if (isMessageNotification) {
      await _saveNotificationIdForConversation(conversationId, notificationId);
    }

    // Afficher/mettre à jour la notification de résumé (style WhatsApp)
    await _showGroupSummaryNotification(
      groupKey: groupKey,
      type: type,
      channelId: channelId,
      channelName: channelName,
      importance: importance,
      soundEnabled: false,
      vibrationEnabled: false,
    );
  }

  /// Construit le MessagingStyle avec l'historique des messages
  Future<MessagingStyleInformation> _buildMessagingStyle({
    required String groupKey,
    required bool isGroup,
    String? conversationTitle,
  }) async {
    final group = _activeGroups[groupKey];
    final messages = <Message>[];

    if (group != null) {
      for (final notification in group.notifications.take(10)) {
        // Créer la Person pour l'expéditeur
        final person = await _getOrCreatePerson(
          name: notification.senderName ?? 'Utilisateur',
          uniqueKey: notification.senderName ?? 'unknown',
          photoUrl: notification.senderPhotoUrl,
        );

        // Adapter le texte selon le type de message
        final messageText = _formatMessagePreview(
          notification.body,
          notification.messageType,
        );

        messages.add(Message(messageText, notification.timestamp, person));
      }
    }

    // Person "moi" pour la conversation
    const me = Person(name: 'Moi', key: 'me');

    return MessagingStyleInformation(
      me,
      messages: messages.reversed.toList(), // Plus récents en premier
      conversationTitle: isGroup ? conversationTitle : null,
      groupConversation: isGroup,
    );
  }

  /// Formate l'aperçu du message selon son type
  String _formatMessagePreview(String body, String? messageType) {
    switch (messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Vidéo';
      case 'voiceNote':
      case 'audio':
        return '🎙️ Message vocal';
      case 'audioFile':
        return '🎵 Audio';
      case 'document':
      case 'file':
        return '📄 Document';
      case 'location':
        return '📍 Position';
      case 'contact':
        return '👤 Contact';
      case 'sticker':
        return '🎨 Sticker';
      default:
        return body;
    }
  }

  /// Vérifie si le message contient une image
  bool _hasImageAttachment(String? messageType, Map<String, dynamic> data) {
    return messageType == 'image' && data['imageUrl'] != null;
  }

  /// Construit BigPictureStyle pour les notifications avec images
  Future<BigPictureStyleInformation?> _buildBigPictureStyle(
    String imageUrl,
    String body,
  ) async {
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/notif_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        return BigPictureStyleInformation(
          FilePathAndroidBitmap(filePath),
          contentTitle: body,
          summaryText: '📷 Photo',
          hideExpandedLargeIcon: true,
        );
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Génère un groupKey automatique basé sur le type et la cible
  String _generateGroupKey(String? type, Map<String, dynamic> data) {
    final targetId = data['targetId'] as String? ?? '';
    final conversationId = data['conversationId'] as String?;
    final senderId = data['senderId'] as String?;

    switch (type) {
      case 'message':
        // Grouper par conversation (comme WhatsApp)
        final id = conversationId ?? senderId ?? targetId;
        return '$_messageGroupPrefix$id';
      case 'groupInvite':
      case 'groupJoinRequest':
      case 'groupRequestApproved':
      case 'groupRequestRejected':
      case 'newMember':
        return '$_groupGroupPrefix$targetId';
      case 'eventUpdate':
      case 'eventReminder':
      case 'eventAttendance':
        return '$_eventGroupPrefix$targetId';
      case 'friendRequest':
      case 'friendRequestAccepted':
      case 'friendAccepted':
      case 'newFollower':
        return '${_friendGroupPrefix}requests';
      case 'newOrder':
      case 'orderPaid':
      case 'orderShipped':
      case 'orderDelivered':
      case 'orderCancelled':
      case 'orderCompleted':
        return '$_orderGroupPrefix$targetId';
      default:
        return 'general_notifications';
    }
  }

  /// Ajoute une notification au groupe actif
  void _addToActiveGroup({
    required String groupKey,
    required String type,
    String? targetId,
    String? conversationTitle,
    String? conversationPhotoUrl,
    bool isGroup = false,
    required ActiveNotification notification,
  }) {
    if (_activeGroups.containsKey(groupKey)) {
      _activeGroups[groupKey]!.notifications.add(notification);
    } else {
      _activeGroups[groupKey] = NotificationGroup(
        groupKey: groupKey,
        type: type,
        targetId: targetId,
        conversationTitle: conversationTitle,
        conversationPhotoUrl: conversationPhotoUrl,
        isGroup: isGroup,
        notifications: [notification],
      );
    }
  }

  /// Affiche la notification de résumé du groupe (style WhatsApp)
  Future<void> _showGroupSummaryNotification({
    required String groupKey,
    String? type,
    required String channelId,
    required String channelName,
    required Importance importance,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    final group = _activeGroups[groupKey];
    if (group == null || group.count < 2) {
      // Pas besoin de résumé pour une seule notification
      return;
    }

    final summaryId = _getSummaryIdForType(type);
    final (summaryTitle, summaryBody) = _buildSummaryText(group);

    // Construire les lignes pour InboxStyle (comme WhatsApp)
    final inboxLines =
        group.notifications
            .take(7) // Max 7 lignes visibles (comme WhatsApp)
            .map((n) {
              final preview = _formatMessagePreview(n.body, n.messageType);
              return '${n.senderName}: $preview';
            })
            .toList();

    // Couleur LED selon le type
    final ledColor = _getLedColorForType(type);

    await _localNotifications.show(
      summaryId,
      summaryTitle,
      summaryBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Résumé pour $channelName',
          importance: importance,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
          color: AppColors.primary,
          colorized: true,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
          enableLights: true,
          ledColor: ledColor,
          groupKey: groupKey,
          setAsGroupSummary: true,
          styleInformation: InboxStyleInformation(
            inboxLines,
            contentTitle: summaryTitle,
            summaryText: summaryBody,
            htmlFormatLines: false,
            htmlFormatContentTitle: false,
            htmlFormatSummaryText: false,
          ),
          category:
              type == 'message'
                  ? AndroidNotificationCategory.message
                  : AndroidNotificationCategory.social,
          visibility: NotificationVisibility.private,
          showWhen: true,
          when: group.notifications.last.timestamp.millisecondsSinceEpoch,
          number: group.count,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
          threadIdentifier: groupKey,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  /// Retourne l'ID de résumé pour un type donné
  int _getSummaryIdForType(String? type) {
    switch (type) {
      case 'message':
        return _messageSummaryId;
      case 'groupInvite':
      case 'groupJoinRequest':
      case 'groupRequestApproved':
      case 'groupRequestRejected':
      case 'newMember':
        return _groupSummaryId;
      case 'eventUpdate':
      case 'eventReminder':
      case 'eventAttendance':
        return _eventSummaryId;
      case 'friendRequest':
      case 'friendRequestAccepted':
      case 'friendAccepted':
      case 'newFollower':
        return _friendSummaryId;
      case 'newOrder':
      case 'orderPaid':
      case 'orderShipped':
      case 'orderDelivered':
      case 'orderCancelled':
      case 'orderCompleted':
        return _orderSummaryId;
      default:
        return 99999;
    }
  }

  /// Construit le texte de résumé style WhatsApp
  (String title, String body) _buildSummaryText(NotificationGroup group) {
    final count = group.count;
    final type = group.type;

    switch (type) {
      case 'message':
        // Style WhatsApp: "X nouveaux messages"
        final senders =
            group.notifications.map((n) => n.senderName).toSet().toList();
        if (senders.length == 1) {
          return (senders.first ?? 'Messages', '$count nouveaux messages');
        } else {
          return (
            'Diaspo Niger',
            '$count messages de ${senders.length} conversations',
          );
        }
      case 'groupInvite':
      case 'groupJoinRequest':
      case 'groupRequestApproved':
      case 'groupRequestRejected':
      case 'newMember':
        return ('Groupes', '$count notifications de groupe');
      case 'eventUpdate':
      case 'eventReminder':
      case 'eventAttendance':
        return ('Événements', '$count notifications d\'événement');
      case 'friendRequest':
      case 'friendRequestAccepted':
      case 'friendAccepted':
      case 'newFollower':
        return ('Amis', '$count demandes d\'ami');
      case 'newOrder':
      case 'orderPaid':
      case 'orderShipped':
      case 'orderDelivered':
      case 'orderCancelled':
      case 'orderCompleted':
        return ('Commandes', '$count mises à jour de commande');
      default:
        return ('Diaspo Niger', '$count nouvelles notifications');
    }
  }

  /// Efface le cache des groupes actifs (à appeler quand l'app est ouverte)
  void clearActiveGroups() {
    _activeGroups.clear();
  }

  /// Efface tous les caches (avatars, persons, groupes)
  Future<void> clearAllCaches() async {
    _activeGroups.clear();
    _personCache.clear();

    // Supprimer les fichiers d'avatar cachés
    for (final path in _avatarPathCache.values) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _avatarPathCache.clear();
  }

  /// Nettoie les fichiers d'avatar obsolètes (plus de 24h)
  Future<void> cleanupOldAvatarCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      final now = DateTime.now();

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains('notification_avatar_')) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age.inHours > 24) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }

  /// Sauvegarde l'ID de notification pour une conversation (pour annulation depuis le background)
  Future<void> _saveNotificationIdForConversation(
    String conversationId,
    int notificationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notification_ids_$conversationId';
      final existingJson = prefs.getString(key);

      List<int> ids = [];
      if (existingJson != null) {
        ids = (jsonDecode(existingJson) as List).cast<int>();
      }

      if (!ids.contains(notificationId)) {
        ids.add(notificationId);
        await prefs.setString(key, jsonEncode(ids));
      }
    } catch (_) {}
  }

  /// Efface un groupe spécifique (quand l'utilisateur ouvre une conversation)
  Future<void> clearGroupNotifications(String groupKey) async {
    final group = _activeGroups[groupKey];
    if (group != null) {
      // Annuler toutes les notifications du groupe
      for (final notification in group.notifications) {
        await _localNotifications.cancel(notification.id);
      }
      // Annuler le résumé
      final summaryId = _getSummaryIdForType(group.type);
      await _localNotifications.cancel(summaryId);
      // Supprimer du cache
      _activeGroups.remove(groupKey);
    }
  }

  /// Efface les notifications de messages pour une conversation spécifique
  Future<void> clearConversationNotifications(String conversationId) async {
    await clearGroupNotifications('$_messageGroupPrefix$conversationId');
    // Nettoyer les IDs sauvegardés
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_ids_$conversationId');
    } catch (_) {}
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
      case 'audioRoomReminder':
      case 'audioRoomLive':
      case 'audioRoomInvite':
      case 'audioRoomSpeakerRequest':
      case 'audioRoomEnded':
        return (
          'audio_rooms_reminders_channel',
          'Audio Room Reminders',
          Importance.high,
        );
      case 'podcastNewEpisode':
      case 'podcastLiveStarting':
      case 'podcastLiveNow':
        return (
          'podcast_reminders_channel',
          'Podcast Episodes',
          Importance.defaultImportance,
        );
      case 'transferReminder':
      case 'transferCompleted':
      case 'transferReceived':
      case 'transferFailed':
        return (
          'transfer_reminders_channel',
          'Transfer Reminders',
          Importance.high,
        );
      case 'missedCall':
        return ('calls_channel', 'Appels', Importance.max);
      case 'newOrder':
      case 'orderPaid':
      case 'orderShipped':
      case 'orderDelivered':
      case 'orderCancelled':
        return ('orders_channel', 'Orders', Importance.high);
      case 'incoming_call':
      case 'call_status':
        return ('calls_channel', 'Appels', Importance.max);
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

  // Callbacks pour les actions de notification (réponse directe, marquer comme lu)
  void Function(String conversationId, String replyText)? _directReplyCallback;
  void Function(String conversationId)? _markAsReadCallback;

  // Callback pour le déchiffrement E2EE des notifications (foreground uniquement)
  Future<String> Function(
    String senderId,
    Map<String, dynamic> cryptoPayload,
    String messageType,
  )?
  _e2eeDecryptionCallback;

  // Callbacks pour les appels entrants
  void Function({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
  })?
  _incomingCallCallback;

  void Function({required String callId, required String status})?
  _callStatusCallback;

  // Callback pour les notifications in-app (foreground)
  // Retourne true si la notification a été affichée en tant que banner
  bool Function(Map<String, dynamic> data)? _inAppNotificationCallback;

  // ID de la conversation actuellement ouverte (pour filtrer les notifications)
  String? _currentOpenConversationId;

  /// Définir la conversation actuellement ouverte
  /// Les notifications pour cette conversation ne déclencheront pas de banner
  void setCurrentConversation(String? conversationId) {
    _currentOpenConversationId = conversationId;
    // Si on ouvre une conversation, effacer ses notifications
    if (conversationId != null) {
      clearConversationNotifications(conversationId);
    }
  }

  /// Obtenir l'ID de la conversation actuellement ouverte
  String? get currentOpenConversationId => _currentOpenConversationId;

  /// Définit le callback pour les notifications in-app
  /// Ce callback est appelé pour les messages en foreground quand l'utilisateur
  /// n'est pas dans la conversation concernée.
  /// Le callback doit retourner true s'il a affiché un banner, false sinon.
  void setInAppNotificationCallback(
    bool Function(Map<String, dynamic> data) callback,
  ) {
    _inAppNotificationCallback = callback;
  }

  /// Définit le callback pour les réponses directes depuis les notifications
  void setDirectReplyCallback(
    void Function(String conversationId, String replyText) callback,
  ) {
    _directReplyCallback = callback;
  }

  /// Définit le callback pour marquer comme lu depuis les notifications
  void setMarkAsReadCallback(void Function(String conversationId) callback) {
    _markAsReadCallback = callback;
  }

  /// Définit le callback pour déchiffrer les notifications E2EE (foreground)
  ///
  /// Ce callback est appelé quand une notification E2EE arrive au premier plan.
  /// Il reçoit: senderId, cryptoPayload (e2eePayloads/e2eePayload/senderKeyPayload), messageType
  /// Il retourne: le texte déchiffré ou un fallback générique
  void setE2EEDecryptionCallback(
    Future<String> Function(
      String senderId,
      Map<String, dynamic> cryptoPayload,
      String messageType,
    )
    callback,
  ) {
    _e2eeDecryptionCallback = callback;
  }

  /// Définit le callback pour les appels entrants
  ///
  /// Ce callback est appelé quand une notification d'appel entrant arrive.
  /// Il doit afficher l'écran/overlay d'appel entrant.
  void setIncomingCallCallback(
    void Function({
      required String callId,
      required String callerId,
      required String callerName,
      String? callerPhotoUrl,
      required bool isVideo,
    })
    callback,
  ) {
    _incomingCallCallback = callback;
  }

  /// Définit le callback pour les changements de statut d'appel
  ///
  /// Ce callback est appelé quand le statut d'un appel change (refusé, manqué, etc.)
  void setCallStatusCallback(
    void Function({required String callId, required String status}) callback,
  ) {
    _callStatusCallback = callback;
  }

  /// Gère les réponses aux notifications (foreground)
  void _handleNotificationResponse(NotificationResponse details) {
    final actionId = details.actionId;
    final payload = details.payload;
    final input = details.input;

    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'] as String?;
        final targetId = data['targetId'] as String? ?? '';
        final conversationId = data['conversationId'] as String?;

        // Gestion de l'action "Répondre"
        if (actionId == kReplyActionId &&
            input != null &&
            input.isNotEmpty &&
            conversationId != null) {
          _handleDirectReply(conversationId, input);
          return;
        }

        // Gestion de l'action "Marquer comme lu"
        if (actionId == kMarkReadActionId && conversationId != null) {
          _handleMarkAsRead(conversationId);
          return;
        }

        // Gestion du tap normal (pas d'action spécifique)
        if (actionId == null || actionId.isEmpty) {
          if (type != null) {
            if (_notificationTapCallback != null) {
              _notificationTapCallback!.call(type, targetId, data);
            } else {
              _pendingNotificationTap = (
                type: type,
                targetId: targetId,
                data: data,
              );
            }
          }
          return;
        }

        // Un actionId connu (reply/mark-read) est arrivé jusqu'ici sans
        // matcher un des blocs ci-dessus (conversationId absent du payload,
        // ou input vide) : sans log, ce cas se referme en silence — la
        // notification reste bloquée sur son indicateur d'envoi côté Android
        // puisque personne n'appelle jamais sendReply/markAsRead ni ne
        // referme la notification. Vécu sur SM A515F le 2026-08-13.
        debugPrint(
          'NotificationService: action "$actionId" non traitée — '
          'conversationId=$conversationId input="${input ?? ''}"',
        );
      } catch (e) {
        debugPrint('NotificationService: erreur parsing payload notification: $e');
      }
    } else if (actionId != null && actionId.isNotEmpty) {
      debugPrint(
        'NotificationService: action "$actionId" reçue sans payload — impossible de router',
      );
    }
  }

  /// Traite une réponse directe
  void _handleDirectReply(String conversationId, String replyText) {
    if (_directReplyCallback != null) {
      _directReplyCallback!(conversationId, replyText);
    } else {
      // Fallback: utiliser le service background si pas de callback
      BackgroundReplyService.sendReply(
        conversationId: conversationId,
        replyText: replyText,
      );
    }
  }

  /// Traite une action "marquer comme lu"
  void _handleMarkAsRead(String conversationId) {
    if (_markAsReadCallback != null) {
      _markAsReadCallback!(conversationId);
    } else {
      // Fallback: utiliser le service background
      BackgroundReplyService.markAsRead(conversationId: conversationId);
    }
    // Effacer les notifications de cette conversation
    clearConversationNotifications(conversationId);
  }

  /// Confirm message delivery to Supabase (single source of truth).
  Future<void> _confirmMessageDelivery({
    required String? conversationId,
    required String? messageId,
  }) async {
    if (conversationId == null || messageId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId == null) return;

      await Supabase.instance.client.rpc('mark_messages_as_delivered', params: {
        'p_conversation_id': conversationId,
        'p_user_id': userId,
      });
    } catch (e) {
      // Silently fail - delivery confirmation is best effort
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
      // Passe par le RPC SECURITY DEFINER : un INSERT direct est bloqué par la
      // RLS notifications_own (firebase_uid() = user_id) dès que le destinataire
      // n'est pas l'appelant — c.-à-d. pour TOUTES les notifs entre utilisateurs.
      // Le RPC contourne la RLS après avoir validé l'appelant et le destinataire.
      await Supabase.instance.client.rpc('create_user_notification', params: {
        'p_user_id': userId,
        'p_type': type,
        'p_title': title,
        'p_body': body,
        'p_data': {...?data, 'target_id': targetId},
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  /// Show proximity notification
  Future<void> showProximityNotification(int count) async {
    await _localNotifications.show(
      0, // ID 0 for generic proximity alert (replaces previous one)
      'Membres à proximité',
      '$count membres de la diaspora sont à moins de 5km de vous',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'proximity_channel', // id
          'Proximity Notifications', // title
          channelDescription: 'Notifications for nearby members',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
          color: AppColors.primary,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a simple local notification (for message failures, etc.)
  Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
          channelDescription: 'Notifications generales de l\'application',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Abonnement à un topic FCM.
  ///
  /// ⚠️ **Aucun back-end n'émet vers un topic aujourd'hui** : ni
  /// `functions/index.js`, ni `functions/supabase.js`, ni l'Edge Function
  /// send-push, qui ne vise que des tokens individuels. Les trois appelants
  /// historiques (`general` de l'interrupteur maître, `group_<id>` à
  /// l'adhésion, le topic d'événement de « M'avertir du prochain ») ont été
  /// retirés : ils promettaient des notifications que personne n'envoyait.
  ///
  /// Ces deux méthodes restent en place pour le jour où un émetteur existera.
  /// Ne pas les rebrancher avant d'avoir écrit le côté serveur.
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

  // ================== APP ICON BADGE MANAGEMENT ==================

  /// Clear the app icon badge (cross-platform)
  /// Call this when the user opens the app or marks all messages as read.
  Future<void> clearAppBadge() async {
    try {
      // Check if badge is supported on this device
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      // Silently fail - badge is not critical
    }
  }

  /// Update the app icon badge count (cross-platform)
  /// Call this to set a specific badge count (e.g., total unread messages).
  /// Note: On Android, badge support depends on the launcher.
  Future<void> updateAppBadge(int count) async {
    try {
      // Check if badge is supported on this device
      final isSupported = await AppBadgePlus.isSupported();
      if (!isSupported) return;

      if (count <= 0) {
        await AppBadgePlus.updateBadge(0);
      } else {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (e) {
      // Silently fail - badge is not critical
    }
  }

  /// Get the total unread count for badge display
  /// Returns the sum of all unread messages across all conversations.
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('conversations')
          .select('data')
          .contains('participant_ids', [userId]);

      int totalUnread = 0;
      for (final row in rows as List) {
        final data = row['data'] as Map<String, dynamic>? ?? {};
        final unreadCount = data['unreadCount'] as Map<String, dynamic>? ?? {};
        final userUnread = unreadCount[userId];
        if (userUnread is int) totalUnread += userUnread;
      }
      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  /// Update badge based on current unread count
  /// Call this when the app state changes (e.g., message read, app resumed).
  Future<void> refreshAppBadge(String userId) async {
    final count = await getTotalUnreadCount(userId);
    await updateAppBadge(count);
  }
}
