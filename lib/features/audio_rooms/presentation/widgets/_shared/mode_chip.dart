import 'package:flutter/material.dart';

import '../../../../../core/theme/dn_colors.dart';
import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';

/// Room mode enum used by [ModeChip] and screen backgrounds.
enum RoomMode { normal, ceremony, radio, heritage }

/// Small pill chip showing the room mode (Normal / Cérémonie / Radio / Patrimoine).
class ModeChip extends StatelessWidget {
  final RoomMode mode;

  const ModeChip({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final (label, textColor, bgColor) = switch (mode) {
      RoomMode.normal   => ('Normal',     dn.onSurface3, dn.surface2),
      RoomMode.ceremony => ('Cérémonie',  DNColors.paper, DNColors.terra),
      RoomMode.radio    => ('Radio',      DNColors.paper, DNColors.teal),
      RoomMode.heritage => ('Patrimoine', DNColors.paper, DNColors.ochre),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label.toUpperCase(), style: DNText.mono(size: 9, color: textColor)),
    );
  }
}

/// Convert domain [AudioRoomMode] string to [RoomMode].
RoomMode roomModeFrom(String mode) => switch (mode) {
      'ceremony' => RoomMode.ceremony,
      'radio'    => RoomMode.radio,
      'heritage' => RoomMode.heritage,
      _          => RoomMode.normal,
    };

/// Background decoration per mode.
BoxDecoration backgroundForMode(RoomMode m, {bool isDark = false}) => switch (m) {
      RoomMode.ceremony => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1714), const Color(0xFF2D1A08)]
                : [DNColors.paper, const Color(0xFFF9E8C4)],
          ),
        ),
      RoomMode.heritage => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1714), const Color(0xFF2A1800)]
                : [DNColors.paper, const Color(0xFFF0DCB4)],
          ),
        ),
      RoomMode.radio  => const BoxDecoration(color: DNColors.ink),
      RoomMode.normal => BoxDecoration(
          color: isDark ? const Color(0xFF1A1714) : DNColors.paper,
        ),
    };
