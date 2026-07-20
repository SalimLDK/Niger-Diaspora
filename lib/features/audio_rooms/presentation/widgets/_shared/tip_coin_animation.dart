import 'package:flutter/material.dart';

/// Floating 🪙 coin that rises and fades out — used in [SendTipBottomSheet]
/// and as a toast overlay when a tip is received.
class TipCoinAnimation extends StatefulWidget {
  final double x;
  final int delayMs;

  const TipCoinAnimation({required this.x, this.delayMs = 0, super.key});

  @override
  State<TipCoinAnimation> createState() => _TipCoinAnimationState();
}

class _TipCoinAnimationState extends State<TipCoinAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Positioned(
          left: widget.x,
          bottom: 80 + _ctrl.value * 200,
          child: Opacity(
            opacity: (1 - _ctrl.value).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: (_ctrl.value - 0.5) * 0.5,
              child: const Text('🪙', style: TextStyle(fontSize: 24)),
            ),
          ),
        ),
      );
}
