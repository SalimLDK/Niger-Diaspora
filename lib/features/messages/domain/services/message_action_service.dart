import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

/// Service pour les actions sur les messages (reactions, favoris, etc.)
class MessageActionService {
  final FirebaseDatabase _database;

  MessageActionService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  /// Basculer une reaction sur un message
  Future<Either<Failure, void>> toggleReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final reactionsRef =
          _database.ref('messages/$conversationId/$messageId/reactions');
      final snapshot = await reactionsRef.get();

      Map<String, List<String>> reactions = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        reactions = data.map((key, value) {
          final users = (value as List?)?.cast<String>() ?? [];
          return MapEntry(key.toString(), users);
        });
      }

      // Verifier si l'utilisateur a deja cette reaction
      final currentUsers = reactions[emoji] ?? [];
      if (currentUsers.contains(userId)) {
        // Retirer la reaction
        currentUsers.remove(userId);
        if (currentUsers.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = currentUsers;
        }
      } else {
        // Ajouter la reaction
        currentUsers.add(userId);
        reactions[emoji] = currentUsers;
      }

      await reactionsRef.set(reactions);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la mise a jour de la reaction: $e'));
    }
  }

  /// Basculer le statut favori d'un message
  Future<Either<Failure, void>> toggleStar({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final starredByRef =
          _database.ref('messages/$conversationId/$messageId/starredBy');
      final snapshot = await starredByRef.get();

      List<String> starredBy = [];
      if (snapshot.exists) {
        starredBy = (snapshot.value as List?)?.cast<String>() ?? [];
      }

      if (starredBy.contains(userId)) {
        starredBy.remove(userId);
      } else {
        starredBy.add(userId);
      }

      await starredByRef.set(starredBy);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la mise a jour du favori: $e'));
    }
  }

  /// Marquer un message comme lu
  Future<Either<Failure, void>> markAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _database
          .ref('messages/$conversationId/$messageId')
          .update({
        'readBy/$userId': true,
        'readAt/$userId': now,
      });

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors du marquage comme lu: $e'));
    }
  }

  /// Signaler un message
  Future<Either<Failure, void>> reportMessage({
    required String conversationId,
    required String messageId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reportRef = _database.ref('reports/messages').push();

      await reportRef.set({
        'conversationId': conversationId,
        'messageId': messageId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'status': 'pending',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors du signalement: $e'));
    }
  }

  /// Obtenir les reactions d'un message
  Future<Either<Failure, Map<String, List<String>>>> getReactions({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final snapshot = await _database
          .ref('messages/$conversationId/$messageId/reactions')
          .get();

      if (!snapshot.exists) {
        return const Right({});
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final reactions = data.map((key, value) {
        final users = (value as List?)?.cast<String>() ?? [];
        return MapEntry(key.toString(), users);
      });

      return Right(reactions);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la recuperation des reactions: $e'));
    }
  }

  /// Verifier si un message est en favori pour un utilisateur
  Future<bool> isStarred({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final snapshot = await _database
          .ref('messages/$conversationId/$messageId/starredBy')
          .get();

      if (!snapshot.exists) return false;

      final starredBy = (snapshot.value as List?)?.cast<String>() ?? [];
      return starredBy.contains(userId);
    } catch (e) {
      return false;
    }
  }
}

// ============ PROVIDER ============

/// Provider pour le service d'actions sur les messages
final messageActionServiceProvider = Provider<MessageActionService>((ref) {
  return MessageActionService();
});

/// Provider pour basculer une reaction
final toggleReactionProvider = FutureProvider.family<void,
    ({String conversationId, String messageId, String userId, String emoji})>(
    (ref, params) async {
  final service = ref.watch(messageActionServiceProvider);
  final result = await service.toggleReaction(
    conversationId: params.conversationId,
    messageId: params.messageId,
    userId: params.userId,
    emoji: params.emoji,
  );

  result.fold(
    (failure) => throw Exception(failure.message),
    (_) => null,
  );
});

/// Provider pour basculer un favori
final toggleStarProvider = FutureProvider.family<void,
    ({String conversationId, String messageId, String userId})>(
    (ref, params) async {
  final service = ref.watch(messageActionServiceProvider);
  final result = await service.toggleStar(
    conversationId: params.conversationId,
    messageId: params.messageId,
    userId: params.userId,
  );

  result.fold(
    (failure) => throw Exception(failure.message),
    (_) => null,
  );
});
