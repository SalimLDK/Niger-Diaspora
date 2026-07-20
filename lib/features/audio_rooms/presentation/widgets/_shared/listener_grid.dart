import 'package:flutter/material.dart';

import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';

/// Compact 8-column grid for room listeners.
class ListenerGrid extends StatelessWidget {
  final List<String> names;
  final int totalCount;
  final double avatarSize;
  final int maxVisible;

  const ListenerGrid({
    required this.names,
    required this.totalCount,
    this.avatarSize = 26,
    this.maxVisible = 56,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxVisible).toList();
    final overflow = totalCount - visible.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visible.map((name) => _AvatarBubble(letter: name.isEmpty ? '?' : name[0], size: avatarSize)),
        if (overflow > 0)
          _OverflowPill(count: overflow, size: avatarSize),
      ],
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String letter;
  final double size;

  const _AvatarBubble({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dn.surfaceVariant,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: DNText.mono(size: size * 0.38, color: dn.onSurface2),
      ),
    );
  }
}

class _OverflowPill extends StatelessWidget {
  final int count;
  final double size;

  const _OverflowPill({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: dn.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text('+$count', style: DNText.mono(size: 7, color: dn.onSurface3)),
    );
  }
}
