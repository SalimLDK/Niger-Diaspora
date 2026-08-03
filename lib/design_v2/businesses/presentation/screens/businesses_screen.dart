import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../../kit/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../features/businesses/domain/entities/business_entity.dart';
import '../../../../features/businesses/presentation/providers/business_provider.dart';
import '../../../../features/businesses/presentation/widgets/business_card.dart';

class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key});

  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _searchController = TextEditingController();
  bool _showLocationFilter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(businessesNotifierProvider.notifier).loadBusinesses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(businessesNotifierProvider);
    final selectedCategory = ref.watch(selectedBusinessCategoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat (§17c) : grand titre serif et recherche toujours
      // visible, au lieu du mode recherche à bascule dans l'AppBar.
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          DesignScreenHeader(
            title: 'Annuaire Business',
            actions: [
              DesignSquareAction(
                icon: Icons.storefront_outlined,
                tooltip: 'Mes entreprises',
                onPressed: () => context.push('/businesses/mine'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: DesignSearchField(
              controller: _searchController,
              hintText: 'Rechercher une entreprise',
              onChanged: (query) => ref
                  .read(businessesNotifierProvider.notifier)
                  .searchBusinesses(query),
              onClear: () {
                _searchController.clear();
                ref.read(businessesNotifierProvider.notifier).loadBusinesses();
                setState(() {});
              },
              onFilterTap: () => setState(
                () => _showLocationFilter = !_showLocationFilter,
              ),
            ),
          ),
          // Location filter (collapsible)
          if (_showLocationFilter) _buildLocationFilter(theme),
          // Category filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DesignFilterChip(
                    label: 'Tous',
                    selected: selectedCategory == null,
                    onTap: () => ref
                        .read(selectedBusinessCategoryProvider.notifier)
                        .clear(),
                  ),
                ),
                ...BusinessCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DesignFilterChip(
                      label: category.label,
                      selected: selectedCategory == category,
                      onTap: () => ref
                          .read(selectedBusinessCategoryProvider.notifier)
                          .select(category),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Business list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(businessesNotifierProvider.notifier).refresh();
              },
              child: businessesAsync.when(
                skipLoadingOnRefresh: true,
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune entreprise trouvee',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Soyez le premier a ajouter votre entreprise !',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: businesses.length,
                    itemBuilder: (context, index) {
                      final business = businesses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BusinessCard(
                          business: business,
                          onTap: () {
                            context.push(
                              '/businesses/${business.id}',
                              extra: business,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            AppIcon.error,
                            size: 64,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(businessesNotifierProvider.notifier)
                                  .refresh();
                            },
                            child: const Text('Reessayer'),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/businesses/create');
        },
        icon: const AppIcon(AppIcon.add),
        label: const Text('Ajouter'),
      ),
    );
  }

  Widget _buildLocationFilter(ThemeData theme) {
    final locationFilter = ref.watch(selectedBusinessLocationProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcon.location,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Filtrer par localisation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (locationFilter.hasFilter)
                TextButton.icon(
                  onPressed: () {
                    ref.read(selectedBusinessLocationProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: false,
                      countryListTheme: CountryListThemeData(
                        flagSize: 25,
                        backgroundColor: theme.colorScheme.surface,
                        textStyle: theme.textTheme.bodyMedium,
                        bottomSheetHeight: 500,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        inputDecoration: InputDecoration(
                          labelText: 'Rechercher un pays',
                          prefixIcon: const AppIcon(AppIcon.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      onSelect: (Country country) {
                        ref
                            .read(selectedBusinessLocationProvider.notifier)
                            .setCountry(country.name);
                      },
                    );
                  },
                  icon: const AppIcon(AppIcon.public, size: 18),
                  label: Text(
                    locationFilter.country ?? 'Pays',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: locationFilter.country != null
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCityDialog(theme, locationFilter.city),
                  icon: const Icon(Icons.location_city, size: 18),
                  label: Text(
                    locationFilter.city ?? 'Ville',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: locationFilter.city != null
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                ref.read(selectedBusinessLocationProvider.notifier).useMyLocation();
              },
              icon: Icon(
                locationFilter.useMyLocation
                    ? Icons.my_location
                    : Icons.my_location_outlined,
                size: 18,
              ),
              label: const Text('Utiliser ma localisation'),
              style: FilledButton.styleFrom(
                backgroundColor: locationFilter.useMyLocation
                    ? theme.colorScheme.primaryContainer
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCityDialog(ThemeData theme, String? currentCity) {
    final controller = TextEditingController(text: currentCity ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrer la ville'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Paris, Niamey, New York...',
            prefixIcon: Icon(Icons.location_city),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final city = controller.text.trim();
              if (city.isNotEmpty) {
                ref.read(selectedBusinessLocationProvider.notifier).setCity(city);
              }
              Navigator.pop(context);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }
}
