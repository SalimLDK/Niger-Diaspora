import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audio_room_model.dart';
import '../models/participant_model.dart';

/// Abstract interface for audio room remote data operations
abstract class AudioRoomRemoteDataSource {
  /// Create a new audio room
  Future<AudioRoomModel> createRoom(AudioRoomModel room);

  /// Get a room by ID
  Future<AudioRoomModel?> getRoom(String roomId);

  /// Update room status
  Future<void> updateRoomStatus(String roomId, String status);

  /// Update the settings an host can change while the room is live.
  /// Only non-null fields are written.
  Future<void> updateRoomSettings(
    String roomId, {
    bool? isRecordingEnabled,
    bool? isVideoEnabled,
    bool? isPrivate,
  });

  /// Start a scheduled room
  Future<void> startRoom(String roomId);

  /// End a room
  Future<void> endRoom(String roomId);

  /// Delete a room
  Future<void> deleteRoom(String roomId);

  /// Join a room as listener
  Future<void> joinAsListener(String roomId, String oderId);

  /// Leave a room
  Future<void> leaveRoom(String roomId, String oderId);

  /// Raise hand to speak
  Future<void> raiseHand(String roomId, String oderId);

  /// Lower hand
  Future<void> lowerHand(String roomId, String oderId);

  /// Promote user to speaker
  Future<void> promoteToSpeaker(String roomId, String oderId);

  /// Demote speaker to listener
  Future<void> demoteToListener(String roomId, String oderId);

  /// Add co-host
  Future<void> addCoHost(String roomId, String oderId);

  /// Remove co-host
  Future<void> removeCoHost(String roomId, String oderId);

  /// Mute a speaker
  Future<void> muteSpeaker(String roomId, String oderId);

  /// Unmute a speaker
  Future<void> unmuteSpeaker(String roomId, String oderId);

  /// Kick user from room
  Future<void> kickUser(String roomId, String oderId);

  /// Block user from room
  Future<void> blockUser(String roomId, String oderId);

  /// Unblock user
  Future<void> unblockUser(String roomId, String oderId);

  /// Stream of live rooms
  Stream<List<AudioRoomModel>> getLiveRoomsStream();

  /// Stream of scheduled rooms
  Stream<List<AudioRoomModel>> getScheduledRoomsStream();

  /// Stream of a specific room
  Stream<AudioRoomModel?> getRoomStream(String roomId);

  /// Stream of participants in a room (from RTDB)
  Stream<List<ParticipantModel>> getParticipantsStream(String roomId);

  /// Update participant speaking state
  Future<void> updateSpeakingState(
    String roomId,
    String oderId,
    bool isSpeaking,
    double? audioLevel,
  );

  /// Update participant mute state
  Future<void> updateMuteState(String roomId, String oderId, bool isMuted);

  /// Update participant camera state
  Future<void> updateCameraState(String roomId, String oderId, bool isCameraOn);

  /// Join as ghost moderator (invisible admin)
  Future<void> joinAsGhostModerator(String roomId, String oderId);

  /// Force end a room (admin action)
  Future<void> forceEndRoom(String roomId, String reason);

  /// Send warning to host (admin action)
  Future<void> warnHost(String roomId, String message);
}

/// Implementation of AudioRoomRemoteDataSource using Supabase (DB) + Firebase RTDB (signaling)
class AudioRoomRemoteDataSourceImpl implements AudioRoomRemoteDataSource {
  final SupabaseClient _supabase;
  final FirebaseDatabase _database;

  AudioRoomRemoteDataSourceImpl({
    SupabaseClient? supabaseInstance,
    FirebaseDatabase? databaseInstance,
  }) : _supabase = supabaseInstance ?? Supabase.instance.client,
       _database = databaseInstance ?? FirebaseDatabase.instance;

  SupabaseQueryBuilder get _roomsTable => _supabase.from('audio_rooms');

