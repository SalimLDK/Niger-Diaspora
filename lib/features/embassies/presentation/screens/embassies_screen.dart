import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/embassies_provider.dart';
import '../widgets/embassy_list_item.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../domain/entities/embassy_entity.dart';

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

  Map<String, List<EmbassyEntity>> _groupByCountry(
    List<EmbassyEntity> embassies,
  ) {
    final grouped = <String, List<EmbassyEntity>>{};
    for (final embassy in embassies) {
      if (!grouped.containsKey(embassy.country)) {
        grouped[embassy.country] = [];
      }
      grouped[embassy.country]!.add(embassy);
    }
    return grouped;
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
      appBar: AppBar(
        title: const Text('Ambassades & Consulats'),
        centerTitle: true,
      ),
      body: embassiesAsync.when(
        skipLoadingOnRefresh: true,
        data: (embassies) {
          final filteredEmbassies = _filterEmbassies(embassies);
          final groupedEmbassies = _groupByCountry(filteredEmbassies);
          final countries = groupedEmbassies.keys.toList()..sort();

          return Column(
            children: [
              // Search bar
              StandardSearchBar(
                controller: _searchController,
                hintText: 'Rechercher par nom, pays ou ville...',
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),

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

              // Embassy list (grouped by country)
              Expanded(
                child:
                    filteredEmbassies.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                          onRefresh: () async {
                            return ref.refresh(embassiesListProvider.future);
                          },
                          child: ListView.builder(
                            itemCount: countries.length,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemBuilder: (context, index) {
                              final country = countries[index];
                              final countryEmbassies =
                                  groupedEmbassies[country]!;

                              return _CountrySection(
                                country: country,
                                embassies: countryEmbassies,
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
