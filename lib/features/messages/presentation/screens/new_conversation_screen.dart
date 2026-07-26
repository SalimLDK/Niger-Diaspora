import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/data/datasources/friend_remote_datasource.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/message_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  List<ProfileModel> _friendResults = [];
  List<ProfileModel> _otherResults = [];
  final List<ProfileModel> _selectedUsers = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  /// Obtenir les initiales du nom
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _friendResults = [];
        _otherResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      final currentUserId = currentUser?.id;

      // Filter out blocked users
      final blockedUsers = ref.read(blockedUsersProvider).valueOrNull ?? [];
      final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

      // Search friends first
      List<ProfileModel> friendProfiles = [];
      if (currentUserId != null) {
        final friendDataSource = FriendRemoteDataSourceImpl();
        final friends = await friendDataSource.searchFriends(currentUserId, query);

        // Convert FriendModel to ProfileModel for consistent display
        friendProfiles = friends
            .where((f) => !blockedUserIds.contains(f.id))
            .map((f) => ProfileModel(
                  id: f.id,
                  displayName: f.displayName,
                  photoUrl: f.photoUrl,
                ))
            .toList();
      }

      // Search all profiles
      final profileDataSource = ProfileRemoteDataSourceImpl();
      final allProfiles = await profileDataSource.searchProfiles(query);

      // Filter out blocked users and friends (to avoid duplicates)
      final friendIds = friendProfiles.map((f) => f.id).toSet();
      final otherProfiles = allProfiles
          .where((user) =>
              !blockedUserIds.contains(user.id) &&
              !friendIds.contains(user.id) &&
              user.id != currentUserId)
          .toList();

      setState(() {
        _friendResults = friendProfiles;
        _otherResults = otherProfiles;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _friendResults = [];
        _otherResults = [];
        _isSearching = false;
      });
    }
  }

  void _toggleUserSelection(ProfileModel user) {
    setState(() {
      if (_selectedUsers.any((u) => u.id == user.id)) {
        _selectedUsers.removeWhere((u) => u.id == user.id);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _startConversation() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedUsers.length == 1) {
        // Conversation individuelle
        final conversation = await ref
            .read(createConversationProvider.notifier)
            .createIndividual(_selectedUsers.first.id);

        if (conversation != null && mounted) {
          context.push(
            '/messages/${conversation.id}',
            extra: {
              'name': _selectedUsers.first.displayName,
              'imageUrl': _selectedUsers.first.photoUrl,
              'otherUserId': _selectedUsers.first.id,
              'isGroup': false,
            },
          );
        }
      } else {
        // Conversation de groupe
        if (_groupNameController.text.trim().isEmpty) {
          _showGroupNameDialog();
          setState(() => _isLoading = false);
          return;
        }

        final conversation = await ref
            .read(createConversationProvider.notifier)
            .createGroup(
              participantIds: _selectedUsers.map((u) => u.id).toList(),
              groupName: _groupNameController.text.trim(),
            );

        if (conversation != null && mounted) {
          context.push(
            '/messages/${conversation.id}',
            extra: {
              'name': _groupNameController.text.trim(),
              'imageUrl': null,
              'isGroup': true,
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGroupNameDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.groupName),
            content: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(hintText: l10n.enterGroupName),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_groupNameController.text.trim().isNotEmpty) {
                    _startConversation();
                  }
                },
                child: Text(l10n.create),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.newConversationTitle),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _startConversation,
              child:
                  _isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.adaptivePrimaryColor,
                        ),
                      )
                      : Text(
                        l10n.start,
                        style: TextStyle(
                          color: context.adaptivePrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            color: context.surfaceColor,
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: l10n.searchMember,
                prefixIcon: AppIcon(
                  AppIcon.search,
                  color: context.textTertiaryColor,
                ),
                filled: true,
                fillColor: context.surfaceVariantColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Utilisateurs sélectionnés
          if (_selectedUsers.isNotEmpty) ...[
            Container(
              height: 90,
              color: context.surfaceColor,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: context.adaptivePrimaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child:
                                  user.photoUrl != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          user.photoUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              _getInitials(user.displayName),
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      : Center(
                                        child: Text(
                                          _getInitials(user.displayName),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => _toggleUserSelection(user),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: AppIcon(
                                    AppIcon.close,
                                    size: 16,
                                    color: context.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            user.displayName ?? 'Utilisateur',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_selectedUsers.length > 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: context.surfaceColor,
                child: Row(
                  children: [
                    AppIcon(
                      AppIcon.groups,
                      color: context.adaptiveSecondaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.createGroupWith(_selectedUsers.length),
                      style: TextStyle(
                        color: context.adaptiveSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],

          // Résultats de recherche
          Expanded(
            child:
                _isSearching
                    ? Center(
                      child: CircularProgressIndicator(
                        color: context.adaptivePrimaryColor,
                      ),
                    )
                    : (_friendResults.isEmpty && _otherResults.isEmpty)
                    ? _buildEmptyState()
                    : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Friends section
                        if (_friendResults.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                AppIcon(
                                  AppIcon.people,
                                  size: 18,
                                  color: context.adaptivePrimaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.friends,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.adaptivePrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._friendResults.map((user) {
                            final isSelected = _selectedUsers.any(
                              (u) => u.id == user.id,
                            );
                            return _UserListItem(
                              user: user,
                              isSelected: isSelected,
                              onTap: () => _toggleUserSelection(user),
                            );
                          }),
                        ],
                        // Other members section
                        if (_otherResults.isNotEmpty) ...[
                          if (_friendResults.isNotEmpty)
                            const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 18,
                                  color: context.textSecondaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Autres membres',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._otherResults.map((user) {
                            final isSelected = _selectedUsers.any(
                              (u) => u.id == user.id,
                            );
                            return _UserListItem(
                              user: user,
                              isSelected: isSelected,
                              onTap: () => _toggleUserSelection(user),
                            );
                          }),
                        ],
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            AppIcon.search,
            size: 64,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchAMember,
            style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final ProfileModel user;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserListItem({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  /// Obtenir les initiales du nom
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                  : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border:
              isSelected
                  ? Border.all(color: context.adaptivePrimaryColor, width: 2)
                  : null,
          boxShadow: [
            BoxShadow(
              color: context.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  user.photoUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          user.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Center(
                                child: Text(
                                  _getInitials(user.displayName),
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        ),
                      )
                      : Center(
                        child: Text(
                          _getInitials(user.displayName),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? AppLocalizations.of(context)!.user,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (user.profession != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.profession!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcon.check,
                  color: context.textInverseColor,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
