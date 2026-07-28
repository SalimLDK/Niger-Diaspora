import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;

  LocationService._internal();

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Demande la permission de localisation au premier plan (sans récupérer la
  /// position). Utilisé par l'onboarding (§14). Renvoie true si accordée.
  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request background location permission (required for Android 10+)
  /// Must be called AFTER foreground location permission is granted.
  Future<bool> requestBackgroundLocationPermission() async {
    if (Platform.isAndroid) {
      // Check if we already have background permission
      final status = await Permission.locationAlways.status;
      if (status.isGranted) {
        return true;
      }

      // Request background location permission
      final result = await Permission.locationAlways.request();
      return result.isGranted;
    }

    // On iOS, requesting "always" is handled by Geolocator
    return true;
  }

  /// Check if background location permission is granted
  Future<bool> hasBackgroundLocationPermission() async {
    if (Platform.isAndroid) {
      return await Permission.locationAlways.isGranted;
    }
    // On iOS, check via Geolocator
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Request notification permission (required for Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        return true;
      }
      final result = await Permission.notification.request();
      return result.isGranted;
    }
    return true;
  }

  /// Get the last known position.
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<void> initializeBackgroundService() async {
    // This calls the static initialize of the background service
    // We import the file here or pass the function if needed, but since it's a separate class
    // we can just call its instance method or static method.
    // However, to keep it clean, let's keep LocationService as a wrapper if preferred.
    // For now, I'll assume the UI calls BackgroundLocationService().initialize() directly or via here.
  }
}
