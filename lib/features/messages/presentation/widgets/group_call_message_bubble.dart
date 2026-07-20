import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../group_calls/domain/entities/group_call_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget pour afficher un message d'appel de groupe dans une conversation
class GroupCallMessageBubble extends StatelessWidget {
  final GroupCallEntity groupCall;
  final bool isHost;
  final String currentUserId;
  final VoidCallback? onJoinCall;
  final VoidCallback? onCallBack;
  final VoidCallback? onDelete;
  final bool isAdmin;

  const GroupCallMessageBubble({
    super.key,
    required this.groupCall,
    required this.isHost,
    required this.currentUserId,
    this.onJoinCall,
    this.onCallBack,
    this.onDelete,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVideoCall = groupCall.type == GroupCallType.video;
    final isActive = groupCall.status == GroupCallStatus.active;
    final hasEnded = groupCall.status == GroupCallStatus.ended;
    final isWaiting = groupCall.status == GroupCallStatus.waiting;

    return Align(
      alignment: isHost ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: isActive ? onJoinCall : onCallBack,
        onLongPress: () => _showContextMenu(context, l10n, isVideoCall),
        child: Container(
          margin: EdgeInsets.only(
            top: 8,
            bottom: 8,
            left: isHost ? 48 : 16,
            right: isHost ? 16 : 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isHost
                    ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                    : context.surfaceVariantColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isHost ? 12 : 4),
              bottomRight: Radius.circular(isHost ? 4 : 12),
            ),
            border: Border.all(
              color:
                  isActive
                      ? AppColors.success.withValues(alpha: 0.5)
                      : (isHost
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.3)
                          : context.dividerColor),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Group call icon with status indicator
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getIconBackgroundColor(
                        context,
                        isActive,
                        hasEnded,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        _getCallIcon(
                          isVideoCall,
                          isActive,
                          size: 20,
                          color: _getIconColor(isActive, hasEnded),
                        ),
                        // Live indicator for active calls (animated pulsing dot)
                        if (isActive)
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: _PulsingDot(
                              size: 8,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Call details
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getCallTitle(
                            l10n,
                            isVideoCall,
                            isActive,
                            isWaiting,
                            hasEnded,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color:
                                isActive
                                    ? AppColors.success
                                    : context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Participants count
                            AppIcon(
                              AppIcon.groups,
                              size: 12,
                              color: context.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${groupCall.participantCount}/${groupCall.maxParticipants}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondaryColor,
                              ),
                            ),
                            // Duration or status
                            if (hasEnded &&
                                groupCall.durationSeconds != null) ...[
                              Text(
                                ' - ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                              Text(
                                groupCall.formattedDuration,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                            // Time
                            Text(
                              ' - ',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiaryColor,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(groupCall.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Join/Callback button
                  if (isActive || onCallBack != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? AppColors.success.withValues(alpha: 0.1)
                                : context.adaptivePrimaryColor.withValues(
                                  alpha: 0.1,
                                ),
                        shape: BoxShape.circle,
                      ),
                      child: isActive
                          ? const Icon(Icons.login, size: 18, color: AppColors.success)
                          : AppIcon(
                              isVideoCall ? AppIcon.video : AppIcon.call,
                              size: 18,
                              color: context.adaptivePrimaryColor,
                            ),
                    ),
                  ],
                ],
              ),
              // Host info for non-hosts
              if (!isHost) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcon.person,
                      size: 12,
                      color: context.textTertiaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.host}: ${groupCall.hostName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              // E2EE indicator
              if (groupCall.isE2EEEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcon.lock, size: 10, color: Colors.green.shade600),
                    const SizedBox(width: 3),
                    Text(
                      'E2EE',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCallIcon(
    bool isVideoCall,
    bool isActive, {
    required double size,
    required Color color,
  }) {
    if (isVideoCall) {
      return AppIcon(AppIcon.video, size: size, color: color);
    }
    return AppIcon(AppIcon.call, size: size, color: color);
  }

  Color _getIconBackgroundColor(
    BuildContext context,
    bool isActive,
    bool hasEnded,
  ) {
    if (isActive) {
      return AppColors.success.withValues(alpha: 0.15);
    }
    if (hasEnded) {
      return context.textTertiaryColor.withValues(alpha: 0.1);
    }
    return context.adaptivePrimaryColor.withValues(alpha: 0.1);
  }

  Color _getIconColor(bool isActive, bool hasEnded) {
    if (isActive) {
      return AppColors.success;
    }
    if (hasEnded) {
      return Colors.grey;
    }
    return AppColors.primary;
  }

  String _getCallTitle(
    AppLocalizations l10n,
    bool isVideoCall,
    bool isActive,
    bool isWaiting,
    bool hasEnded,
  ) {
    if (isActive) {
      return isVideoCall
          ? '${l10n.videoCall} (${l10n.live})'
          : '${l10n.audioCall} (${l10n.live})';
    }
    if (isWaiting) {
      return isVideoCall ? l10n.videoCall : l10n.audioCall;
    }
    return l10n.callEnded;
  }

  /// Show long press context menu
  void _showContextMenu(
    BuildContext context,
    AppLocalizations l10n,
    bool isVideoCall,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: [
        // Join option (for active calls)
        if (groupCall.isActive && onJoinCall != null)
          PopupMenuItem<String>(
            value: 'join',
            child: Row(
              children: [
                const Icon(Icons.login, size: 20, color: AppColors.success),
                const SizedBox(width: 12),
                Text(l10n.join),
              ],
            ),
          ),
        // Call back option (for ended calls)
        if (groupCall.hasEnded && onCallBack != null)
          PopupMenuItem<String>(
            value: 'callback',
            child: Row(
              children: [
                AppIcon(isVideoCall ? AppIcon.video : AppIcon.call,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(l10n.callAgain),
              ],
            ),
          ),
        // View participants info
        PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              AppIcon(
                AppIcon.groups,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text('${groupCall.participantCount} ${l10n.participantsTitle}'),
            ],
          ),
        ),
        // Delete option (only for host or admin)
        if (isHost || isAdmin)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const AppIcon(AppIcon.delete,
                  size: 20,
                  color: AppColors.error,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.delete,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      if (!context.mounted) return;
      switch (value) {
        case 'join':
          onJoinCall?.call();
          break;
        case 'callback':
          onCallBack?.call();
          break;
        case 'info':
          _showParticipantsInfo(context, l10n, isVideoCall);
          break;
        case 'delete':
          onDelete?.call();
          break;
      }
    });
  }

  /// Show participants info dialog
  void _showParticipantsInfo(
    BuildContext context,
    AppLocalizations l10n,
    bool isVideoCall,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                AppIcon(isVideoCall ? AppIcon.video : AppIcon.call,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.groupCall)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Type',
                  isVideoCall ? l10n.videoCall : l10n.audioCall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Host', groupCall.hostName),
                const SizedBox(height: 8),
                _buildInfoRow(
                  l10n.participantsTitle,
                  '${groupCall.participantCount}/${groupCall.maxParticipants}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Status', _getStatusText(l10n)),
                if (groupCall.hasEnded &&
                    groupCall.durationSeconds != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(l10n.duration, groupCall.formattedDuration),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  l10n.dateLabel,
                  DateFormat('dd/MM/yyyy HH:mm').format(groupCall.createdAt),
                ),
                if (groupCall.isE2EEEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AppIcon(AppIcon.lock, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        l10n.endToEndEncrypted,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.close),
              ),
            ],
          ),
    );
  }

  String _getStatusText(AppLocalizations l10n) {
    switch (groupCall.status) {
      case GroupCallStatus.active:
        return l10n.live;
      case GroupCallStatus.waiting:
        return l10n.waiting;
      case GroupCallStatus.ended:
        return l10n.callEnded;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Animated pulsing dot indicator for active calls
class _PulsingDot extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingDot({this.size = 8, this.color = AppColors.success});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder:
          (context, child) => Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: _animation.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4 * _animation.value),
                  blurRadius: 4 * _animation.value,
                  spreadRadius: 1 * _animation.value,
                ),
              ],
            ),
          ),
    );
  }
}
