import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../domain/entities/business_entity.dart';
import '../providers/business_provider.dart';
import '../widgets/business_card.dart';

class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key});

  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

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
      appBar: AppBar(
        title:
            _isSearching
                ? CompactSearchBar(
                  controller: _searchController,
                  hintText: 'Rechercher une entreprise...',
                  autofocus: true,
                  onSubmitted: (query) {
                    ref
                        .read(businessesNotifierProvider.notifier)
                        .searchBusinesses(query);
                  },
                )
                : const Text('Annuaire Business'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref
                      .read(businessesNotifierProvider.notifier)
                      .loadBusinesses();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Tous'),
                    selected: selectedCategory == null,
                    onSelected: (_) {
                      ref
                          .read(selectedBusinessCategoryProvider.notifier)
                          .clear();
                    },
                  ),
                ),
                ...BusinessCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(category.icon, size: 18),
                      label: Text(category.label),
                      selected: selectedCategory == category,
                      onSelected: (_) {
                        ref
                            .read(selectedBusinessCategoryProvider.notifier)
                            .select(category);
                      },
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
                          Icon(
                            Icons.error_outline,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/businesses/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
