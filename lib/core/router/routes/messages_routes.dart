import 'package:go_router/go_router.dart';
import '../../../features/messages/presentation/screens/new_conversation_screen.dart';
import '../../../features/messages/presentation/screens/conversation_screen.dart';
import '../../../features/messages/presentation/screens/media_gallery_screen.dart';

/// Routes de la messagerie
class MessagesRoutes {
  MessagesRoutes._();

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/messages/new',
      builder: (context, state) => const NewConversationScreen(),
    ),
    GoRoute(
      path: '/messages/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        final extra = state.extra as Map<String, dynamic>?;
        return ConversationScreen(
          conversationId: conversationId,
          conversationName: extra?['name'] as String?,
          conversationImageUrl: extra?['imageUrl'] as String?,
          isGroup: extra?['isGroup'] as bool? ?? false,
          otherUserId: extra?['otherUserId'] as String?,
          groupId: extra?['groupId'] as String?,
          isSelfNotes: extra?['isSelfNotes'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/messages/:conversationId/media',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        final extra = state.extra as Map<String, dynamic>?;
        return MediaGalleryScreen(
          conversationId: conversationId,
          title: extra?['title'] as String?,
        );
      },
    ),
  ];
}
