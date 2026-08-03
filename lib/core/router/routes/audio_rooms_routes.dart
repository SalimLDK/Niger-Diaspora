import 'package:go_router/go_router.dart';

import '../../../features/audio_rooms/domain/entities/room_replay_entity.dart';
import '../../../features/audio_rooms/presentation/screens/audio_room_screen.dart';
import '../../../features/audio_rooms/presentation/screens/audio_rooms_list_screen.dart';
import '../../../features/audio_rooms/presentation/screens/create_audio_room_screen.dart';
import '../../../features/audio_rooms/presentation/screens/creator_earnings_screen.dart';
import '../../../features/audio_rooms/presentation/screens/ghost_moderator_screen.dart';
import '../../../features/audio_rooms/presentation/screens/heritage_library_screen.dart';
import '../../../features/audio_rooms/presentation/screens/replay_player_screen.dart';
import '../../../features/audio_rooms/presentation/screens/save_as_podcast_screen.dart';
import '../../../features/audio_rooms/presentation/screens/schedule_room_screen.dart';

/// Routes des salons audio (style X Spaces / Clubhouse).
class AudioRoomsRoutes {
  AudioRoomsRoutes._();

  static List<RouteBase> get routes => [
        GoRoute(
          path: '/audio-rooms',
          builder: (context, state) => const AudioRoomsListScreen(),
        ),
        GoRoute(
          path: '/creator/earnings',
          builder: (context, state) => const CreatorEarningsScreen(),
        ),
        GoRoute(
          path: '/audio-rooms/create',
          builder: (context, state) => const CreateAudioRoomScreen(),
        ),
        // Bibliothèque du patrimoine : l'écran existait et fonctionnait, mais
        // aucune route n'y menait — il était inatteignable dans l'app.
        GoRoute(
          path: '/audio-rooms/heritage',
          builder: (context, state) => const HeritageLibraryScreen(),
        ),
        GoRoute(
          path: '/audio-rooms/schedule',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ScheduleRoomScreen(
              initialTitle: extra?['title'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/audio-rooms/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return AudioRoomScreen(
              roomId: roomId,
              roomTitle: extra?['title'] as String?,
            );
          },
          routes: [
            // Ghost moderator — admin only
            GoRoute(
              path: 'ghost',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                return GhostModeratorScreen(roomId: roomId);
              },
            ),
            // Save recorded session as podcast episode
            GoRoute(
              path: 'podcast',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final extra = state.extra as Map<String, dynamic>?;
                return SaveAsPodcastScreen(
                  roomId: roomId,
                  roomTitle: extra?['title'] as String?,
                  duration: extra?['duration'] as Duration?,
                );
              },
            ),
            // Replay player for recorded rooms
            GoRoute(
              path: 'replay',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final extra = state.extra as Map<String, dynamic>?;
                return ReplayPlayerScreen(
                  roomId: roomId,
                  replay: extra?['replay'] as RoomReplayEntity?,
                );
              },
            ),
          ],
        ),
      ];
}
