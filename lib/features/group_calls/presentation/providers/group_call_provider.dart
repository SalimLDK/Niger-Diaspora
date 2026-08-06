import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/e2ee_service.dart';
import '../../../../core/services/group_call_service.dart';
import '../../../../core/services/livekit_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/group_call_model.dart';
import '../../domain/entities/group_call_entity.dart';
import '../../domain/entities/group_participant_entity.dart';
import '../../../calls/domain/entities/call_entity.dart';

/// Threshold for switching from mesh to SFU
const int meshToSfuThreshold = 5;

/// Provider for GroupCallService (mesh)
final groupCallServiceProvider = Provider<GroupCallService>((ref) {
  return GroupCallService.instance;
});

/// Provider for LiveKitService (SFU)
final liveKitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService.instance;
});

/// Provider for E2EEService
final e2eeServiceProvider = Provider<E2EEService>((ref) {
  return E2EEService.instance;
});

/// Determine call mode based on participant count
GroupCallMode determineCallMode(int participantCount) {
  return participantCount < meshToSfuThreshold
      ? GroupCallMode.mesh
      : GroupCallMode.sfu;
}

/// State for the current group call
class GroupCallState {
  final GroupCallEntity? call;
  final List<GroupParticipantEntity> participants;
  final GroupCallMode mode;
  final GroupCallStatus status;
  final bool isJoining;
  final bool isConnected;
  final bool isLeaving;
  final bool isMuted;
  final bool isCameraOff;
  final bool isScreenSharing;
  final bool isVideo;
  final bool isE2EEEnabled;
  final String? e2eeVerificationCode;
  final Set<String> speakingParticipantIds;
  final Duration? duration;
  final String? error;
  final Map<String, MediaStream> remoteStreams;
  final GroupParticipantEntity? localParticipant;

  const GroupCallState({
    this.call,
    this.participants = const [],
    this.mode = GroupCallMode.mesh,
    this.status = GroupCallStatus.waiting,
    this.isJoining = false,
    this.isConnected = false,
    this.isLeaving = false,
    this.isMuted = false,
    this.isCameraOff = true,
    this.isScreenSharing = false,
    this.isVideo = false,
    this.isE2EEEnabled = true,
    this.e2eeVerificationCode,
    this.speakingParticipantIds = const {},
    this.duration,
    this.error,
    this.remoteStreams = const {},
    this.localParticipant,
  });

  GroupCallState copyWith({
    GroupCallEntity? call,
    List<GroupParticipantEntity>? participants,
    GroupCallMode? mode,
    GroupCallStatus? status,
    bool? isJoining,
    bool? isConnected,
    bool? isLeaving,
    bool? isMuted,
    bool? isCameraOff,
    bool? isScreenSharing,
    bool? isVideo,
    bool? isE2EEEnabled,
    String? e2eeVerificationCode,
    Set<String>? speakingParticipantIds,
    Duration? duration,
    String? error,
    Map<String, MediaStream>? remoteStreams,
    GroupParticipantEntity? localParticipant,
  }) {
    return GroupCallState(
      call: call ?? this.call,
      participants: participants ?? this.participants,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      isJoining: isJoining ?? this.isJoining,
      isConnected: isConnected ?? this.isConnected,
      isLeaving: isLeaving ?? this.isLeaving,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isVideo: isVideo ?? this.isVideo,
      isE2EEEnabled: isE2EEEnabled ?? this.isE2EEEnabled,
      e2eeVerificationCode: e2eeVerificationCode ?? this.e2eeVerificationCode,
      speakingParticipantIds:
          speakingParticipantIds ?? this.speakingParticipantIds,
      duration: duration ?? this.duration,
      error: error,
      remoteStreams: remoteStreams ?? this.remoteStreams,
      localParticipant: localParticipant ?? this.localParticipant,
    );
  }

  /// Get active (connected) participants
  List<GroupParticipantEntity> get activeParticipants =>
      participants.where((p) => p.isConnected && !p.hasLeft).toList();

