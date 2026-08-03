import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/embassies_provider.dart';
import '../widgets/embassy_list_item.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/embassy_entity.dart';

/// Rayon (km) sous lequel une ambassade rejoint la zone « Près de vous »
/// plutôt que sa zone continentale.
const double _nearYouRadiusKm = 1500.0;

/// Zone géographique à partir des coordonnées (§17a) — délibérément PAS basé
/// sur `embassy.country` (texte libre saisi par un admin, sans liste
/// contrôlée : cf `admin_create_embassy_screen.dart`, `_countryController`
/// est un simple champ texte). Le mapping nom→continent avait été tenté et
/// abandonné pour cette raison (risque de tout classer en « Autres » au
/// moindre écart d'orthographe). Les coordonnées, elles, sont numériques et
/// fiables ; en cas de zone limitrophe imprécise, l'ambassade atterrit dans
/// une zone adjacente cohérente plutôt que de faire s'effondrer tout le
/// regroupement.
String _continentForCoordinates(double lat, double lng) {
  if (lat >= 5 && lat <= 84 && lng >= -170 && lng <= -50) {
    return 'Amérique du Nord';
  }
  if (lat >= -56 && lat < 13 && lng >= -82 && lng <= -34) {
    return 'Amérique du Sud';
  }
  if (lat >= 34 && lat <= 72 && lng >= -25 && lng < 45) return 'Europe';
  if (lat >= -35 && lat < 38 && lng >= -18 && lng <= 52) return 'Afrique';
  if (lat <= 10 && lng >= 95) return 'Océanie';
  if (lng >= 45) return 'Asie';
  return 'Autres';
}

