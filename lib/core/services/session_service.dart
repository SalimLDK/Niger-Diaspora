import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../router/app_router.dart';
import 'preferences_service.dart';

/// Enforces single concurrent session rule.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  static SessionService get instance => _instance;

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  String? _currentSessionId;
  bool _isListening = false;

  SessionService._internal();

  /// Initialize session monitoring for a user.
  /// [isNewLogin] should be true if this is a fresh login action,
  /// causing a new session ID to be generated.
  Future<void> initialize(String userId, {bool isNewLogin = false}) async {
    if (_isListening) return;

    // Verify user authentication state
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // debugPrint(
      //   'SessionService: User not authenticated. Cannot initialize session.',
      // );
      return;
    }

    if (currentUser.uid != userId) {
      // debugPrint(
      //   'SessionService: User ID mismatch. Expected: $userId, Got: ${currentUser.uid}',
      // );
      return;
    }

    try {
      if (isNewLogin) {
        // Generate new session ID for fresh login
        _currentSessionId = const Uuid().v4();
        await PreferencesService.instance.setSessionId(_currentSessionId!);

        // Update Firestore with new session ID
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'session_id': _currentSessionId,
                'last_login': FieldValue.serverTimestamp(),
              });
          // debugPrint(
          //   'SessionService: Session initialized successfully for user: $userId',
          // );
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // debugPrint(
            //   'SessionService: Permission denied when updating session for user: $userId',
            // );
            // debugPrint('SessionService: Error details: ${e.message}');
            // Don't throw - allow app to continue without session tracking
          } else if (e.code == 'not-found') {
            // debugPrint(
            //   'SessionService: User document not found for user: $userId',
            // );
            // debugPrint(
            //   'SessionService: The user document may need to be created first.',
            // );
          } else {
            // debugPrint(
            //   'SessionService: Firestore error (${e.code}): ${e.message}',
            // );
          }
          // Clear session ID on error to prevent inconsistent state
          _currentSessionId = null;
          await PreferencesService.instance.clearSessionId();
          return;
        }
      } else {
        // App restart: load existing session ID
        _currentSessionId = PreferencesService.instance.sessionId;

        // If no local session ID exists tracking is impossible/irrelevant until next login
        // or we could force a new session?
        // Strategy: If missing, assume new session to self-heal.
        if (_currentSessionId == null) {
          _currentSessionId = const Uuid().v4();
          await PreferencesService.instance.setSessionId(_currentSessionId!);

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({'session_id': _currentSessionId});
            // debugPrint(
            //   'SessionService: Session ID regenerated for user: $userId',
            // );
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied') {
              // debugPrint(
              //   'SessionService: Permission denied when regenerating session for user: $userId',
              // );
              // debugPrint('SessionService: Error details: ${e.message}');
            } else if (e.code == 'not-found') {
              // debugPrint(
              //   'SessionService: User document not found for user: $userId',
              // );
            } else {
              // debugPrint(
              //   'SessionService: Firestore error (${e.code}): ${e.message}',
              // );
            }
            // Clear session ID on error
            _currentSessionId = null;
            await PreferencesService.instance.clearSessionId();
            return;
          }
        }
      }

      _startListening(userId);
    } catch (e) {
      // debugPrint('SessionService: Unexpected error during initialization: $e');
      // Clear session state on unexpected errors
      _currentSessionId = null;
      await PreferencesService.instance.clearSessionId();
    }
  }

  void _startListening(String userId) {
    _sessionSubscription?.cancel();
    _isListening = true;

    _sessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) return;

            final data = snapshot.data();
            if (data != null && data.containsKey('session_id')) {
              final remoteSessionId = data['session_id'] as String?;

              // precise check: if remote exists and differs from local -> logout
              if (remoteSessionId != null &&
                  remoteSessionId != _currentSessionId) {
                _handleForceLogout();
              }
            }
          },
          onError: (e) {
            // debugPrint('Session listener error: $e');
          },
        );
  }

  Future<void> _handleForceLogout() async {
    dispose(); // Stop listening immediately

    // Sign out from Firebase
    try {
      await FirebaseAuth.instance.signOut();
      await PreferencesService.instance.clearSessionId();
    } catch (e) {
      // debugPrint('Error during forced logout: $e');
    }

    // Show dialog
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => PopScope(
              canPop: false, // Prevent dismissing by back button
              child: AlertDialog(
                title: const Text('Connecté ailleurs'),
                content: const Text(
                  'Votre compte a été connecté sur un autre appareil. Vous avez été déconnecté de cet appareil pour sécurité.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      // Navigate explicitly to login page
                      if (context.mounted) {
                        GoRouter.of(context).go('/auth/login');
                      }
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
      );
    }
  }

  void dispose() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _isListening = false;
  }
}