  /// Get the current speaking participants
  List<GroupParticipantEntity> get speakingParticipants =>
      participants.where((p) => p.isSpeaking).toList();
}

/// Provider for current group call notifier (keepAlive)
final currentGroupCallProvider =
    NotifierProvider<CurrentGroupCallNotifier, GroupCallState>(
      CurrentGroupCallNotifier.new,
    );

/// Notifier for managing group calls
class CurrentGroupCallNotifier extends Notifier<GroupCallState> {
  Timer? _durationTimer;
  DateTime? _callStartTime;
  StreamSubscription? _callSubscription;
  StreamSubscription? _participantsSubscription;
  StreamSubscription<Set<String>>? _speakingSubscription;

  // Firestore and RTDB references
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance;

  @override
  GroupCallState build() {
    ref.onDispose(() {
      _durationTimer?.cancel();
      _callSubscription?.cancel();
      _participantsSubscription?.cancel();
      _speakingSubscription?.cancel();
    });

    // `speakingParticipantIds` était déclaré dans l'état, lu par
    // `group_call_screen` pour la bordure « parle en ce moment », mais jamais
    // alimenté : le set restait vide en permanence. LiveKit publie déjà
    // l'information, il suffisait de s'y abonner.
    //
    // NB : seul le mode SFU passe par LiveKit. En mesh (< 5 participants) le
    // flux n'émet rien et le set reste vide — la détection d'orateur actif
    // n'existe pas côté flutter_webrtc.
    _speakingSubscription = LiveKitService.instance.speakingParticipantsStream
        .listen((ids) => state = state.copyWith(speakingParticipantIds: ids));

    return const GroupCallState();
  }