/// Drapeau du pays, par correspondance normalisée (accents/casse/ponctuation
/// ignorés) sur `ProfileOptions.countries` — `embassy.country` étant du
/// texte libre, on ne peut pas garantir une correspondance exacte. Repli
/// gracieux : pas de drapeau plutôt qu'un mauvais drapeau (contrairement au
/// regroupement par zone, une correspondance manquée ici ne dégrade que
/// CETTE ligne, pas toute la liste).
String _normalizeCountryName(String input) {
  var out = input.toLowerCase().trim();
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  accents.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

final Map<String, String> _flagByNormalizedCountry = {
  for (final c in ProfileOptions.countries)
    _normalizeCountryName(c.name): c.flag,
};

String? _countryFlag(String countryName) =>
    _flagByNormalizedCountry[_normalizeCountryName(countryName)];

class EmbassiesScreen extends ConsumerStatefulWidget {
  const EmbassiesScreen({super.key});

  @override
  ConsumerState<EmbassiesScreen> createState() => _EmbassiesScreenState();
}

class _EmbassiesScreenState extends ConsumerState<EmbassiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(embassiesListProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const List<String> _zoneOrder = [
    'Près de vous',
    'Europe',
    'Afrique',
    'Amérique du Nord',
    'Amérique du Sud',
    'Asie',
    'Océanie',
    'Autres',
  ];

  String _zoneFor(EmbassyEntity embassy, double? myLat, double? myLng) {
    if (embassy.latitude == null || embassy.longitude == null) return 'Autres';
    if (myLat != null && myLng != null) {
      final distance = GeoUtils.calculateDistance(
        myLat,
        myLng,
        embassy.latitude!,
        embassy.longitude!,
      );
      if (distance <= _nearYouRadiusKm) return 'Près de vous';
    }
    return _continentForCoordinates(embassy.latitude!, embassy.longitude!);
  }

  /// Regroupement par zone (§17a) puis par pays au sein de chaque zone —
  /// la zone vient des coordonnées (fiable), le pays reste du texte libre
  /// (juste un sous-titre, une correspondance imparfaite n'y est pas grave).
  Map<String, Map<String, List<EmbassyEntity>>> _groupByZoneThenCountry(
    List<EmbassyEntity> embassies,
    double? myLat,
    double? myLng,
  ) {
    final grouped = <String, Map<String, List<EmbassyEntity>>>{};
    for (final embassy in embassies) {
      final zone = _zoneFor(embassy, myLat, myLng);
      final byCountry = grouped.putIfAbsent(zone, () => {});
      byCountry.putIfAbsent(embassy.country, () => []).add(embassy);
    }
    return grouped;
  }

  /// Ma position (profil, déjà chargée ailleurs — aucune requête ici),
  /// réutilisée pour la carte « plus proche » et le regroupement par zone.
  (double?, double?) _myLatLng() {
    final uid = ref.watch(currentUserProvider).valueOrNull?.id;
    final myProfile =
        uid != null ? ref.watch(profileNotifierProvider(uid)).valueOrNull : null;
    return (myProfile?.latitude, myProfile?.longitude);
  }

  /// Représentation la plus proche (§17a) : distance à vol d'oiseau.
  /// `null` si ma position ou aucune coordonnée d'ambassade n'est connue.
  (EmbassyEntity, double)? _findNearest(
    List<EmbassyEntity> embassies,
    double? myLat,
    double? myLng,
  ) {
    if (myLat == null || myLng == null) return null;

    EmbassyEntity? nearest;
    double? nearestDistance;
    for (final embassy in embassies) {
      if (embassy.latitude == null || embassy.longitude == null) continue;
      final distance = GeoUtils.calculateDistance(
        myLat,
        myLng,
        embassy.latitude!,
        embassy.longitude!,
      );
      if (nearestDistance == null || distance < nearestDistance) {
        nearest = embassy;
        nearestDistance = distance;
      }
    }
    if (nearest == null || nearestDistance == null) return null;
    return (nearest, nearestDistance);
  }

  List<EmbassyEntity> _filterEmbassies(List<EmbassyEntity> embassies) {
    if (_searchQuery.isEmpty) return embassies;

    final lowerQuery = _searchQuery.toLowerCase();
    return embassies.where((embassy) {
      return embassy.name.toLowerCase().contains(lowerQuery) ||
          embassy.country.toLowerCase().contains(lowerQuery) ||
          embassy.city.toLowerCase().contains(lowerQuery) ||
          embassy.address.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final embassiesAsync = ref.watch(embassiesListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat (§17a) : titre serif aligné à gauche, plus de barre
      // Material centrée.
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        automaticallyImplyLeading: false,
        title: const DesignTitle('Ambassades & consulats', size: 24),
      ),
      body: embassiesAsync.when(
        skipLoadingOnRefresh: true,
        data: (embassies) {
          final (myLat, myLng) = _myLatLng();
          final filteredEmbassies = _filterEmbassies(embassies);
          final groupedByZone =
              _groupByZoneThenCountry(filteredEmbassies, myLat, myLng);
          final zones = _zoneOrder.where(groupedByZone.containsKey).toList();
          final nearest =
              _searchQuery.isEmpty
                  ? _findNearest(embassies, myLat, myLng)
                  : null;

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: DesignSearchField(
                  controller: _searchController,
                  hintText: 'Rechercher par nom, pays ou ville',
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Représentation la plus proche (§17a) — masquée en recherche.
              if (nearest != null)
                _NearestEmbassyCard(embassy: nearest.$1, distanceKm: nearest.$2),

              // Results count
              if (filteredEmbassies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '${filteredEmbassies.length} ambassade(s) trouvée(s)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

              // Embassy list (regroupée par zone puis par pays, §17a)
              Expanded(
                child:
                    filteredEmbassies.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                          onRefresh: () async {
                            return ref.refresh(embassiesListProvider.future);
                          },
                          child: ListView.builder(
                            itemCount: zones.length,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemBuilder: (context, index) {
                              final zone = zones[index];
                              final byCountry = groupedByZone[zone]!;
                              final countries = byCountry.keys.toList()
                                ..sort();
                              final zoneCount = byCountry.values
                                  .fold<int>(0, (sum, l) => sum + l.length);

                              return _ZoneSection(
                                zone: zone,
                                count: zoneCount,
                                children: countries
                                    .map(
                                      (country) => _CountrySection(
                                        country: country,
                                        embassies: byCountry[country]!,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: ErrorView(
                message: 'Erreur: ${error.toString()}',
                onRetry: () => ref.refresh(embassiesListProvider),
              ),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.account_balance_outlined
                  : Icons.search_off,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Aucune ambassade disponible'
                  : 'Aucun résultat trouvé',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Les ambassades et consulats disponibles apparaîtront ici.'
                  : 'Essayez de modifier votre recherche.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte héro de la représentation la plus proche (§17a). État d'ouverture
/// limité au drapeau explicite `isTemporarilyClosed` (pas de calcul
/// « ouvert maintenant », même prudence que embassy_detail_screen.dart).
class _NearestEmbassyCard extends StatelessWidget {
  final EmbassyEntity embassy;
  final double distanceKm;

  const _NearestEmbassyCard({required this.embassy, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = embassy.isTemporarilyClosed;
    // Ouvert / fermé : jetons sémantiques plutôt que teintes figées. Les
    // deux valeurs d'origine étaient les variantes foncées, illisibles sur
    // fond nuit — le sens est conservé, le contraste suit le thème.
    final statusColor = closed ? context.errorColor : context.successColor;
    final distanceLabel =
        distanceKm < 1
            ? '< 1 km'
            : '${distanceKm.round()} km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/embassies/${embassy.id}', extra: embassy),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.near_me_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le plus proche · $distanceLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      embassy.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          closed ? 'Temporairement fermé' : 'Ouvert',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section de zone (§17a) : Près de vous / Europe / Afrique / etc.,
/// dépliée par défaut, contient les sous-sections par pays.
class _ZoneSection extends StatefulWidget {
  final String zone;
  final int count;
  final List<Widget> children;

  const _ZoneSection({
    required this.zone,
    required this.count,
    required this.children,
  });

  @override
  State<_ZoneSection> createState() => _ZoneSectionState();
}

class _ZoneSectionState extends State<_ZoneSection> {
  bool _isExpanded = true;

  static const Map<String, IconData> _zoneIcons = {
    'Près de vous': Icons.near_me_rounded,
    'Europe': Icons.euro_rounded,
    'Afrique': Icons.public,
    'Amérique du Nord': Icons.public,
    'Amérique du Sud': Icons.public,
    'Asie': Icons.public,
    'Océanie': Icons.public,
    'Autres': Icons.help_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(
                  _zoneIcons[widget.zone] ?? Icons.public,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.zone,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  '${widget.count}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...widget.children,
      ],
    );
  }
}

class _CountrySection extends StatefulWidget {
  final String country;
  final List<EmbassyEntity> embassies;

  const _CountrySection({required this.country, required this.embassies});

  @override
  State<_CountrySection> createState() => _CountrySectionState();
}

class _CountrySectionState extends State<_CountrySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // Drapeau (§17a) : correspondance normalisée sur le pays
                // (texte libre), masqué en silence si aucune correspondance.
                if (_countryFlag(widget.country) != null) ...[
                  Text(
                    _countryFlag(widget.country)!,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.country,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.embassies.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ...widget.embassies.map(
            (embassy) => EmbassyListItem(embassy: embassy),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
