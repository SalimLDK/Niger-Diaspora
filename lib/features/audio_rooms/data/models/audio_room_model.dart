import 'package:equatable/equatable.dart';

import '../../domain/entities/audio_room_entity.dart';

/// Model representing an audio room in Firebase
class AudioRoomModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final List<String> coHostIds;
  final List<String> speakerIds;
  final List<String> listenerIds;
  final List<String> invitedSpeakerIds;
  final List<String> handRaiseUserIds;
  final List<String> moderatorIds;
  final String status;
  final String? scheduledAt;
  final String? startedAt;
  final String? endedAt;
  final String createdAt;
  final bool isPrivate;
  final List<String> allowedUserIds;
  final int maxListeners;
  final int maxSpeakers;
  final Map<String, String> mutedSpeakers;
  final List<String> blockedUserIds;
  final List<String> tags;
  final bool isRecordingEnabled;
  final bool isVideoEnabled;
  final bool isPaid;
  final int? ticketPrice;
  final String? ticketCurrency;
  // Diaspora-specific fields
  final String category;
  final String mode;
  final String? linkedEventId;
  final String? linkedGroupId;
  final String? linkedEmbassyId;
  final String collectionType;
  final int? collectionGoal;
  final int collectionAmount;
  final String? collectionDescription;
  final String? collectionBeneficiary;
  final bool isHeritageContent;
  final String? heritageLanguage;
  final String? heritageRegion;
  final List<String> displayTimezones;

  const AudioRoomModel({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    this.coHostIds = const [],
    this.speakerIds = const [],
    this.listenerIds = const [],
    this.invitedSpeakerIds = const [],
    this.handRaiseUserIds = const [],
    this.moderatorIds = const [],
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.isPrivate = false,
    this.allowedUserIds = const [],
    this.maxListeners = 1000,
    this.maxSpeakers = 10,
    this.mutedSpeakers = const {},
    this.blockedUserIds = const [],
    this.tags = const [],
    this.isRecordingEnabled = false,
    this.isVideoEnabled = false,
    this.isPaid = false,
    this.ticketPrice,
    this.ticketCurrency,
    this.category = 'general',
    this.mode = 'normal',
    this.linkedEventId,
    this.linkedGroupId,
    this.linkedEmbassyId,
    this.collectionType = 'none',
    this.collectionGoal,
    this.collectionAmount = 0,
    this.collectionDescription,
    this.collectionBeneficiary,
    this.isHeritageContent = false,
    this.heritageLanguage,
    this.heritageRegion,
    this.displayTimezones = const ['Africa/Niamey', 'Europe/Paris', 'America/New_York'],
  });

  factory AudioRoomModel.fromJson(Map<String, dynamic> json) {
    return AudioRoomModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      hostId: json['hostId'] as String? ?? '',
      hostName: json['hostName'] as String? ?? '',
      hostPhotoUrl: json['hostPhotoUrl'] as String?,
      coHostIds: List<String>.from(json['coHostIds'] ?? []),
      speakerIds: List<String>.from(json['speakerIds'] ?? []),
      listenerIds: List<String>.from(json['listenerIds'] ?? []),
      invitedSpeakerIds: List<String>.from(json['invitedSpeakerIds'] ?? []),
      handRaiseUserIds: List<String>.from(json['handRaiseUserIds'] ?? []),
      moderatorIds: List<String>.from(json['moderatorIds'] ?? []),
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: _timestampToString(json['scheduledAt']),
      startedAt: _timestampToString(json['startedAt']),
      endedAt: _timestampToString(json['endedAt']),
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toIso8601String(),
      isPrivate: json['isPrivate'] as bool? ?? false,
      allowedUserIds: List<String>.from(json['allowedUserIds'] ?? []),
      maxListeners: json['maxListeners'] as int? ?? 1000,
      maxSpeakers: json['maxSpeakers'] as int? ?? 10,
      mutedSpeakers: _parseMapStringString(json['mutedSpeakers']),
      blockedUserIds: List<String>.from(json['blockedUserIds'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      isRecordingEnabled: json['isRecordingEnabled'] as bool? ?? false,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? false,
      isPaid: json['isPaid'] as bool? ?? false,
      ticketPrice: json['ticketPrice'] as int?,
      ticketCurrency: json['ticketCurrency'] as String?,
      category: json['category'] as String? ?? 'general',
      mode: json['mode'] as String? ?? 'normal',
      linkedEventId: json['linkedEventId'] as String?,
      linkedGroupId: json['linkedGroupId'] as String?,
      linkedEmbassyId: json['linkedEmbassyId'] as String?,
      collectionType: json['collectionType'] as String? ?? 'none',
      collectionGoal: json['collectionGoal'] as int?,
      collectionAmount: json['collectionAmount'] as int? ?? 0,
      collectionDescription: json['collectionDescription'] as String?,
      collectionBeneficiary: json['collectionBeneficiary'] as String?,
      isHeritageContent: json['isHeritageContent'] as bool? ?? false,
      heritageLanguage: json['heritageLanguage'] as String?,
      heritageRegion: json['heritageRegion'] as String?,
      displayTimezones: List<String>.from(json['displayTimezones'] ?? ['Africa/Niamey', 'Europe/Paris', 'America/New_York']),
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
      'speakerIds': speakerIds,
      'listenerIds': listenerIds,
      'invitedSpeakerIds': invitedSpeakerIds,
      'handRaiseUserIds': handRaiseUserIds,
      'moderatorIds': moderatorIds,
      'status': status,
      'scheduledAt': scheduledAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'createdAt': createdAt,
      'isPrivate': isPrivate,
      'allowedUserIds': allowedUserIds,
      'maxListeners': maxListeners,
      'maxSpeakers': maxSpeakers,
      'mutedSpeakers': mutedSpeakers,
      'blockedUserIds': blockedUserIds,
      'tags': tags,
      'isRecordingEnabled': isRecordingEnabled,
      'isVideoEnabled': isVideoEnabled,
      'isPaid': isPaid,
      'ticketPrice': ticketPrice,
      'ticketCurrency': ticketCurrency,
      'category': category,
      'mode': mode,
      'linkedEventId': linkedEventId,
      'linkedGroupId': linkedGroupId,
      'linkedEmbassyId': linkedEmbassyId,
      'collectionType': collectionType,
      'collectionGoal': collectionGoal,
      'collectionAmount': collectionAmount,
      'collectionDescription': collectionDescription,
      'collectionBeneficiary': collectionBeneficiary,
      'isHeritageContent': isHeritageContent,
      'heritageLanguage': heritageLanguage,
      'heritageRegion': heritageRegion,
      'displayTimezones': displayTimezones,
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
      'speakerIds': speakerIds,
      'listenerIds': listenerIds,
      'invitedSpeakerIds': invitedSpeakerIds,
      'handRaiseUserIds': handRaiseUserIds,
      'moderatorIds': moderatorIds,
      'status': status,
      'scheduledAt': scheduledAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'createdAt': createdAt,
      'isPrivate': isPrivate,
      'allowedUserIds': allowedUserIds,
      'maxListeners': maxListeners,
      'maxSpeakers': maxSpeakers,
      'mutedSpeakers': mutedSpeakers,
      'blockedUserIds': blockedUserIds,
      'tags': tags,
      'isRecordingEnabled': isRecordingEnabled,
      'isVideoEnabled': isVideoEnabled,
      'isPaid': isPaid,
      'ticketPrice': ticketPrice,
      'ticketCurrency': ticketCurrency,
      'category': category,
      'mode': mode,
      'linkedEventId': linkedEventId,
      'linkedGroupId': linkedGroupId,
      'linkedEmbassyId': linkedEmbassyId,
      'collectionType': collectionType,
      'collectionGoal': collectionGoal,
      'collectionAmount': collectionAmount,
      'collectionDescription': collectionDescription,
      'collectionBeneficiary': collectionBeneficiary,
      'isHeritageContent': isHeritageContent,
      'heritageLanguage': heritageLanguage,
      'heritageRegion': heritageRegion,
      'displayTimezones': displayTimezones,
    };
  }

  /// Convert to entity
  AudioRoomEntity toEntity() {
    return AudioRoomEntity(
      id: id,
      title: title,
      description: description,
      coverImageUrl: coverImageUrl,
      hostId: hostId,
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      coHostIds: coHostIds,
      speakerIds: speakerIds,
      listenerIds: listenerIds,
      invitedSpeakerIds: invitedSpeakerIds,
      handRaiseUserIds: handRaiseUserIds,
      moderatorIds: moderatorIds,
      status: _parseStatus(status),
      scheduledAt: scheduledAt != null ? DateTime.parse(scheduledAt!).toLocal() : null,
      startedAt: startedAt != null ? DateTime.parse(startedAt!).toLocal() : null,
      endedAt: endedAt != null ? DateTime.parse(endedAt!).toLocal() : null,
      createdAt: DateTime.parse(createdAt).toLocal(),
      isPrivate: isPrivate,
      allowedUserIds: allowedUserIds,
      maxListeners: maxListeners,
      maxSpeakers: maxSpeakers,
      mutedSpeakers: mutedSpeakers.map((k, v) => MapEntry(k, DateTime.parse(v).toLocal())),
      blockedUserIds: blockedUserIds,
      tags: tags,
      isRecordingEnabled: isRecordingEnabled,
      isVideoEnabled: isVideoEnabled,
      isPaid: isPaid,
      ticketPrice: ticketPrice,
      ticketCurrency: ticketCurrency,
      category: _parseCategory(category),
      mode: _parseMode(mode),
      linkedEventId: linkedEventId,
      linkedGroupId: linkedGroupId,
      linkedEmbassyId: linkedEmbassyId,
      collectionType: _parseCollectionType(collectionType),
      collectionGoal: collectionGoal,
      collectionAmount: collectionAmount,
      collectionDescription: collectionDescription,
      collectionBeneficiary: collectionBeneficiary,
      isHeritageContent: isHeritageContent,
      heritageLanguage: heritageLanguage,
      heritageRegion: heritageRegion,
      displayTimezones: displayTimezones,
    );
  }

  /// Create from entity
  factory AudioRoomModel.fromEntity(AudioRoomEntity entity) {
    return AudioRoomModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      coverImageUrl: entity.coverImageUrl,
      hostId: entity.hostId,
      hostName: entity.hostName,
      hostPhotoUrl: entity.hostPhotoUrl,
      coHostIds: entity.coHostIds,
      speakerIds: entity.speakerIds,
      listenerIds: entity.listenerIds,
      invitedSpeakerIds: entity.invitedSpeakerIds,
      handRaiseUserIds: entity.handRaiseUserIds,
      moderatorIds: entity.moderatorIds,
      status: entity.status.name,
      scheduledAt: entity.scheduledAt?.toIso8601String(),
      startedAt: entity.startedAt?.toIso8601String(),
      endedAt: entity.endedAt?.toIso8601String(),
      createdAt: entity.createdAt.toIso8601String(),
      isPrivate: entity.isPrivate,
      allowedUserIds: entity.allowedUserIds,
      maxListeners: entity.maxListeners,
      maxSpeakers: entity.maxSpeakers,
      mutedSpeakers: entity.mutedSpeakers.map((k, v) => MapEntry(k, v.toIso8601String())),
      blockedUserIds: entity.blockedUserIds,
      tags: entity.tags,
      isRecordingEnabled: entity.isRecordingEnabled,
      isVideoEnabled: entity.isVideoEnabled,
      isPaid: entity.isPaid,
      ticketPrice: entity.ticketPrice,
      ticketCurrency: entity.ticketCurrency,
      category: entity.category.name,
      mode: entity.mode.name,
      linkedEventId: entity.linkedEventId,
      linkedGroupId: entity.linkedGroupId,
      linkedEmbassyId: entity.linkedEmbassyId,
      collectionType: entity.collectionType.name,
      collectionGoal: entity.collectionGoal,
      collectionAmount: entity.collectionAmount,
      collectionDescription: entity.collectionDescription,
      collectionBeneficiary: entity.collectionBeneficiary,
      isHeritageContent: entity.isHeritageContent,
      heritageLanguage: entity.heritageLanguage,
      heritageRegion: entity.heritageRegion,
      displayTimezones: entity.displayTimezones,
    );
  }

  AudioRoomModel copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? coHostIds,
    List<String>? speakerIds,
    List<String>? listenerIds,
    List<String>? invitedSpeakerIds,
    List<String>? handRaiseUserIds,
    List<String>? moderatorIds,
    String? status,
    String? scheduledAt,
    String? startedAt,
    String? endedAt,
    String? createdAt,
    bool? isPrivate,
    List<String>? allowedUserIds,
    int? maxListeners,
    int? maxSpeakers,
    Map<String, String>? mutedSpeakers,
    List<String>? blockedUserIds,
    List<String>? tags,
    bool? isRecordingEnabled,
    bool? isVideoEnabled,
    bool? isPaid,
    int? ticketPrice,
    String? ticketCurrency,
    String? category,
    String? mode,
    String? linkedEventId,
    String? linkedGroupId,
    String? linkedEmbassyId,
    String? collectionType,
    int? collectionGoal,
    int? collectionAmount,
    String? collectionDescription,
    String? collectionBeneficiary,
    bool? isHeritageContent,
    String? heritageLanguage,
    String? heritageRegion,
    List<String>? displayTimezones,
  }) {
    return AudioRoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      coHostIds: coHostIds ?? this.coHostIds,
      speakerIds: speakerIds ?? this.speakerIds,
      listenerIds: listenerIds ?? this.listenerIds,
      invitedSpeakerIds: invitedSpeakerIds ?? this.invitedSpeakerIds,
      handRaiseUserIds: handRaiseUserIds ?? this.handRaiseUserIds,
      moderatorIds: moderatorIds ?? this.moderatorIds,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      isPrivate: isPrivate ?? this.isPrivate,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      maxListeners: maxListeners ?? this.maxListeners,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      mutedSpeakers: mutedSpeakers ?? this.mutedSpeakers,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      tags: tags ?? this.tags,
      isRecordingEnabled: isRecordingEnabled ?? this.isRecordingEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isPaid: isPaid ?? this.isPaid,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      ticketCurrency: ticketCurrency ?? this.ticketCurrency,
      category: category ?? this.category,
      mode: mode ?? this.mode,
      linkedEventId: linkedEventId ?? this.linkedEventId,
      linkedGroupId: linkedGroupId ?? this.linkedGroupId,
      linkedEmbassyId: linkedEmbassyId ?? this.linkedEmbassyId,
      collectionType: collectionType ?? this.collectionType,
      collectionGoal: collectionGoal ?? this.collectionGoal,
      collectionAmount: collectionAmount ?? this.collectionAmount,
      collectionDescription: collectionDescription ?? this.collectionDescription,
      collectionBeneficiary: collectionBeneficiary ?? this.collectionBeneficiary,
      isHeritageContent: isHeritageContent ?? this.isHeritageContent,
      heritageLanguage: heritageLanguage ?? this.heritageLanguage,
      heritageRegion: heritageRegion ?? this.heritageRegion,
      displayTimezones: displayTimezones ?? this.displayTimezones,
    );
  }

  static AudioRoomStatus _parseStatus(String status) {
    switch (status) {
      case 'scheduled':
        return AudioRoomStatus.scheduled;
      case 'live':
        return AudioRoomStatus.live;
      case 'ended':
        return AudioRoomStatus.ended;
      default:
        return AudioRoomStatus.scheduled;
    }
  }

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  static Map<String, String> _parseMapStringString(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, String>.from(
        data.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }
    return {};
  }

  static AudioRoomCategory _parseCategory(String category) {
    switch (category) {
      case 'griot':
        return AudioRoomCategory.griot;
      case 'spirituality':
        return AudioRoomCategory.spirituality;
      case 'news':
        return AudioRoomCategory.news;
      case 'business':
        return AudioRoomCategory.business;
      case 'mentorship':
        return AudioRoomCategory.mentorship;
      case 'family':
        return AudioRoomCategory.family;
      case 'official':
        return AudioRoomCategory.official;
      case 'culture':
        return AudioRoomCategory.culture;
      case 'education':
        return AudioRoomCategory.education;
      default:
        return AudioRoomCategory.general;
    }
  }

  static AudioRoomMode _parseMode(String mode) {
    switch (mode) {
      case 'ceremony':
        return AudioRoomMode.ceremony;
      case 'radio':
        return AudioRoomMode.radio;
      case 'heritage':
        return AudioRoomMode.heritage;
      default:
        return AudioRoomMode.normal;
    }
  }

  static CollectionType _parseCollectionType(String type) {
    switch (type) {
      case 'familyEvent':
        return CollectionType.familyEvent;
      case 'emergency':
        return CollectionType.emergency;
      case 'communityProject':
        return CollectionType.communityProject;
      case 'associationDues':
        return CollectionType.associationDues;
      case 'custom':
        return CollectionType.custom;
      default:
        return CollectionType.none;
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        hostId,
        status,
        createdAt,
        coHostIds,
        speakerIds,
        listenerIds,
        handRaiseUserIds,
      ];
}
