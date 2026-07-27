import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/messages/presentation/providers/message_provider.dart';
import '../../features/messages/presentation/screens/share_to_conversation_screen.dart';
import '../../shared/widgets/bottom_navigation.dart';
import '../services/shared_media_service.dart';
import '../utils/toast_utils.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Handle shares received while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSharedMedia();
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
                bottom: mq.padding.bottom + 110,
              ),
            ),
            child: widget.navigationShell,
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        unreadMessagesCount: unreadMessagesCount,
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
