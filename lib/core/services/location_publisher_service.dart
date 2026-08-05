import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/profile/data/datasources/profile_supabase_datasource.dart';
import 'logger_service.dart';
import 'preferences_service.dart';

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
/// Le service n'écrit jamais sans le consentement explicite : `nearbyMembersEnabled`
/// est à `false` par défaut, et la permission de localisation n'est pas demandée
/// ici (c'est le rôle de l'onboarding et de l'écran carte, qui l'expliquent).
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
    if (!PreferencesService.instance.nearbyMembersEnabled) return;

    _userId = user.uid;
    if (_positionSubscription != null) return;

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

  /// Coupe tout : déconnexion, ou désactivation des « membres à proximité ».
  void stop() {
    _suspend();
    _userId = null;
    _lastPublished = null;
  }

  Future<void> _publish(Position position) async {
    final userId = _userId;
    if (userId == null) return;
    // Relu à chaque écriture : le réglage peut avoir été coupé entre-temps.
    if (!PreferencesService.instance.nearbyMembersEnabled) return;

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
