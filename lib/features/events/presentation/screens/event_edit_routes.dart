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

/// Refus opposé à qui n'est pas l'organisateur.
///
/// La sortie mène à la fiche de l'événement, pas à la liste : c'est là que le
/// récapitulatif est **consultable** (description et grille de photos, cf.
/// `event_detail_screen.dart`). Un non-organisateur n'y perd donc rien de ce
/// qu'il pouvait voir ; il perd seulement le droit d'écrire.
Widget _reserveALOrganisateur(
  BuildContext context,
  AppLocalizations l10n,
  String eventId,
  String titre,
  String message,
) {
  return Scaffold(
    body: DesignUnavailableBody(
      icon: AppIcon(AppIcon.lock, size: 32, color: context.textSecondaryColor),
      title: titre,
      message: message,
      exitLabel: l10n.backToEvent,
      fallbackRoute: '/events/$eventId',
    ),
  );
}

/// `/events/:eventId/edit`.
///
/// ⚠️ Cette route porte **la seule** vérification d'autorisation du parcours :
/// `EditEventScreen` n'en fait aucune, elle faisait confiance à son appelant.
/// Le bouton « modifier » de la fiche est masqué derrière `isOrganizer`
/// (event_detail_screen.dart), mais un lien profond court-circuite la fiche.
/// Sans la garde, résoudre l'identifiant ouvrirait le formulaire d'édition de
/// l'événement de n'importe qui — le plantage, lui, fermait au moins la porte.
class EventEditRoute extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;

  const EventEditRoute({super.key, required this.eventId, this.initialEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _EventResolver(
      eventId: eventId,
      initialEvent: initialEvent,
      // La garde s'applique à l'entité d'où qu'elle vienne, `extra` compris :
      // sinon un appelant interne mal gardé la contournerait.
      builder:
          (event, moi) =>
              (moi == null || event.organizerId != moi)
                  ? _reserveALOrganisateur(
                    context,
                    l10n,
                    eventId,
                    l10n.eventEditNotAllowedTitle,
                    l10n.eventEditNotAllowedMessage,
                  )
                  : EditEventScreen(event: event),
    );
  }
}

/// `/events/:eventId/recap`.
///
/// Même garde que l'édition, et pour la même raison : `EventRecapScreen` est
/// un **formulaire** — titre « Créer / Modifier le récap », description,
/// jusqu'à dix photos, bouton d'enregistrement — sans aucune vérification à
/// lui. Il n'a pas de mode lecture : la consultation du récapitulatif se fait
/// sur la fiche de l'événement.
///
/// Cette garde **change un comportement existant**, et c'est assumé : la carte
/// « rien de prévu » de l'accueil ouvrait ce formulaire à tout le monde dès
/// qu'un événement passé avait des photos, si bien que n'importe qui pouvait
/// réécrire le récapitulatif de l'événement d'autrui. La carte, corrigée au
/// même endroit (`home_screen_widgets.dart`), n'y envoie plus que
/// l'organisateur ; les autres vont à la fiche, où les photos sont visibles.
class EventRecapRoute extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;

  const EventRecapRoute({super.key, required this.eventId, this.initialEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _EventResolver(
      eventId: eventId,
      initialEvent: initialEvent,
      builder:
          (event, moi) =>
              (moi == null || event.organizerId != moi)
                  ? _reserveALOrganisateur(
                    context,
                    l10n,
                    eventId,
                    l10n.eventRecapNotAllowedTitle,
                    l10n.eventRecapNotAllowedMessage,
                  )
                  : EventRecapScreen(event: event),
    );
  }
}

/// Résolution de l'événement **et** de l'identité du lecteur, avec les états
/// sans contenu qui vont avec.
///
/// Les deux sont résolus ici, ensemble, pour une raison précise : tant qu'on
/// ignore qui regarde, on ne peut rien décider. Voir [`build`].
class _EventResolver extends ConsumerWidget {
  final String eventId;
  final EventEntity? initialEvent;

  /// Reçoit l'événement et l'identifiant du lecteur, déjà résolus. `moi` vaut
  /// `null` seulement pour une session réellement absente — jamais pour une
  /// session en cours de chargement.
  final Widget Function(EventEntity event, String? moi) builder;

  const _EventResolver({
    required this.eventId,
    required this.initialEvent,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // ⚠️ « Pas encore chargé » n'est pas « pas autorisé ».
    //
    // `.valueOrNull` rend `null` dans les deux cas, et les confondre fait
    // afficher « réservé à l'organisateur » **à l'organisateur** : la garde
    // tranche avant que la session n'ait émis. Vu sur SM A515F le 2026-09-08,
    // sur un lien qui ouvrait le formulaire une minute plus tôt — donc
    // intermittent, et sans rien à réessayer une fois le refus affiché.
    //
    // On teste l'absence de valeur ET d'erreur plutôt que `isLoading` : ce
    // dernier est aussi vrai pendant un rafraîchissement, ce qui ferait
    // clignoter un écran déjà rendu. Une session en erreur, elle, tranche —
    // on la traite comme absente.
    final utilisateur = ref.watch(currentUserProvider);
    if (!utilisateur.hasValue && !utilisateur.hasError) {
      return _chargement();
    }
    final moi = utilisateur.valueOrNull?.id;

    final initial = initialEvent;
    if (initial != null) return builder(initial, moi);

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
            if (event != null) return builder(event, moi);
            return _unavailable(context, l10n, ref);
          },
          loading: _chargement,
          error: (_, __) => _unavailable(context, l10n, ref),
        );
  }

  /// Attente — de l'événement ou de l'identité. Avec sa sortie : par lien
  /// profond il n'y a rien à dépiler derrière.
  Widget _chargement() => const Scaffold(
    body: DesignExitOnlyBody(
      fallbackRoute: '/events',
      child: Center(child: CircularProgressIndicator()),
    ),
  );

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
