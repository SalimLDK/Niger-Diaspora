import 'package:equatable/equatable.dart';

/// Entity representing a user's subscription to a podcast
class PodcastSubscriptionEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Podcast ID
  final String podcastId;

  /// Podcast title (denormalized for display)
  final String podcastTitle;

  /// Podcast cover image URL (denormalized for display)
  final String? podcastCoverUrl;

  /// Subscriber user ID
  final String userId;

  /// When the subscription was created
  final DateTime subscribedAt;

  /// Whether notifications are enabled for new episodes
  final bool notificationsEnabled;



  const PodcastSubscriptionEntity({
    required this.id,
    required this.podcastId,
    required this.podcastTitle,
    this.podcastCoverUrl,
    required this.userId,
    required this.subscribedAt,
    this.notificationsEnabled = true,
  });

  /// Copy with new values
  PodcastSubscriptionEntity copyWith({
    String? id,
    String? podcastId,
    String? podcastTitle,
    String? podcastCoverUrl,
    String? userId,
    DateTime? subscribedAt,
    bool? notificationsEnabled,
  }) {
    return PodcastSubscriptionEntity(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      podcastCoverUrl: podcastCoverUrl ?? this.podcastCoverUrl,
      userId: userId ?? this.userId,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        podcastId,
        userId,
        subscribedAt,
        notificationsEnabled,
      ];
}
