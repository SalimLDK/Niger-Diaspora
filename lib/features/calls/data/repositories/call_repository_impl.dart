import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_datasource.dart';
import '../models/call_model.dart';

/// Implementation of CallRepository
class CallRepositoryImpl implements CallRepository {
  final CallRemoteDataSource _remoteDataSource;

  CallRepositoryImpl({required CallRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, CallEntity>> initiateCall({
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required String calleeId,
    required String calleeName,
    String? calleePhotoUrl,
    required CallType type,
  }) async {
    try {
      final callModel = CallModel(
        id: '', // Will be set by Firestore
        callerId: callerId,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        calleeId: calleeId,
        calleeName: calleeName,
        calleePhotoUrl: calleePhotoUrl,
        type: type.name,
        status: 'ringing',
        createdAt: DateTime.now().toIso8601String(),
      );

      final result = await _remoteDataSource.createCall(callModel);
      return Right(result.toEntity());
    } catch (e) {
      debugPrint('CallRepository: Error initiating call: $e');
      return const Left(ServerFailure('Impossible de d├®marrer l\'appel'));
    }
  }

  @override
  Future<Either<Failure, CallEntity?>> getCall(String callId) async {
    try {
      final result = await _remoteDataSource.getCall(callId);
      return Right(result?.toEntity());
    } catch (e) {
      debugPrint('CallRepository: Error getting call: $e');
      return const Left(ServerFailure('Impossible de r├®cup├®rer l\'appel'));
    }
  }

  @override
  Future<Either<Failure, void>> answerCall(String callId) async {
    try {
      await _remoteDataSource.answerCall(callId);
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error answering call: $e');
      return const Left(ServerFailure('Impossible de r├®pondre ├á l\'appel'));
    }
  }

  @override
  Future<Either<Failure, void>> declineCall(String callId) async {
    try {
      await _remoteDataSource.declineCall(callId);
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error declining call: $e');
      return const Left(ServerFailure('Impossible de refuser l\'appel'));
    }
  }

  @override
  Future<Either<Failure, void>> endCall(String callId, {String? reason}) async {
    try {
      await _remoteDataSource.endCall(callId, reason ?? 'completed');
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error ending call: $e');
      return const Left(ServerFailure('Impossible de terminer l\'appel'));
    }
  }

  @override
  Future<Either<Failure, void>> updateCallStatus(
    String callId,
    CallStatus status,
  ) async {
    try {
      await _remoteDataSource.updateCallStatus(callId, status.name);
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error updating call status: $e');
      return const Left(ServerFailure('Impossible de mettre ├á jour le statut'));
    }
  }

  @override
  Stream<Either<Failure, CallEntity?>> getActiveCallStream(String userId) {
    return _remoteDataSource.getActiveCallStream(userId).map((callModel) {
      try {
        return Right(callModel?.toEntity());
      } catch (e) {
        debugPrint('CallRepository: Error in active call stream: $e');
        return const Left(ServerFailure('Erreur de flux d\'appel'));
      }
    });
  }

  @override
  Stream<CallEntity?> watchCallById(String callId) {
    return _remoteDataSource.watchCallById(callId).map((callModel) {
      return callModel?.toEntity();
    });
  }

  @override
  Stream<Either<Failure, List<CallEntity>>> getCallHistory(
    String userId, {
    int limit = 50,
  }) {
    return _remoteDataSource.getCallHistory(userId, limit: limit).map((calls) {
      try {
        return Right(calls.map((c) => c.toEntity()).toList());
      } catch (e) {
        debugPrint('CallRepository: Error in call history stream: $e');
        return const Left(ServerFailure('Erreur de l\'historique'));
      }
    });
  }

  @override
  Future<Either<Failure, void>> deleteCall(String callId) async {
    try {
      await _remoteDataSource.deleteCall(callId);
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error deleting call: $e');
      return const Left(ServerFailure('Impossible de supprimer l\'appel'));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> getSignalingStream(
    String callId,
  ) {
    return _remoteDataSource.getSignalingStream(callId).map((data) {
      try {
        return Right(data);
      } catch (e) {
        debugPrint('CallRepository: Error in signaling stream: $e');
        return const Left(ServerFailure('Erreur de signalisation'));
      }
    });
  }

  @override
  Future<Either<Failure, int>> cleanupUserStaleCalls(String userId) async {
    try {
      final count = await _remoteDataSource.cleanupUserStaleCalls(userId);
      return Right(count);
    } catch (e) {
      debugPrint('CallRepository: Error cleaning up stale calls: $e');
      return const Left(ServerFailure('Erreur de nettoyage des appels'));
    }
  }

  @override
  Future<Either<Failure, void>> sendHeartbeat(String callId, String userId) async {
    try {
      await _remoteDataSource.sendHeartbeat(callId, userId);
      return const Right(null);
    } catch (e) {
      debugPrint('CallRepository: Error sending heartbeat: $e');
      return const Left(ServerFailure('Erreur heartbeat'));
    }
  }

  @override
  Stream<Either<Failure, DateTime?>> watchRemoteHeartbeat(
    String callId,
    String remoteUserId,
  ) {
    return _remoteDataSource.watchRemoteHeartbeat(callId, remoteUserId).map((timestamp) {
      try {
        return Right(timestamp);
      } catch (e) {
        debugPrint('CallRepository: Error watching heartbeat: $e');
        return const Left(ServerFailure('Erreur surveillance heartbeat'));
      }
    });
  }
}
