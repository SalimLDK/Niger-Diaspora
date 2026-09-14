import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../providers/lieux_des_groupes_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

/// Centroides approximatifs des pays de destination les plus courants pour la
/// diaspora nigerienne. Un pays absent de cette table n'a simplement pas de
/// marqueur sur la carte (pas de crash, pas de geocodage distant a chaque appel).
///
/// Clés = noms de `ProfileOptions.countries`, la forme que porte
/// `groups.country_code`. Tant que la colonne portait des codes ISO, aucun
/// groupe ne trouvait sa clé et la carte restait vide sans rien signaler.
/// Verrouillé par `test/core/models/pays_en_toutes_lettres_test.dart`.
const Map<String, LatLng> countryCentroids = {
  'Niger': LatLng(17.6078, 8.0817),
  'Nigeria': LatLng(9.0820, 8.6753),
  'Bénin': LatLng(9.3077, 2.3158),
  'Burkina Faso': LatLng(12.2383, -1.5616),
  'Mali': LatLng(17.5707, -3.9962),
  'Tchad': LatLng(15.4542, 18.7322),
  'Sénégal': LatLng(14.4974, -14.4524),
  'Côte d\'Ivoire': LatLng(7.5400, -5.5471),
  'Maroc': LatLng(31.7917, -7.0926),
  'Algérie': LatLng(28.0339, 1.6596),
  'Tunisie': LatLng(33.8869, 9.5375),
  'Égypte': LatLng(26.8206, 30.8025),
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
  'Suède': LatLng(60.1282, 18.6435),
  'États-Unis': LatLng(37.0902, -95.7129),
  'Canada': LatLng(56.1304, -106.3468),
  'Arabie saoudite': LatLng(23.8859, 45.0792),
  'Émirats arabes unis': LatLng(23.4241, 53.8478),
  'Qatar': LatLng(25.3548, 51.1839),
  'Chine': LatLng(35.8617, 104.1954),
  'Inde': LatLng(20.5937, 78.9629),
  'Turquie': LatLng(38.9637, 35.2433),
};

/// Vue carte des groupes : un marqueur par LIEU — un pays, ou une ville
/// depuis que les groupes de ville existent. Ecran distinct de la carte des
/// membres (map_screen.dart) pour ne pas alourdir/risquer sa logique
/// existante.
///
/// Le titre ne dit plus « par pays » : il l'était, il ne l'est plus.
class GroupsMapScreen extends ConsumerStatefulWidget {
  const GroupsMapScreen({super.key});

  @override
  ConsumerState<GroupsMapScreen> createState() => _GroupsMapScreenState();
}

class _GroupsMapScreenState extends ConsumerState<GroupsMapScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _defaultPosition = LatLng(17.6078, 8.0817); // Niger, vue monde

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: DesignTitle(l10n.groupsOnMap, size: 22),
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/groups'),
        ),
      ),
      body: groupsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
        error: (_, __) => Center(child: Text(l10n.groupsLoadFailed)),
        data: (groups) {
          // Un marqueur par LIEU, pas par groupe : un pays, ou une ville
          // depuis que les groupes de ville existent. `lieux` vient de la
          // base ; tant qu'il n'est pas chargé (ou s'il échoue), la carte se
          // comporte exactement comme avant, sur ses centroïdes.
          final lieux = ref.watch(lieuxDesGroupesProvider).valueOrNull ?? const {};

          final parLieu = <String, List<GroupEntity>>{};
          final libelles = <String, String>{};
          final positions = <String, LatLng>{};

          for (final g in groups) {
            final lieu = lieux[g.id];
            final pays = g.country;

            String cle;
            String libelle;
            LatLng? position;

            if (lieu != null && lieu.estUneVille) {
              cle = 'ville:${lieu.groupId}';
              libelle = lieu.villeNom ?? g.name;
              position = LatLng(lieu.latitude, lieu.longitude);
            } else {
              if (pays == null || pays.isEmpty) continue;
              cle = 'pays:$pays';
              libelle = pays;
              // Le centroïde du pays reste prioritaire : la carte ne bouge pas
              // pour les 32 pays qui en ont un. Les 165 autres étaient
              // simplement absents ; ils prennent la plus grande ville du pays.
              position = countryCentroids[pays] ??
                  (lieu == null ? null : LatLng(lieu.latitude, lieu.longitude));
            }
            if (position == null) continue;

            parLieu.putIfAbsent(cle, () => []).add(g);
            libelles[cle] = libelle;
            positions[cle] = position;
          }

          final markers = <Marker>{};
          for (final entry in parLieu.entries) {
            final libelle = libelles[entry.key]!;
            markers.add(
              Marker(
                markerId: MarkerId(entry.key),
                position: positions[entry.key]!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  entry.value.any((g) => g.isOfficial)
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueAzure,
                ),
                infoWindow: InfoWindow(
                  title: libelle,
                  snippet: '${entry.value.length} groupe${entry.value.length > 1 ? 's' : ''}',
                ),
                onTap: () => _showLieuGroupsSheet(context, libelle, entry.value),
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

  void _showLieuGroupsSheet(
    BuildContext context,
    String lieu,
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
              lieu,
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
                              l10n.audioRoomCategoryOfficial,
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
