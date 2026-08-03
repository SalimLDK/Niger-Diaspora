import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Données d'une notification in-app
class InAppNotificationData {
  final String id;
  final String senderName;
  final String? senderPhotoUrl;
  final String messagePreview;
  final String conversationId;
  final String? conversationType;
  final String? conversationTitle;
  final String? conversationPhotoUrl;
  final bool isGroup;
  final DateTime timestamp;

  const InAppNotificationData({
    required this.id,
    required this.senderName,
    this.senderPhotoUrl,
    required this.messagePreview,
    required this.conversationId,
    this.conversationType,
    this.conversationTitle,
    this.conversationPhotoUrl,
    this.isGroup = false,
    required this.timestamp,
  });

  factory InAppNotificationData.fromFcmData(Map<String, dynamic> data) {
    return InAppNotificationData(
      id: data['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: data['senderName'] ?? 'Utilisateur',
      senderPhotoUrl: data['senderPhotoUrl'],
      messagePreview: data['body'] ?? 'Nouveau message',
      conversationId: data['conversationId'] ?? '',
      conversationType: data['conversationType'],
      conversationTitle: data['conversationTitle'],
      conversationPhotoUrl: data['conversationPhotoUrl'],
      isGroup: data['conversationType'] == 'group',
      timestamp: DateTime.now(),
    );
  }
}

/// Widget banner de notification in-app style WhatsApp/Messenger
/// Glisse depuis le haut, reste visible ~4 secondes, peut être swipé pour dismiss
class InAppNotificationBanner extends StatefulWidget {
  final InAppNotificationData notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration displayDuration;
  final bool playSound;
  final bool vibrate;

  const InAppNotificationBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
    this.playSound = true,
    this.vibrate = true,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Démarrer l'animation d'entrée
    _animationController.forward();

    // Feedback haptique léger
    if (widget.vibrate) {
      HapticFeedback.lightImpact();
    }

    // Timer pour auto-dismiss
    _startAutoDismissTimer();
  }

  void _startAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.displayDuration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();

    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _handleTap() {
    _autoDismissTimer?.cancel();
    widget.onTap();
    _dismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final displayName =
        notification.isGroup
            ? notification.conversationTitle ?? notification.senderName
            : notification.senderName;
    final displayPhoto =
        notification.isGroup
            ? notification.conversationPhotoUrl
            : notification.senderPhotoUrl;

    return SafeArea(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: ValueKey(notification.id),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: context.borderColor.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Avatar
                          _buildAvatar(displayPhoto, displayName),
                          const SizedBox(width: 12),

                          // Contenu
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Nom + badge groupe
                                Row(
                                  children: [
                                    if (notification.isGroup) ...[
                                      AppIcon(
                                        AppIcon.groups,
                                        size: 14,
                                        color: context.textSecondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: context.textPrimaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Indicateur de temps
                                    Text(
                                      'maintenant',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textTertiaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Aperçu du message
                                Row(
                                  children: [
                                    // En groupe, afficher le nom de l'expéditeur
                                    if (notification.isGroup) ...[
                                      Text(
                                        '${notification.senderName}: ',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        notification.messagePreview,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: context.textSecondaryColor,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Chevron
                          AppIcon(AppIcon.chevronRight,
                            size: 20,
                            color: context.textTertiaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            photoUrl == null || photoUrl.isEmpty
                ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child:
            photoUrl != null && photoUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildInitialsAvatar(name),
                  errorWidget: (_, __, ___) => _buildInitialsAvatar(name),
                )
                : _buildInitialsAvatar(name),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials =
        name.isNotEmpty
            ? name
                .split(' ')
                .take(2)
                .map((e) => e.isNotEmpty ? e[0] : '')
                .join()
                .toUpperCase()
            : '?';

    return Container(
      alignment: Alignment.center,
      color: AppColors.primary,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
