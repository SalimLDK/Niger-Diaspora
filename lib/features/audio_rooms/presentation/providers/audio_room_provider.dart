import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_room_notification_service.dart';
import '../../../../core/services/livekit_service.dart';
import '../../../admin/presentation/providers/app_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/audio_room_remote_datasource.dart';
import '../../data/models/audio_room_model.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../../domain/entities/participant_entity.dart';

/// Provider for AudioRoomRemoteDataSource
final audioRoomRemoteDataSourceProvider = Provider<AudioRoomRemoteDataSource>((
  ref,
) {
  return AudioRoomRemoteDataSourceImpl(
    databaseInstance: FirebaseDatabase.instance,
  );
});

/// Stream of live audio rooms
final liveAudioRoomsProvider = StreamProvider<List<AudioRoomEntity>>((ref) {
  return ref
      .watch(audioRoomRemoteDataSourceProvider)
      .getLiveRoomsStream()
      .map((rooms) => rooms.map((r) => r.toEntity()).toList());
});

/// Stream of scheduled audio rooms
final scheduledAudioRoomsProvider = StreamProvider<List<AudioRoomEntity>>((
  ref,
) {
  return ref
      .watch(audioRoomRemoteDataSourceProvider)
      .getScheduledRoomsStream()
      .map((rooms) => rooms.map((r) => r.toEntity()).toList());
});

/// Stream of a specific room
final audioRoomStreamProvider = StreamProvider.family<AudioRoomEntity?, String>(
  (ref, roomId) {
    return ref
        .watch(audioRoomRemoteDataSourceProvider)
        .getRoomStream(roomId)
        .map((room) => room?.toEntity());
  },
);

/// Stream of participants in a room
final roomParticipantsProvider =
    StreamProvider.family<List<ParticipantEntity>, String>((ref, roomId) {
      return ref
          .watch(audioRoomRemoteDataSourceProvider)
          .getParticipantsStream(roomId)
          .map(
            (participants) => participants.map((p) => p.toEntity()).toList(),
          );
    });

/// State for the current audio room session
class AudioRoomSessionState {
  final AudioRoomEntity? room;
  final List<ParticipantEntity> participants;
  final bool isJoining;
  final bool isLeaving;
  final bool isMuted;
  final bool isSpeaking;
  final bool isCameraOff;
  final bool isGhostMode;
  final String? error;

  const AudioRoomSessionState({
    this.room,
    this.participants = const [],
    this.isJoining = false,
    this.isLeaving = false,
    this.isMuted = true,
    this.isSpeaking = false,
    this.isCameraOff = true,
    this.isGhostMode = false,
    this.error,
  });

  AudioRoomSessionState copyWith({
    AudioRoomEntity? room,
    List<ParticipantEntity>? participants,
    bool? isJoining,
    bool? isLeaving,
    bool? isMuted,
    bool? isSpeaking,
    bool? isCameraOff,
    bool? isGhostMode,
    String? error,
  }) {
    return AudioRoomSessionState(
      room: room ?? this.room,
      participants: participants ?? this.participants,
      isJoining: isJoining ?? this.isJoining,
      isLeaving: isLeaving ?? this.isLeaving,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      error: error,
    );
  }

  /// Get speakers (host, co-hosts, and speakers)
  List<ParticipantEntity> get speakers =>
      participants
          .where(
            (p) =>
                p.role == ParticipantRole.host ||
                p.role == ParticipantRole.coHost ||
                p.role == ParticipantRole.speaker,
          )
          .toList();

  /// Get listeners
  List<ParticipantEntity> get listeners =>
      participants.where((p) => p.role == ParticipantRole.listener).toList();

  /// Get users with raised hands
  List<ParticipantEntity> get handRaised =>
      participants.where((p) => p.hasHandRaised).toList();

  /// Get visible speakers (excludes ghost moderators)
  List<ParticipantEntity> get visibleSpeakers =>
      speakers.where((p) => !p.isGhostMode).toList();

  /// Get visible listeners (excludes ghost moderators)
  List<ParticipantEntity> get visibleListeners =>
      listeners.where((p) => !p.isGhostMode).toList();
}

