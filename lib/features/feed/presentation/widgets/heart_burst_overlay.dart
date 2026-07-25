import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_icon.dart';

/// Cœur animé joué lors d'un double-tap « like » sur le média d'un post
/// (sémantique Instagram). À placer dans un [Stack] au-dessus du média ;
/// l'overlay est en [IgnorePointer] pour ne pas bloquer les autres gestes.
///
/// Déclenche l'animation via la clé : `_heartKey.currentState?.play()`.
class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key});

  @override
  State<HeartBurst> createState() => HeartBurstState();
}

class HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
  ]).animate(_controller);

  bool _visible = false;

  /// Joue le burst une fois. Sans effet de bord sur l'état de like.
  void play() {
    setState(() => _visible = true);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: const AppIcon(
              AppIcon.heart,
              color: Colors.white,
              size: 96,
            ),
          ),
        ),
      ),
    );
  }
}
