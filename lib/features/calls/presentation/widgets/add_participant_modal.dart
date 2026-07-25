import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/eligible_participants_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Modal for selecting participants to add to an ongoing call
class AddParticipantModal extends ConsumerStatefulWidget {
  /// IDs of users to exclude (current participants)
  final List<String> excludeIds;

  /// Callback when participants are selected and confirmed
  final void Function(List<EligibleParticipant> participants) onParticipantsSelected;

  const AddParticipantModal({
    super.key,
    required this.excludeIds,
    required this.onParticipantsSelected,
  });

  /// Show the modal as a bottom sheet
  static Future<void> show({
    required BuildContext context,
    required List<String> excludeIds,
    required void Function(List<EligibleParticipant> participants) onParticipantsSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddParticipantModal(
        excludeIds: excludeIds,
        onParticipantsSelected: onParticipantsSelected,
      ),
    );
  }

  @override
  ConsumerState<AddParticipantModal> createState() =>
      _AddParticipantModalState();
}

class _AddParticipantModalState extends ConsumerState<AddParticipantModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  final Map<String, EligibleParticipant> _selectedParticipants = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    // Get filtered participants
    final participants = ref.watch(
      filteredEligibleParticipantsProvider(
        (excludeIds: widget.excludeIds, searchQuery: _searchQuery),
      ),
    );

    // Separate friends and contacts
    final friends = participants.where((p) => p.isFriend).toList();
    final contacts = participants.where((p) => !p.isFriend).toList();

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIcon(AppIcon.personAdd,
                  color: context.adaptivePrimaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.addParticipant,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: AppIcon(AppIcon.close,
                    color: context.textSecondaryColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchMember,
                prefixIcon: AppIcon(AppIcon.search,
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

          const SizedBox(height: 16),

          // Participant list
          Expanded(
            child: _buildParticipantList(
              l10n,
              friends,
              contacts,
            ),
          ),

          // Confirm button (visible when at least one participant selected)
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '${l10n.addToCall} (${_selectedIds.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmSelection() {
    Navigator.of(context).pop();
    widget.onParticipantsSelected(_selectedParticipants.values.toList());
  }

  Widget _buildParticipantList(
    AppLocalizations l10n,
    List<EligibleParticipant> friends,
    List<EligibleParticipant> contacts,
  ) {
    final participantsAsync =
        ref.watch(eligibleParticipantsProvider(widget.excludeIds));

    return participantsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.adaptivePrimaryColor,
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcon.error,
              size: 48,
              color: context.textTertiaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.error,
              style: TextStyle(color: context.textSecondaryColor),
            ),
          ],
        ),
      ),
      data: (_) {
        if (friends.isEmpty && contacts.isEmpty) {
          return _buildEmptyState(l10n);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // Friends section
            if (friends.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.people,
                label: l10n.friends,
                color: context.adaptivePrimaryColor,
              ),
              const SizedBox(height: 8),
              ...friends.map(
                (p) => _ParticipantListItem(
                  participant: p,
                  isSelected: _selectedIds.contains(p.id),
                  onTap: () => _toggleParticipant(p),
                ),
              ),
            ],

            // Contacts section
            if (contacts.isNotEmpty) ...[
              if (friends.isNotEmpty) const SizedBox(height: 16),
              _buildSectionHeader(
                icon: Icons.chat_bubble_outline,
                label: l10n.recentConversations,
                color: context.textSecondaryColor,
              ),
              const SizedBox(height: 8),
              ...contacts.map(
                (p) => _ParticipantListItem(
                  participant: p,
                  isSelected: _selectedIds.contains(p.id),
                  onTap: () => _toggleParticipant(p),
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noEligibleParticipants,
            style: TextStyle(
              fontSize: 16,
              color: context.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.noEligibleParticipantsHint,
              style: TextStyle(
                fontSize: 13,
                color: context.textTertiaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleParticipant(EligibleParticipant participant) {
    setState(() {
      if (_selectedIds.contains(participant.id)) {
        _selectedIds.remove(participant.id);
        _selectedParticipants.remove(participant.id);
      } else {
        _selectedIds.add(participant.id);
        _selectedParticipants[participant.id] = participant;
      }
    });
  }
}

class _ParticipantListItem extends StatelessWidget {
  final EligibleParticipant participant;
  final bool isSelected;
  final VoidCallback onTap;

  const _ParticipantListItem({
    required this.participant,
    required this.isSelected,
    required this.onTap,
  });

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: context.adaptivePrimaryColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: context.shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: participant.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        participant.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            _getInitials(participant.displayName),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _getInitials(participant.displayName),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (participant.isFriend) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        AppIcon(AppIcon.person,
                          size: 12,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.friend,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.adaptivePrimaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? context.adaptivePrimaryColor
                      : context.textTertiaryColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const AppIcon(AppIcon.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
