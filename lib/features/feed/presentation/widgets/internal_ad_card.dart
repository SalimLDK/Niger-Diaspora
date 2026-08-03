import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/services/feature_flag_service.dart';
import '../../../../shared/widgets/app_icon.dart';

typedef _AdStringGetter = String Function(AppLocalizations);

class _InternalAd {
  const _InternalAd({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.icon,
    required this.color,
    required this.feature,
    required this.route,
  });

  final _AdStringGetter title;
  final _AdStringGetter subtitle;
  final _AdStringGetter ctaLabel;
  final Widget icon;
  final Color color;
  final AppFeature? feature;

  /// Destination du bouton d'appel à l'action. Sans elle le bouton était un
  /// `onPressed: () {}` : l'encart vantait une fonctionnalité sans y mener.
  final String route;
}

final _kAds = [
  _InternalAd(
    title: (l10n) => l10n.adTransferTitle,
    subtitle: (l10n) => l10n.adTransferSubtitle,
    ctaLabel: (l10n) => l10n.adTransferCta,
    icon: const AppIcon(AppIcon.send, color: Color(0xFF1A7A4A), size: 24),
    color: const Color(0xFF1A7A4A),
    feature: AppFeature.moneyTransfer,
    route: '/transfers',
  ),
  _InternalAd(
    title: (l10n) => l10n.adGroupTitle,
    subtitle: (l10n) => l10n.adGroupSubtitle,
    ctaLabel: (l10n) => l10n.adGroupCta,
    icon: const AppIcon(AppIcon.groups, color: Color(0xFF1565C0), size: 24),
    color: const Color(0xFF1565C0),
    feature: null,
    route: '/groups',
  ),
  _InternalAd(
    title: (l10n) => l10n.adMarketplaceTitle,
    subtitle: (l10n) => l10n.adMarketplaceSubtitle,
    ctaLabel: (l10n) => l10n.adMarketplaceCta,
    icon: const Icon(Icons.storefront_rounded, color: Color(0xFFE65100), size: 24),
    color: const Color(0xFFE65100),
    feature: AppFeature.marketplace,
    route: '/marketplace',
  ),
  _InternalAd(
    title: (l10n) => l10n.adAudioRoomsTitle,
    subtitle: (l10n) => l10n.adAudioRoomsSubtitle,
    ctaLabel: (l10n) => l10n.adAudioRoomsCta,
    icon: const AppIcon(AppIcon.mic, color: Color(0xFF6A1B9A), size: 24),
    color: const Color(0xFF6A1B9A),
    feature: AppFeature.audioRooms,
    route: '/audio-rooms',
  ),
];

class InternalAdCard extends ConsumerWidget {
  const InternalAdCard({required this.adIndex, super.key});

  final int adIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneyTransferEnabled = ref.watch(isMoneyTransferEnabledProvider);
    final marketplaceEnabled = ref.watch(isMarketplaceEnabledProvider);
    final audioRoomsEnabled = ref.watch(isAudioRoomsEnabledProvider);

    bool isAdEnabled(_InternalAd ad) {
      return switch (ad.feature) {
        null => true,
        AppFeature.moneyTransfer => moneyTransferEnabled,
        AppFeature.marketplace => marketplaceEnabled,
        AppFeature.audioRooms => audioRoomsEnabled,
        _ => true,
      };
    }

    final availableAds = _kAds.where(isAdEnabled).toList();
    if (availableAds.isEmpty) {
      return const SizedBox.shrink();
    }
    final ad = availableAds[adIndex % availableAds.length];
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Sponsorisé" badge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  'Sponsorisé',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ad.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ad.icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.title(l10n),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ad.subtitle(l10n),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => context.push(ad.route),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    ad.ctaLabel(l10n),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
