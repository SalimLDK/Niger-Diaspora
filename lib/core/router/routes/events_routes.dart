import 'package:go_router/go_router.dart';
import '../../../features/events/presentation/screens/events_screen.dart';
import '../../../features/events/presentation/screens/create_event_screen.dart';
import '../../../features/events/presentation/screens/event_detail_screen.dart';
import '../../../features/events/presentation/screens/edit_event_screen.dart';
import '../../../features/events/presentation/screens/event_recap_screen.dart';
import '../../../features/events/domain/entities/event_entity.dart';

/// Routes des événements
class EventsRoutes {
  EventsRoutes._();

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsScreen(),
    ),
    GoRoute(
      path: '/events/create',
      builder: (context, state) => const CreateEventScreen(),
    ),
    GoRoute(
      path: '/events/:eventId',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final event = state.extra as EventEntity?;
        return EventDetailScreen(eventId: eventId, initialEvent: event);
      },
    ),
    GoRoute(
      path: '/events/:eventId/edit',
      builder: (context, state) {
        final event = state.extra as EventEntity;
        return EditEventScreen(event: event);
      },
    ),
    GoRoute(
      path: '/events/:eventId/recap',
      builder: (context, state) {
        final event = state.extra as EventEntity;
        return EventRecapScreen(event: event);
      },
    ),
  ];
}
