import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils', () {
    group('calculateDistance', () {
      test('should return 0 for identical points', () {
        const lat = 48.8566;
        const lon = 2.3522;

        final distance = GeoUtils.calculateDistance(lat, lon, lat, lon);

        expect(distance, equals(0.0));
      });

      test('should calculate distance between Paris and Lyon correctly', () {
        // Paris coordinates
        const parisLat = 48.8566;
        const parisLon = 2.3522;
        // Lyon coordinates
        const lyonLat = 45.7640;
        const lyonLon = 4.8357;

        final distance = GeoUtils.calculateDistance(
          parisLat,
          parisLon,
          lyonLat,
          lyonLon,
        );

        // Known distance is approximately 392 km
        expect(distance, closeTo(392, 10));
      });

      test('should calculate distance between Niamey and Paris correctly', () {
        // Niamey coordinates
        const niameyLat = 13.5116;
        const niameyLon = 2.1254;
        // Paris coordinates
        const parisLat = 48.8566;
        const parisLon = 2.3522;

        final distance = GeoUtils.calculateDistance(
          niameyLat,
          niameyLon,
          parisLat,
          parisLon,
        );

        // Known distance is approximately 3912 km
        expect(distance, closeTo(3930, 50));
      });
    });

    group('isWithinRadius', () {
      test('should return true for point within radius', () {
        const centerLat = 48.8566;
        const centerLon = 2.3522;
        // Point about 5 km away
        const pointLat = 48.8800;
        const pointLon = 2.3800;

        final result = GeoUtils.isWithinRadius(
          centerLat,
          centerLon,
          pointLat,
          pointLon,
          10.0, // 10 km radius
        );

        expect(result, isTrue);
      });

      test('should return false for point outside radius', () {
        const centerLat = 48.8566;
        const centerLon = 2.3522;
        // Lyon - about 392 km away
        const pointLat = 45.7640;
        const pointLon = 4.8357;

        final result = GeoUtils.isWithinRadius(
          centerLat,
          centerLon,
          pointLat,
          pointLon,
          100.0, // 100 km radius
        );

        expect(result, isFalse);
      });
    });

    group('formatDistance', () {
      test('should format distances less than 1 km in meters', () {
        expect(GeoUtils.formatDistance(0.5), equals('500 m'));
        expect(GeoUtils.formatDistance(0.1), equals('100 m'));
      });

      test('should format distances between 1-10 km with one decimal', () {
        expect(GeoUtils.formatDistance(2.5), equals('2.5 km'));
        expect(GeoUtils.formatDistance(5.75), equals('5.8 km'));
      });

      test('should format distances over 10 km as integers', () {
        expect(GeoUtils.formatDistance(15.3), equals('15 km'));
        expect(GeoUtils.formatDistance(100.7), equals('101 km'));
      });
    });

    group('getBoundingBox', () {
      test('should return valid bounding box around center point', () {
        const lat = 48.8566;
        const lon = 2.3522;
        const radius = 10.0;

        final bbox = GeoUtils.getBoundingBox(lat, lon, radius);

        expect(bbox.minLat, lessThan(lat));
        expect(bbox.maxLat, greaterThan(lat));
        expect(bbox.minLon, lessThan(lon));
        expect(bbox.maxLon, greaterThan(lon));
      });
    });
  });
}
