import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/podcasts/data/datasources/podcast_remote_datasource.dart';
import 'package:diaspo_niger/features/podcasts/domain/entities/podcast_entity.dart';
import 'package:diaspo_niger/features/podcasts/presentation/providers/podcast_provider.dart';

/// Supprimer, publier/mettre en pause : le notifier posait `AsyncError` sur un
/// état que personne n'écoute, et rendait `void`. L'écran « Mes podcasts »
/// affichait « supprimé » / « publié » dans la foulée — avant même la fin de
/// l'appel, et sans regarder son résultat.
///
/// Ces méthodes rendent maintenant `true` si l'écriture a abouti. Le message
/// de succès est, lui, l'affaire de l'écran (`my_podcasts_screen.dart`).
class _FauxSource implements PodcastRemoteDataSource {
  bool echoue = false;
  final recues = <String>[];

  Future<void> _ecrire(String appel) async {
    recues.add(appel);
    if (echoue) throw StateError('refusé par le serveur');
  }

  @override
  Future<void> deletePodcast(String podcastId) =>
      _ecrire('deletePodcast:$podcastId');

  @override
  Future<void> updatePodcast(String podcastId, Map<String, dynamic> data) =>
      _ecrire('updatePodcast:$podcastId:${data['status']}');

  @override
  Future<void> deleteEpisode(String episodeId, String podcastId) =>
      _ecrire('deleteEpisode:$episodeId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer monter(_FauxSource source) {
    final c = ProviderContainer(
      overrides: [podcastDataSourceProvider.overrideWithValue(source)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('suppression acceptée : rend true et l\'état reste sain', () async {
    final source = _FauxSource();
    final c = monter(source);

    final ok = await c
        .read(podcastNotifierProvider.notifier)
        .deletePodcast('p1');

    expect(ok, isTrue);
    expect(source.recues, ['deletePodcast:p1']);
    expect(c.read(podcastNotifierProvider).hasError, isFalse);
  });

  test('suppression refusée : rend false — l\'écran n\'annonce pas « supprimé »',
      () async {
    final source = _FauxSource()..echoue = true;
    final c = monter(source);

    final ok = await c
        .read(podcastNotifierProvider.notifier)
        .deletePodcast('p1');

    expect(ok, isFalse);
  });

  test('publier ↔ pause : bascule le bon statut, et le refus remonte',
      () async {
    final source = _FauxSource();
    final c = monter(source);
    final notifier = c.read(podcastNotifierProvider.notifier);

    expect(await notifier.togglePodcastStatus('p1', PodcastStatus.published),
        isTrue);
    expect(await notifier.togglePodcastStatus('p1', PodcastStatus.paused),
        isTrue);
    expect(source.recues, [
      'updatePodcast:p1:paused',
      'updatePodcast:p1:published',
    ]);

    source.echoue = true;
    expect(await notifier.togglePodcastStatus('p1', PodcastStatus.published),
        isFalse);
  });

  test('suppression d\'un épisode : même contrat', () async {
    final source = _FauxSource();
    final c = monter(source);
    final notifier = c.read(podcastNotifierProvider.notifier);

    expect(await notifier.deleteEpisode('e1', 'p1'), isTrue);
    source.echoue = true;
    expect(await notifier.deleteEpisode('e1', 'p1'), isFalse);
  });
}
