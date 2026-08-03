import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../domain/entities/recipient_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Screen to add a friend as a recipient for money transfers
class FriendRecipientSelectScreen extends ConsumerStatefulWidget {
  const FriendRecipientSelectScreen({super.key});

  @override
  ConsumerState<FriendRecipientSelectScreen> createState() =>
      _FriendRecipientSelectScreenState();
}

class _FriendRecipientSelectScreenState
    extends ConsumerState<FriendRecipientSelectScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un bénéficiaire')),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: friendsAsync.when(
              data: (friends) => _buildFriendsList(friends),
              loading: () => const LoadingIndicator(),
              error: (error, _) => Center(child: Text('Erreur: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transfers/recipient/add'),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.spacing16,
        right: AppSpacing.spacing16,
        top: AppSpacing.spacing16,
      ),
      child: StandardSearchBar(
        controller: _searchController,
        hintText: 'Rechercher un ami...',
        onChanged:
            (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildFriendsList(List<FriendEntity> friends) {
    final filtered =
        friends.where((friend) {
          if (_searchQuery.isEmpty) return true;
          return friend.displayName.toLowerCase().contains(_searchQuery);
        }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.spacing8),
      itemBuilder: (context, index) {
        return _buildFriendTile(filtered[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.spacing16),
            Text(
              _searchQuery.isEmpty ? 'Aucun ami' : 'Aucun résultat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.spacing8),
            Text(
              _searchQuery.isEmpty
                  ? 'Ajoutez des amis pour les sélectionner comme bénéficiaires'
                  : 'Aucun ami ne correspond à votre recherche',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppSpacing.spacing24),
              ElevatedButton.icon(
                onPressed: () => context.push('/transfers/recipient/add'),
                icon: const Icon(Icons.person_add),
                label: const Text('Ajouter manuellement'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(FriendEntity friend) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () => _selectFriend(friend),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          child: Row(
            children: [
              _buildAvatar(friend),
              const SizedBox(width: AppSpacing.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(FriendEntity friend) {
    Widget avatarContent;
    if (friend.photoUrl != null && friend.photoUrl!.isNotEmpty) {
      avatarContent = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: friend.photoUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholderAvatar(friend),
          errorWidget: (context, url, error) => _buildPlaceholderAvatar(friend),
        ),
      );
    } else {
      avatarContent = _buildPlaceholderAvatar(friend);
    }

    return Stack(
      children: [
        avatarContent,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: OnlineStatusIndicator(
              userId: friend.id,
              showText: false,
              dotSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar(FriendEntity friend) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: Text(
        friend.displayName.isNotEmpty
            ? friend.displayName[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  void _selectFriend(FriendEntity friend) {
    // Navigate to add recipient screen with pre-filled friend info
    final recipientEntity = RecipientEntity(
      id: '', // Will be generated
      userId: '', // Will be filled by the add screen
      fullName: friend.displayName,
      phone: '', // Will be filled by user
      type: RecipientType.mobileWallet, // Default type
      isFavorite: false,
    );
    context.push('/transfers/recipient/add', extra: recipientEntity);
  }
}
