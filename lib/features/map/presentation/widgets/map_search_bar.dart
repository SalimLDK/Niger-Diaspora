import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/services/place_search_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/standard_search_bar.dart';

/// Barre de recherche de lieu pour la carte principale : recentre la caméra
/// sur le lieu sélectionné, sans modifier la position réelle de l'utilisateur.
class MapSearchBar extends StatefulWidget {
  final void Function(LatLng latLng, String label) onPlaceSelected;

  /// Notifie le parent quand la liste de résultats s'ouvre/se ferme, pour qu'il
  /// masque les filtres profession situés juste en dessous (sinon chevauchement).
  final ValueChanged<bool>? onResultsVisibilityChanged;

  const MapSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onResultsVisibilityChanged,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _searchController = TextEditingController();
  final _placeSearch = const PlaceSearchService();
  Timer? _debounceTimer;
  int _searchVersion = 0;
  List<PlaceSearchResult> _results = [];
  bool _isSearching = false;
  bool _showResults = false;

  /// Met à jour `_showResults` et prévient le parent si la visibilité change.
  void _setShowResults(bool value) {
    if (_showResults != value) {
      widget.onResultsVisibilityChanged?.call(value);
    }
    _showResults = value;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _setShowResults(false);
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final currentVersion = ++_searchVersion;
    final results = await _placeSearch.search(query);
    if (currentVersion != _searchVersion || !mounted) return;

    setState(() {
      _results = results;
      _setShowResults(results.isNotEmpty);
      _isSearching = false;
    });
  }

  Future<void> _onSelect(PlaceSearchResult result) async {
    final latLng = await _placeSearch.resolveLatLng(result);
    if (latLng == null || !mounted) return;

    setState(() {
      _setShowResults(false);
      _results = [];
    });
    _searchController.text = result.mainText;
    FocusScope.of(context).unfocus();
    widget.onPlaceSelected(latLng, result.mainText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CompactSearchBar(
            controller: _searchController,
            hintText: l10n.searchLocation,
            isLoading: _isSearching,
            showClearButton: true,
            debounceDuration: const Duration(milliseconds: 300),
            onChanged: _onChanged,
            onSubmitted: _search,
            onClear: () => setState(() {
              _results = [];
              _setShowResults(false);
            }),
          ),
        ),
        if (_showResults && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: context.surfaceColor,
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
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
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
                  subtitle: result.secondaryText.isNotEmpty
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
                  onTap: () => _onSelect(result),
                );
              },
            ),
          ),
      ],
    );
  }
}
