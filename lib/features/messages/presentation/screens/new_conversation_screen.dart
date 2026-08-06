import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/data/datasources/friend_remote_datasource.dart';
import '../../../profile/data/datasources/profile_supabase_datasource.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../domain/entities/conversation_entity.dart';
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool get _hasQuery => _searchController.text.trim().isNotEmpty;

  List<ProfileModel> _friendResults = [];
  List<ProfileModel> _otherResults = [];
  final List<ProfileModel> _selectedUsers = [];
  bool _isSearching = false;
  bool _isLoading = false;

  /// Ma position (pour la distance des « Proches de vous »), si disponible.
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _maybeLoadNearby();
  }

  /// Charge les membres proches pour l'état au repos — **sans** demander la
  /// permission depuis cet écran : on ne charge que si elle est déjà accordée
  /// et si l'utilisateur a activé « membres à proximité ». Sinon la section ne
  /// s'affiche simplement pas.
  Future<void> _maybeLoadNearby() async {
    if (!ref.read(nearbyMembersEnabledProvider)) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      _myLat = pos.latitude;
      _myLng = pos.longitude;
      await ref
          .read(nearbyProfilesNotifierProvider.notifier)
          .loadNearbyProfiles(pos.latitude, pos.longitude, radiusKm: 50);
      if (mounted) setState(() {});
    } catch (_) {
      // Localisation indisponible/refusée : on n'affiche pas la section.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Ouvre « Mes notes » (self-chat), en réutilisant l'éventuelle conversation
  /// déjà chargée. Même flux que la tuile épinglée de MessagesScreen.
  Future<void> _openSelfNotes() async {
    final conversation =
        await ref.read(ensureSelfNotesProvider.notifier).ensure();
    if (!mounted) return;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir Mes notes pour le moment"),
        ),
      );
      return;
    }
    context.push(
      '/messages/${conversation.id}',
      extra: {'name': l10n.messagesMyNotes, 'isGroup': false, 'isSelfNotes': true},
    );
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
      // Recherche de personnes : source Supabase, pas Firestore.
      //
      // Le provider principal des profils est passé à Supabase, mais ce chemin
      // instanciait encore `ProfileRemoteDataSourceImpl`, qui lit Firestore.
      // Relevé le 2026-08-06 : 10 profils dans Supabase, 2 documents dans
      // Firestore dont **un seul** avec un nom renseigné. La recherche ne
      // pouvait donc trouver qu'une personne sur dix, sans erreur ni log.
      final profileDataSource = ProfileSupabaseDataSource();
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
            backgroundColor: context.errorColor,
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
              focusNode: _searchFocus,
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
                                color: context.adaptivePrimaryColor,
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
                                              style: TextStyle(
                                                color: context.onPrimaryColor,
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
                                          style: TextStyle(
                                            color: context.onPrimaryColor,
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
                            user.displayName ?? l10n.user,
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
                    : !_hasQuery
                    ? _buildIdleContent()
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
                                  l10n.otherMembers,
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

  /// Recherche active mais sans résultat.
  Widget _buildEmptyState() {
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
            l10n.noSearchResults,
            style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  /// État au repos (aucune recherche) : raccourcis, « Proches de vous »
  /// (si géoloc déjà autorisée), puis contacts récents.
  Widget _buildIdleContent() {
    final myId = ref.watch(currentUserProvider).valueOrNull?.id ?? '';
    final recents = (ref.watch(conversationsProvider).valueOrNull ?? [])
        .where((c) => c.isIndividual && !c.isSelfNotesFor(myId))
        .take(12)
        .toList();

    // « Proches de vous » : membres géolocalisés (mode « à proximité » activé),
    // hors soi-même. La liste vient du provider partagé avec l'accueil/la carte.
    final nearby = ref.watch(nearbyMembersEnabledProvider)
        ? (ref.watch(nearbyProfilesNotifierProvider).valueOrNull ??
                const <ProfileEntity>[])
            .where((p) => p.id != myId)
            .take(8)
            .toList()
        : const <ProfileEntity>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShortcut(
          icon: AppIcon(AppIcon.groups, size: 22, color: context.adaptivePrimaryColor),
          title: 'Nouveau groupe',
          subtitle: 'Sélectionnez des membres, puis nommez le groupe',
          onTap: () {
            _searchFocus.requestFocus();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Recherchez et sélectionnez plusieurs membres pour créer un groupe.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildShortcut(
          icon: Icon(Icons.edit_note_rounded, size: 24, color: context.adaptivePrimaryColor),
          title: l10n.messagesMyNotes,
          subtitle: 'Vos brouillons, visibles de vous seul',
          onTap: _openSelfNotes,
        ),
        if (nearby.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionLabel('Proches de vous'),
          const SizedBox(height: 8),
          ...nearby.map(_buildNearbyTile),
        ],
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionLabel('Contacts récents'),
          const SizedBox(height: 8),
          ...recents.map((c) => _buildRecentTile(c, myId)),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.textSecondaryColor,
        ),
      );

  /// Distance « à N km » depuis ma position, si connue et si le membre est
  /// géolocalisé.
  String? _distanceLabel(ProfileEntity p) {
    if (_myLat == null || p.latitude == null || p.longitude == null) return null;
    final meters = Geolocator.distanceBetween(
      _myLat!,
      _myLng!,
      p.latitude!,
      p.longitude!,
    );
    final km = meters / 1000;
    return km < 1 ? '< 1 km' : '${km.round()} km';
  }

  /// Ouvre directement une conversation individuelle avec ce membre.
  Future<void> _openWith(ProfileEntity p) async {
    final conversation = await ref
        .read(createConversationProvider.notifier)
        .createIndividual(p.id);
    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': p.displayName,
          'imageUrl': p.photoUrl,
          'otherUserId': p.id,
          'isGroup': false,
        },
      );
    }
  }

  Widget _buildNearbyTile(ProfileEntity p) {
    final online = p.isOnline && p.showOnlineStatus;
    final subtitleParts = <String>[
      if (p.profession != null && p.profession!.isNotEmpty) p.profession!,
      if (_distanceLabel(p) != null) _distanceLabel(p)!,
      if (online) l10n.online,
    ];

    return GestureDetector(
      onTap: () => _openWith(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.photoUrl != null
                      ? Image.network(
                          p.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _nearbyInitials(p),
                        )
                      : _nearbyInitials(p),
                ),
                if (online)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D7D46),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.backgroundColor,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName ?? AppLocalizations.of(context)!.user,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyInitials(ProfileEntity p) => Center(
        child: Text(
          _getInitials(p.displayName),
          style: TextStyle(
            color: context.onPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _buildShortcut({
    required Widget icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textTertiaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTile(ConversationEntity conversation, String myId) {
    final name = conversation.name ?? l10n.user;
    final photoUrl = conversation.imageUrl;
    return GestureDetector(
      onTap: () => context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': name,
          'imageUrl': photoUrl,
          'isGroup': false,
          'otherUserId': conversation.getOtherParticipantId(myId),
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.adaptivePrimaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          _getInitials(name),
                          style: TextStyle(
                            color: context.onPrimaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: context.onPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                color: context.adaptivePrimaryColor,
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
                                  style: TextStyle(
                                    color: context.onPrimaryColor,
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
                          style: TextStyle(
                            color: context.onPrimaryColor,
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
