import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';

/// Centroides approximatifs des pays de destination les plus courants pour la
/// diaspora nigerienne. Un pays absent de cette table n'a simplement pas de
/// marqueur sur la carte (pas de crash, pas de geocodage distant a chaque appel).
const Map<String, LatLng> _countryCentroids = {
  'Niger': LatLng(17.6078, 8.0817),
  'Nigeria': LatLng(9.0820, 8.6753),
  'Benin': LatLng(9.3077, 2.3158),
  'Burkina Faso': LatLng(12.2383, -1.5616),
  'Mali': LatLng(17.5707, -3.9962),
  'Tchad': LatLng(15.4542, 18.7322),
  'Senegal': LatLng(14.4974, -14.4524),
  'Cote d\'Ivoire': LatLng(7.5400, -5.5471),
  'Maroc': LatLng(31.7917, -7.0926),
  'Algerie': LatLng(28.0339, 1.6596),
  'Tunisie': LatLng(33.8869, 9.5375),
  'Egypte': LatLng(26.8206, 30.8025),
  'Ghana': LatLng(7.9465, -1.0232),
  'Togo': LatLng(8.6195, 0.8248),
  'Cameroun': LatLng(7.3697, 12.3547),
  'France': LatLng(46.2276, 2.2137),
  'Belgique': LatLng(50.5039, 4.4699),
  'Allemagne': LatLng(51.1657, 10.4515),
  'Italie': LatLng(41.8719, 12.5674),
  'Espagne': LatLng(40.4637, -3.7492),
  'Royaume-Uni': LatLng(55.3781, -3.4360),
  'Suisse': LatLng(46.8182, 8.2275),
  'Pays-Bas': LatLng(52.1326, 5.2913),
  'Suede': LatLng(60.1282, 18.6435),
  'Etats-Unis': LatLng(37.0902, -95.7129),
  'Canada': LatLng(56.1304, -106.3468),
  'Arabie saoudite': LatLng(23.8859, 45.0792),
  'Emirats arabes unis': LatLng(23.4241, 53.8478),
  'Qatar': LatLng(25.3548, 51.1839),
  'Chine': LatLng(35.8617, 104.1954),
  'Inde': LatLng(20.5937, 78.9629),
  'Turquie': LatLng(38.9637, 35.2433),
};

/// Vue carte des groupes regroupes par pays (un marqueur par pays ayant au
/// moins un groupe). Ecran distinct de la carte des membres (map_screen.dart)
/// pour ne pas alourdir/risquer sa logique existante.
class GroupsMapScreen extends ConsumerStatefulWidget {
  const GroupsMapScreen({super.key});

  @override
  ConsumerState<GroupsMapScreen> createState() => _GroupsMapScreenState();
}

class _GroupsMapScreenState extends ConsumerState<GroupsMapScreen> {
  static const _defaultPosition = LatLng(17.6078, 8.0817); // Niger, vue monde

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Groupes par pays'),
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: groupsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
        error: (_, __) => const Center(child: Text('Impossible de charger les groupes')),
        data: (groups) {
          final byCountry = <String, List<GroupEntity>>{};
          for (final g in groups) {
            if (g.country == null || g.country!.isEmpty) continue;
            byCountry.putIfAbsent(g.country!, () => []).add(g);
          }

          final markers = <Marker>{};
          for (final entry in byCountry.entries) {
            final centroid = _countryCentroids[entry.key];
            if (centroid == null) continue;
            markers.add(
              Marker(
                markerId: MarkerId(entry.key),
                position: centroid,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  entry.value.any((g) => g.isOfficial)
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueAzure,
                ),
                infoWindow: InfoWindow(
                  title: entry.key,
                  snippet: '${entry.value.length} groupe${entry.value.length > 1 ? 's' : ''}',
                ),
                onTap: () => _showCountryGroupsSheet(context, entry.key, entry.value),
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultPosition,
              zoom: 2.2,
            ),
            markers: markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          );
        },
      ),
    );
  }

  void _showCountryGroupsSheet(
    BuildContext context,
    String country,
    List<GroupEntity> groups,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            Text(
              country,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final group = groups[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(AppIcon.groups, color: context.adaptivePrimaryColor),
                    title: Text(group.name),
                    subtitle: Text('${group.memberIds.length} membres'),
                    trailing: group.isOfficial
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.adaptivePrimaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Officiel',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.adaptivePrimaryColor,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/groups/${group.id}', extra: group);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
