import 'package:equatable/equatable.dart';

/// Status of a podcast episode
enum EpisodeStatus {
  /// Draft, not yet published
  draft,

  /// Scheduled for future publication
  scheduled,

  /// Published and available
  published,

  /// Archived/Removed
  archived,
}

/// A chapter/timestamp within an episode
class ChapterEntity extends Equatable {
  /// Title of the chapter
  final String title;

  /// Start time in seconds
  final int startSeconds;

  const ChapterEntity({
    required this.title,
    required this.startSeconds,
  });

  /// Get formatted start time (MM:SS or HH:MM:SS)
  String get formattedStartTime {
    final hours = startSeconds ~/ 3600;
    final minutes = (startSeconds % 3600) ~/ 60;
    final seconds = startSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  ChapterEntity copyWith({
    String? title,
    int? startSeconds,
  }) {
    return ChapterEntity(
      title: title ?? this.title,
      startSeconds: startSeconds ?? this.startSeconds,
    );
  }

  @override
  List<Object?> get props => [title, startSeconds];
}

/// Entity representing a podcast episode
class PodcastEpisodeEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Parent podcast ID
  final String podcastId;

  /// Episode number
  final int episodeNumber;

  /// Season number (optional)
  final int? seasonNumber;

  /// Title of the episode
  final String title;

  /// Description/show notes
  final String? description;

  /// Audio file URL
  final String audioUrl;

  /// Duration in seconds
  final int durationSeconds;

  /// File size in bytes
  final int? fileSizeBytes;

  /// Episode-specific cover image URL (optional, falls back to podcast cover)
  final String? coverImageUrl;

  /// Source audio room ID (if recorded from live room)
  final String? sourceRoomId;

  /// Chapters/timestamps for navigation
  final List<ChapterEntity> chapters;

  /// Current status
  final EpisodeStatus status;

  /// Scheduled publication date (if scheduled)
  final DateTime? scheduledPublishAt;

  /// Actual publication date
  final DateTime? publishedAt;

  /// Creation date
  final DateTime createdAt;

  /// Number of plays
  final int playCount;

  /// Number of likes
  final int likeCount;

  /// Number of shares
  final int shareCount;

  /// Number of downloads
  final int downloadCount;

  /// Transcription text (for accessibility/search)
  final String? transcription;

  /// Whether this is a premium-only episode
  final bool isPremium;

  /// Media type: 'audio', 'video', or 'live_video'
  final String mediaType;

  /// Video file URL (Firebase Storage), null for audio episodes
  final String? videoUrl;

  /// Video thumbnail URL, null for audio episodes
  final String? thumbnailUrl;

  /// Whether a live stream is currently active for this episode
  final bool isLive;

  /// LiveKit room name when live streaming
  final String? livekitRoomName;

  /// Current live viewer count (ephemeral, from RTDB)
  final int liveViewerCount;

  const PodcastEpisodeEntity({
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
    this.status = EpisodeStatus.draft,
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

  /// Get formatted duration (MM:SS or HH:MM:SS)
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min ${seconds}s';
  }

  /// Get short formatted duration (MM:SS or H:MM:SS)
  String get shortFormattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSizeBytes == null) return '';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Get episode label (e.g., "S1 E5" or "Ep. 5")
  String get episodeLabel {
    if (seasonNumber != null) {
      return 'S$seasonNumber E$episodeNumber';
    }
    return 'Ep. $episodeNumber';
  }

  /// Get status label in French
  String get statusLabel => switch (status) {
        EpisodeStatus.draft => 'Brouillon',
        EpisodeStatus.scheduled => 'Programmé',
        EpisodeStatus.published => 'Publié',
        EpisodeStatus.archived => 'Archivé',
      };

  /// Whether the episode was recorded from a live room
  bool get isFromLiveRoom => sourceRoomId != null;

  /// Whether the episode has chapters
  bool get hasChapters => chapters.isNotEmpty;

  /// Whether this episode has video content
  bool get isVideoEpisode => mediaType == 'video' || mediaType == 'live_video';

  /// Copy with new values
  PodcastEpisodeEntity copyWith({
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
    List<ChapterEntity>? chapters,
    EpisodeStatus? status,
    DateTime? scheduledPublishAt,
    DateTime? publishedAt,
    DateTime? createdAt,
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
    return PodcastEpisodeEntity(
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

  @override
  List<Object?> get props => [
        id,
        podcastId,
        episodeNumber,
        title,
        status,
        createdAt,
        playCount,
      ];
}
