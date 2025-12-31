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

  /// Check if user is currently authenticated and matches the expected userId
  bool _isUserAuthenticated([String? expectedUserId]) {
    final user = _auth.currentUser;
    if (user == null) {
      // debugPrint('⚠️ OnlineStatusService: User is not authenticated');
      return false;
    }
    // If expectedUserId is provided, verify it matches the current user
    if (expectedUserId != null && user.uid != expectedUserId) {
      // debugPrint('⚠️ OnlineStatusService: User ID mismatch - expected $expectedUserId but got ${user.uid}');
      return false;
    }
    return true;
  }

  /// Initialize the online status service
  Future<void> initialize() async {
    if (_initialized) {
      // debugPrint('⚠️ OnlineStatusService: Already initialized');
      return;
    }

    // debugPrint('🟢 OnlineStatusService: Initializing...');

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
    // debugPrint('✅ OnlineStatusService: Initialized successfully');
  }

  /// Setup presence tracking for a specific user
  Future<void> _setupPresenceForUser(String userId) async {
    // Validate authentication first
    if (!_isUserAuthenticated()) {
      // debugPrint(
      //   '❌ OnlineStatusService: Cannot setup presence - user not authenticated',
      // );
      return;
    }

    if (_currentUserId == userId) {
      // debugPrint('⚠️ OnlineStatusService: Already tracking user $userId');
      return;
    }

    // debugPrint('🔄 OnlineStatusService: Setting up presence for user $userId');

    // Teardown any existing presence
    await _teardownPresence();

    _currentUserId = userId;
    _presenceRef = _database.ref('presence/$userId');
    _connectedRef = _database.ref('.info/connected');

    try {
      // Check user's privacy preference
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final showOnlineStatus = userDoc.data()?['showOnlineStatus'] ?? true;

      if (!showOnlineStatus) {
        // debugPrint(
        //   '🔒 OnlineStatusService: User has disabled online status visibility',
        // );
        // Set as offline and don't track presence
        await _setOffline(userId);
        return;
      }

      // Listen to connection state
      _connectedSubscription = _connectedRef!.onValue.listen((event) async {
        final connected = event.snapshot.value as bool? ?? false;

        if (connected) {
          // debugPrint('🌐 OnlineStatusService: Connected to Firebase');
          await _setOnline(userId);

          // When disconnected, mark as offline
          try {
            await _presenceRef!.onDisconnect().set({
              'isOnline': false,
              'lastSeen': ServerValue.timestamp,
            });
          } catch (e) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              // debugPrint(
            //     '❌ OnlineStatusService: Permission denied setting disconnect handler. '
            //     'User may not be authenticated or Firebase rules may be incorrect.',
            // );
            } else {
              // debugPrint(
              //   '❌ OnlineStatusService: Error setting disconnect handler: $e',
              // );
            }
          }
        } else {
          // debugPrint('📴 OnlineStatusService: Disconnected from Firebase');
        }
      });
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        // debugPrint(
        //   '❌ OnlineStatusService: Permission denied in _setupPresenceForUser. '
        //   'Check Firebase Realtime Database rules and ensure user is authenticated.',
        // );
      } else {
        // debugPrint('❌ OnlineStatusService: Error setting up presence: $e');
      }
    }
  }

  /// Handle app lifecycle state changes
  void _handleLifecycleStateChange(AppLifecycleState state) {
    if (_currentUserId == null) return;

    // Validate authentication and user ID match before any lifecycle operations
    if (!_isUserAuthenticated(_currentUserId)) {
      // debugPrint(
      //   '⚠️ OnlineStatusService: Skipping lifecycle state change - '
      //   'user not authenticated or ID mismatch',
      // );
      return;
    }

    // debugPrint('🔄 OnlineStatusService: Lifecycle state changed to $state');

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

  Timer? _heartbeatTimer;

  /// Set user status to online
  Future<void> _setOnline(String userId) async {
    // Validate authentication and user ID match before any operations
    if (!_isUserAuthenticated(userId)) {
      // debugPrint(
      //   '❌ OnlineStatusService: Cannot set online - user not authenticated or ID mismatch',
      // );
      return;
    }

    // Null-safety check for presence reference
    if (_presenceRef == null) {
      // debugPrint(
      //   '⚠️ OnlineStatusService: Cannot set online - presence ref is null',
      // );
      return;
    }

    try {
      // Check privacy preference
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final showOnlineStatus = userDoc.data()?['showOnlineStatus'] ?? true;

      if (!showOnlineStatus) {
        // debugPrint(
        //   '🔒 OnlineStatusService: User privacy setting prevents online status',
        // );
        await _setOffline(userId);
        return;
      }

      // debugPrint('✅ OnlineStatusService: Setting user $userId to ONLINE');

      // Update Realtime Database
      await _presenceRef!.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // Also update Firestore for persistence
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Start heartbeat to keep lastSeen fresh in Firestore
      // (This fix preventing "ghosts" who crash and stay online in Firestore forever)
      _startHeartbeat(userId);
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        // debugPrint(
        //   '❌ OnlineStatusService: Permission denied when setting user online. '
        //   'User ID: $userId. Check Firebase Realtime Database rules and '
        //   'ensure user authentication token is valid.',
        // );
      } else {
        // debugPrint(
        //   '❌ OnlineStatusService: Error setting online for user $userId: $e',
        // );
      }
    }
  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    // Update lastSeen every 10 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (
      timer,
    ) async {
      try {
        await _firestore.collection('users').doc(userId).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
        // debugPrint('💓 OnlineStatusService: Heartbeat sent for $userId');
      } catch (e) {
        // debugPrint('❌ OnlineStatusService: Heartbeat failed: $e');
      }
    });
  }

  /// Set user status to offline
  Future<void> _setOffline(String userId) async {
    _heartbeatTimer?.cancel();

    // Validate authentication and user ID match before operations
    // During sign-out, we can't update Firestore anyway, so skip gracefully
    if (!_isUserAuthenticated(userId)) {
      // debugPrint(
      //   '⚠️ OnlineStatusService: Cannot set offline - user not authenticated or ID mismatch. '
      //   'This may be expected during sign-out.',
      // );
      // Only update RTDB if we have the ref (doesn't require auth in same way)
      try {
        await _database.ref('presence/$userId').set({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });
      } catch (_) {
        // Ignore RTDB errors during sign-out
      }
      return;
    }

    try {
      // debugPrint('⚫ OnlineStatusService: Setting user $userId to OFFLINE');

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
      if (e is FirebaseException && e.code == 'permission-denied') {
        // debugPrint(
        //   '❌ OnlineStatusService: Permission denied when setting user offline. '
        //   'User ID: $userId. This may be expected during sign-out or if '
        //   'authentication token has expired.',
        // );
      } else {
        // debugPrint(
        //   '❌ OnlineStatusService: Error setting offline for user $userId: $e',
        // );
      }
    }
  }

  /// Update user's online status visibility preference
  Future<void> updateOnlineStatusVisibility(bool showStatus) async {
    if (_currentUserId == null) return;

    // debugPrint(
    //   '🔄 OnlineStatusService: Updating status visibility to $showStatus',
    // );

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
      // debugPrint('❌ OnlineStatusService: Error updating visibility: $e');
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

    // debugPrint('🔄 OnlineStatusService: Presence tracking torn down');
  }

  /// Dispose of the service
  Future<void> dispose() async {
    // debugPrint('🔄 OnlineStatusService: Disposing...');

    await _teardownPresence();
    await _authStateSubscription?.cancel();
    _lifecycleListener?.dispose();

    _authStateSubscription = null;
    _lifecycleListener = null;
    _initialized = false;

    // debugPrint('✅ OnlineStatusService: Disposed');
  }
}
