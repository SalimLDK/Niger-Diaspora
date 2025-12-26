import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../friends/domain/repositories/friend_repository.dart';

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
  List<ProfileModel> _nearbyMembers = [];
  String _selectedFilter = 'all';
  double _selectedRadius = 50; // Rayon par défaut en km
  String? _userCountry; // Pays de l'utilisateur pour le filtre "Pays entier"
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _mapsInitialized = false;

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

  @override
  void dispose() {
    debugPrint('🗺️ MapScreen: dispose');
    _controller.future.then((c) => c.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ MapScreen: initState');
    _mapsInitialized = true; // Already initialized in main.dart
    _loadUserCountry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🗺️ MapScreen: didChangeDependencies');
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
      debugPrint('Erreur chargement pays utilisateur: $e');
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

    setState(() => _isLoading = true);

    try {
      final position = await LocationService.instance.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _hasLocationPermission = true;
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      debugPrint(
        '📍 Position obtenue: ${position.latitude}, ${position.longitude}',
      );

      // Mettre à jour la localisation de l'utilisateur dans Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('  💾 Updating user location in Firebase...');
        try {
          final dataSource = ProfileRemoteDataSourceImpl();
          await dataSource.updateLocation(
            currentUser.uid,
            position.latitude,
            position.longitude,
          );
          debugPrint('  ✅ Location updated successfully');
        } catch (e) {
          debugPrint('  ⚠️ Failed to update location: $e');
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
    } catch (e) {
      debugPrint('Erreur de localisation: $e');
      if (!mounted) return;

      if (e.toString().contains('Location services are disabled')) {
        _showLocationError(enableLocationMsg, settingsLabel);
      } else if (e.toString().contains('denied')) {
        setState(() => _hasLocationPermission = false);
        _showLocationError(permissionDeniedMsg, settingsLabel);
      } else {
        _showLocationError(unableToGetLocationMsg, settingsLabel);
      }

      setState(() => _isLoading = false);

      await _loadNearbyMembers(
        _defaultPosition.latitude,
        _defaultPosition.longitude,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNearbyMembers(double latitude, double longitude) async {
    debugPrint('🗺️ MapScreen: Loading nearby members...');
    debugPrint('  📍 Center position: ($latitude, $longitude)');
    debugPrint('  📏 Selected radius: ${_selectedRadius}km');
    debugPrint('  🔍 Selected filter: $_selectedFilter');

    try {
      final dataSource = ProfileRemoteDataSourceImpl();
      List<ProfileModel> members;

      // Si rayon = 0 et pays connu, chercher par pays
      if (_selectedRadius == 0 && _userCountry != null) {
        debugPrint('  🌍 Searching by country: $_userCountry');
        members = await dataSource.getProfilesByCountry(_userCountry!);
      } else if (_selectedRadius == 0) {
        debugPrint('  🌍 No country set, using large radius (5000km)');
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

      debugPrint('  ✅ Total members loaded: ${members.length}');

      if (!mounted) return;

      setState(() {
        _nearbyMembers = members;
        _updateMarkers();
      });

      debugPrint(
        '  🎯 After filter "$_selectedFilter": ${_getFilteredMembers().length} members',
      );
    } catch (e) {
      debugPrint('  ❌ Error loading members: $e');
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
      return 60.0; // Zoom loin : pins petits
    } else if (_currentZoom < 14) {
      return 90.0; // Zoom moyen : pins normaux
    } else {
      return 110.0; // Zoom proche : pins détaillés
    }
  }

  /// Crée un marqueur personnalisé avec la photo de profil de l'utilisateur
  Future<BitmapDescriptor> _createMarkerFromPhoto(
    String? photoUrl,
    String userId,
    bool isFriend,
    String? profession,
    DateTime? lastLoginAt,
    bool isOnline,
  ) async {
    // Si déjà en cache avec même config et non expiré, retourner directement
    final cacheKey =
        '${userId}_${isFriend}_${profession}_${lastLoginAt?.millisecondsSinceEpoch}_${isOnline}_${_currentZoom.toInt()}';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    // Nettoyer le cache expiré périodiquement
    _cleanExpiredCache();

    // Taille adaptative selon le zoom
    final markerSize = _getMarkerSizeForZoom();
    final bool isSelected = userId == _selectedMarkerId;
    final double borderWidth =
        isSelected ? 8.0 : 4.0; // Bordure plus épaisse si sélectionné
    final double photoSize = markerSize - (borderWidth * 2);
    final double shadowWidth = 2.0;

    try {
      if (photoUrl != null) {
        // Charger l'image depuis le réseau
        final completer = Completer<ui.Image>();
        final imageProvider = NetworkImage(photoUrl);
        final imageStream = imageProvider.resolve(const ImageConfiguration());

        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool _) {
            completer.complete(info.image);
            imageStream.removeListener(listener);
          },
          onError: (exception, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(exception);
            }
            imageStream.removeListener(listener);
          },
        );
        imageStream.addListener(listener);

        // Attendre l'image avec timeout
        final image = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('Timeout loading image'),
        );

        // Créer le marqueur avec la photo
        final pictureRecorder = ui.PictureRecorder();
        final canvas = Canvas(pictureRecorder);

        // Dessiner une ombre douce pour meilleure visibilité
        final shadowPaint =
            Paint()
              ..color = Colors.white.withValues(alpha: 0.6)
              ..style = PaintingStyle.fill
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(
          Offset(markerSize / 2, markerSize / 2),
          markerSize / 2 + shadowWidth,
          shadowPaint,
        );

        // Déterminer les couleurs selon le statut d'ami
        final borderColors =
            isFriend
                ? [AppColors.secondary, AppColors.secondaryDark]
                : [AppColors.primary, AppColors.primaryDark];

        // Dessiner le fond avec bordure dégradée (verte pour amis, orange pour non-amis)
        final borderGradient = ui.Gradient.radial(
          Offset(markerSize / 2, markerSize / 2),
          markerSize / 2,
          borderColors,
          [0.0, 1.0],
        );
        final borderPaint =
            Paint()
              ..shader = borderGradient
              ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(markerSize / 2, markerSize / 2),
          markerSize / 2,
          borderPaint,
        );

        // Créer un clip circulaire pour la photo
        final photoRect = Rect.fromCenter(
          center: Offset(markerSize / 2, markerSize / 2),
          width: photoSize,
          height: photoSize,
        );

        canvas.save();
        canvas.clipPath(Path()..addOval(photoRect));

        // Dessiner l'image
        final srcRect = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        canvas.drawImageRect(image, srcRect, photoRect, Paint());
        canvas.restore();

        // Dessiner l'ombre du triangle
        final triangleShadowPath =
            Path()
              ..moveTo(markerSize / 2 - 12, markerSize - 5)
              ..lineTo(markerSize / 2, markerSize + 15)
              ..lineTo(markerSize / 2 + 12, markerSize - 5)
              ..close();
        canvas.drawPath(triangleShadowPath, shadowPaint);

        // Dessiner le triangle indicateur de position
        final trianglePath =
            Path()
              ..moveTo(markerSize / 2 - 10, markerSize - 5)
              ..lineTo(markerSize / 2, markerSize + 12)
              ..lineTo(markerSize / 2 + 10, markerSize - 5)
              ..close();
        canvas.drawPath(trianglePath, borderPaint);

        // Ajouter badge de profession en bas à droite
        if (profession != null) {
          _drawProfessionBadge(canvas, profession, markerSize);
        }

        // Ajouter indicateur de statut en ligne en haut à droite
        if (lastLoginAt != null || isOnline) {
          _drawOnlineStatus(
            canvas,
            lastLoginAt ?? DateTime.now(),
            markerSize,
            isOnline,
          );
        }

        final picture = pictureRecorder.endRecording();
        final img = await picture.toImage(
          (markerSize + (shadowWidth * 2)).toInt(),
          (markerSize + 18 + (shadowWidth * 2)).toInt(),
        );
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final descriptor = BitmapDescriptor.bytes(bytes);
        _markerCache[cacheKey] = descriptor;
        _cacheExpiration[cacheKey] = DateTime.now().add(
          const Duration(minutes: 30),
        );
        return descriptor;
      }
    } catch (e) {
      debugPrint('Erreur création marqueur photo: $e');
    }

    // Marqueur par défaut si pas de photo ou erreur
    return _createDefaultMarker(
      userId,
      isFriend,
      profession,
      lastLoginAt,
      isOnline,
    );
  }

  /// Crée un marqueur par défaut avec une icône de personne
  Future<BitmapDescriptor> _createDefaultMarker(
    String userId,
    bool isFriend,
    String? profession,
    DateTime? lastLoginAt,
    bool isOnline,
  ) async {
    final cacheKey =
        'default_${userId}_${isFriend}_${profession}_${lastLoginAt?.millisecondsSinceEpoch}_${isOnline}_${_currentZoom.toInt()}';
    if (_markerCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final markerSize = _getMarkerSizeForZoom();

    final double shadowWidth = 2.0;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Dessiner une ombre douce
    final shadowPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      Offset(markerSize / 2, markerSize / 2),
      markerSize / 2 + shadowWidth,
      shadowPaint,
    );

    // Fond avec dégradé radial (vert pour amis, orange pour non-amis)
    final gradientColors =
        isFriend
            ? [AppColors.secondary, AppColors.secondaryDark]
            : [AppColors.primary, AppColors.primaryDark];
    final gradient = ui.Gradient.radial(
      Offset(markerSize / 2, markerSize / 2),
      markerSize / 2,
      gradientColors,
      [0.0, 1.0],
    );
    final paint = Paint()..shader = gradient;
    canvas.drawCircle(
      Offset(markerSize / 2, markerSize / 2),
      markerSize / 2,
      paint,
    );

    // Icône de personne (cercle pour la tête + arc pour le corps)
    final iconPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    // Tête
    canvas.drawCircle(
      Offset(markerSize / 2, markerSize / 2 - 8),
      14,
      iconPaint,
    );

    // Corps (arc)
    final bodyPath =
        Path()
          ..moveTo(markerSize / 2 - 22, markerSize / 2 + 28)
          ..quadraticBezierTo(
            markerSize / 2,
            markerSize / 2 + 5,
            markerSize / 2 + 22,
            markerSize / 2 + 28,
          )
          ..arcToPoint(
            Offset(markerSize / 2 - 22, markerSize / 2 + 28),
            radius: const Radius.circular(24),
            clockwise: false,
          );
    canvas.drawPath(bodyPath, iconPaint);

    // Dessiner l'ombre du triangle
    final triangleShadowPath =
        Path()
          ..moveTo(markerSize / 2 - 12, markerSize - 5)
          ..lineTo(markerSize / 2, markerSize + 15)
          ..lineTo(markerSize / 2 + 12, markerSize - 5)
          ..close();
    canvas.drawPath(triangleShadowPath, shadowPaint);

    // Triangle indicateur en bas
    final trianglePaint = Paint()..shader = gradient;
    final trianglePath =
        Path()
          ..moveTo(markerSize / 2 - 10, markerSize - 5)
          ..lineTo(markerSize / 2, markerSize + 12)
          ..lineTo(markerSize / 2 + 10, markerSize - 5)
          ..close();
    canvas.drawPath(trianglePath, trianglePaint);

    // Ajouter badge de profession en bas à droite
    if (profession != null) {
      _drawProfessionBadge(canvas, profession, markerSize);
    }

    // Ajouter indicateur de statut en ligne en haut à droite
    if (lastLoginAt != null || isOnline) {
      _drawOnlineStatus(
        canvas,
        lastLoginAt ?? DateTime.now(),
        markerSize,
        isOnline,
      );
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(
      (markerSize + (shadowWidth * 2)).toInt(),
      (markerSize + 18 + (shadowWidth * 2)).toInt(),
    );
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

  Future<BitmapDescriptor> _createClusterMarker(int count) async {
    final size = 80.0;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Cercle de fond (Vert/Orange mix ou Secondaire)
    final paint =
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    // Bordure
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    // Texte du compteur (e.g. "5+")
    final textSpan = TextSpan(
      text: count > 99 ? '99+' : count.toString(),
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Dessine un badge de profession avec emoji
  void _drawProfessionBadge(
    Canvas canvas,
    String profession,
    double markerSize,
  ) {
    final String emoji = _getProfessionEmoji(profession);

    const double badgeSize = 22;
    final badgeX = markerSize - badgeSize / 2 + 2;
    final badgeY = markerSize - badgeSize / 2 - 8;

    // Cercle blanc pour le badge
    final badgePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(badgeX, badgeY), badgeSize / 2, badgePaint);

    // Bordure subtile
    final borderPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    canvas.drawCircle(Offset(badgeX, badgeY), badgeSize / 2, borderPaint);

    // Dessiner l'emoji (utiliser un painter de texte)
    final textPainter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(badgeX - textPainter.width / 2, badgeY - textPainter.height / 2),
    );
  }

  /// Retourne l'emoji correspondant à la profession
  String _getProfessionEmoji(String profession) {
    final p = profession.toLowerCase();

    // Entrepreneurs
    if (p.contains('entrepreneur') ||
        p.contains('commercant') ||
        p.contains('business') ||
        p.contains('fondateur') ||
        p.contains('ceo') ||
        p.contains('gérant')) {
      return '👨‍💼';
    }

    // Étudiants
    if (p.contains('etudiant') ||
        p.contains('student') ||
        p.contains('élève') ||
        p.contains('stagiaire') ||
        p.contains('apprenant')) {
      return '🎓';
    }

    // Artistes
    if (p.contains('artiste') ||
        p.contains('artist') ||
        p.contains('chanteur') ||
        p.contains('musicien') ||
        p.contains('peintre') ||
        p.contains('acteur') ||
        p.contains('écrivain') ||
        p.contains('auteur') ||
        p.contains('designer') ||
        p.contains('créateur') ||
        p.contains('artisan')) {
      return '🎨';
    }

    // Professionnels (par défaut)
    return '💼';
  }

  /// Dessine un indicateur de statut en ligne
  void _drawOnlineStatus(
    Canvas canvas,
    DateTime lastLoginAt,
    double markerSize,
    bool isOnline,
  ) {
    Color statusColor;
    if (isOnline) {
      statusColor = AppColors.success; // Vert pour en ligne
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastLoginAt);

      if (difference.inMinutes < 60) {
        statusColor = AppColors.warning; // Orange pour récemment actif (< 1h)
      } else {
        statusColor = Colors.grey; // Gris pour inactif
      }
    }

    const double statusSize = 14;
    final statusX = markerSize - statusSize / 2 + 2;
    final statusY = statusSize / 2 + 2;

    // Cercle blanc de fond
    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(statusX, statusY), statusSize / 2 + 1, bgPaint);

    // Cercle de statut coloré
    final statusPaint =
        Paint()
          ..color = statusColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(statusX, statusY), statusSize / 2, statusPaint);
  }

  void _updateMarkers() {
    _updateMarkersAsync();
  }

  Future<void> _updateMarkersAsync() async {
    final l10n = AppLocalizations.of(context)!;
    final markers = <Marker>{};

    // Ajouter le marqueur de position actuelle
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: l10n.youAreHere),
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

          final icon = await _createClusterMarker(clusterMembers.length);

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
      final isFriend =
          friendshipStatus.whenOrNull(
            data: (status) => status == FriendshipStatus.friends,
          ) ??
          false;

      // Créer le marqueur avec toutes les infos visuelles
      final icon = await _createMarkerFromPhoto(
        member.photoUrl,
        member.id,
        isFriend,
        member.profession,
        member.lastLoginAt,
        member.isOnline,
      );

      markers.add(
        Marker(
          markerId: MarkerId(member.id),
          position: LatLng(member.latitude!, member.longitude!),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _showMemberDetails(member),
        ),
      );
    }
  }

  bool _matchesFilter(String? profession, String filterKey) {
    if (filterKey == 'all') return true;
    if (profession == null || profession.isEmpty) return false;

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

                        return friendshipStatus.when(
                          data: (status) {
                            if (status != FriendshipStatus.friends) {
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
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
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
                      _controller.complete(controller);
                      // Move camera to current position if available
                      if (_currentPosition != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentPosition!, 12),
                        );
                      }
                    },
                    markers: _markers,
                    myLocationEnabled: _hasLocationPermission,
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            _filterKeys
                                .map(
                                  (filterKey) => Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          filterKey != _filterKeys.last ? 8 : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _onFilterSelected(filterKey),
                                      child: _FilterChip(
                                        label: _getFilterLabel(filterKey, l10n),
                                        isSelected:
                                            _selectedFilter == filterKey,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),

                  // Bottom Sheet Preview
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
                              Text(
                                l10n.membersNearby,
                                style: Theme.of(context).textTheme.titleMedium,
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
                          const SizedBox(height: 16),
                          if (_getFilteredMembers().isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
                                              color: context.textSecondaryColor,
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
