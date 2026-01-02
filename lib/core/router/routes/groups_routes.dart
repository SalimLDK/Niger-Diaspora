import 'package:go_router/go_router.dart';
import '../../../features/groups/presentation/screens/create_group_screen.dart';
import '../../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../../features/groups/presentation/screens/edit_group_screen.dart';
import '../../../features/groups/presentation/screens/group_members_screen.dart';
import '../../../features/groups/domain/entities/group_entity.dart';
import '../../../features/search/presentation/screens/search_screen.dart';
import '../../../features/search/presentation/providers/search_provider.dart';

/// Routes des groupes
class GroupsRoutes {
  GroupsRoutes._();

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/groups/create',
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: '/groups/search',
      builder: (context, state) => const SearchScreen(
        initialFilter: SearchFilter.groups,
        restrictToFilter: true,
      ),
    ),
    GoRoute(
      path: '/groups/:groupId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final group = state.extra as GroupEntity?;
        return GroupDetailScreen(groupId: groupId, initialGroup: group);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/edit',
      builder: (context, state) {
        final group = state.extra as GroupEntity;
        return EditGroupScreen(group: group);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/members',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final group = state.extra as GroupEntity?;
        return GroupMembersScreen(groupId: groupId, group: group);
      },
    ),
  ];
}
