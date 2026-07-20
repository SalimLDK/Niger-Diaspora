import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/tip_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget that displays animated tips floating up
class TipAnimationWidget extends StatefulWidget {
  final List<TipEntity> tips;
  final String currency;

  const TipAnimationWidget({
    super.key,
    required this.tips,
    this.currency = 'XOF',
  });

  @override
  State<TipAnimationWidget> createState() => _TipAnimationWidgetState();
}

class _TipAnimationWidgetState extends State<TipAnimationWidget> {
  final List<_AnimatedTip> _animatedTips = [];
  final List<Timer> _timers = [];
  final _random = Random();
  String? _lastTipId;

  @override
  void didUpdateWidget(TipAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check for new tips
    if (widget.tips.isNotEmpty) {
      final latestTip = widget.tips.first;
      if (_lastTipId != latestTip.id) {
        _lastTipId = latestTip.id;
        _addNewTip(latestTip);
      }
    }
  }

  @override
  void dispose() {
    // Annuler tous les timers pour eviter les fuites memoire
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _addNewTip(TipEntity tip) {
    final animatedTip = _AnimatedTip(
      tip: tip,
      startX: _random.nextDouble() * 0.6 + 0.2, // 20% to 80%
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    setState(() {
      _animatedTips.add(animatedTip);
    });

    // Remove after animation completes - stocker le timer pour pouvoir l'annuler
    final timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _animatedTips.removeWhere((t) => t.id == animatedTip.id);
        });
      }
    });
    _timers.add(timer);
  }

  String _formatAmount(int amountInCents) {
    return '${(amountInCents / 100).toStringAsFixed(0)} ${widget.currency}';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _animatedTips.map((animatedTip) {
          return _FloatingTip(
            key: ValueKey(animatedTip.id),
            tip: animatedTip.tip,
            startX: animatedTip.startX,
            formattedAmount: _formatAmount(animatedTip.tip.amount),
          );
        }).toList(),
      ),
    );
  }
}

class _AnimatedTip {
  final TipEntity tip;
  final double startX;
  final String id;

  _AnimatedTip({
    required this.tip,
    required this.startX,
    required this.id,
  });
}

class _FloatingTip extends StatefulWidget {
  final TipEntity tip;
  final double startX;
  final String formattedAmount;

  const _FloatingTip({
    super.key,
    required this.tip,
    required this.startX,
    required this.formattedAmount,
  });

  @override
  State<_FloatingTip> createState() => _FloatingTipState();
}

class _FloatingTipState extends State<_FloatingTip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _positionAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 70,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width * widget.startX - 75,
          bottom: MediaQuery.of(context).size.height * 0.15 +
              (1 - _positionAnimation.value) * MediaQuery.of(context).size.height * 0.5,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: _buildTipBubble(),
    );
  }

  Widget _buildTipBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const AppIcon(AppIcon.heart,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.formattedAmount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'de ${widget.tip.senderName}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget to display a single tip notification banner
class TipNotificationBanner extends StatelessWidget {
  final TipEntity tip;
  final String currency;
  final VoidCallback? onDismiss;

  const TipNotificationBanner({
    super.key,
    required this.tip,
    this.currency = 'XOF',
    this.onDismiss,
  });

  String _formatAmount(int amountInCents) {
    return '${(amountInCents / 100).toStringAsFixed(0)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const AppIcon(AppIcon.heart,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    children: [
                      TextSpan(
                        text: tip.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' a envoyé '),
                      TextSpan(
                        text: _formatAmount(tip.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' à '),
                      TextSpan(
                        text: tip.recipientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (tip.message != null && tip.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${tip.message}"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: AppIcon(AppIcon.close,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
