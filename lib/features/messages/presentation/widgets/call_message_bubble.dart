import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/message_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget pour afficher un message d'appel dans une conversation (style WhatsApp)
class CallMessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String currentUserId;
  final VoidCallback? onCallBack;
  final VoidCallback? onDelete;
  final bool isAdmin;

  const CallMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.onCallBack,
    this.onDelete,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVideoCall = message.callType == 'video';
    final isMissed = message.callStatus == 'missed';
    final isDeclined = message.callStatus == 'declined';
    final isBusy = message.callStatus == 'busy';
    final isCancelled = message.callStatus == 'cancelled';
    final hasAnswered =
        message.callStatus == 'ended' &&
        message.callDuration != null &&
        message.callDuration! > 0;

    // Déterminer si c'est un appel entrant ou sortant
    // Utiliser callerId (l'appelant original) au lieu de senderId
    final isOutgoing = (message.callerId ?? message.senderId) == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onCallBack,
        onLongPress: () => _showContextMenu(context, l10n, isVideoCall),
        child: Container(
          margin: EdgeInsets.only(
            top: 8,
            bottom: 8,
            left: isMe ? 48 : 16,
            right: isMe ? 16 : 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isMe
                    ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                    : context.surfaceVariantColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 12),
            ),
            border: Border.all(
              color:
                  isMe
                      ? context.adaptivePrimaryColor.withValues(alpha: 0.3)
                      : context.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'appel
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(
                    context,
                    isMissed,
                    isDeclined,
                    isBusy,
                    isCancelled,
                  ),
                  shape: BoxShape.circle,
                ),
                child: _getCallIcon(
                  isVideoCall,
                  isOutgoing,
                  isMissed,
                  isDeclined,
                  isBusy,
                  isCancelled,
                  size: 20,
                  color: _getIconColor(isMissed, isDeclined, isBusy, isCancelled),
                ),
              ),
              const SizedBox(width: 12),
              // Détails de l'appel
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getCallTitle(
                      l10n,
                      isVideoCall,
                      isOutgoing,
                      isMissed,
                      isDeclined,
                      isBusy,
                      isCancelled,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDeclined
                          ? Colors.orange
                          : (isMissed || isBusy || isCancelled)
                              ? AppColors.error
                              : context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Durée ou statut
                      if (hasAnswered)
                        Text(
                          message.callDurationFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondaryColor,
                          ),
                        )
                      else
                        Text(
                          _getCallStatus(
                            l10n,
                            isOutgoing,
                            isMissed,
                            isDeclined,
                            isBusy,
                            isCancelled,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDeclined
                                ? Colors.orange.withValues(alpha: 0.8)
                                : (isMissed || isBusy || isCancelled)
                                    ? AppColors.error.withValues(alpha: 0.8)
                                    : context.textSecondaryColor,
                          ),
                        ),
                      Text(
                        ' - ',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                      // Un message d'appel retourne tôt dans
                      // MessageBubble.build() (`widget.message.isCall`), avant
                      // le Column qui pose _buildMetaRow sous la bulle : c'est
                      // la SEULE heure qu'un appel affiche, pas un doublon.
                      Text(
                        DateFormat.Hm().format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Callback icon
              if (onCallBack != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(isVideoCall ? AppIcon.video : AppIcon.call,
                    size: 18,
                    color: context.adaptivePrimaryColor,
                  ),
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
    bool isOutgoing,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
    bool isCancelled, {
    required double size,
    required Color color,
  }) {
    if (isBusy) {
      return Icon(Icons.phone_disabled, size: size, color: color);
    }
    if (isMissed || isCancelled) {
      return Icon(
        isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed,
        size: size,
        color: color,
      );
    }
    if (isDeclined) {
      return Icon(Icons.call_end, size: size, color: color);
    }
    if (isVideoCall) {
      return AppIcon(AppIcon.video, size: size, color: color);
    }
    return Icon(
      isOutgoing ? Icons.call_made : Icons.call_received,
      size: size,
      color: color,
    );
  }

  Color _getIconBackgroundColor(
    BuildContext context,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
    bool isCancelled,
  ) {
    if (isDeclined) {
      return Colors.orange.withValues(alpha: 0.1); // Orange pour refusé
    }
    if (isMissed || isBusy || isCancelled) {
      return AppColors.error.withValues(alpha: 0.1); // Rouge pour manqué
    }
    return AppColors.success.withValues(alpha: 0.1);
  }

  Color _getIconColor(bool isMissed, bool isDeclined, bool isBusy, bool isCancelled) {
    if (isDeclined) {
      return Colors.orange; // Orange pour refusé
    }
    if (isMissed || isBusy || isCancelled) {
      return AppColors.error; // Rouge pour manqué
    }
    return AppColors.success;
  }

  String _getCallTitle(
    AppLocalizations l10n,
    bool isVideoCall,
    bool isOutgoing,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
    bool isCancelled,
  ) {
    if (isBusy) {
      return l10n.busyCall;
    }
    if (isCancelled) {
      return l10n.outgoingCall;
    }
    if (isMissed) {
      // For the caller, "Missed call" is wrong — they didn't miss anything,
      // the callee never answered. Same distinction as the declined case below.
      return isOutgoing ? l10n.noAnswer : l10n.missedCall;
    }
    if (isDeclined) {
      // For the caller, show "No answer" instead of "Declined"
      return isOutgoing ? l10n.noAnswer : l10n.declinedCall;
    }
    if (isVideoCall) {
      return l10n.videoCall;
    }
    return isOutgoing ? l10n.outgoingCall : l10n.incomingCall;
  }

  String _getCallStatus(
    AppLocalizations l10n,
    bool isOutgoing,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
    bool isCancelled,
  ) {
    if (isBusy) {
      return l10n.busyCall;
    }
    if (isCancelled) {
      return l10n.outgoingCall;
    }
    if (isMissed) {
      return l10n.noAnswer;
    }
    if (isDeclined) {
      // For the caller, show "No answer" instead of "Declined"
      return isOutgoing ? l10n.noAnswer : l10n.declinedCall;
    }
    return l10n.callEnded;
  }

  /// Show long press context menu with call options
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
        // Call back option
        if (onCallBack != null)
          PopupMenuItem<String>(
            value: 'callback',
            child: Row(
              children: [
                AppIcon(isVideoCall ? AppIcon.video : AppIcon.call,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(isVideoCall ? l10n.videoCall : l10n.callAgain),
              ],
            ),
          ),
        // Call info option
        PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              AppIcon(AppIcon.info,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(l10n.info),
            ],
          ),
        ),
        // Delete option (only for sender or admin)
        if (isMe || isAdmin)
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
        case 'callback':
          onCallBack?.call();
          break;
        case 'info':
          _showCallInfoDialog(context, l10n, isVideoCall);
          break;
        case 'delete':
          onDelete?.call();
          break;
      }
    });
  }

  /// Show call info dialog
  void _showCallInfoDialog(
    BuildContext context,
    AppLocalizations l10n,
    bool isVideoCall,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isOutgoing = (message.callerId ?? message.senderId) == currentUserId;
    final hasAnswered =
        message.callStatus == 'ended' &&
        message.callDuration != null &&
        message.callDuration! > 0;

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
                Text(l10n.callHistory),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  l10n.callType,
                  isVideoCall ? l10n.videoCall : l10n.audioCall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  l10n.callDirection,
                  isOutgoing ? l10n.outgoingCall : l10n.incomingCall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Status',
                  _getCallStatus(
                    l10n,
                    isOutgoing,
                    message.callStatus == 'missed',
                    message.callStatus == 'declined',
                    message.callStatus == 'busy',
                    message.callStatus == 'cancelled',
                  ),
                ),
                if (hasAnswered) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(l10n.duration, message.callDurationFormatted),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  l10n.dateLabel,
                  DateFormat('dd/MM/yyyy HH:mm').format(message.createdAt),
                ),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
