import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/recipient_entity.dart';
import '../providers/transfer_provider.dart';

class RecipientSelectScreen extends ConsumerStatefulWidget {
  const RecipientSelectScreen({super.key});

  @override
  ConsumerState<RecipientSelectScreen> createState() => _RecipientSelectScreenState();
}

class _RecipientSelectScreenState extends ConsumerState<RecipientSelectScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  RecipientType? _filterType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un beneficiaire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _navigateToAddRecipient(context),
            tooltip: 'Ajouter un beneficiaire',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(
                  child: _buildRecipientsList(user.id),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddRecipient(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un beneficiaire...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(null, 'Tous'),
          const SizedBox(width: 8),
          _buildFilterChip(RecipientType.mobileWallet, 'Mobile'),
          const SizedBox(width: 8),
          _buildFilterChip(RecipientType.bankAccount, 'Banque'),
          const SizedBox(width: 8),
          _buildFilterChip(RecipientType.cashPickup, 'Especes'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(RecipientType? type, String label) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? type : null;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildRecipientsList(String userId) {
    final recipientsAsync = ref.watch(userRecipientsProvider(userId));

    return recipientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erreur: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(userRecipientsProvider(userId)),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
      data: (recipients) {
        // Apply filters
        var filtered = recipients.where((r) {
          if (_searchQuery.isNotEmpty) {
            final matchesSearch = r.fullName.toLowerCase().contains(_searchQuery) ||
                r.phone.toLowerCase().contains(_searchQuery);
            if (!matchesSearch) return false;
          }
          if (_filterType != null && r.type != _filterType) {
            return false;
          }
          return true;
        }).toList();

        // Sort: favorites first, then by last used
        filtered.sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return b.isFavorite ? 1 : -1;
          }
          if (a.lastUsedAt != null && b.lastUsedAt != null) {
            return b.lastUsedAt!.compareTo(a.lastUsedAt!);
          }
          return 0;
        });

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final recipient = filtered[index];
            return _buildRecipientTile(recipient, userId);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _filterType != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'Aucun beneficiaire trouve'
                : 'Aucun beneficiaire enregistre',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Essayez de modifier vos filtres'
                : 'Ajoutez votre premier beneficiaire',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddRecipient(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter un beneficiaire'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipientTile(RecipientEntity recipient, String userId) {
    return Dismissible(
      key: Key(recipient.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer le beneficiaire ?'),
            content: Text('Voulez-vous supprimer ${recipient.fullName} ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(recipientNotifierProvider.notifier).deleteRecipient(
          recipient.id,
          userId,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${recipient.fullName} supprime')),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(recipient.type).withValues(alpha: 0.2),
          child: Icon(
            _getTypeIcon(recipient.type),
            color: _getTypeColor(recipient.type),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(recipient.fullName)),
            if (recipient.isFavorite)
              const Icon(Icons.star, color: Colors.amber, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipient.phone),
            Text(
              recipient.type.label,
              style: TextStyle(
                color: _getTypeColor(recipient.type),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                recipient.isFavorite ? Icons.star : Icons.star_border,
                color: recipient.isFavorite ? Colors.amber : null,
              ),
              onPressed: () {
                ref.read(recipientNotifierProvider.notifier).toggleFavorite(
                  recipient.id,
                  !recipient.isFavorite,
                  userId,
                );
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _selectRecipient(recipient),
        onLongPress: () => _showRecipientOptions(context, recipient, userId),
      ),
    );
  }

  void _selectRecipient(RecipientEntity recipient) {
    context.pop(recipient);
  }

  Future<void> _navigateToAddRecipient(BuildContext context) async {
    final result = await context.push<RecipientEntity>('/transfers/recipient/add');
    if (result != null && mounted) {
      _selectRecipient(result);
    }
  }

  void _showRecipientOptions(
    BuildContext context,
    RecipientEntity recipient,
    String userId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Envoyer de l\'argent'),
              onTap: () {
                Navigator.pop(context);
                _selectRecipient(recipient);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () async {
                Navigator.pop(context);
                final result = await context.push<RecipientEntity>(
                  '/transfers/recipient/add',
                  extra: recipient,
                );
                if (result != null && mounted) {
                  ref.invalidate(userRecipientsProvider(userId));
                }
              },
            ),
            ListTile(
              leading: Icon(
                recipient.isFavorite ? Icons.star_border : Icons.star,
                color: recipient.isFavorite ? null : Colors.amber,
              ),
              title: Text(recipient.isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris'),
              onTap: () {
                Navigator.pop(context);
                ref.read(recipientNotifierProvider.notifier).toggleFavorite(
                  recipient.id,
                  !recipient.isFavorite,
                  userId,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Supprimer', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Supprimer ?'),
                    content: Text('Supprimer ${recipient.fullName} ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref.read(recipientNotifierProvider.notifier).deleteRecipient(
                    recipient.id,
                    userId,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(RecipientType type) {
    switch (type) {
      case RecipientType.mobileWallet:
        return Icons.phone_android;
      case RecipientType.bankAccount:
        return Icons.account_balance;
      case RecipientType.cashPickup:
        return Icons.storefront;
    }
  }

  Color _getTypeColor(RecipientType type) {
    switch (type) {
      case RecipientType.mobileWallet:
        return AppColors.primary;
      case RecipientType.bankAccount:
        return AppColors.info;
      case RecipientType.cashPickup:
        return AppColors.secondary;
    }
  }
}
