import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/widgets.dart';

/// Service to manage user online/offline status (presence) using Firebase Realtime Database
class OnlineStatusService {
  static OnlineStatusService? _instance;
  static OnlineStatusService get instance {
    _instance ??= OnlineStatusService._();
    return _instance!;
  }

  OnlineStatusService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference? _presenceRef;
  DatabaseReference? _connectedRef;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  AppLifecycleListener? _lifecycleListener;

  bool _initialized = false;
  String? _currentUserId;

  /// Initialize the online status service
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ OnlineStatusService: Already initialized');
      return;
    }

    debugPrint('🟢 OnlineStatusService: Initializing...');

    // Listen to auth state changes
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _setupPresenceForUser(user.uid);
      } else {
        _teardownPresence();
      }
    });

    // Listen to app lifecycle changes
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleStateChange,
    );

    _initialized = true;
    debugPrint('✅ OnlineStatusService: Initialized successfully');
  }

  /// Setup presence tracking for a specific user
  Future<void> _setupPresenceForUser(String userId) async {
    if (_currentUserId == userId) {
      debugPrint('⚠️ OnlineStatusService: Already tracking user $userId');
      return;
    }

    debugPrint('🔄 OnlineStatusService: Setting up presence for user $userId');

    // Teardown any existing presence
    await _teardownPresence();

    _currentUserId = userId;
    _presenceRef = _database.ref('presence/$userId');
    _connectedRef = _database.ref('.info/connected');

    // Check user's privacy preference
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final showOnlineStatus = userDoc.data()?['showOnlineStatus'] ?? true;

    if (!showOnlineStatus) {
      debugPrint(
        '🔒 OnlineStatusService: User has disabled online status visibility',
      );
      // Set as offline and don't track presence
      await _setOffline(userId);
      return;
    }

    // Listen to connection state
    _connectedSubscription = _connectedRef!.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;

      if (connected) {
        debugPrint('🌐 OnlineStatusService: Connected to Firebase');
        await _setOnline(userId);

        // When disconnected, mark as offline
        await _presenceRef!.onDisconnect().set({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });
      } else {
        debugPrint('📴 OnlineStatusService: Disconnected from Firebase');
      }
    });
  }

  /// Handle app lifecycle state changes
  void _handleLifecycleStateChange(AppLifecycleState state) {
    if (_currentUserId == null) return;

    debugPrint('🔄 OnlineStatusService: Lifecycle state changed to $state');

    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // App is in foreground or transitioning
        _setOnline(_currentUserId!);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is in background or closing
        _setOffline(_currentUserId!);
        break;
    }
  }

  /// Set user status to online
  Future<void> _setOnline(String userId) async {
    try {
      // Check privacy preference
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final showOnlineStatus = userDoc.data()?['showOnlineStatus'] ?? true;

      if (!showOnlineStatus) {
        debugPrint(
          '🔒 OnlineStatusService: User privacy setting prevents online status',
        );
        await _setOffline(userId);
        return;
      }

      debugPrint('✅ OnlineStatusService: Setting user $userId to ONLINE');

      // Update Realtime Database
      await _presenceRef?.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // Also update Firestore for persistence
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ OnlineStatusService: Error setting online: $e');
    }
  }

  /// Set user status to offline
  Future<void> _setOffline(String userId) async {
    try {
      debugPrint('⚫ OnlineStatusService: Setting user $userId to OFFLINE');

      // Update Realtime Database
      await _database.ref('presence/$userId').set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      // Also update Firestore for persistence
      await _firestore.collection('users').doc(userId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ OnlineStatusService: Error setting offline: $e');
    }
  }

  /// Update user's online status visibility preference
  Future<void> updateOnlineStatusVisibility(bool showStatus) async {
    if (_currentUserId == null) return;

    debugPrint(
      '🔄 OnlineStatusService: Updating status visibility to $showStatus',
    );

    try {
      // Update Firestore
      await _firestore.collection('users').doc(_currentUserId).update({
        'showOnlineStatus': showStatus,
      });

      if (showStatus) {
        // Re-setup presence tracking
        await _setupPresenceForUser(_currentUserId!);
      } else {
        // Set to offline and stop tracking
        await _setOffline(_currentUserId!);
        await _connectedSubscription?.cancel();
        _connectedSubscription = null;
      }
    } catch (e) {
      debugPrint('❌ OnlineStatusService: Error updating visibility: $e');
    }
  }

  /// Get a stream of user's online status from Realtime Database
  Stream<bool> getUserOnlineStatus(String userId) {
    return _database.ref('presence/$userId/isOnline').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Get a stream of user's last seen timestamp from Realtime Database
  Stream<DateTime?> getUserLastSeen(String userId) {
    return _database.ref('presence/$userId/lastSeen').onValue.map((event) {
      final timestamp = event.snapshot.value;
      if (timestamp == null) return null;
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    });
  }

  /// Teardown presence tracking
  Future<void> _teardownPresence() async {
    if (_currentUserId != null) {
      await _setOffline(_currentUserId!);
    }

    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
    _presenceRef = null;
    _connectedRef = null;
    _currentUserId = null;

    debugPrint('🔄 OnlineStatusService: Presence tracking torn down');
  }

  /// Dispose of the service
  Future<void> dispose() async {
    debugPrint('🔄 OnlineStatusService: Disposing...');

    await _teardownPresence();
    await _authStateSubscription?.cancel();
    _lifecycleListener?.dispose();

    _authStateSubscription = null;
    _lifecycleListener = null;
    _initialized = false;

    debugPrint('✅ OnlineStatusService: Disposed');
  }
}
