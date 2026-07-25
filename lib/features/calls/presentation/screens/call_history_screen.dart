import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/call_entity.dart';
import '../providers/call_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Filter type for call history
enum CallHistoryFilter { all, missed, incoming, outgoing }

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  CallHistoryFilter _selectedFilter = CallHistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final callHistoryAsync = ref.watch(callHistoryProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final currentUserId = currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.callHistory),
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: context.textTertiaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.textPrimaryColor),
            onSelected: (value) {
              if (value == 'clear') {
                _showClearHistoryDialog(context, ref);
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const AppIcon(AppIcon.delete, color: Colors.red),
                        const SizedBox(width: 12),
                        Text(l10n.clearHistory),
                      ],
                    ),
                  ),
                ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterTabs(context, l10n),
        ),
      ),
      body: callHistoryAsync.when(
        data: (calls) {
          // Apply filter
          final filteredCalls = _filterCalls(calls, currentUserId);

          if (filteredCalls.isEmpty) {
            return _buildEmptyState(context, l10n);
          }

          // Grouper les appels par date
          final groupedCalls = _groupCallsByDate(filteredCalls);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedCalls.length,
            itemBuilder: (context, index) {
              final entry = groupedCalls.entries.elementAt(index);
              return _buildDateSection(
                context,
                ref,
                entry.key,
                entry.value,
                currentUserId,
                l10n,
              );
            },
          );
        },
        loading:
            () => Center(
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            ),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(AppIcon.error,
                    size: 48,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingError,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(callHistoryProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: l10n.all,
            filter: CallHistoryFilter.all,
            icon: Icons.call,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: l10n.missedCall,
            filter: CallHistoryFilter.missed,
            icon: Icons.call_missed,
            iconColor: AppColors.error,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: l10n.incomingCall,
            filter: CallHistoryFilter.incoming,
            icon: Icons.call_received,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: l10n.outgoingCall,
            filter: CallHistoryFilter.outgoing,
            icon: Icons.call_made,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required CallHistoryFilter filter,
    required IconData icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedFilter == filter;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color:
                isSelected
                    ? Colors.white
                    : (iconColor ?? context.textSecondaryColor),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: context.adaptivePrimaryColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : context.textPrimaryColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: context.surfaceVariantColor,
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  List<CallEntity> _filterCalls(List<CallEntity> calls, String currentUserId) {
    switch (_selectedFilter) {
      case CallHistoryFilter.all:
        return calls;
      case CallHistoryFilter.missed:
        return calls
            .where(
              (call) =>
                  call.status == CallStatus.missed ||
                  call.status == CallStatus.declined,
            )
            .toList();
      case CallHistoryFilter.incoming:
        return calls.where((call) => call.isIncoming(currentUserId)).toList();
      case CallHistoryFilter.outgoing:
        return calls.where((call) => !call.isIncoming(currentUserId)).toList();
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    String emptyMessage;
    IconData emptyIcon;

    switch (_selectedFilter) {
      case CallHistoryFilter.all:
        emptyMessage = l10n.noCallHistory;
        emptyIcon = Icons.call_outlined;
        break;
      case CallHistoryFilter.missed:
        emptyMessage = l10n.noMissedCalls;
        emptyIcon = Icons.call_missed;
        break;
      case CallHistoryFilter.incoming:
        emptyMessage = l10n.noIncomingCalls;
        emptyIcon = Icons.call_received;
        break;
      case CallHistoryFilter.outgoing:
        emptyMessage = l10n.noOutgoingCalls;
        emptyIcon = Icons.call_made;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              emptyIcon,
              size: 64,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.noCallHistoryDescription,
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<CallEntity>> _groupCallsByDate(List<CallEntity> calls) {
    final Map<String, List<CallEntity>> grouped = {};

    for (final call in calls) {
      final dateKey = _getDateKey(call.createdAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(call);
    }

    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(date.year, date.month, date.day);

    if (callDate == today) {
      return 'today';
    } else if (callDate == yesterday) {
      return 'yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE', LocaleHelper.getDateFormatLocale(context)).format(date);
    } else {
      return DateFormat('d MMMM yyyy', LocaleHelper.getDateFormatLocale(context)).format(date);
    }
  }

  String _formatDateHeader(String key, AppLocalizations l10n) {
    if (key == 'today') return l10n.today('');
    if (key == 'yesterday') return l10n.yesterday('');
    return key.substring(0, 1).toUpperCase() + key.substring(1);
  }

  Widget _buildDateSection(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    List<CallEntity> calls,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            _formatDateHeader(dateKey, l10n),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textSecondaryColor,
            ),
          ),
        ),
        ...calls.map(
          (call) => _SwipeableCallHistoryItem(
            key: ValueKey(call.id),
            call: call,
            currentUserId: currentUserId,
            onTap: () => _onCallTap(context, ref, call, currentUserId),
            onCallBack: () => _onCallBack(context, ref, call, currentUserId),
            onDelete: () => _onDeleteCall(context, ref, call, l10n),
          ),
        ),
      ],
    );
  }

  Future<void> _onDeleteCall(
    BuildContext context,
    WidgetRef ref,
    CallEntity call,
    AppLocalizations l10n,
  ) async {
    final repository = ref.read(callRepositoryProvider);
    final result = await repository.deleteCall(call.id);

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteError),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (_) {
        ref.invalidate(callHistoryProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.callDeleted),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () {
                  // Note: Undo would require storing the deleted call
                  // For now, just show the message
                },
              ),
            ),
          );
        }
      },
    );
  }

  void _onCallTap(
    BuildContext context,
    WidgetRef ref,
    CallEntity call,
    String currentUserId,
  ) {
    final otherUserId = call.getOtherPartyId(currentUserId);
    context.push('/profile/$otherUserId');
  }

  void _onCallBack(
    BuildContext context,
    WidgetRef ref,
    CallEntity call,
    String currentUserId,
  ) {
    final otherUserId = call.getOtherPartyId(currentUserId);
    final otherUserName = call.getOtherPartyName(currentUserId);
    final otherUserPhoto = call.getOtherPartyPhotoUrl(currentUserId);

    ref
        .read(currentCallProvider.notifier)
        .initiateCall(
          calleeId: otherUserId,
          calleeName: otherUserName,
          calleePhotoUrl: otherUserPhoto,
          type: call.type,
        );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.clearHistory),
            content: Text(l10n.clearHistoryConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final calls = ref.read(callHistoryProvider).valueOrNull ?? [];
                  if (calls.isNotEmpty) {
                    final repository = ref.read(callRepositoryProvider);
                    var allSuccess = true;
                    for (final call in calls) {
                      final result = await repository.deleteCall(call.id);
                      if (result.isLeft()) {
                        allSuccess = false;
                      }
                    }
                    ref.invalidate(callHistoryProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            allSuccess
                                ? 'Historique effac├®'
                                : l10n.callDeleteError,
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  l10n.clear,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

class _CallHistoryItem extends StatelessWidget {
  final CallEntity call;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onCallBack;

  const _CallHistoryItem({
    required this.call,
    required this.currentUserId,
    required this.onTap,
    required this.onCallBack,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = call.isIncoming(currentUserId);
    final isMissed = call.status == CallStatus.missed;
    final isDeclined = call.status == CallStatus.declined;
    final isBusy = call.status == CallStatus.busy;
    final otherPartyName = call.getOtherPartyName(currentUserId);
    final otherPartyPhoto = call.getOtherPartyPhotoUrl(currentUserId);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.surfaceVariantColor,
            backgroundImage:
                otherPartyPhoto != null ? NetworkImage(otherPartyPhoto) : null,
            child:
                otherPartyPhoto == null
                    ? AppIcon(AppIcon.person, color: context.textTertiaryColor)
                    : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: AppIcon(call.type == CallType.video ? AppIcon.video : AppIcon.call,
                size: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        otherPartyName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color:
              (isMissed || isDeclined || isBusy)
                  ? AppColors.error
                  : context.textPrimaryColor,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            _getCallIcon(isIncoming, isMissed, isDeclined, isBusy),
            size: 16,
            color:
                (isMissed || isDeclined || isBusy)
                    ? AppColors.error
                    : context.textSecondaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            _getCallSubtitle(context, isIncoming, isMissed, isDeclined, isBusy),
            style: TextStyle(
              fontSize: 13,
              color:
                  (isMissed || isDeclined || isBusy)
                      ? AppColors.error
                      : context.textSecondaryColor,
            ),
          ),
          if (call.durationSeconds != null && call.durationSeconds! > 0) ...[
            Text(
              ' - ${call.formattedDuration}',
              style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(call.createdAt),
            style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCallBack,
            icon: AppIcon(call.type == CallType.video ? AppIcon.video : AppIcon.call,
              color: context.adaptivePrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCallIcon(
    bool isIncoming,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
  ) {
    if (isBusy) {
      return Icons.phone_disabled;
    }
    if (isMissed || isDeclined) {
      return isIncoming ? Icons.call_missed : Icons.call_missed_outgoing;
    }
    return isIncoming ? Icons.call_received : Icons.call_made;
  }

  String _getCallSubtitle(
    BuildContext context,
    bool isIncoming,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (isBusy) {
      return l10n.busyCall;
    }
    if (isMissed) {
      return l10n.missedCall;
    }
    if (isDeclined) {
      // For the caller, show "No answer" instead of "Declined"
      // For the receiver (who declined), show "Declined"
      return isIncoming ? l10n.declinedCall : l10n.noAnswer;
    }
    return isIncoming ? l10n.incomingCall : l10n.outgoingCall;
  }
}

/// Swipeable wrapper for call history items with delete functionality
class _SwipeableCallHistoryItem extends StatelessWidget {
  final CallEntity call;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onCallBack;
  final VoidCallback onDelete;

  const _SwipeableCallHistoryItem({
    super.key,
    required this.call,
    required this.currentUserId,
    required this.onTap,
    required this.onCallBack,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey('dismissible_${call.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        return await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(l10n.deleteCall),
                    content: Text(l10n.deleteCallConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          l10n.delete,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppIcon(AppIcon.delete, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      child: _CallHistoryItem(
        call: call,
        currentUserId: currentUserId,
        onTap: onTap,
        onCallBack: onCallBack,
      ),
    );
  }
}
