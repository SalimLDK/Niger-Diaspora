import 'package:equatable/equatable.dart';

import '../../domain/entities/podcast_episode_entity.dart';

/// Model for a chapter within an episode
class ChapterModel extends Equatable {
  final String title;
  final int startSeconds;

  const ChapterModel({
    required this.title,
    required this.startSeconds,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      title: json['title'] as String? ?? '',
      startSeconds: json['startSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startSeconds': startSeconds,
    };
  }

  ChapterEntity toEntity() {
    return ChapterEntity(
      title: title,
      startSeconds: startSeconds,
    );
  }

  factory ChapterModel.fromEntity(ChapterEntity entity) {
    return ChapterModel(
      title: entity.title,
      startSeconds: entity.startSeconds,
    );
  }

  ChapterModel copyWith({
    String? title,
    int? startSeconds,
  }) {
    return ChapterModel(
      title: title ?? this.title,
      startSeconds: startSeconds ?? this.startSeconds,
    );
  }

  @override
  List<Object?> get props => [title, startSeconds];
}

/// Model representing a podcast episode in Firebase
class PodcastEpisodeModel extends Equatable {
  final String id;
  final String podcastId;
  final int episodeNumber;
  final int? seasonNumber;
  final String title;
  final String? description;
  final String audioUrl;
  final int durationSeconds;
  final int? fileSizeBytes;
  final String? coverImageUrl;
  final String? sourceRoomId;
  final List<ChapterModel> chapters;
  final String status;
  final String? scheduledPublishAt;
  final String? publishedAt;
  final String createdAt;
  final int playCount;
  final int likeCount;
  final int shareCount;
  final int downloadCount;
  final String? transcription;
  final bool isPremium;
  final String mediaType;
  final String? videoUrl;
  final String? thumbnailUrl;
  final bool isLive;
  final String? livekitRoomName;
  final int liveViewerCount;

  const PodcastEpisodeModel({
    required this.id,
    required this.podcastId,
    required this.episodeNumber,
    this.seasonNumber,
    required this.title,
    this.description,
    required this.audioUrl,
    required this.durationSeconds,
    this.fileSizeBytes,
    this.coverImageUrl,
    this.sourceRoomId,
    this.chapters = const [],
    this.status = 'draft',
    this.scheduledPublishAt,
    this.publishedAt,
    required this.createdAt,
    this.playCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.downloadCount = 0,
    this.transcription,
    this.isPremium = false,
    this.mediaType = 'audio',
    this.videoUrl,
    this.thumbnailUrl,
    this.isLive = false,
    this.livekitRoomName,
    this.liveViewerCount = 0,
  });