  /// Create and start a new group call
  Future<GroupCallEntity?> createGroupCall({
    required String name,
    required List<String> participantIds,
    required GroupCallType type,
    bool enableE2EE = true,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Ensure current user is in participant list
    final allParticipantIds = {currentUser.id, ...participantIds}.toList();

    // Determine mode based on participant count
    final mode = determineCallMode(allParticipantIds.length);

    state = state.copyWith(isJoining: true, error: null, mode: mode);

    try {
      // Create call document in Firestore
      final callModel = GroupCallModel(
        id: '',
        name: name,
        hostId: currentUser.id,
        hostName: currentUser.displayName ?? 'Utilisateur',
        hostPhotoUrl: currentUser.photoUrl,
        participantIds: allParticipantIds,
        participantCount: 1, // Just the host initially
        type: type.name,
        status: 'waiting',
        mode: mode.name,
        isE2EEEnabled: enableE2EE,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      final docRef = await _firestore
          .collection('group_calls')
          .add(callModel.toFirestore());

      final callEntity = callModel.copyWith(id: docRef.id).toEntity();

      state = state.copyWith(call: callEntity, isE2EEEnabled: enableE2EE);

      // Join the call based on mode
      await _joinCallInternal(
        callEntity: callEntity,
        oderId: currentUser.id,
        displayName: currentUser.displayName ?? 'Utilisateur',
        enableVideo: type == GroupCallType.video,
        enableE2EE: enableE2EE,
      );

      return callEntity;
    } catch (e) {
      debugPrint('GroupCallProvider: Error creating call: $e');
      state = state.copyWith(isJoining: false, error: 'Erreur: $e');
      return null;
    }
  }

  /// Create a group call from an existing 1:1 call (conversion)
  ///
  /// This method is used when a user wants to add more participants to a 1:1 call.
  /// It creates a new group call and reuses the existing media stream.
  ///
  /// [originalCall] - The original 1:1 call being converted
  /// [additionalParticipantIds] - IDs of new participants to add
  /// [existingLocalStream] - The local media stream from the 1:1 call
  Future<GroupCallEntity?> createFromOneToOneCall({
    required CallEntity originalCall,
    required List<String> additionalParticipantIds,
    required MediaStream existingLocalStream,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Build the participant list: original caller + callee + new participants
    final allParticipantIds = <String>{
      originalCall.callerId,
      originalCall.calleeId,
      ...additionalParticipantIds,
    }.toList();

    // Determine mode based on participant count
    final mode = determineCallMode(allParticipantIds.length);

    // Determine call type from original call
    final callType = originalCall.type == CallType.video
        ? GroupCallType.video
        : GroupCallType.audio;

    state = state.copyWith(
      isJoining: true,
      error: null,
      mode: mode,
      isVideo: callType == GroupCallType.video,
    );

    try {
      debugPrint(
        'GroupCallProvider: Creating group call from 1:1 call ${originalCall.id}',
      );
      debugPrint(
        'GroupCallProvider: Participants: $allParticipantIds',
      );

      // Create call document in Firestore
      final callModel = GroupCallModel(
        id: '',
        name: 'Appel de groupe', // Could use participant names
        hostId: currentUser.id,
        hostName: currentUser.displayName ?? 'Utilisateur',
        hostPhotoUrl: currentUser.photoUrl,
        participantIds: allParticipantIds,
        participantCount: 2, // Start with 2 (original participants)
        type: callType.name,
        status: 'active',
        mode: mode.name,
        isE2EEEnabled: true,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      final docRef = await _firestore
          .collection('group_calls')
          .add(callModel.toFirestore());

      final callEntity = callModel.copyWith(id: docRef.id).toEntity();

      state = state.copyWith(call: callEntity, isE2EEEnabled: true);

      // Join the call with existing stream (mesh only for now)
      if (mode == GroupCallMode.mesh) {
        await _joinMeshCallWithExistingStream(
          callEntity: callEntity,
          userId: currentUser.id,
          existingLocalStream: existingLocalStream,
          enableE2EE: true,
        );
      } else {
        // For SFU, we need to handle differently (future enhancement)
        await _joinSfuCall(
          callEntity: callEntity,
          displayName: currentUser.displayName ?? 'Utilisateur',
          enableVideo: callType == GroupCallType.video,
          enableE2EE: true,
        );
      }

      // Register current user as participant
      await _firestore
          .collection('group_calls')
          .doc(callEntity.id)
          .collection('participants')
          .doc(currentUser.id)
          .set({
            'displayName': currentUser.displayName ?? 'Utilisateur',
            'photoUrl': currentUser.photoUrl,
            'role': 'host',
            'isMuted': false,
            'isCameraOff': callType != GroupCallType.video,
            'joinedAt': FieldValue.serverTimestamp(),
          });

      // Subscribe to call updates
      _subscribeToCallUpdates(callEntity.id);

      // Start duration timer
      _startDurationTimer();

      state = state.copyWith(
        isJoining: false,
        isConnected: true,
        isCameraOff: callType != GroupCallType.video,
      );

      // Send invitations to new participants (via FCM)
      await _sendCallInvitations(
        callId: callEntity.id,
        participantIds: additionalParticipantIds,
        callerName: currentUser.displayName ?? 'Utilisateur',
        callerPhotoUrl: currentUser.photoUrl,
        isVideo: callType == GroupCallType.video,
      );

      debugPrint(
        'GroupCallProvider: Successfully created group call ${callEntity.id} from 1:1 call',
      );

      return callEntity;
    } catch (e) {
      debugPrint('GroupCallProvider: Error creating group call from 1:1: $e');
      state = state.copyWith(isJoining: false, error: 'Erreur: $e');
      return null;
    }
  }

  /// Join mesh call reusing an existing local stream (for 1:1 conversion)
  Future<void> _joinMeshCallWithExistingStream({
    required GroupCallEntity callEntity,
    required String userId,
    required MediaStream existingLocalStream,
    required bool enableE2EE,
  }) async {
    final meshService = ref.read(groupCallServiceProvider);

    await meshService.joinCallWithExistingStream(
      callId: callEntity.id,
      userId: userId,
      participantIds: callEntity.participantIds,
      existingLocalStream: existingLocalStream,
      enableE2EE: enableE2EE,
      onRemoteStream: (participantId, stream) {
        final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
        newStreams[participantId] = stream;
        state = state.copyWith(remoteStreams: newStreams);
      },
      onParticipantJoined: (participantId) {
        debugPrint('Participant joined: $participantId');
      },
      onParticipantLeft: (participantId) {
        debugPrint('GroupCallProvider: Participant left: $participantId');
        final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
        newStreams.remove(participantId);
        state = state.copyWith(remoteStreams: newStreams);

        if (newStreams.isEmpty && state.isConnected && !state.isLeaving) {
          _endCallAsLastParticipant();
        }
      },
    );
  }

  /// Send call invitations to participants via FCM
  /// Creates notification documents that trigger Cloud Function sendNotificationOnCreate
  Future<void> _sendCallInvitations({
    required String callId,
    required List<String> participantIds,
    required String callerName,
    required String? callerPhotoUrl,
    required bool isVideo,
  }) async {
    final currentUserId = (await ref.read(currentUserAsyncProvider.future))?.id;
    if (currentUserId == null) return;

    // Filter out the caller from recipients
    final recipients = participantIds.where((id) => id != currentUserId).toList();

    debugPrint(
      'GroupCallProvider: Sending group call invitations to ${recipients.length} participants',
    );

    // Une notification par participant.
    //
    // Écrites dans Supabase, pas dans Firestore : c'est Supabase que lit
    // l'écran des notifications. Ce lot Firestore déposait les invitations
    // dans une collection que plus personne n'affiche — l'invitation à un
    // appel de groupe n'apparaissait donc jamais dans la liste.
    //
    // La RPC est `SECURITY DEFINER` : elle autorise l'écriture d'une
    // notification destinée à quelqu'un d'autre, que la RLS refuserait.
    // Il n'y a pas d'équivalent du lot Firestore, mais l'échec d'une
    // invitation ne doit pas empêcher les suivantes : chacune est isolée.
    final supabase = Supabase.instance.client;
    for (final recipientId in recipients) {
      try {
        await supabase.rpc(
          'create_user_notification',
          params: {
            'p_user_id': recipientId,
            'p_type': 'groupCallInvitation',
            'p_title': callerName,
            'p_body': isVideo
                ? 'Vous invite à un appel vidéo de groupe'
                : 'Vous invite à un appel vocal de groupe',
            'p_data': {
              'targetId': callId,
              'callId': callId,
              'callerId': currentUserId,
              'callerName': callerName,
              'callerPhotoUrl': callerPhotoUrl ?? '',
              'callType': isVideo ? 'video' : 'audio',
            },
          },
        );
      } catch (e) {
        debugPrint('GroupCall: notification a $recipientId echouee : $e');
      }
    }

    debugPrint(
      'GroupCallProvider: ${recipients.length} invitations envoyees',
    );
  }

  /// Join an existing group call
  Future<bool> joinGroupCall({
    required String callId,
    bool enableVideo = false,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    state = state.copyWith(isJoining: true, error: null);

    try {
      // Get call from Firestore
      final doc = await _firestore.collection('group_calls').doc(callId).get();
      if (!doc.exists) {
        state = state.copyWith(isJoining: false, error: 'Appel introuvable');
        return false;
      }

      final callEntity = GroupCallModel.fromFirestore(doc).toEntity();

      // Check if call is still active
      if (callEntity.hasEnded) {
        state = state.copyWith(isJoining: false, error: 'Appel terminé');
        return false;
      }

      // Check if call is full
      if (!callEntity.canAddMoreParticipants) {
        state = state.copyWith(isJoining: false, error: 'Appel complet');
        return false;
      }

      state = state.copyWith(
        call: callEntity,
        mode: callEntity.mode,
        isE2EEEnabled: callEntity.isE2EEEnabled,
      );

      // Add user to participant list
      await _firestore.collection('group_calls').doc(callId).update({
        'participantIds': FieldValue.arrayUnion([currentUser.id]),
        'participantCount': FieldValue.increment(1),
      });

      // Join the call
      await _joinCallInternal(
        callEntity: callEntity,
        oderId: currentUser.id,
        displayName: currentUser.displayName ?? 'Utilisateur',
        enableVideo: enableVideo || callEntity.type == GroupCallType.video,
        enableE2EE: callEntity.isE2EEEnabled,
      );

      return true;
    } catch (e) {
      debugPrint('GroupCallProvider: Error joining call: $e');
      state = state.copyWith(isJoining: false, error: 'Erreur: $e');
      return false;
    }
  }

  /// Internal method to join call based on mode
  Future<void> _joinCallInternal({
    required GroupCallEntity callEntity,
    required String oderId,
    required String displayName,
    required bool enableVideo,
    required bool enableE2EE,
  }) async {
    if (callEntity.isMeshCall) {
      await _joinMeshCall(
        callEntity: callEntity,
        oderId: oderId,
        enableVideo: enableVideo,
        enableE2EE: enableE2EE,
      );
    } else {
      await _joinSfuCall(
        callEntity: callEntity,
        displayName: displayName,
        enableVideo: enableVideo,
        enableE2EE: enableE2EE,
      );
    }

    // Subscribe to call updates
    _subscribeToCallUpdates(callEntity.id);

    // Start duration timer
    _startDurationTimer();

    state = state.copyWith(
      isJoining: false,
      isConnected: true,
      isCameraOff: !enableVideo,
    );

    // Get E2EE verification code
    if (enableE2EE) {
      final code =
          await ref.read(e2eeServiceProvider).generateVerificationCode();
      state = state.copyWith(e2eeVerificationCode: code);
    }
  }

  /// Join using mesh topology (WebRTC peer-to-peer)
  Future<void> _joinMeshCall({
    required GroupCallEntity callEntity,
    required String oderId,
    required bool enableVideo,
    required bool enableE2EE,
  }) async {
    final meshService = ref.read(groupCallServiceProvider);

    await meshService.joinCall(
      callId: callEntity.id,
      oderId: oderId,
      participantIds: callEntity.participantIds,
      enableVideo: enableVideo,
      enableE2EE: enableE2EE,
      onRemoteStream: (participantId, stream) {
        final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
        newStreams[participantId] = stream;
        state = state.copyWith(remoteStreams: newStreams);
      },
      onParticipantJoined: (participantId) {
        debugPrint('Participant joined: $participantId');
        // Participant list is updated via Firestore subscription
      },
      onParticipantLeft: (participantId) {
        debugPrint('GroupCallProvider: Participant left: $participantId');
        final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
        newStreams.remove(participantId);
        state = state.copyWith(remoteStreams: newStreams);

        // Check if we're now alone (no more remote streams = no other participants)
        if (newStreams.isEmpty && state.isConnected && !state.isLeaving) {
          debugPrint('GroupCallProvider: No more remote streams, checking if alone');
          _endCallAsLastParticipant();
        }
      },
    );
  }

  /// Join using SFU topology (LiveKit)
  Future<void> _joinSfuCall({
    required GroupCallEntity callEntity,
    required String displayName,
    required bool enableVideo,
    required bool enableE2EE,
  }) async {
    final liveKitService = ref.read(liveKitServiceProvider);

    await liveKitService.joinRoom(
      roomName: callEntity.livekitRoomName ?? callEntity.id,
      participantName: displayName,
      enableVideo: enableVideo,
      enableSimulcast: true,
      enableE2EE: enableE2EE,
      onDisconnected: () {
        leaveCall(reason: 'disconnected');
      },
    );
  }

  /// Subscribe to call updates from Firestore
  void _subscribeToCallUpdates(String callId) {
    _callSubscription?.cancel();
    _callSubscription = _firestore
        .collection('group_calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            // Call was deleted
            leaveCall(reason: 'call_ended');
            return;
          }

          final callEntity = GroupCallModel.fromFirestore(doc).toEntity();

          // Check if we need to switch modes
          if (callEntity.shouldSwitchToSfu &&
              state.mode == GroupCallMode.mesh) {
            _handleModeSwitch(callEntity);
          }

          state = state.copyWith(call: callEntity);

          // Check if call ended
          if (callEntity.hasEnded) {
            leaveCall(reason: 'call_ended');
          }
        });

    // Subscribe to participants subcollection
    _participantsSubscription?.cancel();
    _participantsSubscription = _firestore
        .collection('group_calls')
        .doc(callId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
          final participants =
              snapshot.docs
                  .map(
                    (doc) => GroupParticipantEntity(
                      oderId: doc.id,
                      displayName: doc.data()['displayName'] ?? 'Unknown',
                      photoUrl: doc.data()['photoUrl'],
                      role:
                          doc.data()['role'] == 'host'
                              ? GroupParticipantRole.host
                              : GroupParticipantRole.participant,
                      connectionState: ParticipantConnectionState.connected,
                      isMuted: doc.data()['isMuted'] ?? false,
                      isCameraOff: doc.data()['isCameraOff'] ?? true,
                      joinedAt: DateTime.now(),
                    ),
                  )
                  .toList();

          state = state.copyWith(participants: participants);

          // Option A: Auto-end when alone
          _checkIfLastParticipant(participants);
        });
  }

  /// Check if we're the last participant and auto-end the call
  void _checkIfLastParticipant(List<GroupParticipantEntity> participants) {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null || state.call == null) return;

    // Count active participants (excluding ourselves to check if others left)
    final otherParticipants = participants
        .where((p) => p.oderId != currentUser.id && !p.hasLeft)
        .toList();

    // If no other participants and we're connected, end the call
    if (otherParticipants.isEmpty && state.isConnected && !state.isLeaving) {
      debugPrint('GroupCallProvider: Last participant remaining, ending call automatically');
      _endCallAsLastParticipant();
    }
  }

  /// End the call when we're the last participant
  Future<void> _endCallAsLastParticipant() async {
    if (state.call == null || state.isLeaving) return;

    final callId = state.call!.id;

    // Update call status to ended
    try {
      await _firestore.collection('group_calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'all_participants_left',
      });
    } catch (e) {
      debugPrint('GroupCallProvider: Error updating call status: $e');
    }

    // Leave the call with reason
    await leaveCall(reason: 'all_participants_left');
  }

