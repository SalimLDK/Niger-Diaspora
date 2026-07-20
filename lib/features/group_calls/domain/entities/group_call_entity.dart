import 'package:equatable/equatable.dart';

/// Mode of the group call
enum GroupCallMode {
  /// Mesh topology - each participant connects to all others (2-4 participants)
  mesh,

  /// SFU topology - all participants connect to a central server (5+ participants)
  sfu,
}

/// Status of a group call
enum GroupCallStatus {
  /// Call is being set up, waiting for participants
  waiting,

  /// Call is active with participants connected
  active,

  /// Call has ended
  ended,
}

/// Type of group call
enum GroupCallType {
  /// Audio only call
  audio,

  /// Video call
  video,
}

/// Entity representing a group call with multiple participants
class GroupCallEntity extends Equatable {
  /// Unique identifier for the call
  final String id;

  /// Display name of the call (e.g., "Call with Alice, Bob")
  final String name;

  /// ID of the user who initiated the call
  final String hostId;

  /// Display name of the host
  final String hostName;

  /// Photo URL of the host
  final String? hostPhotoUrl;

  /// List of participant user IDs (includes host)
  final List<String> participantIds;

  /// Current number of active participants
  final int participantCount;

  /// Maximum number of participants allowed
  final int maxParticipants;

  /// Type of call (audio or video)
  final GroupCallType type;

  /// Current status of the call
  final GroupCallStatus status;

  /// Mode of the call (mesh or SFU)
  final GroupCallMode mode;

  /// Whether E2EE is enabled for this call
  final bool isE2EEEnabled;

  /// E2EE key ID (for verification)
  final String? e2eeKeyId;

  /// When the call was created
  final DateTime createdAt;

  /// When the call actually started (first participant joined)
  final DateTime? startedAt;

  /// When the call ended
  final DateTime? endedAt;

  /// Duration of the call in seconds (null if not ended)
  final int? durationSeconds;

  /// LiveKit room name (for SFU mode)
  final String? livekitRoomName;

  /// Group ID if this is a group conversation call
  final String? groupId;

  /// Conversation ID if this call is part of a conversation
  final String? conversationId;

  const GroupCallEntity({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    required this.participantIds,
    this.participantCount = 0,
    this.maxParticipants = 10,
    required this.type,
    required this.status,
    required this.mode,
    this.isE2EEEnabled = true,
    this.e2eeKeyId,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.livekitRoomName,
    this.groupId,
    this.conversationId,
  });

  /// Whether this is a mesh call (2-4 participants)
  bool get isMeshCall => mode == GroupCallMode.mesh;

  /// Whether this is an SFU call (5+ participants)
  bool get isSfuCall => mode == GroupCallMode.sfu;

  /// Whether the call is currently active
  bool get isActive => status == GroupCallStatus.active;

  /// Whether the call has ended
  bool get hasEnded => status == GroupCallStatus.ended;

  /// Whether the call is waiting for participants
  bool get isWaiting => status == GroupCallStatus.waiting;

  /// Check if a user is the host
  bool isHost(String oderId) => hostId == oderId;

  /// Check if a user is a participant
  bool isParticipant(String oderId) => participantIds.contains(oderId);

  /// Whether more participants can join
  bool get canAddMoreParticipants => participantCount < maxParticipants;

  /// Whether the call should switch from mesh to SFU
  bool get shouldSwitchToSfu =>
      mode == GroupCallMode.mesh && participantIds.length > 4;

  /// Format duration as mm:ss or hh:mm:ss
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) {
      return '00:00';
    }

    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Copy with new values
  GroupCallEntity copyWith({
    String? id,
    String? name,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? participantIds,
    int? participantCount,
    int? maxParticipants,
    GroupCallType? type,
    GroupCallStatus? status,
    GroupCallMode? mode,
    bool? isE2EEEnabled,
    String? e2eeKeyId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? livekitRoomName,
    String? groupId,
    String? conversationId,
  }) {
    return GroupCallEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      participantIds: participantIds ?? this.participantIds,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      type: type ?? this.type,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      isE2EEEnabled: isE2EEEnabled ?? this.isE2EEEnabled,
      e2eeKeyId: e2eeKeyId ?? this.e2eeKeyId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
      groupId: groupId ?? this.groupId,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        hostId,
        participantIds,
        participantCount,
        type,
        status,
        mode,
        isE2EEEnabled,
        createdAt,
        startedAt,
        endedAt,
      ];
}
