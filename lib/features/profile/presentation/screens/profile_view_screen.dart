import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../friends/domain/repositories/friend_repository.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;
  final ProfileEntity? initialProfile;

  const ProfileViewScreen({
    super.key,
    required this.userId,
    this.initialProfile,
  });

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  ProfileEntity? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      await ref
          .read(profileNotifierProvider.notifier)
          .loadProfile(widget.userId);
      final profile = ref.read(profileNotifierProvider).valueOrNull;
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startConversation() async {
    if (_profile == null) return;

    // Create or get existing conversation with this user
    final conversation = await ref
        .read(createConversationProvider.notifier)
        .createIndividual(_profile!.id);

    if (conversation != null && mounted) {
      context.push(
        '/messages/${conversation.id}',
        extra: {
          'name': _profile!.displayName,
          'imageUrl': _profile!.photoUrl,
          'otherUserId': _profile!.id,
          'isGroup': false,
        },
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_profile == null) return;

    final l10n = AppLocalizations.of(context)!;
    final success = await ref
        .read(friendRequestNotifierProvider.notifier)
        .sendRequest(
          receiverId: _profile!.id,
          receiverName: _profile!.displayName ?? l10n.member,
          receiverPhotoUrl: _profile!.photoUrl,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Demande d\'ami envoyée' : 'Échec de l\'envoi',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  String _buildLocationString(AppLocalizations l10n) {
    final city = _profile?.currentCity;
    final region = _profile?.currentRegion;
    final country = _profile?.currentCountry;

    final parts = <String>[];

    if (city != null && city.isNotEmpty) {
      parts.add(city);
    }

    if (region != null && region.isNotEmpty) {
      parts.add(region);
    }

    if (country != null && country.isNotEmpty) {
      parts.add(country);
    }

    return parts.join(', ');
  }

  String _buildOriginString(AppLocalizations l10n) {
    final region = _profile?.originRegion;
    final city = _profile?.originCity;

    if (region != null &&
        region.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      return '${l10n.fromCity(city)} ($region)';
    } else if (region != null && region.isNotEmpty) {
      return l10n.fromRegion(region);
    } else if (city != null && city.isNotEmpty) {
      return l10n.fromCity(city);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(l10n.profileNotFound)),
      );
    }

    final locationString = _buildLocationString(l10n);
    final originString = _buildOriginString(l10n);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: context.textPrimaryColor),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child:
                            _profile!.photoUrl != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.network(
                                    _profile!.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Icon(
                                          Icons.person,
                                          size: 50,
                                          color: context.adaptivePrimaryColor,
                                        ),
                                  ),
                                )
                                : Icon(
                                  Icons.person,
                                  size: 50,
                                  color: context.adaptivePrimaryColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Center(
                    child: Text(
                      _profile!.displayName ?? l10n.member,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),

                  if (_profile!.profession != null &&
                      _profile!.profession!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _profile!.profession!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Current location (city, country)
                  if (locationString.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationString,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Origin (region, city in Niger)
                  if (originString.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 18,
                            color: context.adaptiveSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            originString,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bio
                  if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
                    Text(
                      l10n.about,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _profile!.bio!,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Compétences
                  if (_profile!.skills.isNotEmpty) ...[
                    Text(
                      l10n.skills,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _profile!.skills
                              .map(
                                (skill) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.adaptivePrimaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    skill,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.adaptivePrimaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Intérêts
                  if (_profile!.interests.isNotEmpty) ...[
                    Text(
                      l10n.interests,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _profile!.interests
                              .map(
                                (interest) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariantColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    interest,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Langues
                  if (_profile!.languages.isNotEmpty) ...[
                    Text(
                      l10n.languagesSpoken,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _profile!.languages
                              .map(
                                (language) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariantColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    language,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final friendshipStatus = ref.watch(
            friendshipStatusProvider(widget.userId),
          );

          return friendshipStatus.when(
            data: (status) {
              // Determine button configuration based on friendship status
              String buttonText = '';
              IconData buttonIcon = Icons.help_outline;
              VoidCallback? onPressed;
              Color backgroundColor = context.adaptivePrimaryColor;

              switch (status) {
                case FriendshipStatus.friends:
                  buttonIcon = Icons.chat;
                  onPressed = _startConversation;
                  backgroundColor = context.adaptivePrimaryColor;
                  break;

                case FriendshipStatus.pendingSent:
                  buttonText = 'Demande envoyée';
                  buttonIcon = Icons.schedule;
                  onPressed = null; // Disabled
                  backgroundColor = context.textSecondaryColor;
                  break;

                case FriendshipStatus.pendingReceived:
                  buttonText = 'Accepter la demande';
                  buttonIcon = Icons.person_add;
                  onPressed = () async {
                    // Find the request and accept it
                    final requests = await ref.read(
                      receivedFriendRequestsProvider.future,
                    );
                    final request = requests.firstWhere(
                      (r) => r.senderId == widget.userId,
                      orElse: () => throw Exception('Request not found'),
                    );
                    await ref
                        .read(friendRequestNotifierProvider.notifier)
                        .acceptRequest(request.id);
                  };
                  backgroundColor = context.successColor;
                  break;

                case FriendshipStatus.none:
                  buttonText = 'Envoyer une demande d\'ami';
                  buttonIcon = Icons.person_add;
                  onPressed = _sendFriendRequest;
                  backgroundColor = context.adaptivePrimaryColor;
                  break;
              }

              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(buttonIcon),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              );
            },
            loading:
                () => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                ),
            error:
                (_, __) => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _sendFriendRequest,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Envoyer une demande d\'ami'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
          );
        },
      ),
    );
  }
}
