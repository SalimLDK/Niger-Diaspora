import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audio_room_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget to display collection/fundraising progress in audio rooms
class CollectionProgressWidget extends ConsumerWidget {
  /// The audio room with collection data
  final AudioRoomEntity room;

  /// Whether to show in compact mode
  final bool compact;

  /// Callback when contribute button is pressed
  final VoidCallback? onContribute;

  const CollectionProgressWidget({
    super.key,
    required this.room,
    this.compact = false,
    this.onContribute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!room.hasActiveCollection) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactView(context);
    }

    return _buildExpandedView(context);
  }

  Widget _buildCompactView(BuildContext context) {
    final progress = room.collectionProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getCollectionColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCollectionColor().withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCollectionIcon(),
            size: 16,
            color: _getCollectionColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.collectionTypeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getCollectionColor(),
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(_getCollectionColor()),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${progress.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getCollectionColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    final progress = room.collectionProgress;
    final currencyFormat = NumberFormat.currency(
      symbol: _getCurrencySymbol(),
      decimalDigits: 0,
    );
    final amountCollected = room.collectionAmount / 100;
    final goalAmount = (room.collectionGoal ?? 0) / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCollectionColor().withValues(alpha: 0.1),
            _getCollectionColor().withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCollectionColor().withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getCollectionColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCollectionIcon(),
                  color: _getCollectionColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCollectionColor(),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            room.collectionTypeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (room.collectionBeneficiary != null)
                      Text(
                        AppLocalizations.of(context)!.forBeneficiary(room.collectionBeneficiary!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Description
          if (room.collectionDescription != null) ...[
            const SizedBox(height: 12),
            Text(
              room.collectionDescription!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFormat.format(amountCollected),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getCollectionColor(),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.goalAmount(currencyFormat.format(goalAmount)),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  // Background
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progress
                  FractionallySizedBox(
                    widthFactor: (progress / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getCollectionColor(),
                            _getCollectionColor().withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: _getCollectionColor().withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.toStringAsFixed(1)}% atteint',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          // Contribute button
          if (onContribute != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onContribute,
                icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.contribute),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getCollectionColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCollectionIcon() {
    return switch (room.collectionType) {
      CollectionType.familyEvent => Icons.celebration_rounded,
      CollectionType.emergency => Icons.emergency_rounded,
      CollectionType.communityProject => Icons.foundation_rounded,
      CollectionType.associationDues => Icons.groups_rounded,
      CollectionType.custom => Icons.volunteer_activism_rounded,
      CollectionType.none => Icons.money_off_rounded,
    };
  }

  Color _getCollectionColor() {
    return switch (room.collectionType) {
      CollectionType.familyEvent => const Color(0xFFE91E63), // Pink
      CollectionType.emergency => const Color(0xFFE53935), // Red
      CollectionType.communityProject => const Color(0xFF43A047), // Green
      CollectionType.associationDues => const Color(0xFF1E88E5), // Blue
      CollectionType.custom => AppColors.secondary,
      CollectionType.none => Colors.grey,
    };
  }

  String _getCurrencySymbol() {
    // Default to XOF for now, can be extended based on room settings
    return 'FCFA ';
  }
}

/// Bottom sheet for contributing to a collection
class ContributeBottomSheet extends ConsumerStatefulWidget {
  final AudioRoomEntity room;
  final Function(int amount, String? message) onContribute;

  const ContributeBottomSheet({
    super.key,
    required this.room,
    required this.onContribute,
  });

  @override
  ConsumerState<ContributeBottomSheet> createState() =>
      _ContributeBottomSheetState();
}

class _ContributeBottomSheetState extends ConsumerState<ContributeBottomSheet> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  int? _selectedPresetAmount;
  bool _isLoading = false;

  // Preset amounts in cents (XOF)
  final List<int> _presetAmounts = [
    100000, // 1,000 XOF
    500000, // 5,000 XOF
    1000000, // 10,000 XOF
    2500000, // 25,000 XOF
    5000000, // 50,000 XOF
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Color _getCollectionColor() {
    return switch (widget.room.collectionType) {
      CollectionType.familyEvent => const Color(0xFFE91E63),
      CollectionType.emergency => const Color(0xFFE53935),
      CollectionType.communityProject => const Color(0xFF43A047),
      CollectionType.associationDues => const Color(0xFF1E88E5),
      CollectionType.custom => AppColors.secondary,
      CollectionType.none => Colors.grey,
    };
  }

  void _selectPreset(int amount) {
    setState(() {
      _selectedPresetAmount = amount;
      _amountController.text = (amount ~/ 100).toString();
    });
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      await widget.onContribute(
        amount * 100, // Convert to cents
        _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCollectionColor();
    final currencyFormat = NumberFormat.currency(
      symbol: 'FCFA ',
      decimalDigits: 0,
    );

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.contribute,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        widget.room.collectionTypeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.room.collectionBeneficiary != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcon.person, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.forBeneficiary(widget.room.collectionBeneficiary!),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Preset amounts
            Text(
              AppLocalizations.of(context)!.suggestedAmount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedPresetAmount == amount;
                return GestureDetector(
                  onTap: () => _selectPreset(amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      currencyFormat.format(amount / 100),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Custom amount
            Text(
              AppLocalizations.of(context)!.orEnterAmount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.amountInXof,
                prefixText: 'FCFA ',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedPresetAmount = null;
                });
              },
            ),

            const SizedBox(height: 16),

            // Optional message
            TextField(
              controller: _messageController,
              maxLines: 2,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.messageOptional,
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppIcon(AppIcon.heart, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.confirmContribution,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small badge showing collection type on room cards
class CollectionBadge extends StatelessWidget {
  final CollectionType type;

  const CollectionBadge({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (type == CollectionType.none) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _getLabel(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    return switch (type) {
      CollectionType.familyEvent => Icons.celebration_rounded,
      CollectionType.emergency => Icons.emergency_rounded,
      CollectionType.communityProject => Icons.foundation_rounded,
      CollectionType.associationDues => Icons.groups_rounded,
      CollectionType.custom => Icons.volunteer_activism_rounded,
      CollectionType.none => Icons.money_off_rounded,
    };
  }

  Color _getColor() {
    return switch (type) {
      CollectionType.familyEvent => const Color(0xFFE91E63),
      CollectionType.emergency => const Color(0xFFE53935),
      CollectionType.communityProject => const Color(0xFF43A047),
      CollectionType.associationDues => const Color(0xFF1E88E5),
      CollectionType.custom => AppColors.secondary,
      CollectionType.none => Colors.grey,
    };
  }

  String _getLabel() {
    return switch (type) {
      CollectionType.familyEvent => 'Collecte',
      CollectionType.emergency => 'Urgence',
      CollectionType.communityProject => 'Projet',
      CollectionType.associationDues => 'Cotisation',
      CollectionType.custom => 'Collecte',
      CollectionType.none => '',
    };
  }
}