  factory PodcastEpisodeModel.fromJson(Map<String, dynamic> json) {
    return PodcastEpisodeModel(
      id: json['id'] as String? ?? '',
      podcastId: json['podcastId'] as String? ?? '',
      episodeNumber: json['episodeNumber'] as int? ?? 1,
      seasonNumber: json['seasonNumber'] as int?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      audioUrl: json['audioUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      coverImageUrl: json['coverImageUrl'] as String?,
      sourceRoomId: json['sourceRoomId'] as String?,
      chapters: _parseChapters(json['chapters']),
      status: json['status'] as String? ?? 'draft',
      scheduledPublishAt: _timestampToString(json['scheduledPublishAt']),
      publishedAt: _timestampToString(json['publishedAt']),
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toIso8601String(),
      playCount: json['playCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      downloadCount: json['downloadCount'] as int? ?? 0,
      transcription: json['transcription'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      mediaType: json['mediaType'] as String? ?? 'audio',
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isLive: json['isLive'] as bool? ?? false,
      livekitRoomName: json['livekitRoomName'] as String?,
      liveViewerCount: json['liveViewerCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'podcastId': podcastId,
      'episodeNumber': episodeNumber,
      'seasonNumber': seasonNumber,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'coverImageUrl': coverImageUrl,
      'sourceRoomId': sourceRoomId,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'status': status,
      'scheduledPublishAt': scheduledPublishAt,
      'publishedAt': publishedAt,
      'createdAt': createdAt,
      'playCount': playCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'downloadCount': downloadCount,
      'transcription': transcription,
      'isPremium': isPremium,
      'mediaType': mediaType,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'isLive': isLive,
      'livekitRoomName': livekitRoomName,
      'liveViewerCount': liveViewerCount,
    };
  }

  /// Create from Firestore document
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'podcastId': podcastId,
      'episodeNumber': episodeNumber,
      'seasonNumber': seasonNumber,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'coverImageUrl': coverImageUrl,
      'sourceRoomId': sourceRoomId,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'status': status,
      'scheduledPublishAt': scheduledPublishAt,
      'publishedAt': publishedAt,
      'createdAt': createdAt,
      'playCount': playCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'downloadCount': downloadCount,
      'transcription': transcription,
      'isPremium': isPremium,
      'mediaType': mediaType,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'isLive': isLive,
      'livekitRoomName': livekitRoomName,
      'liveViewerCount': liveViewerCount,
    };
  }

  /// Convert to entity
  PodcastEpisodeEntity toEntity() {
    return PodcastEpisodeEntity(
      id: id,
      podcastId: podcastId,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
      title: title,
      description: description,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      coverImageUrl: coverImageUrl,
      sourceRoomId: sourceRoomId,
      chapters: chapters.map((c) => c.toEntity()).toList(),
      status: _parseStatus(status),
      scheduledPublishAt: scheduledPublishAt != null ? DateTime.parse(scheduledPublishAt!).toLocal() : null,
      publishedAt: publishedAt != null ? DateTime.parse(publishedAt!).toLocal() : null,
      createdAt: DateTime.parse(createdAt).toLocal(),
      playCount: playCount,
      likeCount: likeCount,
      shareCount: shareCount,
      downloadCount: downloadCount,
      transcription: transcription,
      isPremium: isPremium,
      mediaType: mediaType,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      isLive: isLive,
      livekitRoomName: livekitRoomName,
      liveViewerCount: liveViewerCount,
    );
  }

  /// Create from entity
  factory PodcastEpisodeModel.fromEntity(PodcastEpisodeEntity entity) {
    return PodcastEpisodeModel(
      id: entity.id,
      podcastId: entity.podcastId,
      episodeNumber: entity.episodeNumber,
      seasonNumber: entity.seasonNumber,
      title: entity.title,
      description: entity.description,
      audioUrl: entity.audioUrl,
      durationSeconds: entity.durationSeconds,
      fileSizeBytes: entity.fileSizeBytes,
      coverImageUrl: entity.coverImageUrl,
      sourceRoomId: entity.sourceRoomId,
      chapters: entity.chapters.map((c) => ChapterModel.fromEntity(c)).toList(),
      status: entity.status.name,
      scheduledPublishAt: entity.scheduledPublishAt?.toIso8601String(),
      publishedAt: entity.publishedAt?.toIso8601String(),
      createdAt: entity.createdAt.toIso8601String(),
      playCount: entity.playCount,
      likeCount: entity.likeCount,
      shareCount: entity.shareCount,
      downloadCount: entity.downloadCount,
      transcription: entity.transcription,
      isPremium: entity.isPremium,
      mediaType: entity.mediaType,
      videoUrl: entity.videoUrl,
      thumbnailUrl: entity.thumbnailUrl,
      isLive: entity.isLive,
      livekitRoomName: entity.livekitRoomName,
      liveViewerCount: entity.liveViewerCount,
    );
  }

  PodcastEpisodeModel copyWith({
    String? id,
    String? podcastId,
    int? episodeNumber,
    int? seasonNumber,
    String? title,
    String? description,
    String? audioUrl,
    int? durationSeconds,
    int? fileSizeBytes,
    String? coverImageUrl,
    String? sourceRoomId,
    List<ChapterModel>? chapters,
    String? status,
    String? scheduledPublishAt,
    String? publishedAt,
    String? createdAt,
    int? playCount,
    int? likeCount,
    int? shareCount,
    int? downloadCount,
    String? transcription,
    bool? isPremium,
    String? mediaType,
    String? videoUrl,
    String? thumbnailUrl,
    bool? isLive,
    String? livekitRoomName,
    int? liveViewerCount,
  }) {
    return PodcastEpisodeModel(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      sourceRoomId: sourceRoomId ?? this.sourceRoomId,
      chapters: chapters ?? this.chapters,
      status: status ?? this.status,
      scheduledPublishAt: scheduledPublishAt ?? this.scheduledPublishAt,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      downloadCount: downloadCount ?? this.downloadCount,
      transcription: transcription ?? this.transcription,
      isPremium: isPremium ?? this.isPremium,
      mediaType: mediaType ?? this.mediaType,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isLive: isLive ?? this.isLive,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
      liveViewerCount: liveViewerCount ?? this.liveViewerCount,
    );
  }

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  static List<ChapterModel> _parseChapters(dynamic chapters) {
    if (chapters == null) return [];
    if (chapters is List) {
      return chapters
          .map((c) => ChapterModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
    }
    return [];
  }

  static EpisodeStatus _parseStatus(String status) {
    return EpisodeStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => EpisodeStatus.draft,
    );
  }

  @override
  List<Object?> get props => [
        id,
        podcastId,
        episodeNumber,
        title,
        audioUrl,
        durationSeconds,
        status,
        createdAt,
        playCount,
      ];
}
