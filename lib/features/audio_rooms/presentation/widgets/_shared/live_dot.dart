import 'package:flutter/material.dart';

import '../../../../../core/theme/dn_colors.dart';

/// Pulsing dot shown next to LIVE indicator.
class LiveDot extends StatefulWidget {
  final double size;
  final Color color;

  const LiveDot({this.size = 6, this.color = DNColors.danger, super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
