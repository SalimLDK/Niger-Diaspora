import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/event_by_id_provider.dart';
import 'edit_event_screen.dart';
import 'event_recap_screen.dart';

/// Entrées des routes `/events/:eventId/edit` et `/events/:eventId/recap`.
///
/// Les deux écrans exigent un `EventEntity` complet, et les deux routes ne le
/// prenaient que dans `state.extra`, avec un transtypage vers un type **non
/// nullable** : `state.extra as EventEntity`. Par lien profond ou par
/// notification, `extra` est nul par construction — le transtypage levait
/// donc un `TypeError` avant même que l'écran ne se monte. Même famille que
/// `/embassies/:id`, en plus brutal : là c'était un `!`, ici c'est un cast.
///
/// L'identifiant est dans `pathParameters` depuis toujours ; il suffisait de
/// s'en servir.

/// `/events/:eventId/edit`.
///
/// ⚠️ Cette route porte **la seule** vérification d'autorisation du parcours :
/// `EditEventScreen` n'en fait aucune, elle faisait confiance à son appelant.
/// Le bouton « modifier » de la fiche est masqué derrière `isOrganizer`
/// (event_detail_screen.dart), mais un lien profond court-circuite la fiche.
/// Sans la garde ci-dessous, résoudre l'identifiant ouvrirait le formulaire
/// d'édition de l'événement de n'importe qui — le plantage, lui, fermait au
/// moins la porte.
class EventEditRoute extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;

  const EventEditRoute({super.key, required this.eventId, this.initialEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // L'identité est lue ici, pas dans la branche `data` : la garde doit
    // valoir aussi pour l'entité arrivée par `extra`, sinon un appelant
    // interne mal gardé la contournerait.
    final me = ref.watch(currentUserProvider).valueOrNull?.id;

    Widget guard(EventEntity event) {
      if (me == null || event.organizerId != me) {
        return Scaffold(
          body: DesignUnavailableBody(
            icon: AppIcon(
              AppIcon.lock,
              size: 32,
              color: context.textSecondaryColor,
            ),
            title: l10n.eventEditNotAllowedTitle,
            message: l10n.eventEditNotAllowedMessage,
            exitLabel: l10n.backToEvent,
            fallbackRoute: '/events/$eventId',
          ),
        );
      }
      return EditEventScreen(event: event);
    }

    return _EventResolver(
      eventId: eventId,
      initialEvent: initialEvent,
      builder: guard,
    );
  }
}

/// `/events/:eventId/recap`.
///
/// Pas de garde d'organisateur ajoutée ici, volontairement : l'accueil ouvre
/// déjà ce récapitulatif pour tout le monde dès qu'un événement passé a des
/// photos (home_screen_widgets.dart). En poser une changerait un comportement
/// existant, au-delà du défaut traité. Que l'écran soit un formulaire ouvert
/// à tous est une question distincte, consignée dans
/// TESTS_APPAREIL_A_FAIRE.md.
class EventRecapRoute extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;

  const EventRecapRoute({super.key, required this.eventId, this.initialEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EventResolver(
      eventId: eventId,
      initialEvent: initialEvent,
      builder: (event) => EventRecapScreen(event: event),
    );
  }
}

/// Résolution de l'événement, et les trois états sans contenu qui vont avec.
class _EventResolver extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;
  final Widget Function(EventEntity) builder;

  const _EventResolver({
    required this.eventId,
    required this.initialEvent,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = initialEvent;
    if (initial != null) return builder(initial);

    final l10n = AppLocalizations.of(context)!;
    return ref
        .watch(eventByIdProvider(eventId))
        .when(
          // Un seul état pour « absent » et « échec », parce que la couche
          // en dessous ne les distingue pas : `getEventById` rend un `Left`
          // aussi bien pour un document supprimé que pour une panne réseau,
          // et `eventByIdProvider` replie tout sur `null`. Trancher ici
          // reviendrait à lire le message d'erreur — et à affirmer
          // « supprimé » quand on n'en sait rien.
          data: (event) {
            if (event != null) return builder(event);
            return _unavailable(context, l10n, ref);
          },
          loading:
              () => const Scaffold(
                body: DesignExitOnlyBody(
                  fallbackRoute: '/events',
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          error: (_, __) => _unavailable(context, l10n, ref),
        );
  }

  Widget _unavailable(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    return Scaffold(
      body: DesignUnavailableBody(
        icon: AppIcon(
          AppIcon.refresh,
          size: 32,
          color: context.textSecondaryColor,
        ),
        title: l10n.eventLoadFailedTitle,
        message: l10n.eventLoadFailedMessage,
        exitLabel: l10n.backToEvents,
        fallbackRoute: '/events',
        retryLabel: l10n.retry,
        onRetry: () => ref.invalidate(eventByIdProvider(eventId)),
      ),
    );
  }
}
