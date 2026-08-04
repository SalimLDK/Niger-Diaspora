import 'package:equatable/equatable.dart';

import '../../domain/entities/podcast_entity.dart';

/// Model representing a podcast in Firebase
class PodcastModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String coverImageUrl;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final List<String> coHostIds;
  final String category;
  final String language;
  final List<String> tags;
  final bool isExplicit;
  final String status;
  final int subscriberCount;
  final int totalPlayCount;
  final int totalEpisodes;
  final String? episodeFrequency;
  final String createdAt;
  final String? updatedAt;
  final String? lastEpisodeAt;
  final bool isPremium;
  final int? premiumPrice;
  final String? premiumCurrency;
  final String? rssFeedUrl;

  const PodcastModel({
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
    this.status = 'draft',
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

  factory PodcastModel.fromJson(Map<String, dynamic> json) {
    return PodcastModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      hostName: json['hostName'] as String? ?? '',
      hostPhotoUrl: json['hostPhotoUrl'] as String?,
      coHostIds: List<String>.from(json['coHostIds'] ?? []),
      category: json['category'] as String? ?? 'other',
      language: json['language'] as String? ?? 'fr',
      tags: List<String>.from(json['tags'] ?? []),
      isExplicit: json['isExplicit'] as bool? ?? false,
      status: json['status'] as String? ?? 'draft',
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      totalPlayCount: json['totalPlayCount'] as int? ?? 0,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      episodeFrequency: json['episodeFrequency'] as String?,
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: _timestampToString(json['updatedAt']),
      lastEpisodeAt: _timestampToString(json['lastEpisodeAt']),
      isPremium: json['isPremium'] as bool? ?? false,
      premiumPrice: json['premiumPrice'] as int?,
      premiumCurrency: json['premiumCurrency'] as String?,
      rssFeedUrl: json['rssFeedUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'coHostIds': coHostIds,
      'category': category,
      'language': language,
      'tags': tags,
      'isExplicit': isExplicit,
      'status': status,
      'subscriberCount': subscriberCount,
      'totalPlayCount': totalPlayCount,
      'totalEpisodes': totalEpisodes,
      'episodeFrequency': episodeFrequency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastEpisodeAt': lastEpisodeAt,
      'isPremium': isPremium,
      'premiumPrice': premiumPrice,
      'premiumCurrency': premiumCurrency,
      'rssFeedUrl': rssFeedUrl,
    };
  }

  /// Create from Firestore document
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'coHostIds': coHostIds,
      'category': category,
      'language': language,
      'tags': tags,
      'isExplicit': isExplicit,
      'status': status,
      'subscriberCount': subscriberCount,
      'totalPlayCount': totalPlayCount,
      'totalEpisodes': totalEpisodes,
      'episodeFrequency': episodeFrequency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastEpisodeAt': lastEpisodeAt,
      'isPremium': isPremium,
      'premiumPrice': premiumPrice,
      'premiumCurrency': premiumCurrency,
      'rssFeedUrl': rssFeedUrl,
    };
  }

  /// Convert to entity
  PodcastEntity toEntity() {
    return PodcastEntity(
      id: id,
      title: title,
      description: description,
      coverImageUrl: coverImageUrl,
      hostId: hostId,
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      coHostIds: coHostIds,
      category: _parseCategory(category),
      language: language,
      tags: tags,
      isExplicit: isExplicit,
      status: _parseStatus(status),
      subscriberCount: subscriberCount,
      totalPlayCount: totalPlayCount,
      totalEpisodes: totalEpisodes,
      episodeFrequency: episodeFrequency,
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!).toLocal() : null,
      lastEpisodeAt: lastEpisodeAt != null ? DateTime.parse(lastEpisodeAt!).toLocal() : null,
      isPremium: isPremium,
      premiumPrice: premiumPrice,
      premiumCurrency: premiumCurrency,
      rssFeedUrl: rssFeedUrl,
    );
  }

  /// Create from entity
  factory PodcastModel.fromEntity(PodcastEntity entity) {
    return PodcastModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      coverImageUrl: entity.coverImageUrl,
      hostId: entity.hostId,
      hostName: entity.hostName,
      hostPhotoUrl: entity.hostPhotoUrl,
      coHostIds: entity.coHostIds,
      category: entity.category.name,
      language: entity.language,
      tags: entity.tags,
      isExplicit: entity.isExplicit,
      status: entity.status.name,
      subscriberCount: entity.subscriberCount,
      totalPlayCount: entity.totalPlayCount,
      totalEpisodes: entity.totalEpisodes,
      episodeFrequency: entity.episodeFrequency,
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt?.toUtc().toIso8601String(),
      lastEpisodeAt: entity.lastEpisodeAt?.toUtc().toIso8601String(),
      isPremium: entity.isPremium,
      premiumPrice: entity.premiumPrice,
      premiumCurrency: entity.premiumCurrency,
      rssFeedUrl: entity.rssFeedUrl,
    );
  }

  PodcastModel copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? coHostIds,
    String? category,
    String? language,
    List<String>? tags,
    bool? isExplicit,
    String? status,
    int? subscriberCount,
    int? totalPlayCount,
    int? totalEpisodes,
    String? episodeFrequency,
    String? createdAt,
    String? updatedAt,
    String? lastEpisodeAt,
    bool? isPremium,
    int? premiumPrice,
    String? premiumCurrency,
    String? rssFeedUrl,
  }) {
    return PodcastModel(
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

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  static PodcastCategory _parseCategory(String category) {
    return PodcastCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => PodcastCategory.other,
    );
  }

  static PodcastStatus _parseStatus(String status) {
    return PodcastStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => PodcastStatus.draft,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        hostId,
        category,
        status,
        subscriberCount,
        totalPlayCount,
        totalEpisodes,
        createdAt,
      ];
}
