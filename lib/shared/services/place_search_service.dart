import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_config.dart';

/// Résultat de recherche de lieu, avec coordonnées optionnelles (déjà connues
/// lorsque le résultat vient du repli géocodage plutôt que de Places).
class PlaceSearchResult {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  const PlaceSearchResult({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });
}

/// Recherche de lieux/adresses : Google Places Autocomplete en priorité,
/// avec repli sur le package `geocoding` si l'appel API échoue.
///
/// Extrait de `location_picker_modal.dart` pour être réutilisable ailleurs
/// (ex: barre de recherche sur la carte principale) sans dupliquer la
/// logique d'appel aux API Google Places.
class PlaceSearchService {
  const PlaceSearchService();

  String get _apiKey => AppConfig.googleMapsApiKey;

  /// Recherche des suggestions de lieux pour [query] (max 5 résultats).
  Future<List<PlaceSearchResult>> search(String query) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=fr'
        '&types=geocode|establishment',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK') {
          final predictions = data['predictions'] as List? ?? [];
          return predictions.take(5).map((prediction) {
            final structured = prediction['structured_formatting'] ?? {};
            return PlaceSearchResult(
              placeId: prediction['place_id'] ?? '',
              description: prediction['description'] ?? '',
              mainText:
                  structured['main_text'] ?? prediction['description'] ?? '',
              secondaryText: structured['secondary_text'] ?? '',
            );
          }).toList();
        }
        throw Exception('Places API status: $status');
      }
      throw Exception('Places API HTTP error: ${response.statusCode}');
    } catch (_) {
      return _fallbackSearch(query);
    }
  }

  Future<List<PlaceSearchResult>> _fallbackSearch(String query) async {
    try {
      final locations = await locationFromAddress(query);
      final results = <PlaceSearchResult>[];

      for (final location in locations.take(5)) {
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        final place = placemarks.isNotEmpty ? placemarks.first : null;
        final address =
            place != null
                ? [
                  place.street,
                  place.locality,
                  place.country,
                ].where((s) => s != null && s.isNotEmpty).join(', ')
                : query;

        results.add(
          PlaceSearchResult(
            placeId: '',
            description: address,
            mainText: address,
            secondaryText: '',
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Résout les coordonnées d'un [result] : directement si déjà connues
  /// (repli géocodage), sinon via l'API Place Details, avec un dernier
  /// repli sur `geocoding` si la résolution échoue.
  Future<LatLng?> resolveLatLng(PlaceSearchResult result) async {
    if (result.latitude != null && result.longitude != null) {
      return LatLng(result.latitude!, result.longitude!);
    }

    if (result.placeId.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${result.placeId}'
          '&fields=geometry'
          '&key=$_apiKey',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final location = data['result']?['geometry']?['location'];
          if (location != null) {
            return LatLng(
              (location['lat'] as num).toDouble(),
              (location['lng'] as num).toDouble(),
            );
          }
        }
      } catch (_) {}
    }

    try {
      final locations = await locationFromAddress(result.description);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {}

    return null;
  }
}
