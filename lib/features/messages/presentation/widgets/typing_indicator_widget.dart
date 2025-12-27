import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/typing_indicator_provider.dart';

/// Animated typing indicator widget that shows when other users are typing
class TypingIndicatorWidget extends ConsumerWidget {
  final String conversationId;
  final String? currentUserId;
  final Map<String, String>? userNames; // userId -> displayName

  const TypingIndicatorWidget({
    super.key,
    required this.conversationId,
    this.currentUserId,
    this.userNames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingStatusAsync = ref.watch(typingStatusProvider(conversationId));

    return typingStatusAsync.when(
      data: (typingUsers) {
        // Filter out current user
        final othersTyping =
            typingUsers.entries
                .where((e) => e.key != currentUserId && e.value)
                .map((e) => e.key)
                .toList();

        if (othersTyping.isEmpty) {
          return const SizedBox.shrink();
        }

        return _TypingIndicatorContent(
          typingUserIds: othersTyping,
          userNames: userNames,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TypingIndicatorContent extends StatefulWidget {
  final List<String> typingUserIds;
  final Map<String, String>? userNames;

  const _TypingIndicatorContent({required this.typingUserIds, this.userNames});

  @override
  State<_TypingIndicatorContent> createState() =>
      _TypingIndicatorContentState();
}

class _TypingIndicatorContentState extends State<_TypingIndicatorContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTypingText() {
    final count = widget.typingUserIds.length;

    if (count == 0) return '';

    if (widget.userNames != null && widget.userNames!.isNotEmpty) {
      final names =
          widget.typingUserIds
              .map((id) => widget.userNames![id] ?? 'Quelqu\'un')
              .take(2)
              .toList();

      if (count == 1) {
        return '${names[0]} écrit...';
      } else if (count == 2) {
        return '${names[0]} et ${names[1]} écrivent...';
      } else {
        return '${names[0]} et ${count - 1} autres écrivent...';
      }
    }

    // Fallback without names
    if (count == 1) {
      return 'Quelqu\'un écrit...';
    } else {
      return '$count personnes écrivent...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedDots(),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _getTypingText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated dots (like iMessage/WhatsApp typing indicator)
class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations =
        _controllers.map((controller) {
          return Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          );
        }).toList();

    // Start animations with staggered delay
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * _animations[index].value),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(
                      alpha: 0.4 + (0.6 * _animations[index].value),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
