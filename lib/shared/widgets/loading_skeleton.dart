import 'package:flutter/material.dart';

/// A reusable animated loading skeleton widget for consistent loading states.
/// Uses a simple fade animation instead of shimmer to avoid external dependencies.
///
/// Usage:
/// ```dart
/// LoadingSkeleton.card(height: 120)
/// LoadingSkeleton.text(width: 200)
/// LoadingSkeleton.circle(size: 48)
/// ```
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  /// Creates a rectangular skeleton
  factory LoadingSkeleton.rect({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return LoadingSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
    );
  }

  /// Creates a card-shaped skeleton
  factory LoadingSkeleton.card({double? width, double? height = 120}) {
    return LoadingSkeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// Creates a circular skeleton
  factory LoadingSkeleton.circle({required double size}) {
    return LoadingSkeleton(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  /// Creates a text line skeleton
  factory LoadingSkeleton.text({double? width, double height = 14}) {
    return LoadingSkeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

/// A pre-built loading skeleton for list items
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          LoadingSkeleton.circle(size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton.text(width: double.infinity),
                const SizedBox(height: 8),
                LoadingSkeleton.text(width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pre-built loading skeleton for cards
class CardSkeleton extends StatelessWidget {
  final double? height;

  const CardSkeleton({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LoadingSkeleton.card(height: height),
    );
  }
}
