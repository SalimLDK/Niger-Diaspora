import 'package:flutter/material.dart';

import 'internal_ad_card.dart';
import 'native_ad_widget.dart';

/// Dispatche entre annonce interne (index pair) et annonce AdMob native (index impair).
/// Si AdMob échoue, [NativeAdWidget] se replie automatiquement sur [InternalAdCard].
class AdSlot extends StatelessWidget {
  const AdSlot({required this.adIndex, super.key});

  final int adIndex;

  @override
  Widget build(BuildContext context) {
    if (adIndex.isEven) {
      return InternalAdCard(adIndex: adIndex);
    }
    return NativeAdWidget(adIndex: adIndex);
  }
}
