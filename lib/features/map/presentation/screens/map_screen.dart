import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/logger_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/datasources/profile_supabase_datasource.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../friends/domain/repositories/friend_repository.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../embassies/presentation/providers/embassies_provider.dart';
import '../../../embassies/domain/entities/embassy_entity.dart';
import '../../../businesses/presentation/providers/business_provider.dart';
import '../../../businesses/domain/entities/business_entity.dart';
import '../../../../core/extensions/business_entity_extensions.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../../features/map/presentation/utils/cluster_marker_generator.dart';
import '../../../../features/map/presentation/utils/marker_image_loader.dart';
import '../widgets/map_legend.dart';
import '../widgets/map_search_bar.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _controller = Completer();

  // Position par défaut: Niamey, Niger
  static const LatLng _defaultPosition = LatLng(13.5116, 2.1254);

  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  Set<Marker> _embassyMarkers = {};
  Set<Marker> _businessMarkers = {};
  List<ProfileModel> _nearbyMembers = [];
  List<EmbassyEntity> _embassies = [];
  List<BusinessEntity> _businesses = [];
  /// Ordre de la liste des membres (§7e) : il était fixe et muet.
  _MemberSort _sort = _MemberSort.nearest;

  /// Mode « liste seule » (§7e) : consulter les membres proches sans
  /// charger la carte, utile en données réduites.
  bool _listOnly = false;

  bool _showBusinesses = true;
  bool _showEmbassies = true;
  String _selectedFilter = 'all';

  /// Vrai quand la liste de résultats de recherche de lieu est ouverte : on
  /// masque alors les filtres profession (top:76) qu'elle recouvrirait.
  bool _isSearchResultsOpen = false;
  double _selectedRadius = 50; // Rayon par défaut en km
  String? _userCountry; // Pays de l'utilisateur pour le filtre "Pays entier"
  bool _isLoading = true;

  bool _mapsInitialized = false;
  bool _isReciprocityRestricted = false;

  String? _lightMapStyle;
  String? _darkMapStyle;

  // Nouvelles variables pour Phase 2 & 3
  String? _selectedMarkerId; // Pin sélectionné
  double _currentZoom = 12.0; // Niveau de zoom actuel
  int _lastZoomCategory =
      1; // Catégorie de zoom précédente pour éviter rebuilds inutiles
  final Map<String, DateTime> _cacheExpiration = {}; // Cache avec expiration

  // Filter keys for profession matching
  static const List<String> _filterKeys = [
    'all',
    'entrepreneurs',
    'students',
    'professionals',
    'artists',
  ];

  String _getFilterLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'all':
        return l10n.filterAll;
      case 'entrepreneurs':
        return l10n.filterEntrepreneurs;
      case 'students':
        return l10n.filterStudents;
      case 'professionals':
        return l10n.filterProfessionals;
      case 'artists':
        return l10n.filterArtists;
      default:
        return key;
    }
  }

  // Options de rayon disponibles (en km) - 0 = pays entier, -1 = global (monde entier)
  final List<double> _radiusOptions = [10, 25, 50, 100, 200, 500, 0, -1];

  final Map<String, BitmapDescriptor> _markerCache = {};

  bool _hasInitialized = false;

  // Stream et timer pour mise à jour automatique
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _membersRefreshTimer;
  Timer? _uiRefreshTimer;
  static const int _membersRefreshIntervalSeconds =
      45; // Rafraîchir les membres toutes les 45s
  static const int _distanceFilterMeters =
      50; // Mise à jour position tous les 50m
  static const int _uiRefreshIntervalSeconds =
      10; // Rafraîchir l'affichage du temps toutes les 10s

  // Indicateur de dernière mise à jour
  DateTime? _lastMembersUpdate;
  DateTime? _lastPositionUpdate;

  // Debounce et versioning pour _updateMarkers
  Timer? _updateMarkersDebounce;
  int _markersVersion = 0;
  static const Duration _updateMarkersDebounceDelay = Duration(
    milliseconds: 300,
  );

  /// Formate un DateTime en temps relatif (ex: "il y a 2 min")
  String _formatRelativeTime(DateTime? dateTime, AppLocalizations l10n) {
    if (dateTime == null) return l10n.loading;

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 10) {
      return l10n.justNow;
    } else if (difference.inSeconds < 60) {
      return l10n.secondsAgo(difference.inSeconds);
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else {
      return l10n.hoursAgo(difference.inHours);
    }
  }

  @override
  void dispose() {
    // debugPrint('🗺️ MapScreen: dispose');
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _membersRefreshTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _updateMarkersDebounce?.cancel();
    _controller.future.then((c) => c.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Pause les timers quand l'app est en arrière-plan
        _membersRefreshTimer?.cancel();
        _membersRefreshTimer = null;
        _uiRefreshTimer?.cancel();
        _uiRefreshTimer = null;
        _positionStreamSubscription?.pause();
        break;
      case AppLifecycleState.resumed:
        // Reprendre les timers quand l'app revient au premier plan
        _positionStreamSubscription?.resume();
        if (_currentPosition != null) {
          _startMembersRefreshTimer();
          // Refresh immédiat des membres après reprise
          _loadNearbyMembers(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        }
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // debugPrint('🗺️ MapScreen: initState');
    _mapsInitialized = true; // Already initialized in main.dart
    // §7e : en données réduites, on n'ouvre pas la carte d'emblée. Le
    // réglage existait déjà, il n'était simplement pas lu ici.
    _listOnly = PreferencesService.instance.dataSaverMode;
    _showBusinesses = PreferencesService.instance.mapBusinessesLayerVisible;
    _loadUserCountry();
    _loadMapStyles();
  }

  /// Charge les styles de carte clair/sombre depuis les assets une seule fois.
  /// `GoogleMap.style` est déclaratif (pris en compte à chaque rebuild), donc
  /// aucune réapplication manuelle n'est nécessaire lors des changements de
  /// thème : le rebuild déclenché par `Theme.of(context)` s'en charge.
  Future<void> _loadMapStyles() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/map_styles/light.json'),
        rootBundle.loadString('assets/map_styles/dark.json'),
      ]);
      if (!mounted) return;
      setState(() {
        _lightMapStyle = results[0];
        _darkMapStyle = results[1];
      });
    } catch (e, stackTrace) {
      LoggerService.w('MapScreen: failed to load map styles', e, stackTrace);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // debugPrint('🗺️ MapScreen: didChangeDependencies');
    // Initialiser la localisation après que le context soit disponible
    if (!_hasInitialized) {
      _hasInitialized = true;
      _initializeLocation();
    } else {
      // Si déjà initialisé, mettre à jour les marqueurs pour refléter les changements de langue/thème
      _updateMarkers();
    }
  }

  Future<void> _loadUserCountry() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final dataSource = ProfileSupabaseDataSource();
        final profile = await dataSource.getProfile(currentUser.uid);
        if (mounted) {
          setState(() {
            _userCountry = profile.currentCountry;
          });
        }
      }
    } catch (e) {
      // debugPrint('Erreur chargement pays utilisateur: $e');
    }
  }

  // void _showLocationError(String message, String settingsLabel) {
  //   if (!mounted) return;
  //
  //   final l10n = AppLocalizations.of(context)!;
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder:
  //         (context) => AlertDialog(
  //           title: Text(l10n.locationRequired),
  //           content: Text(message),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //                 // Retry loading with default position if cancelled
  //                 _loadNearbyMembers(
  //                   _defaultPosition.latitude,
  //                   _defaultPosition.longitude,
  //                 );
  //               },
  //               child: Text(l10n.cancel),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //                 LocationService.instance.openLocationSettings();
  //               },
  //               child: Text(settingsLabel),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    // Mode priv\u00e9 : ne pas charger la position ni les membres
    if (!ref.read(nearbyMembersEnabledProvider)) {
      setState(() {
        _isLoading = false;
        _isReciprocityRestricted = true;
        _nearbyMembers = [];
      });
      _updateMarkers();
      return;
    }

    // final l10n = AppLocalizations.of(context)!;
    // final enableLocationMsg = l10n.enableLocationServices;
    // final permissionDeniedMsg = l10n.locationPermissionDenied;
    // final unableToGetLocationMsg = l10n.unableToGetLocation;
    // final settingsLabel = l10n.settingsLabel;

    setState(() {
      _isLoading = true;
      _isReciprocityRestricted = false; // Reset restriction flag when retrying
    });

    try {
      final position = await LocationService.instance.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _lastPositionUpdate = DateTime.now();
      });

      // debugPrint(
      //   '📍 Position obtenue: ${position.latitude}, ${position.longitude}',
      // );

      // Mettre à jour la localisation de l'utilisateur dans Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // debugPrint('  💾 Updating user location in Firebase...');
        try {
          final dataSource = ProfileSupabaseDataSource();
          await dataSource.updateLocation(
            currentUser.uid,
            position.latitude,
            position.longitude,
          );
          // debugPrint('  ✅ Location updated successfully');
        } catch (e, stackTrace) {
          LoggerService.w(
            'MapScreen: Failed to update user location',
            e,
            stackTrace,
          );
        }
      }

      // Déplacer la caméra vers la position actuelle
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 12),
        );
      }

      // Charger les membres à proximité
      await _loadNearbyMembers(position.latitude, position.longitude);
      await _loadNearbyBusinesses(position.latitude, position.longitude);

      // Démarrer le stream de position et le timer de rafraîchissement
      _startPositionStream();
      _startMembersRefreshTimer();
    } catch (e) {
      // debugPrint('Erreur de localisation: $e');
      if (!mounted) return;

      setState(() {
        _isReciprocityRestricted = true;
        _nearbyMembers = []; // Clear members due to reciprocity
      });
      _updateMarkers();

      // if (e.toString().contains('Location services are disabled')) {
      //   _showLocationError(enableLocationMsg, settingsLabel);
      // } else if (e.toString().contains('denied')) {
      //   _showLocationError(permissionDeniedMsg, settingsLabel);
      // } else {
      //   _showLocationError(unableToGetLocationMsg, settingsLabel);
      // }

      setState(() => _isLoading = false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Démarre l'écoute du stream de position pour suivre les déplacements de l'utilisateur
  void _startPositionStream() {
    // Annuler l'ancien stream s'il existe
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters, // Mise à jour tous les 50m
      ),
    ).listen(
      (Position position) async {
        if (!mounted) return;

        // Mode priv\u00e9 : ne plus envoyer la position \u00e0 Firestore
        if (!ref.read(nearbyMembersEnabledProvider)) return;

        final newPosition = LatLng(position.latitude, position.longitude);

        // Mettre à jour la position actuelle
        setState(() {
          _currentPosition = newPosition;
          _lastPositionUpdate = DateTime.now();
        });

        // Mettre à jour la localisation dans Firebase
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            final dataSource = ProfileSupabaseDataSource();
            await dataSource.updateLocation(
              currentUser.uid,
              position.latitude,
              position.longitude,
            );
          } catch (e) {
            // Ignorer les erreurs de mise à jour silencieusement
          }
        }

        // Mettre à jour les marqueurs pour refléter la nouvelle position
        _updateMarkers();
      },
      onError: (error) {
        // En cas d'erreur du stream, on continue avec la dernière position connue
        debugPrint('Position stream error: $error');
      },
    );
  }

  /// Démarre un timer pour rafraîchir périodiquement la liste des membres à proximité
  void _startMembersRefreshTimer() {
    // Annuler les anciens timers s'ils existent
    _membersRefreshTimer?.cancel();
    _uiRefreshTimer?.cancel();

    // Timer pour rafraîchir les membres
    _membersRefreshTimer = Timer.periodic(
      const Duration(seconds: _membersRefreshIntervalSeconds),
      (_) {
        if (!mounted || _currentPosition == null) return;

        // Rafraîchir les membres à proximité sans bloquer l'UI
        _loadNearbyMembers(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      },
    );

    // Timer pour rafraîchir l'affichage du temps relatif
    _uiRefreshTimer = Timer.periodic(
      const Duration(seconds: _uiRefreshIntervalSeconds),
      (_) {
        if (mounted &&
            (_lastMembersUpdate != null || _lastPositionUpdate != null)) {
          setState(() {}); // Rebuild pour mettre à jour l'affichage du temps
        }
      },
    );
  }

  Future<void> _loadNearbyMembers(double latitude, double longitude) async {
    // Mode priv\u00e9 : ne pas charger les membres \u00e0 proximit\u00e9
    if (!ref.read(nearbyMembersEnabledProvider)) {
      if (mounted) {
        setState(() {
          _nearbyMembers = [];
        });
        _updateMarkers();
      }
      return;
    }

    try {
      final dataSource = ProfileSupabaseDataSource();
      List<ProfileModel> members;

      // Si rayon = -1, recherche globale (monde entier)
      if (_selectedRadius == -1) {
        members = await dataSource.getNearbyProfiles(
          latitude,
          longitude,
          50000.0, // Rayon suffisant pour couvrir le monde entier
        );
      }
      // Si rayon = 0 et pays connu, chercher par pays
      else if (_selectedRadius == 0 && _userCountry != null) {
        members = await dataSource.getProfilesByCountry(_userCountry!);
      } else if (_selectedRadius == 0) {
        // Si pas de pays connu, utiliser un grand rayon par défaut
        members = await dataSource.getNearbyProfiles(
          latitude,
          longitude,
          5000.0,
        );
      } else {
        members = await dataSource.getNearbyProfiles(
          latitude,
          longitude,
          _selectedRadius,
        );
      }

      if (!mounted) return;

      // Get blocked users (users I blocked + users who blocked me)
      final blockedUsers = ref.read(blockedUsersProvider).valueOrNull ?? [];
      final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Filter by presence - STRICT: only show truly active users
      // 1. Online within last 1 hour
      // 2. OR Location updated within last 5 minutes
      // Also filter out blocked users (both ways)
      final now = DateTime.now();
      final filteredMembers =
          members.where((p) {
            // Skip blocked users (I blocked them)
            if (blockedUserIds.contains(p.id)) return false;
            // Skip users who blocked me
            if (currentUserId != null &&
                p.blockedByUserIds.contains(currentUserId)) {
              return false;
            }
            // debugPrint('    📋 Checking ${p.displayName ?? p.id}:');
            // debugPrint('      - isOnline: ${p.isOnline}');
            // debugPrint('      - lastSeen: ${p.lastSeen}');
            // debugPrint('      - locationUpdatedAt: ${p.locationUpdatedAt}');

            if (p.isOnline) {
              // Check if "Online" status is recent (within 1 hour)
              if (p.lastSeen != null) {
                final diffOnline = now.difference(p.lastSeen!);
                // debugPrint(
                //   '      - diffOnline: ${diffOnline.inMinutes} minutes',
                // );
                if (diffOnline.inHours < 1) {
                  // debugPrint('      ✅ PASS: Online within 1 hour');
                  return true;
                }
              }
            }

            if (p.locationUpdatedAt != null) {
              final diffLocation = now.difference(p.locationUpdatedAt!);
              // debugPrint(
              //   '      - diffLocation: ${diffLocation.inSeconds} seconds',
              // );
              // Show members with location updated in last 5 minutes
              if (diffLocation.inMinutes < 5) {
                // debugPrint('      ✅ PASS: Location updated within 5 minutes');
                return true;
              }
            }

            // debugPrint('      ❌ FAIL: Not recently active');
            return false;
          }).toList();

      // debugPrint(
      //   '  ✅ After presence filter: ${filteredMembers.length} members',
      // );

      setState(() {
        _nearbyMembers = filteredMembers;
        _lastMembersUpdate = DateTime.now();
        _updateMarkers();
      });

      // debugPrint(
      //   '  🎯 After filter "$_selectedFilter": ${_getFilteredMembers().length} members',
      // );
    } catch (e, stackTrace) {
      LoggerService.e('MapScreen: Error loading nearby members', e, stackTrace);
      // En cas d'erreur, continuer avec une liste vide
      if (mounted) {
        setState(() {
          _nearbyMembers = [];
          _updateMarkers();
        });
      }
    }
  }

  /// Charge les commerces à proximité (couche optionnelle, pilotée par le
  /// feature flag "annuaire des commerces" et le bouton bascule utilisateur)
  Future<void> _loadNearbyBusinesses(double latitude, double longitude) async {
    if (!ref.read(isBusinessDirectoryEnabledProvider) || !_showBusinesses) {
      return;
    }

    final radiusKm =
        _selectedRadius <= 0 ? 50.0 : _selectedRadius; // "pays"/"monde" → 50km
    await ref
        .read(businessesNotifierProvider.notifier)
        .loadNearbyBusinesses(latitude, longitude, radiusKm: radiusKm);
  }

  /// Vérifie si le cache pour un marqueur est valide (non expiré)
  bool _isCacheValid(String cacheKey) {
    final expiration = _cacheExpiration[cacheKey];
    if (expiration == null) return false;
    return DateTime.now().isBefore(expiration);
  }

  /// Nettoie les entrées de cache expirées
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys =
        _cacheExpiration.entries
            .where((entry) => now.isAfter(entry.value))
            .map((entry) => entry.key)
            .toList();

    for (final key in expiredKeys) {
      _markerCache.remove(key);
      _cacheExpiration.remove(key);
    }
  }

  /// Crée un marqueur circulaire interactif avec photo de profil
  ///
  /// Caractéristiques:
  /// - Forme: Cercle blanc de 48x48 pixels
  /// - Bordure: 3px de couleur selon la catégorie
  /// - Ombre: BoxShadow avec la couleur de catégorie (alpha 0.3), blur 8, offset (0, 4)
  /// - Contenu: Photo de profil pour les users
  Future<BitmapDescriptor> _createCircularMarker(
    String? photoUrl,
    bool isFriend,
    bool isOnline,
    String? displayName, {
    bool isSelected = false,
  }) async {
    const double markerSize = 48.0;
    // Toile plus grande que le disque visible pour laisser respirer l'ombre
    // et l'anneau de sélection sans qu'ils soient rognés sur les bords.
    const double canvasSize = 64.0;
    const double borderWidth = 3.0;

    // Couleur selon le type (vert pour amis, orange pour membres)
    final color = isFriend ? AppColors.secondary : AppColors.primary;

    final cacheKey =
        'circular_${photoUrl?.hashCode ?? displayName?.hashCode ?? 'no_photo'}_${isFriend}_${isOnline}_$isSelected';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    _cleanExpiredCache();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const center = Offset(canvasSize / 2, canvasSize / 2);
    const radius = (markerSize / 2) - borderWidth / 2;
    const innerRadius = radius - borderWidth / 2;

    // 1. Ombre à deux couches pour un effet d'élévation plus doux
    final ambientShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx, center.dy + 6), radius, ambientShadowPaint);

    final colorShadowPaint =
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), radius, colorShadowPaint);

    // 2. Fond blanc du cercle
    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 3. Bordure colorée de 3px
    final borderPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Contenu: Photo de profil ou icône par défaut
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final image = await MarkerImageLoader.load(photoUrl);
        if (image != null) {
          canvas.save();
          final clipPath =
              Path()..addOval(
                Rect.fromCircle(center: center, radius: innerRadius - 1),
              );
          canvas.clipPath(clipPath);

          final srcRect = Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          );
          final dstRect = Rect.fromCircle(
            center: center,
            radius: innerRadius - 1,
          );
          canvas.drawImageRect(image, srcRect, dstRect, Paint());

          canvas.restore();
        } else {
          // Dessiner l'avatar à initiales par défaut
          _drawInitialsAvatar(canvas, center, innerRadius, color, displayName);
        }
      } catch (_) {
        _drawInitialsAvatar(canvas, center, innerRadius, color, displayName);
      }
    } else {
      _drawInitialsAvatar(canvas, center, innerRadius, color, displayName);
    }

    // 5. Indicateur de sélection : anneau coloré séparé du pin par un
    // interstice blanc (effet "focus ring" façon story Instagram)
    if (isSelected) {
      final gapPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 4, gapPaint);

      final selectionPaint =
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius + 7, selectionPaint);
    }

    // 6. Indicateur en ligne (petit point en bas à droite du disque)
    if (isOnline) {
      const indicatorSize = markerSize * 0.25;
      final indicatorX = center.dx + radius - indicatorSize / 2 + 1;
      final indicatorY = center.dy + radius - indicatorSize / 2 + 1;
      final indicatorCenter = Offset(indicatorX, indicatorY);

      // Fond blanc
      final indicatorBgPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawCircle(
        indicatorCenter,
        indicatorSize / 2 + 2,
        indicatorBgPaint,
      );

      // Point vert
      final onlinePaint =
          Paint()
            ..color = AppColors.success
            ..style = PaintingStyle.fill;
      canvas.drawCircle(indicatorCenter, indicatorSize / 2, onlinePaint);
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = descriptor;
    _cacheExpiration[cacheKey] = DateTime.now().add(
      const Duration(minutes: 30),
    );
    return descriptor;
  }

  /// Dessine un avatar à initiales (fond coloré plein + initiales blanches),
  /// utilisé quand un membre n'a pas de photo de profil. Se replie sur la
  /// silhouette générique si aucun nom n'est disponible.
  void _drawInitialsAvatar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    String? displayName,
  ) {
    final initials = _initialsFor(displayName);
    if (initials == null) {
      _drawDefaultPersonIcon(canvas, center, radius, color);
      return;
    }

    final bgPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 1, bgPaint);

    final textSpan = TextSpan(
      text: initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.85,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  /// Extrait 1 ou 2 initiales d'un nom affiché, ou `null` si aucun nom
  /// exploitable n'est disponible
  String? _initialsFor(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    final single = parts.first;
    return single.length >= 2
        ? single.substring(0, 2).toUpperCase()
        : single.toUpperCase();
  }

  /// Dessine l'icône de personne par défaut
  void _drawDefaultPersonIcon(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    // Fond avec la couleur de la catégorie (version claire)
    final bgPaint =
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 1, bgPaint);

    // Icône de personne
    final iconPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final scale = radius / 18;

    // Tête
    canvas.drawCircle(
      Offset(center.dx, center.dy - 4 * scale),
      5 * scale,
      iconPaint,
    );

    // Corps
    final bodyPath =
        Path()
          ..moveTo(center.dx - 8 * scale, center.dy + 10 * scale)
          ..quadraticBezierTo(
            center.dx,
            center.dy + 2 * scale,
            center.dx + 8 * scale,
            center.dy + 10 * scale,
          )
          ..arcToPoint(
            Offset(center.dx - 8 * scale, center.dy + 10 * scale),
            radius: Radius.circular(10 * scale),
            clockwise: false,
          );
    canvas.drawPath(bodyPath, iconPaint);
  }

  // --- Helpers d'affichage ---

  /// Crée un marqueur circulaire pour la position actuelle de l'utilisateur
  ///
  /// Caractéristiques:
  /// - Forme: Cercle blanc de 48x48 pixels
  /// - Bordure: 3px de couleur rouge
  /// - Ombre: BoxShadow avec la couleur rouge (alpha 0.3), blur 8, offset (0, 4)
  /// - Contenu: Emoji 📍
  Future<BitmapDescriptor> _createCurrentUserMarker() async {
    const double markerSize = 48.0;
    const double canvasSize = 76.0;
    const double borderWidth = 3.0;
    const userColor = Color(0xFFE53935);

    const cacheKey = 'current_user_circular';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    _cleanExpiredCache();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const center = Offset(canvasSize / 2, canvasSize / 2);
    const radius = (markerSize / 2) - borderWidth / 2;

    // 0. Halo statique façon "vous êtes ici" (radar)
    final haloPaint =
        Paint()
          ..color = userColor.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 12, haloPaint);

    // 1. Ombre à deux couches pour un effet d'élévation plus doux
    final ambientShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx, center.dy + 6), radius, ambientShadowPaint);

    final colorShadowPaint =
        Paint()
          ..color = userColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), radius, colorShadowPaint);

    // 2. Fond blanc du cercle
    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 3. Bordure colorée de 3px
    final borderPaint =
        Paint()
          ..color = userColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Emoji 📍 au centre
    const textSpan = TextSpan(text: '📍', style: TextStyle(fontSize: 22));
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = descriptor;
    _cacheExpiration[cacheKey] = DateTime.now().add(
      const Duration(minutes: 30),
    );
    return descriptor;
  }

  /// Crée un marqueur de cluster amélioré avec avatars
  Future<BitmapDescriptor> _createClusterMarker(
    int count, {
    List<ProfileModel>? members,
  }) async {
    // Utiliser le nouveau générateur de clusters
    if (members != null && members.isNotEmpty) {
      return ClusterMarkerGenerator.createClusterMarker(members);
    }
    return ClusterMarkerGenerator.createSimpleClusterMarker(count);
  }

  /// Crée un marqueur circulaire pour une ambassade avec emoji 🏛️
  ///
  /// Caractéristiques:
  /// - Forme: Cercle blanc de 48x48 pixels
  /// - Bordure: 3px de couleur bleue
  /// - Ombre: BoxShadow avec la couleur bleue (alpha 0.3), blur 8, offset (0, 4)
  /// - Contenu: Emoji 🏛️
  Future<BitmapDescriptor> _createEmbassyMarker(
    String embassyId,
    bool isSelected,
  ) async {
    const double markerSize = 48.0;
    const double canvasSize = 64.0;
    const double borderWidth = 3.0;
    const embassyColor = Color(0xFF1976D2);

    final cacheKey = 'embassy_circular_$isSelected';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    _cleanExpiredCache();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const center = Offset(canvasSize / 2, canvasSize / 2);
    const radius = (markerSize / 2) - borderWidth / 2;

    // 1. Ombre à deux couches pour un effet d'élévation plus doux
    final ambientShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx, center.dy + 6), radius, ambientShadowPaint);

    final colorShadowPaint =
        Paint()
          ..color = embassyColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), radius, colorShadowPaint);

    // 2. Fond blanc du cercle
    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 3. Bordure colorée de 3px
    final borderPaint =
        Paint()
          ..color = embassyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Emoji 🏛️ au centre
    const textSpan = TextSpan(text: '🏛️', style: TextStyle(fontSize: 22));
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // 5. Indicateur de sélection : anneau bleu séparé par un interstice blanc
    if (isSelected) {
      final gapPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 4, gapPaint);

      final selectionPaint =
          Paint()
            ..color = embassyColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius + 7, selectionPaint);
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = descriptor;
    _cacheExpiration[cacheKey] = DateTime.now().add(
      const Duration(minutes: 30),
    );
    return descriptor;
  }

  /// Met à jour les marqueurs d'ambassades
  Future<void> _updateEmbassyMarkers() async {
    final embassyMarkers = <Marker>{};

    for (final embassy in _embassies) {
      // Skip embassies without valid coordinates
      if (embassy.latitude == null || embassy.longitude == null) continue;
      if (embassy.latitude == 0.0 && embassy.longitude == 0.0) continue;

      final isSelected = _selectedMarkerId == 'embassy_${embassy.id}';
      final icon = await _createEmbassyMarker(embassy.id, isSelected);

      embassyMarkers.add(
        Marker(
          markerId: MarkerId('embassy_${embassy.id}'),
          position: LatLng(embassy.latitude!, embassy.longitude!),
          icon: icon,
          anchor: const Offset(
            0.5,
            0.5,
          ), // Centré pour les marqueurs circulaires
          onTap: () => _showEmbassyDetails(embassy),
        ),
      );
    }

    if (mounted) {
      setState(() => _embassyMarkers = embassyMarkers);
    }
  }

  /// Affiche les détails d'une ambassade dans un bottom sheet
  void _showEmbassyDetails(EmbassyEntity embassy) {
    setState(() => _selectedMarkerId = 'embassy_${embassy.id}');
    _updateEmbassyMarkers(); // Refresh marker to show selected state

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: SheetHandle(),
                  ),

                  // Temporarily closed banner (if applicable)
                  if (embassy.isTemporarilyClosed)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.warningBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.warningColor),
                      ),
                      child: Row(
                        children: [
                          AppIcon(AppIcon.warning,
                            color: context.warningColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              embassy.closureMessage ??
                                  AppLocalizations.of(
                                    context,
                                  )!.temporarilyClosed,
                              style: TextStyle(
                                color: context.textPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Embassy name
                        Text(
                          embassy.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Address
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppIcon(AppIcon.location,
                              color: context.adaptivePrimaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${embassy.address}, ${embassy.city}, ${embassy.country}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Contact info
                        if (embassy.phone != null) ...[
                          _buildContactRow(
                            context,
                            Icons.phone,
                            embassy.phone!,
                            () async {
                              final uri = Uri.parse('tel:${embassy.phone}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (embassy.email != null) ...[
                          _buildContactRow(
                            context,
                            Icons.email,
                            embassy.email!,
                            () async {
                              final uri = Uri.parse('mailto:${embassy.email}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (embassy.website != null) ...[
                          _buildContactRow(
                            context,
                            Icons.language,
                            embassy.website!,
                            () async {
                              final uri = Uri.parse(embassy.website!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Services
                        if (embassy.services.isNotEmpty) ...[
                          Text(
                            AppLocalizations.of(context)!.services,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                embassy.services.map((service) {
                                  return Chip(
                                    label: Text(service),
                                    backgroundColor: context
                                        .adaptivePrimaryColor
                                        .withValues(alpha: 0.1),
                                    labelStyle: TextStyle(
                                      color: context.adaptivePrimaryColor,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Navigation button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/embassies/${embassy.id}');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.adaptivePrimaryColor,
                              foregroundColor: context.onPrimaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.viewFullDetails,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _selectedMarkerId = null);
        _updateEmbassyMarkers(); // Refresh to deselect
      }
    });
  }

  /// Emoji représentatif par catégorie de commerce
  String _emojiForBusinessCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.restaurant:
        return '🍽️';
      case BusinessCategory.commerce:
        return '🛍️';
      case BusinessCategory.services:
        return '🔧';
      case BusinessCategory.sante:
        return '🏥';
      case BusinessCategory.juridique:
        return '⚖️';
      case BusinessCategory.education:
        return '🎓';
      case BusinessCategory.beaute:
        return '💅';
      case BusinessCategory.transport:
        return '🚚';
      case BusinessCategory.immobilier:
        return '🏠';
      case BusinessCategory.artisanat:
        return '🔨';
      case BusinessCategory.technologie:
        return '💻';
      case BusinessCategory.other:
        return '🏪';
    }
  }

  /// Crée un marqueur circulaire pour un commerce
  ///
  /// Caractéristiques:
  /// - Forme: Cercle blanc de 48x48 pixels
  /// - Bordure: 3px teal (distincte de l'orange membres et du bleu ambassades)
  /// - Contenu: Emoji selon la catégorie du commerce
  /// - Badge ⭐ en haut à droite si le commerce est boosté
  Future<BitmapDescriptor> _createBusinessMarker(
    BusinessCategory category,
    bool isBoosted,
    bool isSelected,
  ) async {
    const double markerSize = 48.0;
    const double canvasSize = 64.0;
    const double borderWidth = 3.0;
    const businessColor = Color(0xFF00897B);

    final cacheKey =
        'business_circular_${category.name}_${isBoosted}_$isSelected';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    _cleanExpiredCache();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const center = Offset(canvasSize / 2, canvasSize / 2);
    const radius = (markerSize / 2) - borderWidth / 2;

    // 1. Ombre à deux couches pour un effet d'élévation plus doux
    final ambientShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx, center.dy + 6), radius, ambientShadowPaint);

    final colorShadowPaint =
        Paint()
          ..color = businessColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), radius, colorShadowPaint);

    // 2. Fond blanc du cercle
    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 3. Bordure teal de 3px
    final borderPaint =
        Paint()
          ..color = businessColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Emoji de catégorie au centre
    final textSpan = TextSpan(
      text: _emojiForBusinessCategory(category),
      style: const TextStyle(fontSize: 22),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // 5. Indicateur de sélection : anneau teal séparé par un interstice blanc
    if (isSelected) {
      final gapPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 4, gapPaint);

      final selectionPaint =
          Paint()
            ..color = businessColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius + 7, selectionPaint);
    }

    // 6. Badge "boosté" (petite étoile en haut à droite du disque)
    if (isBoosted) {
      final badgeCenter = Offset(
        center.dx + radius - 6,
        center.dy - radius + 6,
      );
      final badgeBgPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 9, badgeBgPaint);

      final badgePaint =
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 7, badgePaint);

      const starSpan = TextSpan(
        text: '⭐',
        style: TextStyle(fontSize: 10),
      );
      final starPainter = TextPainter(
        text: starSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      starPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - starPainter.width / 2,
          badgeCenter.dy - starPainter.height / 2,
        ),
      );
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = descriptor;
    _cacheExpiration[cacheKey] = DateTime.now().add(
      const Duration(minutes: 30),
    );
    return descriptor;
  }

  /// Met à jour les marqueurs de commerces
  Future<void> _updateBusinessMarkers() async {
    if (!_showBusinesses || !ref.read(isBusinessDirectoryEnabledProvider)) {
      if (mounted && _businessMarkers.isNotEmpty) {
        setState(() => _businessMarkers = {});
      }
      return;
    }

    final businessMarkers = <Marker>{};

    for (final business in _businesses) {
      if (business.latitude == null || business.longitude == null) continue;
      if (business.latitude == 0.0 && business.longitude == 0.0) continue;

      final isSelected = _selectedMarkerId == 'business_${business.id}';
      final icon = await _createBusinessMarker(
        business.category,
        business.isBoostActive,
        isSelected,
      );

      businessMarkers.add(
        Marker(
          markerId: MarkerId('business_${business.id}'),
          position: LatLng(business.latitude!, business.longitude!),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showBusinessDetails(business),
        ),
      );
    }

    if (mounted) {
      setState(() => _businessMarkers = businessMarkers);
    }
  }

  /// Affiche les détails d'un commerce dans un bottom sheet
  void _showBusinessDetails(BusinessEntity business) {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _selectedMarkerId = 'business_${business.id}');
    _updateBusinessMarkers(); // Refresh marker to show selected state

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: SheetHandle(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + badge vérifié
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                            ),
                            if (business.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.verifiedBadge,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Catégorie
                        Text(
                          business.category.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Note et avis
                        if (business.reviewCount > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                business.averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${business.reviewCount} ${l10n.reviews})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),

                        // Adresse
                        if (business.address != null ||
                            business.fullLocation != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppIcon(AppIcon.location,
                                color: context.adaptivePrimaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [
                                    business.address,
                                    business.fullLocation,
                                  ].where((s) => s != null && s.isNotEmpty).join(
                                    ', ',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),

                        // Navigation button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(
                                '/businesses/${business.id}',
                                extra: business,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.adaptivePrimaryColor,
                              foregroundColor: context.onPrimaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l10n.viewFullDetails,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _selectedMarkerId = null);
        _updateBusinessMarkers(); // Refresh to deselect
      }
    });
  }

  /// Helper method to build a contact row
  Widget _buildContactRow(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: context.adaptivePrimaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _updateMarkers() {
    // Debounce pour éviter les mises à jour trop fréquentes
    _updateMarkersDebounce?.cancel();
    _updateMarkersDebounce = Timer(_updateMarkersDebounceDelay, () {
      _updateMarkersAsync();
    });
  }

  Future<void> _updateMarkersAsync() async {
    // Versioning pour annuler les mises à jour obsolètes
    _markersVersion++;
    final currentVersion = _markersVersion;
    final l10n = AppLocalizations.of(context)!;
    final markers = <Marker>{};

    // Ajouter le marqueur de position actuelle (petit point rouge discret)
    if (_currentPosition != null) {
      final currentUserIcon = await _createCurrentUserMarker();
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          icon: currentUserIcon,
          anchor: const Offset(
            0.5,
            0.5,
          ), // Centré car c'est un point, pas un pin
          infoWindow: InfoWindow(title: l10n.youAreHere),
          zIndexInt: 0, // En dessous des autres marqueurs
        ),
      );
    }

    // Clustering ou Affichage individuel
    final filteredMembers = _getFilteredMembers();

    // Si zoom < 14, on active le clustering
    if (_currentZoom < 14) {
      final Map<Point<int>, List<ProfileModel>> clusters = {};
      // Taille de la grille en degrés (approx) : 70px / 2^zoom
      final double gridSize = 70.0 / pow(2, _currentZoom);

      for (final member in filteredMembers) {
        if (member.latitude != null && member.longitude != null) {
          final int x = (member.latitude! / gridSize).floor();
          final int y = (member.longitude! / gridSize).floor();
          final key = Point(x, y);
          clusters.putIfAbsent(key, () => []).add(member);
        }
      }

      for (final entry in clusters.entries) {
        final clusterMembers = entry.value;
        if (clusterMembers.isEmpty) continue;

        if (clusterMembers.length == 1) {
          // Un seul membre : afficher le marqueur normal
          await _addSingleMarker(markers, clusterMembers.first, ref);
        } else {
          // Cluster : afficher un marqueur de groupe
          // Position moyenne
          double latSum = 0;
          double lngSum = 0;
          for (final m in clusterMembers) {
            latSum += m.latitude!;
            lngSum += m.longitude!;
          }
          final center = LatLng(
            latSum / clusterMembers.length,
            lngSum / clusterMembers.length,
          );

          final icon = await _createClusterMarker(
            clusterMembers.length,
            members: clusterMembers,
          );

          markers.add(
            Marker(
              markerId: MarkerId('cluster_${entry.key.x}_${entry.key.y}'),
              position: center,
              icon: icon,
              onTap: () {
                // Zoom sur le cluster
                _controller.future.then((c) {
                  c.animateCamera(
                    CameraUpdate.newLatLngZoom(center, _currentZoom + 2),
                  );
                });
              },
            ),
          );
        }
      }
    } else {
      // Zoom élevé : afficher tous les marqueurs individuellement
      for (final member in filteredMembers) {
        await _addSingleMarker(markers, member, ref);
      }
    }

    // Vérifier que cette mise à jour est toujours la plus récente
    if (mounted && currentVersion == _markersVersion) {
      setState(() => _markers = markers);
    }
  }

  Future<void> _addSingleMarker(
    Set<Marker> markers,
    ProfileModel member,
    WidgetRef ref,
  ) async {
    if (member.latitude != null && member.longitude != null) {
      final l10n = AppLocalizations.of(context)!;

      // Vérifier si c'est un ami
      final friendshipStatus = ref.read(friendshipStatusProvider(member.id));
      final isFriend = friendshipStatus == FriendshipStatus.friends;
      final isSelected = member.id == _selectedMarkerId;

      // Créer le marqueur circulaire avec photo de profil
      final icon = await _createCircularMarker(
        member.photoUrl,
        isFriend,
        member.isOnline,
        member.displayName,
        isSelected: isSelected,
      );

      // Construire le snippet pour l'accessibilité
      final accessibilitySnippet = [
        if (member.profession != null && member.profession!.isNotEmpty)
          member.profession,
        member.isOnline ? l10n.online : null,
        isFriend ? l10n.friend : null,
      ].where((s) => s != null).join(' - ');

      markers.add(
        Marker(
          markerId: MarkerId(member.id),
          position: LatLng(member.latitude!, member.longitude!),
          icon: icon,
          anchor: const Offset(
            0.5,
            0.5,
          ), // Centré pour les marqueurs circulaires
          onTap: () => _showMemberDetails(member),
          // InfoWindow pour l'accessibilité (lecteurs d'écran)
          infoWindow: InfoWindow(
            title: member.displayName ?? l10n.member,
            snippet:
                accessibilitySnippet.isNotEmpty ? accessibilitySnippet : null,
          ),
        ),
      );
    }
  }

  bool _matchesFilter(String? profession, String filterKey) {
    // debugPrint(
    //   '  🔍 _matchesFilter: profession="$profession", filterKey="$filterKey"',
    // );
    if (filterKey == 'all') {
      // debugPrint('    ✅ Filter is "all", returning true');
      return true;
    }
    if (profession == null || profession.isEmpty) {
      // debugPrint('    ❌ Profession is null/empty, returning false');
      return false;
    }

    final p = profession.toLowerCase();

    switch (filterKey) {
      case 'entrepreneurs':
        return p.contains('entrepreneur') ||
            p.contains('commercant') ||
            p.contains('business') ||
            p.contains('fondateur') ||
            p.contains('ceo') ||
            p.contains('gérant');
      case 'students':
        return p.contains('etudiant') ||
            p.contains('student') ||
            p.contains('élève') ||
            p.contains('stagiaire') ||
            p.contains('apprenant');
      case 'professionals':
        return p.contains('ingenieur') ||
            p.contains('medecin') ||
            p.contains('avocat') ||
            p.contains('enseignant') ||
            p.contains('journaliste') ||
            p.contains('informaticien') ||
            p.contains('comptable') ||
            p.contains('banquier') ||
            p.contains('consultant') ||
            p.contains('fonctionnaire') ||
            p.contains('diplomate') ||
            p.contains('chercheur') ||
            p.contains('humanitaire');
      case 'artists':
        return p.contains('artiste') ||
            p.contains('artist') ||
            p.contains('chanteur') ||
            p.contains('musicien') ||
            p.contains('peintre') ||
            p.contains('acteur') ||
            p.contains('écrivain') ||
            p.contains('auteur') ||
            p.contains('designer') ||
            p.contains('créateur') ||
            p.contains('artisan');
      default:
        return true;
    }
  }

  /// Applique l'ordre choisi (§7e). Le tri par distance suppose une
  /// position connue ; sans elle, on garde l'ordre d'arrivée plutôt que
  /// d'inventer un classement.
  List<ProfileModel> _applySort(List<ProfileModel> membres) {
    final liste = List<ProfileModel>.from(membres);
    switch (_sort) {
      case _MemberSort.nearest:
        if (_currentPosition == null) return liste;
        liste.sort((a, b) {
          final da = _distanceTo(a);
          final db = _distanceTo(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      case _MemberSort.name:
        liste.sort(
          (a, b) => (a.displayName ?? '').toLowerCase().compareTo(
            (b.displayName ?? '').toLowerCase(),
          ),
        );
    }
    return liste;
  }

  /// Distance en km jusqu'à un membre, ou `null` si l'un des deux points
  /// manque.
  double? _distanceTo(ProfileModel membre) {
    final pos = _currentPosition;
    if (pos == null) return null;
    final lat = membre.latitude;
    final lng = membre.longitude;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  List<ProfileModel> _getFilteredMembers() {
    return _nearbyMembers.where((member) {
      return _matchesFilter(member.profession, _selectedFilter);
    }).toList();
  }

  void _showMemberDetails(ProfileModel member) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barre de glissement
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Photo de profil centrée et agrandie
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.adaptivePrimaryColor,
                  ),
                  child:
                      member.photoUrl != null &&
                              member.photoUrl!.trim().isNotEmpty
                          ? ClipOval(
                            child: Image.network(
                              member.photoUrl!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder:
                                  (_, __, ___) => AppIcon(AppIcon.person,
                                    color: context.surfaceColor,
                                    size: 50,
                                  ),
                            ),
                          )
                          : AppIcon(AppIcon.person,
                            color: context.surfaceColor,
                            size: 50,
                          ),
                ),
                const SizedBox(height: 16),

                // Nom
                Text(
                  (member.displayName != null &&
                          member.displayName!.trim().isNotEmpty)
                      ? member.displayName!
                      : l10n.member,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Profession
                if (member.profession != null &&
                    member.profession!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      member.profession!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                  ),
                ],

                // Localisation
                if (member.currentCity != null &&
                    member.currentCity!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        AppIcon.location,
                        size: 16,
                        color: context.textTertiaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        member.currentCity!,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ],

                // Bio
                if (member.bio != null && member.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      member.bio!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // Compétences
                if (member.skills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children:
                        member.skills
                            .take(4)
                            .map(
                              (skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: context.adaptiveSecondaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.adaptiveSecondaryColor
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  skill,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.adaptiveSecondaryColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(
                            '/profile/${member.id}',
                            extra: member.toEntity(),
                          );
                        },
                        icon: AppIcon(AppIcon.person, color: context.adaptivePrimaryColor),
                        label: Text(l10n.viewProfile),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: context.adaptivePrimaryColor),
                          foregroundColor: context.adaptivePrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Consumer(
                      builder: (context, ref, child) {
                        final friendshipStatus = ref.watch(
                          friendshipStatusProvider(member.id),
                        );

                        if (friendshipStatus != FriendshipStatus.friends) {
                          return const SizedBox.shrink();
                        }

                        return Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final conversation = await ref
                                  .read(createConversationProvider.notifier)
                                  .createIndividual(member.id);
                              if (conversation != null && context.mounted) {
                                context.push(
                                  '/messages/${conversation.id}',
                                  extra: {
                                    'name': member.displayName,
                                    'imageUrl': member.photoUrl,
                                    'otherUserId': member.id,
                                    'isGroup': false,
                                  },
                                );
                              }
                            },
                            icon: AppIcon(AppIcon.chatBubble, color: context.warningColor),
                            label: Text(l10n.message),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.adaptivePrimaryColor,
                              foregroundColor: context.onPrimaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Espace pour le safe area en bas
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
    );
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
      _updateMarkers();
    });
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _selectedRadius = radius;
    });
    // Recharger les membres et les commerces avec le nouveau rayon
    if (_currentPosition != null) {
      _loadNearbyMembers(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      _loadNearbyBusinesses(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }
  }

  void _showRadiusSelector() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.radar,
                      color: context.adaptivePrimaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.searchRadius,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.searchRadiusDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      _radiusOptions.map((radius) {
                        final isSelected = _selectedRadius == radius;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _onRadiusChanged(radius);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? context.adaptivePrimaryColor
                                      : context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? context.adaptivePrimaryColor
                                        : context.borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow:
                                  isSelected && !context.isDarkMode
                                      ? [
                                        BoxShadow(
                                          color: context.adaptivePrimaryColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                      : null,
                            ),
                            child: Text(
                              radius == -1
                                  ? l10n.everywhere
                                  : radius == 0
                                  ? l10n.wholeCountry
                                  : '${radius.toInt()} km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? context.onPrimaryColor
                                        : context.textPrimaryColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
    // Rafraîchir les marqueurs seulement si le changement de zoom est significatif
    // (changement de catégorie de taille)
    final newCategory = _currZoomLevelCategory();
    if (newCategory != _lastZoomCategory) {
      _lastZoomCategory = newCategory;
      _updateMarkers();
    }
  }

  int _currZoomLevelCategory() {
    if (_currentZoom < 10) return 0;
    if (_currentZoom < 14) return 1;
    return 2;
  }

  /// Recul de 3 crans depuis la carte « zone vide » — assez pour changer de
  /// catégorie de zoom et déclencher un rechargement des marqueurs.
  Future<void> _zoomOut() async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.zoomTo((_currentZoom - 3).clamp(3.0, 20.0)),
    );
  }

  /// Feuille de légende ouverte par le bouton « ? » de la barre d'actions
  /// (remplace la légende flottante et son calcul de position conditionnel).
  void _showLegendSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.information,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const MapLegend(),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouton « calques » de l'en-tête unifié (§7d) : ouvre la feuille de
  /// bascule des couches (membres / commerces / ambassades).
  Widget _buildLayersButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLayersSheet(context),
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              context.isDarkMode
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Icon(Icons.layers_outlined, color: context.textPrimaryColor),
      ),
    );
  }

  /// Feuille « Calques » (§7d) : consolide les bascules de couches auparavant
  /// dispersées dans l'AppBar (membres, commerces, ambassades).
  void _showLayersSheet(BuildContext context) {
    final businessDirectoryEnabled =
        ref.read(isBusinessDirectoryEnabledProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Calques', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Membres (état privé partagé, via provider).
                Consumer(
                  builder: (c, r, _) {
                    final on = r.watch(nearbyMembersEnabledProvider);
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.people_alt_outlined),
                      title: const Text('Membres'),
                      value: on,
                      onChanged: (v) => r
                          .read(nearbyMembersEnabledProvider.notifier)
                          .setEnabled(v),
                    );
                  },
                ),
                if (businessDirectoryEnabled)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.storefront_outlined),
                    title: const Text('Commerces'),
                    value: _showBusinesses,
                    onChanged: (v) {
                      _toggleBusinessesLayer(v);
                      setModalState(() {});
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.account_balance_outlined),
                  title: const Text('Ambassades'),
                  value: _showEmbassies,
                  onChanged: (v) {
                    setState(() => _showEmbassies = v);
                    setModalState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bascule la couche commerces (avec chargement paresseux + persistance),
  /// logique reprise de l'ancien bouton de l'AppBar.
  Future<void> _toggleBusinessesLayer(bool newValue) async {
    setState(() => _showBusinesses = newValue);
    await PreferencesService.instance.setMapBusinessesLayerVisible(newValue);
    if (newValue && _currentPosition != null) {
      await _loadNearbyBusinesses(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }
    _updateBusinessMarkers();
  }

  /// Petit bouton flottant pour rouvrir le panneau "Membres à proximité"
  /// une fois masqué complètement.
  /// Écran assumé sans localisation (8c) : réciprocité expliquée, trois
  /// garanties, CTA d'activation, puis repli « explorer autrement ».
  Widget _buildNoLocationScreen(AppLocalizations l10n, bool nearbyEnabled) {
    final accent = context.adaptivePrimaryColor;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewPadding.bottom + 100,
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              nearbyEnabled
                  ? Icons.location_off_outlined
                  : Icons.visibility_off_outlined,
              size: 46,
              color: accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            nearbyEnabled
                ? l10n.locationRequiredToSeeMembers
                : l10n.nearbyMembersDisabled,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.locationReciprocity,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          _guaranteeRow(Icons.my_location, l10n.locationGuarantee1),
          _guaranteeRow(Icons.toggle_off_outlined, l10n.locationGuarantee2),
          _guaranteeRow(Icons.block_outlined, l10n.locationGuarantee3),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: context.onPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: nearbyEnabled
                  ? _initializeLocation
                  : () => ref
                      .read(nearbyMembersEnabledProvider.notifier)
                      .setEnabled(true),
              icon: const Icon(Icons.my_location, size: 20),
              label: Text(
                l10n.mapEnable,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.exploreOtherwise.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: context.textTertiaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _exploreCard(
                  Icons.account_balance,
                  l10n.embassies,
                  () => context.push('/embassies'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _exploreCard(
                  Icons.groups_outlined,
                  l10n.groupsTitle,
                  () => context.go('/groups'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guaranteeRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.adaptivePrimaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exploreCard(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: context.adaptivePrimaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne de membre dans la feuille : avatar 44 + nom + « métier · ville »,
  /// bouton d'action 40 px (ouvre la fiche membre).
  Widget _buildMemberSheetItem(ProfileModel member, AppLocalizations l10n) {
    final subtitle = [
      member.profession,
      member.currentCity,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' · ');

    return InkWell(
      onTap: () => _showMemberDetails(member),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: member.photoUrl != null
                  ? Image.network(
                      member.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => AppIcon(
                        AppIcon.person,
                        color: context.onPrimaryColor,
                      ),
                    )
                  : AppIcon(AppIcon.person, color: context.onPrimaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName ?? l10n.member,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showMemberDetails(member),
                icon: AppIcon(
                  AppIcon.chatBubble,
                  size: 18,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override // Correction: override build method signature match
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nearbyEnabled = ref.watch(nearbyMembersEnabledProvider);

    // R\u00e9agir au toggle "Membres \u00e0 proximit\u00e9"
    ref.listen<bool>(nearbyMembersEnabledProvider, (prev, next) {
      if (prev == next) return;
      if (next) {
        // R\u00e9activ\u00e9 : reinitialiser la position et recharger les membres
        _initializeLocation();
        _startPositionStream();
        _startMembersRefreshTimer();
      } else {
        // D\u00e9sactiv\u00e9 : couper le suivi et purger l'\u00e9tat local
        _membersRefreshTimer?.cancel();
        _membersRefreshTimer = null;
        _uiRefreshTimer?.cancel();
        _uiRefreshTimer = null;
        _positionStreamSubscription?.cancel();
        _positionStreamSubscription = null;
        if (mounted) {
          setState(() {
            _nearbyMembers = [];
            _isReciprocityRestricted = true;
            _isLoading = false;
          });
          _updateMarkers();
        }
      }
    });

    // Watch embassies data
    final embassiesAsync = ref.watch(embassiesListProvider);
    embassiesAsync.whenData((embassies) {
      if (_embassies != embassies) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _embassies = embassies);
            _updateEmbassyMarkers();
          }
        });
      }
    });

    // Watch businesses data (couche optionnelle, pilotée par feature flag)
    final businessDirectoryEnabled = ref.watch(
      isBusinessDirectoryEnabledProvider,
    );
    if (businessDirectoryEnabled) {
      final businessesAsync = ref.watch(businessesNotifierProvider);
      businessesAsync.whenData((businesses) {
        if (_businesses != businesses) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _businesses = businesses);
              _updateBusinessMarkers();
            }
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          // (Bascules de couches deplacees vers le bouton calques de l'en-tete -- refonte 7d.)
          // Bouton de sélection du rayon
          GestureDetector(
            onTap: _showRadiusSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.adaptivePrimaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radar,
                    color: context.adaptivePrimaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedRadius == -1
                        ? l10n.everywhereLabel
                        : _selectedRadius == 0
                        ? l10n.countryLabel
                        : '${_selectedRadius.toInt()} km',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.my_location, color: context.textPrimaryColor),
            ),
            onPressed: _initializeLocation,
          ),
          // Légende dans un bouton « ? » (supprime le calcul bottom: conditionnel
          // de la légende flottante — refonte 7d).
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: context.textPrimaryColor,
              ),
            ),
            tooltip: l10n.information,
            onPressed: () => _showLegendSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          !_mapsInitialized
              ? const Center(child: CircularProgressIndicator())
              // 8c : écran dédié sans localisation (réciprocité + garanties +
              // repli « explorer autrement »), au lieu d'un bandeau sur une
              // carte inutilisable.
              : _isReciprocityRestricted
              ? _buildNoLocationScreen(l10n, nearbyEnabled)
              : Stack(
                children: [
                  // Mode liste (§7e) : la carte n'est pas chargée du tout.
                  // Sur un forfait compté, ne pas télécharger de tuiles vaut
                  // mieux que les télécharger et les cacher.
                  if (_listOnly)
                    Positioned.fill(
                      child: Container(
                        color: context.surfaceVariantColor,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 32,
                              color: context.textTertiaryColor,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: context.borderColor),
                              ),
                              child: Text(
                                'tuiles allégées',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Carte non chargée · données réduites',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.textTertiaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _listOnly = false),
                              icon: const Icon(Icons.open_in_full, size: 16),
                              label: const Text('Plein écran'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.textPrimaryColor,
                                side: BorderSide(color: context.borderColor),
                                backgroundColor: context.surfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                  // Google Map
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _defaultPosition,
                      zoom: 12,
                    ),
                    style: context.isDarkMode ? _darkMapStyle : _lightMapStyle,
                    onCameraMove: _onCameraMove,
                    onTap: (_) {
                      if (_selectedMarkerId != null) {
                        setState(() => _selectedMarkerId = null);
                        _updateMarkers();
                      }
                    },
                    onMapCreated: (controller) {
                      if (!_controller.isCompleted) {
                        _controller.complete(controller);
                      }
                      // Move camera to current position if available
                      if (_currentPosition != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentPosition!, 12),
                        );
                      }
                    },
                    markers: {
                      ..._markers,
                      if (_showEmbassies) ..._embassyMarkers,
                      ..._businessMarkers,
                    },
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),

                  // Loading indicator
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.adaptivePrimaryColor,
                        ),
                      ),
                    ),

                  // Zone vide (maquette 2c) : la carte chargée ne montre
                  // aucun marqueur. Sans ça, l'utilisateur ne sait pas si
                  // c'est vide ou cassé, et n'a aucune sortie.
                  if (!_isLoading &&
                      !_isSearchResultsOpen &&
                      _markers.isEmpty &&
                      _businessMarkers.isEmpty &&
                      (!_showEmbassies || _embassyMarkers.isEmpty))
                    Positioned(
                      top: 150,
                      left: 24,
                      right: 24,
                      child: _EmptyAreaCard(
                        onZoomOut: _zoomOut,
                        onShowEmbassies: _showEmbassies
                            ? null
                            : () => setState(() => _showEmbassies = true),
                      ),
                    ),

                  // Filter Chips — masqués tant que la liste de résultats de
                  // recherche est ouverte (elle descend jusqu'à ~top:296).
                  if (!_isSearchResultsOpen)
                  Positioned(
                    top: 76,
                    left: 16,
                    right: 16,
                    child:
                        _isReciprocityRestricted
                            ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.warningBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.warningColor),
                                boxShadow:
                                    context.isDarkMode
                                        ? null
                                        : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    nearbyEnabled
                                        ? Icons.location_disabled
                                        : Icons.visibility_off,
                                    color: context.warningColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      nearbyEnabled
                                          ? l10n.locationRequiredToSeeMembers
                                          : l10n.nearbyMembersDisabled,
                                      style: TextStyle(
                                        color: context.textPrimaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: nearbyEnabled
                                        ? _initializeLocation
                                        : () => ref
                                            .read(
                                              nearbyMembersEnabledProvider
                                                  .notifier,
                                            )
                                            .setEnabled(true),
                                    child: Text(l10n.mapEnable),
                                  ),
                                ],
                              ),
                            )
                            : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    _filterKeys
                                        .map(
                                          (filterKey) => Padding(
                                            padding: EdgeInsets.only(
                                              right:
                                                  filterKey != _filterKeys.last
                                                      ? 8
                                                      : 0,
                                            ),
                                            child: GestureDetector(
                                              onTap:
                                                  () => _onFilterSelected(
                                                    filterKey,
                                                  ),
                                              child: _FilterChip(
                                                label: _getFilterLabel(
                                                  filterKey,
                                                  l10n,
                                                ),
                                                isSelected:
                                                    _selectedFilter ==
                                                    filterKey,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                  ),

                  // Barre de recherche de lieu — peinte APRÈS les chips :
                  // sa liste de suggestions se déploie vers le bas et doit
                  // recouvrir les filtres de profession, pas l'inverse.
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    // En-tête unifié (§7d) : recherche + bouton « calques » sur
                    // une même ligne. Les filtres profession restent la rangée
                    // juste en dessous (top:76). Le bouton calques est aligné en
                    // haut pour ne pas suivre le déroulant de recherche.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MapSearchBar(
                            onResultsVisibilityChanged: (open) {
                              if (_isSearchResultsOpen != open) {
                                setState(() => _isSearchResultsOpen = open);
                              }
                            },
                            onPlaceSelected: (latLng, _) {
                              _controller.future.then((c) {
                                c.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 14),
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildLayersButton(context),
                      ],
                    ),
                  ),

                  // (La légende flottante a migré vers le bouton « ? » de la
                  // barre d'actions — plus de calcul bottom: conditionnel.)

                  // Panneau membres : feuille à trois positions (18/45/92 %)
                  // — refonte 7d, remplace le panneau ancré + chip de réouverture.
                  if (!_isReciprocityRestricted)
                    DraggableScrollableSheet(
                      initialChildSize: 0.18,
                      minChildSize: 0.18,
                      maxChildSize: 0.92,
                      snap: true,
                      snapSizes: const [0.18, 0.45, 0.92],
                      builder: (context, scrollController) {
                        final members = _applySort(_getFilteredMembers());
                        return Container(
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow:
                                context.isDarkMode
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, -4),
                                      ),
                                    ],
                          ),
                          child: Column(
                            children: [
                              // Poignée + en-tête (fixes).
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 10, 20, 10),
                                child: Column(
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: context.borderColor,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.membersNearby,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  AppIcon(
                                                    AppIcon.groups,
                                                    size: 12,
                                                    color: context
                                                        .textTertiaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      _formatRelativeTime(
                                                        _lastMembersUpdate,
                                                        l10n,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: context
                                                            .textTertiaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.my_location,
                                                    size: 12,
                                                    color: context
                                                        .textTertiaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      _formatRelativeTime(
                                                        _lastPositionUpdate,
                                                        l10n,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: context
                                                            .textTertiaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.surfaceVariantColor,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            l10n.members(members.length),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  context.adaptivePrimaryColor,
                                            ),
                                          ),
                                        ),
                                        // Bascule Carte / Liste (§7e).
                                        const SizedBox(width: 4),
                                        TextButton.icon(
                                          onPressed: () => setState(
                                            () => _listOnly = !_listOnly,
                                          ),
                                          icon: Icon(
                                            _listOnly
                                                ? Icons.map_outlined
                                                : Icons.list,
                                            size: 16,
                                            color: context.textSecondaryColor,
                                          ),
                                          label: Text(
                                            _listOnly ? 'Carte' : 'Liste',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: context.textSecondaryColor,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        // Ordre de la liste (§7e) : il était
                                        // appliqué sans être dit ni modifiable.
                                        const SizedBox(width: 4),
                                        TextButton.icon(
                                          onPressed: () => setState(() {
                                            _sort = _sort == _MemberSort.nearest
                                                ? _MemberSort.name
                                                : _MemberSort.nearest;
                                          }),
                                          icon: Icon(
                                            Icons.swap_vert,
                                            size: 16,
                                            color:
                                                context.adaptivePrimaryColor,
                                          ),
                                          label: Text(
                                            _sort == _MemberSort.nearest
                                                ? 'Les plus proches'
                                                : 'Par nom',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  context.adaptivePrimaryColor,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: context.borderColor),
                              // Liste verticale : la faire défiler redimensionne
                              // la feuille (scrollController de la sheet).
                              Expanded(
                                child: members.isEmpty
                                    ? ListView(
                                        controller: scrollController,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            child: Center(
                                              child: Text(
                                                l10n.noMembersNearby,
                                                style: TextStyle(
                                                  color: context
                                                      .textTertiaryColor,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.separated(
                                        controller: scrollController,
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(context)
                                                  .viewPadding
                                                  .bottom +
                                              90,
                                        ),
                                        itemCount: members.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          indent: 76,
                                          color: context.borderColor,
                                        ),
                                        itemBuilder: (context, index) =>
                                            _buildMemberSheetItem(
                                          members[index],
                                          l10n,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({required this.label, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? context.adaptivePrimaryColor : context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? context.onPrimaryColor : context.textSecondaryColor,
        ),
      ),
    );
  }
}

/// Carte de récupération affichée quand la vue courante ne contient aucun
/// marqueur (maquette 2c). Elle nomme l'état et propose deux sorties plutôt
/// que de laisser une carte muette.
class _EmptyAreaCard extends StatelessWidget {
  final VoidCallback onZoomOut;

  /// `null` quand la couche ambassades est déjà active — proposer de
  /// l'activer une deuxième fois n'aiderait pas.
  final VoidCallback? onShowEmbassies;

  const _EmptyAreaCard({
    required this.onZoomOut,
    this.onShowEmbassies,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 20,
                color: context.textTertiaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mapEmptyAreaTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.mapEmptyAreaBody,
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onZoomOut,
                  icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                  label: Text(l10n.mapZoomOut),
                ),
              ),
              if (onShowEmbassies != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onShowEmbassies,
                    child: Text(l10n.mapShowEmbassies),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Ordre de la liste des membres proches (§7e).
enum _MemberSort { nearest, name }
