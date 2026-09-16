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
import 'ecran_mise_a_jour_requise.dart';
import '../services/version_minimale.dart';
import '../services/app_review_service.dart';
import '../services/mise_a_jour_service.dart';
import '../services/shared_media_service.dart';
import '../utils/toast_utils.dart';
import 'bandeaux_shell.dart';

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
  /// Une seule source depuis le retrait du rappel E2EE (voir
  /// `bandeaux_shell.dart`), mais la variable garde son rôle : sans elle, le
  /// bandeau était reposé à chaque rebuild — `clearMaterialBanners()` puis
  /// `showMaterialBanner()`, donc un clignotement.
  NoticeMiseAJour? _bandeauAffiche;

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
      // Le verrou de version, lui, décide s'il faut REFUSER de continuer. Il
      // est inerte tant que `VERSION_MINIMALE_APP` n'est pas servie, et
      // refuse de bloquer dans quatre cas (cf. `miseAJourObligatoire`).
      unawaited(ref.read(versionTropAncienneProvider.notifier).verifie());
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
    // Avant tout le reste : une version trop ancienne ne doit pas pouvoir
    // écrire. C'est ce qui rend le gel de `messages` tenable — un bandeau
    // qu'on ignore ne suffisait pas.
    if (ref.watch(versionTropAncienneProvider)) {
      return const EcranMiseAJourRequise();
    }

    // Watch total unread count for messages
    final unreadMessagesCount = ref.watch(totalUnreadCountProvider);

    // Listen for shares received while the app is already running.
    ref.listen(
      sharedMediaStreamProvider,
      (_, next) {
        next.whenData(_handleSharedMedia);
      },
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

  /// Repose le bandeau haut d'après la notice de mise à jour. Non bloquant.
  ///
  /// Le rappel E2EE passait ici aussi, et primait sur la mise à jour : deux
  /// sources pour un canal qui n'affiche qu'un `MaterialBanner` à la fois.
  /// Depuis son retrait (voir `bandeaux_shell.dart`), la notice est seule.
  void _rafraichitBandeau() {
    if (!mounted) return;

    final demande = ref.read(coordinateurMiseAJourProvider);

    if (demande == _bandeauAffiche) return;
    _bandeauAffiche = demande;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    if (demande == null) return;

    final l10n = AppLocalizations.of(context)!;
    messenger.showMaterialBanner(_bandeauMiseAJour(messenger, l10n, demande));
  }

  /// Câble le bandeau de mise à jour sur son notifier.
  MaterialBanner _bandeauMiseAJour(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    NoticeMiseAJour notice,
  ) {
    void ferme() => messenger.hideCurrentMaterialBanner();
    final coordinateur = ref.read(coordinateurMiseAJourProvider.notifier);

    return bandeauMiseAJour(
      l10n: l10n,
      notice: notice,
      surPasMaintenant: () {
        ferme();
        coordinateur.ecarte();
      },
      surMettreAJour: () {
        ferme();
        // `ouvre()` et non `ecarte()` : partir vers le store ne prouve pas que
        // la mise à jour a été installée.
        coordinateur.ouvre();
        // `ouvrirLaFicheSansAvis` et non `ouvrirLaFicheDuStore` : la seconde
        // marquerait un avis en cours de dépôt.
        unawaited(AppReviewService.instance.ouvrirLaFicheSansAvis());
      },
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
