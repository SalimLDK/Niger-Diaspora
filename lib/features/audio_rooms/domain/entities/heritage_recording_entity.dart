import 'package:equatable/equatable.dart';

/// Type of heritage content
enum HeritageContentType {
  story, // Contes traditionnels
  proverb, // Proverbes et sagesse
  history, // Histoire orale
  ceremony, // Cérémonies traditionnelles
  language, // Leçons de langue
  craft, // Savoir-faire artisanal
  recipe, // Recettes traditionnelles
  medicine, // Médecine traditionnelle
  other,
}

/// Status of a heritage recording
enum HeritageRecordingStatus {
  pending, // En attente de modération
  approved, // Approuvé et visible
  rejected, // Rejeté par modération
  archived, // Archivé (ancien)
}

/// Entity representing a heritage recording in the cultural library
class HeritageRecordingEntity extends Equatable {
  final String id;
  final String title;
  final String? description;

  // Source audio room
  final String sourceRoomId;
  final String sourceRoomTitle;

  // Contributor info
  final String contributorId;
  final String contributorName;
  final String? contributorPhotoUrl;

  // Audio content
  final String audioUrl;
  final int durationSeconds;
  final int? fileSizeBytes;

  // Heritage metadata
  final HeritageContentType contentType;
  final String language;
  final String? region;
  final String? tribe;
  final String? era; // Époque historique si applicable

  // Classification
  final List<String> tags;
  final List<String> relatedRecordingIds;

  // Moderation
  final HeritageRecordingStatus status;
  final String? moderatorId;
  final String? moderationNote;
  final DateTime? moderatedAt;

  // Engagement
  final int playCount;
  final int likeCount;
  final int shareCount;
  final int downloadCount;

  // Timestamps
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Access control
  final bool isPremium;
  final int? premiumPrice;
  final String? premiumCurrency;
  final List<String> purchasedByUserIds;

  const HeritageRecordingEntity({
    required this.id,
    required this.title,
    this.description,
    required this.sourceRoomId,
    required this.sourceRoomTitle,
    required this.contributorId,
    required this.contributorName,
    this.contributorPhotoUrl,
    required this.audioUrl,
    required this.durationSeconds,
    this.fileSizeBytes,
    required this.contentType,
    required this.language,
    this.region,
    this.tribe,
    this.era,
    this.tags = const [],
    this.relatedRecordingIds = const [],
    this.status = HeritageRecordingStatus.pending,
    this.moderatorId,
    this.moderationNote,
    this.moderatedAt,
    this.playCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.downloadCount = 0,
    required this.recordedAt,
    required this.createdAt,
    this.updatedAt,
    this.isPremium = false,
    this.premiumPrice,
    this.premiumCurrency,
    this.purchasedByUserIds = const [],
  });

  /// Check if content is approved and visible
  bool get isApproved => status == HeritageRecordingStatus.approved;

  /// Check if user has purchased this recording (for premium content)
  bool hasAccess(String userId) {
    if (!isPremium) return true;
    return purchasedByUserIds.contains(userId);
  }

  /// Get content type label in French
  String get contentTypeLabel {
    switch (contentType) {
      case HeritageContentType.story:
        return 'Conte';
      case HeritageContentType.proverb:
        return 'Proverbe';
      case HeritageContentType.history:
        return 'Histoire';
      case HeritageContentType.ceremony:
        return 'Cérémonie';
      case HeritageContentType.language:
        return 'Langue';
      case HeritageContentType.craft:
        return 'Artisanat';
      case HeritageContentType.recipe:
        return 'Recette';
      case HeritageContentType.medicine:
        return 'Médecine';
      case HeritageContentType.other:
        return 'Autre';
    }
  }

  /// Get status label in French
  String get statusLabel {
    switch (status) {
      case HeritageRecordingStatus.pending:
        return 'En attente';
      case HeritageRecordingStatus.approved:
        return 'Approuvé';
      case HeritageRecordingStatus.rejected:
        return 'Rejeté';
      case HeritageRecordingStatus.archived:
        return 'Archivé';
    }
  }

  /// Format duration as mm:ss
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  HeritageRecordingEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? sourceRoomId,
    String? sourceRoomTitle,
    String? contributorId,
    String? contributorName,
    String? contributorPhotoUrl,
    String? audioUrl,
    int? durationSeconds,
    int? fileSizeBytes,
    HeritageContentType? contentType,
    String? language,
    String? region,
    String? tribe,
    String? era,
    List<String>? tags,
    List<String>? relatedRecordingIds,
    HeritageRecordingStatus? status,
    String? moderatorId,
    String? moderationNote,
    DateTime? moderatedAt,
    int? playCount,
    int? likeCount,
    int? shareCount,
    int? downloadCount,
    DateTime? recordedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPremium,
    int? premiumPrice,
    String? premiumCurrency,
    List<String>? purchasedByUserIds,
  }) {
    return HeritageRecordingEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceRoomId: sourceRoomId ?? this.sourceRoomId,
      sourceRoomTitle: sourceRoomTitle ?? this.sourceRoomTitle,
      contributorId: contributorId ?? this.contributorId,
      contributorName: contributorName ?? this.contributorName,
      contributorPhotoUrl: contributorPhotoUrl ?? this.contributorPhotoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      contentType: contentType ?? this.contentType,
      language: language ?? this.language,
      region: region ?? this.region,
      tribe: tribe ?? this.tribe,
      era: era ?? this.era,
      tags: tags ?? this.tags,
      relatedRecordingIds: relatedRecordingIds ?? this.relatedRecordingIds,
      status: status ?? this.status,
      moderatorId: moderatorId ?? this.moderatorId,
      moderationNote: moderationNote ?? this.moderationNote,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      downloadCount: downloadCount ?? this.downloadCount,
      recordedAt: recordedAt ?? this.recordedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPremium: isPremium ?? this.isPremium,
      premiumPrice: premiumPrice ?? this.premiumPrice,
      premiumCurrency: premiumCurrency ?? this.premiumCurrency,
      purchasedByUserIds: purchasedByUserIds ?? this.purchasedByUserIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        sourceRoomId,
        contributorId,
        audioUrl,
        contentType,
        language,
        status,
        recordedAt,
        createdAt,
      ];
}