  /// Handle switching from mesh to SFU when participant count exceeds threshold
  Future<void> _handleModeSwitch(GroupCallEntity callEntity) async {
    debugPrint('GroupCallProvider: Switching from mesh to SFU');

    // Leave mesh call
    final meshService = ref.read(groupCallServiceProvider);
    await meshService.leaveCall();

    state = state.copyWith(mode: GroupCallMode.sfu);

    // Join SFU call
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser != null) {
      await _joinSfuCall(
        callEntity: callEntity,
        displayName: currentUser.displayName ?? 'Utilisateur',
        enableVideo: !state.isCameraOff,
        enableE2EE: state.isE2EEEnabled,
      );
    }

    // Update call mode in Firestore
    await _firestore.collection('group_calls').doc(callEntity.id).update({
      'mode': 'sfu',
    });
  }

  /// Start the call duration timer
  void _startDurationTimer() {
    _callStartTime = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        state = state.copyWith(duration: duration);
      }
    });
  }

  /// Toggle microphone mute
  void toggleMute() {
    if (state.mode == GroupCallMode.mesh) {
      ref.read(groupCallServiceProvider).toggleMute();
    } else {
      ref.read(liveKitServiceProvider).toggleMute();
    }

    state = state.copyWith(isMuted: !state.isMuted);
  }

  /// Toggle camera on/off
  void toggleCamera() {
    if (state.mode == GroupCallMode.mesh) {
      ref.read(groupCallServiceProvider).toggleCamera();
    } else {
      ref.read(liveKitServiceProvider).toggleCamera();
    }

    state = state.copyWith(isCameraOff: !state.isCameraOff);
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (state.mode == GroupCallMode.mesh) {
      await ref.read(groupCallServiceProvider).switchCamera();
    } else {
      await ref.read(liveKitServiceProvider).switchCamera();
    }
  }

  /// Set camera enabled/disabled
  Future<void> setCameraEnabled(bool enabled) async {
    if (state.mode == GroupCallMode.mesh) {
      await ref.read(groupCallServiceProvider).setCameraEnabled(enabled);
    } else {
      await ref.read(liveKitServiceProvider).setCameraEnabled(enabled);
    }
    state = state.copyWith(isCameraOff: !enabled);
  }

  /// Toggle screen sharing
  Future<void> toggleScreenShare() async {
    if (state.mode == GroupCallMode.sfu) {
      await ref.read(liveKitServiceProvider).toggleScreenShare();
      state = state.copyWith(isScreenSharing: !state.isScreenSharing);
    }
    // Screen sharing not supported in mesh mode
  }

  /// Set video quality for a remote participant (SFU only)
  Future<void> setVideoQuality(
    String participantId,
    VideoQuality quality,
  ) async {
    if (state.mode == GroupCallMode.sfu) {
      final liveKit = ref.read(liveKitServiceProvider);
      final participant =
          liveKit.remoteParticipants
              .where((p) => p.identity == participantId)
              .firstOrNull;
      if (participant != null) {
        await liveKit.setVideoQuality(participant, quality);
      }
    }
    // Update participant in state
    final updatedParticipants =
        state.participants.map((p) {
          if (p.oderId == participantId) {
            return p.copyWith(videoQuality: quality);
          }
          return p;
        }).toList();
    state = state.copyWith(participants: updatedParticipants);
  }

  /// Leave the current call
  Future<void> leaveCall({String? reason}) async {
    if (state.call == null) return;

    state = state.copyWith(isLeaving: true);

    _durationTimer?.cancel();
    _callSubscription?.cancel();
    _participantsSubscription?.cancel();

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    final callId = state.call!.id;

    try {
      // Leave the call based on mode
      if (state.mode == GroupCallMode.mesh) {
        await ref.read(groupCallServiceProvider).leaveCall();
      } else {
        await ref.read(liveKitServiceProvider).leaveRoom();
      }

      // Update Firestore
      if (currentUser != null) {
        // Remove from participants
        await _firestore.collection('group_calls').doc(callId).update({
          'participantIds': FieldValue.arrayRemove([currentUser.id]),
          'participantCount': FieldValue.increment(-1),
        });

        // Remove from participants subcollection
        await _firestore
            .collection('group_calls')
            .doc(callId)
            .collection('participants')
            .doc(currentUser.id)
            .delete();

        // If we're the host and last to leave, end the call
        if (state.call!.isHost(currentUser.id)) {
          final doc =
              await _firestore.collection('group_calls').doc(callId).get();
          if (doc.exists) {
            final data = doc.data()!;
            final participantCount = data['participantCount'] as int? ?? 0;
            if (participantCount <= 0) {
              await _firestore.collection('group_calls').doc(callId).update({
                'status': 'ended',
                'endedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      // Cleanup RTDB signaling data for mesh calls
      if (state.mode == GroupCallMode.mesh) {
        await _database.ref('group_calls/$callId').remove();
      }
    } catch (e) {
      debugPrint('GroupCallProvider: Error leaving call: $e');
    }

    // Reset state
    _callStartTime = null;
    state = const GroupCallState();
  }
}

/// Provider to check if user is currently in a group call
final isInGroupCallProvider = Provider<bool>((ref) {
  final session = ref.watch(currentGroupCallProvider);
  return session.call != null && session.isConnected;
});

/// Provider to get the current group call ID
final currentGroupCallIdProvider = Provider<String?>((ref) {
  final session = ref.watch(currentGroupCallProvider);
  return session.call?.id;
});

/// Provider for active group calls (that the user can join)
final activeGroupCallsProvider = StreamProvider<List<GroupCallEntity>>((ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('group_calls')
      .where('status', isEqualTo: 'active')
      .where('participantIds', arrayContains: currentUser.id)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => GroupCallModel.fromFirestore(doc).toEntity())
                .toList(),
      );
});
