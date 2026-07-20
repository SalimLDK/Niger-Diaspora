import 'package:equatable/equatable.dart';

/// Status of an audio room
enum AudioRoomStatus {
  /// Room is scheduled for a future time
  scheduled,

  /// Room is currently live
  live,

  /// Room has ended
  ended,
}

/// Cultural categories for diaspora audio rooms
enum AudioRoomCategory {
  /// General discussion
  general,

  /// Griot/Traditional storytelling
  griot,

  /// Spirituality/Religion
  spirituality,

  /// News from the home country
  news,

  /// Business/Networking for diaspora
  business,

  /// Mentorship/Integration support
  mentorship,

  /// Family gatherings (private)
  family,

  /// Official (Embassies/Associations)
  official,

  /// Music and culture
  culture,

  /// Education/Learning
  education,
}

/// Special modes for diaspora events
enum AudioRoomMode {
  /// Normal discussion
  normal,

  /// Ceremony mode (wedding, baptism broadcast)
  ceremony,

  /// Radio mode (continuous broadcast with playlist)
  radio,

  /// Heritage recording (for cultural preservation)
  heritage,
}

/// Collection/Fundraising type
enum CollectionType {
  /// No collection
  none,

  /// Family event contribution (wedding, baptism, etc.)
  familyEvent,

  /// Emergency aid (health, repatriation)
  emergency,

  /// Community project in home country
  communityProject,

  /// Association dues
  associationDues,

  /// Custom collection
  custom,
}

/// Entity representing an audio room (like X Spaces)
class AudioRoomEntity extends Equatable {
  /// Unique identifier for the room
  final String id;

  /// Title of the room
  final String title;

  /// Description of the room
  final String? description;

  /// Cover image URL
  final String? coverImageUrl;

  /// ID of the host
  final String hostId;

  /// Display name of the host
  final String hostName;

  /// Photo URL of the host
  final String? hostPhotoUrl;

  /// List of co-host user IDs
  final List<String> coHostIds;

  /// List of speaker user IDs (not including host and co-hosts)
  final List<String> speakerIds;

  /// List of listener user IDs
  final List<String> listenerIds;

  /// List of user IDs who have been invited to speak
  final List<String> invitedSpeakerIds;

  /// List of user IDs who have raised their hand
  final List<String> handRaiseUserIds;

  /// List of moderator user IDs (invisible admins in ghost mode)
  final List<String> moderatorIds;

  /// Current status of the room
  final AudioRoomStatus status;

  /// When the room is scheduled to start (for scheduled rooms)
  final DateTime? scheduledAt;

  /// When the room actually started
  final DateTime? startedAt;

  /// When the room ended
  final DateTime? endedAt;

  /// When the room was created
  final DateTime createdAt;

  /// Whether the room is private (invite-only)
  final bool isPrivate;

  /// List of user IDs allowed to join (for private rooms)
  final List<String> allowedUserIds;

  /// Maximum number of listeners allowed
  final int maxListeners;

  /// Maximum number of speakers allowed (like X Spaces limit of 10)
  final int maxSpeakers;

  /// Map of muted speaker IDs to when they were muted
  final Map<String, DateTime> mutedSpeakers;

  /// List of blocked/banned user IDs
  final List<String> blockedUserIds;

  /// Tags for discoverability
  final List<String> tags;

  /// Whether recording is enabled
  final bool isRecordingEnabled;

  /// Whether video is enabled for this room
  final bool isVideoEnabled;

  /// Whether the room is a paid/ticketed room
  final bool isPaid;

  /// Ticket price in cents (if paid)
  final int? ticketPrice;

  /// Currency for ticket price
  final String? ticketCurrency;

  // ========== DIASPORA-SPECIFIC FIELDS ==========

  /// Cultural category of the room
  final AudioRoomCategory category;

  /// Special mode for the room
  final AudioRoomMode mode;

  /// Linked event ID (for ceremony broadcasts)
  final String? linkedEventId;

  /// Linked group ID (for group-exclusive rooms)
  final String? linkedGroupId;

  /// Linked embassy ID (for official announcements)
  final String? linkedEmbassyId;

  /// Collection/Fundraising type
  final CollectionType collectionType;

  /// Collection goal amount in cents
  final int? collectionGoal;

  /// Current collection amount in cents
  final int collectionAmount;

  /// Collection description/purpose
  final String? collectionDescription;

  /// Collection beneficiary name
  final String? collectionBeneficiary;

  /// Whether this is a heritage/cultural preservation recording
  final bool isHeritageContent;

  /// Heritage content language (e.g., 'hausa', 'zarma', 'french')
  final String? heritageLanguage;

  /// Heritage content region/origin
  final String? heritageRegion;

  /// Display timezones for international participants
  final List<String> displayTimezones;

  const AudioRoomEntity({
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
    // Diaspora-specific fields
    this.category = AudioRoomCategory.general,
    this.mode = AudioRoomMode.normal,
    this.linkedEventId,
    this.linkedGroupId,
    this.linkedEmbassyId,
    this.collectionType = CollectionType.none,
    this.collectionGoal,
    this.collectionAmount = 0,
    this.collectionDescription,
    this.collectionBeneficiary,
    this.isHeritageContent = false,
    this.heritageLanguage,
    this.heritageRegion,
    this.displayTimezones = const ['Africa/Niamey', 'Europe/Paris', 'America/New_York'],
  });

