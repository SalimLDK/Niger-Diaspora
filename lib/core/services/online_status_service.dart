import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// `User` masqué : firebase_auth expose déjà ce nom, et c'est celui-là qu'on
// utilise ici (l'identité vient de Firebase).
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:flutter/widgets.dart';

import 'supabase_auth_bridge.dart';

/// Service to manage user online/offline status (presence).
///
/// Deux datastores, chacun pour ce qu'il sait faire :
/// - **RTDB** pour la présence temps réel — `onDisconnect()` est une capacité
///   propre à Firebase : elle marque l'utilisateur hors ligne même si l'app est
///   tuée sans prévenir. Rien d'équivalent côté Supabase.
/// - **Supabase** pour la persistance (`users.is_online`, `last_seen_at`) et la
///   préférence de visibilité (`show_online_status`).
///
/// Auparavant tout passait par la collection Firestore `users`, qui a migré :
/// les écritures échouaient en silence et, surtout, `show_online_status` était
/// toujours relu à `true` — un utilisateur ayant masqué son statut était donc
/// quand même diffusé comme en ligne.
class OnlineStatusService {
  static OnlineStatusService? _instance;
  static OnlineStatusService get instance {
    _instance ??= OnlineStatusService._();
    return _instance!;
  }

  OnlineStatusService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Lit la préférence de visibilité du statut en ligne.
  ///
  /// En cas d'échec (hors ligne, RLS, ligne absente) on retourne `true`, comme
  /// avant : le défaut produit est « statut visible », qui est aussi la valeur
  /// par défaut de la colonne.
  Future<bool> _showOnlineStatus(String userId) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return true;
      final row = await _supabase
          .from('users')
          .select('show_online_status')
          .eq('id', userId)
          .maybeSingle();
      return (row?['show_online_status'] as bool?) ?? true;
    } catch (e) {
      debugPrint('OnlineStatusService: lecture show_online_status échouée ($e)');
      return true;
    }
  }

  /// Persiste le statut dans Supabase. Best-effort : la présence temps réel
  /// reste portée par RTDB, cette écriture n'est qu'un miroir consultable.
  Future<void> _persistStatus(String userId, {required bool isOnline}) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
      await _supabase.from('users').update({
        'is_online': isOnline,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('OnlineStatusService: persistance du statut échouée ($e)');
    }
  }

  DatabaseReference? _presenceRef;
  DatabaseReference? _connectedRef;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  AppLifecycleListener? _lifecycleListener;

  bool _initialized = false;
  String? _currentUserId;

  // ── Fraîcheur de la présence ────────────────────────────────────────────
  //
  // `isOnline` seul ne dit pas si c'est encore vrai. Vu le 2026-09-22 sur
  // deux téléphones : un compte passé en mode avion, app fermée, restait
  // « En ligne » chez l'autre plusieurs minutes — le `_setOffline` du passage
  // en arrière-plan ne pouvait plus partir, et seul `onDisconnect` restait,
  // quand le serveur finit par constater la coupure. Et le battement de
  // 10 min n'écrivait que dans Supabase, que personne ne lit pour ça.
  //
  // Désormais, au premier plan, `lastSeen` est rafraîchi toutes les
  // [battement] dans RTDB, et le nœud porte `battement` (en secondes). Un
  // lecteur tient pour hors ligne un `isOnline` dont le `lastSeen` a dépassé
  // [fraicheurPour]. Un nœud SANS `battement` vient d'un ancien client (il
  // réécrit le nœud entier, donc efface le champ) : l'ancienne règle s'y
  // applique, sinon on l'afficherait hors ligne alors qu'il est là.

  /// Période du battement de présence, au premier plan.
  ///
  /// 20 s et non 60 : c'est le **filet** quand l'app est gelée par Android
  /// avant d'avoir pu écrire « hors ligne » (mesuré le 2026-09-22 sur
  /// SM A515F : au retour à l'accueil, une fois sur trois aucune écriture
  /// n'arrivait, et seul `onDisconnect` jouait, ~95 s plus tard). Avec 20 s,
  /// un lecteur à jour tient le compte pour hors ligne en moins d'une minute.
  static const battement = Duration(seconds: 20);

  /// Au-delà, un `isOnline` à vrai est périmé : deux battements manqués, plus
  /// une marge pour la latence et l'horloge (55 s pour 20 s).
  @visibleForTesting
  static Duration fraicheurPour(int battementSecondes) =>
      Duration(seconds: battementSecondes * 2 + 15);

  /// La règle d'affichage « En ligne », sur le nœud `presence/<uid>` brut.
  ///
  /// [maintenantServeurMs] : l'heure **du serveur**, car `lastSeen` est posé
  /// par `ServerValue.timestamp` — l'horloge du téléphone qui lit peut
  /// dériver.
  @visibleForTesting
  static bool estEnLigne(Object? noeud, {required int maintenantServeurMs}) {
    if (noeud is! Map) return false;
    if (noeud['isOnline'] != true) return false;
    final periode = noeud['battement'];
    if (periode is! num || periode <= 0) return true;
    final vu = noeud['lastSeen'];
    if (vu is! num) return false;
    return maintenantServeurMs - vu.toInt() <=
        fraicheurPour(periode.toInt()).inMilliseconds;
  }

  Map<String, Object> get _noeudEnLigne => {
    'isOnline': true,
    'lastSeen': ServerValue.timestamp,
    'battement': battement.inSeconds,
  };

  /// Vrai quand l'app est affichée. Rien ne doit mettre « en ligne » un
  /// compte dont l'app tourne sans écran : c'était possible par
  /// `.info/connected`, qui se reconnecte aussi en arrière-plan.
  /// Relevé dans [initialize], quand le binding existe à coup sûr.
  bool _auPremierPlan = true;

  static bool _estAuPremierPlan(AppLifecycleState? etat) =>
      etat == null ||
      etat == AppLifecycleState.resumed ||
      etat == AppLifecycleState.inactive;

  /// Ce que fait la présence à chaque état du cycle de vie.
  ///
  /// - `resumed` : en ligne.
  /// - `inactive` : **rien**. C'est un état de passage (volet de
  ///   notifications, sélecteur d'apps, et surtout le chemin vers
  ///   l'arrière-plan : `inactive` → `hidden` → `paused`). Y écrire « en
  ///   ligne » faisait partir un `true` au moment où l'app s'en allait, qui
  ///   arrivait parfois APRÈS le `false` (2 fois sur 3 le 2026-09-22).
  /// - `hidden`, `paused`, `detached` : hors ligne, tout de suite.
  @visibleForTesting
  static bool? presencePour(AppLifecycleState etat) => switch (etat) {
    AppLifecycleState.resumed => true,
    AppLifecycleState.inactive => null,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };

  /// La préférence « Afficher mon statut en ligne », gardée en mémoire.
  ///
  /// Relue sur le réseau à chaque passage en ligne, elle retardait l'écriture
  /// RTDB — et, dans la file, tout ce qui suivait, dont le « hors ligne » du
  /// passage en arrière-plan. Lue une fois à la mise en place, tenue à jour
  /// par [updateOnlineStatusVisibility], et relue en arrière-plan au retour.
  bool? _visibleEnMemoire;

  /// Les écritures de présence, une à la fois, dans l'ordre des événements.
  ///
  /// Au passage en arrière-plan, `inactive` → `hidden` → `paused` arrivent
  /// d'affilée. `_setOnline` (pour `inactive`) attend une lecture Supabase
  /// avant d'écrire : sans file, il pouvait écrire `true` APRÈS les
  /// `_setOffline` des deux suivants, et laisser le compte « En ligne ».
  Future<void> _file = Future<void>.value();

  Future<void> _enFile(Future<void> Function() ecriture) {
    return _file = _file.then((_) => ecriture()).catchError((Object e) {
      debugPrint('OnlineStatusService: écriture de présence échouée ($e)');
    });
  }

  /// Écart entre l'horloge du serveur RTDB et celle de ce téléphone.
  int _decalageServeurMs = 0;
  StreamSubscription<DatabaseEvent>? _decalageSubscription;

  void _suivreDecalageServeur() {
    _decalageSubscription ??= _database
        .ref('.info/serverTimeOffset')
        .onValue
        .listen((event) {
          final valeur = event.snapshot.value;
          if (valeur is num) _decalageServeurMs = valeur.toInt();
        });
  }

  int _maintenantServeurMs() =>
      DateTime.now().millisecondsSinceEpoch + _decalageServeurMs;

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
    _auPremierPlan = _estAuPremierPlan(WidgetsBinding.instance.lifecycleState);

    // Listen to auth state changes
    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _setupPresenceForUser(user.uid);
      } else {
        await _teardownPresence();
      }
    });

    // Listen to app lifecycle changes
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleStateChange,
    );

    _initialized = true;
    // debugPrint('✅ OnlineStatusService: Initialized successfully');
  }

  /// Vrai si la présence de [userId] est **déjà suivie** : identité retenue
  /// *et* écoute de la connexion posée.
  ///
  /// L'identité seule ne prouve rien. `_setupPresenceForUser` retient l'uid
  /// AVANT de lire la préférence de visibilité, puis sort sans poser d'écoute
  /// quand le statut est masqué : un utilisateur masqué a donc un uid retenu et
  /// aucun abonnement. Avec la seule identité, ré-afficher son statut
  /// (`updateOnlineStatusVisibility(true)`, qui rappelle
  /// `_setupPresenceForUser`) tombait sur « déjà suivi » et ne rétablissait
  /// rien : l'utilisateur ne repassait « en ligne » qu'au prochain retour au
  /// premier plan, et sans le gestionnaire de déconnexion — donc restait
  /// « en ligne » si l'app était tuée.
  ///
  /// Extrait pour être testable : le service tient des singletons Firebase et
  /// ne se monte pas en test.
  @visibleForTesting
  static bool isPresenceTracked({
    required String? trackedUserId,
    required String userId,
    required bool hasConnectionListener,
  }) => trackedUserId == userId && hasConnectionListener;

  /// Setup presence tracking for a specific user
  Future<void> _setupPresenceForUser(String userId) async {
    // Validate authentication first
    if (!_isUserAuthenticated()) {
      // debugPrint(
      //   '❌ OnlineStatusService: Cannot setup presence - user not authenticated',
      // );
      return;
    }

    if (isPresenceTracked(
      trackedUserId: _currentUserId,
      userId: userId,
      hasConnectionListener: _connectedSubscription != null,
    )) {
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
      final showOnlineStatus = await _showOnlineStatus(userId);
      _visibleEnMemoire = showOnlineStatus;

      if (!showOnlineStatus) {
        // debugPrint(
        //   '🔒 OnlineStatusService: User has disabled online status visibility',
        // );
        // Set as offline and don't track presence
        await _enFile(() => _setOffline(userId));
        return;
      }

      // Listen to connection state
      _connectedSubscription = _connectedRef!.onValue.listen((event) async {
        final connected = event.snapshot.value as bool? ?? false;

        if (connected) {
          // debugPrint('🌐 OnlineStatusService: Connected to Firebase');
          // Reconnexion en arrière-plan : on arme `onDisconnect`, mais on ne
          // se déclare pas en ligne — personne ne regarde l'écran.
          if (_auPremierPlan) await _enFile(() => _setOnline(userId));

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
  void _handleLifecycleStateChange(AppLifecycleState state) async {
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

    final userId = _currentUserId!;
    final enLigne = presencePour(state);
    if (enLigne == null) return;
    _auPremierPlan = enLigne;
    if (enLigne) {
      await _enFile(() => _setOnline(userId));
      // Le réglage a pu changer ailleurs pendant l'absence : relu sans
      // retarder l'écriture qui précède.
      unawaited(_relireVisibilite(userId));
    } else {
      _heartbeatTimer?.cancel();
      await _enFile(() => _setOffline(userId));
    }
  }

  Future<void> _relireVisibilite(String userId) async {
    final visible = await _showOnlineStatus(userId);
    final avant = _visibleEnMemoire;
    _visibleEnMemoire = visible;
    if (avant != false && !visible) {
      await _enFile(() => _setOffline(userId));
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
      // Check privacy preference — en mémoire : pas d'aller-retour réseau
      // avant l'écriture (voir [_visibleEnMemoire]).
      final showOnlineStatus =
          _visibleEnMemoire ??= await _showOnlineStatus(userId);

      if (!showOnlineStatus) {
        // debugPrint(
        //   '🔒 OnlineStatusService: User privacy setting prevents online status',
        // );
        await _setOffline(userId);
        return;
      }

      // debugPrint('✅ OnlineStatusService: Setting user $userId to ONLINE');

      // Pendant la lecture de la préférence, l'app a pu passer en arrière-plan.
      if (!_auPremierPlan) return;

      // Update Realtime Database
      await _presenceRef!.set(_noeudEnLigne);

      // Miroir Supabase hors de la file : il ne doit pas retarder l'écriture
      // de présence suivante (le « hors ligne » d'un départ en arrière-plan).
      unawaited(_persistStatus(userId, isOnline: true));

      // Start heartbeat to keep lastSeen fresh
      // (This fix preventing "ghosts" who crash and stay online in Firestore forever)
      _startHeartbeat(userId);
    } catch (e) {
      debugPrint('OnlineStatusService: passage en ligne échoué ($e)');
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

  /// Au premier plan : `lastSeen` rafraîchi dans RTDB toutes les [battement]
  /// — c'est ce que les lecteurs jugent ([estEnLigne]) —, et le miroir
  /// Supabase toutes les 10 min comme avant.
  ///
  /// Le battement **réaffirme** aussi `isOnline` : si une coupure passagère a
  /// fait jouer `onDisconnect` sans que le retour ne se ré-écrive, l'app au
  /// premier plan redevient « en ligne » au battement suivant, au lieu de
  /// rester « Vu il y a 2 minutes » sous les yeux de l'autre.
  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    final parMiroir = const Duration(minutes: 10).inSeconds ~/ battement.inSeconds;
    _heartbeatTimer = Timer.periodic(battement, (timer) {
      if (!_auPremierPlan) return;
      unawaited(
        _enFile(() async {
          final ref = _presenceRef;
          if (ref == null || !_auPremierPlan || !_isUserAuthenticated(userId)) {
            return;
          }
          await ref.update(_noeudEnLigne);
          if (timer.tick % parMiroir == 0) {
            unawaited(_persistStatus(userId, isOnline: true));
          }
        }),
      );
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

      // Miroir Supabase hors de la file, comme pour le passage en ligne.
      unawaited(_persistStatus(userId, isOnline: false));
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

  /// Écrit `users.show_online_status` et **lève si aucune ligne n'a été
  /// touchée**.
  ///
  /// PostgREST rend 200 sur un `UPDATE` qui ne matche rien — RLS qui cache la
  /// ligne, ou ligne pas encore créée. Sans ce contrôle l'écriture « réussissait »
  /// à vide : l'interrupteur gardait la nouvelle valeur, la présence était
  /// alignée dessus, et le serveur gardait l'ancienne — un compte qui croyait
  /// s'être masqué repartait visible au lancement suivant. Même garde que
  /// `updateNotificationPrefs` (voir `profile_notification_writes_test.dart`).
  ///
  /// Statique et prenant le client en paramètre : le service tient des
  /// singletons Firebase et ne se monte pas en test, cette écriture-là si.
  @visibleForTesting
  static Future<void> writeShowOnlineStatus(
    SupabaseClient client,
    String userId,
    bool value,
  ) async {
    final touchees = await client
        .from('users')
        .update({'show_online_status': value})
        .eq('id', userId)
        .select('id');
    if (touchees.isEmpty) {
      throw StateError('Réglage non enregistré : aucun compte mis à jour');
    }
  }

  /// Update user's online status visibility preference.
  ///
  /// **Lève** si la préférence n'a pas pu être écrite : aucun utilisateur,
  /// session Supabase absente, aucune ligne touchée, ou refus du serveur. Elle
  /// rendait auparavant
  /// sans rien dire dans ces trois cas — `_currentUserId == null` (présence pas
  /// encore montée) et session absente sortaient sur un `return`, et un `catch`
  /// avalait le reste. L'interrupteur affichait donc la nouvelle valeur sans
  /// que le serveur l'ait reçue, et son seul appelant, le notifier, avait un
  /// `try/catch` qui ne pouvait jamais se déclencher.
  ///
  /// L'identité vient de Firebase et non de `_currentUserId` : la préférence ne
  /// dépend pas de la présence temps réel, qui peut ne pas être montée.
  ///
  /// Ce qui suit l'écriture — aligner la présence temps réel — reste au mieux :
  /// la préférence, elle, est enregistrée.
  Future<void> updateOnlineStatusVisibility(bool showStatus) async {
    final userId = _currentUserId ?? _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Aucun utilisateur connecté');
    }
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw StateError('Session distante indisponible');
    }

    await writeShowOnlineStatus(_supabase, userId, showStatus);
    _visibleEnMemoire = showStatus;

    try {
      if (showStatus) {
        // Re-setup presence tracking
        await _setupPresenceForUser(userId);
      } else {
        // Set to offline and stop tracking
        await _enFile(() => _setOffline(userId));
        await _connectedSubscription?.cancel();
        _connectedSubscription = null;
      }
    } catch (e) {
      debugPrint(
        'OnlineStatusService: présence non alignée après changement de '
        'visibilité ($e)',
      );
    }
  }

  /// « En ligne » ou non, selon [estEnLigne] : le nœud entier est suivi, et la
  /// règle est **réévaluée toutes les 30 s** même sans nouvel événement —
  /// un compte qui disparaît sans prévenir n'émet justement plus rien, et
  /// c'est le temps qui doit le faire passer hors ligne.
  Stream<bool> getUserOnlineStatus(String userId) {
    late final StreamController<bool> sortie;
    StreamSubscription<DatabaseEvent>? abonnement;
    Timer? reevaluation;
    Object? noeud;
    var recu = false;

    void emettre() {
      if (!recu || sortie.isClosed) return;
      sortie.add(estEnLigne(noeud, maintenantServeurMs: _maintenantServeurMs()));
    }

    sortie = StreamController<bool>(
      onListen: () {
        _suivreDecalageServeur();
        abonnement = _database.ref('presence/$userId').onValue.listen(
          (event) {
            noeud = event.snapshot.value;
            recu = true;
            emettre();
          },
          onError: sortie.addError,
        );
        reevaluation = Timer.periodic(
          const Duration(seconds: 30),
          (_) => emettre(),
        );
      },
      onCancel: () async {
        reevaluation?.cancel();
        await abonnement?.cancel();
      },
    );
    return sortie.stream.distinct();
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
    _heartbeatTimer?.cancel();
    final sortant = _currentUserId;
    if (sortant != null) {
      // Dans la file : un battement déjà parti ne doit pas réécrire « en
      // ligne » après la déconnexion.
      await _enFile(() => _setOffline(sortant));
    }

    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
    _presenceRef = null;
    _connectedRef = null;
    _currentUserId = null;
    // Préférence d'un autre compte : à relire pour le prochain.
    _visibleEnMemoire = null;

    // debugPrint('🔄 OnlineStatusService: Presence tracking torn down');
  }

  /// Dispose of the service
  Future<void> dispose() async {
    // debugPrint('🔄 OnlineStatusService: Disposing...');

    await _teardownPresence();
    await _authStateSubscription?.cancel();
    await _decalageSubscription?.cancel();
    _decalageSubscription = null;
    _lifecycleListener?.dispose();

    _authStateSubscription = null;
    _lifecycleListener = null;
    _initialized = false;

    // debugPrint('✅ OnlineStatusService: Disposed');
  }
}