/// Provider for audio room session notifier (keepAlive)
final audioRoomSessionProvider =
    NotifierProvider<AudioRoomSessionNotifier, AudioRoomSessionState>(
      AudioRoomSessionNotifier.new,
    );

/// Notifier for managing audio room session
class AudioRoomSessionNotifier extends Notifier<AudioRoomSessionState> {
  StreamSubscription? _roomSubscription;
  StreamSubscription? _participantsSubscription;

  // Mutex flags to prevent race conditions
  bool _isJoinInProgress = false;
  bool _isLeaveInProgress = false;
  bool _isDisposed = false;
  String? _currentRoomId;

  @override
  AudioRoomSessionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _cleanupSubscriptions();
    });
    return const AudioRoomSessionState();
  }

  void _cleanupSubscriptions() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _participantsSubscription?.cancel();
    _participantsSubscription = null;
  }

  /// Create a new audio room
  Future<AudioRoomEntity?> createRoom({
    required String title,
    String? description,
    bool isPrivate = false,
    bool isRecordingEnabled = false,
    bool isVideoEnabled = false,
    bool isPaid = false,
    int? ticketPrice,
    String? ticketCurrency,
    List<String> tags = const [],
    DateTime? scheduledAt,
    // Diaspora-specific fields
    AudioRoomCategory category = AudioRoomCategory.general,
    AudioRoomMode mode = AudioRoomMode.normal,
    String? linkedEventId,
    String? linkedGroupId,
    String? linkedEmbassyId,
    CollectionType collectionType = CollectionType.none,
    int? collectionGoal,
    String? collectionDescription,
    String? collectionBeneficiary,
    bool isHeritageContent = false,
    String? heritageLanguage,
    String? heritageRegion,
    List<String>? displayTimezones,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Get admin settings for validation
    final settings = ref.read(appSettingsNotifierProvider).valueOrNull;
    final audioSettings = settings?.audioRooms;

    // Validate feature flags
    if (isPaid && !(audioSettings?.allowPaidRooms ?? true)) {
      state = state.copyWith(error: 'Les salons payants ne sont pas autorisés');
      return null;
    }

    if (collectionType != CollectionType.none &&
        !(audioSettings?.allowCollections ?? true)) {
      state = state.copyWith(error: 'Les collectes ne sont pas autorisées');
      return null;
    }

    if (isRecordingEnabled && !(audioSettings?.allowRecording ?? true)) {
      state = state.copyWith(error: 'L\'enregistrement n\'est pas autorisé');
      return null;
    }

    if (isHeritageContent && !(audioSettings?.allowHeritageContent ?? true)) {
      state = state.copyWith(
        error: 'Le contenu patrimonial n\'est pas autorisé',
      );
      return null;
    }

    // Validate ticket price limits
    if (isPaid && ticketPrice != null) {
      final minTicketPrice = audioSettings?.minTicketPrice ?? 500;
      final maxTicketPrice = audioSettings?.maxTicketPrice ?? 10000000;
      if (ticketPrice < minTicketPrice) {
        state = state.copyWith(
          error: 'Le prix minimum du ticket est ${minTicketPrice ~/ 100} XOF',
        );
        return null;
      }
      if (ticketPrice > maxTicketPrice) {
        state = state.copyWith(
          error: 'Le prix maximum du ticket est ${maxTicketPrice ~/ 100} XOF',
        );
        return null;
      }
    }

    // Validate collection goal limits
    if (collectionType != CollectionType.none && collectionGoal != null) {
      final minCollectionGoal = audioSettings?.minCollectionGoal ?? 1000;
      final maxCollectionGoal = audioSettings?.maxCollectionGoal ?? 100000000;
      if (collectionGoal < minCollectionGoal) {
        state = state.copyWith(
          error:
              'L\'objectif minimum de collecte est ${minCollectionGoal ~/ 100} XOF',
        );
        return null;
      }
      if (collectionGoal > maxCollectionGoal) {
        state = state.copyWith(
          error:
              'L\'objectif maximum de collecte est ${maxCollectionGoal ~/ 100} XOF',
        );
        return null;
      }
    }

    try {
      final roomModel = AudioRoomModel(
        id: '',
        title: title,
        description: description,
        hostId: currentUser.id,
        hostName: currentUser.displayName ?? 'Utilisateur',
        hostPhotoUrl: currentUser.photoUrl,
        status: scheduledAt != null ? 'scheduled' : 'live',
        scheduledAt: scheduledAt?.toIso8601String(),
        startedAt:
            scheduledAt == null ? DateTime.now().toIso8601String() : null,
        createdAt: DateTime.now().toIso8601String(),
        isPrivate: isPrivate,
        isRecordingEnabled: isRecordingEnabled,
        isVideoEnabled: isVideoEnabled,
        isPaid: isPaid,
        ticketPrice: ticketPrice,
        ticketCurrency: ticketCurrency,
        tags: tags,
        // Diaspora-specific fields
        category: category.name,
        mode: mode.name,
        linkedEventId: linkedEventId,
        linkedGroupId: linkedGroupId,
        linkedEmbassyId: linkedEmbassyId,
        collectionType: collectionType.name,
        collectionGoal: collectionGoal,
        collectionDescription: collectionDescription,
        collectionBeneficiary: collectionBeneficiary,
        isHeritageContent: isHeritageContent,
        heritageLanguage: heritageLanguage,
        heritageRegion: heritageRegion,
        displayTimezones:
            displayTimezones ??
            const ['Africa/Niamey', 'Europe/Paris', 'America/New_York'],
      );

      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      final createdRoom = await dataSource.createRoom(roomModel);
      final roomEntity = createdRoom.toEntity();

      // Auto-join the room as host (unless it's scheduled for later)
      if (scheduledAt == null) {
        await _joinRoom(
          roomEntity.id,
          isHost: true,
          isVideoEnabled: isVideoEnabled,
        );
      }

      return roomEntity;
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de la création: $e');
      return null;
    }
  }

  /// Join an existing room
  Future<bool> joinRoom(String roomId) async {
    // Prevent concurrent join attempts
    if (_isJoinInProgress || _isDisposed) {
      return false;
    }

    // Prevent joining if already in another room
    if (_currentRoomId != null && _currentRoomId != roomId) {
      await leaveRoom();
    }

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    _isJoinInProgress = true;
    state = state.copyWith(isJoining: true, error: null);

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);

      // Check if room exists and is joinable
      final room = await dataSource.getRoom(roomId);
      if (room == null) {
        _isJoinInProgress = false;
        state = state.copyWith(isJoining: false, error: 'Salon introuvable');
        return false;
      }

      final roomEntity = room.toEntity();

      // Check if blocked
      if (roomEntity.isBlocked(currentUser.id)) {
        _isJoinInProgress = false;
        state = state.copyWith(
          isJoining: false,
          error: 'Vous êtes bloqué de ce salon',
        );
        return false;
      }

      // Check if room is full
      if (roomEntity.isAtListenerCapacity) {
        _isJoinInProgress = false;
        state = state.copyWith(isJoining: false, error: 'Salon complet');
        return false;
      }

      final result = await _joinRoom(
        roomId,
        isHost: false,
        isVideoEnabled: roomEntity.isVideoEnabled,
      );
      if (result) {
        _currentRoomId = roomId;
      }
      _isJoinInProgress = false;
      return result;
    } catch (e) {
      _isJoinInProgress = false;
      state = state.copyWith(
        isJoining: false,
        error: 'Erreur lors de la connexion: $e',
      );
      return false;
    }
  }

  Future<bool> _joinRoom(
    String roomId, {
    required bool isHost,
    bool isVideoEnabled = false,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);

      if (!isHost) {
        await dataSource.joinAsListener(roomId, currentUser.id);
      }

      // Connect to LiveKit SFU for video-enabled rooms
      if (isVideoEnabled) {
        _connectToLiveKit(roomId, currentUser.displayName ?? currentUser.id);
      }

      // Subscribe to room updates
      _roomSubscription?.cancel();
      _roomSubscription = dataSource.getRoomStream(roomId).listen((roomModel) {
        if (roomModel != null) {
          final roomEntity = roomModel.toEntity();
          state = state.copyWith(room: roomEntity);

          // Update notification with latest room info
          if (AudioRoomNotificationService().isShowing) {
            AudioRoomNotificationService().show(
              roomId: roomEntity.id,
              roomTitle: roomEntity.title,
              hostName: roomEntity.hostName,
              participantCount: roomEntity.totalParticipants,
              speakerCount: roomEntity.speakerCount,
              isMuted: state.isMuted,
            );
          }
        } else {
          // Room was deleted
          leaveRoom();
        }
      });

      // Subscribe to participants
      _participantsSubscription?.cancel();
      _participantsSubscription = dataSource
          .getParticipantsStream(roomId)
          .listen((participants) {
            final participantList = participants.map((p) => p.toEntity()).toList();
            state = state.copyWith(participants: participantList);

            // Update notification participant count
            if (AudioRoomNotificationService().isShowing && state.room != null) {
              AudioRoomNotificationService().updateParticipants(
                participantList.length,
              );
            }
          });

      // Show ongoing notification
      final room = state.room;
      if (room != null) {
        AudioRoomNotificationService().show(
          roomId: room.id,
          roomTitle: room.title,
          hostName: room.hostName,
          participantCount: room.totalParticipants,
          speakerCount: room.speakerCount,
          isMuted: state.isMuted,
        );
      }

      state = state.copyWith(isJoining: false);
      return true;
    } catch (e) {
      state = state.copyWith(isJoining: false, error: 'Erreur: $e');
      return false;
    }
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    // Prevent concurrent leave attempts
    if (_isLeaveInProgress) {
      return;
    }

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;

    _isLeaveInProgress = true;

    // Don't update state if disposed
    if (!_isDisposed) {
      state = state.copyWith(isLeaving: true);
    }

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);

      // If host, end the room
      if (room.isHost(currentUser.id)) {
        await dataSource.endRoom(room.id);
      } else {
        await dataSource.leaveRoom(room.id, currentUser.id);
      }

      _cleanupSubscriptions();
      _currentRoomId = null;

      // Disconnect from LiveKit SFU if connected
      if (LiveKitService.instance.isConnected) {
        await LiveKitService.instance.leaveRoom();
      }

      // Dismiss ongoing notification
      AudioRoomNotificationService().dismiss();

      // Don't update state if disposed
      if (!_isDisposed) {
        state = const AudioRoomSessionState();
      }
    } catch (e) {
      // Don't update state if disposed
      if (!_isDisposed) {
        state = state.copyWith(isLeaving: false, error: 'Erreur: $e');
      }
    } finally {
      _isLeaveInProgress = false;
    }
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;

    final newMuteState = !state.isMuted;
    state = state.copyWith(isMuted: newMuteState);

    // Update notification mute state
    AudioRoomNotificationService().updateMuteState(newMuteState);

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.updateMuteState(room.id, currentUser.id, newMuteState);
    } catch (e) {
      // Revert on error
      state = state.copyWith(isMuted: !newMuteState);
    }
  }

  /// Raise hand to speak
  Future<void> raiseHand() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.raiseHand(room.id, currentUser.id);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Lower hand
  Future<void> lowerHand() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.lowerHand(room.id, currentUser.id);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Promote a user to speaker (host/co-host only)
  Future<void> promoteToSpeaker(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.canModerate(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.promoteToSpeaker(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Demote a speaker to listener (host/co-host only)
  Future<void> demoteToListener(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.canModerate(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.demoteToListener(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Add a co-host (host only)
  Future<void> addCoHost(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.isHost(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.addCoHost(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Mute a speaker (host/co-host only)
  Future<void> muteSpeaker(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.canModerate(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.muteSpeaker(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Kick a user from the room (host/co-host only)
  Future<void> kickUser(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.canModerate(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.kickUser(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Block a user from the room (host/co-host only)
  Future<void> blockUser(String userId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.canModerate(currentUser.id)) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.blockUser(room.id, userId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Toggle camera on/off (for video-enabled rooms)
  Future<void> toggleCamera() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!room.isVideoEnabled) return;

    final newCameraState = !state.isCameraOff;
    state = state.copyWith(isCameraOff: newCameraState);

    try {
      // Toggle LiveKit camera track (SFU)
      await LiveKitService.instance.toggleCamera();

      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.updateCameraState(
        room.id,
        currentUser.id,
        !newCameraState,
      );
    } catch (e) {
      // Revert on error
      state = state.copyWith(isCameraOff: !newCameraState);
    }
  }

  /// Join room as invisible ghost moderator (admin only)
  Future<bool> joinAsGhostModerator(String roomId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    // Check if user is admin
    if (!currentUser.isAdmin) {
      state = state.copyWith(error: 'Accès non autorisé');
      return false;
    }

    state = state.copyWith(isJoining: true, isGhostMode: true, error: null);

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);

      // Check if room exists
      final room = await dataSource.getRoom(roomId);
      if (room == null) {
        state = state.copyWith(
          isJoining: false,
          isGhostMode: false,
          error: 'Salon introuvable',
        );
        return false;
      }

      // Join as ghost moderator (invisible)
      await dataSource.joinAsGhostModerator(roomId, currentUser.id);

      // Subscribe to room updates
      _roomSubscription?.cancel();
      _roomSubscription = dataSource.getRoomStream(roomId).listen((roomModel) {
        if (roomModel != null) {
          state = state.copyWith(room: roomModel.toEntity());
        } else {
          leaveRoom();
        }
      });

      // Subscribe to participants
      _participantsSubscription?.cancel();
      _participantsSubscription = dataSource
          .getParticipantsStream(roomId)
          .listen((participants) {
            state = state.copyWith(
              participants: participants.map((p) => p.toEntity()).toList(),
            );
          });

      state = state.copyWith(isJoining: false, isMuted: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isJoining: false,
        isGhostMode: false,
        error: 'Erreur: $e',
      );
      return false;
    }
  }

  /// Fetch a LiveKit token and connect to the SFU room (fire-and-forget).
  /// Errors are logged but do not affect the Firestore/RTDB session.
  void _connectToLiveKit(String roomId, String participantName) {
    Future(() async {
      try {
        final callable = FirebaseFunctions.instance
            .httpsCallable('getAudioRoomLiveKitToken');
        final result = await callable.call<Map<dynamic, dynamic>>({
          'roomId': roomId,
          'participantName': participantName,
        });
        final token = result.data['token'] as String?;
        if (token == null) return;
        final livekitRoomName = result.data['livekitRoomName'] as String? ??
            'audio-room-$roomId';
        // E2EE key optionally returned by the Cloud Function
        final e2eeKey = result.data['e2eeKey'] as String?;
        await LiveKitService.instance.joinRoomWithToken(
          roomName: livekitRoomName,
          token: token,
          participantName: participantName,
          e2eeKey: e2eeKey,
        );
      } catch (e) {
        debugPrint('AudioRoom: LiveKit connect failed (non-fatal): $e');
        if (!_isDisposed) {
          state = state.copyWith(
            error: 'Connexion audio partielle — certains participants peuvent ne pas vous entendre',
          );
        }
      }
    });
  }

  /// Force end a room (admin/moderator only)
  Future<void> forceEndRoom(String reason) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!state.isGhostMode && !currentUser.isAdmin) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.forceEndRoom(room.id, reason);
      await leaveRoom();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Warn the host (admin/moderator only)
  Future<void> warnHost(String message) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final room = state.room;

    if (currentUser == null || room == null) return;
    if (!state.isGhostMode && !currentUser.isAdmin) return;

    try {
      final dataSource = ref.read(audioRoomRemoteDataSourceProvider);
      await dataSource.warnHost(room.id, message);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }
}

/// Provider to check if user is currently in a room
final isInAudioRoomProvider = Provider<bool>((ref) {
  final session = ref.watch(audioRoomSessionProvider);
  return session.room != null;
});

/// Provider to get the current room ID
final currentAudioRoomIdProvider = Provider<String?>((ref) {
  final session = ref.watch(audioRoomSessionProvider);
  return session.room?.id;
});

