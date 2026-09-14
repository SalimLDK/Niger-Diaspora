import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../theme/service_accents.dart';
import '../widgets/quick_action_card.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Collect available services
    final services = [
      // Le fil est toujours disponible (même règle que la grille de
      // l'accueil : pas de flag).
      _ServiceItem(
        icon: Icons.dynamic_feed_rounded,
        label: l10n.homeServiceFeed,
        color: ServiceAccents.feed.of(context),
        route: '/feed',
      ),
      // Transfert et Boutique masqués de la grille « Tous les services »
      // (2026-08-23) : code conservé pour réactivation. Les deux routes
      // restent joignables ailleurs (raccourcis de l'accueil, encarts du
      // fil), donc /transfers et /marketplace ne deviennent pas orphelines.
      // TODO(services): remettre ces deux entrées quand les modules seront
      // prêts à être exposés dans la grille.
      // if (ref.watch(isMoneyTransferEnabledProvider))
      //   _ServiceItem(
      //     icon: Icons.send_rounded,
      //     label: l10n.serviceTransfer,
      //     color: ServiceAccents.transfers.of(context),
      //     route: '/transfers',
      //   ),
      // if (ref.watch(isMarketplaceEnabledProvider))
      //   _ServiceItem(
      //     icon: Icons.storefront_rounded,
      //     label: l10n.serviceMarketplace,
      //     color: ServiceAccents.marketplace.of(context),
      //     route: '/marketplace',
      //   ),
      // Annuaire et ambassades : toujours présents, comme le Fil (décision
      // produit 2026-08-19 — plus de flag).
      _ServiceItem(
        icon: Icons.business_rounded,
        label: l10n.homeDirectory,
        color: ServiceAccents.directory.of(context),
        route: '/businesses',
      ),
      _ServiceItem(
        icon: Icons.account_balance,
        label: l10n.embassies,
        color: ServiceAccents.embassies.of(context),
        route: '/embassies',
      ),
      // Absents de la grille alors que les modules sont livrés : sans ces deux
      // entrées, /audio-rooms et /podcasts n'étaient joignables par aucun
      // chemin depuis l'app.
      // if (ref.watch(isAudioRoomsEnabledProvider))
      //   _ServiceItem(
      //     icon: Icons.podcasts_rounded,
      //     label: 'Salons audio',
      //     color: ServiceAccents.audioRooms.of(context),
      //     route: '/audio-rooms',
      //   ),
      // if (ref.watch(isPodcastsEnabledProvider))
      //   _ServiceItem(
      //     icon: Icons.mic_rounded,
      //     label: l10n.podcasts,
      //     color: ServiceAccents.podcasts.of(context),
      //     route: '/podcasts',
      //   ),
      // Événements et Amis manquaient : le module événements a un flag et une
      // route depuis longtemps mais aucune tuile, et /friends n'était joignable
      // que depuis le profil.
      if (ref.watch(isEventsEnabledProvider))
        _ServiceItem(
          icon: Icons.event_rounded,
          label: l10n.eventsTitle,
          color: ServiceAccents.events.of(context),
          route: '/events',
        ),
      _ServiceItem(
        icon: Icons.people_alt_rounded,
        label: l10n.friends,
        color: ServiceAccents.friends.of(context),
        route: '/friends',
      ),
    ];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: DesignTitle(l10n.allServices, size: 22),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/home'),
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
