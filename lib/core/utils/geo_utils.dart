import 'dart:math' as math;

/// Utility class for geographic calculations
class GeoUtils {
  // Earth radius in kilometers
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two points using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Check if a point is within a given radius from a center point
  static bool isWithinRadius(
    double centerLat,
    double centerLon,
    double pointLat,
    double pointLon,
    double radiusKm,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLon,
      pointLat,
      pointLon,
    );
    return distance <= radiusKm;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Convert radians to degrees
  static double toDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }

  /// Format distance for display (e.g., "2.5 km" or "500 m")
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  /// Get bounding box coordinates for a center point and radius
  /// Useful for initial Firestore query filtering before precise distance calculation
  static ({double minLat, double maxLat, double minLon, double maxLon})
  getBoundingBox(double centerLat, double centerLon, double radiusKm) {
    // Angular distance in radians on a great circle
    final angularDistance = radiusKm / earthRadiusKm;
    final centerLatRad = _toRadians(centerLat);

    final minLat = centerLat - toDegrees(angularDistance);
    final maxLat = centerLat + toDegrees(angularDistance);

    // Compensate for longitude getting closer together at higher latitudes
    final deltaLon = toDegrees(
      math.asin(math.sin(angularDistance) / math.cos(centerLatRad)),
    );

    final minLon = centerLon - deltaLon;
    final maxLon = centerLon + deltaLon;

    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }
}
