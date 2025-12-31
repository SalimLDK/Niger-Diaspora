import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../friends/domain/repositories/friend_repository.dart';
import '../../../embassies/presentation/providers/embassies_provider.dart';
import '../../../embassies/domain/entities/embassy_entity.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../utils/marker_painter.dart';
import '../utils/cluster_marker_generator.dart';
import '../widgets/map_legend.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // Position par défaut: Niamey, Niger
  static const LatLng _defaultPosition = LatLng(13.5116, 2.1254);

  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  Set<Marker> _embassyMarkers = {};
  List<ProfileModel> _nearbyMembers = [];
  List<EmbassyEntity> _embassies = [];
  String _selectedFilter = 'all';
  double _selectedRadius = 50; // Rayon par défaut en km
  String? _userCountry; // Pays de l'utilisateur pour le filtre "Pays entier"
  bool _isLoading = true;

  bool _mapsInitialized = false;
  bool _isReciprocityRestricted = false;

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

  // Options de rayon disponibles (en km) - 0 = pays entier (aucune limite)
  final List<double> _radiusOptions = [10, 25, 50, 100, 200, 500, 0];

  final Map<String, BitmapDescriptor> _markerCache = {};

  bool _hasInitialized = false;

  // Stream et timer pour mise à jour automatique
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _membersRefreshTimer;
  Timer? _uiRefreshTimer;
  static const int _membersRefreshIntervalSeconds = 45; // Rafraîchir les membres toutes les 45s
  static const int _distanceFilterMeters = 50; // Mise à jour position tous les 50m
  static const int _uiRefreshIntervalSeconds = 10; // Rafraîchir l'affichage du temps toutes les 10s

  // Indicateur de dernière mise à jour
  DateTime? _lastMembersUpdate;
  DateTime? _lastPositionUpdate;

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
    _positionStreamSubscription?.cancel();
    _membersRefreshTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _controller.future.then((c) => c.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // debugPrint('🗺️ MapScreen: initState');
    _mapsInitialized = true; // Already initialized in main.dart
    _loadUserCountry();
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
        final dataSource = ProfileRemoteDataSourceImpl();
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

  void _showLocationError(String message, String settingsLabel) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Required'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Retry loading with default position if cancelled
                  _loadNearbyMembers(
                    _defaultPosition.latitude,
                    _defaultPosition.longitude,
                  );
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  LocationService.instance.openLocationSettings();
                },
                child: Text(settingsLabel),
              ),
            ],
          ),
    );
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final enableLocationMsg = l10n.enableLocationServices;
    final permissionDeniedMsg = l10n.locationPermissionDenied;
    final unableToGetLocationMsg = l10n.unableToGetLocation;
    final settingsLabel = l10n.settingsLabel;

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
          final dataSource = ProfileRemoteDataSourceImpl();
          await dataSource.updateLocation(
            currentUser.uid,
            position.latitude,
            position.longitude,
          );
          // debugPrint('  ✅ Location updated successfully');
        } catch (e) {
          // debugPrint('  ⚠️ Failed to update location: $e');
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

      if (e.toString().contains('Location services are disabled')) {
        _showLocationError(enableLocationMsg, settingsLabel);
      } else if (e.toString().contains('denied')) {
        _showLocationError(permissionDeniedMsg, settingsLabel);
      } else {
        _showLocationError(unableToGetLocationMsg, settingsLabel);
      }

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
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters, // Mise à jour tous les 50m
      ),
    ).listen(
      (Position position) async {
        if (!mounted) return;

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
            final dataSource = ProfileRemoteDataSourceImpl();
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
      Duration(seconds: _membersRefreshIntervalSeconds),
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
      Duration(seconds: _uiRefreshIntervalSeconds),
      (_) {
        if (mounted && (_lastMembersUpdate != null || _lastPositionUpdate != null)) {
          setState(() {}); // Rebuild pour mettre à jour l'affichage du temps
        }
      },
    );
  }

  Future<void> _loadNearbyMembers(double latitude, double longitude) async {
    try {
      final dataSource = ProfileRemoteDataSourceImpl();
      List<ProfileModel> members;

      // Si rayon = 0 et pays connu, chercher par pays
      if (_selectedRadius == 0 && _userCountry != null) {
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
            if (currentUserId != null && p.blockedByUserIds.contains(currentUserId)) return false;
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
    } catch (e) {
      // debugPrint('  ❌ Error loading members: $e');
      // debugPrint('  ❌ Stack trace: ${StackTrace.current}');
      // En cas d'erreur, continuer avec une liste vide
      if (mounted) {
        setState(() {
          _nearbyMembers = [];
          _updateMarkers();
        });
      }
    }
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

  /// Retourne la taille du marqueur adaptée au niveau de zoom
  double _getMarkerSizeForZoom() {
    if (_currentZoom < 10) {
      return 44.0; // Zoom loin : pins compacts (minimum accessible)
    } else if (_currentZoom < 14) {
      return 56.0; // Zoom moyen : pins normaux
    } else {
      return 68.0; // Zoom proche : pins détaillés
    }
  }

  /// Crée un marqueur drop-pin style Google Maps
  Future<BitmapDescriptor> _createSimpleMarker(
    String userId,
    bool isFriend,
    bool isOnline,
  ) async {
    final bool isSelected = userId == _selectedMarkerId;
    final baseSize = _getMarkerSizeForZoom();
    final scale = isSelected ? 1.15 : 1.0;
    final markerSize = baseSize * scale;

    final cacheKey =
        'droppin_${isFriend}_${isOnline}_${_currentZoom.toInt()}_$isSelected';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    _cleanExpiredCache();

    // Couleur selon le type (vert pour amis, orange pour membres)
    final color = isFriend ? AppColors.secondary : AppColors.primary;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Créer le chemin du drop-pin
    final dropPinPath = MarkerPainter.createDropPinPath(markerSize);

    // Ombre portée
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(dropPinPath.shift(const Offset(0, 2)), shadowPaint);

    // Fond coloré du pin
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawPath(dropPinPath, fillPaint);

    // Bordure blanche fine
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawPath(dropPinPath, borderPaint);

    // Cercle blanc au centre (dans le bulbe)
    final bulbCenterY = markerSize * 0.40;
    final whiteCircleRadius = markerSize * 0.18;
    final centerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(markerSize / 2, bulbCenterY),
      whiteCircleRadius,
      centerPaint,
    );

    // Indicateur en ligne (petit point vert en haut à droite)
    if (isOnline) {
      final statusSize = markerSize * 0.14;
      final statusX = markerSize * 0.72;
      final statusY = markerSize * 0.12;

      // Fond blanc
      final bgPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(statusX, statusY), statusSize + 1.5, bgPaint);

      // Point vert
      final onlinePaint =
          Paint()
            ..color = AppColors.success
            ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(statusX, statusY), statusSize, onlinePaint);
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(markerSize.toInt(), markerSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = descriptor;
    _cacheExpiration[cacheKey] = DateTime.now().add(
      const Duration(minutes: 30),
    );
    return descriptor;
  }

  // --- Helpers d'affichage ---

  /// Crée un marqueur discret pour la position actuelle de l'utilisateur
  /// (petit point rouge avec cercle pulsant pour ne pas masquer les autres membres)
  Future<BitmapDescriptor> _createCurrentUserMarker() async {
    // Marqueur plus petit que les autres pour ne pas gêner la visibilité
    final markerSize = 32.0; // Taille fixe, petit
    final cacheKey = 'current_user_dot_${_currentZoom.toInt()}';

    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    // Rouge pour l'utilisateur actuel
    const userColor = Color(0xFFE53935);

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final center = Offset(markerSize / 2, markerSize / 2);

    // Cercle externe semi-transparent (effet de halo)
    final haloPaint =
        Paint()
          ..color = userColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, markerSize / 2 - 2, haloPaint);

    // Cercle moyen semi-transparent
    final midPaint =
        Paint()
          ..color = userColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, markerSize / 3, midPaint);

    // Cercle central rouge plein
    final centerPaint =
        Paint()
          ..color = userColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, markerSize / 5, centerPaint);

    // Bordure blanche fine autour du point central
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawCircle(center, markerSize / 5, borderPaint);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(markerSize.toInt(), markerSize.toInt());
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

  /// Crée un marqueur drop-pin pour une ambassade avec icône bâtiment
  Future<BitmapDescriptor> _createEmbassyMarker(
    String embassyId,
    bool isSelected,
  ) async {
    final scale = isSelected ? 1.15 : 1.0;
    final markerSize = _getMarkerSizeForZoom() * scale;

    final cacheKey = 'embassy_droppin_${isSelected}_${_currentZoom.toInt()}';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    // Bleu foncé pour les ambassades
    const embassyColor = Color(0xFF1976D2);

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Créer le chemin du drop-pin
    final dropPinPath = MarkerPainter.createDropPinPath(markerSize);

    // Ombre portée
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(dropPinPath.shift(const Offset(0, 2)), shadowPaint);

    // Fond bleu du pin
    final fillPaint =
        Paint()
          ..color = embassyColor
          ..style = PaintingStyle.fill;
    canvas.drawPath(dropPinPath, fillPaint);

    // Bordure blanche fine
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawPath(dropPinPath, borderPaint);

    // Dessiner l'icône de bâtiment au centre du bulbe
    final bulbCenterX = markerSize / 2;
    final bulbCenterY = markerSize * 0.40;
    final iconScale = markerSize / 80;

    final iconPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    // Base du bâtiment (rectangle)
    final buildingWidth = 18 * iconScale;
    final buildingHeight = 14 * iconScale;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bulbCenterX, bulbCenterY + 2 * iconScale),
        width: buildingWidth,
        height: buildingHeight,
      ),
      iconPaint,
    );

    // Toit triangulaire
    final roofPath =
        Path()
          ..moveTo(bulbCenterX - 11 * iconScale, bulbCenterY - 5 * iconScale)
          ..lineTo(bulbCenterX, bulbCenterY - 12 * iconScale)
          ..lineTo(bulbCenterX + 11 * iconScale, bulbCenterY - 5 * iconScale)
          ..close();
    canvas.drawPath(roofPath, iconPaint);

    // Colonnes (lignes verticales sur le bâtiment)
    final columnPaint =
        Paint()
          ..color = embassyColor
          ..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final columnX = bulbCenterX - 6 * iconScale + (i * 6 * iconScale);
      canvas.drawRect(
        Rect.fromLTWH(
          columnX - 1 * iconScale,
          bulbCenterY - 3 * iconScale,
          2 * iconScale,
          10 * iconScale,
        ),
        columnPaint,
      );
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(markerSize.toInt(), markerSize.toInt());
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
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textSecondaryColor.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
                          Icon(
                            Icons.warning_amber_rounded,
                            color: context.warningColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              embassy.closureMessage ?? 'Temporairement fermé',
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
                            Icon(
                              Icons.location_on,
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
                            'Services',
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
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Voir les détails complets',
                              style: TextStyle(
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
    _updateMarkersAsync();
  }

  Future<void> _updateMarkersAsync() async {
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
          anchor: const Offset(0.5, 0.5), // Centré car c'est un point, pas un pin
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

    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  Future<void> _addSingleMarker(
    Set<Marker> markers,
    ProfileModel member,
    WidgetRef ref,
  ) async {
    if (member.latitude != null && member.longitude != null) {
      // Vérifier si c'est un ami
      final friendshipStatus = ref.read(friendshipStatusProvider(member.id));
      final isFriend = friendshipStatus == FriendshipStatus.friends;

      // Créer le marqueur simple
      final icon = await _createSimpleMarker(
        member.id,
        isFriend,
        member.isOnline,
      );

      // Construire le snippet pour l'accessibilité
      final accessibilitySnippet = [
        if (member.profession != null && member.profession!.isNotEmpty)
          member.profession,
        member.isOnline ? 'En ligne' : null,
        isFriend ? 'Ami' : null,
      ].where((s) => s != null).join(' - ');

      markers.add(
        Marker(
          markerId: MarkerId(member.id),
          position: LatLng(member.latitude!, member.longitude!),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _showMemberDetails(member),
          // InfoWindow pour l'accessibilité (lecteurs d'écran)
          infoWindow: InfoWindow(
            title: member.displayName ?? 'Membre',
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    gradient: context.adaptivePrimaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
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
                                  (_, __, ___) => Icon(
                                    Icons.person,
                                    color: context.surfaceColor,
                                    size: 50,
                                  ),
                            ),
                          )
                          : Icon(
                            Icons.person,
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
                      Icon(
                        Icons.location_on_outlined,
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
                        icon: const Icon(Icons.person_outline),
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
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(
                                '/messages/new',
                                extra: {
                                  'selectedUserId': member.id,
                                  'selectedUserName': member.displayName,
                                  'selectedUserPhoto': member.photoUrl,
                                },
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(l10n.message),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.adaptivePrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
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
    // Recharger les membres avec le nouveau rayon
    if (_currentPosition != null) {
      _loadNearbyMembers(
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
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                                  isSelected
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
                              radius == 0
                                  ? l10n.wholeCountry
                                  : '${radius.toInt()} km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
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

  @override // Correction: override build method signature match
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
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
                    _selectedRadius == 0
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
          const SizedBox(width: 8),
        ],
      ),
      body:
          !_mapsInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  // Google Map
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _defaultPosition,
                      zoom: 12,
                    ),
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
                    markers: {..._markers, ..._embassyMarkers},
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

                  // Filter Chips
                  Positioned(
                    top: 16,
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
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_disabled,
                                    color: context.warningColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Localisation requise pour voir les membres",
                                      style: TextStyle(
                                        color: context.textPrimaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _initializeLocation,
                                    child: const Text("ACTIVER"),
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

                  // Légende flottante
                  if (!_isReciprocityRestricted)
                    const Positioned(bottom: 200, left: 16, child: MapLegend()),

                  // Bottom Sheet Preview
                  if (!_isReciprocityRestricted)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -4),
                            ),
                          ],
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
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.membersNearby,
                                        style:
                                            Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      // Indicateur de dernière mise à jour
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.groups_outlined,
                                            size: 12,
                                            color: context.textTertiaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatRelativeTime(_lastMembersUpdate, l10n),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textTertiaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.my_location,
                                            size: 12,
                                            color: context.textTertiaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatRelativeTime(_lastPositionUpdate, l10n),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textTertiaryColor,
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l10n.members(_getFilteredMembers().length),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.adaptivePrimaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_getFilteredMembers().isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(
                                  l10n.noMembersNearby,
                                  style: TextStyle(
                                    color: context.textTertiaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _getFilteredMembers().length,
                                  itemBuilder: (context, index) {
                                    final member = _getFilteredMembers()[index];
                                    return GestureDetector(
                                      onTap: () => _showMemberDetails(member),
                                      child: Container(
                                        width: 60,
                                        margin: EdgeInsets.only(
                                          left: index == 0 ? 0 : 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                gradient:
                                                    context
                                                        .adaptivePrimaryGradient,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child:
                                                  member.photoUrl != null
                                                      ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        child: Image.network(
                                                          member.photoUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => const Icon(
                                                                Icons.person,
                                                                color:
                                                                    AppColors
                                                                        .white,
                                                              ),
                                                        ),
                                                      )
                                                      : const Icon(
                                                        Icons.person,
                                                        color: AppColors.white,
                                                      ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              member.displayName ?? l10n.member,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    context.textSecondaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
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
        boxShadow: [
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
          color: isSelected ? Colors.white : context.textSecondaryColor,
        ),
      ),
    );
  }
}
