import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../models/call_model.dart';

/// Abstract interface for call remote data operations
abstract class CallRemoteDataSource {
  /// Create a new call
  Future<CallModel> createCall(CallModel call);

  /// Check if a user is currently busy (in an active call)
  Future<bool> isUserBusy(String userId);

  /// Get a call by ID
  Future<CallModel?> getCall(String callId);

  /// Update call status
  Future<void> updateCallStatus(String callId, String status);

  /// End a call
  Future<void> endCall(String callId, String endReason);

  /// Answer a call
  Future<void> answerCall(String callId);

  /// Decline a call
  Future<void> declineCall(String callId);

  /// Stream of active call for a user (incoming or outgoing)
  Stream<CallModel?> getActiveCallStream(String userId);

  /// Stream that watches a specific call by ID (regardless of status)
  /// This is crucial for detecting when the remote party ends/declines the call
  Stream<CallModel?> watchCallById(String callId);

  /// Get call history for a user
  Stream<List<CallModel>> getCallHistory(String userId, {int limit = 50});

  /// Delete call record
  Future<void> deleteCall(String callId);

  /// Send WebRTC offer
  Future<void> sendOffer(String callId, Map<String, dynamic> offer);

  /// Send WebRTC answer
  Future<void> sendAnswer(String callId, Map<String, dynamic> answer);

  /// Send ICE candidate
  Future<void> sendIceCandidate(
    String callId,
    String oderId,
    Map<String, dynamic> candidate,
  );

  /// Stream of WebRTC signaling data
  Stream<Map<String, dynamic>> getSignalingStream(String callId);

  /// Cleanup stale calls for a user (crash recovery)
  /// Returns the number of calls cleaned up
  Future<int> cleanupUserStaleCalls(String userId);

  /// Send heartbeat for active call
  Future<void> sendHeartbeat(String callId, String userId);

  /// Stream of remote party heartbeat
  Stream<DateTime?> watchRemoteHeartbeat(String callId, String remoteUserId);

  /// Mark a 1:1 call as converted to a group call
  Future<void> markAsConvertedToGroup(String callId, String groupCallId);

  /// Send a transition signal to notify the other participant about group call conversion
  Future<void> sendTransitionSignal(String callId, String groupCallId);

  /// Watch for transition signal from the other participant
  Stream<String?> watchTransitionSignal(String callId);
}

