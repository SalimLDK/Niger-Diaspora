import 'package:equatable/equatable.dart';

/// Category for podcasts
enum PodcastCategory {
  /// News and current events
  news,

  /// Culture and traditions
  culture,

  /// Spirituality and religion
  spirituality,

  /// Business and entrepreneurship
  business,

  /// Entertainment
  entertainment,

  /// Education and learning
  education,

  /// Storytelling (Griot/Contes)
  storytelling,

  /// Sports
  sports,

  /// Politics
  politics,

  /// Technology
  technology,

  /// Health and wellness
  health,

  /// Other topics
  other,
}

/// Status of a podcast show
enum PodcastStatus {
  /// Draft, not yet published
  draft,

  /// Published and active
  published,

  /// Temporarily paused
  paused,

  /// Archived/Inactive
  archived,
}

/// Entity representing a podcast show
class PodcastEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Title of the podcast
  final String title;

  /// Description of the podcast
  final String? description;

  /// Cover image URL
  final String coverImageUrl;

  /// Host user ID
  final String hostId;

  /// Host display name
  final String hostName;

  /// Host photo URL
  final String? hostPhotoUrl;

  /// List of co-host user IDs
  final List<String> coHostIds;

  /// Category of the podcast
  final PodcastCategory category;

  /// Primary language
  final String language;

  /// Tags for discoverability
  final List<String> tags;

  /// Whether the podcast contains explicit content
  final bool isExplicit;

  /// Current status
  final PodcastStatus status;

  /// Number of subscribers
  final int subscriberCount;

  /// Total play count across all episodes
  final int totalPlayCount;

  /// Total number of episodes
  final int totalEpisodes;

  /// Episode frequency (e.g., "weekly", "biweekly", "monthly")
  final String? episodeFrequency;

  /// When the podcast was created
  final DateTime createdAt;

  /// When the podcast was last updated
  final DateTime? updatedAt;

  /// When the last episode was published
  final DateTime? lastEpisodeAt;

  /// Whether premium subscription is required
  final bool isPremium;

  /// Premium subscription price in cents
  final int? premiumPrice;

  /// Currency for premium price
  final String? premiumCurrency;

  /// External RSS feed URL (for syndication)
  final String? rssFeedUrl;

  const PodcastEntity({
    required this.id,
    required this.title,
    this.description,
    required this.coverImageUrl,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    this.coHostIds = const [],
    required this.category,
    required this.language,
    this.tags = const [],
    this.isExplicit = false,
    this.status = PodcastStatus.draft,
    this.subscriberCount = 0,
    this.totalPlayCount = 0,
    this.totalEpisodes = 0,
    this.episodeFrequency,
    required this.createdAt,
    this.updatedAt,
    this.lastEpisodeAt,
    this.isPremium = false,
    this.premiumPrice,
    this.premiumCurrency,
    this.rssFeedUrl,
  });

  /// Check if a user is the host
  bool isHost(String userId) => hostId == userId;

  /// Check if a user is a co-host
  bool isCoHost(String userId) => coHostIds.contains(userId);

  /// Check if a user can manage this podcast
  bool canManage(String userId) => isHost(userId) || isCoHost(userId);

  /// Get category label in French
  String get categoryLabel => switch (category) {
        PodcastCategory.news => 'Actualités',
        PodcastCategory.culture => 'Culture',
        PodcastCategory.spirituality => 'Spiritualité',
        PodcastCategory.business => 'Business',
        PodcastCategory.entertainment => 'Divertissement',
        PodcastCategory.education => 'Éducation',
        PodcastCategory.storytelling => 'Contes/Griot',
        PodcastCategory.sports => 'Sports',
        PodcastCategory.politics => 'Politique',
        PodcastCategory.technology => 'Technologie',
        PodcastCategory.health => 'Santé',
        PodcastCategory.other => 'Autre',
      };

  /// Get category label in English
  String get categoryLabelEn => switch (category) {
        PodcastCategory.news => 'News',
        PodcastCategory.culture => 'Culture',
        PodcastCategory.spirituality => 'Spirituality',
        PodcastCategory.business => 'Business',
        PodcastCategory.entertainment => 'Entertainment',
        PodcastCategory.education => 'Education',
        PodcastCategory.storytelling => 'Storytelling',
        PodcastCategory.sports => 'Sports',
        PodcastCategory.politics => 'Politics',
        PodcastCategory.technology => 'Technology',
        PodcastCategory.health => 'Health',
        PodcastCategory.other => 'Other',
      };

  /// Get status label in French
  String get statusLabel => switch (status) {
        PodcastStatus.draft => 'Brouillon',
        PodcastStatus.published => 'Publié',
        PodcastStatus.paused => 'En pause',
        PodcastStatus.archived => 'Archivé',
      };

  /// Copy with new values
  PodcastEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? coHostIds,
    PodcastCategory? category,
    String? language,
    List<String>? tags,
    bool? isExplicit,
    PodcastStatus? status,
    int? subscriberCount,
    int? totalPlayCount,
    int? totalEpisodes,
    String? episodeFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastEpisodeAt,
    bool? isPremium,
    int? premiumPrice,
    String? premiumCurrency,
    String? rssFeedUrl,
  }) {
    return PodcastEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      coHostIds: coHostIds ?? this.coHostIds,
      category: category ?? this.category,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      isExplicit: isExplicit ?? this.isExplicit,
      status: status ?? this.status,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      totalPlayCount: totalPlayCount ?? this.totalPlayCount,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      episodeFrequency: episodeFrequency ?? this.episodeFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastEpisodeAt: lastEpisodeAt ?? this.lastEpisodeAt,
      isPremium: isPremium ?? this.isPremium,
      premiumPrice: premiumPrice ?? this.premiumPrice,
      premiumCurrency: premiumCurrency ?? this.premiumCurrency,
      rssFeedUrl: rssFeedUrl ?? this.rssFeedUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        hostId,
        status,
        createdAt,
        subscriberCount,
        totalEpisodes,
      ];
}
