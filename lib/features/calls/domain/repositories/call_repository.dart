import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/call_entity.dart';

/// Abstract repository interface for call operations
abstract class CallRepository {
  /// Initiate a new call
  Future<Either<Failure, CallEntity>> initiateCall({
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required String calleeId,
    required String calleeName,
    String? calleePhotoUrl,
    required CallType type,
  });

  /// Get a call by ID
  Future<Either<Failure, CallEntity?>> getCall(String callId);

  /// Answer an incoming call
  Future<Either<Failure, void>> answerCall(String callId);

  /// Decline an incoming call
  Future<Either<Failure, void>> declineCall(String callId);

  /// End an active call
  Future<Either<Failure, void>> endCall(String callId, {String? reason});

  /// Update call status
  Future<Either<Failure, void>> updateCallStatus(String callId, CallStatus status);

  /// Stream of active call for current user
  Stream<Either<Failure, CallEntity?>> getActiveCallStream(String userId);

  /// Watch a specific call by ID (regardless of status)
  /// Essential for detecting when remote party ends/declines the call
  Stream<CallEntity?> watchCallById(String callId);

  /// Get call history for a user
  Stream<Either<Failure, List<CallEntity>>> getCallHistory(String userId, {int limit = 50});

  /// Delete a call record
  Future<Either<Failure, void>> deleteCall(String callId);

  /// Get WebRTC signaling stream
  Stream<Either<Failure, Map<String, dynamic>>> getSignalingStream(String callId);

  /// Cleanup stale calls for a user (crash recovery on app startup)
  /// Returns the number of calls cleaned up
  Future<Either<Failure, int>> cleanupUserStaleCalls(String oderId);

  /// Send heartbeat for active call (proves user is still alive)
  Future<Either<Failure, void>> sendHeartbeat(String callId, String oderId);

  /// Stream of remote party heartbeat (to detect if they're still alive)
  Stream<Either<Failure, DateTime?>> watchRemoteHeartbeat(String callId, String remoteUserId);
}
