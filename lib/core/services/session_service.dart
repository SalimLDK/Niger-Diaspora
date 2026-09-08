import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';
import 'preferences_service.dart';

/// Enforces single concurrent session rule.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  static SessionService get instance => _instance;

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  String? _currentSessionId;
  bool _isListening = false;

  /// Déconnexion complète, fournie par `AuthNotifier`. Rend `true` si elle a
  /// pris la main.
  ///
  /// Sans elle, la déconnexion forcée ci-dessous ne faisait que signer la
  /// sortie de Firebase : les caches Hive, les préférences personnelles
  /// (brouillons, hashtags suivis), les pièces jointes en clair et le jeton
  /// FCM restaient en place. Le compte suivant sur ce téléphone en héritait,
  /// et l'appareil continuait de recevoir les notifications du précédent —
  /// exactement ce que le chemin normal prend soin de nettoyer.
  ///
  /// Elle laisse aussi `AuthState` sur `authenticated` alors que Firebase est
  /// sorti : le garde du routeur (« si non authentifié → /auth/login ») ne
  /// voyait rien, seule la navigation explicite du bouton OK masquait
  /// l'incohérence.
  Future<bool> Function()? onForceLogout;

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

  /// Point d'entrée de test pour la déconnexion forcée.
  ///
  /// Le déclencheur réel est un instantané Firestore, hors de portée d'un test
  /// unitaire ; or ce qui doit être verrouillé est la décision prise ensuite —
  /// déléguer à la déconnexion complète, et retomber sur le repli si elle
  /// manque ou échoue.
  @visibleForTesting
  Future<void> forcerDeconnexionPourTest() => _handleForceLogout();

  Future<void> _handleForceLogout() async {
    dispose(); // Stop listening immediately

    // La déconnexion complète est celle d'`AuthNotifier` : même purge, même
    // retrait du jeton FCM, même bascule d'état que le bouton « Déconnexion ».
    // La dupliquer ici garantissait qu'elle diverge — c'est cette duplication
    // qui avait laissé ce chemin sans nettoyage.
    var traite = false;
    final deconnexionComplete = onForceLogout;
    if (deconnexionComplete != null) {
      try {
        traite = await deconnexionComplete();
      } catch (e) {
        debugPrint('SessionService: deconnexion complete en echec: $e');
      }
    }
    // Repli : personne n'a branché la déconnexion complète (ou elle a échoué).
    // Mieux vaut une sortie incomplète que pas de sortie du tout.
    if (!traite) {
      try {
        await FirebaseAuth.instance.signOut();
        await PreferencesService.instance.clearSessionId();
      } catch (e) {
        debugPrint('SessionService: repli de deconnexion forcee en echec: $e');
      }
    }

    // Show dialog
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    // `of(context)` et non `of(context)!` comme ailleurs : on est appelé depuis
    // un écouteur de flux, où une levée ne remonterait nulle part. Sans
    // traductions, la sortie a déjà eu lieu — seule l'explication manque.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint('SessionService: traductions indisponibles, dialogue omis');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => PopScope(
            canPop: false, // Prevent dismissing by back button
            child: AlertDialog(
              title: Text(l10n.connectedElsewhere),
              content: Text(l10n.connectedElsewhereMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Navigate explicitly to login page
                    if (context.mounted) {
                      GoRouter.of(context).go('/auth/login');
                    }
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          ),
    );
  }

  void dispose() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _isListening = false;
    // La session est terminée : garder son identifiant ferait comparer le
    // prochain écouteur à celui d'un compte sorti.
    _currentSessionId = null;
  }
}
