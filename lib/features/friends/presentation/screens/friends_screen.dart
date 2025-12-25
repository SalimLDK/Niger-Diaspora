import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../providers/friend_provider.dart';
import '../widgets/friend_list_item.dart';
import '../widgets/friend_request_item.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsTitle),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.adaptivePrimaryColor,
          unselectedLabelColor: context.textSecondaryColor,
          indicatorColor: context.adaptivePrimaryColor,
          tabs: [
            Tab(text: l10n.friends),
            Tab(text: l10n.received),
            Tab(text: l10n.sent),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendsListTab(),
          _ReceivedRequestsTab(),
          _SentRequestsTab(),
        ],
      ),
    );
  }
}

class _FriendsListTab extends ConsumerWidget {
  const _FriendsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: context.textSecondaryColor,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text(
                  l10n.noFriends,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.spacing8),
                Text(
                  l10n.noFriendsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          itemCount: friends.length,
          separatorBuilder:
              (_, __) => const SizedBox(height: AppSpacing.spacing8),
          itemBuilder: (context, index) {
            return FriendListItem(friend: friends[index]);
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }
}

class _ReceivedRequestsTab extends ConsumerWidget {
  const _ReceivedRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(receivedFriendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: context.textSecondaryColor,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text(
                  l10n.noRequests,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.spacing8),
                Text(
                  l10n.receivedRequestsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          itemCount: requests.length,
          separatorBuilder:
              (_, __) => const SizedBox(height: AppSpacing.spacing8),
          itemBuilder: (context, index) {
            return FriendRequestItem(
              request: requests[index],
              isReceived: true,
            );
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }
}

class _SentRequestsTab extends ConsumerWidget {
  const _SentRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(sentFriendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  size: 64,
                  color: context.textSecondaryColor,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text(
                  l10n.noRequests,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.spacing8),
                Text(
                  l10n.sentRequestsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          itemCount: requests.length,
          separatorBuilder:
              (_, __) => const SizedBox(height: AppSpacing.spacing8),
          itemBuilder: (context, index) {
            return FriendRequestItem(
              request: requests[index],
              isReceived: false,
            );
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }
}
