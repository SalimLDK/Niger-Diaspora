import 'package:go_router/go_router.dart';
import '../../../features/calls/presentation/screens/call_screen.dart';
import '../../../features/calls/presentation/screens/call_history_screen.dart';
import '../../../features/group_calls/presentation/screens/group_call_screen.dart';

/// Routes des appels audio/vidéo (1:1 et de groupe)
class CallsRoutes {
  CallsRoutes._();

  static List<RouteBase> get routes => [
        GoRoute(
          path: '/calls/history',
          builder: (context, state) => const CallHistoryScreen(),
        ),
        // 1:1 call route
        GoRoute(
          path: '/calls/:callId',
          builder: (context, state) {
            final callId = state.pathParameters['callId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return CallScreen(
              callId: callId,
              isInitiator: extra?['isInitiator'] as bool? ?? false,
              isVideo: extra?['isVideo'] as bool? ?? false,
              calleeName: extra?['calleeName'] as String?,
              calleePhotoUrl: extra?['calleePhotoUrl'] as String?,
              isCalleeOnline: extra?['isCalleeOnline'] as bool? ?? true,
            );
          },
        ),
        // Group call route (mesh 2-4 participants, SFU 5+)
        GoRoute(
          path: '/group-calls/:callId',
          builder: (context, state) {
            final callId = state.pathParameters['callId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return GroupCallScreen(
              callId: callId,
              isInitiator: extra?['isInitiator'] as bool? ?? false,
              isVideo: extra?['isVideo'] as bool? ?? false,
              initialParticipantIds:
                  (extra?['participantIds'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList(),
            );
          },
        ),
      ];
}
