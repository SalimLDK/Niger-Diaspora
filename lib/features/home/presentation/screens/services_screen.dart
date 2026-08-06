import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../widgets/quick_action_card.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Collect available services
    final services = [
      if (ref.watch(isMoneyTransferEnabledProvider))
        _ServiceItem(
          icon: Icons.send_rounded,
          label: l10n.serviceTransfer,
          color: AppColors.primary,
          route: '/transfers',
        ),
      if (ref.watch(isMarketplaceEnabledProvider))
        _ServiceItem(
          icon: Icons.storefront_rounded,
          label: l10n.serviceMarketplace,
          color: context.adaptiveSecondaryColor,
          route: '/marketplace',
        ),
      if (ref.watch(isBusinessDirectoryEnabledProvider))
        _ServiceItem(
          icon: Icons.business_rounded,
          label: l10n.homeDirectory,
          color: AppColors.primaryDark,
          route: '/businesses',
        ),
      if (ref.watch(isEmbassiesEnabledProvider))
        _ServiceItem(
          icon: Icons.account_balance,
          label: l10n.embassies,
          color: Colors.indigo,
          route: '/embassies',
        ),
      // Absents de la grille alors que les modules sont livrés : sans ces deux
      // entrées, /audio-rooms et /podcasts n'étaient joignables par aucun
      // chemin depuis l'app.
      if (ref.watch(isAudioRoomsEnabledProvider))
        _ServiceItem(
          icon: Icons.podcasts_rounded,
          label: 'Salons audio',
          color: context.adaptivePrimaryColor,
          route: '/audio-rooms',
        ),
      if (ref.watch(isPodcastsEnabledProvider))
        _ServiceItem(
          icon: Icons.mic_rounded,
          label: l10n.podcasts,
          color: context.adaptiveSecondaryColor,
          route: '/podcasts',
        ),
    ];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.allServices),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          onPressed: () => context.pop(),
        ),
        titleTextStyle: TextStyle(
          color: context.onSurfaceColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return QuickActionCard(
              icon: service.icon,
              label: service.label,
              color: service.color,
              onTap: () => context.push(service.route),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  _ServiceItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}
