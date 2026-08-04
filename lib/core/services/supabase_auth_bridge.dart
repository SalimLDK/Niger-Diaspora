import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Synchronise la session Firebase Auth avec Supabase.
///
/// Après chaque login Firebase, échange le Firebase ID token contre un
/// Supabase JWT via l'Edge Function `auth-firebase-exchange`.
/// Le client Supabase peut ensuite utiliser les RLS policies.
class SupabaseAuthBridge {
  SupabaseAuthBridge._();

  static final SupabaseAuthBridge instance = SupabaseAuthBridge._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Échange en cours : les appels concurrents partagent le même Future.
  ///
  /// Sans cette déduplication, plusieurs datasources appelant
  /// ensureAuthenticated() au démarrage déclenchent des invocations parallèles
  /// de l'Edge Function ; or generateLink invalide le magic link précédent du
  /// même utilisateur (usage unique) — les échanges concurrents se sabotent
  /// mutuellement en 401 « Email link is invalid or has expired ».
  Future<void>? _inFlightSync;

  /// Renouvellement proactif : re-mint la session ~5 min avant son expiration.
  /// Le refresh token issu du magic link n'est pas fiable pour l'auto-refresh
  /// gotrue — sans ce timer, la session (et le websocket Realtime) meurt au
  /// bout d'une heure avec « InvalidJWTToken: Token has expired ».
  Timer? _renewTimer;

  /// Échange le token Firebase contre une session Supabase.
  /// À appeler après chaque `FirebaseAuth.instance.authStateChanges()` non-null.
  Future<void> syncWithFirebase(firebase_auth.User firebaseUser) {
    final pending = _inFlightSync;
    if (pending != null) return pending;
    final sync = _doSync(firebaseUser).whenComplete(() => _inFlightSync = null);
    _inFlightSync = sync;
    return sync;
  }

  Future<void> _doSync(firebase_auth.User firebaseUser) async {
    try {
      // Forcer le rafraîchissement du token Firebase si proche de l'expiration
      final idToken = await firebaseUser.getIdToken();

      final response = await _supabase.functions.invoke(
        'auth-firebase-exchange',
        body: {'firebase_token': idToken},
      );

      if (response.status != 200) {
        debugPrint('SupabaseAuthBridge: exchange failed (${response.status}) — ${response.data}');
        _scheduleRetry();
        return;
      }

      final accessToken = response.data['access_token'] as String?;
      final refreshToken = response.data['refresh_token'] as String?;

      if (accessToken == null) {
        debugPrint('SupabaseAuthBridge: access_token manquant dans la réponse');
        _scheduleRetry();
        return;
      }

      // Session.fromJson (gotrue-dart) requires a non-null 'user' field — if it's
      // absent the hard cast `json['user'] as Map` throws TypeError silently.
      // Decode the Supabase JWT payload to build the minimal user object.
      Map<String, dynamic> userJson;
      try {
        final parts = accessToken.split('.');
        final padded = base64Url.normalize(parts[1]);
        final payload =
            jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
        userJson = {
          'id': payload['sub'],
          'email': payload['email'],
          'role': payload['role'] ?? 'authenticated',
          'aud': payload['aud'] ?? 'authenticated',
          'app_metadata': payload['app_metadata'] ?? <String, dynamic>{},
          'user_metadata': payload['user_metadata'] ?? <String, dynamic>{},
          'created_at': DateTime.fromMillisecondsSinceEpoch(
            ((payload['iat'] as num?)?.toInt() ?? 0) * 1000,
          ).toUtc().toIso8601String(),
        };
      } catch (e) {
        debugPrint('SupabaseAuthBridge: JWT decode failed: $e');
        return;
      }

      final expiresIn = (response.data['expires_in'] as num?)?.toInt() ?? 3600;
      await _supabase.auth.recoverSession(jsonEncode({
        'access_token': accessToken,
        'refresh_token': refreshToken ?? '',
        'token_type': 'bearer',
        'expires_in': expiresIn,
        'user': userJson,
      }),);

      // Propage le JWT frais au websocket Realtime : sans cet appel, les
      // canaux (feed, messages) reconnectent avec l'ancien token expiré.
      _supabase.realtime.setAuth(accessToken);

      _retryCount = 0;
      _scheduleRenewal(expiresIn);
      debugPrint('SupabaseAuthBridge: session sync OK');
    } catch (e) {
      // Ne pas crasher si Supabase n'est pas disponible — l'app fonctionne sans
      debugPrint('SupabaseAuthBridge: $e');
      _scheduleRetry();
    }
  }

  /// Nombre d'échecs consécutifs de l'échange (pour le backoff).
  int _retryCount = 0;

  /// Ré-essaie l'échange après un échec (backoff 5 s → 80 s max).
  ///
  /// Sans retry, un seul échec au démarrage (réseau, 401 transitoire) laissait
  /// la session Supabase en anon : RLS filtrait tout et le realtime restait
  /// muet jusqu'au redémarrage de l'app.
  void _scheduleRetry() {
    _renewTimer?.cancel();
    final delay = Duration(seconds: min(5 * (1 << min(_retryCount, 4)), 80));
    _retryCount++;
    _renewTimer = Timer(delay, () {
      if (hasValidSession) return;
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) syncWithFirebase(user);
    });
  }

  void _scheduleRenewal(int expiresInSeconds) {
    _renewTimer?.cancel();
    final delay = Duration(seconds: max(expiresInSeconds - 300, 60));
    _renewTimer = Timer(delay, () {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) syncWithFirebase(user);
    });
  }

  /// Déconnecte la session Supabase (à appeler avec Firebase signOut).
  Future<void> signOut() async {
    _renewTimer?.cancel();
    _renewTimer = null;
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuthBridge signOut: $e');
    }
  }

  /// Vérifie si la session Supabase est active.
  bool get isAuthenticated => _supabase.auth.currentSession != null;

  /// Session valide = non nulle ET expirant dans plus de 60 s.
  ///
  /// Une session restaurée du stockage local (ou vieille d'une heure) peut
  /// être expirée alors que currentSession != null — d'où la marge.
  bool get hasValidSession {
    final session = _supabase.auth.currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds < expiresAt - 60;
  }

  /// Garantit qu'une session Supabase valide est établie avant une opération
  /// d'écriture. Appelé en tête des datasources qui écrivent dans Supabase.
  ///
  /// firebase_uid() utilise désormais auth_mappings comme fallback DB — inutile
  /// d'exiger le claim firebase_uid dans le JWT, seulement une session valide.
  Future<bool> ensureAuthenticated() async {
    if (hasValidSession) return true;

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    await syncWithFirebase(firebaseUser);
    return hasValidSession;
  }
}
