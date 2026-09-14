import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/messages/presentation/providers/message_provider.dart';
import '../../features/messages/presentation/screens/share_to_conversation_screen.dart';
import '../../features/podcasts/presentation/providers/podcast_player_provider.dart';
import '../../features/podcasts/presentation/widgets/podcast_mini_player.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/bottom_navigation.dart';
import '../../shared/widgets/tablet_navigation_rail.dart';
import '../services/app_review_service.dart';
import '../services/e2ee/e2ee_backup_coordinator.dart';
import '../services/mise_a_jour_service.dart';
import '../services/shared_media_service.dart';
import '../utils/toast_utils.dart';

/// Même seuil que `feed_screen.dart` (tour 4b) : au-delà, le fil affiche déjà
/// sa colonne droite tablette — le rail de navigation gauche doit apparaître
/// au même point pour ne pas désynchroniser les deux layouts.
const double _kTabletBreakpoint = 700;

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Ce que le bandeau haut affiche actuellement, pour ne pas le reposer
  /// identique à chaque rebuild. `null` = aucun bandeau.
  ///
  /// Une seule variable pour les deux sources, et volontairement :
  /// `ScaffoldMessenger` n'affiche qu'un `MaterialBanner` à la fois et
  /// `clearMaterialBanners()` vide aussi la file d'attente — deux appelants
  /// indépendants se seraient effacés l'un l'autre selon l'ordre d'arrivée.
  Object? _bandeauAffiche;

  @override
  void initState() {
    super.initState();
    // Handle shares received while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSharedMedia();
      // Les coordinateurs peuvent avoir déjà décidé avant que ce shell soit
      // monté : ref.listen ne rejoue pas l'état courant, on le lit donc une
      // fois ici.
      _rafraichitBandeau();
      // La vérification de version, elle, n'a personne pour la déclencher :
      // elle n'est accrochée ni à la connexion ni à une navigation.
      unawaited(ref.read(coordinateurMiseAJourProvider.notifier).verifie());
    });
  }

  Future<void> _checkInitialSharedMedia() async {
    final service = ref.read(sharedMediaServiceProvider);
    final initial = await service.consumeInitialMedia();
    if (initial == null || initial.isEmpty) return;
    if (!mounted) return;
    await ShareToConversationScreen.show(
      context,
      mediaFiles: initial,
    );
    // Aussi quand la feuille est fermée sans rien envoyer : le contenu ne doit
    // pas rester en attente.
    service.resetInitialMedia();
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    if (!mounted || media.isEmpty) return;
    await ShareToConversationScreen.show(
      context,
      mediaFiles: media,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch total unread count for messages
    final unreadMessagesCount = ref.watch(totalUnreadCountProvider);

    // Listen for shares received while the app is already running.
    ref.listen(
      sharedMediaStreamProvider,
      (_, next) {
        next.whenData(_handleSharedMedia);
      },
    );

    // Les deux sources du bandeau haut passent par le même point d'entrée.
    ref.listen<E2EEBackupPrompt>(
      e2eeBackupCoordinatorProvider,
      (_, __) => _rafraichitBandeau(),
    );
    ref.listen<NoticeMiseAJour?>(
      coordinateurMiseAJourProvider,
      (_, __) => _rafraichitBandeau(),
    );

    final isWide = MediaQuery.of(context).size.width >= _kTabletBreakpoint;
    // Le mini-lecteur ne s'affiche que si un épisode est chargé : la réserve
    // basse doit suivre, sinon elle est fausse dans un sens ou dans l'autre.
    final hasMiniPlayer =
        ref.watch(podcastPlayerProvider.select((s) => s.hasEpisode));

    if (isWide) {
      // Tablette/desktop (tour 4b) : rail de navigation fixe 86px à gauche,
      // pas de barre flottante — la colonne centrale n'a pas besoin de la
      // réserve basse de 110px (rien ne flotte par-dessus le contenu ici).
      return Scaffold(
        body: Row(
          children: [
            TabletNavigationRail(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => _onTap(context, index),
              unreadMessagesCount: unreadMessagesCount,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: widget.navigationShell),
                  const PodcastMiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // extendBody: true keeps the glass/blur effect (nav bar floats over body).
    // MediaQuery.padding.bottom is inflated so every ListView/ScrollView that
    // reads it (default padding: null) automatically adds bottom clearance.
    // 74px = nav bar height, +16px = comfortable gap above the last list item.
    return Scaffold(
      extendBody: true,
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                // + la hauteur du mini-lecteur quand il est là, sinon il
                // masquerait le dernier élément de chaque liste (le corps
                // passe sous la barre, `extendBody: true`).
                bottom: mq.padding.bottom + 110 + (hasMiniPlayer ? 64 : 0),
              ),
            ),
            child: widget.navigationShell,
          );
        },
      ),
      // Le mini-lecteur était un widget orphelin : la classe existait, le
      // provider de lecture tournait, mais rien ne l'affichait — une lecture
      // lancée depuis un épisode devenait invisible dès qu'on quittait
      // l'écran. Il se place au-dessus de la barre de navigation et se
      // masque tout seul quand aucun épisode n'est chargé.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PodcastMiniPlayer(),
          CustomBottomNavigation(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => _onTap(context, index),
            unreadMessagesCount: unreadMessagesCount,
          ),
        ],
      ),
    );
  }

  /// Repose le bandeau haut d'après l'état des deux sources qui peuvent en
  /// réclamer un. Non bloquant dans les deux cas.
  ///
  /// La sécurité passe avant la mise à jour : des clés non sauvegardées font
  /// perdre des messages, une version en retard non. Si le rappel E2EE est
  /// traité alors qu'une notice de mise à jour attend, celle-ci prend sa place
  /// — l'état des deux est relu à chaque passage.
  void _rafraichitBandeau() {
    if (!mounted) return;

    final e2ee = ref.read(e2eeBackupCoordinatorProvider);
    final maj = ref.read(coordinateurMiseAJourProvider);
    final Object? demande = e2ee != E2EEBackupPrompt.none ? e2ee : maj;

    if (demande == _bandeauAffiche) return;
    _bandeauAffiche = demande;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    if (demande == null) return;

    final l10n = AppLocalizations.of(context)!;
    messenger.showMaterialBanner(
      demande is E2EEBackupPrompt
          ? _bandeauE2EE(messenger, l10n, demande)
          : _bandeauMiseAJour(messenger, l10n, demande as NoticeMiseAJour),
    );
  }

  /// Bandeau invitant à sauvegarder ou restaurer les clés E2EE.
  MaterialBanner _bandeauE2EE(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    E2EEBackupPrompt prompt,
  ) {
    final isRestore = prompt == E2EEBackupPrompt.needsRestore;

    return MaterialBanner(
      content: Text(
        isRestore ? l10n.e2eeRestoreNudgeMessage : l10n.e2eeBackupNudgeMessage,
      ),
      leading: const Icon(Icons.lock_outline),
      actions: [
        // Sortie définitive : « Pas maintenant » ne met en veille que 7 jours,
        // et `needsRestore` reste vrai tant que la restauration n'a pas eu
        // lieu — le bandeau revenait donc indéfiniment.
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            ref.read(e2eeBackupCoordinatorProvider.notifier).dismissForever();
          },
          child: Text(l10n.e2eeNudgeMuteAction),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            ref.read(e2eeBackupCoordinatorProvider.notifier).acknowledge();
          },
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            ref.read(e2eeBackupCoordinatorProvider.notifier).acknowledge();
            context.push('/settings/security/backup');
          },
          child: Text(
            isRestore ? l10n.e2eeRestoreNudgeAction : l10n.e2eeBackupNudgeAction,
          ),
        ),
      ],
    );
  }

  /// Bandeau « une nouvelle version est disponible ».
  ///
  /// Deux actions seulement, et aucune n'est définitive : « Pas maintenant »
  /// ne tait que cette version-là, et la version suivante reparlera.
  MaterialBanner _bandeauMiseAJour(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    NoticeMiseAJour notice,
  ) {
    return MaterialBanner(
      content: Text(l10n.updateAvailableMessage(notice.versionPubliee)),
      leading: const Icon(Icons.system_update_outlined),
      actions: [
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            ref.read(coordinateurMiseAJourProvider.notifier).ecarte();
          },
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            // `ouvre()` et non `ecarte()` : partir vers le store ne prouve pas
            // que la mise à jour a été installée.
            ref.read(coordinateurMiseAJourProvider.notifier).ouvre();
            // `ouvrirLaFicheSansAvis` et non `ouvrirLaFicheDuStore` : la
            // seconde marquerait un avis en cours de dépôt.
            unawaited(AppReviewService.instance.ouvrirLaFicheSansAvis());
          },
          child: Text(l10n.updateAvailableAction),
        ),
      ],
    );
  }

  void _onTap(BuildContext context, int index) {
    ToastUtils.hide();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
