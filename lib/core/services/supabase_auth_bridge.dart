import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_service.dart';
import 'politique_de_reprise.dart';

/// Synchronise la session Firebase Auth avec Supabase.
///
/// Après chaque login Firebase, échange le Firebase ID token contre un
/// Supabase JWT via l'Edge Function `auth-firebase-exchange`.
/// Le client Supabase peut ensuite utiliser les RLS policies.
class SupabaseAuthBridge {
  SupabaseAuthBridge._();

  /// Dernier état connu : on ne veut réagir qu'à la TRANSITION vers connecté,
  /// pas à chaque émission (le flux répète l'état sur bien des appareils).
  bool _etaitConnecte = true;
  bool _ecouteLeReseau = false;

  /// S'abonne au retour du réseau, une seule fois, et seulement une fois
  /// qu'on a abandonné.
  ///
  /// **Paresseux à dessein.** S'abonner dans le constructeur touchait un
  /// `EventChannel`, donc le binding Flutter : les tests unitaires du profil
  /// (de simples `test()`, sans binding) tombaient tous sur « Binding has not
  /// yet been initialized » dès que le pont était instancié. Au moment où on
  /// abandonne, l'app tourne pour de bon et le binding existe.
  ///
  /// Jamais annulé : le pont est un singleton qui vit aussi longtemps que
  /// l'app, l'abonnement doit lui survivre d'une session à l'autre.
  void _ecouterRetourReseau() {
    if (_ecouteLeReseau) return;
    _ecouteLeReseau = true;
    // On ne s'abonne QUE depuis l'abandon, donc on est hors ligne à cet
    // instant. Sans ce faux de départ, `_etaitConnecte` resterait à `true` et
    // le `true` du retour ne ressemblerait pas à une transition : la reprise
    // ne partait jamais (constaté sur SM A515F le 2026-09-08).
    _etaitConnecte = false;
    try {
      ConnectivityService.instance.onConnectivityChanged.listen((connecte) {
        if (connecte && !_etaitConnecte) reprendreApresRetourReseau();
        _etaitConnecte = connecte;
      });
    } catch (e) {
      // Pas de plugin (test, plateforme réduite) : on s'en passe, la reprise
      // se fera au prochain appel externe passé la fenêtre de repos.
      _ecouteLeReseau = false;
      debugPrint('SupabaseAuthBridge: écoute réseau indisponible ($e)');
    }
  }

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

  /// Quand une nouvelle tentative vaut la peine. Voir `politique_de_reprise.dart`.
  final PolitiqueDeReprise _reprise = PolitiqueDeReprise();

  /// Échange le token Firebase contre une session Supabase.
  /// À appeler après chaque `FirebaseAuth.instance.authStateChanges()` non-null.
  Future<void> syncWithFirebase(firebase_auth.User firebaseUser) {
    final pending = _inFlightSync;
    if (pending != null) return pending;

    // `_inFlightSync` ne dedoublonne que les appels SIMULTANES. Ceux qui
    // arrivent ENTRE deux tentatives passaient au travers, et
    // `auth_remote_datasource` en emet un a chaque `authStateChanges()` --
    // c'est-a-dire a chaque echec de rafraichissement Firebase. Resultat vu
    // sur SM A515F : une tentative toutes les ~5 s, sans fin, malgre le repli
    // exponentiel ci-dessous. La fenetre de calme, elle, vaut pour tout le
    // monde.
    if (!_reprise.peutTenter) return Future.value();

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

      _reprise.enregistrerSucces();
      _scheduleRenewal(expiresIn);
      debugPrint('SupabaseAuthBridge: session sync OK');
    } catch (e) {
      // Ne pas crasher si Supabase n'est pas disponible — l'app fonctionne sans
      debugPrint('SupabaseAuthBridge: $e');
      _scheduleRetry();
    }
  }

  /// Ré-essaie l'échange après un échec, puis finit par abandonner.
  ///
  /// Sans retry du tout, un seul échec au démarrage (réseau, 401 transitoire)
  /// laissait la session Supabase en anon : RLS filtrait tout et le realtime
  /// restait muet jusqu'au redémarrage de l'app. Mais retenter sans fin n'est
  /// pas mieux : hors ligne, l'app s'acharnait toutes les ~5 s et les écrans
  /// qui attendent la session tournaient indéfiniment (SM A515F, 2026-09-08).
  ///
  /// La politique tranche les deux : repli exponentiel, puis abandon au bout
  /// de six tentatives — avec une fenêtre de repos, parce que le réseau peut
  /// revenir sans que rien ne nous le signale.
  void _scheduleRetry() {
    _renewTimer?.cancel();
    final delai = _reprise.enregistrerEchec();

    if (delai == null) {
      debugPrint(
        'SupabaseAuthBridge: abandon après '
        '${_reprise.echecsConsecutifs} tentatives — la session reste anon '
        'jusqu\'au retour du réseau',
      );
      _ecouterRetourReseau();
      return;
    }

    _renewTimer = Timer(delai, () {
      if (hasValidSession) return;
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) syncWithFirebase(user);
    });
  }

  /// Le réseau est revenu, ou l'app repasse au premier plan : on redonne
  /// une chance immédiate sans attendre la fin du repos.
  void reprendreApresRetourReseau() {
    _reprise.autoriserUneTentative();
    if (hasValidSession) return;
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) syncWithFirebase(user);
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
    // L'abonnement connectivité survit volontairement à la déconnexion : le
    // pont est un singleton, il resservira à la prochaine session.
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

  /// Variante bornée d'[ensureAuthenticated], pour les lectures qui ne
  /// doivent jamais rester bloquées.
  ///
  /// `_startFromLocalSession` (auth_provider.dart) débloque volontairement
  /// `/home` sur la seule foi de Firebase quand le pont Supabase n'a pas
  /// répondu sous 8 s (splash bloqué constaté le 2026-08-04) — pendant cette
  /// fenêtre, les lectures faites depuis `/home` tournent en `anon` tant que
  /// personne ne les borne. Contrairement à [ensureAuthenticated], un
  /// timeout ici ne fait PAS échouer la lecture : mieux vaut dégrader (état
  /// en cache, vide, ou repli existant de l'appelant) que geler l'écran en
  /// attendant un réseau lent. La synchronisation continue en tâche de fond
  /// (dédupliquée via [syncWithFirebase]) et profite au prochain appelant,
  /// écriture ou lecture.
  Future<bool> ensureReadableSession({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (hasValidSession) return true;

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    try {
      await syncWithFirebase(firebaseUser).timeout(timeout);
    } on TimeoutException {
      // Repli intentionnel : voir docstring.
    } catch (e) {
      debugPrint('SupabaseAuthBridge.ensureReadableSession: $e');
    }
    return hasValidSession;
  }
}
