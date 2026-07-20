import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/post_entity.dart';
import 'feed_personalization_provider.dart';

class FeedScorer {
  final Set<String> followingIds;
  final String? myCountry;
  final Map<String, int> hashtagWeights;

  const FeedScorer({
    required this.followingIds,
    required this.myCountry,
    required this.hashtagWeights,
  });

  double score(PostEntity post) {
    final hoursSince =
        DateTime.now().difference(post.createdAt).inMinutes / 60.0;

    final baseEngagement =
        post.likeCount * 2 + post.commentCount * 3 + post.shareCount * 4 + 1;

    // HN-style time decay: newer posts rank higher
    final recencyFactor = 1.0 / pow(hoursSince + 2, 1.2);

    final followBoost =
        followingIds.contains(post.authorId) ? 1.5 : 1.0;

    final countryBoost =
        (myCountry != null && myCountry!.isNotEmpty && post.authorCountry == myCountry)
            ? 1.3
            : 1.0;

    // Sum interaction weights for this post's hashtags, scaled and capped
    double hashtagBoost = 1.0;
    for (final tag in post.hashtags) {
      hashtagBoost += (hashtagWeights[tag] ?? 0) * 0.05;
    }
    hashtagBoost = hashtagBoost.clamp(1.0, 1.5);

    final mediaBoost = post.mediaUrls.isNotEmpty ? 1.2 : 1.0;

    return baseEngagement *
        recencyFactor *
        followBoost *
        countryBoost *
        hashtagBoost *
        mediaBoost;
  }

  List<PostEntity> sorted(List<PostEntity> posts) =>
      [...posts]..sort((a, b) => score(b).compareTo(score(a)));
}

final feedScorerProvider = FutureProvider<FeedScorer>((ref) async {
  final results = await Future.wait([
    ref.watch(followingIdsProvider.future),
    ref.watch(myCountryProvider.future),
    ref.watch(hashtagWeightsProvider.future),
  ]);

  return FeedScorer(
    followingIds: results[0] as Set<String>,
    myCountry: results[1] as String?,
    hashtagWeights: results[2] as Map<String, int>,
  );
});
