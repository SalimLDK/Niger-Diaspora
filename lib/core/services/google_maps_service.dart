import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class GoogleMapsService {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  static GoogleMapsService get instance => _instance;

  GoogleMapsService._internal();

  bool _initialized = false;

  /// Initialize Google Maps renderer (call before displaying first map)
  Future<void> initialize() async {
    if (_initialized) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final GoogleMapsFlutterPlatform mapsImplementation =
          GoogleMapsFlutterPlatform.instance;
      if (mapsImplementation is GoogleMapsFlutterAndroid) {
        try {
          debugPrint('🗺️ Initializing Google Maps with AndroidViewSurface...');
          mapsImplementation.useAndroidViewSurface = true;
          final renderer = await mapsImplementation
              .initializeWithRenderer(AndroidMapRenderer.latest);
          debugPrint('🗺️ Google Maps renderer initialized: $renderer');
        } catch (e) {
          // Renderer already initialized - this is fine
          debugPrint('🗺️ Google Maps renderer already initialized');
        }
      }
    }

    _initialized = true;
    debugPrint('🗺️ GoogleMapsService initialized');
  }

  bool get isInitialized => _initialized;
}
