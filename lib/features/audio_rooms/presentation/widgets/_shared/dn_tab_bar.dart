import 'package:flutter/material.dart';

import '../../../../../core/theme/dn_colors.dart';
import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';

/// Sahel tab bar — simple underline style, no capsule, no shadow.
class DnTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const DnTabBar({
    required this.controller,
    required this.labels,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return TabBar(
      controller: controller,
      labelStyle: DNText.sans(size: 13, w: FontWeight.w600),
      unselectedLabelStyle: DNText.sans(size: 13),
      labelColor: DNColors.terra,
      unselectedLabelColor: dn.onSurface3,
      indicatorColor: DNColors.terra,
      indicatorWeight: 2,
      dividerColor: dn.surface2,
      tabs: labels.map((l) => Tab(text: l)).toList(),
    );
  }
}
