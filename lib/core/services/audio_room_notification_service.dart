import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for displaying a persistent ongoing notification when the user
/// participates in an audio room (like Twitter Spaces / Clubhouse).
///
/// The notification is visible on the lock screen and in the notification shade,
/// with actions to mute/unmute and leave the room.
class AudioRoomNotificationService {
  static final AudioRoomNotificationService _instance =
      AudioRoomNotificationService._internal();
  factory AudioRoomNotificationService() => _instance;
  AudioRoomNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 900001;
  static const String _channelId = 'audio_room_active_channel';

  String? _currentRoomId;
  bool _isMuted = true;

  /// Whether a notification is currently shown.
  bool get isShowing => _currentRoomId != null;

  /// Show the ongoing audio room notification.
  Future<void> show({
    required String roomId,
    required String roomTitle,
    required String hostName,
    required int participantCount,
    required int speakerCount,
    bool isMuted = true,
  }) async {
    _currentRoomId = roomId;
    _isMuted = isMuted;

    await _showNotification(
      roomTitle: roomTitle,
      hostName: hostName,
      participantCount: participantCount,
      speakerCount: speakerCount,
      isMuted: isMuted,
    );
  }

  /// Update the notification when mute state changes.
  Future<void> updateMuteState(bool isMuted) async {
    if (_currentRoomId == null) return;
    _isMuted = isMuted;
    await _showNotification(
      roomTitle: _lastRoomTitle,
      hostName: _lastHostName,
      participantCount: _lastParticipantCount,
      speakerCount: _lastSpeakerCount,
      isMuted: isMuted,
    );
  }

  /// Update participant count.
  Future<void> updateParticipants(int count) async {
    if (_currentRoomId == null) return;
    await _showNotification(
      roomTitle: _lastRoomTitle,
      hostName: _lastHostName,
      participantCount: count,
      speakerCount: _lastSpeakerCount,
      isMuted: _isMuted,
    );
  }

  /// Dismiss the notification (e.g. when user leaves the room).
  Future<void> dismiss() async {
    _currentRoomId = null;
    _lastRoomTitle = '';
    _lastHostName = '';
    _lastParticipantCount = 0;
    _lastSpeakerCount = 0;
    await _notifications.cancel(_notificationId);
  }

  // Cached values for updates
  String _lastRoomTitle = '';
  String _lastHostName = '';
  int _lastParticipantCount = 0;
  int _lastSpeakerCount = 0;

  Future<void> _showNotification({
    required String roomTitle,
    required String hostName,
    required int participantCount,
    required int speakerCount,
    required bool isMuted,
  }) async {
    _lastRoomTitle = roomTitle;
    _lastHostName = hostName;
    _lastParticipantCount = participantCount;
    _lastSpeakerCount = speakerCount;

    final muteAction = AndroidNotificationAction(
      isMuted ? 'unmute' : 'mute',
      isMuted ? '🔊 Activer' : '🔇 Couper',
      showsUserInterface: false,
    );

    const leaveAction = AndroidNotificationAction(
      'leave',
      '🚪 Quitter',
      showsUserInterface: false,
    );

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Salon Audio Actif',
      channelDescription:
          'Notification pendant la participation à un salon audio',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      actions: [muteAction, leaveAction],
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      '🎤 Salon Audio Actif',
      '🏷️ $roomTitle\n👤 $hostName · 👥 $participantCount auditeurs · 🎙️ $speakerCount speakers',
      notificationDetails,
      payload: 'audio_room_$_currentRoomId',
    );
  }
}