/// Implementation of CallRemoteDataSource using Firebase
class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  CallRemoteDataSourceImpl({
    FirebaseFirestore? firestoreInstance,
    FirebaseDatabase? databaseInstance,
  }) : _firestore = firestoreInstance ?? FirebaseFirestore.instance,
       _database = databaseInstance ?? FirebaseDatabase.instance;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection(FirebaseCollections.calls);

  DatabaseReference _callSignalingRef(String callId) =>
      _database.ref('calls/$callId');

  /// Active call statuses for busy check
  static const _activeStatuses = ['ringing', 'connecting', 'connected', 'reconnecting', 'onHold'];

  @override
  Future<bool> isUserBusy(String userId) async {
    try {
      // Check if user is caller in any active call
      final callerQuery = await _callsCollection
          .where('callerId', isEqualTo: userId)
          .where('status', whereIn: _activeStatuses)
          .limit(1)
          .get();

      if (callerQuery.docs.isNotEmpty) {
        return true;
      }

      // Check if user is callee in any active call
      final calleeQuery = await _callsCollection
          .where('calleeId', isEqualTo: userId)
          .where('status', whereIn: _activeStatuses)
          .limit(1)
          .get();

      return calleeQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error checking if user is busy: $e');
      return false; // Assume not busy on error to avoid blocking calls
    }
  }

  @override
  Future<CallModel> createCall(CallModel call) async {
    try {
      // Check if callee is busy before creating call
      final isCalleeBusy = await isUserBusy(call.calleeId);
      if (isCalleeBusy) {
        debugPrint('CallRemoteDataSource: Callee ${call.calleeId} is busy');
        // Create call with busy status immediately
        final busyCall = CallModel(
          id: '',
          callerId: call.callerId,
          callerName: call.callerName,
          callerPhotoUrl: call.callerPhotoUrl,
          calleeId: call.calleeId,
          calleeName: call.calleeName,
          calleePhotoUrl: call.calleePhotoUrl,
          type: call.type,
          status: 'busy',
          createdAt: DateTime.now().toIso8601String(),
          endReason: 'callee_busy',
        );
        final docRef = await _callsCollection.add(busyCall.toFirestore());
        final doc = await docRef.get();
        return CallModel.fromFirestore(doc);
      }

      // Check if caller is already in a call
      final isCallerBusy = await isUserBusy(call.callerId);
      if (isCallerBusy) {
        throw Exception('Caller is already in a call');
      }

      final docRef = await _callsCollection.add(call.toFirestore());
      final doc = await docRef.get();
      return CallModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error creating call: $e');
      rethrow;
    }
  }

  @override
  Future<CallModel?> getCall(String callId) async {
    try {
      final doc = await _callsCollection.doc(callId).get();
      if (!doc.exists) return null;
      return CallModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error getting call: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      // Use transaction to validate state transition
      await _firestore.runTransaction((transaction) async {
        final docRef = _callsCollection.doc(callId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('Call $callId does not exist');
        }

        final currentStatus = doc.data()?['status'] as String?;

        // Skip if already in the target status (idempotent)
        if (currentStatus == status) {
          debugPrint('CallRemoteDataSource: Call already in status $status');
          return;
        }

        // Check if this is a terminal status and don't allow changes
        const terminalStatuses = ['ended', 'declined', 'missed', 'busy', 'error'];
        if (terminalStatuses.contains(currentStatus)) {
          debugPrint('CallRemoteDataSource: Cannot change status from terminal state $currentStatus');
          return;
        }

        transaction.update(docRef, {'status': status});
      });

      // Also update in RTDB for real-time sync (outside transaction)
      await _callSignalingRef(callId).update({'status': status});
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error updating call status: $e');
      rethrow;
    }
  }

  @override
  Future<void> endCall(String callId, String endReason) async {
    try {
      // Use transaction to ensure idempotency
      await _firestore.runTransaction((transaction) async {
        final docRef = _callsCollection.doc(callId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          debugPrint('CallRemoteDataSource: Call $callId does not exist');
          return;
        }

        final data = doc.data()!;
        final currentStatus = data['status'] as String?;

        // Check if already ended (idempotent)
        const terminalStatuses = ['ended', 'declined', 'missed', 'busy', 'error'];
        if (terminalStatuses.contains(currentStatus)) {
          debugPrint('CallRemoteDataSource: Call $callId already ended with status $currentStatus');
          return;
        }

        // Calculate duration if call was answered
        int? duration;
        final answeredAtStr = data['answeredAt'];
        if (answeredAtStr != null) {
          try {
            final answeredAt = answeredAtStr is Timestamp
                ? answeredAtStr.toDate()
                : DateTime.parse(answeredAtStr.toString());
            duration = DateTime.now().difference(answeredAt).inSeconds;
          } catch (e) {
            debugPrint('CallRemoteDataSource: Error parsing answeredAt: $e');
          }
        }

        final updates = <String, dynamic>{
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'endReason': endReason,
        };

        if (duration != null) {
          updates['durationSeconds'] = duration;
        }

        transaction.update(docRef, updates);
      });

      // Cleanup RTDB signaling data (outside transaction)
      await _callSignalingRef(callId).remove();
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error ending call: $e');
      rethrow;
    }
  }

  @override
  Future<void> answerCall(String callId) async {
    try {
      await _callsCollection.doc(callId).update({
        'status': 'connecting',
        'answeredAt': FieldValue.serverTimestamp(),
      });

      await _callSignalingRef(callId).update({'status': 'connecting'});
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error answering call: $e');
      rethrow;
    }
  }

  @override
  Future<void> declineCall(String callId) async {
    try {
      await _callsCollection.doc(callId).update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'declined',
      });

      await _callSignalingRef(callId).remove();
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error declining call: $e');
      rethrow;
    }
  }

  @override
  Stream<CallModel?> getActiveCallStream(String userId) {
    // Firestore rules require callerId or calleeId filter ÔÇö a bare status query
    // is denied because the rule checks resource.data fields at list time.
    // Use two separate queries and merge them.
    final activeStatuses = ['ringing', 'connecting', 'connected'];

    final callerStream = _callsCollection
        .where('callerId', isEqualTo: userId)
        .where('status', whereIn: activeStatuses)
        .snapshots()
        .map<CallModel?>((s) => s.docs.isNotEmpty
            ? CallModel.fromFirestore(s.docs.first)
            : null,);

    final calleeStream = _callsCollection
        .where('calleeId', isEqualTo: userId)
        .where('status', whereIn: activeStatuses)
        .snapshots()
        .map<CallModel?>((s) => s.docs.isNotEmpty
            ? CallModel.fromFirestore(s.docs.first)
            : null,);

    return Rx.combineLatest2<CallModel?, CallModel?, CallModel?>(
      callerStream,
      calleeStream,
      (a, b) => a ?? b,
    );
  }

  @override
  Stream<CallModel?> watchCallById(String callId) {
    // Watch a specific call by ID, regardless of its status
    // This is essential for detecting when the remote party ends/declines
    return _callsCollection.doc(callId).snapshots().map((doc) {
      if (!doc.exists) {
        debugPrint('CallRemoteDataSource: Call $callId does not exist');
        return null;
      }
      return CallModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<CallModel>> getCallHistory(String userId, {int limit = 50}) {
    // Get calls where user was either caller or callee
    // We need two queries and merge them
    final callerQuery = _callsCollection
        .where('callerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final calleeQuery = _callsCollection
        .where('calleeId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return callerQuery.snapshots().asyncMap((callerSnapshot) async {
      final calleeSnapshot = await calleeQuery.get();

      final allCalls = <CallModel>[];

      for (final doc in callerSnapshot.docs) {
        allCalls.add(CallModel.fromFirestore(doc));
      }

      for (final doc in calleeSnapshot.docs) {
        // Avoid duplicates
        if (!allCalls.any((c) => c.id == doc.id)) {
          allCalls.add(CallModel.fromFirestore(doc));
        }
      }

      // Sort by createdAt descending
      allCalls.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allCalls.take(limit).toList();
    });
  }

  @override
  Future<void> deleteCall(String callId) async {
    try {
      await _callsCollection.doc(callId).delete();
      await _callSignalingRef(callId).remove();
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error deleting call: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendOffer(String callId, Map<String, dynamic> offer) async {
    try {
      await _callSignalingRef(callId).child('offer').set(offer);
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error sending offer: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendAnswer(String callId, Map<String, dynamic> answer) async {
    try {
      await _callSignalingRef(callId).child('answer').set(answer);
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error sending answer: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendIceCandidate(
    String callId,
    String oderId,
    Map<String, dynamic> candidate,
  ) async {
    try {
      await _callSignalingRef(
        callId,
      ).child('candidates').child(oderId).push().set(candidate);
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error sending ICE candidate: $e');
      rethrow;
    }
  }

  @override
  Stream<Map<String, dynamic>> getSignalingStream(String callId) {
    return _callSignalingRef(callId).onValue.map((event) {
      if (event.snapshot.value == null) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  @override
  Future<int> cleanupUserStaleCalls(String userId) async {
    try {
      int cleanedCount = 0;

      // Find calls where user is caller with active status
      final callerQuery = await _callsCollection
          .where('callerId', isEqualTo: userId)
          .where('status', whereIn: _activeStatuses)
          .get();

      // Find calls where user is callee with active status
      final calleeQuery = await _callsCollection
          .where('calleeId', isEqualTo: userId)
          .where('status', whereIn: _activeStatuses)
          .get();

      // Combine and deduplicate
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in callerQuery.docs) {
        allDocs[doc.id] = doc;
      }
      for (final doc in calleeQuery.docs) {
        allDocs[doc.id] = doc;
      }

      // End each stale call
      for (final doc in allDocs.values) {
        try {
          await doc.reference.update({
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'endReason': 'app_restart_cleanup',
          });

          // Cleanup RTDB signaling data
          await _callSignalingRef(doc.id).remove();
          cleanedCount++;

          debugPrint('CallRemoteDataSource: Cleaned up stale call ${doc.id}');
        } catch (e) {
          debugPrint('CallRemoteDataSource: Error cleaning call ${doc.id}: $e');
        }
      }

      return cleanedCount;
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error cleaning up stale calls: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendHeartbeat(String callId, String userId) async {
    try {
      final heartbeatRef = _callSignalingRef(callId).child('heartbeat').child(userId);
      await heartbeatRef.set(ServerValue.timestamp);
      // Auto-remove on RTDB connection loss so the server cleanup function
      // detects the absence immediately rather than waiting for a stale timestamp.
      await heartbeatRef.onDisconnect().remove();
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error sending heartbeat: $e');
      // Don't rethrow - heartbeat failure shouldn't crash the call
    }
  }

  @override
  Stream<DateTime?> watchRemoteHeartbeat(String callId, String remoteUserId) {
    return _callSignalingRef(callId)
        .child('heartbeat')
        .child(remoteUserId)
        .onValue
        .map((event) {
      final timestamp = event.snapshot.value;
      if (timestamp == null) return null;
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    });
  }

  @override
  Future<void> markAsConvertedToGroup(String callId, String groupCallId) async {
    try {
      await _callsCollection.doc(callId).update({
        'status': 'converted_to_group',
        'groupCallId': groupCallId,
        'convertedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'CallRemoteDataSource: Marked call $callId as converted to group $groupCallId',
      );
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error marking call as converted: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendTransitionSignal(String callId, String groupCallId) async {
    try {
      await _callSignalingRef(callId).child('transition').set({
        'groupCallId': groupCallId,
        'initiatedAt': ServerValue.timestamp,
      });
      debugPrint(
        'CallRemoteDataSource: Sent transition signal for call $callId to group $groupCallId',
      );
    } catch (e) {
      debugPrint('CallRemoteDataSource: Error sending transition signal: $e');
      rethrow;
    }
  }

  @override
  Stream<String?> watchTransitionSignal(String callId) {
    return _callSignalingRef(callId)
        .child('transition')
        .child('groupCallId')
        .onValue
        .map((event) {
      final groupCallId = event.snapshot.value;
      if (groupCallId == null) return null;
      return groupCallId.toString();
    });
  }
}
