import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/adaptive_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/online_status_provider.dart';

/// A widget that displays a user's online status and last seen information
///
/// Features:
/// - Green dot when user is online
/// - Gray dot when user is offline
/// - "En ligne" text when online
/// - "Vu il y a X" text when offline
/// - Respects the current user's showOnlineStatus privacy setting (reciprocity rule)
class OnlineStatusIndicator extends ConsumerWidget {
  final String userId;
  final bool showText;
  final double dotSize;
  final TextStyle? textStyle;

  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.showText = true,
    this.dotSize = 8.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First check if current user has showOnlineStatus enabled (reciprocity rule)
    final currentUserAsync = ref.watch(currentUserAsyncProvider);
    final currentUser = currentUserAsync.valueOrNull;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    // Check current user's privacy preference
    final visibilityAsync = ref.watch(
      currentUserOnlineStatusVisibilityProvider,
    );

    return visibilityAsync.when(
      data: (showOnlineStatus) {
        // If current user has disabled online status, don't show any indicators
        if (!showOnlineStatus) {
          return const SizedBox.shrink();
        }

        // Now show the target user's status
        return _OnlineStatusContent(
          userId: userId,
          showText: showText,
          dotSize: dotSize,
          textStyle: textStyle,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Internal widget that actually displays the status
class _OnlineStatusContent extends ConsumerWidget {
  final String userId;
  final bool showText;
  final double dotSize;
  final TextStyle? textStyle;

  const _OnlineStatusContent({
    required this.userId,
    required this.showText,
    required this.dotSize,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(userOnlineStatusProvider(userId));
    final lastSeenAsync = ref.watch(userLastSeenProvider(userId));

    return isOnlineAsync.when(
      data: (isOnline) {
        if (isOnline) {
          // User is online
          return _buildOnlineIndicator(context);
        } else {
          // User is offline, show last seen
          return lastSeenAsync.when(
            data: (lastSeen) => _buildOfflineIndicator(context, lastSeen),
            loading: () => _buildOfflineIndicator(context, null),
            error: (_, __) => _buildOfflineIndicator(context, null),
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOnlineIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: context.successColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.successColor.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            'En ligne',
            style:
                textStyle ??
                TextStyle(
                  fontSize: 12,
                  color: context.successColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildOfflineIndicator(BuildContext context, DateTime? lastSeen) {
    String lastSeenText = '';
    if (lastSeen != null) {
      // Configure French locale for timeago
      timeago.setLocaleMessages('fr', timeago.FrMessages());
      final ago = timeago.format(lastSeen, locale: 'fr');
      lastSeenText = 'Vu $ago';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: context.textTertiaryColor,
            shape: BoxShape.circle,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            lastSeenText.isNotEmpty ? lastSeenText : 'Hors ligne',
            style:
                textStyle ??
                TextStyle(fontSize: 12, color: context.textSecondaryColor),
          ),
        ],
      ],
    );
  }
}