  /// Total number of participants
  int get totalParticipants =>
      1 + coHostIds.length + speakerIds.length + listenerIds.length;

  /// Number of current speakers (including host and co-hosts)
  int get speakerCount => 1 + coHostIds.length + speakerIds.length;

  /// Number of current listeners
  int get listenerCount => listenerIds.length;

  /// Whether the room is at speaker capacity
  bool get isAtSpeakerCapacity => speakerCount >= maxSpeakers;

  /// Whether the room is at listener capacity
  bool get isAtListenerCapacity => listenerCount >= maxListeners;

  /// Check if a user is the host
  bool isHost(String userId) => hostId == userId;

  /// Check if a user is a co-host
  bool isCoHost(String userId) => coHostIds.contains(userId);

  /// Check if a user is a speaker (including host and co-hosts)
  bool isSpeaker(String userId) =>
      isHost(userId) || isCoHost(userId) || speakerIds.contains(userId);

  /// Check if a user is a listener
  bool isListener(String userId) => listenerIds.contains(userId);

  /// Check if a user is a participant (speaker or listener)
  bool isParticipant(String userId) => isSpeaker(userId) || isListener(userId);

  /// Check if a user has raised their hand
  bool hasHandRaised(String userId) => handRaiseUserIds.contains(userId);

  /// Check if a user has been invited to speak
  bool isInvitedToSpeak(String userId) => invitedSpeakerIds.contains(userId);

  /// Check if a user is muted
  bool isMuted(String userId) => mutedSpeakers.containsKey(userId);

  /// Check if a user is blocked
  bool isBlocked(String userId) => blockedUserIds.contains(userId);

  /// Check if a user is a ghost moderator (invisible admin)
  bool isModerator(String userId) => moderatorIds.contains(userId);

  /// Check if a user can speak (is speaker and not muted)
  bool canSpeak(String userId) => isSpeaker(userId) && !isMuted(userId);

  /// Check if a user has moderation rights (host or co-host)
  bool canModerate(String userId) => isHost(userId) || isCoHost(userId);

  /// Check if a user can join the room
  bool canJoin(String userId) {
    if (isBlocked(userId)) return false;
    if (!isPrivate) return true;
    return allowedUserIds.contains(userId) ||
        isHost(userId) ||
        isCoHost(userId) ||
        invitedSpeakerIds.contains(userId);
  }

  /// Get the role of a user in the room
  String getRoleLabel(String userId) {
    if (isHost(userId)) return 'Hôte';
    if (isCoHost(userId)) return 'Co-hôte';
    if (speakerIds.contains(userId)) return 'Speaker';
    if (listenerIds.contains(userId)) return 'Listener';
    return 'Non participant';
  }

  /// Copy with new values
  AudioRoomEntity copyWith({
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
    AudioRoomStatus? status,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    bool? isPrivate,
    List<String>? allowedUserIds,
    int? maxListeners,
    int? maxSpeakers,
    Map<String, DateTime>? mutedSpeakers,
    List<String>? blockedUserIds,
    List<String>? tags,
    bool? isRecordingEnabled,
    bool? isVideoEnabled,
    bool? isPaid,
    int? ticketPrice,
    String? ticketCurrency,
    // Diaspora-specific fields
    AudioRoomCategory? category,
    AudioRoomMode? mode,
    String? linkedEventId,
    String? linkedGroupId,
    String? linkedEmbassyId,
    CollectionType? collectionType,
    int? collectionGoal,
    int? collectionAmount,
    String? collectionDescription,
    String? collectionBeneficiary,
    bool? isHeritageContent,
    String? heritageLanguage,
    String? heritageRegion,
    List<String>? displayTimezones,
  }) {
    return AudioRoomEntity(
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
      // Diaspora-specific fields
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

  /// Check if collection is active
  bool get hasActiveCollection => collectionType != CollectionType.none;

  /// Collection progress percentage (0-100)
  double get collectionProgress {
    if (collectionGoal == null || collectionGoal == 0) return 0;
    return (collectionAmount / collectionGoal! * 100).clamp(0, 100);
  }

  /// Get category label in French
  String get categoryLabel => switch (category) {
        AudioRoomCategory.general => 'Discussion',
        AudioRoomCategory.griot => 'Griot/Conte',
        AudioRoomCategory.spirituality => 'Spiritualité',
        AudioRoomCategory.news => 'Actualités',
        AudioRoomCategory.business => 'Business',
        AudioRoomCategory.mentorship => 'Mentorat',
        AudioRoomCategory.family => 'Famille',
        AudioRoomCategory.official => 'Officiel',
        AudioRoomCategory.culture => 'Culture',
        AudioRoomCategory.education => 'Éducation',
      };

  /// Get mode label in French
  String get modeLabel => switch (mode) {
        AudioRoomMode.normal => 'Normal',
        AudioRoomMode.ceremony => 'Cérémonie',
        AudioRoomMode.radio => 'Radio',
        AudioRoomMode.heritage => 'Patrimoine',
      };

  /// Get collection type label in French
  String get collectionTypeLabel => switch (collectionType) {
        CollectionType.none => 'Aucune',
        CollectionType.familyEvent => 'Événement familial',
        CollectionType.emergency => 'Aide d\'urgence',
        CollectionType.communityProject => 'Projet communautaire',
        CollectionType.associationDues => 'Cotisation',
        CollectionType.custom => 'Personnalisé',
      };

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
