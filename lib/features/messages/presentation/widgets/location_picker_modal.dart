import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/services/place_search_service.dart';
import '../../../map/presentation/utils/location_pin_generator.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Modal pour sélectionner et partager une position
class LocationPickerModal extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationSelected;

  const LocationPickerModal({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _address = '';
  bool _isLoading = true;
  bool _isSendingCurrentLocation = false;
  String? _errorMessage;
  BitmapDescriptor? _pinIcon;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final _placeSearch = const PlaceSearchService();
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounceTimer;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchResults.isEmpty) {
        setState(() => _showSearchResults = false);
      }
    });
    LocationPinGenerator.getPin().then((icon) {
      if (mounted) setState(() => _pinIcon = icon);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    // Rafraîchir l'UI pour le bouton clear
    setState(() {});

    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchLocation(query);
    });
  }

  Future<void> _searchLocation(String query) async {
    final currentVersion = ++_searchVersion;

    final results = await _placeSearch.search(query);

    // Ignorer si une nouvelle recherche a été lancée entre-temps
    if (currentVersion != _searchVersion || !mounted) return;

    setState(() {
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
      _isSearching = false;
    });
  }

  Future<void> _selectSearchResult(PlaceSearchResult result) async {
    final latLng = await _placeSearch.resolveLatLng(result);

    if (latLng == null || !mounted) return;

    setState(() {
      _selectedLocation = latLng;
      _address = result.description;
      _showSearchResults = false;
      _searchResults = [];
    });

    _searchFocusNode.unfocus();

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
  }

  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.locationPermissionDenied;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.locationPermissionDeniedForever;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      await _getAddressFromLatLng(_selectedLocation!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.unableToGetLocation;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address = [
            place.street,
            place.locality,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      setState(() => _address = l10n.selectedPosition);
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() => _selectedLocation = latLng);
    _getAddressFromLatLng(latLng);
    // Animate camera to selected position
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  Future<void> _sendCurrentLocation() async {
    setState(() => _isSendingCurrentLocation = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _getAddressFromLatLng(
        LatLng(position.latitude, position.longitude),
      );

      widget.onLocationSelected(
        position.latitude,
        position.longitude,
        _address,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.unableToGetLocation)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCurrentLocation = false);
    }
  }

  void _sendSelectedLocation() {
    if (_selectedLocation == null) return;

    widget.onLocationSelected(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
      _address,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textTertiaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  l10n.shareALocation,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: AppIcon(AppIcon.close, color: context.textSecondaryColor),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.searchLocation,
                hintStyle: TextStyle(color: context.textTertiaryColor),
                prefixIcon: AppIcon(AppIcon.search,
                  color: context.textSecondaryColor,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: context.textSecondaryColor,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        )
                        : _isSearching
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : null,
                filled: true,
                fillColor: context.surfaceVariantColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: TextStyle(color: context.textPrimaryColor),
              onChanged: _onSearchChanged,
              onSubmitted: _searchLocation,
            ),
          ),

          // Search results (5 suggestions max)
          if (_showSearchResults && _searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: AppIcon(
                      AppIcon.location,
                      color: context.adaptivePrimaryColor,
                      size: 20,
                    ),
                    title: Text(
                      result.mainText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle:
                        result.secondaryText.isNotEmpty
                            ? Text(
                              result.secondaryText,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                            : null,
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Send current location button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isSendingCurrentLocation ? null : _sendCurrentLocation,
                icon:
                    _isSendingCurrentLocation
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.my_location),
                label: Text(
                  _isSendingCurrentLocation
                      ? l10n.gettingLocation
                      : l10n.myCurrentLocation,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.adaptivePrimaryColor,
                  side: BorderSide(color: context.adaptivePrimaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Divider with text
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: context.outlineColor.withValues(alpha: 0.2),
                  indent: 16,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.orSelectOnMap,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: context.outlineColor.withValues(alpha: 0.2),
                  endIndent: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Map
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.loadingMap,
                            style: TextStyle(color: context.textSecondaryColor),
                          ),
                        ],
                      ),
                    )
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 48,
                            color: context.textTertiaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: context.textSecondaryColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _getCurrentLocation();
                            },
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                    : ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              _selectedLocation ??
                              const LatLng(13.5127, 2.1128), // Niamey default
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: _onMapTap,
                        markers:
                            _selectedLocation != null
                                ? {
                                  Marker(
                                    markerId: const MarkerId('selected'),
                                    position: _selectedLocation!,
                                    icon:
                                        _pinIcon ??
                                        BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueOrange,
                                        ),
                                    anchor: const Offset(0.5, 0.95),
                                    infoWindow: InfoWindow(
                                      title: l10n.selectedPosition,
                                      snippet: _address,
                                    ),
                                  ),
                                }
                                : {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        // Enable all gestures for map navigation
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        // Capture gestures to prevent modal from intercepting
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                      ),
                    ),
          ),

          // Selected location info and send button
          if (_selectedLocation != null && !_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(AppIcon.location,
                          size: 20,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address.isNotEmpty
                                ? _address
                                : l10n.selectedPosition,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendSelectedLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.adaptivePrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.sendThisLocation),
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