  DatabaseReference _roomParticipantsRef(String roomId) =>
      _database.ref('audioRooms/$roomId/participants');

  @override
  Future<AudioRoomModel> createRoom(AudioRoomModel room) async {
    try {
      final data = room.toJson()..remove('id');
      final response =
          await _roomsTable.insert(data).select().single();
      return AudioRoomModel.fromJson(response);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error creating room: $e');
      rethrow;
    }
  }

  @override
  Future<AudioRoomModel?> getRoom(String roomId) async {
    try {
      final response = await _roomsTable
          .select()
          .eq('id', roomId)
          .maybeSingle();
      if (response == null) return null;
      return AudioRoomModel.fromJson(response);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error getting room: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateRoomStatus(String roomId, String status) async {
    try {
      await _roomsTable.update({'status': status}).eq('id', roomId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error updating room status: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateRoomSettings(
    String roomId, {
    bool? isRecordingEnabled,
    bool? isVideoEnabled,
    bool? isPrivate,
  }) async {
    // Seuls les champs fournis sont écrits : un `update` complet écraserait
    // les réglages que l'appelant n'a pas touchés.
    final patch = <String, dynamic>{
      if (isRecordingEnabled != null) 'isRecordingEnabled': isRecordingEnabled,
      if (isVideoEnabled != null) 'isVideoEnabled': isVideoEnabled,
      if (isPrivate != null) 'isPrivate': isPrivate,
    };
    if (patch.isEmpty) return;
    try {
      await _roomsTable.update(patch).eq('id', roomId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error updating room settings: $e');
      rethrow;
    }
  }

  @override
  Future<void> startRoom(String roomId) async {
    try {
      await _roomsTable.update({
        'status': 'live',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error starting room: $e');
      rethrow;
    }
  }

  @override
  Future<void> endRoom(String roomId) async {
    try {
      await _roomsTable.update({
        'status': 'ended',
        'endedAt': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', roomId);

      // Cleanup RTDB data
      await _database.ref('audioRooms/$roomId').remove();
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error ending room: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    try {
      await _roomsTable.delete().eq('id', roomId);
      await _database.ref('audioRooms/$roomId').remove();
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error deleting room: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Array-mutation helpers (Supabase uses Postgres array functions via rpc)
  // ---------------------------------------------------------------------------

  /// Append [value] to a text[] column if not already present.
  Future<void> _arrayUnion(String roomId, String column, String value) async {
    await _supabase.rpc('array_append_unique', params: {
      'p_table': 'audio_rooms',
      'p_id': roomId,
      'p_column': column,
      'p_value': value,
    },);
  }

  /// Remove [value] from a text[] column.
  Future<void> _arrayRemove(String roomId, String column, String value) async {
    await _supabase.rpc('array_remove_element', params: {
      'p_table': 'audio_rooms',
      'p_id': roomId,
      'p_column': column,
      'p_value': value,
    },);
  }

  @override
  Future<void> joinAsListener(String roomId, String oderId) async {
    try {
      await _arrayUnion(roomId, 'listenerIds', oderId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error joining as listener: $e');
      rethrow;
    }
  }

  @override
  Future<void> leaveRoom(String roomId, String oderId) async {
    try {
      for (final col in ['listenerIds', 'speakerIds', 'coHostIds', 'handRaiseUserIds']) {
        await _arrayRemove(roomId, col, oderId);
      }

      // Remove from RTDB participants
      await _roomParticipantsRef(roomId).child(oderId).remove();
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error leaving room: $e');
      rethrow;
    }
  }

  @override
  Future<void> raiseHand(String roomId, String oderId) async {
    try {
      await _arrayUnion(roomId, 'handRaiseUserIds', oderId);

      // Update in RTDB for real-time
      await _roomParticipantsRef(roomId).child(oderId).update({
        'hasHandRaised': true,
        'handRaisedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error raising hand: $e');
      rethrow;
    }
  }

  @override
  Future<void> lowerHand(String roomId, String oderId) async {
    try {
      await _arrayRemove(roomId, 'handRaiseUserIds', oderId);

      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'hasHandRaised': false, 'handRaisedAt': null});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error lowering hand: $e');
      rethrow;
    }
  }

  @override
  Future<void> promoteToSpeaker(String roomId, String oderId) async {
    try {
      await _arrayUnion(roomId, 'speakerIds', oderId);
      await _arrayRemove(roomId, 'listenerIds', oderId);
      await _arrayRemove(roomId, 'handRaiseUserIds', oderId);

      await _roomParticipantsRef(roomId).child(oderId).update({
        'role': 'speaker',
        'hasHandRaised': false,
        'handRaisedAt': null,
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error promoting to speaker: $e');
      rethrow;
    }
  }

  @override
  Future<void> demoteToListener(String roomId, String oderId) async {
    try {
      await _arrayRemove(roomId, 'speakerIds', oderId);
      await _arrayUnion(roomId, 'listenerIds', oderId);

      await _roomParticipantsRef(roomId).child(oderId).update({
        'role': 'listener',
        'isSpeaking': false,
        'audioLevel': 0,
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error demoting to listener: $e');
      rethrow;
    }
  }

  @override
  Future<void> addCoHost(String roomId, String oderId) async {
    try {
      await _arrayUnion(roomId, 'coHostIds', oderId);
      await _arrayRemove(roomId, 'speakerIds', oderId);
      await _arrayRemove(roomId, 'listenerIds', oderId);

      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'role': 'coHost'});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error adding co-host: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeCoHost(String roomId, String oderId) async {
    try {
      await _arrayRemove(roomId, 'coHostIds', oderId);
      await _arrayUnion(roomId, 'speakerIds', oderId);

      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'role': 'speaker'});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error removing co-host: $e');
      rethrow;
    }
  }

  @override
  Future<void> muteSpeaker(String roomId, String oderId) async {
    try {
      // Fetch current mutedSpeakers map, add entry, and update
      final row = await _roomsTable
          .select('mutedSpeakers')
          .eq('id', roomId)
          .single();
      final muted = Map<String, dynamic>.from(
        (row['mutedSpeakers'] as Map?) ?? {},
      );
      muted[oderId] = DateTime.now().toUtc().toIso8601String();
      await _roomsTable.update({'mutedSpeakers': muted}).eq('id', roomId);

      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'isMuted': true});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error muting speaker: $e');
      rethrow;
    }
  }

  @override
  Future<void> unmuteSpeaker(String roomId, String oderId) async {
    try {
      final row = await _roomsTable
          .select('mutedSpeakers')
          .eq('id', roomId)
          .single();
      final muted = Map<String, dynamic>.from(
        (row['mutedSpeakers'] as Map?) ?? {},
      );
      muted.remove(oderId);
      await _roomsTable.update({'mutedSpeakers': muted}).eq('id', roomId);

      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'isMuted': false});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error unmuting speaker: $e');
      rethrow;
    }
  }

  @override
  Future<void> kickUser(String roomId, String oderId) async {
    try {
      await leaveRoom(roomId, oderId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error kicking user: $e');
      rethrow;
    }
  }

  @override
  Future<void> blockUser(String roomId, String oderId) async {
    try {
      await leaveRoom(roomId, oderId);
      await _arrayUnion(roomId, 'blockedUserIds', oderId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error blocking user: $e');
      rethrow;
    }
  }

  @override
  Future<void> unblockUser(String roomId, String oderId) async {
    try {
      await _arrayRemove(roomId, 'blockedUserIds', oderId);
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error unblocking user: $e');
      rethrow;
    }
  }

  @override
  Stream<List<AudioRoomModel>> getLiveRoomsStream() {
    return _supabase
        .from('audio_rooms')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .order('startedAt', ascending: false)
        .map((rows) => rows.map(AudioRoomModel.fromJson).toList());
  }

  @override
  Stream<List<AudioRoomModel>> getScheduledRoomsStream() {
    return _supabase
        .from('audio_rooms')
        .stream(primaryKey: ['id'])
        .eq('status', 'scheduled')
        .order('scheduledAt')
        .map((rows) => rows
            .where((r) {
              final s = r['scheduledAt'] as String?;
              return s != null && DateTime.tryParse(s)?.isAfter(DateTime.now()) == true;
            },)
            .map(AudioRoomModel.fromJson)
            .toList(),);
  }

  @override
  Stream<AudioRoomModel?> getRoomStream(String roomId) {
    return _supabase
        .from('audio_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isEmpty ? null : AudioRoomModel.fromJson(rows.first));
  }

  @override
  Stream<List<ParticipantModel>> getParticipantsStream(String roomId) {
    return _roomParticipantsRef(roomId).onValue.map((event) {
      if (event.snapshot.value == null) return <ParticipantModel>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((entry) {
        final participantData = Map<String, dynamic>.from(entry.value as Map);
        return ParticipantModel.fromRTDB(entry.key, participantData);
      }).toList();
    });
  }

  @override
  Future<void> updateSpeakingState(
    String roomId,
    String oderId,
    bool isSpeaking,
    double? audioLevel,
  ) async {
    try {
      await _roomParticipantsRef(roomId).child(oderId).update({
        'isSpeaking': isSpeaking,
        'audioLevel': audioLevel ?? 0,
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error updating speaking state: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateMuteState(
    String roomId,
    String oderId,
    bool isMuted,
  ) async {
    try {
      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'isMuted': isMuted});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error updating mute state: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateCameraState(
    String roomId,
    String oderId,
    bool isCameraOn,
  ) async {
    try {
      await _roomParticipantsRef(
        roomId,
      ).child(oderId).update({'isCameraOn': isCameraOn});
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error updating camera state: $e');
      rethrow;
    }
  }

  @override
  Future<void> joinAsGhostModerator(String roomId, String oderId) async {
    try {
      // Add to moderatorIds in Supabase (not visible to regular users)
      await _arrayUnion(roomId, 'moderatorIds', oderId);

      // Add to RTDB participants with ghost mode flag
      await _roomParticipantsRef(roomId).child(oderId).set({
        'userName': 'Modérateur',
        'role': 'moderator',
        'connectionState': 'connected',
        'isMuted': true,
        'isSpeaking': false,
        'joinedAt': DateTime.now().toUtc().toIso8601String(),
        'hasHandRaised': false,
        'isCameraOn': false,
        'isGhostMode': true,
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error joining as ghost moderator: $e');
      rethrow;
    }
  }

  @override
  Future<void> forceEndRoom(String roomId, String reason) async {
    try {
      await _roomsTable.update({
        'status': 'ended',
        'endedAt': DateTime.now().toUtc().toIso8601String(),
        'endedByAdmin': true,
        'endReason': reason,
      }).eq('id', roomId);

      // Cleanup RTDB data
      await _database.ref('audioRooms/$roomId').remove();
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error force ending room: $e');
      rethrow;
    }
  }

  @override
  Future<void> warnHost(String roomId, String message) async {
    try {
      // Fetch current adminWarnings array, append, and update
      final row = await _roomsTable
          .select('adminWarnings')
          .eq('id', roomId)
          .single();
      final warnings = List<Map<String, dynamic>>.from(
        (row['adminWarnings'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      warnings.add({
        'message': message,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      await _roomsTable.update({'adminWarnings': warnings}).eq('id', roomId);

      // Also send to RTDB for real-time notification
      await _database.ref('audioRooms/$roomId/warnings').push().set({
        'message': message,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      debugPrint('AudioRoomDataSource: Error warning host: $e');
      rethrow;
    }
  }
}
