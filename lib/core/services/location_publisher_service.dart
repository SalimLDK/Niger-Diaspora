import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/profile/data/datasources/profile_supabase_datasource.dart';
import 'logger_service.dart';

/// Publie la position de l'utilisateur courant tant que l'app est au premier
/// plan, **quel que soit l'écran affiché**.
///
/// Auparavant le `getPositionStream` ne vivait que dans `MapScreen` : un membre
/// n'émettait sa position que pendant qu'il regardait lui-même la carte. Vu des
/// autres, il restait donc figé à sa dernière position connue, puis disparaissait
/// — le filtre de présence de la carte exige un `location_updated_at` de moins de
/// cinq minutes. Aucun raccourcissement du sondage ne pouvait corriger ça : la
/// donnée à l'autre bout n'était pas fraîche non plus.
///
/// Deux sources d'écriture :
/// - le flux `Geolocator`, déclenché à chaque déplacement de [_distanceFilterMeters] ;
/// - un battement de cœur qui réécrit la dernière position connue, pour qu'un
///   membre immobile ne sorte pas de la fenêtre de fraîcheur de cinq minutes.
///
/// Le service n'écrit jamais sans le consentement explicite : le
/// consentement qui compte est `share_location` sur le profil serveur — le
/// même champ que lit `getNearbyProfiles` pour décider si quelqu'un d'autre
/// peut voir cette position. La permission de localisation n'est pas demandée
/// ici (c'est le rôle de l'onboarding et de l'écran carte, qui l'expliquent).
///
/// `start()` relit ce champ à chaque appel plutôt que de faire confiance à la
/// préférence locale `nearbyMembersEnabled` : Réglages écrit le profil sans
/// passer par cette préférence, et un compte qui avait activé « Ma
/// localisation » dans Réglages restait invisible pour toujours faute d'avoir
/// aussi ouvert la carte pour activer son calque « Membres » (le seul chemin
/// qui touchait `nearbyMembersEnabled` avant ce correctif). Se relire depuis
/// le serveur à chaque démarrage guérit ces comptes sans action de leur part.
class LocationPublisherService {
  static LocationPublisherService? _instance;
  static LocationPublisherService get instance {
    _instance ??= LocationPublisherService._();
    return _instance!;
  }

  LocationPublisherService._();

  /// Même seuil que celui utilisé historiquement par l'écran carte.
  static const int _distanceFilterMeters = 50;

  /// Confortablement sous la fenêtre de 5 minutes du filtre de présence.
  static const Duration _heartbeatInterval = Duration(minutes: 2);

  final ProfileSupabaseDataSource _dataSource = ProfileSupabaseDataSource();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<User?>? _authSubscription;
  AppLifecycleListener? _lifecycleListener;
  Timer? _heartbeatTimer;

  bool _initialized = false;
  String? _userId;
  Position? _lastPublished;

  /// Copie du `share_location` serveur lu par le dernier `start()` réussi.
  /// `_publish` s'y fie plutôt que de refaire une lecture réseau à chaque
  /// battement de cœur ou déplacement.
  bool _shareLocationEnabled = false;

  /// Branche le service sur l'authentification et le cycle de vie de l'app.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        stop();
      } else {
        unawaited(start());
      }
    });

    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.resumed:
          case AppLifecycleState.inactive:
            // `inactive` est transitoire (volet de notifications, appel
            // entrant) : on ne coupe pas le flux pour ça.
            unawaited(start());
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
            // Le relais en arrière-plan est assuré par
            // `BackgroundLocationService`, quand l'utilisateur l'a activé.
            _suspend();
        }
      },
    );

    if (FirebaseAuth.instance.currentUser != null) {
      await start();
    }
  }

  /// Démarre la publication si toutes les conditions sont réunies. Idempotent.
  Future<void> start() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Déjà en train de streamer : ne pas relire le profil en réseau à
    // chaque `inactive` transitoire (volet de notifications, appel entrant),
    // qui redéclenche `start()` sans que le flux ait été suspendu.
    if (_positionSubscription != null) return;

    try {
      final profile = await _dataSource.getProfile(user.uid);
      _shareLocationEnabled = profile.shareLocation;
    } catch (e, s) {
      // Session pas encore prête, ou profil pas encore créé : on retentera
      // au prochain `start()` (retour au premier plan, changement d'auth).
      LoggerService.w(
        'LocationPublisherService: lecture du profil échouée',
        e,
        s,
      );
      return;
    }
    if (!_shareLocationEnabled) return;

    _userId = user.uid;

    // On se contente de la permission déjà accordée : la demander ici la
    // ferait surgir sur un écran quelconque, sans explication.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }

    // Publication immédiate de la dernière position connue : sans elle, un
    // utilisateur immobile n'écrit rien avant son premier déplacement de 50 m
    // et reste invisible aux autres.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) await _publish(lastKnown);
    } catch (_) {
      // Pas de position en cache : le flux ci-dessous prendra le relais.
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters,
      ),
    ).listen(
      _publish,
      onError: (Object e, StackTrace s) {
        LoggerService.w('LocationPublisherService: flux de position en erreur', e, s);
      },
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final last = _lastPublished;
      if (last != null) unawaited(_publish(last));
    });
  }

  /// Coupe le flux sans oublier l'utilisateur : l'app est passée en arrière-plan.
  void _suspend() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Coupe tout : déconnexion, ou désactivation de « Ma localisation ».
  void stop() {
    _suspend();
    _userId = null;
    _lastPublished = null;
    _shareLocationEnabled = false;
  }

  Future<void> _publish(Position position) async {
    final userId = _userId;
    if (userId == null) return;
    // Le réglage peut avoir été coupé entre-temps ; `stop()` annule déjà
    // l'abonnement et le battement de cœur, ce garde couvre l'appel encore
    // en vol au moment de la coupure.
    if (!_shareLocationEnabled) return;

    try {
      await _dataSource.updateLocation(
        userId,
        position.latitude,
        position.longitude,
      );
      _lastPublished = position;
    } catch (e, s) {
      LoggerService.w(
        'LocationPublisherService: publication de la position échouée',
        e,
        s,
      );
    }
  }

  /// Libère les abonnements permanents (tests, arrêt de l'app).
  Future<void> dispose() async {
    stop();
    await _authSubscription?.cancel();
    _authSubscription = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _initialized = false;
  }
}