/// Entity for heritage collection/playlist
class HeritageCollectionEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;

  // Creator
  final String creatorId;
  final String creatorName;

  // Content
  final List<String> recordingIds;

  // Classification
  final HeritageContentType? contentType;
  final String? language;
  final String? region;
  final List<String> tags;

  // Engagement
  final int followerCount;
  final int playCount;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Visibility
  final bool isPublic;
  final bool isFeatured;

  const HeritageCollectionEntity({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.creatorId,
    required this.creatorName,
    this.recordingIds = const [],
    this.contentType,
    this.language,
    this.region,
    this.tags = const [],
    this.followerCount = 0,
    this.playCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
    this.isFeatured = false,
  });

  /// Get total recordings count
  int get recordingCount => recordingIds.length;

  HeritageCollectionEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    String? creatorId,
    String? creatorName,
    List<String>? recordingIds,
    HeritageContentType? contentType,
    String? language,
    String? region,
    List<String>? tags,
    int? followerCount,
    int? playCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    bool? isFeatured,
  }) {
    return HeritageCollectionEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      recordingIds: recordingIds ?? this.recordingIds,
      contentType: contentType ?? this.contentType,
      language: language ?? this.language,
      region: region ?? this.region,
      tags: tags ?? this.tags,
      followerCount: followerCount ?? this.followerCount,
      playCount: playCount ?? this.playCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        creatorId,
        recordingIds,
        createdAt,
      ];
}

/// Entity for user's heritage library preferences/history
class HeritageUserDataEntity extends Equatable {
  final String userId;

  // Liked recordings
  final List<String> likedRecordingIds;

  // Saved/downloaded recordings
  final List<String> savedRecordingIds;

  // Followed collections
  final List<String> followedCollectionIds;

  // Listening history (last 100)
  final List<HeritageListenHistoryEntry> listenHistory;

  // Preferences
  final List<String> preferredLanguages;
  final List<String> preferredRegions;
  final List<HeritageContentType> preferredContentTypes;

  const HeritageUserDataEntity({
    required this.userId,
    this.likedRecordingIds = const [],
    this.savedRecordingIds = const [],
    this.followedCollectionIds = const [],
    this.listenHistory = const [],
    this.preferredLanguages = const [],
    this.preferredRegions = const [],
    this.preferredContentTypes = const [],
  });

  HeritageUserDataEntity copyWith({
    String? userId,
    List<String>? likedRecordingIds,
    List<String>? savedRecordingIds,
    List<String>? followedCollectionIds,
    List<HeritageListenHistoryEntry>? listenHistory,
    List<String>? preferredLanguages,
    List<String>? preferredRegions,
    List<HeritageContentType>? preferredContentTypes,
  }) {
    return HeritageUserDataEntity(
      userId: userId ?? this.userId,
      likedRecordingIds: likedRecordingIds ?? this.likedRecordingIds,
      savedRecordingIds: savedRecordingIds ?? this.savedRecordingIds,
      followedCollectionIds:
          followedCollectionIds ?? this.followedCollectionIds,
      listenHistory: listenHistory ?? this.listenHistory,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      preferredRegions: preferredRegions ?? this.preferredRegions,
      preferredContentTypes:
          preferredContentTypes ?? this.preferredContentTypes,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        likedRecordingIds,
        savedRecordingIds,
        followedCollectionIds,
        listenHistory,
      ];
}

/// Entry in listening history
class HeritageListenHistoryEntry extends Equatable {
  final String recordingId;
  final DateTime listenedAt;
  final int progressSeconds;
  final bool completed;

  const HeritageListenHistoryEntry({
    required this.recordingId,
    required this.listenedAt,
    this.progressSeconds = 0,
    this.completed = false,
  });

  HeritageListenHistoryEntry copyWith({
    String? recordingId,
    DateTime? listenedAt,
    int? progressSeconds,
    bool? completed,
  }) {
    return HeritageListenHistoryEntry(
      recordingId: recordingId ?? this.recordingId,
      listenedAt: listenedAt ?? this.listenedAt,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [recordingId, listenedAt, progressSeconds, completed];
}
