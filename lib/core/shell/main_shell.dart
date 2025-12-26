import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/bottom_navigation.dart';

import '../utils/toast_utils.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/messages/presentation/providers/message_provider.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    ToastUtils.hide();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch total unread count for messages
    final unreadMessagesCount = ref.watch(totalUnreadCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        unreadMessagesCount: unreadMessagesCount,
      ),
    );
  }
}
