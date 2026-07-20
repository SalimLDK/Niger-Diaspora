import 'package:go_router/go_router.dart';

import '../../../features/podcasts/presentation/screens/podcasts_home_screen.dart';
import '../../../features/podcasts/presentation/screens/podcast_detail_screen.dart';
import '../../../features/podcasts/presentation/screens/episode_detail_screen.dart';
import '../../../features/podcasts/presentation/screens/create_podcast_screen.dart';
import '../../../features/podcasts/presentation/screens/live_podcast_screen.dart';
import '../../../features/podcasts/presentation/screens/my_podcasts_screen.dart';
import '../../../features/podcasts/presentation/screens/record_episode_screen.dart';

/// Routes for the podcasts feature
class PodcastsRoutes {
  static const String home = '/podcasts';
  static const String detail = '/podcasts/:podcastId';
  static const String episode = '/podcasts/episodes/:episodeId';
  static const String create = '/podcasts/create';
  static const String myPodcasts = '/podcasts/my';
  static const String recordEpisode = '/podcasts/:podcastId/record';
  static const String live = '/podcasts/:podcastId/live';

  static List<RouteBase> get routes => [
        GoRoute(
          path: home,
          name: 'podcasts',
          builder: (context, state) => const PodcastsHomeScreen(),
        ),
        GoRoute(
          path: create,
          builder: (context, state) => const CreatePodcastScreen(),
        ),
        GoRoute(
          path: myPodcasts,
          builder: (context, state) => const MyPodcastsScreen(),
        ),
        GoRoute(
          path: detail,
          builder: (context, state) {
            final podcastId = state.pathParameters['podcastId']!;
            return PodcastDetailScreen(podcastId: podcastId);
          },
          routes: [
            GoRoute(
              path: 'record',
              builder: (context, state) {
                final podcastId = state.pathParameters['podcastId']!;
                return RecordEpisodeScreen(podcastId: podcastId);
              },
            ),
            GoRoute(
              path: 'live',
              builder: (context, state) {
                final podcastId = state.pathParameters['podcastId']!;
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return LivePodcastScreen(
                  podcastId: podcastId,
                  hostName: extra['hostName'] as String? ?? '',
                  isHost: extra['isHost'] as bool? ?? false,
                  livekitRoomName: extra['livekitRoomName'] as String?,
                  episodeTitle: extra['episodeTitle'] as String?,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: episode,
          builder: (context, state) {
            final episodeId = state.pathParameters['episodeId']!;
            return EpisodeDetailScreen(episodeId: episodeId);
          },
        ),
      ];
}
