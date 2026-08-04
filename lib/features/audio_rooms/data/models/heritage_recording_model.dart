import 'package:equatable/equatable.dart';

import '../../domain/entities/heritage_recording_entity.dart';

/// Model representing a heritage recording in Firebase
class HeritageRecordingModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String sourceRoomId;
  final String sourceRoomTitle;
  final String contributorId;
  final String contributorName;
  final String? contributorPhotoUrl;
  final String audioUrl;
  final int durationSeconds;
  final int? fileSizeBytes;
  final String contentType;
  final String language;
  final String? region;
  final String? tribe;
  final String? era;
  final List<String> tags;
  final List<String> relatedRecordingIds;
  final String status;
  final String? moderatorId;
  final String? moderationNote;
  final String? moderatedAt;
  final int playCount;
  final int likeCount;
  final int shareCount;
  final int downloadCount;
  final String recordedAt;
  final String createdAt;
  final String? updatedAt;
  final bool isPremium;
  final int? premiumPrice;
  final String? premiumCurrency;
  final List<String> purchasedByUserIds;

  const HeritageRecordingModel({
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
    this.status = 'pending',
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

  factory HeritageRecordingModel.fromJson(Map<String, dynamic> json) {
    return HeritageRecordingModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sourceRoomId: json['sourceRoomId'] as String? ?? '',
      sourceRoomTitle: json['sourceRoomTitle'] as String? ?? '',
      contributorId: json['contributorId'] as String? ?? '',
      contributorName: json['contributorName'] as String? ?? '',
      contributorPhotoUrl: json['contributorPhotoUrl'] as String?,
      audioUrl: json['audioUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      contentType: json['contentType'] as String? ?? 'other',
      language: json['language'] as String? ?? '',
      region: json['region'] as String?,
      tribe: json['tribe'] as String?,
      era: json['era'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      relatedRecordingIds: List<String>.from(json['relatedRecordingIds'] ?? []),
      status: json['status'] as String? ?? 'pending',
      moderatorId: json['moderatorId'] as String?,
      moderationNote: json['moderationNote'] as String?,
      moderatedAt: _timestampToString(json['moderatedAt']),
      playCount: json['playCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      downloadCount: json['downloadCount'] as int? ?? 0,
      recordedAt: _timestampToString(json['recordedAt']) ?? DateTime.now().toIso8601String(),
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toIso8601String(),
      updatedAt: _timestampToString(json['updatedAt']),
      isPremium: json['isPremium'] as bool? ?? false,
      premiumPrice: json['premiumPrice'] as int?,
      premiumCurrency: json['premiumCurrency'] as String?,
      purchasedByUserIds: List<String>.from(json['purchasedByUserIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sourceRoomId': sourceRoomId,
      'sourceRoomTitle': sourceRoomTitle,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'contributorPhotoUrl': contributorPhotoUrl,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'contentType': contentType,
      'language': language,
      'region': region,
      'tribe': tribe,
      'era': era,
      'tags': tags,
      'relatedRecordingIds': relatedRecordingIds,
      'status': status,
      'moderatorId': moderatorId,
      'moderationNote': moderationNote,
      'moderatedAt': moderatedAt,
      'playCount': playCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'downloadCount': downloadCount,
      'recordedAt': recordedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPremium': isPremium,
      'premiumPrice': premiumPrice,
      'premiumCurrency': premiumCurrency,
      'purchasedByUserIds': purchasedByUserIds,
    };
  }

  /// Create from Firestore document
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'sourceRoomId': sourceRoomId,
      'sourceRoomTitle': sourceRoomTitle,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'contributorPhotoUrl': contributorPhotoUrl,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'contentType': contentType,
      'language': language,
      'region': region,
      'tribe': tribe,
      'era': era,
      'tags': tags,
      'relatedRecordingIds': relatedRecordingIds,
      'status': status,
      'moderatorId': moderatorId,
      'moderationNote': moderationNote,
      'moderatedAt': moderatedAt,
      'playCount': playCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'downloadCount': downloadCount,
      'recordedAt': recordedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPremium': isPremium,
      'premiumPrice': premiumPrice,
      'premiumCurrency': premiumCurrency,
      'purchasedByUserIds': purchasedByUserIds,
    };
  }

  /// Convert to entity
  HeritageRecordingEntity toEntity() {
    return HeritageRecordingEntity(
      id: id,
      title: title,
      description: description,
      sourceRoomId: sourceRoomId,
      sourceRoomTitle: sourceRoomTitle,
      contributorId: contributorId,
      contributorName: contributorName,
      contributorPhotoUrl: contributorPhotoUrl,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      contentType: _parseContentType(contentType),
      language: language,
      region: region,
      tribe: tribe,
      era: era,
      tags: tags,
      relatedRecordingIds: relatedRecordingIds,
      status: _parseStatus(status),
      moderatorId: moderatorId,
      moderationNote: moderationNote,
      moderatedAt: moderatedAt != null ? DateTime.parse(moderatedAt!).toLocal() : null,
      playCount: playCount,
      likeCount: likeCount,
      shareCount: shareCount,
      downloadCount: downloadCount,
      recordedAt: DateTime.parse(recordedAt).toLocal(),
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!).toLocal() : null,
      isPremium: isPremium,
      premiumPrice: premiumPrice,
      premiumCurrency: premiumCurrency,
      purchasedByUserIds: purchasedByUserIds,
    );
  }

  /// Create from entity
  factory HeritageRecordingModel.fromEntity(HeritageRecordingEntity entity) {
    return HeritageRecordingModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      sourceRoomId: entity.sourceRoomId,
      sourceRoomTitle: entity.sourceRoomTitle,
      contributorId: entity.contributorId,
      contributorName: entity.contributorName,
      contributorPhotoUrl: entity.contributorPhotoUrl,
      audioUrl: entity.audioUrl,
      durationSeconds: entity.durationSeconds,
      fileSizeBytes: entity.fileSizeBytes,
      contentType: entity.contentType.name,
      language: entity.language,
      region: entity.region,
      tribe: entity.tribe,
      era: entity.era,
      tags: entity.tags,
      relatedRecordingIds: entity.relatedRecordingIds,
      status: entity.status.name,
      moderatorId: entity.moderatorId,
      moderationNote: entity.moderationNote,
      moderatedAt: entity.moderatedAt?.toIso8601String(),
      playCount: entity.playCount,
      likeCount: entity.likeCount,
      shareCount: entity.shareCount,
      downloadCount: entity.downloadCount,
      recordedAt: entity.recordedAt.toIso8601String(),
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt?.toIso8601String(),
      isPremium: entity.isPremium,
      premiumPrice: entity.premiumPrice,
      premiumCurrency: entity.premiumCurrency,
      purchasedByUserIds: entity.purchasedByUserIds,
    );
  }

  HeritageRecordingModel copyWith({
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
    String? contentType,
    String? language,
    String? region,
    String? tribe,
    String? era,
    List<String>? tags,
    List<String>? relatedRecordingIds,
    String? status,
    String? moderatorId,
    String? moderationNote,
    String? moderatedAt,
    int? playCount,
    int? likeCount,
    int? shareCount,
    int? downloadCount,
    String? recordedAt,
    String? createdAt,
    String? updatedAt,
    bool? isPremium,
    int? premiumPrice,
    String? premiumCurrency,
    List<String>? purchasedByUserIds,
  }) {
    return HeritageRecordingModel(
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

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  static HeritageContentType _parseContentType(String type) {
    switch (type) {
      case 'story':
        return HeritageContentType.story;
      case 'proverb':
        return HeritageContentType.proverb;
      case 'history':
        return HeritageContentType.history;
      case 'ceremony':
        return HeritageContentType.ceremony;
      case 'language':
        return HeritageContentType.language;
      case 'craft':
        return HeritageContentType.craft;
      case 'recipe':
        return HeritageContentType.recipe;
      case 'medicine':
        return HeritageContentType.medicine;
      default:
        return HeritageContentType.other;
    }
  }

  static HeritageRecordingStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return HeritageRecordingStatus.pending;
      case 'approved':
        return HeritageRecordingStatus.approved;
      case 'rejected':
        return HeritageRecordingStatus.rejected;
      case 'archived':
        return HeritageRecordingStatus.archived;
      default:
        return HeritageRecordingStatus.pending;
    }
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

/// Model representing a heritage collection in Firebase
class HeritageCollectionModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String creatorId;
  final String creatorName;
  final List<String> recordingIds;
  final String? contentType;
  final String? language;
  final String? region;
  final List<String> tags;
  final int followerCount;
  final int playCount;
  final String createdAt;
  final String? updatedAt;
  final bool isPublic;
  final bool isFeatured;

  const HeritageCollectionModel({
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

  factory HeritageCollectionModel.fromJson(Map<String, dynamic> json) {
    return HeritageCollectionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      recordingIds: List<String>.from(json['recordingIds'] ?? []),
      contentType: json['contentType'] as String?,
      language: json['language'] as String?,
      region: json['region'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      followerCount: json['followerCount'] as int? ?? 0,
      playCount: json['playCount'] as int? ?? 0,
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toIso8601String(),
      updatedAt: _timestampToString(json['updatedAt']),
      isPublic: json['isPublic'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'recordingIds': recordingIds,
      'contentType': contentType,
      'language': language,
      'region': region,
      'tags': tags,
      'followerCount': followerCount,
      'playCount': playCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPublic': isPublic,
      'isFeatured': isFeatured,
    };
  }

  /// Create from Firestore document
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'recordingIds': recordingIds,
      'contentType': contentType,
      'language': language,
      'region': region,
      'tags': tags,
      'followerCount': followerCount,
      'playCount': playCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPublic': isPublic,
      'isFeatured': isFeatured,
    };
  }

  /// Convert to entity
  HeritageCollectionEntity toEntity() {
    return HeritageCollectionEntity(
      id: id,
      title: title,
      description: description,
      coverImageUrl: coverImageUrl,
      creatorId: creatorId,
      creatorName: creatorName,
      recordingIds: recordingIds,
      contentType: contentType != null ? _parseContentType(contentType!) : null,
      language: language,
      region: region,
      tags: tags,
      followerCount: followerCount,
      playCount: playCount,
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!).toLocal() : null,
      isPublic: isPublic,
      isFeatured: isFeatured,
    );
  }

  /// Create from entity
  factory HeritageCollectionModel.fromEntity(HeritageCollectionEntity entity) {
    return HeritageCollectionModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      coverImageUrl: entity.coverImageUrl,
      creatorId: entity.creatorId,
      creatorName: entity.creatorName,
      recordingIds: entity.recordingIds,
      contentType: entity.contentType?.name,
      language: entity.language,
      region: entity.region,
      tags: entity.tags,
      followerCount: entity.followerCount,
      playCount: entity.playCount,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt?.toIso8601String(),
      isPublic: entity.isPublic,
      isFeatured: entity.isFeatured,
    );
  }

  HeritageCollectionModel copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    String? creatorId,
    String? creatorName,
    List<String>? recordingIds,
    String? contentType,
    String? language,
    String? region,
    List<String>? tags,
    int? followerCount,
    int? playCount,
    String? createdAt,
    String? updatedAt,
    bool? isPublic,
    bool? isFeatured,
  }) {
    return HeritageCollectionModel(
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

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  static HeritageContentType _parseContentType(String type) {
    switch (type) {
      case 'story':
        return HeritageContentType.story;
      case 'proverb':
        return HeritageContentType.proverb;
      case 'history':
        return HeritageContentType.history;
      case 'ceremony':
        return HeritageContentType.ceremony;
      case 'language':
        return HeritageContentType.language;
      case 'craft':
        return HeritageContentType.craft;
      case 'recipe':
        return HeritageContentType.recipe;
      case 'medicine':
        return HeritageContentType.medicine;
      default:
        return HeritageContentType.other;
    }
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
