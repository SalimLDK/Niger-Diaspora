import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final count = widget.typingUserIds.length;

    if (count == 0) return '';

    if (widget.userNames != null && widget.userNames!.isNotEmpty) {
      final names =
          widget.typingUserIds
              .map((id) => widget.userNames![id] ?? l10n.typingSomeone)
              .take(2)
              .toList();

      if (count == 1) {
        return l10n.typingOneName(names[0]);
      } else if (count == 2) {
        return l10n.typingTwoNames(names[0], names[1]);
      } else {
        return l10n.typingManyNames(names[0], count - 1);
      }
    }

    if (count == 1) {
      return l10n.typingSomeone;
    } else {
      return l10n.typingManyPeople(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern glass bubble with animated dots
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.surfaceVariantColor.withValues(alpha: 0.9),
                        context.surfaceVariantColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedDots(),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _getTypingText(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator shown as a left-aligned message bubble inside the message list
class TypingBubble extends StatefulWidget {
  final List<String> typingUserIds;
  final Map<String, String>? userNames;

  const TypingBubble({
    super.key,
    required this.typingUserIds,
    this.userNames,
  });

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _firstTyperName() {
    if (widget.userNames == null || widget.typingUserIds.isEmpty) return null;
    return widget.userNames![widget.typingUserIds.first];
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstTyperName();

    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 64, bottom: 8, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _AnimatedDots(),
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
  late List<Animation<double>> _bounceAnimations;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
    });

    _bounceAnimations =
        _controllers.map((controller) {
          return Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
          );
        }).toList();

    _scaleAnimations =
        _controllers.map((controller) {
          return Tween<double>(begin: 1.0, end: 1.3).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
          );
        }).toList();

    // Start animations with staggered delay
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
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
    final dotColor = context.adaptivePrimaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -5 * _bounceAnimations[index].value),
                child: Transform.scale(
                  scale: _scaleAnimations[index].value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          dotColor.withValues(
                            alpha: 0.5 + (0.5 * _bounceAnimations[index].value),
                          ),
                          dotColor.withValues(
                            alpha: 0.3 + (0.5 * _bounceAnimations[index].value),
                          ),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(
                            alpha: 0.3 * _bounceAnimations[index].value,
                          ),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
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
