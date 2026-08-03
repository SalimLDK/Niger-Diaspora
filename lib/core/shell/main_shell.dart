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
import '../services/e2ee/e2ee_backup_coordinator.dart';
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
  /// Dernier prompt E2EE affiché, pour ne pas ré-afficher le même bandeau à
  /// chaque rebuild.
  E2EEBackupPrompt? _e2eePromptShown;

  @override
  void initState() {
    super.initState();
    // Handle shares received while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSharedMedia();
      // Le coordinateur peut avoir déjà décidé avant que ce shell soit monté :
      // ref.listen ne rejoue pas l'état courant, on le lit donc une fois ici.
      _handleE2EEPrompt(ref.read(e2eeBackupCoordinatorProvider));
    });
  }

  Future<void> _checkInitialSharedMedia() async {
    final service = ref.read(sharedMediaServiceProvider);
    final initial = service.consumeInitialMedia();
    if (initial != null && initial.isNotEmpty && mounted) {
      await ShareToConversationScreen.show(
        context,
        mediaFiles: initial,
      );
      service.resetInitialMedia();
    }
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

    // Bandeau de sauvegarde/restauration des clés E2EE.
    ref.listen<E2EEBackupPrompt>(
      e2eeBackupCoordinatorProvider,
      (_, next) => _handleE2EEPrompt(next),
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

  /// Affiche (ou masque) le bandeau invitant à sauvegarder ou restaurer les clés
  /// E2EE, selon la décision du coordinateur. Non bloquant.
  void _handleE2EEPrompt(E2EEBackupPrompt prompt) {
    if (!mounted) return;
    if (prompt == _e2eePromptShown) return;
    _e2eePromptShown = prompt;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    if (prompt == E2EEBackupPrompt.none) return;

    final l10n = AppLocalizations.of(context)!;
    final isRestore = prompt == E2EEBackupPrompt.needsRestore;

    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          isRestore ? l10n.e2eeRestoreNudgeMessage : l10n.e2eeBackupNudgeMessage,
        ),
        leading: const Icon(Icons.lock_outline),
        actions: [
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
      ),
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
